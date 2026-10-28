using Android.App;
using Android.Hardware.Display;
using Android.Runtime;
using Avalonia;
using Avalonia.Android;
using LumaChart.Application.Archives;
using LumaChart.Avalonia;
using LumaChart.Avalonia.Audio;
using LumaChart.Avalonia.Infrastructure;
using LumaChart.Avalonia.Services;
using LumaChart.Android.Platform;

namespace LumaChart.Android;

[Application]
public sealed class Application : AvaloniaAndroidApplication<AndroidApp>
{
    public Application(nint javaReference, JniHandleOwnership transfer)
        : base(javaReference, transfer)
    {
        // Must run before the shared MainWindow is built: the settings panel
        // fills its frame-rate list once, during construction.
        ReportDisplayRefreshRate(this);
        var locations = new AndroidAppStorageLocations(this);
        AvaloniaAppPaths.RegisterLocations(locations);
        // Android kills the process instead of shutting it down, so the desktop
        // shutdown cleanup never runs here and each launch used to leave its
        // session_<pid> scratch tree behind. Earlier sessions are reclaimed at
        // start instead, off the startup path.
        locations.PruneEarlierSessionScratchInBackground();
        // Copying the 53 MB corpus out of the APK used to happen right here, on
        // the main thread and unguarded: a full disk or an unavailable volume
        // threw on every launch and the app never opened. Only romanization
        // needs it, so it is published when ready and a failure leaves just
        // that feature unavailable.
        AndroidDictionaryAssets.PublishWhenReady(this, locations.ResourceCache);
        var platform = new AndroidTabletPlatformServices(this, locations);
        // Key-sound preview goes through the shared runtime, the same path
        // Windows uses. It reaches the device through the AudioTrack factory
        // above, so Android no longer needs a private preview implementation.
        PlatformAudioOutputs.Current = new AndroidAudioOutputFactory(this);
        PlatformSessionTokenStores.Current = new AndroidKeystoreSessionTokenStore(locations);
        PlatformArchiveDirectoryCreators.Current = ManagedArchiveDirectoryCreator.Instance;
        AndroidTabletPlatformServices.Current = platform;
        PlatformFileImportServices.Current = platform;
        PlatformFileExportServices.Current = platform;
        PlatformNoticeServices.Current = new AndroidNoticeService();
        PlatformExternalUriServices.Current = platform;
        PlatformTextInputServices.Current = platform;
    }

    // The embedded Simplified-Chinese face is made the default and the glyph
    // fallback here. Without it, Chinese text depended on the device's own font
    // set and rendered as nothing on some OEM ROMs — see MobileFontConfiguration.
    //
    // The dispatcher guard goes in after setup, because the UI dispatcher does
    // not exist before it — the same place the iOS host installs its own.
    protected override AppBuilder CustomizeAppBuilder(AppBuilder builder) =>
        base.CustomizeAppBuilder(builder)
            .WithEmbeddedChineseFont()
            .AfterSetup(_ => AndroidDispatcherExceptionGuard.Install());

    /// <summary>
    /// Publishes the panel refresh rate so the editor never offers or applies a
    /// frame cap the display cannot present. Asking for more than the panel
    /// rate paces worse than matching it, and the top preset drives a frame
    /// pump that takes the Android render thread down.
    /// </summary>
    private static void ReportDisplayRefreshRate(global::Android.Content.Context context)
    {
        try
        {
            var manager = context.GetSystemService(DisplayService) as DisplayManager;
            var display = manager?.GetDisplay(global::Android.Views.Display.DefaultDisplay);
            if (display == null) return;

            // A panel reports whichever mode it currently sits in and idles at
            // a lower one, so take the highest mode it supports; otherwise a
            // 120 Hz screen resting at 60 would be capped to 60.
            var refreshRate = display.RefreshRate;
            foreach (var mode in display.GetSupportedModes() ?? [])
                refreshRate = Math.Max(refreshRate, mode.RefreshRate);
            if (float.IsFinite(refreshRate) && refreshRate > 0)
                PlatformDisplayRefreshRates.Current = refreshRate;
        }
        catch (Exception)
        {
            // With no reported rate the editor keeps the full preset list.
        }
    }
}
