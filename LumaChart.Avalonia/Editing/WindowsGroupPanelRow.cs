using Avalonia.Controls;

namespace LumaChart.Avalonia.Editing;

/// <summary>
/// Live references to one Group Manager row.
///
/// The panel used to rebuild every row on each inspector refresh, which is fine
/// for text-only rows. Now a row owns a name box and a parent picker, and a
/// rebuild while the mapper is typing would take the caret away, so a refresh
/// updates the cheap parts in place (visibility, counts, "current" highlight)
/// and only rebuilds when the set of groups actually changes.
/// </summary>
internal sealed class GroupRowControls
{
    public GroupRowControls(
        int group,
        CheckBox visible,
        TextBox name,
        Button color,
        ComboBox? parent,
        IReadOnlyList<int?> parentIds,
        Button use,
        Button? child,
        Button dissolve,
        TextBlock stats,
        Border container)
    {
        Group = group;
        Visible = visible;
        Name = name;
        Color = color;
        Parent = parent;
        ParentIds = parentIds;
        Use = use;
        Child = child;
        Dissolve = dissolve;
        Stats = stats;
        Container = container;
    }

    public int Group { get; }
    public CheckBox Visible { get; }
    public TextBox Name { get; }
    public Button Color { get; }

    /// <summary>Null while the sub-group column is hidden, which is the default.</summary>
    public ComboBox? Parent { get; }

    /// <summary>Id behind each parent-combo index, so no item template is needed.</summary>
    public IReadOnlyList<int?> ParentIds { get; }

    public Button Use { get; }

    /// <summary>Null while the sub-group column is hidden, which is the default.</summary>
    public Button? Child { get; }

    public Button Dissolve { get; }
    public TextBlock Stats { get; }
    public Border Container { get; }

    /// <summary>Set while a refresh writes into the row's controls.</summary>
    public bool SuppressEvents { get; set; }
}

/// <summary>
/// Live references to one 批注 row: the block's text and the actions that act on
/// it. Rebuilt only when the set of blocks changes, so typing in one block's
/// text box is never interrupted by an inspector refresh.
/// </summary>
internal sealed class AnnotationRowControls
{
    public AnnotationRowControls(
        int annotation,
        Border swatch,
        TextBox text,
        TextBlock position,
        TextBlock coverage,
        Button jump,
        Button retarget,
        Button delete,
        ComboBox drawer,
        IReadOnlyList<int?> drawerIds,
        Border container)
    {
        Annotation = annotation;
        Swatch = swatch;
        Text = text;
        Position = position;
        Coverage = coverage;
        Jump = jump;
        Retarget = retarget;
        Delete = delete;
        Drawer = drawer;
        DrawerIds = drawerIds;
        Container = container;
    }

    public int Annotation { get; }
    public Border Swatch { get; }
    public TextBox Text { get; }
    public TextBlock Position { get; }
    public TextBlock Coverage { get; }
    public Button Jump { get; }
    public Button Retarget { get; }
    public Button Delete { get; }

    /// <summary>Which annotation drawer this block is filed under.</summary>
    public ComboBox Drawer { get; }

    /// <summary>Preset id behind each picker index; null is "未分类".</summary>
    public IReadOnlyList<int?> DrawerIds { get; }

    public Border Container { get; }

    /// <summary>Set while a refresh writes into the row's controls.</summary>
    public bool SuppressEvents { get; set; }
}
