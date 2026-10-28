using UIKit;

namespace LumaChart.iOS.Platform;

/// <summary>
/// Finds the view controller anything modal has to be presented from.
///
/// Shared by the notice service and the file pickers rather than duplicated:
/// getting this wrong is not a cosmetic bug. Presenting on the root controller
/// while it already has a modal child throws, and the shared editor shows its
/// own modal overlays, so "the root" and "what is on screen" routinely differ.
/// </summary>
internal static class IOSViewControllers
{
    public static UIViewController? TryFindPresenter()
    {
        // KeyWindow on UIApplication is deprecated under the scene-based
        // lifecycle iPadOS 26 uses, and returns nothing useful in a multi-window
        // session; the key window has to be found through the connected scenes.
        var window = UIApplication.SharedApplication.ConnectedScenes
            .OfType<UIWindowScene>()
            .SelectMany(scene => scene.Windows)
            .FirstOrDefault(candidate => candidate.IsKeyWindow);

        var controller = window?.RootViewController;
        while (controller?.PresentedViewController != null)
            controller = controller.PresentedViewController;
        return controller;
    }
}
