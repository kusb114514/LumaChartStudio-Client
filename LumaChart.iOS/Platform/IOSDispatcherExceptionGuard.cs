using Avalonia.Threading;
using LumaChart.Avalonia.Services;

namespace LumaChart.iOS.Platform;

/// <summary>
/// Stops one bad event handler from killing the editor.
///
/// The shared editor wires its UI through roughly a hundred and sixty handlers
/// shaped like <c>async (_, _) =&gt; await SomethingAsync()</c>. Those compile to
/// <c>async void</c>: an exception escaping one is unhandled by definition, and
/// on iOS an unhandled exception is not a dialog, it is <c>abort()</c>. Choosing
/// the wrong file type in the chart importer did exactly that — an ordinary
/// mistake took the whole app down, with the only trace being a crash report
/// carrying no managed stack.
///
/// Auditing every one of those call sites would fix the ones known today and
/// nothing written tomorrow. Avalonia offers a single seam instead: the
/// dispatcher only catches at all when something is listening —
///
///   var requestCatch = UnhandledException is not null;   // Dispatcher.Exceptions.cs
///
/// — so attaching here converts every one of them from a process kill into a
/// logged, reported failure. This is not swallowing errors: the exception is
/// written to the launch log with its type and stack, and the user is told
/// something failed. It only refuses to make the failure fatal.
///
/// Installed by the iOS host alone. Windows keeps Avalonia's default, where an
/// unhandled UI exception is meant to surface as a crash.
/// </summary>
internal static class IOSDispatcherExceptionGuard
{
    /// <summary>
    /// A handler that throws once usually throws again — a broken timer tick can
    /// do it every frame. The log takes all of them; the user is only
    /// interrupted this often.
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
            IOSLaunchLog.WriteException("dispatcher", args.Exception);
            args.Handled = true;
            TryNotify(args.Exception);
        };

        IOSLaunchLog.Write("dispatcher exception guard installed");
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
            // The message is the exception's own. Under UseSystemResourceKeys a
            // BCL message arrives as its resource key rather than a sentence,
            // which is unhelpful but still identifies the failure; anything the
            // editor itself throws carries real text.
            PlatformNoticeServices.Current?.Show(
                "操作失败",
                exception.Message,
                PlatformNoticeSeverity.Error);
        }
        catch (Exception)
        {
            // A guard that throws while reporting would defeat its own purpose.
        }
    }
}
