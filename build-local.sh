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

# Use local ZMK directory for development (skips git clone)
USE_LOCAL_ZMK="${USE_LOCAL_ZMK:-false}"
LOCAL_ZMK_PATH="${LOCAL_ZMK_PATH:-/home/lzampier/Clone/zmk}"

if [ "$USE_LOCAL_ZMK" = "true" ]; then
    echo -e "${YELLOW}Using local ZMK directory: ${LOCAL_ZMK_PATH}${NC}"
    if [ ! -d "$LOCAL_ZMK_PATH" ]; then
        echo -e "${RED}Error: Local ZMK path does not exist: ${LOCAL_ZMK_PATH}${NC}"
        exit 1
    fi
else
    # Override with HID battery reporting (default: enabled)
    if [ "${USE_HID_BATTERY:-true}" = "true" ]; then
        # Choose between Genteure's fork (default) and personal fork
        if [ "${USE_PERSONAL_FORK:-false}" = "true" ]; then
            ZMK_REPO="https://github.com/zampierilucas/zmk.git"
            ZMK_BRANCH="feat/individual-hid-battery-reporting"
            echo -e "${YELLOW}Using personal fork for individual HID battery reporting${NC}"
        else
            ZMK_REPO="https://github.com/Genteure/zmk.git"
            ZMK_BRANCH="feat/battery-reporting"
            echo -e "${YELLOW}Using PR #2938 branch for USB HID battery reporting${NC}"
        fi
    fi
fi

PRISTINE="${PRISTINE:-false}"  # Set PRISTINE=true for clean builds
PARALLEL="${PARALLEL:-true}"   # Set PARALLEL=false for sequential builds

# Build separate logging-only dongle (disabled by default since main build has logging+studio)
BUILD_DONGLE_LOGGING="${BUILD_DONGLE_LOGGING:-false}"

# Read build configuration from build.yaml
BUILD_YAML="${WORKSPACE_DIR}/build.yaml"
if [ ! -f "$BUILD_YAML" ]; then
    echo -e "${RED}Error: build.yaml not found at ${BUILD_YAML}${NC}"
    exit 1
fi

echo -e "${BLUE}Reading build configuration from build.yaml...${NC}"

# Parse build.yaml and extract build configurations
BUILD_CONFIGS=()
while IFS= read -r line; do
    BUILD_CONFIGS+=("$line")
done < <(yq e '.include[] | @json' "$BUILD_YAML")

# Create directories
mkdir -p "$BUILD_DIR"
mkdir -p "$ZMK_WORKSPACE"

# Always clean build directory to ensure fresh builds
echo -e "${YELLOW}Cleaning previous build artifacts...${NC}"
rm -f "$BUILD_DIR"/*.uf2
echo -e "${GREEN}✓ Build directory cleaned${NC}"

# If PRISTINE=true, remove entire workspace for true clean build
if [ "$PRISTINE" = "true" ]; then
    echo -e "${YELLOW}PRISTINE mode: Removing entire ZMK workspace...${NC}"
    # Use Docker to remove workspace since files are owned by Docker user
    if [ -d "$ZMK_WORKSPACE" ]; then
        docker run --rm -v "$ZMK_WORKSPACE:/workspace" zmkfirmware/zmk-build-arm:stable \
            bash -c "rm -rf /workspace/* /workspace/.*" 2>/dev/null || true
        # Clean up the directory itself
        sudo rm -rf "$ZMK_WORKSPACE"
    fi
    echo -e "${GREEN}✓ ZMK workspace removed for pristine build${NC}"
fi

# Check if ZMK workspace exists and is valid (skip if using local ZMK)
if [ "$USE_LOCAL_ZMK" = "true" ]; then
    # Check if local ZMK has west initialized
    if [ ! -d "$LOCAL_ZMK_PATH/.west" ]; then
        echo -e "${BLUE}Initializing west in local ZMK directory...${NC}"
        docker run --rm \
            -v "$LOCAL_ZMK_PATH:/zmk" \
            -w /zmk \
            zmkfirmware/zmk-build-arm:stable \
            bash -c "
                set -e
                west init -l app
                west update
            "
        echo -e "${GREEN}✓ West initialized in local ZMK directory${NC}"
    else
        echo -e "${GREEN}✓ Using local ZMK directory (west already initialized)${NC}"
    fi
    echo ""
elif [ ! -d "$ZMK_WORKSPACE/zmk/.git" ]; then
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

# Function to build from a build.yaml config
build_from_config() {
    local CONFIG_JSON=$1
    local BOARD=$(echo "$CONFIG_JSON" | jq -r '.board')
    local SHIELD=$(echo "$CONFIG_JSON" | jq -r '.shield')
    local SNIPPET=$(echo "$CONFIG_JSON" | jq -r '.snippet // empty')
    local CMAKE_ARGS=$(echo "$CONFIG_JSON" | jq -r '."cmake-args" // empty')
    local ARTIFACT_NAME=$(echo "$CONFIG_JSON" | jq -r '."artifact-name" // empty')

    local BUILD_SUFFIX=""
    local OUTPUT_NAME="${SHIELD}-${BOARD}-zmk"

    if [ -n "$ARTIFACT_NAME" ]; then
        OUTPUT_NAME="$ARTIFACT_NAME"
        BUILD_SUFFIX="-${ARTIFACT_NAME}"
    fi

    local OUTPUT_FILE="$BUILD_DIR/${OUTPUT_NAME}.uf2"
    local PRISTINE_FLAG=""

    if [ "$PRISTINE" = "true" ]; then
        PRISTINE_FLAG="-p"
    fi

    echo -e "${BLUE}Building: ${SHIELD} on ${BOARD}${NC}"
    if [ -n "$SNIPPET" ]; then
        echo -e "${YELLOW}  Snippet: ${SNIPPET}${NC}"
    fi
    if [ -n "$CMAKE_ARGS" ]; then
        echo -e "${YELLOW}  CMake args: ${CMAKE_ARGS}${NC}"
    fi

    # Determine ZMK source mount based on USE_LOCAL_ZMK
    if [ "$USE_LOCAL_ZMK" = "true" ]; then
        ZMK_MOUNT="-v $LOCAL_ZMK_PATH:/zmk"
        WORK_DIR="/zmk"
    else
        ZMK_MOUNT="-v $ZMK_WORKSPACE:/workspace"
        WORK_DIR="/workspace/zmk"
    fi

    # Construct build command
    local SNIPPET_ARG=""
    if [ -n "$SNIPPET" ]; then
        SNIPPET_ARG="-S $SNIPPET"
    fi

    # Run build in Docker
    docker run --rm \
        -v "$WORKSPACE_DIR:/project" \
        $ZMK_MOUNT \
        -w $WORK_DIR \
        zmkfirmware/zmk-build-arm:stable \
        bash -c "
            set -e

            # Copy custom shield to ZMK's boards directory (required for shield discovery)
            mkdir -p app/boards/shields/dactyl_manuform_5x6
            cp -r /project/boards/shields/dactyl_manuform_5x6/* app/boards/shields/dactyl_manuform_5x6/

            # Check if build directory has stale absolute paths and clean if needed
            if [ -d app/build-${SHIELD}${BUILD_SUFFIX}/CMakeCache.txt ] && [ -z \"$PRISTINE_FLAG\" ]; then
                if grep -q '/.zmk-workspace/' app/build-${SHIELD}${BUILD_SUFFIX}/CMakeCache.txt 2>/dev/null; then
                    echo \"Cleaning stale build cache with old paths...\"
                    rm -rf app/build-${SHIELD}${BUILD_SUFFIX}
                fi
            fi

            # Build the firmware
            cd app
            west build $PRISTINE_FLAG -b $BOARD -d build-${SHIELD}${BUILD_SUFFIX} $SNIPPET_ARG -o=--quiet -- \
                -DSHIELD=$SHIELD $CMAKE_ARGS 2>&1

            # Copy output to host
            cp build-${SHIELD}${BUILD_SUFFIX}/zephyr/zmk.uf2 /project/build/${OUTPUT_NAME}.uf2
        "

    if [ -f "$OUTPUT_FILE" ]; then
        SIZE=$(stat -c%s "$OUTPUT_FILE" 2>/dev/null || stat -f%z "$OUTPUT_FILE" 2>/dev/null)
        echo -e "${GREEN}✓ Built: ${OUTPUT_NAME}.uf2${NC} (${SIZE} bytes)"
    else
        echo -e "${RED}✗ Failed to build: ${OUTPUT_NAME}${NC}"
        return 1
    fi
}

# Legacy function for logging builds
build_shield_logging() {
    local SHIELD=$1
    local BOARD=$2
    local OUTPUT_FILE="$BUILD_DIR/${SHIELD}-${BOARD}-zmk-logging.uf2"
    local PRISTINE_FLAG=""

    if [ "$PRISTINE" = "true" ]; then
        PRISTINE_FLAG="-p"
    fi

    echo -e "${BLUE}Building: ${SHIELD} (with logging)${NC}"

    # Determine ZMK source mount based on USE_LOCAL_ZMK
    if [ "$USE_LOCAL_ZMK" = "true" ]; then
        ZMK_MOUNT="-v $LOCAL_ZMK_PATH:/zmk"
        WORK_DIR="/zmk"
    else
        ZMK_MOUNT="-v $ZMK_WORKSPACE:/workspace"
        WORK_DIR="/workspace/zmk"
    fi

    # Run build in Docker
    docker run --rm \
        -v "$WORKSPACE_DIR:/project" \
        $ZMK_MOUNT \
        -w $WORK_DIR \
        zmkfirmware/zmk-build-arm:stable \
        bash -c "
            set -e

            # Copy custom shield to ZMK's boards directory (required for shield discovery)
            mkdir -p app/boards/shields/dactyl_manuform_5x6
            cp -r /project/boards/shields/dactyl_manuform_5x6/* app/boards/shields/dactyl_manuform_5x6/

            # Build the firmware
            cd app
            west build $PRISTINE_FLAG -b $BOARD -d build-${SHIELD}-logging -S zmk-usb-logging -o=--quiet -- \
                -DSHIELD=$SHIELD 2>&1

            # Copy output to host
            cp build-${SHIELD}-logging/zephyr/zmk.uf2 /project/build/${SHIELD}-${BOARD}-zmk-logging.uf2
        "

    if [ -f "$OUTPUT_FILE" ]; then
        SIZE=$(stat -c%s "$OUTPUT_FILE" 2>/dev/null || stat -f%z "$OUTPUT_FILE" 2>/dev/null)
        echo -e "${GREEN}✓ Built: ${SHIELD}-logging${NC} (${SIZE} bytes)"
    else
        echo -e "${RED}✗ Failed to build: ${SHIELD}-logging${NC}"
        return 1
    fi
}

# Build from build.yaml configurations
if [ "$PARALLEL" = "true" ]; then
    echo -e "${YELLOW}Building all configurations in parallel...${NC}"
    echo ""

    # Start all builds in background
    PIDS=()
    BUILD_NAMES=()

    for config in "${BUILD_CONFIGS[@]}"; do
        build_from_config "$config" &
        PIDS+=($!)
        SHIELD=$(echo "$config" | jq -r '.shield')
        BUILD_NAMES+=("$SHIELD")
    done

    # Build logging-enabled dongle if enabled
    if [ "$BUILD_DONGLE_LOGGING" = "true" ]; then
        build_shield_logging "dactyl_manuform_5x6_dongle" "nice_nano_v2" &
        PIDS+=($!)
        BUILD_NAMES+=("dactyl_manuform_5x6_dongle-logging")
    fi

    # Wait for all builds to complete
    FAILED=0
    for i in "${!PIDS[@]}"; do
        if ! wait "${PIDS[$i]}"; then
            FAILED=1
            echo -e "${RED}✗ Build failed for ${BUILD_NAMES[$i]}${NC}"
        fi
    done

    if [ $FAILED -ne 0 ]; then
        exit 1
    fi
else
    echo -e "${YELLOW}Building configurations sequentially...${NC}"
    echo ""

    for config in "${BUILD_CONFIGS[@]}"; do
        build_from_config "$config"
        echo ""
    done

    # Build logging-enabled dongle if enabled
    if [ "$BUILD_DONGLE_LOGGING" = "true" ]; then
        build_shield_logging "dactyl_manuform_5x6_dongle" "nice_nano_v2"
        echo ""
    fi
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
echo "Built firmware files:"
for config in "${BUILD_CONFIGS[@]}"; do
    SHIELD=$(echo "$config" | jq -r '.shield')
    BOARD=$(echo "$config" | jq -r '.board')
    ARTIFACT_NAME=$(echo "$config" | jq -r '."artifact-name" // empty')
    if [ -n "$ARTIFACT_NAME" ]; then
        OUTPUT_NAME="$ARTIFACT_NAME"
    else
        OUTPUT_NAME="${SHIELD}-${BOARD}-zmk"
    fi
    echo "  - ${SHIELD}: $BUILD_DIR/${OUTPUT_NAME}.uf2"
done
echo ""
if [ "$BUILD_DONGLE_LOGGING" = "true" ]; then
    echo -e "${BLUE}Debug version (with USB logging):${NC}"
    echo "  - Dongle:      $BUILD_DIR/dactyl_manuform_5x6_dongle-nice_nano_v2-zmk-logging.uf2"
    echo ""
fi
echo -e "${YELLOW}Tips:${NC}"
echo "  - For clean build: PRISTINE=true ./build-local.sh"
echo "  - For sequential build: PARALLEL=false ./build-local.sh"
echo "  - Disable dongle logging: BUILD_DONGLE_LOGGING=false ./build-local.sh"
echo "  - Use local ZMK: USE_LOCAL_ZMK=true ./build-local.sh"
echo "  - Set local ZMK path: LOCAL_ZMK_PATH=/path/to/zmk USE_LOCAL_ZMK=true ./build-local.sh"
echo ""
echo -e "${YELLOW}Options when NOT using local ZMK:${NC}"
echo "  - Disable HID battery: USE_HID_BATTERY=false ./build-local.sh"
echo "  - Use personal fork: USE_PERSONAL_FORK=true ./build-local.sh"
echo ""
echo -e "${YELLOW}Maintenance:${NC}"
echo "  - To clean workspace: rm -rf .zmk-workspace"
