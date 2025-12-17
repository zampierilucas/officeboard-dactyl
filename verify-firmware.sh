#!/bin/bash
# Post-flash firmware verification script
# Checks if the correct firmware was flashed by reading Bluetooth device name
# Usage: ./verify-firmware.sh [left|right|dongle]

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ $# -eq 0 ]; then
    echo -e "${YELLOW}Post-Flash Verification Script${NC}"
    echo ""
    echo "Usage: $0 [left|right|dongle]"
    echo ""
    echo "This script verifies that the correct firmware was flashed"
    echo "by checking the Bluetooth device name."
    echo ""
    echo "Run this AFTER flashing firmware and waiting for device to reboot."
    exit 1
fi

TARGET=$(echo "$1" | tr '[:lower:]' '[:upper:]')
EXPECTED_NAME="DM5x6_${TARGET}"

case "$TARGET" in
    LEFT|RIGHT|DONGLE)
        ;;
    *)
        echo -e "${RED}Error: Invalid target '$1'${NC}"
        echo "Valid options: left, right, dongle"
        exit 1
        ;;
esac

echo -e "${BLUE}=== Firmware Verification ===${NC}"
echo ""
echo -e "${YELLOW}Expected device name:${NC} $EXPECTED_NAME"
echo ""
echo -e "${YELLOW}Scanning for Bluetooth devices...${NC}"
echo "This may take up to 10 seconds..."
echo ""

# Use bluetoothctl to scan for devices
if ! command -v bluetoothctl &> /dev/null; then
    echo -e "${RED}Error: bluetoothctl not found${NC}"
    echo "Install bluez package: sudo dnf install bluez"
    exit 1
fi

# Start bluetooth if not running
if ! systemctl is-active --quiet bluetooth; then
    echo -e "${YELLOW}Starting bluetooth service...${NC}"
    sudo systemctl start bluetooth
    sleep 2
fi

# Scan for devices
SCAN_OUTPUT=$(timeout 10 bluetoothctl --timeout 10 scan on 2>&1 | grep -i "DM5x6" || true)

if echo "$SCAN_OUTPUT" | grep -q "$EXPECTED_NAME"; then
    echo -e "${GREEN}✓ SUCCESS: Found device with name '$EXPECTED_NAME'${NC}"
    echo ""
    echo -e "${GREEN}Firmware verification passed!${NC}"
    echo "The correct firmware was flashed to this device."
    exit 0
else
    echo -e "${RED}✗ FAILED: Device '$EXPECTED_NAME' not found${NC}"
    echo ""

    # Show what was found
    if [ -n "$SCAN_OUTPUT" ]; then
        echo -e "${YELLOW}Found these DM5x6 devices instead:${NC}"
        echo "$SCAN_OUTPUT" | grep "DM5x6" || echo "  (none)"
        echo ""
        echo -e "${RED}⚠️  WARNING: Wrong firmware may have been flashed! ⚠️${NC}"
        echo ""
        echo "Possible causes:"
        echo "  1. Wrong .uf2 file was copied to bootloader"
        echo "  2. Device hasn't rebooted yet (wait 10 seconds and retry)"
        echo "  3. Bluetooth is not enabled on the device"
    else
        echo -e "${YELLOW}No DM5x6 devices found.${NC}"
        echo ""
        echo "Possible causes:"
        echo "  1. Device hasn't rebooted from bootloader yet (wait and retry)"
        echo "  2. Bluetooth is not enabled"
        echo "  3. Device is out of range"
    fi
    exit 1
fi
