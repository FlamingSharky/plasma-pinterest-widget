# Pinterest Plasma Widget

A KDE Plasma widget that displays a Pinterest feed (Personal, User, or Search results) on your desktop.

FYI: This entire thing seems to have been written in AI so I decided to just skim through it and see if I can make it work and ask the author to update it from the fork. I will see about maybe getting it up on the KDE Plasma store but I do not know if I feel like that is a solid idea considering the base code is just written by AI. Not that it's a problem entirely, just that it is not my project and I do not really feel like keeping it up to date beyond my own usages of it.

## Features
- **Personal Feed**: View your own Pinterest home feed (requires authentication).
- **User Feed**: View pins from a specific user.
- **Search Feed**: View pins matching a search query.
- **Save Pins**: Save pins to your profile directly from the widget.
- **Configurable**: Adjust refresh interval, number of pins, and more.

## Requirements
This widget requires Python 3 and the `requests` library to fetch data.

```bash
# Arch Linux
sudo pacman -S python-requests

# Ubuntu/Debian
sudo apt install python3-requests

# Fedora
sudo dnf install python3-requests
```

## Installation

1.  Download the `.plasmoid` file.
2.  Install using `kpackagetool6`:

```bash
kpackagetool6 -i org.user.pinterest.plasmoid
```

(Note: On Plasma 5, use `kpackagetool5`).

## Configuration

### Authentication (Optional)
To use the "Personal Feed" feature, you need to provide your Pinterest cookies.

1.  Run the setup script included in the widget:
    ```bash
    python3 ~/.local/share/plasma/plasmoids/org.user.pinterest/contents/pinterest_setup.py
    ```
    *Note: The path might vary depending on your installation.*

2.  Follow the on-screen instructions to copy your cookies from your browser.

## License
GPL-3.0
