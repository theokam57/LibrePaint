using Avalonia;
using Avalonia.ReactiveUI;
using LibrePaint.Views;

namespace LibrePaint.Desktop;

public static class Program
{
    public static void Main(string[] args) => BuildAvaloniaApp().StartWithClassicDesktopLifetime(args);

    public static AppBuilder BuildAvaloniaApp()
        => AppBuilder.Configure<App>()
            .UsePlatformDetect()
            .WithInterFont()
            .LogToTrace()
            .UseReactiveUI();
}
