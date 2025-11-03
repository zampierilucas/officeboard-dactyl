#!/bin/bash
# ZMK Local Build Script - Optimized for speed
# Uses persistent workspace and parallel builds

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}ZMK Local Build Script${NC}"
echo ""

# Configuration
WORKSPACE_DIR="$(pwd)"
BUILD_DIR="${WORKSPACE_DIR}/build"
ZMK_WORKSPACE="${WORKSPACE_DIR}/.zmk-workspace"
ZMK_VERSION="v0.2.1"
ZMK_REPO="https://github.com/zmkfirmware/zmk.git"
ZMK_BRANCH="$ZMK_VERSION"

# Override with PR #2938 for HID battery reporting (default: enabled)
if [ "${USE_HID_BATTERY:-true}" = "true" ]; then
    ZMK_REPO="https://github.com/Genteure/zmk.git"
    ZMK_BRANCH="feat/battery-reporting"
    echo -e "${YELLOW}Using PR #2938 branch for USB HID battery reporting${NC}"
fi

BOARD="nice_nano_v2"
PRISTINE="${PRISTINE:-false}"  # Set PRISTINE=true for clean builds
PARALLEL="${PARALLEL:-true}"   # Set PARALLEL=false for sequential builds

# Shields to build
SHIELDS=("dactyl_manuform_5x6_left" "dactyl_manuform_5x6_right" "dactyl_manuform_5x6_dongle")

# Create directories
mkdir -p "$BUILD_DIR"
mkdir -p "$ZMK_WORKSPACE"

# Always clean build directory to ensure fresh builds
echo -e "${YELLOW}Cleaning previous build artifacts...${NC}"
rm -f "$BUILD_DIR"/*.uf2
echo -e "${GREEN}✓ Build directory cleaned${NC}"

# Check if ZMK workspace exists and is valid
if [ ! -d "$ZMK_WORKSPACE/zmk/.git" ]; then
    echo -e "${BLUE}Initializing ZMK workspace (first run)...${NC}"
    docker run --rm \
        -v "$ZMK_WORKSPACE:/workspace" \
        -w /workspace \
        zmkfirmware/zmk-build-arm:stable \
        bash -c "
            set -e
            git clone --depth 1 --branch $ZMK_BRANCH $ZMK_REPO zmk
            cd zmk
            west init -l app
            west update
        "
    echo -e "${GREEN}✓ ZMK workspace initialized${NC}"
    echo ""
else
    echo -e "${GREEN}✓ Using existing ZMK workspace${NC}"
    echo ""
fi

# Function to build a single shield
build_shield() {
    local SHIELD=$1
    local OUTPUT_FILE="$BUILD_DIR/${SHIELD}-${BOARD}-zmk.uf2"
    local PRISTINE_FLAG=""

    if [ "$PRISTINE" = "true" ]; then
        PRISTINE_FLAG="-p"
    fi

    echo -e "${BLUE}Building: ${SHIELD}${NC}"

    # Run build in Docker with persistent workspace
    docker run --rm \
        -v "$WORKSPACE_DIR:/project" \
        -v "$ZMK_WORKSPACE:/workspace" \
        -w /workspace/zmk \
        zmkfirmware/zmk-build-arm:stable \
        bash -c "
            set -e

            # Copy custom shield to ZMK's boards directory (required for shield discovery)
            mkdir -p app/boards/shields/dactyl_manuform_5x6
            cp -r /project/boards/shields/dactyl_manuform_5x6/* app/boards/shields/dactyl_manuform_5x6/

            # Check if build directory has stale absolute paths and clean if needed
            if [ -d app/build-$SHIELD/CMakeCache.txt ] && [ -z \"$PRISTINE_FLAG\" ]; then
                if grep -q '/.zmk-workspace/' app/build-$SHIELD/CMakeCache.txt 2>/dev/null; then
                    echo \"Cleaning stale build cache with old paths...\"
                    rm -rf app/build-$SHIELD
                fi
            fi

            # Build the firmware
            cd app
            west build $PRISTINE_FLAG -b $BOARD -d build-$SHIELD -- \
                -DSHIELD=$SHIELD 2>&1

            # Copy output to host
            cp build-$SHIELD/zephyr/zmk.uf2 /project/build/${SHIELD}-${BOARD}-zmk.uf2
        " 2>&1 | grep -v "^Cloning\|^remote:\|^Receiving\|^Resolving" || true

    if [ -f "$OUTPUT_FILE" ]; then
        SIZE=$(stat -c%s "$OUTPUT_FILE" 2>/dev/null || stat -f%z "$OUTPUT_FILE" 2>/dev/null)
        echo -e "${GREEN}✓ Built: ${SHIELD}${NC} (${SIZE} bytes)"
    else
        echo -e "${RED}✗ Failed to build: ${SHIELD}${NC}"
        return 1
    fi
}

# Build shields
if [ "$PARALLEL" = "true" ]; then
    echo -e "${YELLOW}Building all shields in parallel...${NC}"
    echo ""

    # Start all builds in background
    PIDS=()
    for SHIELD in "${SHIELDS[@]}"; do
        build_shield "$SHIELD" &
        PIDS+=($!)
    done

    # Wait for all builds to complete
    FAILED=0
    for i in "${!PIDS[@]}"; do
        if ! wait "${PIDS[$i]}"; then
            FAILED=1
            echo -e "${RED}✗ Build failed for ${SHIELDS[$i]}${NC}"
        fi
    done

    if [ $FAILED -ne 0 ]; then
        exit 1
    fi
else
    echo -e "${YELLOW}Building shields sequentially...${NC}"
    echo ""

    for SHIELD in "${SHIELDS[@]}"; do
        build_shield "$SHIELD"
        echo ""
    done
fi

echo ""
echo -e "${GREEN}=== Build Complete ===${NC}"
echo ""
echo "Firmware files:"
ls -lh "$BUILD_DIR"/*.uf2 2>/dev/null
echo ""
echo -e "${BLUE}Build mode:${NC} $([ "$PRISTINE" = "true" ] && echo "Clean build" || echo "Incremental build")"
echo -e "${BLUE}Parallel:${NC} $([ "$PARALLEL" = "true" ] && echo "Enabled" || echo "Disabled")"
echo ""
echo -e "${YELLOW}To flash:${NC}"
echo "1. Put your board into bootloader mode (double-tap reset)"
echo "2. Copy the .uf2 file to the mounted USB drive"
echo ""
echo "Flash in this order:"
echo "  1. Dongle:     $BUILD_DIR/dactyl_manuform_5x6_dongle-${BOARD}-zmk.uf2"
echo "  2. Left half:  $BUILD_DIR/dactyl_manuform_5x6_left-${BOARD}-zmk.uf2"
echo "  3. Right half: $BUILD_DIR/dactyl_manuform_5x6_right-${BOARD}-zmk.uf2"
echo ""
echo -e "${YELLOW}Tips:${NC}"
echo "  - For clean build: PRISTINE=true ./build-local.sh"
echo "  - For sequential build: PARALLEL=false ./build-local.sh"
echo "  - Disable HID battery: USE_HID_BATTERY=false ./build-local.sh"
echo "  - To clean workspace: rm -rf .zmk-workspace"
