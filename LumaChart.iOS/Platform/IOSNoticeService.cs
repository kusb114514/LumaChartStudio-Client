using Avalonia.Threading;
using LumaChart.Avalonia.Services;
using UIKit;

namespace LumaChart.iOS.Platform;

/// <summary>
/// Presents the editor's one-way notices as a <see cref="UIAlertController"/>.
/// The shared editor raises these from wherever an export, import or recovery
/// finished, so the call is marshalled to the UI thread here rather than at
/// every call site.
/// </summary>
internal sealed class IOSNoticeService : IPlatformNoticeService
{
    public void Show(string caption, string message, PlatformNoticeSeverity severity)
    {
        // Severity has no separate iOS presentation; it is folded into the
        // title so the user still sees which kind of notice this is.
        var title = severity switch
        {
            PlatformNoticeSeverity.Error => string.IsNullOrWhiteSpace(caption) ? "错误" : caption,
            PlatformNoticeSeverity.Warning => string.IsNullOrWhiteSpace(caption) ? "警告" : caption,
            PlatformNoticeSeverity.Question => string.IsNullOrWhiteSpace(caption) ? "确认" : caption,
            _ => string.IsNullOrWhiteSpace(caption) ? "提示" : caption
        };

        if (Dispatcher.UIThread.CheckAccess()) Present(title, message);
        else Dispatcher.UIThread.Post(() => Present(title, message));
    }

    private static void Present(string title, string message)
    {
        try
        {
            var controller = IOSViewControllers.TryFindPresenter();
            if (controller == null) return;

            var alert = UIAlertController.Create(title, message, UIAlertControllerStyle.Alert);
            alert.AddAction(UIAlertAction.Create("好", UIAlertActionStyle.Default, null));
            controller.PresentViewController(alert, animated: true, completionHandler: null);
        }
        catch (Exception)
        {
            // A notice that cannot be presented must not take down the editor
            // operation that raised it.
        }
    }
}
