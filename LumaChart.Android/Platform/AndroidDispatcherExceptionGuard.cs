using Avalonia.Threading;
using LumaChart.Avalonia.Services;
using LumaChart.Core.Localization;

namespace LumaChart.Android.Platform;

/// <summary>
/// Stops one bad event handler from killing the editor — the Android
/// counterpart of <c>IOSDispatcherExceptionGuard</c>, with the same reasoning.
///
/// The shared editor wires its buttons as <c>async (_, _) =&gt; await ...</c>,
/// which compiles to <c>async void</c>: an exception escaping one is unhandled
/// by definition, and on Android that ends the process. Picking a file of the
/// wrong type, tapping Open twice, or the activity being recreated while the
/// picker was up all did exactly that. Avalonia's dispatcher only catches when
/// something listens to <see cref="Dispatcher.UnhandledException"/>, so
/// listening here turns each of them into a logged, reported failure. The
/// exception still reaches logcat with its type and stack, and the user is told
/// something failed; only the process kill is refused.
///
/// Installed by the Android host alone. Windows keeps Avalonia's default, where
/// an unhandled UI exception is meant to surface as a crash.
/// </summary>
internal static class AndroidDispatcherExceptionGuard
{
    private const string LogTag = "LumaChart";

    /// <summary>
    /// A handler that throws once usually throws again — a broken timer tick can
    /// do it every frame. Logcat takes all of them; the user is only interrupted
    /// this often.
    /// </summary>
    private static readonly TimeSpan NoticeInterval = TimeSpan.FromSeconds(20);

    private static readonly object Gate = new();
    private static DateTimeOffset lastNotice = DateTimeOffset.MinValue;
    private static bool installed;

    public static void Install()
    {
        lock (Gate)
        {
            if (installed) return;
            installed = true;
        }

        Dispatcher.UIThread.UnhandledException += (_, args) =>
        {
            Log(args.Exception);
            args.Handled = true;
            // A cancelled operation is not a failure the user needs told about;
            // it is usually the user's own doing, or the activity going away.
            if (args.Exception is not System.OperationCanceledException)
                TryNotify(args.Exception);
        };

        global::Android.Util.Log.Info(LogTag, "dispatcher exception guard installed");
    }

    /// <summary>
    /// Type and stack first, then the full text: the same order the iOS log uses,
    /// so that if formatting the message fails the culprit is already recorded.
    /// </summary>
    private static void Log(Exception exception)
    {
        try
        {
            global::Android.Util.Log.Error(
                LogTag,
                $"Unhandled UI exception: {exception.GetType().FullName}{Environment.NewLine}" +
                (exception.StackTrace ?? "(no stack)"));
            global::Android.Util.Log.Error(LogTag, exception.ToString());
        }
        catch (Exception)
        {
            // Logging must never be the reason the guard fails.
        }
    }

    private static void TryNotify(Exception exception)
    {
        lock (Gate)
        {
            var now = DateTimeOffset.UtcNow;
            if (now - lastNotice < NoticeInterval) return;
            lastNotice = now;
        }

        try
        {
            // Editor code throws Chinese source text, which the catalog can
            // translate; anything else is shown as it came.
            PlatformNoticeServices.Current?.Show(
                LocalizationCatalog.Text("操作失败"),
                LocalizationCatalog.Text(exception.Message),
                PlatformNoticeSeverity.Error);
        }
        catch (Exception)
        {
            // A guard that throws while reporting would defeat its own purpose.
        }
    }
}
