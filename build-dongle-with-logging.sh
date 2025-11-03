#!/bin/bash
# Build dongle with USB logging enabled

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}Building dongle with USB logging${NC}"
echo ""

WORKSPACE_DIR="$(pwd)"
BUILD_DIR="${WORKSPACE_DIR}/build"
ZMK_WORKSPACE="${WORKSPACE_DIR}/.zmk-workspace"
BOARD="nice_nano_v2"
SHIELD="dactyl_manuform_5x6_dongle"

mkdir -p "$BUILD_DIR"

echo -e "${YELLOW}Building with zmk-usb-logging snippet...${NC}"

docker run --rm \
    -v "$WORKSPACE_DIR:/project" \
    -v "$ZMK_WORKSPACE:/workspace" \
    -w /workspace/zmk \
    zmkfirmware/zmk-build-arm:stable \
    bash -c "
        set -e

        # Copy custom shield to ZMK's boards directory
        mkdir -p app/boards/shields/dactyl_manuform_5x6
        cp -r /project/boards/shields/dactyl_manuform_5x6/* app/boards/shields/dactyl_manuform_5x6/

        # Build with USB logging snippet
        cd app
        west build -p -b $BOARD -d build-${SHIELD}-logging -S zmk-usb-logging -- -DSHIELD=$SHIELD

        # Copy output
        cp build-${SHIELD}-logging/zephyr/zmk.uf2 /project/build/${SHIELD}-${BOARD}-zmk-logging.uf2
    "

OUTPUT_FILE="$BUILD_DIR/${SHIELD}-${BOARD}-zmk-logging.uf2"

if [ -f "$OUTPUT_FILE" ]; then
    SIZE=$(stat -c%s "$OUTPUT_FILE" 2>/dev/null || stat -f%z "$OUTPUT_FILE" 2>/dev/null)
    echo -e "${GREEN}✓ Built dongle with logging: ${OUTPUT_FILE}${NC} (${SIZE} bytes)"
    echo ""
    echo -e "${YELLOW}To use:${NC}"
    echo "1. Flash this firmware to the dongle"
    echo "2. Connect dongle via USB"
    echo "3. View logs with: cat /dev/ttyACM0"
    echo "   or: tio /dev/ttyACM0"
    echo "   or: screen /dev/ttyACM0 115200"
else
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi
