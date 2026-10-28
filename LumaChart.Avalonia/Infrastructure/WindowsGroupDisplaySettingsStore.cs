using System.Text.Json;
using LumaChart.Avalonia.Rendering;

namespace LumaChart.Avalonia.Infrastructure;

/// <summary>
/// How the editor draws group membership. These are display preferences, not
/// chart data: the same chart opened on another machine keeps its groups and
/// loses only the local view choices.
/// </summary>
public sealed class WindowsGroupDisplaySettings
{
    public static WindowsGroupDisplaySettings Default { get; } = new();

    public WindowsGroupColorMode ColorMode { get; init; } = WindowsGroupColorMode.Leaf;

    public bool ShowGroupNumbers { get; init; }

    public bool ShowAnnotations { get; init; } = true;

    public bool AnnotationsDockRight { get; init; } = true;

    /// <summary>
    /// Show the parent-group column and the "+子" button, i.e. the group tree.
    /// Off by default: nesting is a real feature but a rare one, and a flat
    /// list of groups is what a mapper almost always wants to see.
    /// </summary>
    public bool ShowSubGroups { get; init; }

    public WindowsGroupDisplaySettings Normalize() => new()
    {
        ColorMode = Enum.IsDefined(ColorMode) ? ColorMode : WindowsGroupColorMode.Leaf,
        ShowGroupNumbers = ShowGroupNumbers,
        ShowAnnotations = ShowAnnotations,
        AnnotationsDockRight = AnnotationsDockRight,
        ShowSubGroups = ShowSubGroups
    };
}

/// <summary>
/// Atomic Avalonia-only persistence for <see cref="WindowsGroupDisplaySettings"/>.
/// Kept out of <see cref="WindowsEditorViewSettings"/> deliberately: that type is
/// a positional record with a carried-through accessor per field, and none of
/// these values belong to its geometry contract.
/// </summary>
public static class WindowsGroupDisplaySettingsStore
{
    public const int CurrentSchemaVersion = 1;
    private const string FileName = "group-display-settings.json";

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = true
    };

    public static string SettingsPath => Path.Combine(AvaloniaAppPaths.LocalDataRoot, FileName);

    public static WindowsGroupDisplaySettings Load()
    {
        string? path = null;
        try
        {
            path = SettingsPath;
            if (!WindowsSettingsFileGuard.TryReadExisting(path, out var bytes))
                return WindowsGroupDisplaySettings.Default;
            var persisted = JsonSerializer.Deserialize<PersistedSettings>(bytes, JsonOptions);
            return persisted?.SchemaVersion == CurrentSchemaVersion
                ? new WindowsGroupDisplaySettings
                {
                    ColorMode = persisted.ColorMode,
                    ShowGroupNumbers = persisted.ShowGroupNumbers,
                    ShowAnnotations = persisted.ShowAnnotations,
                    AnnotationsDockRight = persisted.AnnotationsDockRight,
                    ShowSubGroups = persisted.ShowSubGroups
                }.Normalize()
                : WindowsGroupDisplaySettings.Default;
        }
        catch (Exception exception)
        {
            if (path != null) WindowsSettingsFileGuard.ReportLoadFailure(path, exception);
            return WindowsGroupDisplaySettings.Default;
        }
    }

    public static void Save(WindowsGroupDisplaySettings settings)
    {
        ArgumentNullException.ThrowIfNull(settings);
        var normalized = settings.Normalize();
        var root = AvaloniaAppPaths.LocalDataRoot;
        var destination = Path.Combine(root, FileName);
        if (!WindowsSettingsFileGuard.CanWrite(destination)) return;
        Directory.CreateDirectory(root);
        var temporary = Path.Combine(root, $".{FileName}.{Guid.NewGuid():N}.tmp");
        try
        {
            var bytes = JsonSerializer.SerializeToUtf8Bytes(
                new PersistedSettings
                {
                    SchemaVersion = CurrentSchemaVersion,
                    ColorMode = normalized.ColorMode,
                    ShowGroupNumbers = normalized.ShowGroupNumbers,
                    ShowAnnotations = normalized.ShowAnnotations,
                    AnnotationsDockRight = normalized.AnnotationsDockRight,
                    ShowSubGroups = normalized.ShowSubGroups
                },
                JsonOptions);
            using (var output = new FileStream(
                       temporary,
                       FileMode.CreateNew,
                       FileAccess.Write,
                       FileShare.None,
                       16 * 1024,
                       FileOptions.WriteThrough))
            {
                output.Write(bytes);
                output.Flush(flushToDisk: true);
            }

            if (File.Exists(destination))
                File.Replace(
                    temporary,
                    destination,
                    destinationBackupFileName: null,
                    ignoreMetadataErrors: true);
            else
                File.Move(temporary, destination);
        }
        finally
        {
            try
            {
                if (File.Exists(temporary)) File.Delete(temporary);
            }
            catch
            {
                // Preserve the primary settings-write failure.
            }
        }
    }

    private sealed class PersistedSettings
    {
        public int SchemaVersion { get; set; }
        public WindowsGroupColorMode ColorMode { get; set; } = WindowsGroupColorMode.Leaf;
        public bool ShowGroupNumbers { get; set; }
        public bool ShowAnnotations { get; set; } = true;
        public bool AnnotationsDockRight { get; set; } = true;
        public bool ShowSubGroups { get; set; }
    }
}
