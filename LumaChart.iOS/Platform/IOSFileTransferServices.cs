using Avalonia.Threading;
using Foundation;
using LumaChart.Avalonia.Services;
using UIKit;
using UniformTypeIdentifiers;

namespace LumaChart.iOS.Platform;

/// <summary>
/// How charts and audio cross the sandbox boundary on iOS.
///
/// Both directions go through <see cref="UIDocumentPickerViewController"/>,
/// which is the only way an app reaches storage it does not own. The shape it
/// forces is not the same in both directions, and that asymmetry is the reason
/// import and export are written differently below:
///
/// - Opening hands back a URL the app may read, so the import can copy
///   immediately and return a real path, exactly as Android does.
/// - Exporting has no "create an empty document here" mode. The picker takes a
///   file that already exists, so the destination cannot be chosen before the
///   bytes are written. The picker is therefore presented at commit time, which
///   is precisely the case <see cref="IPlatformFileExportService"/> was written
///   for: the platform "takes over once the bytes exist".
/// </summary>
internal sealed class IOSFileTransferServices : IPlatformFileImportService, IPlatformFileExportService
{
    private readonly string libraryRoot;
    private readonly string importStagingRoot;
    private readonly string exportStagingRoot;

    public IOSFileTransferServices(IOSAppStorageLocations locations)
    {
        ArgumentNullException.ThrowIfNull(locations);
        libraryRoot = locations.Library;
        importStagingRoot = Path.Combine(locations.ResourceCache, "_import");
        exportStagingRoot = Path.Combine(locations.ResourceCache, "_export");
    }

    /// <summary>
    /// The document picker can return a directory, but only as a
    /// security-scoped URL that has to be re-resolved from a bookmark on every
    /// launch — a path handed to the shared workspace code would stop being
    /// readable the next time the app starts. Same answer as Android, different
    /// reason.
    /// </summary>
    public bool SupportsWorkspaceDirectorySelection => false;

    /// <summary>
    /// Save As stays inside the app's own library, where a chart keeps its audio
    /// and images and stays indexed. A picked export location is a one-shot
    /// write, not something a tab can stay bound to.
    /// </summary>
    public string? InAppSaveAsRoot => libraryRoot;

    /// <summary>
    /// Nothing thrown from here may reach the caller.
    ///
    /// Every call site is an Avalonia click handler written as
    /// <c>async (_, _) =&gt; await PickAndOpenChartAsync()</c>, which is an
    /// <c>async void</c>: an exception escaping it is unhandled by definition,
    /// and on iOS an unhandled exception aborts the process. Picking a .png is
    /// a user's ordinary mistake, and it took the whole editor down —
    ///
    ///   FAILED at AppDomain.UnhandledException: System.IO.InvalidDataException
    ///   请选择 .mc、.mcz、.osu 或 .osz 谱面文件。
    ///
    /// — so a wrong choice reports itself through the notice seam and returns
    /// null, which the shared caller already treats as "nothing was picked".
    /// </summary>
    public async Task<string?> PickChartFileAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            // Every data file is offered and the extension is checked
            // afterwards, the same way Android asks for */*. The alternative is
            // to declare custom UTIs for .mc/.mcz/.osu/.osz, which would also
            // make the system hide every one of those files that arrived before
            // the app existed.
            var picked = await PresentPickerAsync(
                () => new UIDocumentPickerViewController([UTTypes.Data], asCopy: true),
                cancellationToken).ConfigureAwait(false);
            if (picked is not { Length: > 0 }) return null;

            var source = picked[0];
            var sourcePath = source.Path;
            if (string.IsNullOrWhiteSpace(sourcePath))
                return Reject("无法读取所选文件。");

            var name = source.LastPathComponent;
            if (string.IsNullOrWhiteSpace(name)) name = Path.GetFileName(sourcePath);
            var extension = Path.GetExtension(name);
            if (!IsSupportedChartExtension(extension))
                return Reject("请选择 .mc、.mcz、.osu 或 .osz 谱面文件。");

            // A picked .mc/.osu becomes the library item itself, so it is copied
            // straight into the library. An archive is only the input to the
            // shared import, which unpacks it into its own library folder;
            // keeping the archive in the library would leave a dead copy beside
            // every import.
            var archive = IsArchiveExtension(extension);
            var root = archive ? importStagingRoot : libraryRoot;
            if (archive) ClearDirectory(importStagingRoot);
            Directory.CreateDirectory(root);

            var destination = CreateUniqueDestination(root, MakeSafeFileName(name));
            await using (var input = new FileStream(
                             sourcePath, FileMode.Open, FileAccess.Read, FileShare.Read))
            await using (var output = new FileStream(
                             destination, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            {
                await input.CopyToAsync(output, cancellationToken).ConfigureAwait(false);
            }

            // asCopy hands over a copy in the app's own inbox that nothing else
            // will clean up.
            TryDelete(sourcePath);
            return destination;
        }
        catch (OperationCanceledException)
        {
            // The caller cancelled; not a failure to report.
            return null;
        }
        catch (Exception exception)
        {
            IOSLaunchLog.WriteException("chart import", exception);
            return Reject(exception.Message);
        }
    }

    private static string? Reject(string message)
    {
        PlatformNoticeServices.Current?.Show(
            "导入谱面", message, PlatformNoticeSeverity.Warning);
        return null;
    }

    public Task<IPlatformExportDestination?> PickExportDestinationAsync(
        string suggestedFileName,
        string extension,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(suggestedFileName);
        cancellationToken.ThrowIfCancellationRequested();

        // No picker here: see the type comment. The export runs against the
        // staging path first and the user chooses where it lands on commit.
        ClearDirectory(exportStagingRoot);
        Directory.CreateDirectory(exportStagingRoot);
        var stagingPath = Path.Combine(
            exportStagingRoot,
            MakeSafeFileName(Path.GetFileName(suggestedFileName)));
        _ = extension;

        return Task.FromResult<IPlatformExportDestination?>(
            new IOSExportDestination(stagingPath));
    }

    /// <summary>
    /// Takes a file the system handed over through "open with LumaChart" and
    /// returns an app-private copy the editor can open, or null if it is not a
    /// chart.
    ///
    /// The copy is not optional. With LSSupportsOpeningDocumentsInPlace the URL
    /// points at the file where it actually lives and is only readable inside a
    /// security scope, exactly like a picked document — the same trap that made
    /// audio import report "音频文件已不存在" a few seconds after the pick.
    /// Copying happens while the scope is open and everything downstream sees an
    /// ordinary path.
    ///
    /// Synchronous on purpose: UIApplication expects OpenUrl to answer promptly,
    /// and this is a local file copy of a chart or a chart archive.
    /// </summary>
    public string? TryAcceptIncomingFile(NSUrl url)
    {
        ArgumentNullException.ThrowIfNull(url);
        var scoped = url.StartAccessingSecurityScopedResource();
        try
        {
            var sourcePath = url.Path;
            if (string.IsNullOrWhiteSpace(sourcePath) || !File.Exists(sourcePath))
                return Reject("无法读取该文件。");

            var name = url.LastPathComponent;
            if (string.IsNullOrWhiteSpace(name)) name = Path.GetFileName(sourcePath);
            var extension = Path.GetExtension(name);
            if (!IsSupportedChartExtension(extension))
                return Reject("只能打开 .mc、.mcz、.osu 或 .osz 谱面文件。");

            var archive = IsArchiveExtension(extension);
            var root = archive ? importStagingRoot : libraryRoot;
            if (archive) ClearDirectory(importStagingRoot);
            Directory.CreateDirectory(root);

            var destination = CreateUniqueDestination(root, MakeSafeFileName(name));
            File.Copy(sourcePath, destination);

            // Without open-in-place iOS drops a copy in Documents/Inbox that
            // nothing else ever cleans up.
            if (sourcePath.Contains("/Documents/Inbox/", StringComparison.Ordinal))
                TryDelete(sourcePath);

            return destination;
        }
        catch (Exception exception)
        {
            IOSLaunchLog.WriteException("incoming file", exception);
            return Reject(exception.Message);
        }
        finally
        {
            if (scoped) url.StopAccessingSecurityScopedResource();
        }
    }

    /// <summary>
    /// Presents a document picker and completes with what the user chose, or
    /// null if they dismissed it.
    /// </summary>
    internal static Task<NSUrl[]?> PresentPickerAsync(
        Func<UIDocumentPickerViewController> create,
        CancellationToken cancellationToken)
    {
        var completion = new TaskCompletionSource<NSUrl[]?>(
            TaskCreationOptions.RunContinuationsAsynchronously);

        void Present()
        {
            try
            {
                var presenter = IOSViewControllers.TryFindPresenter();
                if (presenter == null)
                {
                    completion.TrySetException(new InvalidOperationException(
                        "iOS 界面尚未就绪，无法打开文件选择器。"));
                    return;
                }

                var picker = create();
                picker.AllowsMultipleSelection = false;
                picker.DidPickDocumentAtUrls += (_, args) =>
                    completion.TrySetResult(args.Urls);
                picker.WasCancelled += (_, _) => completion.TrySetResult(null);
                presenter.PresentViewController(picker, animated: true, completionHandler: null);
            }
            catch (Exception exception)
            {
                completion.TrySetException(exception);
            }
        }

        if (Dispatcher.UIThread.CheckAccess()) Present();
        else Dispatcher.UIThread.Post(Present);

        // Dismissing the picker from here would race the user's own tap, so
        // cancellation only abandons the wait; the picker closes itself.
        return completion.Task.WaitAsync(cancellationToken);
    }

    internal static string MakeSafeFileName(string name)
    {
        var invalid = Path.GetInvalidFileNameChars();
        var safe = new string(name
            .Select(character => invalid.Contains(character) ? '_' : character)
            .ToArray());
        return string.IsNullOrWhiteSpace(safe) ? "imported-chart.mc" : safe;
    }

    private static string CreateUniqueDestination(string root, string fileName)
    {
        var destination = Path.Combine(root, fileName);
        if (!File.Exists(destination)) return destination;
        var stem = Path.GetFileNameWithoutExtension(fileName);
        var extension = Path.GetExtension(fileName);
        for (var suffix = 2; suffix < 10_000; suffix++)
        {
            destination = Path.Combine(root, $"{stem} ({suffix}){extension}");
            if (!File.Exists(destination)) return destination;
        }

        throw new IOException("曲库中同名导入文件过多。");
    }

    private static void ClearDirectory(string path)
    {
        try
        {
            if (Directory.Exists(path)) Directory.Delete(path, recursive: true);
        }
        catch (Exception exception) when (
            exception is IOException or UnauthorizedAccessException)
        {
            // Stale staged bytes cost cache space but must never block a
            // transfer; the next attempt tries again.
        }
    }

    private static void TryDelete(string path)
    {
        try
        {
            if (File.Exists(path)) File.Delete(path);
        }
        catch (Exception exception) when (
            exception is IOException or UnauthorizedAccessException)
        {
            // iOS reclaims the inbox copy on its own schedule.
        }
    }

    private static bool IsSupportedChartExtension(string extension) =>
        extension.Equals(".mc", StringComparison.OrdinalIgnoreCase) ||
        extension.Equals(".osu", StringComparison.OrdinalIgnoreCase) ||
        IsArchiveExtension(extension);

    private static bool IsArchiveExtension(string extension) =>
        extension.Equals(".mcz", StringComparison.OrdinalIgnoreCase) ||
        extension.Equals(".osz", StringComparison.OrdinalIgnoreCase);

    /// <summary>
    /// Holds the staged export and hands it to the system once it exists.
    /// </summary>
    private sealed class IOSExportDestination(string stagingPath) : IPlatformExportDestination
    {
        private string displayName = "文件";

        public string StagingPath { get; } = stagingPath;

        /// <summary>
        /// Only meaningful after <see cref="CommitAsync"/>, which is the only
        /// time the destination is known — and is also the only time the caller
        /// reads it, to name the location in the success notice.
        /// </summary>
        public string DisplayName => displayName;

        public async Task CommitAsync(CancellationToken cancellationToken = default)
        {
            if (!File.Exists(StagingPath))
                throw new FileNotFoundException("导出内容未生成。", StagingPath);

            var url = NSUrl.FromFilename(StagingPath);
            var picked = await PresentPickerAsync(
                () => new UIDocumentPickerViewController([url], asCopy: true),
                cancellationToken).ConfigureAwait(false);

            // Dismissing the picker is a cancelled export, not a failed one; the
            // shared caller turns OperationCanceledException into "导出已取消"
            // and anything else into an error dialog.
            if (picked is not { Length: > 0 })
                throw new OperationCanceledException("导出已取消。");

            var chosen = picked[0].LastPathComponent;
            if (!string.IsNullOrWhiteSpace(chosen)) displayName = chosen;
        }

        public ValueTask DisposeAsync()
        {
            TryDelete(StagingPath);
            return ValueTask.CompletedTask;
        }
    }
}
