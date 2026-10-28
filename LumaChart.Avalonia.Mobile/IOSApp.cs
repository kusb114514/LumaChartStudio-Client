using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Styling;
using Avalonia.Themes.Fluent;
using LumaChart.Avalonia.Infrastructure;

namespace LumaChart.Avalonia;

/// <summary>
/// The iOS Avalonia application. It hands the same shared
/// <see cref="MainWindow"/> to the mobile lifetime that Windows and Android
/// run, so the editor surface on iPad is that implementation rather than a
/// mobile re-creation of it.
/// </summary>
public sealed class IOSApp : global::Avalonia.Application
{
    public override void Initialize()
    {
        Styles.Add(new FluentTheme());
        RequestedThemeVariant = ThemeVariant.Dark;
        WindowsWpf110ControlTheme.Apply(this);
    }

    public override void OnFrameworkInitializationCompleted()
    {
        // Avalonia.iOS hands the app an ISingleViewApplicationLifetime — its
        // SingleViewLifetime implements that and ISingleTopLevelApplicationLifetime
        // and nothing else, so there is no view factory to supply here. Setting
        // MainView before the scene connects is safe: the lifetime re-applies it
        // when Avalonia's own view is created.
        if (ApplicationLifetime is ISingleViewApplicationLifetime singleView)
        {
            var view = new MainWindow(Array.Empty<string>());
            singleView.MainView = view;
            view.InitializeEmbedded();
        }

        base.OnFrameworkInitializationCompleted();
    }
}
