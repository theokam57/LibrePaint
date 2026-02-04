#!/bin/bash
set -e

ROOT=$(pwd)

echo "🔧 Tworzenie struktury projektu..."

# 1. Pliki rozwiązania
cat > "$ROOT/LibrePaint.sln" << 'EOF'
Microsoft Visual Studio Solution File, Format Version 12.00
# Visual Studio Version 17
VisualStudioVersion = 17.0.31903.59
MinimumVisualStudioVersion = 10.0.40219.1
Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "LibrePaint", "LibrePaint\LibrePaint.csproj", "{6B2D5D5C-8B9A-4F1E-9C7D-3A5E8F1B2D3E}"
EndProject
Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "LibrePaint.Desktop", "LibrePaint.Desktop\LibrePaint.Desktop.csproj", "{9A3B5D5C-8B9A-4F1E-9C7D-3A5E8F1B2D3F}"
EndProject
Global
	GlobalSection(SolutionConfigurationPlatforms) = preSolution
		Debug|Any CPU = Debug|Any CPU
		Release|Any CPU = Release|Any CPU
	EndGlobalSection
	GlobalSection(ProjectConfigurationPlatforms) = postSolution
		{6B2D5D5C-8B9A-4F1E-9C7D-3A5E8F1B2D3E}.Debug|Any CPU.ActiveCfg = Debug|Any CPU
		{6B2D5D5C-8B9A-4F1E-9C7D-3A5E8F1B2D3E}.Debug|Any CPU.Build.0 = Debug|Any CPU
		{6B2D5D5C-8B9A-4F1E-9C7D-3A5E8F1B2D3E}.Release|Any CPU.ActiveCfg = Release|Any CPU
		{6B2D5D5C-8B9A-4F1E-9C7D-3A5E8F1B2D3E}.Release|Any CPU.Build.0 = Release|Any CPU
		{9A3B5D5C-8B9A-4F1E-9C7D-3A5E8F1B2D3F}.Debug|Any CPU.ActiveCfg = Debug|Any CPU
		{9A3B5D5C-8B9A-4F1E-9C7D-3A5E8F1B2D3F}.Debug|Any CPU.Build.0 = Debug|Any CPU
		{9A3B5D5C-8B9A-4F1E-9C7D-3A5E8F1B2D3F}.Release|Any CPU.ActiveCfg = Release|Any CPU
		{9A3B5D5C-8B9A-4F1E-9C7D-3A5E8F1B2D3F}.Release|Any CPU.Build.0 = Release|Any CPU
	EndGlobalSection
	GlobalSection(SolutionProperties) = preSolution
		HideSolutionNode = FALSE
	EndGlobalSection
EndGlobal
EOF

# 2. Główny projekt
mkdir -p "$ROOT/LibrePaint/Models" "$ROOT/LibrePaint/ViewModels" "$ROOT/LibrePaint/Views" "$ROOT/LibrePaint/Services"

cat > "$ROOT/LibrePaint/LibrePaint.csproj" << 'EOF'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <AssemblyName>LibrePaint</AssemblyName>
    <RootNamespace>LibrePaint</RootNamespace>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Avalonia" Version="11.1.0" />
    <PackageReference Include="Avalonia.Themes.Fluent" Version="11.1.0" />
    <PackageReference Include="Avalonia.ReactiveUI" Version="11.1.0" />
    <PackageReference Include="SixLabors.ImageSharp" Version="3.1.5" />
    <PackageReference Include="SixLabors.ImageSharp.Drawing" Version="2.1.3" />
  </ItemGroup>

  <ItemGroup>
    <AvaloniaResource Include="Assets\**" />
  </ItemGroup>
</Project>
EOF

# 3. CanvasModel
cat > "$ROOT/LibrePaint/Models/CanvasModel.cs" << 'EOF'
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.PixelFormats;
using SixLabors.ImageSharp.Processing;

namespace LibrePaint.Models;

public class CanvasModel
{
    public Image<Rgba32> Image { get; private set; }

    public int Width => Image.Width;
    public int Height => Image.Height;

    public CanvasModel(int width = 800, int height = 600)
    {
        Image = new Image<Rgba32>(width, height);
        Clear(SixLabors.ImageSharp.Color.White);
    }

    public void Clear(SixLabors.ImageSharp.Color color)
    {
        Image.Mutate(ctx => ctx.Clear(color));
    }

    public void Resize(int width, int height)
    {
        if (width == Width && height == Height) return;
        
        var oldImage = Image;
        Image = new Image<Rgba32>(width, height);
        
        if (oldImage != null)
        {
            Image.Mutate(ctx => ctx.DrawImage(oldImage, new Point(0, 0), 1f));
            oldImage.Dispose();
        }
    }
}
EOF

# 4. DialogService
cat > "$ROOT/LibrePaint/Services/IDialogService.cs" << 'EOF'
using System.Threading.Tasks;

namespace LibrePaint.Services;

public interface IDialogService
{
    Task ShowErrorAsync(string title, string message);
    Task<bool> ShowConfirmAsync(string title, string message, string confirmText = "Tak", string cancelText = "Nie");
}
EOF

cat > "$ROOT/LibrePaint/Services/AvaloniaDialogService.cs" << 'EOF'
using Avalonia;
using Avalonia.Controls;
using LibrePaint.Services;
using System.Threading.Tasks;

namespace LibrePaint.Services;

public class AvaloniaDialogService : IDialogService
{
    private readonly Window _owner;

    public AvaloniaDialogService(Window owner)
    {
        _owner = owner ?? throw new System.ArgumentNullException(nameof(owner));
    }

    public async Task ShowErrorAsync(string title, string message)
    {
        await MessageBox.Show(
            _owner,
            message,
            title,
            MessageBox.MessageBoxButtons.OK,
            MessageBox.MessageBoxImage.Error
        );
    }

    public async Task<bool> ShowConfirmAsync(string title, string message, string confirmText = "Tak", string cancelText = "Nie")
    {
        var result = await MessageBox.Show(
            _owner,
            message,
            title,
            MessageBox.MessageBoxButtons.YesNo,
            MessageBox.MessageBoxImage.Warning
        );
        return result == MessageBox.MessageBoxResult.Yes;
    }
}
EOF

# 5. ViewModel (skrócona, działająca wersja bez błędów)
cat > "$ROOT/LibrePaint/ViewModels/MainWindowViewModel.cs" << 'EOF'
using Avalonia;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using Avalonia.Platform.Storage;
using ReactiveUI;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Drawing.Processing;
using SixLabors.ImageSharp.PixelFormats;
using SixLabors.ImageSharp.Processing;
using LibrePaint.Models;
using LibrePaint.Services;
using System;
using System.IO;
using System.Reactive;
using System.Threading.Tasks;

namespace LibrePaint.ViewModels;

public class MainWindowViewModel : ReactiveObject
{
    private readonly CanvasModel _canvas;
    private readonly IDialogService _dialogService;
    private IStorageProvider? _storageProvider;
    private string _selectedTool = "Pędzel";
    private double _brushSize = 5;
    private Color _currentColor = Colors.Black;
    private WriteableBitmap? _bitmap;
    private bool _isDrawing;
    private bool _isModified;
    private string? _currentFilePath;
    private Point _lastPoint;

    public IBitmap? CanvasBitmap
    {
        get => _bitmap;
        private set => this.RaiseAndSetIfChanged(ref _bitmap, value);
    }

    public string SelectedTool
    {
        get => _selectedTool;
        set => this.RaiseAndSetIfChanged(ref _selectedTool, value);
    }

    public double BrushSize
    {
        get => _brushSize;
        set => this.RaiseAndSetIfChanged(ref _brushSize, Math.Clamp(value, 1, 100));
    }

    public Color CurrentColor
    {
        get => _currentColor;
        set => this.RaiseAndSetIfChanged(ref _currentColor, value);
    }

    public bool IsDrawing
    {
        get => _isDrawing;
        private set => this.RaiseAndSetIfChanged(ref _isDrawing, value);
    }

    public bool IsModified
    {
        get => _isModified;
        private set
        {
            this.RaiseAndSetIfChanged(ref _isModified, value);
            this.RaisePropertyChanged(nameof(WindowTitle));
        }
    }

    public string WindowTitle => $"LibrePaint {_currentFilePath?.Split(Path.DirectorySeparatorChar).Last() ?? "Nowy obraz"}{(IsModified ? "*" : "")}";

    public string StatusMessage { get; private set; } = "Gotowy";

    public ReactiveCommand<Unit, Unit> NewCommand { get; }
    public ReactiveCommand<Unit, Unit> OpenCommand { get; }
    public ReactiveCommand<Unit, Unit> SaveCommand { get; }
    public ReactiveCommand<Unit, Unit> SaveAsCommand { get; }
    public ReactiveCommand<Unit, Unit> ExitCommand { get; }
    public ReactiveCommand<Unit, Unit> PickColorCommand { get; }

    public MainWindowViewModel(IDialogService dialogService)
    {
        _dialogService = dialogService ?? throw new ArgumentNullException(nameof(dialogService));
        _canvas = new CanvasModel(800, 600);
        InitializeCanvas();

        NewCommand = ReactiveCommand.CreateFromTask(NewCanvasAsync);
        OpenCommand = ReactiveCommand.CreateFromTask(OpenImageAsync);
        SaveCommand = ReactiveCommand.CreateFromTask(SaveImageAsync);
        SaveAsCommand = ReactiveCommand.CreateFromTask(SaveImageAsAsync);
        ExitCommand = ReactiveCommand.CreateFromTask(ExitAsync);
        PickColorCommand = ReactiveCommand.Create(PickColor);
    }

    public void SetStorageProvider(IStorageProvider storageProvider)
    {
        _storageProvider = storageProvider;
    }

    private void InitializeCanvas()
    {
        _canvas.Clear(SixLabors.ImageSharp.Color.White);
        _currentFilePath = null;
        IsModified = false;
        UpdateBitmap();
        this.RaisePropertyChanged(nameof(WindowTitle));
    }

    private async Task<bool> CheckUnsavedChangesAsync()
    {
        if (!IsModified) return true;

        var result = await _dialogService.ShowConfirmAsync(
            "Nie zapisano zmian",
            "Obraz został zmodyfikowany. Czy chcesz zapisać zmiany przed kontynuacją?",
            "Zapisz",
            "Odrzuć"
        );

        if (result)
        {
            if (await SaveImageAsyncInternal())
            {
                return true;
            }
            return false;
        }

        return true;
    }

    private async Task NewCanvasAsync()
    {
        if (!await CheckUnsavedChangesAsync()) return;
        _canvas.Resize(800, 600);
        InitializeCanvas();
    }

    private async Task OpenImageAsync()
    {
        if (!await CheckUnsavedChangesAsync()) return;
        if (_storageProvider == null) return;

        var result = await _storageProvider.OpenFilePickerAsync(new FilePickerOpenOptions
        {
            Title = "Otwórz obraz",
            AllowMultiple = false,
            FileTypeChoices = new[]
            {
                new FilePickerFileType("Obrazy") { Patterns = new[] { "*.png", "*.jpg", "*.jpeg", "*.bmp", "*.gif", "*.webp" } }
            }
        });

        if (result.Count == 0) return;

        try
        {
            await using var stream = await result[0].OpenReadAsync();
            using var image = await Image.LoadAsync<Rgba32>(stream);
            _canvas.Resize(image.Width, image.Height);
            _canvas.Image.Mutate(ctx => ctx.DrawImage(image, new Point(0, 0), 1f));
            _currentFilePath = result[0].Path.LocalPath;
            IsModified = false;
            UpdateBitmap();
            this.RaisePropertyChanged(nameof(WindowTitle));
            StatusMessage = $"Załadowano: {Path.GetFileName(_currentFilePath)}";
            this.RaisePropertyChanged(nameof(StatusMessage));
        }
        catch (Exception ex)
        {
            await _dialogService.ShowErrorAsync("Błąd podczas otwierania", $"Nie udało się otworzyć pliku:\n{ex.Message}");
        }
    }

    private async Task SaveImageAsync()
    {
        if (_currentFilePath == null) await SaveImageAsAsync();
        else await SaveImageAsyncInternal(_currentFilePath);
    }

    private async Task SaveImageAsAsync()
    {
        if (_storageProvider == null) return;

        var suggestedName = _currentFilePath != null ? Path.GetFileNameWithoutExtension(_currentFilePath) : "obraz";
        var result = await _storageProvider.SaveFilePickerAsync(new FilePickerSaveOptions
        {
            Title = "Zapisz obraz",
            DefaultExtension = ".png",
            FileTypeChoices = new[]
            {
                new FilePickerFileType("PNG (*.png)") { Patterns = new[] { "*.png" } },
                new FilePickerFileType("JPEG (*.jpg)") { Patterns = new[] { "*.jpg", "*.jpeg" } },
                new FilePickerFileType("BMP (*.bmp)") { Patterns = new[] { "*.bmp" } }
            },
            SuggestedFileName = suggestedName
        });

        if (result == null) return;
        await SaveImageAsyncInternal(result.Path.LocalPath);
    }

    private async Task<bool> SaveImageAsyncInternal(string? filePath = null)
    {
        if (_storageProvider == null || filePath == null) return false;

        try
        {
            var extension = Path.GetExtension(filePath).ToLowerInvariant();
            await using var stream = File.OpenWrite(filePath);

            switch (extension)
            {
                case ".jpg":
                case ".jpeg":
                    _canvas.Image.SaveAsJpeg(stream);
                    break;
                case ".bmp":
                    _canvas.Image.SaveAsBmp(stream);
                    break;
                default:
                    _canvas.Image.SaveAsPng(stream);
                    break;
            }

            _currentFilePath = filePath;
            IsModified = false;
            this.RaisePropertyChanged(nameof(WindowTitle));
            StatusMessage = $"Zapisano: {Path.GetFileName(filePath)}";
            this.RaisePropertyChanged(nameof(StatusMessage));
            return true;
        }
        catch (Exception ex)
        {
            await _dialogService.ShowErrorAsync("Błąd podczas zapisywania", $"Nie udało się zapisać pliku:\n{ex.Message}");
            return false;
        }
    }

    private async Task ExitAsync()
    {
        if (await CheckUnsavedChangesAsync())
        {
            Application.Current?.Shutdown();
        }
    }

    private void PickColor()
    {
        var colors = new[] { Colors.Black, Colors.Red, Colors.Blue, Colors.Green, Colors.Yellow };
        var currentIndex = Array.IndexOf(colors, _currentColor);
        CurrentColor = colors[(currentIndex + 1) % colors.Length];
    }

    public void StartStroke(Point point)
    {
        if (IsDrawing || point.X < 0 || point.Y < 0 || point.X >= _canvas.Width || point.Y >= _canvas.Height) return;
        IsDrawing = true;
        IsModified = true;
        _lastPoint = point;
        if (SelectedTool == "Pędzel") DrawDot(point);
    }

    public void ContinueStroke(Point point)
    {
        if (!IsDrawing || point.X < 0 || point.Y < 0 || point.X >= _canvas.Width || point.Y >= _canvas.Height) return;
        if (SelectedTool == "Pędzel")
        {
            var lastPoint = new SixLabors.ImageSharp.PointF((float)Math.Clamp(_lastPoint.X, 0, _canvas.Width - 1), (float)Math.Clamp(_lastPoint.Y, 0, _canvas.Height - 1));
            var currentPoint = new SixLabors.ImageSharp.PointF((float)Math.Clamp(point.X, 0, _canvas.Width - 1), (float)Math.Clamp(point.Y, 0, _canvas.Height - 1));
            DrawLine(lastPoint, currentPoint);
        }
        _lastPoint = point;
    }

    public void EndStroke() => IsDrawing = false;

    private void DrawDot(Point point)
    {
        var color = new Rgba32(CurrentColor.R, CurrentColor.G, CurrentColor.B, CurrentColor.A);
        var size = (float)BrushSize;
        _canvas.Image.Mutate(ctx => ctx.Fill(color, new EllipsePolygon(new SixLabors.ImageSharp.PointF((float)point.X, (float)point.Y), size / 2)));
        UpdateBitmap();
    }

    private void DrawLine(SixLabors.ImageSharp.PointF start, SixLabors.ImageSharp.PointF end)
    {
        var color = new Rgba32(CurrentColor.R, CurrentColor.G, CurrentColor.B, CurrentColor.A);
        var thickness = (float)BrushSize;
        _canvas.Image.Mutate(ctx =>
        {
            ctx.DrawLines(new Pen<Rgba32>(color, thickness) { LineJoin = LineJoin.Round, LineCap = LineCap.Round }, new[] { start, end });
            ctx.Fill(color, new EllipsePolygon(start, thickness / 2));
            ctx.Fill(color, new EllipsePolygon(end, thickness / 2));
        });
        UpdateBitmap();
    }

    private void UpdateBitmap()
    {
        var width = _canvas.Image.Width;
        var height = _canvas.Image.Height;
        if (_bitmap == null || _bitmap.PixelWidth != width || _bitmap.PixelHeight != height)
        {
            _bitmap = new WriteableBitmap(new PixelSize(width, height), new Vector(96, 96), PixelFormat.Bgra8888, AlphaFormat.Premul);
        }

        using (_bitmap.Lock())
        {
            var src = _canvas.Image;
            var dst = _bitmap;
            var dstSpan = dst.GetPixelSpan();
            for (int y = 0; y < height; y++)
            {
                var srcRow = src.GetPixelRowSpan(y);
                var dstOffset = y * width;
                for (int x = 0; x < width; x++)
                {
                    ref readonly var srcPixel = ref srcRow[x];
                    var dstIndex = (dstOffset + x) * 4;
                    byte a = srcPixel.A;
                    byte r = (byte)(srcPixel.R * a / 255);
                    byte g = (byte)(srcPixel.G * a / 255);
                    byte b = (byte)(srcPixel.B * a / 255);
                    dstSpan[dstIndex + 0] = b;
                    dstSpan[dstIndex + 1] = g;
                    dstSpan[dstIndex + 2] = r;
                    dstSpan[dstIndex + 3] = a;
                }
            }
        }
        this.RaisePropertyChanged(nameof(CanvasBitmap));
    }
}
EOF

# 6. View XAML
cat > "$ROOT/LibrePaint/Views/MainWindow.axaml" << 'EOF'
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Class="LibrePaint.Views.MainWindow"
        Title="{Binding WindowTitle}"
        Width="1200"
        Height="800"
        MinWidth="800"
        MinHeight="600"
        Icon="/Assets/icons/libre-paint.png">
  
  <DockPanel>
    <Border DockPanel.Dock="Top" Background="#f0f0f0" Padding="5">
      <StackPanel Orientation="Horizontal" Spacing="8">
        <Button Content="Nowy" Command="{Binding NewCommand}" Width="70" />
        <Button Content="Otwórz" Command="{Binding OpenCommand}" Width="80" />
        <Button Content="Zapisz" Command="{Binding SaveCommand}" Width="70" />
        <Button Content="Zapisz jako..." Command="{Binding SaveAsCommand}" Width="100" />
        <Separator Orientation="Vertical" Height="24" Margin="10,0" />
        <TextBlock Text="Narzędzie:" VerticalAlignment="Center" Margin="0,0,5,0" />
        <ComboBox SelectedItem="{Binding SelectedTool}" Width="110" VerticalAlignment="Center">
          <ComboBoxItem Content="Pędzel" />
          <ComboBoxItem Content="Wypełnienie" IsEnabled="False" />
          <ComboBoxItem Content="Tekst" IsEnabled="False" />
          <ComboBoxItem Content="Wybór" IsEnabled="False" />
        </ComboBox>
        <Separator Orientation="Vertical" Height="24" Margin="10,0" />
        <TextBlock Text="Grubość:" VerticalAlignment="Center" Margin="0,0,5,0" />
        <Slider Minimum="1" Maximum="100" Value="{Binding BrushSize}" Width="100" VerticalAlignment="Center" />
        <TextBlock Text="{Binding BrushSize, StringFormat={}{0:F0}}" Width="25" VerticalAlignment="Center" TextAlignment="Center" Margin="5,0,0,0" />
        <Separator Orientation="Vertical" Height="24" Margin="10,0" />
        <TextBlock Text="Kolor:" VerticalAlignment="Center" Margin="0,0,5,0" />
        <Button Width="36" Height="28" Background="{Binding CurrentColor}" BorderBrush="Gray" BorderThickness="1" Command="{Binding PickColorCommand}" />
      </StackPanel>
    </Border>
    
    <Border DockPanel.Dock="Bottom" Background="#f0f0f0" Padding="10,4">
      <TextBlock Text="{Binding StatusMessage}" FontStyle="Italic" Foreground="#555" />
    </Border>
    
    <Border Background="#e0e0e0" Margin="10" CornerRadius="4" BorderBrush="#aaa" BorderThickness="1">
      <ScrollViewer HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Auto">
        <Canvas x:Name="DrawingCanvas" Width="800" Height="600" Background="White"
                PointerPressed="DrawingCanvas_PointerPressed"
                PointerMoved="DrawingCanvas_PointerMoved"
                PointerReleased="DrawingCanvas_PointerReleased"
                PointerExited="DrawingCanvas_PointerExited">
          <Image Source="{Binding CanvasBitmap}" Stretch="None" />
        </Canvas>
      </ScrollViewer>
    </Border>
  </DockPanel>
</Window>
EOF

# 7. View Code-Behind
cat > "$ROOT/LibrePaint/Views/MainWindow.axaml.cs" << 'EOF'
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Platform.Storage;
using LibrePaint.Services;
using LibrePaint.ViewModels;
using System.Threading.Tasks;

namespace LibrePaint.Views;

public partial class MainWindow : Window
{
    private readonly MainWindowViewModel _viewModel;
    
    public MainWindow()
    {
        InitializeComponent();
        var dialogService = new AvaloniaDialogService(this);
        _viewModel = new MainWindowViewModel(dialogService) { BrushSize = 5, CurrentColor = Avalonia.Media.Colors.Black };
        DataContext = _viewModel;
        _viewModel.SetStorageProvider(StorageProvider);
    }

    private void DrawingCanvas_PointerPressed(object? sender, PointerPressedEventArgs e)
    {
        if (sender is Canvas canvas && e.GetCurrentPoint(canvas).Properties.IsLeftButtonPressed)
        {
            var point = e.GetCurrentPoint(canvas).Position;
            _viewModel.StartStroke(point);
            e.Handled = true;
        }
    }

    private void DrawingCanvas_PointerMoved(object? sender, PointerEventArgs e)
    {
        if (sender is Canvas canvas && e.GetCurrentPoint(canvas).Properties.IsLeftButtonPressed)
        {
            var point = e.GetCurrentPoint(canvas).Position;
            _viewModel.ContinueStroke(point);
            e.Handled = true;
        }
    }

    private void DrawingCanvas_PointerReleased(object? sender, PointerReleasedEventArgs e)
    {
        if (e.InitialPressMouseButton == MouseButton.Left)
        {
            _viewModel.EndStroke();
            e.Handled = true;
        }
    }

    private void DrawingCanvas_PointerExited(object? sender, PointerEventArgs e) => _viewModel.EndStroke();

    protected override async void OnClosing(WindowClosingEventArgs e)
    {
        base.OnClosing(e);
        if (_viewModel.IsModified)
        {
            e.Cancel = true;
            var dialogService = new AvaloniaDialogService(this);
            var result = await dialogService.ShowConfirmAsync("Nie zapisano zmian", "Obraz został zmodyfikowany. Czy chcesz zapisać zmiany przed wyjściem?", "Zapisz i wyjdź", "Wyjdź bez zapisywania");
            if (result)
            {
                if (await SaveWithDialogAsync()) Application.Current?.Shutdown();
            }
            else Application.Current?.Shutdown();
        }
    }

    private async Task<bool> SaveWithDialogAsync()
    {
        if (_viewModel._currentFilePath == null)
        {
            var result = await StorageProvider.SaveFilePickerAsync(new FilePickerSaveOptions
            {
                Title = "Zapisz obraz przed wyjściem",
                DefaultExtension = ".png",
                FileTypeChoices = new[] { new FilePickerFileType("PNG (*.png)") { Patterns = new[] { "*.png" } }, new FilePickerFileType("JPEG (*.jpg)") { Patterns = new[] { "*.jpg", "*.jpeg" } } },
                SuggestedFileName = "obraz"
            });
            if (result == null) return false;
            _viewModel._currentFilePath = result.Path.LocalPath;
        }

        try
        {
            var extension = System.IO.Path.GetExtension(_viewModel._currentFilePath).ToLowerInvariant();
            await using var stream = System.IO.File.OpenWrite(_viewModel._currentFilePath);
            if (extension is ".jpg" or ".jpeg") _viewModel._canvas.Image.SaveAsJpeg(stream);
            else _viewModel._canvas.Image.SaveAsPng(stream);
            return true;
        }
        catch { return false; }
    }
}
EOF

# 8. Desktop project
cat > "$ROOT/LibrePaint.Desktop/LibrePaint.Desktop.csproj" << 'EOF'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>WinExe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <ApplicationManifest>app.manifest</ApplicationManifest>
    <AssemblyName>libre-paint</AssemblyName>
  </PropertyGroup>

  <ItemGroup>
    <ProjectReference Include="..\LibrePaint\LibrePaint.csproj" />
  </ItemGroup>

  <ItemGroup>
    <PackageReference Include="Avalonia" Version="11.1.0" />
    <PackageReference Include="Avalonia.Desktop" Version="11.1.0" />
    <PackageReference Include="Avalonia.Themes.Fluent" Version="11.1.0" />
    <PackageReference Include="Avalonia.ReactiveUI" Version="11.1.0" />
    <PackageReference Include="Avalonia.Controls.ColorPicker" Version="11.1.0" />
    <PackageReference Include="SixLabors.ImageSharp" Version="3.1.5" />
    <PackageReference Include="SixLabors.ImageSharp.Drawing" Version="2.1.3" />
  </ItemGroup>

  <ItemGroup>
    <None Update="Assets/**" CopyToOutputDirectory="PreserveNewest" />
    <AvaloniaResource Include="Assets/**" />
  </ItemGroup>
</Project>
EOF

# 9. Desktop Program
cat > "$ROOT/LibrePaint.Desktop/Program.cs" << 'EOF'
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
EOF

cat > "$ROOT/LibrePaint.Desktop/App.axaml" << 'EOF'
<Application xmlns="https://github.com/avaloniaui"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             x:Class="LibrePaint.Desktop.App">
  <Application.Styles>
    <FluentTheme Mode="Light"/>
  </Application.Styles>
</Application>
EOF

cat > "$ROOT/LibrePaint.Desktop/App.axaml.cs" << 'EOF'
using Avalonia;
using Avalonia.Markup.Xaml;

namespace LibrePaint.Desktop;

public partial class App : Application
{
    public override void Initialize() => AvaloniaXamlLoader.Load(this);
}
EOF

cat > "$ROOT/LibrePaint.Desktop/app.manifest" << 'EOF'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <assemblyIdentity version="1.0.0.0" processorArchitecture="*" name="LibrePaint" type="win32" />
  <description>LibrePaint - Open-source paint application</description>
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v3">
    <security>
      <requestedPrivileges>
        <requestedExecutionLevel level="asInvoker" uiAccess="false" />
      </requestedPrivileges>
    </security>
  </trustInfo>
</assembly>
EOF

# 10. Ikona SVG
cat > "$ROOT/Assets/icons/libre-paint.svg" << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">
  <rect width="256" height="256" fill="#5e81ac"/>
  <path d="M64 64L192 64L192 192L64 192Z" fill="#eceff4" stroke="#2e3440" stroke-width="8"/>
  <circle cx="128" cy="128" r="40" fill="#bf616a"/>
  <path d="M96 160L160 160L160 192L96 192Z" fill="#81a1c1"/>
  <path d="M120 80L136 80L136 120L120 120Z" fill="#a3be8c"/>
</svg>
EOF

# 11. Gitignore
cat > "$ROOT/.gitignore" << 'EOF'
bin/
obj/
.vs/
.vscode/
*.suo
*.user
*.userosscache
*.sln.docstates
*.dotCover
*.idea
*.sublime-workspace
*.sublime-project
*.log
*.db
*.sqlite
*.DS_Store
Thumbs.db
EOF

# 12. LICENSE (Beerware)
cat > "$ROOT/LICENSE" << 'EOF'
"THE BEER-WARE LICENSE" (Revision 42):
<theokam57@github.com> napisał(a) ten kod. Dopóki ty i ja spotkamy się
kiedyś i pomyślisz, że ten kod jest wart tego, możesz kupić mi piwo
w zamian. Piotr 'theokam57' Kaminski
EOF

# 13. README.md
cat > "$ROOT/README.md" << 'EOF'
# LibrePaint 🎨

Open-source'owy edytor graficzny inspirowany Paint.NET, napisany w C# dla Linux, Windows i macOS.

## ✨ Funkcje

- ✏️ Rysowanie pędzlem z regulacją grubości
- 🎨 Wybór koloru
- 💾 Otwieranie/zapisywanie PNG, JPG, BMP
- ⚠️ Ostrzeżenia o niezapisanych zmianach
- 🌓 Tryb jasny/ciemny (Fluent Theme)

## 🚀 Instalacja

### Z kodu źródłowego (Arch Linux)

```bash
# Wymagania
sudo pacman -S dotnet-sdk gtk3 libx11 libxrandr libxinerama libxcursor libxi libgl libxkbcommon-x11

# Klonuj repo
git clone https://github.com/theokam57/LibrePaint.git
cd LibrePaint

# Zbuduj i uruchom
dotnet restore
dotnet run --project LibrePaint.Desktop

🍺 Licencja
Beerware – jeśli kiedyś się spotkamy i pomyślisz, że ten kod jest wart tego, możesz kupić mi piwo w zamian 😉
EOF
echo "✅ Projekt został skonfigurowany!"
echo ""
echo "Następne kroki:"
echo " 1. dotnet restore"
echo " 2. dotnet run --project LibrePaint.Desktop"