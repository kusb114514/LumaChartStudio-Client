using Avalonia;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.iOS;
using Avalonia.Platform.Storage;
using Foundation;
using LumaChart.Application.Archives;
using LumaChart.Avalonia;
using LumaChart.Avalonia.Audio;
using LumaChart.Avalonia.Infrastructure;
using LumaChart.Avalonia.Services;
using LumaChart.iOS.Platform;
using UIKit;

namespace LumaChart.iOS;

/// <summary>
/// iOS host entry point. Every platform seam is registered once, before the
/// shared MainWindow is built, so the editor source itself never has to ask
/// which operating system it is on — the same arrangement
/// <c>LumaChart.Android.Application</c> uses.
/// </summary>
[Register(nameof(AppDelegate))]
public sealed class AppDelegate : AvaloniaAppDelegate<IOSApp>
{
    private static IOSFileTransferServices? fileTransfers;

    public AppDelegate() => IOSLaunchLog.Write("AppDelegate: constructed");

    /// <summary>
    /// "Open with LumaChart", from Files, a browser, a chat app or anywhere else
    /// that can share a document.
    ///
    /// Avalonia already owns <c>application:openURL:options:</c> — its own
    /// handler is not virtual — and turns a file URL into a FileActivatedEventArgs
    /// on this delegate's Activated event, so subscribing is both the supported
    /// route and the one that covers a cold launch as well as a running app.
    ///
    /// The bytes are copied here and now, and the open is queued rather than
    /// performed: see <see cref="IOSFileTransferServices.TryAcceptIncomingFile"/>
    /// for why the URL cannot be kept, and <see cref="PlatformIncomingFiles"/>
    /// for why the editor may not exist yet.
    /// </summary>
    private void ObserveIncomingFiles()
    {
        ((IAvaloniaAppDelegate)this).Activated += (_, args) =>
        {
            if (args is not FileActivatedEventArgs files) return;
            foreach (var file in files.Files)
            {
                var localPath = file.TryGetLocalPath();
                if (string.IsNullOrWhiteSpace(localPath)) continue;

                IOSLaunchLog.Write($"incoming file: {Path.GetFileName(localPath)}");
                var accepted = fileTransfers?.TryAcceptIncomingFile(
                    NSUrl.FromFilename(localPath));
                if (!string.IsNullOrWhiteSpace(accepted))
                    PlatformIncomingFiles.Deliver(accepted);
            }
        };
    }

    /// <summary>
    /// Registration happens here rather than in the constructor. The base
    /// delegate calls this while configuring Avalonia and only creates the
    /// application — and therefore the shared MainWindow — afterwards, so every
    /// seam is in place before the editor is built. The constructor runs while
    /// UIKit is still bringing the process up, which is a needlessly fragile
    /// place to touch the file system and the screen.
    /// </summary>
    protected override AppBuilder CustomizeAppBuilder(AppBuilder builder)
    {
        RegisterPlatformSeams();
        ObserveIncomingFiles();

        // Avalonia reports render failures through its own logger and nowhere
        // else: DefaultRenderLoop.TimerTick wraps every frame in a catch that
        // logs "Exception in render loop", and no sink is installed by default.
        // A render task that throws on every tick is then completely silent —
        // no crash, nothing in the device log, an idle GPU and a black screen.
        // That is exactly how the 1.2.0.9 black screen hid a per-frame
        // ExecutionEngineException for several rounds, so the bridge is part of
        // the shipping app rather than something added when trouble starts.
        AvaloniaLogBridge.Install();

        IOSLaunchLog.Write("CustomizeAppBuilder: configuring Avalonia");

        // WithInterFont supplies the embedded default typeface. Avalonia's own
        // iOS template does this; without it nothing rendered on device at all.
        // WithEmbeddedChineseFont then makes a bundled Simplified-Chinese face
        // the default and the glyph fallback, so CJK text does not depend on the
        // device's own fonts — the same fix Android needs (see
        // MobileFontConfiguration).
        var configured = base.CustomizeAppBuilder(builder)
            .WithInterFont()
            .WithEmbeddedChineseFont();

        // OpenGl is pinned deliberately, not left at Avalonia's Metal-first
        // default. It is the backend the editor has actually been seen to
        // render with on iPadOS 26, against the two fixes carried in the
        // patched Avalonia assemblies (see LumaChart.iOS.csproj). Both backends
        // were affected by the off-main-thread layer refusal and both should be
        // fixed by moving rendering onto the main thread, but the Metal path
        // writes CAMetalLayer.Device and DrawableSize of its own and has not
        // been tried since. Switching to it is a deliberate experiment with its
        // own device run, not a default to drift into.
        configured = configured.With(new iOSPlatformOptions
        {
            RenderingMode = [iOSRenderingMode.OpenGl]
        });

        // After setup, because the UI dispatcher does not exist before it. See
        // IOSDispatcherExceptionGuard for why this is a seam and not an audit.
        configured = configured.AfterSetup(_ => IOSDispatcherExceptionGuard.Install());

        IOSLaunchLog.Write("CustomizeAppBuilder: configured, OpenGl rendering");
        return configured;
    }

    private static void RegisterPlatformSeams()
    {
        // Must run before the shared MainWindow is constructed: the settings
        // panel fills its frame-rate list once, during construction.
        IOSLaunchLog.Write("seam: display refresh rate");
        ReportDisplayRefreshRate();

        IOSLaunchLog.Write("seam: storage locations");
        var locations = new IOSAppStorageLocations();
        AvaloniaAppPaths.RegisterLocations(locations);
        IOSLaunchLog.Write($"seam: storage locations -> library={locations.Library}");
        // The desktop removes its scratch tree on shutdown; iOS never shuts the
        // app down that way, so earlier sessions are reclaimed here instead.
        locations.PruneEarlierSessionScratchInBackground();

        IOSLaunchLog.Write("seam: japanese romanization dictionary");
        PlatformJapaneseRomanizationServices.DictionaryRoot = IOSDictionaryAssets.Locate();

        IOSLaunchLog.Write("seam: session token store");
        PlatformSessionTokenStores.Current = new IOSKeychainSessionTokenStore();

        IOSLaunchLog.Write("seam: archive directory creator");
        PlatformArchiveDirectoryCreators.Current = ManagedArchiveDirectoryCreator.Instance;

        IOSLaunchLog.Write("seam: notices");
        PlatformNoticeServices.Current = new IOSNoticeService();

        IOSLaunchLog.Write("seam: external uri");
        PlatformExternalUriServices.Current = new IOSExternalUriService();

        IOSLaunchLog.Write("seam: text input");
        PlatformTextInputServices.Current = new IOSTextInputService();

        IOSLaunchLog.Write("seam: audio output");
        PlatformAudioOutputs.Current = new IOSAudioOutputFactory();

        IOSLaunchLog.Write("seam: file import and export");
        var transfers = new IOSFileTransferServices(locations);
        PlatformFileImportServices.Current = transfers;
        PlatformFileExportServices.Current = transfers;
        fileTransfers = transfers;

        IOSLaunchLog.Write("seam: all registered");
    }

    /// <summary>
    /// Publishes the panel refresh rate so the editor never offers or applies a
    /// frame cap the display cannot present. ProMotion iPads report 120 here
    /// while a non-ProMotion device reports 60.
    /// </summary>
    private static void ReportDisplayRefreshRate()
    {
        try
        {
            var rate = (double)UIScreen.MainScreen.MaximumFramesPerSecond;
            if (double.IsFinite(rate) && rate > 0)
                PlatformDisplayRefreshRates.Current = rate;
        }
        catch (Exception)
        {
            // With no reported rate the editor keeps the full preset list.
        }
    }
}
