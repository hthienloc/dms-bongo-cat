# Bongo Cat

Watch the cat tap its paws as you type!

<img src="screenshot.png" width="400" alt="Screenshot">

## Install


**Required:** This plugin requires [dms-common](https://github.com/hthienloc/dms-common) to be installed.

```bash
# 1. Install shared components
git clone https://github.com/hthienloc/dms-common ~/.config/DankMaterialShell/plugins/dms-common

# 2. Install this plugin
dms://plugin/install/bongoCat
```

Or manually:
```bash
git clone https://github.com/hthienloc/dms-bongo-cat ~/.config/DankMaterialShell/plugins/bongoCat
```

## Features

- **Real-time typing** - Cat reacts to your keyboard input
- **Big hit detection** - Space/Enter triggers double-paw animation
- **Blink & sleep** - Cat blinks when active, sleeps after inactivity
- **Adjustable size** - Customize cat size from 50% to 200%

## Usage

| Action | Result |
|--------|--------|
| Left click | Open settings |
| Right click | Toggle sleep mode |

## Requirements

- `evtest` - Keyboard event monitoring
- User must be in `input` group: `sudo usermod -aG input $USER`

## Roadmap / TODO

- [ ] **Stable Hand Hold** - Currently, keeping the hand down during long presses is challenging due to the synchronization gap between the initial OS key-press event and the start of repeat events. Future improvements involve more sophisticated input polling or kernel-level event bridging.
- [ ] **Mouse Support** - Add paw animations for mouse clicks and movement.
- [ ] **Custom Skins** - Support for different cat skins and colors.

## License

MIT
