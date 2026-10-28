using Avalonia.Input;
using LumaChart.Avalonia.Infrastructure;

namespace LumaChart.Avalonia.Specs;

/// <summary>
/// Two editor additions that are easy to get subtly wrong. The wheel
/// quick-scroll gesture is the only shortcut whose persisted form is a bare
/// modifier set rather than a keystroke, so it has to be captured, parsed and
/// rejected differently from every other action. The quick range copy switch
/// reuses the existing copy route instead of adding a second one, so what
/// matters is that turning it off restores the old behaviour exactly.
/// </summary>
internal static class WheelScrollRangeSpecs
{
    private const string WheelAction = "WheelQuickScroll";

    public static int Run()
    {
        try
        {
            VerifyWheelCatalogEntry();
            VerifyModifierParsing();
            VerifyCaptureAcceptsABareModifierOnlyForTheWheel();
            VerifyMissingOrHandEditedBindings();
            VerifyRangeCopySettingRoundTrips();
            Console.WriteLine(
                $"Wheel quick-scroll and range-copy contracts: passed ({Count} checks)");
            return 0;
        }
        catch (Exception exception)
        {
            Console.Error.WriteLine(exception);
            Console.Error.WriteLine(
                $"Wheel quick-scroll and range-copy contracts: failed after {Count} checks");
            return 1;
        }
    }

    private static void VerifyWheelCatalogEntry()
    {
        var descriptor = WindowsEditorShortcutSettings.Catalog
            .FirstOrDefault(item => item.Id == WheelAction);
        Require(
            descriptor != null,
            "the wheel quick-scroll gesture is in the configurable shortcut catalog");
        Require(
            WindowsEditorShortcutSettings.CreateDefaults()[WheelAction] == "Alt",
            "its default binding is Alt, the one modifier the wheel has not already spent");
        Require(
            WindowsEditorShortcutRouting.Resolve(WheelAction).Route ==
            WindowsEditorShortcutRoute.WheelQuickScroll,
            "the action resolves to its own route");

        // Zoom and pan used to be hard-wired to Ctrl and Shift. They are now
        // catalog entries with the same defaults, so an upgraded install keeps
        // the gesture it always had.
        var defaults = WindowsEditorShortcutSettings.CreateDefaults();
        Require(
            defaults["WheelZoom"] == "Ctrl" && defaults["WheelPan"] == "Shift",
            $"zoom and pan keep their historic Ctrl / Shift defaults (got {defaults["WheelZoom"]} / {defaults["WheelPan"]})");
        Require(
            WindowsEditorShortcutRouting.Resolve("WheelZoom").Route ==
            WindowsEditorShortcutRoute.WheelZoom &&
            WindowsEditorShortcutRouting.Resolve("WheelPan").Route ==
            WindowsEditorShortcutRoute.WheelPan,
            "both resolve to their own routes");
        Require(
            defaults["WheelZoom"] != defaults["WheelPan"] &&
            defaults["WheelZoom"] != defaults[WheelAction] &&
            defaults["WheelPan"] != defaults[WheelAction],
            "the three wheel gestures start out distinct, so exactly one wins a notch");

        var settings = new WindowsEditorShortcutSettings(null);
        Require(
            WindowsEditorShortcutGesture.ResolveWheelModifiers(settings, "WheelZoom") ==
            KeyModifiers.Control &&
            WindowsEditorShortcutGesture.ResolveWheelModifiers(settings, "WheelPan") ==
            KeyModifiers.Shift &&
            WindowsEditorShortcutGesture.ResolveWheelModifiers(settings, "WheelQuickScroll") ==
            KeyModifiers.Alt,
            "all three resolve independently from the same settings object");

        var conflict = settings.Assign("WheelZoom", "Alt", replaceConflict: false);
        Require(
            !conflict.Applied && conflict.ConflictAction == "WheelQuickScroll",
            $"two wheel actions cannot share a modifier set (got {conflict.Applied}/{conflict.ConflictAction})");
        Require(
            WindowsEditorShortcutGesture.ResolveWheelModifiers(settings, "WheelZoom") ==
            KeyModifiers.Control,
            "a refused assignment leaves the old zoom binding alone");

        var swapped = new WindowsEditorShortcutSettings(
            new Dictionary<string, string>
            {
                ["WheelZoom"] = "Shift",
                ["WheelPan"] = "Ctrl"
            });
        Require(
            WindowsEditorShortcutGesture.ResolveWheelModifiers(swapped, "WheelZoom") ==
            KeyModifiers.Shift &&
            WindowsEditorShortcutGesture.ResolveWheelModifiers(swapped, "WheelPan") ==
            KeyModifiers.Control,
            "zoom and pan can be swapped, which is why the wheel handler compares both");
    }

    private static void VerifyModifierParsing()
    {
        Require(
            WindowsEditorShortcutGesture.ParseModifiers("Alt") == KeyModifiers.Alt,
            "Alt parses back to the Alt modifier");
        Require(
            WindowsEditorShortcutGesture.ParseModifiers("ctrl+alt") ==
            (KeyModifiers.Control | KeyModifiers.Alt),
            $"modifier names are case-insensitive and combine (got {WindowsEditorShortcutGesture.ParseModifiers("ctrl+alt")})");
        Require(
            WindowsEditorShortcutGesture.ParseModifiers("Alt+X") == KeyModifiers.None,
            "a gesture that carries a key is rejected, so a stray keystroke cannot scroll the timeline");
        Require(
            WindowsEditorShortcutGesture.ParseModifiers(string.Empty) == KeyModifiers.None,
            "an empty binding means no quick scroll at all");
        Require(
            WindowsEditorShortcutGesture.FormatModifiers(
                KeyModifiers.Shift | KeyModifiers.Alt) == "Shift+Alt",
            "formatting keeps the catalog order, so a captured gesture round trips");
    }

    private static void VerifyCaptureAcceptsABareModifierOnlyForTheWheel()
    {
        var ignored = WindowsEditorShortcutGesture.InterpretCapture(
            Key.LeftAlt,
            KeyModifiers.Alt);
        Require(
            ignored.Kind == WindowsEditorShortcutCaptureKind.IgnoreModifier,
            "every other action still ignores a bare modifier press");

        var captured = WindowsEditorShortcutGesture.InterpretCapture(
            Key.LeftAlt,
            KeyModifiers.Alt,
            allowModifierOnly: true);
        Require(
            captured.Kind == WindowsEditorShortcutCaptureKind.Assign &&
            captured.Gesture == "Alt",
            $"the wheel action captures a bare modifier as Alt (got {captured.Kind}/{captured.Gesture})");

        var combined = WindowsEditorShortcutGesture.InterpretCapture(
            Key.LeftShift,
            KeyModifiers.Alt | KeyModifiers.Shift,
            allowModifierOnly: true);
        Require(
            combined.Gesture == "Shift+Alt",
            $"a combination is captured in catalog order (got {combined.Gesture})");
    }

    private static void VerifyMissingOrHandEditedBindings()
    {
        var upgraded = new WindowsEditorShortcutSettings(
            new Dictionary<string, string> { ["Copy"] = "Ctrl+C" });
        Require(
            upgraded.Bindings[WheelAction] == "Alt",
            "an existing shortcuts.json without the action gains the Alt default");
        Require(
            upgraded.Bindings["WheelZoom"] == "Ctrl" &&
            upgraded.Bindings["WheelPan"] == "Shift",
            "the same file also gains the zoom and pan wheel gestures");
        Require(
            WindowsEditorShortcutGesture.ResolveWheelModifiers(upgraded) ==
            KeyModifiers.Alt,
            "the runtime reads Alt back out of that upgraded file");

        var handEdited = new WindowsEditorShortcutSettings(
            new Dictionary<string, string> { [WheelAction] = "F8" });
        Require(
            WindowsEditorShortcutGesture.ResolveWheelModifiers(handEdited) ==
            KeyModifiers.None,
            "a hand-edited key gesture disables quick scroll instead of hijacking the wheel");

        var handEditedZoom = new WindowsEditorShortcutSettings(
            new Dictionary<string, string> { ["WheelZoom"] = "F8" });
        Require(
            WindowsEditorShortcutGesture.ResolveWheelModifiers(handEditedZoom, "WheelZoom") ==
            KeyModifiers.None,
            "the same guard applies to zoom: a stray key cannot make the wheel zoom");
    }

    private static void VerifyRangeCopySettingRoundTrips()
    {
        var defaults = WindowsEditorViewSettings.Default;
        Require(!defaults.QuickRangeCopy, "quick range copy is off by default");
        Require(
            defaults.UnsnapScrollDivision == 8,
            $"the Un-snap wheel step defaults to 1/8 (got {defaults.UnsnapScrollDivision})");

        var enabled = defaults.WithQuickRangeCopy(true);
        Require(
            enabled.QuickRangeCopy &&
            enabled.UnsnapScrollDivision == defaults.UnsnapScrollDivision &&
            enabled.SnapDivision == defaults.SnapDivision,
            "enabling range copy leaves the neighbouring settings untouched");
        Require(
            !enabled.WithQuickRangeCopy(false).QuickRangeCopy,
            "it can be turned back off");
        Require(
            enabled.WithUnsnapScrollDivision(16).QuickRangeCopy,
            "changing an unrelated setting does not silently drop the flag");

        const string variable = "LUMACHART_AVALONIA_LOCAL_DATA_ROOT";
        var previous = Environment.GetEnvironmentVariable(variable);
        var root = Path.Combine(
            Path.GetTempPath(),
            "lumachart-wheel-range-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);
        try
        {
            Environment.SetEnvironmentVariable(variable, root);
            WindowsEditorViewSettingsStore.Save(
                enabled.WithUnsnapScrollDivision(16));
            var loaded = WindowsEditorViewSettingsStore.Load();
            Require(
                loaded.QuickRangeCopy,
                "the switch survives a save/load round trip");
            Require(
                loaded.UnsnapScrollDivision == 16,
                $"the Un-snap wheel step survives alongside it (got {loaded.UnsnapScrollDivision})");
        }
        finally
        {
            Environment.SetEnvironmentVariable(variable, previous);
            try
            {
                Directory.Delete(root, recursive: true);
            }
            catch
            {
                // A leftover temp directory must not fail the run.
            }
        }
    }

    private static int Count;

    private static void Require(bool condition, string message)
    {
        Count++;
        if (condition)
        {
            Console.WriteLine($"  ok    {message}");
            return;
        }
        Console.WriteLine($"  FAIL  {message}");
        throw new InvalidOperationException(
            "Wheel quick-scroll / range-copy contract failed: " + message);
    }
}
