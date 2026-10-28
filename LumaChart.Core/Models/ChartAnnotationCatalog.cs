using System.Text.Json.Serialization;

namespace LumaChart.Core.Models;

/// <summary>
/// A stable reference to one note.
///
/// <see cref="ChartNote.Id"/> is a per-run <see cref="System.Guid"/> that the
/// Malody and osu! serializers do not persist, so it cannot survive a save and
/// reload. Lane and beat are both written to the file, so they are what an
/// annotation is allowed to remember. The pair is the note's identity as far as
/// any other tool on disk can see it.
///
/// <para>
/// 正式轨与 ProEditor 额外轨道共用这一个键：正式 note 用 <see cref="Lane"/> 当轨道，
/// 草稿 note（<see cref="ChartNote.IsDraft"/>）把 <see cref="ChartNote.DraftColumn"/>
/// 存进同一个字段，并把 <see cref="IsDraft"/> 置真。两套列**不共用坐标空间**
/// （正式 = <c>0..KeyCount-1</c>，草稿 = <c>-64..KeyCount+63</c> 再挖掉正式那一段），
/// 所以带上这个标志，一条压在正式键上的草稿键才不会和正式 note 撞车。
/// </para>
///
/// <see cref="IsDraft"/> 是 <c>false</c> 时**不写进 JSON**，所以磁盘上已有的批注
/// 一个字节都不会变，旧客户端读到的也只是「正式轨」这一种。
/// </summary>
public readonly record struct ChartNoteKey(
    int Lane,
    BeatPosition Beat,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)] bool IsDraft = false)
{
    /// <summary>
    /// 从一条 note 取键。<see cref="Lane"/> 装的是**有效列** —— 正式轨是
    /// <see cref="ChartNote.Lane"/>，草稿轨是 <see cref="ChartNote.DraftColumn"/>。
    /// 凡「note → 批注键」的地方都必须走这里，别在调用点自己拼三元表达式，
    /// 否则草稿轨一定会漏掉一处。
    /// </summary>
    public static ChartNoteKey ForNote(ChartNote note)
    {
        ArgumentNullException.ThrowIfNull(note);
        return new ChartNoteKey(
            note.IsDraft ? note.DraftColumn : note.Lane,
            note.Beat,
            note.IsDraft);
    }
}

/// <summary>
/// A block of chart-analysis text pinned to a set of notes.
///
/// An annotation is deliberately *not* a group. A note carries exactly one
/// <see cref="ChartNote.Group"/>, so a second reading axis — "which hand does
/// this belong to" versus "does this pattern feel good to play" — cannot also
/// live in that field. The group field stays the axis the chart file owns;
/// annotations are the axis the mapper owns, they may cut across groups, and
/// they may sit on notes that were never grouped at all.
/// </summary>
public sealed class ChartAnnotation
{
    public int Id { get; set; }

    public string Text { get; set; } = string.Empty;

    /// <summary>The notes this block points at.</summary>
    public List<ChartNoteKey> Notes { get; set; } = [];

    /// <summary>
    /// Where the block jumps to. Kept even when <see cref="Notes"/> no longer
    /// resolves, so a stale annotation still has somewhere to go instead of
    /// silently disappearing from the list.
    /// </summary>
    public BeatPosition AnchorBeat { get; set; } = BeatPosition.Zero;

    public void CopyFrom(ChartAnnotation source)
    {
        ArgumentNullException.ThrowIfNull(source);
        Text = source.Text;
        Notes = [.. source.Notes];
        AnchorBeat = source.AnchorBeat;
    }

    public ChartAnnotation Clone() => new()
    {
        Id = Id,
        Text = Text,
        Notes = [.. Notes],
        AnchorBeat = AnchorBeat
    };
}

/// <summary>
/// A named set of annotations — the annotation-side twin of
/// <see cref="ChartGroupPreset"/>, and deliberately a *separate* drawer system:
/// the two presets organise two different readings of the same chart (音轨分组
/// versus 分析批注), so filing an annotation into a drawer must never move a
/// group, and the two lists never consult each other.
///
/// Like a group preset this is view organisation only. It decides which drawer
/// a block is listed in, never what a block says or which notes it covers.
/// </summary>
public sealed class ChartAnnotationPreset
{
    public int Id { get; set; }

    /// <summary>Display name. Empty falls back to "批注预设 N".</summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>Annotation ids in this preset. A block belongs to at most one.</summary>
    public List<int> AnnotationIds { get; set; } = [];

    public void CopyFrom(ChartAnnotationPreset source)
    {
        ArgumentNullException.ThrowIfNull(source);
        Name = source.Name;
        AnnotationIds = [.. source.AnnotationIds];
    }

    public ChartAnnotationPreset Clone() => new()
    {
        Id = Id,
        Name = Name,
        AnnotationIds = [.. AnnotationIds]
    };
}

/// <summary>
/// The per-chart annotation list. Like <see cref="ChartGroupCatalog"/> this is
/// editor metadata: it never touches the document, so adding or rewriting an
/// annotation cannot change a single note and produces no undo entry.
/// </summary>
public sealed class ChartAnnotationCatalog
{
    public const int MaximumAnnotations = 2048;
    public const int MaximumTextLength = 400;
    public const int MaximumNotesPerAnnotation = 4096;
    public const int MaximumPresets = 128;
    public const int MaximumPresetNameLength = 64;

    /// <summary>Empty text is what the UI renders as a placeholder block.</summary>
    public const string PlaceholderText = "在这里写批注";

    private readonly List<ChartAnnotation> annotations = [];
    private readonly Dictionary<int, ChartAnnotation> index = [];
    private readonly List<ChartAnnotationPreset> presets = [];
    private readonly Dictionary<int, ChartAnnotationPreset> presetIndex = [];

    public IReadOnlyList<ChartAnnotation> Annotations => annotations;

    public IReadOnlyList<ChartAnnotationPreset> Presets => presets;

    public bool IsEmpty => annotations.Count == 0;

    public static string DefaultText(int id) => $"批注 {id}";

    public static string DefaultPresetName(int id) => $"批注预设 {id}";

    public ChartAnnotation? Find(int id) => index.GetValueOrDefault(id);

    public int IndexOf(int id) => annotations.FindIndex(item => item.Id == id);

    /// <summary>Returns the annotation for <paramref name="id"/>, creating it when absent.</summary>
    public ChartAnnotation Ensure(int id)
    {
        if (index.TryGetValue(id, out var existing)) return existing;
        var created = new ChartAnnotation { Id = id };
        annotations.Add(created);
        index[id] = created;
        annotations.Sort((left, right) => left.Id.CompareTo(right.Id));
        return created;
    }

    public bool Remove(int id)
    {
        if (!index.TryGetValue(id, out var removed)) return false;
        index.Remove(id);
        annotations.Remove(removed);
        // A preset that kept listing a deleted block would render a tab whose
        // count never matches its contents.
        foreach (var preset in presets) preset.AnnotationIds.Remove(id);
        return true;
    }

    // ---- presets ---------------------------------------------------------
    // Independent of ChartGroupCatalog's presets on purpose: a group scheme
    // re-partitions the notes, an annotation preset only decides which blocks
    // are on screen. The two never read each other's ids.

    /// <summary>
    /// The preset whose blocks are on screen, or null for 全部 — every block,
    /// which is the state a chart starts in and the one place an unfiled block
    /// stays reachable. Persisted with the catalog so reopening a chart lands on
    /// the same reading.
    /// </summary>
    public int? ActivePresetId { get; set; }

    public ChartAnnotationPreset? FindPreset(int id) => presetIndex.GetValueOrDefault(id);

    /// <summary>Returns the preset for <paramref name="id"/>, creating it when absent.</summary>
    public ChartAnnotationPreset EnsurePreset(int id)
    {
        if (presetIndex.TryGetValue(id, out var existing)) return existing;
        var created = new ChartAnnotationPreset { Id = id };
        presets.Add(created);
        presetIndex[id] = created;
        presets.Sort((left, right) => left.Id.CompareTo(right.Id));
        return created;
    }

    public bool RemovePreset(int id)
    {
        if (!presetIndex.TryGetValue(id, out var removed)) return false;
        presetIndex.Remove(id);
        presets.Remove(removed);
        if (ActivePresetId == id) ActivePresetId = null;
        return true;
    }

    /// <summary>The smallest unused positive preset id.</summary>
    public int NextPresetId()
    {
        for (var candidate = 1; candidate <= MaximumPresets; candidate++)
            if (!presetIndex.ContainsKey(candidate)) return candidate;
        return presets.Count == 0 ? 1 : presets[^1].Id + 1;
    }

    public string PresetNameOf(int id) =>
        FindPreset(id) is { Name.Length: > 0 } preset
            ? preset.Name
            : DefaultPresetName(id);

    public ChartAnnotationPreset? PresetContaining(int annotationId) =>
        presets.FirstOrDefault(preset => preset.AnnotationIds.Contains(annotationId));

    public int? PresetIdOf(int annotationId) => PresetContaining(annotationId)?.Id;

    /// <summary>
    /// Puts <paramref name="annotationId"/> in <paramref name="presetId"/>,
    /// removing it from whichever drawer held it before. A null id takes it out
    /// of every drawer. Returns true when something actually moved.
    /// </summary>
    public bool AssignAnnotationToPreset(int annotationId, int? presetId)
    {
        if (annotationId <= 0) return false;
        if (presetId is { } target && target <= 0) return false;
        var current = PresetContaining(annotationId);
        if (presetId is null)
        {
            if (current == null) return false;
            current.AnnotationIds.Remove(annotationId);
            return true;
        }
        if (current?.Id == presetId) return false;
        current?.AnnotationIds.Remove(annotationId);
        EnsurePreset(presetId.Value).AnnotationIds.Add(annotationId);
        return true;
    }

    /// <summary>Blocks that no drawer claims, in beat order.</summary>
    public IReadOnlyList<int> UnassignedAnnotationIds() =>
        InBeatOrder()
            .Where(annotation => PresetContaining(annotation.Id) == null)
            .Select(annotation => annotation.Id)
            .ToArray();

    /// <summary>
    /// The blocks the active preset puts on screen, in reading order. With no
    /// active preset this is every block, so an unfiled one is never stranded.
    /// </summary>
    public IReadOnlyList<ChartAnnotation> VisibleAnnotations() =>
        ActivePresetId is { } active && FindPreset(active) is { } preset
            ? InBeatOrder().Where(annotation => preset.AnnotationIds.Contains(annotation.Id)).ToArray()
            : InBeatOrder();

    /// <summary>
    /// The same choice for the timeline, which draws cards in a hot loop:
    /// null means "everything", otherwise only these ids are drawn. Returning
    /// null rather than a full set keeps the common case allocation-free.
    /// </summary>
    public IReadOnlySet<int>? VisibleAnnotationIds() =>
        ActivePresetId is { } active && FindPreset(active) is { } preset
            ? preset.AnnotationIds.ToHashSet()
            : null;

    /// <summary>The blocks one preset holds, in beat order.</summary>
    public IReadOnlyList<int> PresetMembersInBeatOrder(int presetId)
    {
        if (FindPreset(presetId) is not { } preset) return [];
        var members = preset.AnnotationIds.ToHashSet();
        return InBeatOrder()
            .Where(annotation => members.Contains(annotation.Id))
            .Select(annotation => annotation.Id)
            .ToArray();
    }

    /// <summary>
    /// Preset clean-up, mirroring the group side: drops unusable presets and
    /// empty-string names, and enforces that a block is listed by at most one
    /// drawer so "which drawer is it in" has exactly one answer.
    /// </summary>
    private void NormalizePresets()
    {
        for (var position = presets.Count - 1; position >= 0; position--)
            if (presets[position].Id <= 0)
                presets.RemoveAt(position);

        presets.Sort((left, right) => left.Id.CompareTo(right.Id));
        RebuildPresetIndex();

        var claimed = new HashSet<int>();
        foreach (var preset in presets)
        {
            preset.Name = Clamp(preset.Name, MaximumPresetNameLength);
            var kept = new List<int>(preset.AnnotationIds.Count);
            foreach (var annotationId in preset.AnnotationIds)
            {
                if (annotationId <= 0) continue;
                if (!claimed.Add(annotationId)) continue;
                if (!kept.Contains(annotationId)) kept.Add(annotationId);
            }
            preset.AnnotationIds = kept;
        }

        while (presets.Count > MaximumPresets) presets.RemoveAt(presets.Count - 1);
        RebuildPresetIndex();
        if (ActivePresetId is { } active && FindPreset(active) == null) ActivePresetId = null;
    }

    /// <summary>The smallest unused positive id.</summary>
    public int NextId()
    {
        for (var candidate = 1; candidate <= MaximumAnnotations; candidate++)
            if (!index.ContainsKey(candidate)) return candidate;
        return annotations.Count == 0 ? 1 : annotations[^1].Id + 1;
    }

    /// <summary>
    /// Blocks in reading order. A block sits where its anchor sits, so the list
    /// follows the chart top to bottom instead of insertion order.
    /// </summary>
    public IReadOnlyList<ChartAnnotation> InBeatOrder() =>
        annotations
            .OrderBy(annotation => annotation.AnchorBeat)
            .ThenBy(annotation => annotation.Id)
            .ToArray();

    /// <summary>
    /// Drops unusable entries and clamps text and note counts. Called on every
    /// load so a hand-edited or truncated catalog cannot close the editor.
    /// </summary>
    public void Normalize()
    {
        for (var position = annotations.Count - 1; position >= 0; position--)
            if (annotations[position].Id <= 0)
                annotations.RemoveAt(position);

        RebuildIndex();
        foreach (var annotation in annotations)
        {
            annotation.Text = Clamp(annotation.Text, MaximumTextLength);
            if (annotation.Notes.Count > MaximumNotesPerAnnotation)
                annotation.Notes.RemoveRange(
                    MaximumNotesPerAnnotation,
                    annotation.Notes.Count - MaximumNotesPerAnnotation);
            annotation.Notes = annotation.Notes
                // 草稿列的合法范围是负数，所以只有正式键才受 >= 0 约束。
                // 漏掉 IsDraft 这一半，手改过的文件里草稿批注会在下次载入时被吃掉。
                .Where(key => key.IsDraft || key.Lane >= 0)
                .Distinct()
                .ToList();
            if (annotation.Notes.Count > 0 && !annotation.Notes.Any(key => key.Beat.Equals(annotation.AnchorBeat)))
                annotation.AnchorBeat = annotation.Notes.Min(key => key.Beat);
        }

        while (annotations.Count > MaximumAnnotations)
            annotations.RemoveAt(annotations.Count - 1);
        RebuildIndex();
        annotations.Sort((left, right) => left.Id.CompareTo(right.Id));
        NormalizePresets();
    }

    public ChartAnnotationCatalog Clone()
    {
        var copy = new ChartAnnotationCatalog { ActivePresetId = ActivePresetId };
        foreach (var annotation in annotations) copy.annotations.Add(annotation.Clone());
        foreach (var preset in presets) copy.presets.Add(preset.Clone());
        copy.RebuildIndex();
        copy.RebuildPresetIndex();
        return copy;
    }

    private void RebuildPresetIndex()
    {
        presetIndex.Clear();
        for (var position = presets.Count - 1; position >= 0; position--)
        {
            var preset = presets[position];
            if (presetIndex.ContainsKey(preset.Id))
            {
                presets.RemoveAt(position);
                continue;
            }
            presetIndex[preset.Id] = preset;
        }
    }

    private void RebuildIndex()
    {
        index.Clear();
        for (var position = annotations.Count - 1; position >= 0; position--)
        {
            var annotation = annotations[position];
            if (index.ContainsKey(annotation.Id))
            {
                annotations.RemoveAt(position);
                continue;
            }
            index[annotation.Id] = annotation;
        }
    }

    private static string Clamp(string? text, int maximum)
    {
        var trimmed = (text ?? string.Empty).Trim();
        return trimmed.Length <= maximum ? trimmed : trimmed[..maximum];
    }
}
