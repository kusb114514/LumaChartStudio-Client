namespace LumaChart.Avalonia.Infrastructure;

/// <summary>
/// The console front end needs exactly one thing from the editor's path helper:
/// the root the per-chart metadata store is keyed under. Linking the real
/// <c>AvaloniaAppPaths</c> would drag its single-instance policy and per-user
/// storage registrations into a build that has no window at all, so this
/// re-derives the same root from the same environment override the editor
/// honours.
///
/// This must stay in step with <c>AvaloniaAppPaths.CreateDefaultLocations</c>
/// (and its <c>LocalDataOverride</c> constant). If the two ever disagree the
/// CLI would silently read and write a different catalog than the editor, which
/// is the one failure mode that would look like "the tool did nothing".
/// </summary>
internal static class AvaloniaAppPaths
{
    private const string LocalDataOverride = "LUMACHART_AVALONIA_LOCAL_DATA_ROOT";

    public static string LocalDataRoot { get; } = ResolveLocalDataRoot();

    private static string ResolveLocalDataRoot()
    {
        var overridden = Environment.GetEnvironmentVariable(LocalDataOverride);
        if (!string.IsNullOrWhiteSpace(overridden)) return Path.GetFullPath(overridden.Trim());
        return Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "LumaChart Studio",
            "Avalonia");
    }
}
