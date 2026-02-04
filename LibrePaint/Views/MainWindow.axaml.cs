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
