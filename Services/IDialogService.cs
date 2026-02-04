using System.Threading.Tasks;

namespace LibrePaint.Services;

public interface IDialogService
{
    Task ShowErrorAsync(string title, string message);
    Task<bool> ShowConfirmAsync(string title, string message, string confirmText = "Tak", string cancelText = "Nie");
}