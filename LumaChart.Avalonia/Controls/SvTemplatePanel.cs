using System.Globalization;
using Avalonia;
using Avalonia.Automation;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Layout;
using Avalonia.Media;
using LumaChart.Application.Editing;
using LumaChart.Avalonia.Infrastructure;
using LumaChart.Core.Effects;
using LumaChart.Core.Models;
using LumaChart.Core.Timing;

namespace LumaChart.Avalonia.Controls;

/// <summary>
/// The SV template panel that lives in the right inspector, on its own sub-tab under
/// the Timing parent tab. Presentation is one column because the inspector is narrow;
/// every knob and the template list come straight from <see cref="SvTemplateCatalog"/>,
/// so adding a template never means touching this file.
/// </summary>
internal sealed class SvTemplatePanel : UserControl
{
    private static readonly IBrush PanelBrush = Brush("#181C1F");
    private static readonly IBrush RaisedBrush = Brush("#242C31");
    private static readonly IBrush SelectedBrush = Brush("#2F4247");
    private static readonly IBrush StrokeBrush = Brush("#3B474D");
    private static readonly IBrush AccentBrush = Brush("#79B8BD");
    private static readonly IBrush TextBrush = Brush("#E3E8E9");
    private static readonly IBrush MutedBrush = Brush("#93A0A5");
    private static readonly IBrush WarnBrush = Brush("#D39A88");
    private static readonly IBrush OkBrush = Brush("#8FC4A5");

    private readonly Func<EditorSession?> sessionProvider;
    private readonly double fontScale;
    private readonly Action<SvTemplateApplyResult>? onApplied;

    private readonly ComboBox templateCombo = new();
    private readonly TextBox beatBox = new();
    private readonly TextBox lengthBox = new();
    private readonly TextBox targetBox = new();
    private readonly ComboBox stepCombo = new();
    private readonly CheckBox replaceBox = new();
    private readonly CheckBox useMarksBox = new();
    private readonly CheckBox advancedBox = new();
    private readonly StackPanel slotHost = new() { Spacing = 8 };
    private readonly WrapPanel presetHost = new();
    private readonly StackPanel presetSection = new() { Spacing = 6 };
    private readonly StackPanel advancedHost = new() { Spacing = 6 };
    private readonly SvSpeedStrip speedStrip = new();
    private readonly TextBlock summaryText = new();
    private readonly TextBlock describeText = new();
    private readonly TextBlock stripHintText = new();
    private readonly TextBlock statsText = new();
    private readonly TextBlock warningText = new();
    private readonly TextBlock statusText = new();
    private readonly Dictionary<string, Control> slotInputs = new(StringComparer.Ordinal);
    private readonly List<(Button Button, SvTemplatePreset Preset)> presetButtons = [];

    private SvTemplate? selected;
    private SvTemplateDraft? draft;
    private bool suppressRefresh;

    internal SvTemplatePanel(
        Func<EditorSession?> sessionProvider,
        double initialBeat,
        double fontScale,
        Action<SvTemplateApplyResult>? onApplied = null)
    {
        this.sessionProvider = sessionProvider;
        this.fontScale = double.IsFinite(fontScale) ? Math.Clamp(fontScale, .8, 1.6) : 1;
        this.onApplied = onApplied;

        beatBox.Text = WindowsBeatDisplayFormat.Format(
            BeatPosition.FromDouble(Math.Max(0, initialBeat)));
        lengthBox.Text = "2";
        targetBox.Text = "1";

        AutomationProperties.SetAutomationId(this, "Inspector.SvTemplate.Root");
        Content = BuildContent();
        SelectTemplate(SvTemplateCatalog.Find("push") ?? SvTemplateCatalog.All[0]);
    }

    /// <summary>Re-reads the session clock so the panel follows the red line after a click.</summary>
    internal void SyncStartBeat(double beat)
    {
        suppressRefresh = true;
        try
        {
            beatBox.Text = WindowsBeatDisplayFormat.Format(
                BeatPosition.FromDouble(Math.Max(0, beat)));
        }
        finally
        {
            suppressRefresh = false;
        }
        RefreshPreview();
    }

    private Control BuildContent()
    {
        var body = new StackPanel { Spacing = 10, Margin = new Thickness(0, 2, 0, 8) };

        var usage = new TextBlock
        {
            Text = "红线停在要加效果的那一拍 → 选模板 → 点一个效果档 → 应用到谱面。下面的数字只在想微调时才动。",
            Foreground = MutedBrush,
            FontSize = 10 * fontScale,
            TextWrapping = TextWrapping.Wrap
        };
        body.Children.Add(usage);

        // 模板：一个下拉框。选项前面带分组名，十几条里找得着。加模板只改目录。
        body.Children.Add(Field("模板", BuildTemplateCombo()));
        summaryText.Foreground = MutedBrush;
        summaryText.FontSize = 10.5 * fontScale;
        summaryText.TextWrapping = TextWrapping.Wrap;
        body.Children.Add(summaryText);

        // 效果档：不懂 scroll 的人从这里起步 —— 点一下就有整套能用的参数，
        // 下面那些数字只是给要微调的人留的口子。
        presetSection.Children.Add(SectionTitle("效果档（点一个就是一套能直接用的参数）"));
        presetSection.Children.Add(presetHost);
        presetSection.IsVisible = false;
        body.Children.Add(presetSection);

        speedStrip.Margin = new Thickness(0, 2, 0, 0);
        body.Children.Add(speedStrip);
        stripHintText.Foreground = MutedBrush;
        stripHintText.FontSize = 10 * fontScale;
        stripHintText.TextWrapping = TextWrapping.Wrap;
        stripHintText.Text =
            "横轴 = 这一段本身，竖轴 = 画面速度；虚线是 1 倍（正常速度）。线以上更快，线以下更慢，贴到底就是停住。";
        body.Children.Add(stripHintText);

        describeText.Foreground = TextBrush;
        describeText.FontSize = 11 * fontScale;
        describeText.TextWrapping = TextWrapping.Wrap;
        describeText.Text = "还没有算出结果。";
        body.Children.Add(describeText);

        warningText.Foreground = WarnBrush;
        warningText.FontSize = 10.5 * fontScale;
        warningText.TextWrapping = TextWrapping.Wrap;
        body.Children.Add(warningText);

        body.Children.Add(Divider());

        var position = new Grid { ColumnDefinitions = new ColumnDefinitions("*,8,*") };
        var beatField = Field("从哪一拍开始", beatBox);
        var lengthField = Field("持续多少拍", lengthBox);
        Grid.SetColumn(lengthField, 2);
        position.Children.Add(beatField);
        position.Children.Add(lengthField);
        body.Children.Add(position);

        // 只有声明了 UsesMarks 的模板（帧定格这类）才显示这个开关。
        useMarksBox.Content = "节奏点用选中的 note（不勾就按固定间隔自己排）";
        useMarksBox.Foreground = TextBrush;
        useMarksBox.FontSize = 10.5 * fontScale;
        useMarksBox.Margin = new Thickness(2, 0, 0, 0);
        useMarksBox.IsVisible = false;
        AutomationProperties.SetAutomationId(useMarksBox, "Inspector.SvTemplate.UseMarks");
        useMarksBox.IsCheckedChanged += (_, _) => RefreshPreview();
        body.Children.Add(useMarksBox);

        body.Children.Add(Divider());
        body.Children.Add(SectionTitle("参数"));
        body.Children.Add(slotHost);

        body.Children.Add(Divider());
        BuildAdvancedSection(body);

        var scroll = new ScrollViewer
        {
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled,
            Padding = new Thickness(0, 0, 4, 0),
            Content = body
        };

        var footer = BuildFooter();

        var root = new Grid
        {
            RowDefinitions = new RowDefinitions("*,Auto"),
            Margin = new Thickness(10, 8, 10, 0)
        };
        root.Children.Add(scroll);
        Grid.SetRow(footer, 1);
        root.Children.Add(footer);

        return new Border
        {
            Background = PanelBrush,
            BorderBrush = StrokeBrush,
            BorderThickness = new Thickness(0, 1, 0, 0),
            Child = root
        };
    }

    /// <summary>
    /// Everything the engine needs but a mapper never has to look at: the target speed,
    /// the row spacing, the overwrite switch, and the raw numbers. Collapsed by default —
    /// an inspector column should open on the effect, not on the field names.
    /// </summary>
    private void BuildAdvancedSection(StackPanel body)
    {
        advancedBox.Content = "高级参数（目标位移 / 精度 / 覆盖）";
        advancedBox.Foreground = MutedBrush;
        advancedBox.FontSize = 10.5 * fontScale;
        advancedBox.Margin = new Thickness(2, 0, 0, 0);
        AutomationProperties.SetAutomationId(advancedBox, "Inspector.SvTemplate.Advanced");
        body.Children.Add(advancedBox);

        var targetField = Field("目标位移（1 = 整段净前进不变）", targetBox);
        var stepField = Field("变化精度（每拍写几行）", stepCombo);
        replaceBox.Content = "覆盖区间内已有的 Effect";
        replaceBox.IsChecked = true;
        replaceBox.Foreground = TextBrush;
        replaceBox.FontSize = 10.5 * fontScale;
        replaceBox.Margin = new Thickness(2, 4, 0, 0);

        statsText.Foreground = MutedBrush;
        statsText.FontSize = 10 * fontScale;
        statsText.TextWrapping = TextWrapping.Wrap;

        advancedHost.Children.Add(targetField);
        advancedHost.Children.Add(stepField);
        advancedHost.Children.Add(replaceBox);
        advancedHost.Children.Add(statsText);
        advancedHost.IsVisible = false;
        advancedBox.IsCheckedChanged += (_, _) => advancedHost.IsVisible = advancedBox.IsChecked == true;
        body.Children.Add(advancedHost);
    }

    private Control BuildTemplateCombo()
    {
        var items = SvTemplateCatalog.All
            .Select(template => new TemplateChoice(
                template,
                $"[{SvTemplateCatalog.GroupLabel(template.Definition.Group)}] {template.Definition.Title}"))
            .ToArray();
        templateCombo.ItemsSource = items;
        // 默认停在「冲一下」：它是唯一同时有观感说明和四档预设的模板，
        // 也是第一次打开这个面板最可能想做的事。找不到就退回第一条。
        var initialIndex = Array.FindIndex(
            items,
            item => item.Template.Definition.Id == "push");
        templateCombo.SelectedIndex = initialIndex >= 0 ? initialIndex : 0;
        templateCombo.HorizontalAlignment = HorizontalAlignment.Stretch;
        StyleCombo(templateCombo);
        AutomationProperties.SetAutomationId(templateCombo, "Inspector.SvTemplate.Picker");
        templateCombo.SelectionChanged += (_, _) =>
        {
            if (templateCombo.SelectedItem is TemplateChoice choice) SelectTemplate(choice.Template);
        };
        return templateCombo;
    }

    private Control BuildFooter()
    {
        stepCombo.ItemsSource = SvStepChoice.All;
        stepCombo.SelectedItem = SvStepChoice.All.First(choice => choice.Denominator == 8);
        stepCombo.HorizontalAlignment = HorizontalAlignment.Stretch;
        StyleCombo(stepCombo);
        AutomationProperties.SetAutomationId(stepCombo, "Inspector.SvTemplate.Step");
        stepCombo.SelectionChanged += (_, _) => RefreshPreview();

        statusText.Foreground = MutedBrush;
        statusText.FontSize = 10.5 * fontScale;
        statusText.TextWrapping = TextWrapping.Wrap;
        statusText.Text = "还没有写入任何内容。";

        var apply = new Button
        {
            Content = "应用到谱面",
            Background = AccentBrush,
            Foreground = Brush("#0F1416"),
            BorderThickness = new Thickness(0),
            CornerRadius = new CornerRadius(3),
            Padding = new Thickness(12, 5),
            HorizontalAlignment = HorizontalAlignment.Right,
            Focusable = false
        };
        AutomationProperties.SetAutomationId(apply, "Inspector.SvTemplate.Apply");
        apply.Click += (_, _) => ApplyDraft();

        var actions = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto") };
        actions.Children.Add(statusText);
        Grid.SetColumn(apply, 1);
        actions.Children.Add(apply);

        return new StackPanel
        {
            Spacing = 0,
            Margin = new Thickness(0, 6, 0, 8),
            Children = { actions }
        };
    }

    private TextBlock SectionTitle(string text) => new()
    {
        Text = text,
        Foreground = MutedBrush,
        FontSize = 10.5 * fontScale
    };

    private static Control Divider() => new Border
    {
        Height = 1,
        Background = StrokeBrush,
        Opacity = .6,
        Margin = new Thickness(0, 2)
    };

    private Control Field(string label, Control input)
    {
        var panel = new StackPanel { Spacing = 4 };
        panel.Children.Add(new TextBlock
        {
            Text = label,
            Foreground = MutedBrush,
            FontSize = 10.5 * fontScale,
            TextWrapping = TextWrapping.Wrap
        });
        StyleInput(input);
        panel.Children.Add(input);
        return panel;
    }

    private void SelectTemplate(SvTemplate template)
    {
        if (ReferenceEquals(selected, template) && slotHost.Children.Count > 0)
        {
            RefreshPreview();
            return;
        }

        selected = template;
        summaryText.Text = template.Definition.Summary;

        suppressRefresh = true;
        try
        {
            slotInputs.Clear();
            slotHost.Children.Clear();
            foreach (var slot in template.Definition.Slots)
                slotHost.Children.Add(BuildSlot(slot));

            BuildPresetButtons(template.Definition.StartingPoints);

            targetBox.IsEnabled = template.Definition.UsesTarget;
            targetBox.Opacity = template.Definition.UsesTarget ? 1 : .45;
            useMarksBox.IsVisible = template.Definition.UsesMarks;
            if (!template.Definition.UsesMarks) useMarksBox.IsChecked = false;
            var preferred = SvStepChoice.All.FirstOrDefault(
                choice => choice.Denominator == template.Definition.PreferredStepDenominator);
            if (preferred != null) stepCombo.SelectedItem = preferred;
        }
        finally
        {
            suppressRefresh = false;
        }

        RefreshPreview();
    }

    /// <summary>
    /// One row of named starting points. A mapper who cannot predict what 0.0001 looks
    /// like can still press 「停一拍」 and get a usable result, then nudge from there.
    /// </summary>
    private void BuildPresetButtons(IReadOnlyList<SvTemplatePreset> presets)
    {
        presetButtons.Clear();
        presetHost.Children.Clear();
        presetSection.IsVisible = presets.Count > 0;
        if (presets.Count == 0) return;

        foreach (var preset in presets)
        {
            var button = new Button
            {
                Content = preset.Name,
                Background = RaisedBrush,
                Foreground = TextBrush,
                BorderBrush = StrokeBrush,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(3),
                Padding = new Thickness(9, 3),
                FontSize = 10.5 * fontScale,
                Margin = new Thickness(0, 0, 4, 4),
                Focusable = false
            };
            AutomationProperties.SetAutomationId(button, "Inspector.SvTemplate.Preset." + preset.Name);
            var captured = preset;
            button.Click += (_, _) => ApplyPreset(captured);
            presetButtons.Add((button, preset));
            presetHost.Children.Add(button);
        }
    }

    private void ApplyPreset(SvTemplatePreset preset)
    {
        if (selected == null) return;
        suppressRefresh = true;
        try
        {
            foreach (var slot in selected.Definition.Slots)
            {
                if (!slotInputs.TryGetValue(slot.Id, out var input) || input is not TextBox box) continue;
                if (preset.Texts.TryGetValue(slot.Id, out var text))
                {
                    box.Text = text;
                }
                else if (preset.Values.TryGetValue(slot.Id, out var value))
                {
                    box.Text = slot.Kind == SvSlotKind.Integer
                        ? ((int)Math.Round(value)).ToString(CultureInfo.InvariantCulture)
                        : value.ToString("0.####", CultureInfo.InvariantCulture);
                }
            }
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
        panel.Children.Add(new TextBlock
        {
            Text = slot.Unit.Length > 0 ? $"{slot.Label}（{slot.Unit}）" : slot.Label,
            Foreground = MutedBrush,
            FontSize = 10.5 * fontScale,
            TextWrapping = TextWrapping.Wrap
        });

        if (slot.Kind == SvSlotKind.Curve)
        {
            var combo = new ComboBox
            {
                ItemsSource = SvCurveLibrary.All.Select(SvCurveLibrary.Label).ToArray(),
                SelectedIndex = Math.Clamp(
                    (int)Math.Round(slot.Default),
                    0,
                    SvCurveLibrary.All.Count - 1),
                HorizontalAlignment = HorizontalAlignment.Stretch
            };
            StyleCombo(combo);
            AutomationProperties.SetAutomationId(combo, "Inspector.SvTemplate.Slot." + slot.Id);
            combo.SelectionChanged += (_, _) => RefreshPreview();
            panel.Children.Add(combo);
            slotInputs[slot.Id] = combo;
        }
        else if (slot.Kind == SvSlotKind.Text)
        {
            var box = new TextBox { Text = slot.DefaultText, AcceptsReturn = false };
            StyleInput(box);
            AutomationProperties.SetAutomationId(box, "Inspector.SvTemplate.Slot." + slot.Id);
            AutomationProperties.SetName(box, slot.Label);
            box.TextChanged += (_, _) => RefreshPreview();
            panel.Children.Add(box);
            slotInputs[slot.Id] = box;
        }
        else
        {
            var box = new TextBox
            {
                Text = slot.Kind == SvSlotKind.Integer
                    ? ((int)Math.Round(slot.Default)).ToString(CultureInfo.InvariantCulture)
                    : slot.Default.ToString("0.####", CultureInfo.InvariantCulture)
            };
            StyleInput(box);
            AutomationProperties.SetAutomationId(box, "Inspector.SvTemplate.Slot." + slot.Id);
            AutomationProperties.SetName(box, slot.Label);
            box.TextChanged += (_, _) => RefreshPreview();
            panel.Children.Add(box);
            slotInputs[slot.Id] = box;
        }

        if (!string.IsNullOrEmpty(slot.Help))
        {
            panel.Children.Add(new TextBlock
            {
                Text = slot.Help,
                Foreground = MutedBrush,
                FontSize = 10 * fontScale,
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

        var session = sessionProvider();
        if (session == null)
        {
            ShowStatus("没有活动谱面。", error: true);
            return;
        }

        var marks = useMarksBox.IsChecked == true
            ? ResolveMarks(session)
            : [];
        if (selected.Definition.UsesMarks && useMarksBox.IsChecked == true && marks.Count < 2)
            ShowStatus($"选中的 note 只有 {marks.Count} 个，帧定格至少要两个；已退回按「帧间隔」自动排帧。",
                error: true);

        var document = session.Document;
        var timingMap = new TimingMap(document.Timing);
        var step = (stepCombo.SelectedItem as SvStepChoice)?.Denominator ?? 8;
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

        // 速度包络：进场那条 scroll 也要算进来，否则第一段会从 1× 起画。
        var points = new List<(double Beat, double Value)>();
        var entry = document.Timing
            .Where(timing => timing.Effect == TimingEffectKind.Scroll && timing.Beat.CompareTo(start) < 0)
            .OrderBy(timing => timing.Beat)
            .LastOrDefault();
        if (entry != null) points.Add((entry.Beat.Value, entry.EffectValue));
        var jumpMarks = new List<double>();
        foreach (var row in built.Rows)
        {
            if (row.Kind == TimingEffectKind.Scroll) points.Add((row.Beat.Value, row.Value));
            else jumpMarks.Add(row.Beat.Value);
        }
        points.Sort((left, right) => left.Beat.CompareTo(right.Beat));
        speedStrip.SetContent(points, start.Value, start.Value + length, jumpMarks,
            "这个效果没有速度变化，全靠整屏跳动完成 —— 所以这里画不出曲线。");

        var explanation = selected.Describe(context, built);
        describeText.Text = explanation.Count == 0
            ? "这个模板还没有写说明。"
            : string.Join("\n", explanation.Select(line => "· " + line));

        UpdatePresetHighlight(slots, textSlots);

        var ratio = built.WindowBeats > 0 ? built.NetDisplacement / built.WindowBeats : 0;
        statsText.Text =
            $"净位移 {built.NetDisplacement:0.###} 拍 / 区间 {built.WindowBeats:0.###} 拍（平均 {ratio:0.###}×）　" +
            $"行数 {built.Rows.Count}\n" +
            $"峰值 {built.Peak:0.###}×　谷值 {built.Valley:0.###}×　每步 {built.MillisecondsPerStep:0.##} ms";
        warningText.Text = built.Warnings.Count == 0
            ? string.Empty
            : string.Join("\n", built.Warnings.Select(text => "· " + text));
        ShowStatus(string.Empty);
    }

    /// <summary>Lights the preset whose values still match the boxes; null when hand-edited.</summary>
    private void UpdatePresetHighlight(
        IReadOnlyDictionary<string, double> slots,
        IReadOnlyDictionary<string, string> textSlots)
    {
        if (presetButtons.Count == 0) return;
        SvTemplatePreset? matched = null;
        foreach (var (_, preset) in presetButtons)
        {
            var same = true;
            foreach (var pair in preset.Values)
            {
                if (!slots.TryGetValue(pair.Key, out var value) || Math.Abs(value - pair.Value) > 1e-6)
                {
                    same = false;
                    break;
                }
            }
            if (same)
            {
                foreach (var pair in preset.Texts)
                {
                    if (!textSlots.TryGetValue(pair.Key, out var text) ||
                        !string.Equals(text.Trim(), pair.Value.Trim(), StringComparison.Ordinal))
                    {
                        same = false;
                        break;
                    }
                }
            }
            if (!same) continue;
            matched = preset;
            break;
        }

        foreach (var (button, preset) in presetButtons)
        {
            var isActive = ReferenceEquals(preset, matched);
            button.Background = isActive ? SelectedBrush : RaisedBrush;
            button.BorderBrush = isActive ? AccentBrush : StrokeBrush;
            button.Foreground = isActive ? TextBrush : MutedBrush;
        }
    }

    private void ApplyDraft()
    {
        if (draft == null)
        {
            ShowStatus("还没有可写入的内容，先检查输入。", error: true);
            return;
        }

        var session = sessionProvider();
        if (session == null)
        {
            ShowStatus("没有活动谱面。", error: true);
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

    private void StyleInput(Control input)
    {
        if (input is TextBox box)
        {
            box.Background = Brush("#101315");
            box.Foreground = TextBrush;
            box.BorderBrush = StrokeBrush;
            box.BorderThickness = new Thickness(1);
            box.CornerRadius = new CornerRadius(3);
            box.Padding = new Thickness(6, 3);
            box.FontSize = 11 * fontScale;
            box.MinHeight = 24;
        }
        input.HorizontalAlignment = HorizontalAlignment.Stretch;
    }

    private void StyleCombo(ComboBox combo)
    {
        combo.Background = Brush("#101315");
        combo.Foreground = TextBrush;
        combo.BorderBrush = StrokeBrush;
        combo.BorderThickness = new Thickness(1);
        combo.CornerRadius = new CornerRadius(3);
        combo.Padding = new Thickness(6, 3);
        combo.FontSize = 11 * fontScale;
        combo.MinHeight = 24;
        combo.HorizontalAlignment = HorizontalAlignment.Stretch;
    }

    private static bool TryNumber(string? text, out double value) =>
        double.TryParse(
            (text ?? string.Empty).Trim().Replace("，", ","),
            NumberStyles.Float,
            CultureInfo.InvariantCulture,
            out value);

    /// <summary>Beats of the selected notes, ascending; drafts excluded.</summary>
    private static IReadOnlyList<BeatPosition> ResolveMarks(EditorSession session)
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

    private static IBrush Brush(string value) => new SolidColorBrush(Color.Parse(value));

    private sealed record TemplateChoice(SvTemplate Template, string Text)
    {
        public override string ToString() => Text;
    }

    /// <summary>Rows per beat. Mirrors the dialog's list so both surfaces stay in step.</summary>
    internal sealed record SvStepChoice(int Denominator, string Label)
    {
        internal static IReadOnlyList<SvStepChoice> All { get; } =
        [
            new(4, "1/4 拍"),
            new(8, "1/8 拍"),
            new(12, "1/12 拍"),
            new(16, "1/16 拍"),
            new(24, "1/24 拍"),
            new(32, "1/32 拍"),
            new(40, "1/40 拍")
        ];

        public override string ToString() => Label;
    }
}
