# Dactyl Manuform 5x6 ZMK Configuration

## Overview

This is a ZMK firmware configuration for the Dactyl Manuform 5x6 keyboard with a wireless dongle setup.

## Hardware Setup

This configuration assumes:
- **Board**: nice!nano v2 (or compatible nRF52840 board)
- **Left Half**: Peripheral (connects via BLE to dongle)
- **Right Half**: Peripheral (connects via BLE to dongle)
- **Dongle**: Central (receives from both halves, connects to computer via USB)

## Pin Configuration

Based on the QMK configuration, the pin mapping is:
- **Columns**: D4, C6, D7, E6, B4, B5 (Pro Micro pins)
- **Rows**: F6, F7, B1, B3, B2, B6 (Pro Micro pins)
- **Diode Direction**: COL2ROW

## Keymap

The keymap has been ported from your QMK configuration with 4 layers:

### Layer 0: QWERTY
- Standard QWERTY layout
- Dual function keys on thumbs

### Layer 1: LOWER
- Number pad on right side
- Navigation keys (arrows)
- RGB controls
- Layer switching (to QWERTY/GAMING)
- Bootloader access

### Layer 2: RAISE
- Function keys (F1-F12)
- Media controls
- RGB brightness controls
- Volume controls
- Bootloader access

### Layer 3: GAMING
- Modified QWERTY for gaming
- Duplicated modifiers on left side for easier gaming access
- Quick switch back to QWERTY layer

## Building Firmware

### Local Build (using west)

```bash
# Build left half
west build -p -b nice_nano_v2 -- -DSHIELD=dactyl_manuform_5x6_left

# Build right half
west build -p -b nice_nano_v2 -- -DSHIELD=dactyl_manuform_5x6_right

# Build dongle
west build -p -b nice_nano_v2 -- -DSHIELD=dactyl_manuform_5x6_dongle
```

### GitHub Actions Build

Push your changes to GitHub and the workflow will automatically build all three firmware files.

## Flashing

1. Put each board into bootloader mode
2. Flash the corresponding UF2 file:
   - Left half: `dactyl_manuform_5x6_left-nice_nano_v2-zmk.uf2`
   - Right half: `dactyl_manuform_5x6_right-nice_nano_v2-zmk.uf2`
   - Dongle: `dactyl_manuform_5x6_dongle-nice_nano_v2-zmk.uf2`

## Pairing

1. Flash all three boards
2. Power on the dongle (central)
3. Power on the left half - it should automatically pair with the dongle
4. Power on the right half - it should automatically pair with the dongle
5. Connect the dongle to your computer via USB

## Customization

### Changing the Board

If you're using a different board (e.g., Seeed XIAO BLE), update `build.yaml`:

```yaml
include:
  - board: seeeduino_xiao_ble
    shield: dactyl_manuform_5x6_left
  - board: seeeduino_xiao_ble
    shield: dactyl_manuform_5x6_right
  - board: seeeduino_xiao_ble
    shield: dactyl_manuform_5x6_dongle
```

### Modifying the Keymap

Edit `dactyl_manuform_5x6.keymap` to change your layout.

### Pin Configuration

If your pin configuration is different, edit the overlay files:
- `dactyl_manuform_5x6_left.overlay`
- `dactyl_manuform_5x6_right.overlay`

## Notes

- **RGB Support**: ZMK's RGB underglow support is still in development. The RGB keycodes are included but may require additional configuration.
- **OLED Support**: ZMK doesn't currently support OLEDs in the same way as QMK. The Luna pet animation from your QMK config isn't available in ZMK.
- **Battery**: Since this is a wireless setup, make sure to add batteries to your keyboard halves (not needed for the dongle if USB-powered).
- **Deep Sleep**: The configuration includes deep sleep after 15 minutes of inactivity to save battery.

## Key Differences from QMK

1. **No WPM tracking**: ZMK doesn't support WPM calculation yet
2. **No OLED animations**: The Luna pet won't work in ZMK
3. **RGB Matrix**: Limited compared to QMK's RGB matrix
4. **Wireless**: Main advantage - full wireless operation with dongle

## Troubleshooting

### Halves not connecting
- Make sure all three boards are powered
- Try resetting the BLE bonds (hold bootloader key combinations)
- Check that the dongle is the central and halves are peripherals

### Wrong board type
- If you're not using nice!nano v2, update the board name in build.yaml
- Common alternatives: `seeeduino_xiao_ble`, `bluemicro840`

### Pin issues
- Double-check your wiring matches the pin configuration
- Verify the pin mapping in the overlay files matches your hardware

## Resources

- [ZMK Documentation](https://zmk.dev)
- [ZMK Discord](https://zmk.dev/community/discord/invite)
- [Pro Micro to nice!nano Pin Mapping](https://nicekeyboards.com/docs/nice-nano/pinout-schematic)
