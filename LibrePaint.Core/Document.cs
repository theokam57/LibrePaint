namespace LibrePaint.Core;

public class Document
{
    public int Width { get; }
    public int Height { get; }

    public List<Layer> Layers { get; } = new();

    public Document(int width, int height)
    {
        Width = width;
        Height = height;
        Layers.Add(new Layer(width, height, "Background"));
    }
}
