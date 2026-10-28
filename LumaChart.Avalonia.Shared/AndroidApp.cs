using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Styling;
using Avalonia.Themes.Fluent;
using LumaChart.Avalonia.Infrastructure;

namespace LumaChart.Avalonia;

public sealed class AndroidApp : global::Avalonia.Application
{
    public override void Initialize()
    {
        Styles.Add(new FluentTheme());
        RequestedThemeVariant = ThemeVariant.Dark;
        WindowsWpf110ControlTheme.Apply(this);
    }

    public override void OnFrameworkInitializationCompleted()
    {
        if (ApplicationLifetime is ISingleViewApplicationLifetime singleView)
        {
            var view = new MainWindow(Array.Empty<string>());
            singleView.MainView = view;
            view.InitializeEmbedded();
        }

        base.OnFrameworkInitializationCompleted();
    }
}

public sealed class MainView : global::Avalonia.Controls.UserControl { }
