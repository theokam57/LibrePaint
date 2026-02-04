using Avalonia;
using Avalonia.Markup.Xaml;

namespace LibrePaint.Desktop;

public partial class App : Application
{
    public override void Initialize() => AvaloniaXamlLoader.Load(this);
}
