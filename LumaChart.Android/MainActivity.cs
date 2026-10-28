using Android.App;
using Android.Content;
using Android.Content.PM;
using Android.OS;
using Avalonia.Android;
using AndroidX.Core.View;
using LumaChart.Avalonia;
using LumaChart.Avalonia.Infrastructure;
using LumaChart.Android.Platform;

namespace LumaChart.Android;

[Activity(
    Name = "cc.lumachart.studio.MainActivity",
    Label = "LumaChart Studio",
    Theme = "@style/MyTheme.NoActionBar",
    Icon = "@drawable/icon",
    MainLauncher = true,
    ScreenOrientation = ScreenOrientation.Landscape,
    // Every change listed here is handled in place instead of by destroying and
    // recreating the activity. Recreation cancels a document picker that is on
    // screen, so attaching a keyboard to a tablet, changing the system language,
    // display size or font size, or switching dark mode while choosing a chart
    // lost the pick. Avalonia's view takes these through its own
    // OnConfigurationChanged and re-reads the surface size and density.
    ConfigurationChanges = ConfigChanges.Orientation |
                           ConfigChanges.ScreenSize |
                           ConfigChanges.SmallestScreenSize |
                           ConfigChanges.ScreenLayout |
                           ConfigChanges.UiMode |
                           ConfigChanges.Keyboard |
                           ConfigChanges.KeyboardHidden |
                           ConfigChanges.Navigation |
                           ConfigChanges.Locale |
                           ConfigChanges.LayoutDirection |
                           ConfigChanges.Density |
                           ConfigChanges.FontScale)]
public sealed class MainActivity : AvaloniaMainActivity
{
    protected override void OnCreate(Bundle? savedInstanceState)
    {
        AndroidTabletPlatformServices.AttachActivity(this);
        base.OnCreate(savedInstanceState);
        RequestHighestDisplayMode();
        ApplyImmersiveMode();
    }

    protected override void OnResume()
    {
        base.OnResume();
        ApplyImmersiveMode();
    }

    public override void OnWindowFocusChanged(bool hasFocus)
    {
        base.OnWindowFocusChanged(hasFocus);
        if (hasFocus)
            ApplyImmersiveMode();
    }

    protected override void OnDestroy()
    {
        AndroidTabletPlatformServices.DetachActivity(this);
        base.OnDestroy();
    }

    protected override void OnActivityResult(int requestCode, Result resultCode, Intent? data)
    {
        if (!AndroidTabletPlatformServices.TryCompletePicker(requestCode, resultCode, data))
            base.OnActivityResult(requestCode, resultCode, data);
    }

    /// <summary>
    /// Asks the compositor for the panel's fastest mode at the current
    /// resolution. A 120 Hz panel idles in its 60 Hz mode and does not switch
    /// just because the editor draws faster, so without this the frame cap can
    /// never be reached. The editor's own cap still decides how much is drawn.
    /// </summary>
    private void RequestHighestDisplayMode()
    {
        try
        {
            var window = Window;
            var display = OperatingSystem.IsAndroidVersionAtLeast(30)
                ? Display
                : WindowManager?.DefaultDisplay;
            if (window?.Attributes is not { } attributes || display == null) return;

            var modes = display.GetSupportedModes();
            if (modes == null || modes.Length == 0) return;

            // Only consider the panel's full resolution; a lower-resolution
            // mode with a higher rate would trade sharpness for frames.
            var widest = modes.Max(mode => (long)mode.PhysicalWidth * mode.PhysicalHeight);
            global::Android.Views.Display.Mode? fastest = null;
            foreach (var mode in modes)
            {
                if ((long)mode.PhysicalWidth * mode.PhysicalHeight != widest) continue;
                if (fastest == null || mode.RefreshRate > fastest.RefreshRate)
                    fastest = mode;
            }

            if (fastest == null) return;
            // Some compositors honour the mode id and some only the rate, so
            // state both; a vendor policy may still keep the panel where it is.
            attributes.PreferredDisplayModeId = fastest.ModeId;
            attributes.PreferredRefreshRate = fastest.RefreshRate;
            window.Attributes = attributes;
        }
        catch (Exception)
        {
            // Staying on the compositor's chosen mode is an acceptable fallback.
        }
    }

    private void ApplyImmersiveMode()
    {
        var window = Window;
        if (window?.DecorView is not { } decorView) return;

        WindowCompat.SetDecorFitsSystemWindows(window, false);
        var controller = WindowCompat.GetInsetsController(window, decorView);
        if (controller == null) return;
        controller.SystemBarsBehavior =
            WindowInsetsControllerCompat.BehaviorShowTransientBarsBySwipe;
        controller.Hide(WindowInsetsCompat.Type.SystemBars());
    }
}
