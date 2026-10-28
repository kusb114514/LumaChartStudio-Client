using Foundation;
using LumaChart.Avalonia.Services;
using UIKit;

namespace LumaChart.iOS.Platform;

/// <summary>
/// Opens community, feedback and osu! OAuth links in the system browser.
/// </summary>
internal sealed class IOSExternalUriService : IPlatformExternalUriService
{
    public Task OpenExternalUriAsync(Uri uri, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(uri);
        cancellationToken.ThrowIfCancellationRequested();

        // Only web links are ever handed to the system opener. A file: or
        // custom-scheme URI reaching here would be a shared-code bug, and
        // forwarding it blindly hands an arbitrary scheme to another app.
        if (!uri.IsAbsoluteUri ||
            (!string.Equals(uri.Scheme, Uri.UriSchemeHttp, StringComparison.OrdinalIgnoreCase) &&
             !string.Equals(uri.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase)))
            throw new InvalidOperationException($"Refusing to open a non-web URI: {uri.Scheme}.");

        var completion = new TaskCompletionSource<bool>(
            TaskCreationOptions.RunContinuationsAsynchronously);

        UIApplication.SharedApplication.InvokeOnMainThread(() =>
        {
            try
            {
                using var url = new NSUrl(uri.AbsoluteUri);
                UIApplication.SharedApplication.OpenUrl(
                    url,
                    new UIApplicationOpenUrlOptions(),
                    success => completion.TrySetResult(success));
            }
            catch (Exception exception)
            {
                // Wrapped, not passed through. Both call sites catch this with a
                // filter — `when (exception is InvalidOperationException or
                // Win32Exception)` — so a raw UIKit exception slips past them and
                // becomes an unobserved task fault: no crash, but also no
                // "无法打开系统浏览器" for the user, just a link that does nothing.
                completion.TrySetException(new InvalidOperationException(
                    exception.Message, exception));
            }
        });

        return completion.Task;
    }
}

/// <summary>
/// Whether a password field may use the platform input method.
///
/// This must be true on iOS, and the name is a trap. On Windows the "input
/// method" is the IME composition engine, and WindowsPasswordInputPolicy turns
/// it off so a CJK candidate window never sits over a secret and physical keys
/// commit directly — physical keys still work without it. On iOS the input
/// method <em>is</em> the on-screen keyboard: the flag reaches
/// InputMethod.SetIsInputMethodEnabled, and with it false, focusing the
/// password box raises no keyboard at all and the field cannot be typed into.
///
/// It was false here originally, on the reasoning that iOS presents its own
/// secure-entry keyboard so the Windows workaround was unnecessary. That is
/// true of the workaround and false of the flag. Android has always set true.
/// </summary>
internal sealed class IOSTextInputService : IPlatformTextInputService
{
    public bool EnablePasswordInputMethod => true;
}
