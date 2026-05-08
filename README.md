# Bongo Cat Plugin for DMS

A fun, reactive Bongo Cat widget for [Dank Material Shell](https://github.com/AvengeMedia/DankMaterialShell). Watch the cat tap its paws on your bar in real-time as you type!

![Screenshot](screenshot.png)

## Features

- **Real-time Reactivity**: The cat slaps its left and right paws as you type.
- **Big Hits**: Space and Enter keys trigger a double-paw slap.
- **Blinking**: The cat blinks occasionally when you're active.
- **Sleep Mode**: The cat goes to sleep after 5 seconds of inactivity.
- **Customizable**: Adjust the cat's size and idle timeout in settings.
- **Automatic Device Discovery**: Easily select your keyboard from the settings menu.

## Prerequisites

This plugin requires `evtest` to monitor keyboard events globally.

### Installation (Fedora)
```bash
sudo dnf install evtest
```

### Installation (Arch Linux)
```bash
sudo pacman -S evtest
```

### Permissions (Important!)
To allow the plugin to read keyboard events without root access, you must add your user to the `input` group:

```bash
sudo usermod -aG input $USER
```
**You must reboot (or log out and back in) for this change to take effect.**

## Installation

1. Create a directory for the plugin:
   ```bash
   mkdir -p ~/.config/DankMaterialShell/plugins/bongoCat
   ```
2. Copy all files and the `assets` folder to that directory.
3. Reload DMS or scan for plugins in DMS Settings.

## Credits

Based on the [Slow Bongo](https://github.com/noctalia-dev/noctalia-plugins/tree/main/slowbongo) plugin for Noctalia.

## License

MIT
