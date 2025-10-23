# Dactyl Manuform 5x6 ZMK Configuration - Summary

## What Was Done

Successfully configured a ZMK firmware repository for the Dactyl Manuform 5x6 keyboard with a wireless dongle setup.

### Configuration Files Created

```
boards/shields/dactyl_manuform_5x6/
├── Kconfig.shield                         # Shield identification
├── Kconfig.defconfig                      # Default configurations
├── dactyl_manuform_5x6.keymap             # 3-layer keymap
├── dactyl_manuform_5x6.conf               # Common settings
├── dactyl_manuform_5x6_left.conf          # Left peripheral config
├── dactyl_manuform_5x6_left.overlay       # Left hardware definition
├── dactyl_manuform_5x6_right.conf         # Right peripheral config
├── dactyl_manuform_5x6_right.overlay      # Right hardware definition
├── dactyl_manuform_5x6_dongle.conf        # Dongle/central config
├── dactyl_manuform_5x6_dongle.overlay     # Dongle definition
└── README.md                              # Documentation
```

### Hardware Setup

- **Board**: nice!nano v2 (nRF52840-based)
- **Left Half**: Peripheral (connects via BLE to dongle)
- **Right Half**: Peripheral (connects via BLE to dongle)
- **Dongle**: Central (USB to computer, BLE to peripherals)

### Pin Configuration

Ported from QMK configuration:
- **Columns**: D4, C6, D7, E6, B4, B5
- **Rows**: F6, F7, B1, B3, B2, B6
- **Diode Direction**: COL2ROW

### Keymap (3 Layers)

Ported from your QMK configuration with minor modifications:

#### Layer 0: QWERTY
- Standard QWERTY layout
- Custom bindings including á (RALT+')
- Dual function thumb cluster

#### Layer 1: LOWER
- Number pad on right side
- Arrow navigation
- RGB controls (hue, saturation, effects)
- Bootloader access
- Symbols and special characters

#### Layer 2: RAISE
- Function keys (F1-F12)
- Media controls (play, pause, volume, prev/next)
- RGB brightness
- Page up/down
- Bootloader access
- Special character: ñ (RALT+,)

### Key Features Ported

✅ 3 layers (removed Gaming layer as requested)
✅ RGB underglow controls
✅ Media keys
✅ Navigation keys
✅ Bootloader access on both halves
✅ Custom key bindings (á, ñ)

### Features Not Available in ZMK

❌ OLED displays (Luna pet animation)
❌ WPM tracking
❌ Full RGB matrix effects (limited support)

### Build System

- **GitHub Actions**: Automatic builds on push
- **Local Build**: See BUILD.md for Docker-based local building
- **Output**: Three UF2 firmware files

## Next Steps

### 1. Wait for Build to Complete

The GitHub Actions workflow is currently building the firmware. Check status:

```bash
gh run list
```

### 2. Download Firmware

Once build completes, download the three UF2 files from the Actions tab.

### 3. Flash Boards

For each board (left, right, dongle):
1. Double-tap the reset button to enter bootloader mode
2. Board appears as USB drive
3. Copy the corresponding .uf2 file
4. Board reboots automatically

Flash in this order:
1. **Dongle first** (central)
2. **Left half** (will auto-pair with dongle)
3. **Right half** (will auto-pair with dongle)

### 4. Use Your Keyboard

- Connect dongle to computer via USB
- Power on both keyboard halves
- They should automatically connect to the dongle
- Start typing!

## Customization

### Change Keymap

Edit `boards/shields/dactyl_manuform_5x6/dactyl_manuform_5x6.keymap`

### Change Board Type

If using different boards (e.g., Seeed XIAO BLE), update `build.yaml`:

```yaml
include:
  - board: seeeduino_xiao_ble
    shield: dactyl_manuform_5x6_left
  # ... etc
```

### Adjust Pin Configuration

If your wiring is different, edit the overlay files to match your hardware.

## Troubleshooting

### Halves Won't Connect
- Make sure dongle is powered and flashed as central
- Reset BLE bonds (re-flash if needed)
- Check that all three boards are running the correct firmware

### Wrong Keys
- Verify pin configuration matches your wiring
- Check matrix transform in overlay files

### Build Failures
- Check GitHub Actions logs
- See BUILD.md for local build troubleshooting

## Resources

- [ZMK Documentation](https://zmk.dev)
- [ZMK Discord](https://zmk.dev/community/discord/invite)
- [nice!nano Pinout](https://nicekeyboards.com/docs/nice-nano/pinout-schematic)
- Repository README: boards/shields/dactyl_manuform_5x6/README.md
- Build Guide: BUILD.md

## Files in This Repository

- `build.yaml` - Build configuration for GitHub Actions
- `BUILD.md` - Local build instructions
- `SUMMARY.md` - This file
- `config/west.yml` - West manifest
- `boards/shields/dactyl_manuform_5x6/` - Shield configuration
- `.github/workflows/build.yml` - GitHub Actions workflow

## Credits

- Original QMK configuration from ../dactyl_manuform/
- ZMK firmware by ZMK Project
- Configuration created for lzampier (Lucas Zampieri)
