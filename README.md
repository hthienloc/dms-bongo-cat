# Bongo Cat

Watch the cat tap its paws as you type!

<img src="screenshot.png" width="400" alt="Screenshot">

## Install

Use the DMS CLI:
```bash
dms plugins install bongoCat
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

### Keyboard Selection
You can select a specific keyboard from the dropdown menu in the settings. This is useful if you have multiple input devices and want the cat to only react to a specific one.

**Note:** The device filtering is currently based on a manual exclusion list. If you have a peripheral (like a mouse or headset) that is incorrectly identified as a keyboard and appears in the list, please **open an issue** with the device name so it can be added to the exclusion list.

## Requirements

- `evtest` - Primary tool for monitoring specific keyboard events.
- `libinput` - Required only for **"All Keyboards (Auto)"** mode.
- User must be in `input` group: `sudo usermod -aG input $USER`

## Roadmap / TODO

- [ ] **Improved Key-Hold Logic:** Refine input polling to ensure paws stay down during sustained key presses.
- [ ] **Mouse Interaction:** Animate paws reacting to mouse button clicks and scroll events.
- [ ] **Performance Metrics (WPM):** Optional overlay showing real-time typing speed and accuracy.
- [ ] **Extended Skin Library:** Support for loading custom SVG/PNG skins and different "cat" variants (e.g., Robot-cat, Ghost-cat).
- [ ] **Audio Feedback:** Optional haptic-like mechanical keyboard sound effects on every keystroke.

## License

MIT
