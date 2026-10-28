using System.Text.Json;
using System.Text.Json.Serialization;
using LumaChart.Core.Models;

namespace LumaChart.Avalonia.Infrastructure;

/// <summary>
/// Per-chart editor metadata: group names and colours, the group tree, the
/// named group presets, and the annotation blocks.
///
/// It cannot live inside the chart file: Malody's .mc envelope is shared with
/// other tools and an osu! round-trip has nowhere to put it, so an editor-only
/// key would either be dropped or leak into someone else's parser. Instead each
/// chart's metadata is stored beside the client's other local settings and
/// keyed by the chart's own source path, which is the one identifier that
/// survives saving, undoing and reopening.
///
/// The note's integer group is still the only thing that travels with the
/// chart, so a chart whose metadata is missing still opens with the right
/// grouping and simply falls back to the built-in palette.
/// </summary>
public static class WindowsGroupCatalogStore
{
    /// <summary>
    /// 1 — groups only. 2 — adds group presets and annotations (and, added
    /// afterwards, annotation presets as an extra optional array on the same
    /// entry).
    ///
    /// The version is deliberately *not* bumped for annotation presets. Reading
    /// is additive — a file without <c>AnnotationPresets</c> simply has no
    /// annotation drawers — and a bump would make a stock client reject the
    /// whole entry, and because a rejected entry is replaced by an empty
    /// catalog on its next save, cost the mapper every group name on that
    /// chart. Leaving the version at 2 means an older client ignores the new
    /// array, keeps every annotation, and at worst drops the drawer filing.
    /// </summary>
    public const int CurrentSchemaVersion = 2;
    private const int MinimumReadableSchemaVersion = 1;
    private const string FileName = "chart-group-catalog.json";
    private const int MaximumEntries = 500;
    private const int RetentionDays = 365;

    private static readonly object Gate = new();
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = true,
        Converters = { new BeatPositionJsonConverter() }
    };

    private static Dictionary<string, PersistedEntry>? entries;

    public static string SettingsPath => Path.Combine(AvaloniaAppPaths.LocalDataRoot, FileName);

    /// <summary>
    /// Case-insensitive absolute source path. Returns empty for an unsaved chart,
    /// which means "keep this metadata in memory only".
    /// </summary>
    public static string KeyFor(string? sourcePath)
    {
        if (string.IsNullOrWhiteSpace(sourcePath)) return string.Empty;
        try
        {
            return Path.GetFullPath(sourcePath.Trim()).ToLowerInvariant();
        }
        catch (Exception exception) when (
            exception is ArgumentException or NotSupportedException or PathTooLongException)
        {
            return string.Empty;
        }
    }

    public static ChartGroupCatalog Load(string? sourcePath)
    {
        var key = KeyFor(sourcePath);
        if (key.Length == 0) return new ChartGroupCatalog();
        lock (Gate)
        {
            var loaded = ReadEntries();
            if (!loaded.TryGetValue(key, out var entry)) return new ChartGroupCatalog();
            var catalog = new ChartGroupCatalog();
            foreach (var group in entry.Groups)
            {
                if (group == null) continue;
                catalog.Ensure(group.Id).CopyFrom(group);
            }
            foreach (var preset in entry.Presets)
            {
                if (preset == null) continue;
                catalog.EnsurePreset(preset.Id).CopyFrom(preset);
            }
            catalog.ActivePresetId = entry.ActiveGroupPresetId;
            catalog.Normalize();
            return catalog;
        }
    }

    /// <summary>Annotation blocks for one chart. Empty for an unsaved chart.</summary>
    public static ChartAnnotationCatalog LoadAnnotations(string? sourcePath)
    {
        var key = KeyFor(sourcePath);
        if (key.Length == 0) return new ChartAnnotationCatalog();
        lock (Gate)
        {
            var loaded = ReadEntries();
            if (!loaded.TryGetValue(key, out var entry)) return new ChartAnnotationCatalog();
            var catalog = new ChartAnnotationCatalog();
            foreach (var annotation in entry.Annotations)
            {
                if (annotation == null) continue;
                catalog.Ensure(annotation.Id).CopyFrom(annotation);
            }
            foreach (var preset in entry.AnnotationPresets)
            {
                if (preset == null) continue;
                catalog.EnsurePreset(preset.Id).CopyFrom(preset);
            }
            catalog.ActivePresetId = entry.ActiveAnnotationPresetId;
            catalog.Normalize();
            return catalog;
        }
    }

    /// <summary>
    /// The per-group free text a schema-1 entry still carries.
    ///
    /// Schema 1 kept one note on the group itself; schema 2 moved the text onto
    /// blocks that pin it to a set of notes, so the old field has nowhere left
    /// to live and would be dropped by the next rewrite. Reading it back here is
    /// what lets that text survive the upgrade instead of vanishing the first
    /// time a group is renamed. Only a schema-1 file is read, because once the
    /// entry has been rewritten at 2 the blocks hold the text and minting it
    /// again would duplicate it on every launch.
    /// </summary>
    public static IReadOnlyList<(int GroupId, string Text)> LoadLegacyGroupAnnotations(
        string? sourcePath)
    {
        var key = KeyFor(sourcePath);
        if (key.Length == 0) return [];
        if (!WindowsSettingsFileGuard.TryReadExisting(SettingsPath, out var bytes)) return [];
        LegacyFile? file;
        try
        {
            file = JsonSerializer.Deserialize<LegacyFile>(bytes, JsonOptions);
        }
        catch (Exception exception) when (
            exception is JsonException or NotSupportedException)
        {
            return [];
        }

        if (file is not { SchemaVersion: 1 }) return [];
        var entry = file.Entries.FirstOrDefault(candidate =>
            candidate != null &&
            string.Equals(KeyFor(candidate.Path), key, StringComparison.Ordinal));
        if (entry == null) return [];

        var result = new List<(int, string)>();
        foreach (var group in entry.Groups)
        {
            if (group == null || group.Id <= 0 || !group.HasAnnotation) continue;
            var text = (group.Annotation ?? string.Empty).Trim();
            if (text.Length == 0) continue;
            if (text.Length > ChartAnnotationCatalog.MaximumTextLength)
                text = text[..ChartAnnotationCatalog.MaximumTextLength];
            result.Add((group.Id, text));
        }
        return result;
    }

    public static void Save(string? sourcePath, ChartGroupCatalog catalog) =>
        SaveCore(sourcePath, catalog, null);

    public static void SaveAnnotations(string? sourcePath, ChartAnnotationCatalog catalog) =>
        SaveCore(sourcePath, null, catalog);

    private static void SaveCore(
        string? sourcePath,
        ChartGroupCatalog? catalog,
        ChartAnnotationCatalog? annotations)
    {
        if (catalog == null && annotations == null) return;
        var key = KeyFor(sourcePath);
        if (key.Length == 0) return;
        lock (Gate)
        {
            var loaded = ReadEntries();
            loaded.TryGetValue(key, out var existing);
            var merged = new PersistedEntry
            {
                Path = key,
                UpdatedUtc = DateTime.UtcNow,
                Groups = catalog?.Groups.Select(group => group.Clone()).ToList()
                         ?? existing?.Groups ?? [],
                Presets = catalog?.Presets.Select(preset => preset.Clone()).ToList()
                          ?? existing?.Presets ?? [],
                ActiveGroupPresetId = catalog?.ActivePresetId ?? existing?.ActiveGroupPresetId,
                Annotations = annotations?.Annotations.Select(item => item.Clone()).ToList()
                              ?? existing?.Annotations ?? [],
                AnnotationPresets = annotations?.Presets.Select(preset => preset.Clone()).ToList()
                                    ?? existing?.AnnotationPresets ?? [],
                ActiveAnnotationPresetId = annotations?.ActivePresetId
                                           ?? existing?.ActiveAnnotationPresetId
            };

            // An entry exists only while it still says something. Saving a
            // half-empty state would otherwise leave a row behind forever for a
            // chart whose metadata was deliberately cleared.
            if (merged.Groups.Count == 0 &&
                merged.Presets.Count == 0 &&
                merged.Annotations.Count == 0 &&
                merged.AnnotationPresets.Count == 0)
            {
                if (!loaded.Remove(key)) return;
            }
            else
            {
                loaded[key] = merged;
            }

            Prune(loaded);
            WriteEntries(loaded);
        }
    }

    public static void Forget(string? sourcePath)
    {
        var key = KeyFor(sourcePath);
        if (key.Length == 0) return;
        lock (Gate)
        {
            var loaded = ReadEntries();
            if (!loaded.Remove(key)) return;
            WriteEntries(loaded);
        }
    }

    private static void Prune(Dictionary<string, PersistedEntry> loaded)
    {
        if (loaded.Count <= MaximumEntries) return;
        var expiry = DateTime.UtcNow.AddDays(-RetentionDays);
        foreach (var stale in loaded
                     .Where(pair => pair.Value.UpdatedUtc < expiry)
                     .OrderBy(pair => pair.Value.UpdatedUtc)
                     .Take(loaded.Count - MaximumEntries)
                     .Select(pair => pair.Key)
                     .ToArray())
            loaded.Remove(stale);
        foreach (var oldest in loaded
                     .OrderBy(pair => pair.Value.UpdatedUtc)
                     .Take(Math.Max(0, loaded.Count - MaximumEntries))
                     .Select(pair => pair.Key)
                     .ToArray())
            loaded.Remove(oldest);
    }

    private static Dictionary<string, PersistedEntry> ReadEntries()
    {
        if (entries != null) return entries;
        Dictionary<string, PersistedEntry> result = new(StringComparer.Ordinal);
        if (WindowsSettingsFileGuard.TryReadExisting(SettingsPath, out var bytes))
        {
            try
            {
                var persisted = JsonSerializer.Deserialize<PersistedFile>(bytes, JsonOptions);
                if (persisted is { } file &&
                    file.SchemaVersion >= MinimumReadableSchemaVersion &&
                    file.SchemaVersion <= CurrentSchemaVersion)
                {
                    foreach (var entry in file.Entries)
                    {
                        var key = KeyFor(entry.Path);
                        if (key.Length == 0) continue;
                        result[key] = entry;
                    }
                }
                else if (persisted != null)
                {
                    WindowsSettingsFileGuard.ReportLoadFailure(
                        SettingsPath,
                        new InvalidDataException(
                            $"Group catalog schema {persisted.SchemaVersion} is not in " +
                            $"[{MinimumReadableSchemaVersion}, {CurrentSchemaVersion}]."));
                }
            }
            catch (Exception exception)
            {
                WindowsSettingsFileGuard.ReportLoadFailure(SettingsPath, exception);
                result.Clear();
            }
        }
        entries = result;
        return entries;
    }

    private static void WriteEntries(Dictionary<string, PersistedEntry> loaded)
    {
        var root = AvaloniaAppPaths.LocalDataRoot;
        var destination = SettingsPath;
        if (!WindowsSettingsFileGuard.CanWrite(destination)) return;
        Directory.CreateDirectory(root);
        var temporary = Path.Combine(root, $".{FileName}.{Guid.NewGuid():N}.tmp");
        try
        {
            var bytes = JsonSerializer.SerializeToUtf8Bytes(
                new PersistedFile
                {
                    SchemaVersion = CurrentSchemaVersion,
                    Entries = loaded.Values
                        .OrderByDescending(entry => entry.UpdatedUtc)
                        .Select(entry => new PersistedEntry
                        {
                            Path = entry.Path,
                            UpdatedUtc = entry.UpdatedUtc,
                            Groups = entry.Groups
                                .Where(group => group != null)
                                .Select(group => group.Clone())
                                .ToList(),
                            Presets = entry.Presets
                                .Where(preset => preset != null)
                                .Select(preset => preset.Clone())
                                .ToList(),
                            ActiveGroupPresetId = entry.ActiveGroupPresetId,
                            Annotations = entry.Annotations
                                .Where(annotation => annotation != null)
                                .Select(annotation => annotation.Clone())
                                .ToList(),
                            AnnotationPresets = entry.AnnotationPresets
                                .Where(preset => preset != null)
                                .Select(preset => preset.Clone())
                                .ToList(),
                            ActiveAnnotationPresetId = entry.ActiveAnnotationPresetId
                        })
                        .ToList()
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
        catch (Exception exception)
        {
            WindowsSettingsFileGuard.ReportSaveFailure(SettingsPath, exception);
        }
        finally
        {
            try
            {
                if (File.Exists(temporary)) File.Delete(temporary);
            }
            catch
            {
                // Preserve the primary write failure.
            }
        }
    }

    private sealed class PersistedFile
    {
        public int SchemaVersion { get; set; }
        public List<PersistedEntry> Entries { get; set; } = [];
    }

    private sealed class PersistedEntry
    {
        public string Path { get; set; } = string.Empty;
        public DateTime UpdatedUtc { get; set; }
        public List<ChartGroupDefinition> Groups { get; set; } = [];
        public List<ChartGroupPreset> Presets { get; set; } = [];

        /// <summary>
        /// Which scheme the chart's saved grouping is the answer to. Absent in
        /// an entry written before presets became schemes, which reads as
        /// "the grouping belongs to no preset" — the same state a fresh chart
        /// is in, so an old entry opens without pretending.
        /// </summary>
        public int? ActiveGroupPresetId { get; set; }

        public List<ChartAnnotation> Annotations { get; set; } = [];
        public List<ChartAnnotationPreset> AnnotationPresets { get; set; } = [];

        /// <summary>Which annotation preset is on screen; absent means 全部.</summary>
        public int? ActiveAnnotationPresetId { get; set; }
    }

    /// <summary>
    /// Read-only view of the schema-1 shape, which carried a text note on the
    /// group instead of on a block. It exists only so an upgrade can rescue that
    /// text; nothing writes it back.
    /// </summary>
    private sealed class LegacyFile
    {
        public int SchemaVersion { get; set; }
        public List<LegacyEntry?> Entries { get; set; } = [];
    }

    private sealed class LegacyEntry
    {
        public string Path { get; set; } = string.Empty;
        public List<LegacyGroup?> Groups { get; set; } = [];
    }

    private sealed class LegacyGroup
    {
        public int Id { get; set; }
        public string Annotation { get; set; } = string.Empty;
        public bool HasAnnotation { get; set; }
    }
}
