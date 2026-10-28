using Foundation;

namespace LumaChart.iOS.Platform;

/// <summary>
/// Locates the IpaDic corpus used for Japanese romanization.
///
/// Android has to extract it from the APK because assets there are not real
/// files. iOS bundle resources already are files inside the read-only app
/// bundle, and Kawazu only reads them, so nothing is copied out.
/// </summary>
internal static class IOSDictionaryAssets
{
    private const string BundleFolder = "IpaDic";
    private static readonly (string Name, long Length)[] RequiredFiles =
    [
        ("char.bin", 262_496),
        ("matrix.bin", 3_463_716),
        ("sys.dic", 49_205_956),
        ("unk.dic", 5_690)
    ];

    /// <summary>
    /// Returns the bundled dictionary directory, or null when it is incomplete.
    /// Null leaves romanization unavailable, which is far better than handing
    /// the tokenizer a truncated corpus.
    /// </summary>
    public static string? Locate()
    {
        try
        {
            var root = Path.Combine(NSBundle.MainBundle.BundlePath, BundleFolder);
            if (!Directory.Exists(root)) return null;

            foreach (var (name, expectedLength) in RequiredFiles)
            {
                var file = new FileInfo(Path.Combine(root, name));
                if (!file.Exists || file.Length != expectedLength) return null;
            }

            return root;
        }
        catch (Exception)
        {
            return null;
        }
    }
}
