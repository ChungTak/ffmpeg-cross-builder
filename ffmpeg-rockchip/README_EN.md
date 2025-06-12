# FFmpeg RockChip Cross-Compilation Tool

[中文](README.md) | English

## Overview

This project is a FFmpeg cross-compilation build system based on the Zig toolchain, specifically optimized for RockChip hardware acceleration support. It can cross-compile FFmpeg for multiple target platforms and automatically handle RockChip RGA and MPP dependency libraries.

## Key Features

- 🚀 **Zig Toolchain Based**: Leverages Zig's powerful cross-compilation capabilities
- 🎯 **Multi-Platform Support**: Supports Linux, Android, Windows, macOS, HarmonyOS, and more
- ⚡ **RockChip Hardware Acceleration**: Built-in RGA and MPP support for hardware encoding/decoding acceleration
- 📦 **Automatic Dependency Management**: Automatically downloads and configures required dependency libraries
- 🔧 **Flexible Configuration**: Supports both minimal and complete build modes
- 📏 **Size Optimization**: Optional library file size optimization

## ⚠️ Important Notice

**About Dependency Library Compatibility:**
- **librga** and **mpp** dependency libraries are hardware acceleration libraries officially provided by RockChip
- **Official Support**: Limited to ARM Linux and Android platforms only
- **Other Platforms**: Versions for x86, Windows, macOS, etc. are **for testing and development purposes only**
- Hardware acceleration features may not work properly on unofficially supported platforms

## System Requirements

### Required Tools
- **Zig**: Latest version (for cross-compilation)
- **make**: For the build process
- **git**: For downloading source code
- **curl** or **wget**: For downloading dependency packages
- **pkg-config**: For library configuration

### Optional Tools
- **jq**: For better JSON parsing (recommended)

## Quick Start

### 1. Install Zig

Visit the [Zig official website](https://ziglang.org/download/) to download and install the latest version of Zig.

### 2. Basic Usage

```bash
# Use default configuration (x86_64 Linux)
./build_with_zig.sh

# Specify target platform
./build_with_zig.sh --target=aarch64-linux-gnu

# Use minimal configuration (RockChip components only)
./build_with_zig.sh --target=aarch64-linux-gnu --ffmpeg-options=rk_only

# Enable size optimization
./build_with_zig.sh --target=aarch64-linux-gnu --optimize-size
```

### 3. Clean Build

```bash
# Clean build directory
./build_with_zig.sh clean

# Clean build and install directories
./build_with_zig.sh clean-dist
```

## Supported Target Platforms

### Linux Platforms
- `x86_64-linux-gnu` - x86_64 Linux (GNU libc) ⚠️ *Testing purposes*
- `aarch64-linux-gnu` - ARM64 Linux (GNU libc) ✅ *Officially supported*
- `arm-linux-gnueabihf` - ARM 32-bit Linux (GNU libc) ✅ *Officially supported*
- `riscv64-linux-gnu` - RISC-V 64-bit Linux ⚠️ *Testing purposes*
- `loongarch64-linux-gnu` - LoongArch64 Linux ⚠️ *Testing purposes*

### Android Platforms
- `aarch64-linux-android` - ARM64 Android ✅ *Officially supported*
- `arm-linux-android` - ARM 32-bit Android ✅ *Officially supported*
- `x86_64-linux-android` - x86_64 Android ⚠️ *Testing purposes*
- `x86-linux-android` - x86 32-bit Android ⚠️ *Testing purposes*

### Windows Platforms
- `x86_64-windows-gnu` - x86_64 Windows (MinGW) ⚠️ *Testing purposes*
- `aarch64-windows-gnu` - ARM64 Windows (MinGW) ⚠️ *Testing purposes*

### macOS Platforms
- `x86_64-macos` - Intel macOS ⚠️ *Testing purposes*
- `aarch64-macos` - Apple Silicon macOS ⚠️ *Testing purposes*

### HarmonyOS Platforms
- `aarch64-linux-harmonyos` - ARM64 HarmonyOS ⚠️ *Testing purposes*
- `arm-linux-harmonyos` - ARM 32-bit HarmonyOS ⚠️ *Testing purposes*
- `x86_64-linux-harmonyos` - x86_64 HarmonyOS ⚠️ *Testing purposes*

## Build Options

### FFmpeg Configuration Options

#### rk_only (Recommended)
Minimal build with only RockChip hardware acceleration related components:
- Hardware encoders: H.264, HEVC, MJPEG
- Hardware decoders: H.264, AV1, MJPEG, HEVC, VP8, VP9, H.263, MPEG1/2/4
- RGA hardware scaling filters
- Basic container format support

#### complete
Complete build with all available codecs and features.

### Optimization Options

#### --optimize-size
Enable library file size optimization:
- Use `-Os` optimization flags
- Enable function and data section separation
- Automatically strip debug information
- Remove unused symbols

## Directory Structure

Directory structure after build completion:

```
ffmpeg-rockchip/
├── build_with_zig.sh          # Main build script
├── ffmpeg/                    # FFmpeg source directory (auto-downloaded)
├── build_deps/                # Dependency libraries directory
│   ├── rkrga/                # RGA library
│   └── rkmpp/                # MPP library
├── ffmpeg_build/             # Build cache directory
│   └── {target}/             # Categorized by target platform
└── ffmpeg_install/           # Installation directory
    └── Release/
        └── {target}/
            ├── lib/          # Compiled library files
            ├── include/      # Header files
            └── bin/          # Executable files (if enabled)
```

## Environment Variable Configuration

### Android Development
```bash
export ANDROID_NDK_HOME=/path/to/android-ndk
```

### HarmonyOS Development
```bash
export HARMONYOS_SDK_HOME=/path/to/harmonyos-sdk
```

## Usage Examples

### Build for RockChip Development Boards
```bash
# ARM64 Linux platform, minimal build
./build_with_zig.sh --target=aarch64-linux-gnu --ffmpeg-options=rk_only --optimize-size
```

### Build for Android Applications
```bash
# ARM64 Android, need to set ANDROID_NDK_HOME first
export ANDROID_NDK_HOME=~/sdk/android_ndk/android-ndk-r21e
./build_with_zig.sh --target=aarch64-linux-android --ffmpeg-options=rk_only
```

### x86 Build for Testing Purposes
```bash
# x86_64 Linux, for development testing
./build_with_zig.sh --target=x86_64-linux-gnu --ffmpeg-options=complete
```

## FAQ

### Q: Build fails with dependency library not found
A: Ensure network connection is stable. The script will automatically download required dependency libraries. If download fails, try manually deleting the `build_deps` directory and retry.

### Q: Compilation succeeds on non-ARM platforms but runtime errors occur
A: This is normal behavior. RockChip's hardware acceleration libraries can only run normally on corresponding hardware platforms. Versions for other platforms are for development testing only.

### Q: How to reduce compiled library file size
A: Using the `--optimize-size` option and `--ffmpeg-options=rk_only` configuration can significantly reduce library file size.

### Q: Which RockChip chips are supported
A: Supports all RockChip chips compatible with RGA and MPP interfaces, including RK3588, RK3566, RK3568, etc.

## License

This project follows relevant open source licenses:
- FFmpeg: LGPL v2.1+ or GPL v2+
- RockChip MPP: Apache License 2.0
- RockChip RGA: Apache License 2.0

## Contributing

Issues and Pull Requests are welcome to improve this project.

## Related Links

- [FFmpeg Official Website](https://ffmpeg.org/)
- [Zig Official Website](https://ziglang.org/)
- [RockChip MPP](https://github.com/rockchip-linux/mpp)
- [RockChip RGA](https://github.com/airockchip/librga)
