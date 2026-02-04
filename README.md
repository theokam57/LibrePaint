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
