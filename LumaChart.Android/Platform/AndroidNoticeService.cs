using Android.App;
using LumaChart.Avalonia.Services;

namespace LumaChart.Android.Platform;

/// <summary>
/// Shows the editor's one-way notices as a native dialog. The shared code path
/// is the same one that raises a Windows message box; without this the notices
/// were discarded and operations appeared to finish with no result at all.
/// </summary>
internal sealed class AndroidNoticeService : IPlatformNoticeService
{
    public void Show(string caption, string message, PlatformNoticeSeverity severity)
    {
        if (string.IsNullOrWhiteSpace(message)) return;
        var activity = AndroidTabletPlatformServices.CurrentActivity;
        if (activity == null) return;

        activity.RunOnUiThread(() =>
        {
            try
            {
                if (activity.IsFinishing || activity.IsDestroyed) return;
                using var builder = new AlertDialog.Builder(activity);
                builder.SetTitle(string.IsNullOrWhiteSpace(caption)
                    ? ResolveFallbackTitle(severity)
                    : caption);
                builder.SetMessage(message);
                builder.SetCancelable(true);
                builder.SetPositiveButton("确定", (_, _) => { });
                builder.Show();
            }
            catch (Exception)
            {
                // A notice must never take the editor down with it; the status
                // line still carries the same text.
            }
        });
    }

    private static string ResolveFallbackTitle(PlatformNoticeSeverity severity) => severity switch
    {
        PlatformNoticeSeverity.Error => "操作失败",
        PlatformNoticeSeverity.Warning => "注意",
        PlatformNoticeSeverity.Question => "请确认",
        _ => "提示"
    };
}
