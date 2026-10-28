using Android.Content;
using LumaChart.Storage;

namespace LumaChart.Android.Platform;

/// <summary>
/// Android-owned app-private roots. Durable user charts and editing state use
/// external app-private storage; settings and process scratch remain internal.
///
/// External app-private storage is removed with the app, like internal storage.
/// The manifest's <c>hasFragileUserData</c> makes Android 10+ offer to keep it
/// on uninstall, which is the only protection the charts in it have.
/// </summary>
internal sealed class AndroidAppStorageLocations : IAppStorageLocations, IAppLibraryStorageLocation
{
    private const string LogTag = "LumaChart";
    private const string SessionPrefix = "session_";

    public AndroidAppStorageLocations(Context context)
    {
        ArgumentNullException.ThrowIfNull(context);
        var applicationContext = context.ApplicationContext ?? context;
        var internalFiles = applicationContext.FilesDir?.AbsolutePath
            ?? throw new InvalidOperationException("Android app-private internal files root is unavailable.");
        var internalCache = applicationContext.CacheDir?.AbsolutePath
            ?? throw new InvalidOperationException("Android app-private internal cache root is unavailable.");
        // Both external roots are null while shared storage is unavailable —
        // being mounted or checked, or removed on a device whose primary storage
        // is removable. That used to throw here, inside the Application
        // constructor, so the app could not start at all until storage came
        // back. The internal roots always exist; the library opens from there
        // for this launch and the external one is used again once it returns.
        var externalFiles = ResolveExternalRoot(
            () => applicationContext.GetExternalFilesDir(null)?.AbsolutePath,
            internalFiles,
            "files");
        var externalCache = ResolveExternalRoot(
            () => applicationContext.ExternalCacheDir?.AbsolutePath,
            internalCache,
            "cache");

        Library = Path.GetFullPath(Path.Combine(externalFiles, "Library"));
        Settings = Path.GetFullPath(Path.Combine(internalFiles, "settings"));
        PersistentEditing = Path.GetFullPath(Path.Combine(externalFiles, "_editing"));
        ResourceCache = Path.GetFullPath(Path.Combine(externalCache, "_resources"));
        SessionScratch = Path.GetFullPath(Path.Combine(
            internalCache,
            "_scratch",
            $"session_{Environment.ProcessId}"));

        Directory.CreateDirectory(Library);
        Directory.CreateDirectory(Settings);
        Directory.CreateDirectory(PersistentEditing);
        Directory.CreateDirectory(ResourceCache);
        Directory.CreateDirectory(SessionScratch);
    }

    public string Library { get; }
    public string Settings { get; }
    public string PersistentEditing { get; }
    public string ResourceCache { get; }
    public string SessionScratch { get; }

    /// <summary>
    /// Deletes the scratch trees earlier processes left behind. Android ends an
    /// app by killing its process, so the per-session tree is never removed on
    /// the way out and one accumulated per launch. Only one process of this app
    /// runs at a time, so at startup every other <c>session_*</c> sibling is
    /// dead. Runs on a worker thread because a leftover export can be large.
    /// </summary>
    public void PruneEarlierSessionScratchInBackground()
    {
        var sessionRoot = SessionScratch;
        _ = Task.Run(() => PruneEarlierSessionScratch(sessionRoot));
    }

    private static void PruneEarlierSessionScratch(string sessionRoot)
    {
        try
        {
            var scratchRoot = Path.GetDirectoryName(sessionRoot);
            // The same shape check the desktop cleanup makes before deleting.
            if (scratchRoot == null ||
                !Path.GetFileName(scratchRoot).Equals("_scratch", StringComparison.Ordinal) ||
                !Directory.Exists(scratchRoot))
                return;

            var current = Path.GetFileName(sessionRoot);
            foreach (var directory in new DirectoryInfo(scratchRoot).EnumerateDirectories(SessionPrefix + "*"))
            {
                // A link is never followed out of the scratch tree.
                if (directory.Name.Equals(current, StringComparison.Ordinal) ||
                    directory.Attributes.HasFlag(FileAttributes.ReparsePoint))
                    continue;
                try
                {
                    directory.Delete(recursive: true);
                }
                catch (Exception exception) when (
                    exception is IOException or UnauthorizedAccessException)
                {
                    // Left for the next launch; scratch space is not worth a failure.
                }
            }
        }
        catch (Exception exception)
        {
            global::Android.Util.Log.Warn(LogTag, $"Session scratch cleanup skipped: {exception.Message}");
        }
    }

    private static string ResolveExternalRoot(Func<string?> resolve, string fallback, string kind)
    {
        try
        {
            var path = resolve();
            if (!string.IsNullOrWhiteSpace(path)) return path;
        }
        catch (Exception exception)
        {
            global::Android.Util.Log.Warn(LogTag, $"External {kind} root lookup failed: {exception.Message}");
        }

        global::Android.Util.Log.Warn(
            LogTag,
            $"External app-private {kind} root is unavailable; using internal storage for this launch.");
        return fallback;
    }
}
