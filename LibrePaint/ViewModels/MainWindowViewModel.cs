using AvaloniaColor = Avalonia.Media.Color;
using ImageColor = SixLabors.ImageSharp.Color;
using AvaloniaPoint = Avalonia.Point;
using AvaloniaColors = Avalonia.Media.Colors;
using MessageBox.Avalonia;
using MessageBox.Avalonia.Enums;
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
    private AvaloniaColor _currentColor = AvaloniaColors.Black;
    private WriteableBitmap? _bitmap;
    private bool _isDrawing;
    private bool _isModified;
    private string? _currentFilePath;
    private AvaloniaPoint _lastPoint;

    public WriteableBitmap? CanvasBitmap
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

    public AvaloniaColor CurrentColor
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
        var colors = new[]
            {
                AvaloniaColors.Black,
                AvaloniaColors.Red,
                AvaloniaColors.Blue,
                AvaloniaColors.Green,
                AvaloniaColors.Yellow
            };
        var currentIndex = Array.IndexOf(colors, _currentColor);
        CurrentColor = colors[(currentIndex + 1) % colors.Length];
    }

    public void StartStroke(AvaloniaPoint point)
    {
        if (IsDrawing || point.X < 0 || point.Y < 0 || point.X >= _canvas.Width || point.Y >= _canvas.Height) return;
        IsDrawing = true;
        IsModified = true;
        _lastPoint = point;
        if (SelectedTool == "Pędzel") DrawDot(point);
    }

    public void ContinueStroke(AvaloniaPoint point)
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

    private void DrawDot(AvaloniaPoint point)
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
        if (_bitmap == null || _bitmap.Size.Width != width || _bitmap.Size.Height != height)
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
