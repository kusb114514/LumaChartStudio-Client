using System.Globalization;
using Avalonia;
using Avalonia.Automation;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Layout;
using Avalonia.Media;
using LumaChart.Application.Editing;
using LumaChart.Avalonia.Controls;
using LumaChart.Avalonia.Infrastructure;
using LumaChart.Core.Effects;
using LumaChart.Core.Models;
using LumaChart.Core.Timing;

namespace LumaChart.Avalonia.Dialogs;

/// <summary>
/// The SV template picker: choose a shape on the left, fill its slots in the
/// middle, watch the result scroll on the right. Applying writes one undoable
/// mutation and keeps the window open so the numbers can be tuned without
/// closing and reopening the playtest.
/// </summary>
internal sealed class SvTemplateWindow : PlatformWindow
{
    private static readonly IBrush WindowBrush = Brush("#101315");
    private static readonly IBrush PanelBrush = Brush("#181C1F");
    private static readonly IBrush RaisedBrush = Brush("#242C31");
    private static readonly IBrush SelectedBrush = Brush("#2F4247");
    private static readonly IBrush StrokeBrush = Brush("#3B474D");
    private static readonly IBrush AccentBrush = Brush("#79B8BD");
    private static readonly IBrush TextBrush = Brush("#E3E8E9");
    private static readonly IBrush MutedBrush = Brush("#93A0A5");
    private static readonly IBrush WarnBrush = Brush("#D39A88");
    private static readonly IBrush OkBrush = Brush("#8FC4A5");

    private readonly EditorSession session;
    private readonly Action<SvTemplateApplyResult>? onApplied;
    private readonly double fontScale;

    private readonly SvPreviewSurface preview = new();
    private readonly StackPanel templateHost = new() { Spacing = 2 };
    private readonly StackPanel slotHost = new() { Spacing = 8 };
    private readonly TextBox beatBox = new();
    private readonly TextBox lengthBox = new();
    private readonly TextBox targetBox = new();
    private readonly ComboBox sampleBox = new();
    private readonly CheckBox replaceBox = new() { IsChecked = true, Foreground = TextBrush };
    private readonly CheckBox useMarksBox = new() { Foreground = TextBrush };
    private readonly TextBlock statsText = new();
    private readonly TextBlock warningText = new();
    private readonly TextBlock statusText = new();
    private readonly Button playButton = new();
    private readonly List<(Button Button, SvTemplate Template)> templateButtons = [];
    private readonly Dictionary<string, Control> slotInputs = [];

    private SvTemplate? selected;
    private SvTemplateDraft? draft;
    private bool suppressRefresh;

    internal SvTemplateWindow(
        EditorSession session,
        double initialBeat,
        double uiScale,
        double fontScale,
        Action<SvTemplateApplyResult>? onApplied = null)
    {
        this.session = session;
        this.onApplied = onApplied;
        this.fontScale = double.IsFinite(fontScale) ? Math.Clamp(fontScale, .8, 1.6) : 1;
        uiScale = double.IsFinite(uiScale) ? Math.Clamp(uiScale, .8, 1.6) : 1;

        Title = "SV 模板";
        Width = 960 * uiScale;
        Height = 660 * uiScale;
        MinWidth = 840 * uiScale;
        MinHeight = 560 * uiScale;
        CanResize = true;
        ShowInTaskbar = false;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        WindowDecorations = WindowDecorations.None;
        Background = WindowBrush;
        FontFamily = new FontFamily("Segoe UI Variable Text, Microsoft YaHei UI");
        FontSize = 12 * this.fontScale;
        AutomationProperties.SetAutomationId(this, "SvTemplate.Dialog");
        AutomationProperties.SetName(this, "SV 模板");

        beatBox.Text = WindowsBeatDisplayFormat.Format(
            BeatPosition.FromDouble(Math.Max(0, initialBeat)));
        lengthBox.Text = "2";
        targetBox.Text = "1";

        BuildTemplateList();
        Content = BuildContent();
        AddHandler(InputElement.KeyDownEvent, OnKeyDown, RoutingStrategies.Tunnel, true);

        SelectTemplate(SvTemplateCatalog.All[1]);
        Closed += (_, _) => preview.StopAnimation();
    }

    // ------------------------------------------------------------------ layout

    private void BuildTemplateList()
    {
        foreach (var group in SvTemplateCatalog.All.GroupBy(template => template.Definition.Group))
        {
            var header = new TextBlock
            {
                Text = SvTemplateCatalog.GroupLabel(group.Key),
                Foreground = MutedBrush,
                FontSize = 11 * fontScale,
                Margin = new Thickness(4, 10, 0, 4)
            };
            templateHost.Children.Add(header);
            foreach (var template in group)
            {
                var button = new Button
                {
                    Content = new TextBlock
                    {
                        Text = template.Definition.Title,
                        Foreground = TextBrush,
                        TextWrapping = TextWrapping.Wrap
                    },
                    Background = Brushes.Transparent,
                    BorderThickness = new Thickness(0),
                    HorizontalAlignment = HorizontalAlignment.Stretch,
                    HorizontalContentAlignment = HorizontalAlignment.Left,
                    Padding = new Thickness(8, 6),
                    CornerRadius = new CornerRadius(4),
                    Focusable = false
                };
                AutomationProperties.SetAutomationId(button, "SvTemplate.Item." + template.Definition.Id);
                var captured = template;
                button.Click += (_, _) => SelectTemplate(captured);
                templateButtons.Add((button, template));
                templateHost.Children.Add(button);
            }
        }
    }

    private Control BuildContent()
    {
        var headerClose = SmallButton("×");
        headerClose.Click += (_, _) => Close(false);
        AutomationProperties.SetAutomationId(headerClose, "SvTemplate.HeaderClose");
        var header = new Grid
        {
            ColumnDefinitions = new ColumnDefinitions("*,Auto"),
            Margin = new Thickness(22, 18, 22, 0)
        };
        header.Children.Add(new StackPanel
        {
            Spacing = 3,
            Children =
            {
                new TextBlock
                {
                    Text = "SV 模板",
                    FontSize = 20 * fontScale,
                    FontWeight = FontWeight.SemiBold,
                    Foreground = TextBrush
                },
                new TextBlock
                {
                    Text = "选形态 → 填槽位 → 右边实时看效果；应用后窗口不关，可以继续调数。",
                    Foreground = MutedBrush,
                    TextWrapping = TextWrapping.Wrap
                }
            }
        });
        Grid.SetColumn(headerClose, 1);
        header.Children.Add(headerClose);

        var left = new Border
        {
            Background = PanelBrush,
            BorderBrush = StrokeBrush,
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(5),
            Child = new ScrollViewer
            {
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
                Padding = new Thickness(8),
                Content = templateHost
            }
        };

        var middle = new Border
        {
            Background = PanelBrush,
            BorderBrush = StrokeBrush,
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(5),
            Margin = new Thickness(10, 0),
            Child = new ScrollViewer
            {
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
                Padding = new Thickness(14, 12),
                Content = BuildSlotForm()
            }
        };

        var right = BuildPreviewPanel();

        var content = new Grid
        {
            ColumnDefinitions = new ColumnDefinitions("220,330,*"),
            Margin = new Thickness(22, 14, 22, 0)
        };
        content.Children.Add(left);
        Grid.SetColumn(middle, 1);
        content.Children.Add(middle);
        Grid.SetColumn(right, 2);
        content.Children.Add(right);

        var apply = PrimaryButton("应用");
        apply.Click += (_, _) => ApplyDraft();
        AutomationProperties.SetAutomationId(apply, "SvTemplate.Apply");
        var close = SmallButton("关闭");
        close.Click += (_, _) => Close(true);
        AutomationProperties.SetAutomationId(close, "SvTemplate.Close");

        statusText.Foreground = MutedBrush;
        statusText.TextWrapping = TextWrapping.Wrap;
        statusText.Margin = new Thickness(0, 0, 12, 0);
        statusText.VerticalAlignment = VerticalAlignment.Center;
        statusText.Text = "还没有写入任何内容。";

        var footer = new Grid
        {
            ColumnDefinitions = new ColumnDefinitions("*,Auto,10,Auto"),
            Margin = new Thickness(22, 12, 22, 18)
        };
        footer.Children.Add(statusText);
        Grid.SetColumn(apply, 1);
        footer.Children.Add(apply);
        Grid.SetColumn(close, 3);
        footer.Children.Add(close);

        var root = new Grid { RowDefinitions = new RowDefinitions("Auto,*,Auto"), Background = PanelBrush };
        root.Children.Add(header);
        Grid.SetRow(content, 1);
        root.Children.Add(content);
        Grid.SetRow(footer, 2);
        root.Children.Add(footer);

        return new Border
        {
            Margin = new Thickness(1),
            Background = PanelBrush,
            BorderBrush = StrokeBrush,
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(7),
            Child = root
        };
    }

    private Control BuildSlotForm()
    {
        sampleBox.ItemsSource = SvStepOption.All;
        sampleBox.SelectedIndex = SvStepOption.IndexDenominator(8);
        sampleBox.HorizontalAlignment = HorizontalAlignment.Stretch;
        StyleCombo(sampleBox);
        AutomationProperties.SetAutomationId(sampleBox, "SvTemplate.Sample");

        StyleInput(beatBox, "SvTemplate.Beat", "起拍");
        StyleInput(lengthBox, "SvTemplate.Length", "长度");
        StyleInput(targetBox, "SvTemplate.Target", "目标位移");

        replaceBox.Content = "覆盖区间内已有的 Effect";
        replaceBox.Foreground = MutedBrush;
        replaceBox.FontSize = 11 * fontScale;
        AutomationProperties.SetAutomationId(replaceBox, "SvTemplate.Replace");

        useMarksBox.Content = "节奏点用选中的 note";
        useMarksBox.Foreground = MutedBrush;
        useMarksBox.FontSize = 11 * fontScale;
        useMarksBox.IsVisible = false;
        AutomationProperties.SetAutomationId(useMarksBox, "SvTemplate.UseMarks");
        useMarksBox.IsCheckedChanged += (_, _) => RefreshPreview();

        beatBox.TextChanged += (_, _) => RefreshPreview();
        lengthBox.TextChanged += (_, _) => RefreshPreview();
        targetBox.TextChanged += (_, _) => RefreshPreview();
        sampleBox.SelectionChanged += (_, _) => RefreshPreview();

        return new StackPanel
        {
            Spacing = 6,
            Children =
            {
                Label("起拍"),
                beatBox,
                Label("长度（拍）"),
                lengthBox,
                Label("采样（每拍几次）"),
                sampleBox,
                Label("目标位移（1 = 净前进不变；0 = 原地往返）"),
                targetBox,
                useMarksBox,
                replaceBox,
                new Border
                {
                    Height = 1,
                    Background = StrokeBrush,
                    Margin = new Thickness(0, 8, 0, 8)
                },
                slotHost
            }
        };
    }

    private Control BuildPreviewPanel()
    {
        preview.HorizontalAlignment = HorizontalAlignment.Stretch;
        preview.VerticalAlignment = VerticalAlignment.Stretch;
        AutomationProperties.SetAutomationId(preview, "SvTemplate.Preview");

        playButton.Content = "暂停预览";
        playButton.Background = RaisedBrush;
        playButton.Foreground = TextBrush;
        playButton.BorderBrush = StrokeBrush;
        playButton.BorderThickness = new Thickness(1);
        playButton.Padding = new Thickness(10, 4);
        playButton.Focusable = false;
        playButton.Click += (_, _) =>
        {
            preview.SetPlaying(!preview.IsPlaying);
            playButton.Content = preview.IsPlaying ? "暂停预览" : "播放预览";
        };
        AutomationProperties.SetAutomationId(playButton, "SvTemplate.PlayToggle");

        var replay = SmallButton("重播");
        replay.Click += (_, _) =>
        {
            preview.SkipToStart();
            preview.SetPlaying(true);
            playButton.Content = "暂停预览";
        };
        AutomationProperties.SetAutomationId(replay, "SvTemplate.Replay");

        statsText.Foreground = MutedBrush;
        statsText.TextWrapping = TextWrapping.Wrap;
        statsText.FontSize = 11.5 * fontScale;
        statsText.Margin = new Thickness(0, 8, 0, 0);

        warningText.Foreground = WarnBrush;
        warningText.TextWrapping = TextWrapping.Wrap;
        warningText.FontSize = 11.5 * fontScale;
        warningText.Margin = new Thickness(0, 6, 0, 0);

        var previewHeader = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto,6,Auto") };
        var title = new TextBlock
        {
            Text = "实时预览",
            Foreground = TextBrush,
            FontWeight = FontWeight.SemiBold,
            VerticalAlignment = VerticalAlignment.Center
        };
        previewHeader.Children.Add(title);
        Grid.SetColumn(playButton, 1);
        previewHeader.Children.Add(playButton);
        Grid.SetColumn(replay, 3);
        previewHeader.Children.Add(replay);

        var panel = new Border
        {
            Background = PanelBrush,
            BorderBrush = StrokeBrush,
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(5),
            Padding = new Thickness(12, 10),
            Child = new Grid
            {
                RowDefinitions = new RowDefinitions("Auto,*,Auto,Auto"),
                Children =
                {
                    previewHeader,
                    preview,
                    statsText,
                    warningText
                }
            }
        };
        var grid = (Grid)panel.Child!;
        Grid.SetRow(preview, 1);
        Grid.SetRow(statsText, 2);
        Grid.SetRow(warningText, 3);
        return panel;
    }

    // ------------------------------------------------------------- behaviour

    private void SelectTemplate(SvTemplate template)
    {
        selected = template;
        foreach (var (button, candidate) in templateButtons)
            button.Background = ReferenceEquals(candidate, template) ? SelectedBrush : Brushes.Transparent;

        suppressRefresh = true;
        try
        {
            slotInputs.Clear();
            slotHost.Children.Clear();
            slotHost.Children.Add(new TextBlock
            {
                Text = template.Definition.Title,
                Foreground = TextBrush,
                FontWeight = FontWeight.SemiBold,
                TextWrapping = TextWrapping.Wrap
            });
            slotHost.Children.Add(new TextBlock
            {
                Text = template.Definition.Summary,
                Foreground = MutedBrush,
                FontSize = 11 * fontScale,
                TextWrapping = TextWrapping.Wrap,
                Margin = new Thickness(0, 0, 0, 2)
            });

            foreach (var slot in template.Definition.Slots)
                slotHost.Children.Add(BuildSlot(slot));

            targetBox.IsEnabled = template.Definition.UsesTarget;
            useMarksBox.IsVisible = template.Definition.UsesMarks;
            if (!template.Definition.UsesMarks) useMarksBox.IsChecked = false;
            sampleBox.SelectedIndex = SvStepOption.IndexDenominator(
                template.Definition.PreferredStepDenominator);
            slotHost.Children.Add(new TextBlock
            {
                Text = template.Definition.UsesTarget
                    ? "目标位移只对这类形状生效：1 表示整段净前进不变。"
                    : "这个形态不使用目标位移。",
                Foreground = MutedBrush,
                FontSize = 10.5 * fontScale,
                TextWrapping = TextWrapping.Wrap,
                Margin = new Thickness(0, 4, 0, 0)
            });
        }
        finally
        {
            suppressRefresh = false;
        }
        RefreshPreview();
    }

    private Control BuildSlot(SvTemplateSlot slot)
    {
        var panel = new StackPanel { Spacing = 4 };
        panel.Children.Add(Label(slot.Unit.Length > 0 ? $"{slot.Label}（{slot.Unit}）" : slot.Label));
        switch (slot.Kind)
        {
            case SvSlotKind.Curve:
                {
                    var combo = new ComboBox
                    {
                        ItemsSource = SvCurveLibrary.All.Select(SvCurveLibrary.Label).ToArray(),
                        SelectedIndex = Math.Clamp((int)Math.Round(slot.Default), 0, SvCurveLibrary.All.Count - 1),
                        HorizontalAlignment = HorizontalAlignment.Stretch
                    };
                    StyleCombo(combo);
                    combo.SelectionChanged += (_, _) => RefreshPreview();
                    AutomationProperties.SetAutomationId(combo, "SvTemplate.Slot." + slot.Id);
                    panel.Children.Add(combo);
                    slotInputs[slot.Id] = combo;
                    break;
                }
            case SvSlotKind.Integer:
                {
                    var box = new TextBox { Text = ((int)Math.Round(slot.Default)).ToString(CultureInfo.InvariantCulture) };
                    StyleInput(box, "SvTemplate.Slot." + slot.Id, slot.Label);
                    box.TextChanged += (_, _) => RefreshPreview();
                    panel.Children.Add(box);
                    slotInputs[slot.Id] = box;
                    break;
                }
            case SvSlotKind.Text:
                {
                    var box = new TextBox { Text = slot.DefaultText };
                    StyleInput(box, "SvTemplate.Slot." + slot.Id, slot.Label);
                    box.TextChanged += (_, _) => RefreshPreview();
                    panel.Children.Add(box);
                    slotInputs[slot.Id] = box;
                    break;
                }
            default:
                {
                    var box = new TextBox
                    {
                        Text = slot.Default.ToString("0.####", CultureInfo.InvariantCulture)
                    };
                    StyleInput(box, "SvTemplate.Slot." + slot.Id, slot.Label);
                    box.TextChanged += (_, _) => RefreshPreview();
                    panel.Children.Add(box);
                    slotInputs[slot.Id] = box;
                    break;
                }
        }
        if (!string.IsNullOrEmpty(slot.Help))
        {
            panel.Children.Add(new TextBlock
            {
                Text = slot.Help,
                Foreground = MutedBrush,
                FontSize = 10.5 * fontScale,
                TextWrapping = TextWrapping.Wrap
            });
        }
        return panel;
    }

    private void RefreshPreview()
    {
        if (suppressRefresh || selected == null) return;
        draft = null;
        if (!WindowsBeatDisplayFormat.TryParse(beatBox.Text, out var start))
        {
            ShowStatus("起拍要写成 1:0/1 这样的拍号，或直接写十进制拍数。", error: true);
            return;
        }
        if (!TryNumber(lengthBox.Text, out var length) || length <= 0 || length > 512)
        {
            ShowStatus("长度要写在 0 ~ 512 拍之间。", error: true);
            return;
        }
        if (!TryNumber(targetBox.Text, out var target)) target = 1;

        var slots = new Dictionary<string, double>(StringComparer.Ordinal);
        var textSlots = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var slot in selected.Definition.Slots)
        {
            if (!slotInputs.TryGetValue(slot.Id, out var input)) continue;
            if (input is ComboBox combo)
            {
                slots[slot.Id] = combo.SelectedIndex < 0 ? slot.Default : combo.SelectedIndex;
                continue;
            }
            if (input is TextBox box)
            {
                if (slot.Kind == SvSlotKind.Text)
                {
                    textSlots[slot.Id] = box.Text ?? string.Empty;
                    continue;
                }
                if (!TryNumber(box.Text, out var value)) value = slot.Default;
                slots[slot.Id] = value;
            }
        }

        var marks = useMarksBox.IsChecked == true ? ResolveMarks() : [];

        var document = session.Document;
        var timingMap = new TimingMap(document.Timing);
        var step = (sampleBox.SelectedItem as SvStepOption)?.Denominator ?? 8;
        var context = new SvTemplateContext
        {
            Start = start,
            LengthBeats = length,
            StepDenominator = step,
            TargetDisplacement = target,
            Slots = slots,
            TextSlots = textSlots,
            Marks = marks,
            BpmAt = beat => timingMap.BpmAt(beat),
            ReferenceBpm = ResolveReferenceBpm(document),
            TailValue = 1
        };

        SvTemplateDraft built;
        try
        {
            built = selected.Build(context);
        }
        catch (Exception exception) when (exception is ArgumentException or InvalidOperationException)
        {
            ShowStatus("模板算不出来：" + exception.Message, error: true);
            return;
        }
        draft = built;

        var points = new List<(double Beat, double Value)>();
        foreach (var timing in document.Timing)
        {
            if (timing.Effect != TimingEffectKind.Scroll) continue;
            if (timing.Beat.CompareTo(start) >= 0) continue;
            points.Add((timing.Beat.Value, timing.EffectValue));
        }
        foreach (var row in built.Rows)
        {
            if (row.Kind == TimingEffectKind.Scroll) points.Add((row.Beat.Value, row.Value));
        }
        points.Sort((left, right) => left.Beat.CompareTo(right.Beat));

        preview.SetContent(start.Value, start.Value + length, points, context.BpmAtStart, document.KeyCount);

        var ratio = built.WindowBeats > 0 ? built.NetDisplacement / built.WindowBeats : 0;
        statsText.Text =
            $"净位移 {built.NetDisplacement:0.###} 拍 / 区间 {built.WindowBeats:0.###} 拍（平均 {ratio:0.###}×）\n" +
            $"峰值 {built.Peak:0.###}×　谷值 {built.Valley:0.###}×　行数 {built.Rows.Count}\n" +
            $"每步 {built.MillisecondsPerStep:0.##} ms　BPM {context.BpmAtStart:0.###}";

        if (built.Warnings.Count == 0)
        {
            warningText.Text = string.Empty;
        }
        else
        {
            warningText.Text = string.Join("\n", built.Warnings.Select(text => "· " + text));
        }
        ShowStatus(string.Empty);
    }

    private void ApplyDraft()
    {
        if (draft == null)
        {
            ShowStatus("还没有可写入的内容，先检查输入。", error: true);
            return;
        }
        try
        {
            var result = SvTemplateEditingService.Apply(session, draft, replaceBox.IsChecked == true);
            ShowStatus(result.Message, error: !result.Applied);
            if (result.Applied) onApplied?.Invoke(result);
        }
        catch (Exception exception) when (exception is InvalidOperationException or ArgumentException)
        {
            ShowStatus(exception.Message, error: true);
        }
    }

    private void ShowStatus(string text, bool error = false)
    {
        statusText.Text = text;
        statusText.Foreground = error ? WarnBrush : OkBrush;
    }

    private static double ResolveReferenceBpm(ChartDocument document)
    {
        var bpms = document.Timing
            .Where(timing => timing.Bpm is > 0 and <= ChartDocument.MaximumTimingBpm)
            .OrderBy(timing => timing.Beat)
            .ToArray();
        if (bpms.Length == 0)
            return document.Metadata.Bpm is > 0 and <= ChartDocument.MaximumTimingBpm
                ? document.Metadata.Bpm
                : 120;
        var best = bpms[0].Bpm!.Value;
        var bestSpan = -1d;
        for (var i = 0; i < bpms.Length; i++)
        {
            var span = i + 1 < bpms.Length ? bpms[i + 1].Beat.Value - bpms[i].Beat.Value : 0;
            if (span > bestSpan)
            {
                bestSpan = span;
                best = bpms[i].Bpm!.Value;
            }
        }
        return best;
    }

    private void OnKeyDown(object? sender, KeyEventArgs eventArgs)
    {
        if (eventArgs.Key != Key.Escape) return;
        Close(false);
        eventArgs.Handled = true;
    }

    // ------------------------------------------------------------------ pieces

    private TextBlock Label(string text) => new()
    {
        Text = text,
        Foreground = MutedBrush,
        FontSize = 11 * fontScale,
        TextWrapping = TextWrapping.Wrap,
        Margin = new Thickness(0, 6, 0, 0)
    };

    private void StyleInput(TextBox box, string automationId, string name)
    {
        box.Background = Brush("#15181A");
        box.Foreground = TextBrush;
        box.CaretBrush = AccentBrush;
        box.BorderBrush = StrokeBrush;
        box.BorderThickness = new Thickness(1);
        box.CornerRadius = new CornerRadius(3);
        box.Padding = new Thickness(8, 6);
        box.MinHeight = 32;
        box.FontSize = 12 * fontScale;
        AutomationProperties.SetAutomationId(box, automationId);
        AutomationProperties.SetName(box, name);
    }

    private static void StyleCombo(ComboBox combo)
    {
        combo.Background = Brush("#15181A");
        combo.Foreground = TextBrush;
        combo.BorderBrush = StrokeBrush;
        combo.BorderThickness = new Thickness(1);
        combo.CornerRadius = new CornerRadius(3);
        combo.Padding = new Thickness(8, 4);
        combo.MinHeight = 32;
    }

    private Button PrimaryButton(string text)
    {
        var button = new Button
        {
            Content = text,
            Background = SelectedBrush,
            Foreground = TextBrush,
            BorderBrush = AccentBrush,
            BorderThickness = new Thickness(1),
            Padding = new Thickness(18, 7),
            CornerRadius = new CornerRadius(4),
            Focusable = false
        };
        return button;
    }

    private Button SmallButton(string text)
    {
        var button = new Button
        {
            Content = text,
            Background = RaisedBrush,
            Foreground = TextBrush,
            BorderBrush = StrokeBrush,
            BorderThickness = new Thickness(1),
            Padding = new Thickness(12, 5),
            CornerRadius = new CornerRadius(4),
            Focusable = false
        };
        return button;
    }

    private static bool TryNumber(string? text, out double value) =>
        double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out value) ||
        double.TryParse(text, NumberStyles.Float, CultureInfo.CurrentCulture, out value);

    /// <summary>Beats of the selected notes, ascending; drafts excluded.</summary>
    private IReadOnlyList<BeatPosition> ResolveMarks()
    {
        if (session.Selection.Count == 0) return [];
        var marks = new List<BeatPosition>(session.Selection.Count);
        foreach (var note in session.Document.Notes)
        {
            if (note.IsDraft) continue;
            if (!session.Selection.Contains(note.Id)) continue;
            marks.Add(note.Beat);
        }
        marks.Sort((left, right) => left.CompareTo(right));
        return marks;
    }

    private static IBrush Brush(string hex) => new SolidColorBrush(Color.Parse(hex));
}

/// <summary>Sampling step choices, ordered the way mappers actually think about them.</summary>
internal sealed record SvStepOption(int Denominator, string Label)
{
    public static IReadOnlyList<SvStepOption> All { get; } =
    [
        new(4, "每 1/4 拍"),
        new(8, "每 1/8 拍"),
        new(10, "每 1/10 拍"),
        new(16, "每 1/16 拍"),
        new(20, "每 1/20 拍"),
        new(32, "每 1/32 拍"),
        new(40, "每 1/40 拍"),
        new(100, "每 1/100 拍"),
        new(200, "每 1/200 拍")
    ];

    public static int IndexDenominator(int denominator)
    {
        for (var i = 0; i < All.Count; i++)
            if (All[i].Denominator == denominator) return i;
        return 1;
    }

    public override string ToString() => Label;
}
