using Android.Content;
using LumaChart.Avalonia.Services;

namespace LumaChart.Android.Platform;

internal static class AndroidDictionaryAssets
{
    private const string AssetRoot = "IpaDic";
    private static readonly (string Name, long Length)[] RequiredFiles =
    [
        ("char.bin", 262_496),
        ("matrix.bin", 3_463_716),
        ("sys.dic", 49_205_956),
        ("unk.dic", 5_690)
    ];

    /// <summary>
    /// Sets <see cref="PlatformJapaneseRomanizationServices.DictionaryRoot"/>
    /// once the corpus is on disk, without holding up startup.
    ///
    /// A corpus already extracted by an earlier launch — every launch but the
    /// first after an install or update — is published immediately, since that
    /// costs four file lookups. Otherwise the copy runs on a worker thread. If
    /// it fails the root stays null, which leaves romanization unavailable (the
    /// metadata editor reports that and offers manual entry) rather than
    /// handing the tokenizer a truncated corpus, the way the iOS host treats a
    /// bundle it cannot verify.
    ///
    /// The romanizer resolves the root once, on first use, and does not retry;
    /// a first use during a first-launch extraction therefore stays unavailable
    /// until the next launch.
    /// </summary>
    public static void PublishWhenReady(Context context, string resourceCacheRoot)
    {
        ArgumentNullException.ThrowIfNull(context);
        var applicationContext = context.ApplicationContext ?? context;
        try
        {
            var destinationRoot = Path.Combine(resourceCacheRoot, AssetRoot);
            if (RequiredFiles.All(file => IsCurrent(Path.Combine(destinationRoot, file.Name), file.Length)))
            {
                PlatformJapaneseRomanizationServices.DictionaryRoot = destinationRoot;
                return;
            }
        }
        catch (Exception)
        {
            // Fall through to the full extraction, which reports its own failure.
        }

        _ = Task.Run(() =>
        {
            try
            {
                PlatformJapaneseRomanizationServices.DictionaryRoot =
                    EnsureExtracted(applicationContext, resourceCacheRoot);
            }
            catch (Exception exception)
            {
                global::Android.Util.Log.Warn(
                    "LumaChart",
                    $"Japanese romanization dictionary unavailable: {exception}");
            }
        });
    }

    public static string EnsureExtracted(Context context, string resourceCacheRoot)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentException.ThrowIfNullOrWhiteSpace(resourceCacheRoot);
        var destinationRoot = Path.Combine(resourceCacheRoot, AssetRoot);
        Directory.CreateDirectory(destinationRoot);

        foreach (var (fileName, expectedLength) in RequiredFiles)
        {
            var destination = Path.Combine(destinationRoot, fileName);
            if (IsCurrent(destination, expectedLength)) continue;
            var temporary = $"{destination}.{Guid.NewGuid():N}.tmp";
            try
            {
                using var source = OpenAsset(context, fileName);
                using (var target = new FileStream(
                           temporary,
                           FileMode.CreateNew,
                           FileAccess.Write,
                           FileShare.None))
                {
                    source.CopyTo(target);
                    target.Flush(flushToDisk: true);
                }
                File.Move(temporary, destination, true);
            }
            finally
            {
                try
                {
                    if (File.Exists(temporary)) File.Delete(temporary);
                }
                catch
                {
                    // Preserve the primary extraction failure.
                }
            }
        }
        return destinationRoot;
    }

    private static bool IsCurrent(string destination, long expectedLength) =>
        File.Exists(destination) && new FileInfo(destination).Length == expectedLength;

    private static Stream OpenAsset(Context context, string fileName) =>
        context.Assets?.Open($"{AssetRoot}/{fileName}")
        ?? throw new FileNotFoundException($"Android asset is missing: {AssetRoot}/{fileName}");
}
