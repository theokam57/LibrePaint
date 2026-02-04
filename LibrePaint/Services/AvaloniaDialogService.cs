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
