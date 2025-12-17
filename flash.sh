#!/bin/bash

# Flash script for Dactyl Manuform keyboard firmware
# Usage: ./flash.sh [left|right|dongle|dongle-log|left-ble|right-ble]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

if [ $# -eq 0 ]; then
    echo -e "${RED}Usage: $0 [left|right|dongle|dongle-log|left-ble|right-ble|reset]${NC}"
    echo ""
    echo -e "${BLUE}Dongle mode (use with USB dongle):${NC}"
    echo -e "${CYAN}  $0 left        ${NC}# Left half (peripheral)"
    echo -e "${CYAN}  $0 right       ${NC}# Right half (peripheral)"
    echo -e "${CYAN}  $0 dongle      ${NC}# USB dongle (central)"
    echo ""
    echo -e "${BLUE}Dongle-less mode (direct Bluetooth):${NC}"
    echo -e "${CYAN}  $0 left-ble    ${NC}# Left half (central, connects to host)"
    echo -e "${CYAN}  $0 right-ble   ${NC}# Right half (peripheral, connects to left)"
    echo ""
    echo -e "${BLUE}Utility:${NC}"
    echo -e "${CYAN}  $0 reset       ${NC}# Settings reset (clears BT bonds, flash to BOTH halves)"
    echo ""
    echo -e "${BLUE}Debug:${NC}"
    echo -e "${CYAN}  $0 dongle-log  ${NC}# Dongle with USB logging"
    exit 1
fi

TARGET=$1
MOUNT_POINT="/tmp/zmk_flash_$$"

# Validate target and determine firmware filename
case $TARGET in
    left|right)
        FIRMWARE="build/dactyl_manuform_5x6_${TARGET}-nice_nano-zmk.uf2"
        TARGET="$TARGET (dongle mode)"
        ;;
    left-ble)
        FIRMWARE="build/dactyl_manuform_5x6_left_central_ble.uf2"
        TARGET="left (dongle-less mode, central)"
        ;;
    right-ble)
        FIRMWARE="build/dactyl_manuform_5x6_right_peripheral_ble.uf2"
        TARGET="right (dongle-less mode, peripheral)"
        ;;
    dongle)
        FIRMWARE="build/dactyl_manuform_5x6_dongle_studio.uf2"
        ;;
    dongle-log)
        FIRMWARE="build/dactyl_manuform_5x6_dongle-nice_nano-zmk-logging.uf2"
        TARGET="dongle (with logging)"
        ;;
    reset)
        FIRMWARE="build/settings_reset-nice_nano-zmk.uf2"
        TARGET="settings reset (flash to BOTH halves)"
        ;;
    *)
        echo -e "${RED}Error: Invalid target '$TARGET'${NC}"
        echo -e "${YELLOW}Valid targets: left, right, dongle, dongle-log, left-ble, right-ble, reset${NC}"
        exit 1
        ;;
esac

# Check if firmware exists
if [ ! -f "$FIRMWARE" ]; then
    echo -e "${RED}Error: Firmware file not found: $FIRMWARE${NC}"
    echo -e "${YELLOW}Please build the firmware first${NC}"
    exit 1
fi

echo -e "${BLUE}Preparing to flash $TARGET...${NC}"
echo -e "${CYAN}Firmware: $FIRMWARE${NC}"
echo ""

# Detect USB mass storage bootloader device
detect_bootloader_device() {
    echo -e "${YELLOW}Checking for existing bootloader device...${NC}" >&2

    for dev in $(ls /dev/sd[a-z] 2>/dev/null | sort); do
        local dev_name=$(basename "$dev")
        if [ -f "/sys/block/$dev_name/removable" ]; then
            local is_removable=$(cat "/sys/block/$dev_name/removable")
            if [ "$is_removable" = "1" ]; then
                local label=$(lsblk -no LABEL "$dev" 2>/dev/null || echo "")
                if [[ "$label" =~ NICENANO|BOOT|RPI-RP2|UF2 ]] || [ -z "$label" ]; then
                    echo -e "${GREEN}Found existing bootloader device: $dev${NC}" >&2
                    echo "$dev"
                    return 0
                fi
            fi
        fi
    done

    local before=$(ls /dev/sd* 2>/dev/null | sort)

    echo -e "${YELLOW}Please put the keyboard into bootloader mode (double-tap reset)${NC}" >&2
    echo -e "${YELLOW}Waiting for bootloader device to appear...${NC}" >&2

    local TIMEOUT=60
    local ELAPSED=0
    local DEVICE=""

    while [ -z "$DEVICE" ] && [ $ELAPSED -lt $TIMEOUT ]; do
        sleep 1
        ELAPSED=$((ELAPSED + 1))

        # Get current block devices
        local after=$(ls /dev/sd* 2>/dev/null | sort)
        local new_devices=$(comm -13 <(echo "$before") <(echo "$after") | grep -E '/dev/sd[a-z]$')

        if [ -n "$new_devices" ]; then
            for dev in $new_devices; do
                local dev_name=$(basename "$dev")
                if [ -f "/sys/block/$dev_name/removable" ]; then
                    local is_removable=$(cat "/sys/block/$dev_name/removable")
                    if [ "$is_removable" = "1" ]; then
                        DEVICE="$dev"
                        break
                    fi
                fi
            done
        fi

        if [ $((ELAPSED % 5)) -eq 0 ] && [ -z "$DEVICE" ]; then
            echo -e "${CYAN}Still waiting... ($ELAPSED seconds)${NC}" >&2
        fi
    done

    if [ -z "$DEVICE" ]; then
        echo -e "${RED}Error: Bootloader device did not appear within $TIMEOUT seconds${NC}" >&2
        exit 1
    fi

    echo "$DEVICE"
}

DEVICE=$(detect_bootloader_device)
echo -e "${GREEN}Device detected: $DEVICE${NC}"
sleep 1  # Give it a moment to settle

mkdir -p "$MOUNT_POINT"

# Cleanup function
cleanup() {
    if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        echo -e "${YELLOW}Cleaning up mount...${NC}"
        sudo umount "$MOUNT_POINT"
    fi
    if [ -d "$MOUNT_POINT" ]; then
        rmdir "$MOUNT_POINT"
    fi
}

trap cleanup EXIT

echo -e "${BLUE}Mounting $DEVICE...${NC}"
sudo mount "$DEVICE" "$MOUNT_POINT"

echo -e "${BLUE}Copying firmware...${NC}"
sudo cp "$FIRMWARE" "$MOUNT_POINT/"

echo -e "${BLUE}Syncing filesystem...${NC}"
sudo sync

echo -e "${BLUE}Unmounting...${NC}"
sudo umount "$MOUNT_POINT"
rmdir "$MOUNT_POINT"

echo ""
echo -e "${GREEN}✓ Successfully flashed $TARGET!${NC}"
echo -e "${CYAN}The device should reboot automatically.${NC}"

# Show logging instructions if this was a logging build
if [[ "$FIRMWARE" == *"-logging.uf2" ]]; then
    echo ""
    echo -e "${YELLOW}USB Logging is enabled on this dongle firmware.${NC}"
    echo -e "${CYAN}To view logs:${NC}"
    echo -e "  ${BLUE}cat /dev/ttyACM0${NC}"
    echo -e "  ${BLUE}tio /dev/ttyACM0${NC}"
    echo -e "  ${BLUE}screen /dev/ttyACM0 115200${NC}"
    echo ""
fi
