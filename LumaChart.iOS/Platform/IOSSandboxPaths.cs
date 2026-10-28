using Foundation;

namespace LumaChart.iOS.Platform;

/// <summary>
/// Resolves the iOS sandbox roots through the platform's own search-path API.
///
/// <c>Environment.GetFolderPath</c> is a Unix-shaped abstraction that depends on
/// <c>HOME</c> being set the way desktop Unix sets it; on iOS the sandbox layout
/// is what <c>NSFileManager</c> reports, and asking it directly cannot silently
/// return an empty path.
/// </summary>
internal static class IOSSandboxPaths
{
    public static string Documents => Resolve(NSSearchPathDirectory.DocumentDirectory);

    public static string Library => Resolve(NSSearchPathDirectory.LibraryDirectory);

    public static string Caches => Resolve(NSSearchPathDirectory.CachesDirectory);

    /// <summary>
    /// iOS points TMPDIR at the sandbox's own tmp directory, so this is the
    /// sandbox path rather than a shared system location. There is no
    /// NSSearchPathDirectory value for it.
    /// </summary>
    public static string Temporary => Path.TrimEndingDirectorySeparator(Path.GetTempPath());

    private static string Resolve(NSSearchPathDirectory directory)
    {
        var urls = NSFileManager.DefaultManager.GetUrls(directory, NSSearchPathDomain.User);
        var path = urls is { Length: > 0 } ? urls[0].Path : null;
        if (string.IsNullOrWhiteSpace(path))
            throw new InvalidOperationException($"The iOS sandbox directory {directory} is unavailable.");
        return path;
    }
}
