using LumaChart.Storage;

namespace LumaChart.iOS.Platform;

/// <summary>
/// iOS sandbox roots. The chart library lives under <c>Documents</c> so the
/// Files app can reach it — that is how charts and audio get in and out of an
/// iOS sandbox at all, and it is the closest equivalent to the app-private
/// external directory Android uses. Settings and editing state stay in
/// <c>Library/Application Support</c>, which is durable but not user-visible,
/// and disposable data goes to <c>Library/Caches</c> and <c>tmp</c> so the
/// system can reclaim it under storage pressure.
/// </summary>
internal sealed class IOSAppStorageLocations : IAppStorageLocations, IAppLibraryStorageLocation
{
    public IOSAppStorageLocations()
    {
        // Resolved through NSFileManager rather than Environment.SpecialFolder:
        // the latter is a Unix-shaped abstraction over HOME, while the sandbox
        // layout is whatever iOS reports.
        var documents = IOSSandboxPaths.Documents;
        var applicationSupport = Path.Combine(IOSSandboxPaths.Library, "Application Support");
        var caches = IOSSandboxPaths.Caches;
        var temporary = IOSSandboxPaths.Temporary;

        Library = Path.GetFullPath(Path.Combine(documents, "Library"));
        Settings = Path.GetFullPath(Path.Combine(applicationSupport, "settings"));
        PersistentEditing = Path.GetFullPath(Path.Combine(applicationSupport, "_editing"));
        ResourceCache = Path.GetFullPath(Path.Combine(caches, "_resources"));
        SessionScratch = Path.GetFullPath(Path.Combine(
            temporary,
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
    /// Deletes the scratch trees earlier processes left behind. iOS ends an app
    /// by suspending and then killing it, so the per-session tree is never
    /// removed on the way out and one accumulated per launch — iOS purges
    /// <c>tmp</c> only when it decides to. The app is the only process in its
    /// sandbox, so at startup every other <c>session_*</c> sibling is dead. Runs
    /// on a worker thread because a leftover export can be large.
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
            foreach (var directory in new DirectoryInfo(scratchRoot).EnumerateDirectories("session_*"))
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
            IOSLaunchLog.Write($"session scratch cleanup skipped: {exception.GetType().Name}");
        }
    }
}
