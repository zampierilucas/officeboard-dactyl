# Building Firmware Locally

There are three ways to build your ZMK firmware:

## 1. GitHub Actions (Easiest - Recommended)

Simply push to GitHub and the Actions workflow will build automatically:

```bash
git push
```

Then download the artifacts from the Actions tab in GitHub.

## 2. Using `act` (Best Local Option)

[act](https://github.com/nektos/act) runs GitHub Actions locally using Docker.

### Install act

```bash
# Fedora
sudo dnf install act

# Or via brew
brew install act

# Or download binary from GitHub
```

### Build

```bash
# Run the build workflow
act -j build

# Artifacts will be in the workflow output
```

## 3. Manual Docker Build

If you prefer to build manually with Docker:

```bash
# Pull the build image
docker pull zmkfirmware/zmk-build-arm:stable

# Create build directory
mkdir -p build

# Build each configuration
for SHIELD in dactyl_manuform_5x6_left dactyl_manuform_5x6_right dactyl_manuform_5x6_dongle; do
    echo "Building $SHIELD..."

    docker run --rm \
        -v "$(pwd):/workspace" \
        -w /workspace \
        zmkfirmware/zmk-build-arm:stable \
        bash -c "
            # Initialize workspace
            if [ ! -d zmk ]; then
                git clone --depth 1 --branch v0.3-branch https://github.com/zmkfirmware/zmk.git
            fi

            cd zmk/app

            # Build
            west build -p -b nice_nano_v2 -- \
                -DZMK_CONFIG=/workspace/config \
                -DZMK_EXTRA_MODULES=/workspace/boards \
                -DSHIELD=$SHIELD

            # Copy output
            cp build/zephyr/zmk.uf2 /workspace/build/${SHIELD}-nice_nano_v2-zmk.uf2
        "

    echo "Built: build/${SHIELD}-nice_nano_v2-zmk.uf2"
done
```

## 4. Native Build (Advanced)

If you want to build without Docker:

### Install Dependencies

```bash
# Install west and dependencies
pip3 install west

# Clone ZMK
git clone --branch v0.3-branch https://github.com/zmkfirmware/zmk.git
cd zmk

# Install west dependencies
west init -l app/
west update
```

### Build

```bash
# From ZMK directory
cd app

# Build each shield
west build -p -b nice_nano_v2 -- \
    -DZMK_CONFIG=/path/to/officeboard-dactyl/config \
    -DZMK_EXTRA_MODULES=/path/to/officeboard-dactyl/boards \
    -DSHIELD=dactyl_manuform_5x6_left

# Output: build/zephyr/zmk.uf2
```

## Build Output

Successful builds produce `.uf2` files:
- `dactyl_manuform_5x6_left-nice_nano_v2-zmk.uf2` (Left peripheral)
- `dactyl_manuform_5x6_right-nice_nano_v2-zmk.uf2` (Right peripheral)
- `dactyl_manuform_5x6_dongle-nice_nano_v2-zmk.uf2` (Central/dongle)

## Flashing

1. Put board into bootloader mode (double-tap reset button)
2. Board appears as USB drive
3. Copy the .uf2 file to the drive
4. Board automatically reboots with new firmware

## Checking Build Status

```bash
# View GitHub Actions status
gh run list

# Watch current build
gh run watch

# View in browser
gh run view --web
```

## Troubleshooting

### Build fails with "no such file or directory"
- Make sure you're in the repository root
- Check that `config/` and `boards/` directories exist

### Docker permission denied
```bash
# Add your user to docker group
sudo usermod -aG docker $USER
# Then log out and log back in
```

### West command not found
- Make sure you're using the Docker image or have west installed
- Docker method is recommended for most users
