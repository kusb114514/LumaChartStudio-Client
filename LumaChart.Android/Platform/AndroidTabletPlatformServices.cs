using Android.App;
using Android.Content;
using Android.Database;
using Android.Provider;
using Android.OS;
using LumaChart.Android.Platform;
using LumaChart.Avalonia.Services;
using LumaChart.Core.Localization;

namespace LumaChart.Android;

public sealed class AndroidTabletPlatformServices :
    IPlatformFileImportService,
    IPlatformFileExportService,
    IPlatformExternalUriService,
    IPlatformTextInputService
{
    public static AndroidTabletPlatformServices? Current { get; set; }
    private const int PickChartRequest = 6041;
    private const int CreateExportRequest = 6042;
    private static readonly object ActivityGate = new();
    private static MainActivity? currentActivity;
    // Keyed by request code so an import and an export can never consume each
    // other's result.
    private static readonly Dictionary<int, TaskCompletionSource<Intent?>> PendingPickers = [];

    private readonly Context context;

    internal AndroidTabletPlatformServices(Context context, AndroidAppStorageLocations locations)
    {
        this.context = context.ApplicationContext ?? context;
        ArgumentNullException.ThrowIfNull(locations);
        LibraryRoot = locations.Library;
        EditingRoot = locations.PersistentEditing;
        CacheRoot = locations.ResourceCache;
        ImportStagingRoot = Path.Combine(CacheRoot, "_import");
        ExportStagingRoot = Path.Combine(CacheRoot, "_export");
    }

    public string LibraryRoot { get; }
    public string EditingRoot { get; }
    public string CacheRoot { get; }
    private string ImportStagingRoot { get; }
    private string ExportStagingRoot { get; }
    public bool EnablePasswordInputMethod => true;
    public bool SupportsWorkspaceDirectorySelection => false;

    /// <summary>
    /// Scoped storage gives no writable path for a created document, so a tab
    /// cannot stay bound to a SAF destination. Save As therefore writes inside
    /// the app-private library, where the chart keeps its audio and images and
    /// stays indexed; reaching storage outside the sandbox remains Export's job.
    /// </summary>
    public string? InAppSaveAsRoot => LibraryRoot;

    /// <summary>
    /// The activity notices and pickers attach to, or null between destroy and
    /// the next create.
    /// </summary>
    internal static MainActivity? CurrentActivity
    {
        get { lock (ActivityGate) return currentActivity; }
    }

    public static void AttachActivity(MainActivity activity)
    {
        lock (ActivityGate) currentActivity = activity;
    }

    public static void DetachActivity(MainActivity activity)
    {
        lock (ActivityGate)
        {
            if (ReferenceEquals(currentActivity, activity)) currentActivity = null;
            foreach (var pending in PendingPickers.Values) pending.TrySetCanceled();
            PendingPickers.Clear();
        }
    }

    /// <summary>
    /// Launches a document picker and awaits its result through the activity's
    /// own result callback. Returns null — the same answer as the user backing
    /// out — whenever no picker result can be had.
    ///
    /// None of those cases throws any more. The editor awaits the picker from
    /// <c>async void</c> button handlers, where an exception ends the process:
    /// a second tap on Open while the picker was up, and the activity being
    /// recreated underneath it, both closed the app.
    /// </summary>
    private static async Task<Intent?> RunPickerAsync(
        Func<Intent> createIntent,
        int requestCode,
        CancellationToken cancellationToken)
    {
        MainActivity activity;
        TaskCompletionSource<Intent?> completion;
        lock (ActivityGate)
        {
            // Between destroy and the next create there is nothing to launch
            // the picker from.
            if (currentActivity == null) return null;
            // A repeated tap. The picker already on screen delivers the file to
            // the request that opened it; this one steps aside.
            if (PendingPickers.ContainsKey(requestCode)) return null;
            activity = currentActivity;
            completion = new TaskCompletionSource<Intent?>(
                TaskCreationOptions.RunContinuationsAsynchronously);
            PendingPickers[requestCode] = completion;
        }

        using var registration = cancellationToken.Register(
            () => completion.TrySetCanceled(cancellationToken));
        try
        {
            // Inside the try, so a launch that throws still releases the request
            // code instead of leaving every later pick looking "already open".
            using var intent = createIntent();
            activity.StartActivityForResult(intent, requestCode);
            return await completion.Task.ConfigureAwait(false);
        }
        catch (System.OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            // DetachActivity cancelled it: the activity went away with the
            // picker still up, so its result has nowhere to arrive.
            return null;
        }
        finally
        {
            lock (ActivityGate)
            {
                if (PendingPickers.TryGetValue(requestCode, out var pending) &&
                    ReferenceEquals(pending, completion))
                    PendingPickers.Remove(requestCode);
            }
        }
    }

    public async Task<string?> PickChartFileAsync(CancellationToken cancellationToken = default)
    {
        var result = await RunPickerAsync(
            () =>
            {
                var intent = new Intent(Intent.ActionOpenDocument);
                intent.AddCategory(Intent.CategoryOpenable);
                intent.SetType("*/*");
                return intent;
            },
            PickChartRequest,
            cancellationToken).ConfigureAwait(false);

        if (result?.Data is not global::Android.Net.Uri uri) return null;
        var name = ReadDisplayName(uri);
        var extension = Path.GetExtension(name);
        if (!IsSupportedChartExtension(extension))
        {
            // Told to the user and answered as "nothing picked". Thrown, this
            // ended the app: the caller awaits it from an async void handler.
            PlatformNoticeServices.Current?.Show(
                LocalizationCatalog.Text("打开谱面"),
                LocalizationCatalog.Text("请选择 .mc、.mcz、.osu 或 .osz 谱面文件。"),
                PlatformNoticeSeverity.Warning);
            return null;
        }
        // A picked .mc/.osu becomes the library item itself, so it is copied
        // straight into the library. An archive is only the input to the shared
        // import, which unpacks it into its own library folder; keeping the
        // archive in the library would leave a dead copy beside every import,
        // so it is staged in the resource cache the way the desktop client
        // leaves the archive outside the library.
        var archive = IsArchiveExtension(extension);
        var root = archive ? ImportStagingRoot : LibraryRoot;
        if (archive) ClearImportStaging();
        Directory.CreateDirectory(root);
        var destination = CreateUniqueDestination(root, MakeSafeFileName(name));
        await using var source = context.ContentResolver?.OpenInputStream(uri)
            ?? throw new IOException("Unable to open the selected chart.");
        await using var target = new FileStream(
            destination,
            FileMode.CreateNew,
            FileAccess.Write,
            FileShare.None);
        await source.CopyToAsync(target, cancellationToken).ConfigureAwait(false);
        return destination;
    }

    public Task OpenExternalUriAsync(
        Uri uri,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(uri);
        cancellationToken.ThrowIfCancellationRequested();

        MainActivity activity;
        lock (ActivityGate)
        {
            activity = currentActivity
                ?? throw new InvalidOperationException("The Android activity is not ready.");
        }

        var completion = new TaskCompletionSource(
            TaskCreationOptions.RunContinuationsAsynchronously);
        activity.RunOnUiThread(() =>
        {
            if (cancellationToken.IsCancellationRequested)
            {
                completion.TrySetCanceled(cancellationToken);
                return;
            }

            try
            {
                using var intent = new Intent(
                    Intent.ActionView,
                    global::Android.Net.Uri.Parse(uri.AbsoluteUri));
                intent.AddCategory(Intent.CategoryBrowsable);
                activity.StartActivity(intent);
                completion.TrySetResult();
            }
            catch (ActivityNotFoundException exception)
            {
                completion.TrySetException(new InvalidOperationException(
                    "No Android browser can handle this link.",
                    exception));
            }
            catch (Exception exception)
            {
                completion.TrySetException(exception);
            }
        });
        return completion.Task;
    }

    public static bool TryCompletePicker(int requestCode, Result resultCode, Intent? data)
    {
        lock (ActivityGate)
        {
            if (!PendingPickers.TryGetValue(requestCode, out var pending)) return false;
            pending.TrySetResult(resultCode == Result.Ok ? data : null);
        }
        return true;
    }

    /// <summary>
    /// Creates the document the user picks and hands back a cache path for the
    /// shared export pipeline to write. Scoped storage gives no writable
    /// filesystem path for a chosen document, so the bytes are staged first and
    /// copied into the document on commit.
    /// </summary>
    public async Task<IPlatformExportDestination?> PickExportDestinationAsync(
        string suggestedFileName,
        string extension,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(suggestedFileName);
        var result = await RunPickerAsync(
            () =>
            {
                var intent = new Intent(Intent.ActionCreateDocument);
                intent.AddCategory(Intent.CategoryOpenable);
                // A concrete type makes the picker append its own extension to
                // the title, which is already complete; the generic stream type
                // leaves the name exactly as offered.
                intent.SetType("application/octet-stream");
                intent.PutExtra(Intent.ExtraTitle, MakeSafeFileName(suggestedFileName));
                return intent;
            },
            CreateExportRequest,
            cancellationToken).ConfigureAwait(false);

        if (result?.Data is not global::Android.Net.Uri uri) return null;

        ClearExportStaging();
        Directory.CreateDirectory(ExportStagingRoot);
        var stagingPath = Path.Combine(
            ExportStagingRoot,
            MakeSafeFileName(Path.GetFileName(suggestedFileName)));
        _ = extension;
        return new AndroidExportDestination(
            context,
            uri,
            stagingPath,
            ReadDisplayName(uri));
    }

    private void ClearExportStaging()
    {
        try
        {
            if (Directory.Exists(ExportStagingRoot))
                Directory.Delete(ExportStagingRoot, recursive: true);
        }
        catch (Exception exception) when (
            exception is IOException or UnauthorizedAccessException)
        {
            // Leftover staged bytes cost cache space but must not block export.
        }
    }

    private sealed class AndroidExportDestination(
        Context context,
        global::Android.Net.Uri target,
        string stagingPath,
        string displayName) : IPlatformExportDestination
    {
        public string StagingPath { get; } = stagingPath;
        public string DisplayName { get; } = displayName;

        public async Task CommitAsync(CancellationToken cancellationToken = default)
        {
            if (!File.Exists(StagingPath))
                throw new FileNotFoundException("导出内容未生成。", StagingPath);
            await using var source = new FileStream(
                StagingPath,
                FileMode.Open,
                FileAccess.Read,
                FileShare.Read);
            // "wt" truncates, so replacing a shorter file cannot leave a tail of
            // the previous contents behind.
            await using var output = context.ContentResolver?.OpenOutputStream(target, "wt")
                ?? throw new IOException("无法写入所选导出位置。");
            await source.CopyToAsync(output, cancellationToken).ConfigureAwait(false);
            await output.FlushAsync(cancellationToken).ConfigureAwait(false);
        }

        public ValueTask DisposeAsync()
        {
            try
            {
                if (File.Exists(StagingPath)) File.Delete(StagingPath);
            }
            catch (Exception exception) when (
                exception is IOException or UnauthorizedAccessException)
            {
                // The next export clears the staging directory anyway.
            }

            return ValueTask.CompletedTask;
        }
    }

    private string ReadDisplayName(global::Android.Net.Uri uri)
    {
        using ICursor? cursor = context.ContentResolver?.Query(
            uri,
            new[] { global::Android.Provider.IOpenableColumns.DisplayName },
            null,
            null,
            null);
        if (cursor?.MoveToFirst() == true)
        {
            var index = cursor.GetColumnIndex(global::Android.Provider.IOpenableColumns.DisplayName);
            if (index >= 0 && !string.IsNullOrWhiteSpace(cursor.GetString(index)))
                return cursor.GetString(index)!;
        }
        return "imported-chart.mc";
    }

    private static string MakeSafeFileName(string name)
    {
        var invalid = Path.GetInvalidFileNameChars();
        var safe = new string(name.Select(character => invalid.Contains(character) ? '_' : character).ToArray());
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

    /// <summary>
    /// Drops the previous staged archive. The shared import has already
    /// unpacked it into the library by the time the next pick starts, so
    /// nothing here has to survive across picks.
    /// </summary>
    private void ClearImportStaging()
    {
        try
        {
            if (Directory.Exists(ImportStagingRoot))
                Directory.Delete(ImportStagingRoot, recursive: true);
        }
        catch (Exception exception) when (
            exception is IOException or UnauthorizedAccessException)
        {
            // A stale staged archive costs cache space but must never block an
            // import; the next pick tries again.
        }
    }

    private static bool IsSupportedChartExtension(string extension) =>
        extension.Equals(".mc", StringComparison.OrdinalIgnoreCase) ||
        extension.Equals(".osu", StringComparison.OrdinalIgnoreCase) ||
        IsArchiveExtension(extension);

    private static bool IsArchiveExtension(string extension) =>
        extension.Equals(".mcz", StringComparison.OrdinalIgnoreCase) ||
        extension.Equals(".osz", StringComparison.OrdinalIgnoreCase);
}
