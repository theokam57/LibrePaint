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
