# FFmpeg RockChip 交叉编译工具

[English](README_EN.md) | 中文

## 概述

本项目是一个基于 Zig 工具链的 FFmpeg 交叉编译构建系统，专门优化了对 RockChip 硬件加速的支持。它能够为多种目标平台交叉编译 FFmpeg，并自动处理 RockChip RGA 和 MPP 依赖库。

## 主要特性

- 🚀 **基于 Zig 工具链**：利用 Zig 的强大交叉编译能力
- 🎯 **多平台支持**：支持 Linux、Android、Windows、macOS、HarmonyOS 等多个平台
- ⚡ **RockChip 硬件加速**：内置 RGA 和 MPP 支持，提供硬件编解码加速
- 📦 **自动依赖管理**：自动下载和配置所需的依赖库
- 🔧 **灵活配置**：支持最小化构建和完整构建两种模式
- 📏 **大小优化**：可选的库文件大小优化

## ⚠️ 重要说明

**关于依赖库兼容性：**
- **librga** 和 **mpp** 依赖库是 RockChip 官方提供的硬件加速库
- **官方正式支持**：仅限 ARM Linux 和 Android 平台
- **其他平台**：如 x86、Windows、macOS 等版本**仅供测试和开发用途**
- 在非官方支持的平台上，硬件加速功能可能无法正常工作

## 系统要求

### 必需工具
- **Zig**：最新版本（用于交叉编译）
- **make**：用于构建过程
- **git**：用于下载源码
- **curl** 或 **wget**：用于下载依赖包
- **pkg-config**：用于库配置

### 可选工具
- **jq**：用于更好的 JSON 解析（推荐）

## 快速开始

### 1. 安装 Zig

访问 [Zig 官网](https://ziglang.org/download/) 下载并安装最新版本的 Zig。

### 2. 基本使用

```bash
# 使用默认配置（x86_64 Linux）
./build_with_zig.sh

# 指定目标平台
./build_with_zig.sh --target=aarch64-linux-gnu

# 使用最小化配置（仅 RockChip 相关组件）
./build_with_zig.sh --target=aarch64-linux-gnu --ffmpeg-options=rk_only

# 启用大小优化
./build_with_zig.sh --target=aarch64-linux-gnu --optimize-size
```

### 3. 清理构建

```bash
# 清理构建目录
./build_with_zig.sh clean

# 清理构建和安装目录
./build_with_zig.sh clean-dist
```

## 支持的目标平台

### Linux 平台
- `x86_64-linux-gnu` - x86_64 Linux (GNU libc) ⚠️ *测试用途*
- `aarch64-linux-gnu` - ARM64 Linux (GNU libc) ✅ *官方支持*
- `arm-linux-gnueabihf` - ARM 32-bit Linux (GNU libc) ✅ *官方支持*
- `riscv64-linux-gnu` - RISC-V 64-bit Linux ⚠️ *测试用途*
- `loongarch64-linux-gnu` - LoongArch64 Linux ⚠️ *测试用途*

### Android 平台
- `aarch64-linux-android` - ARM64 Android ✅ *官方支持*
- `arm-linux-android` - ARM 32-bit Android ✅ *官方支持*
- `x86_64-linux-android` - x86_64 Android ⚠️ *测试用途*
- `x86-linux-android` - x86 32-bit Android ⚠️ *测试用途*

### Windows 平台
- `x86_64-windows-gnu` - x86_64 Windows (MinGW) ⚠️ *测试用途*
- `aarch64-windows-gnu` - ARM64 Windows (MinGW) ⚠️ *测试用途*

### macOS 平台
- `x86_64-macos` - Intel macOS ⚠️ *测试用途*
- `aarch64-macos` - Apple Silicon macOS ⚠️ *测试用途*

### HarmonyOS 平台
- `aarch64-linux-harmonyos` - ARM64 HarmonyOS ⚠️ *测试用途*
- `arm-linux-harmonyos` - ARM 32-bit HarmonyOS ⚠️ *测试用途*
- `x86_64-linux-harmonyos` - x86_64 HarmonyOS ⚠️ *测试用途*

## 编译选项

### FFmpeg 配置选项

#### rk_only（推荐）
最小化构建，仅包含 RockChip 硬件加速相关组件：
- 硬件编码器：H.264、HEVC、MJPEG
- 硬件解码器：H.264、AV1、MJPEG、HEVC、VP8、VP9、H.263、MPEG1/2/4
- RGA 硬件缩放滤镜
- 基本的封装格式支持

#### complete
完整构建，包含所有可用的编解码器和功能。

### 优化选项

#### --optimize-size
启用库文件大小优化：
- 使用 `-Os` 优化标志
- 启用函数和数据段分离
- 自动剥离调试信息
- 移除未使用的符号

## 目录结构

构建完成后的目录结构：

```
ffmpeg-rockchip/
├── build_with_zig.sh          # 主构建脚本
├── ffmpeg/                    # FFmpeg 源码目录（自动下载）
├── build_deps/                # 依赖库目录
│   ├── rkrga/                # RGA 库
│   └── rkmpp/                # MPP 库
├── ffmpeg_build/             # 构建缓存目录
│   └── {target}/             # 按目标平台分类
└── ffmpeg_install/           # 安装目录
    └── Release/
        └── {target}/
            ├── lib/          # 编译后的库文件
            ├── include/      # 头文件
            └── bin/          # 可执行文件（如启用）
```

## 环境变量配置

### Android 开发
```bash
export ANDROID_NDK_HOME=/path/to/android-ndk
```

### HarmonyOS 开发
```bash
export HARMONYOS_SDK_HOME=/path/to/harmonyos-sdk
```

## 使用示例

### 为 RockChip 开发板构建
```bash
# ARM64 Linux 平台，最小化构建
./build_with_zig.sh --target=aarch64-linux-gnu --ffmpeg-options=rk_only --optimize-size
```

### 为 Android 应用构建
```bash
# ARM64 Android，需要先设置 ANDROID_NDK_HOME
export ANDROID_NDK_HOME=~/sdk/android_ndk/android-ndk-r21e
./build_with_zig.sh --target=aarch64-linux-android --ffmpeg-options=rk_only
```

### 测试用途的 x86 构建
```bash
# x86_64 Linux，用于开发测试
./build_with_zig.sh --target=x86_64-linux-gnu --ffmpeg-options=complete
```

## 常见问题

### Q: 编译失败，提示找不到依赖库
A: 确保网络连接正常，脚本会自动下载所需的依赖库。如果下载失败，可以手动删除 `build_deps` 目录后重试。

### Q: 在非 ARM 平台上编译成功，但运行时出错
A: 这是正常现象。RockChip 的硬件加速库只能在对应的硬件平台上正常运行，其他平台的版本仅供开发测试使用。

### Q: 如何减小编译后的库文件大小
A: 使用 `--optimize-size` 选项和 `--ffmpeg-options=rk_only` 配置可以显著减小库文件大小。

### Q: 支持哪些 RockChip 芯片
A: 支持所有兼容 RGA 和 MPP 接口的 RockChip 芯片，包括 RK3588、RK3566、RK3568 等。

## 许可证

本项目遵循相关开源许可证：
- FFmpeg：LGPL v2.1+ 或 GPL v2+
- RockChip MPP：Apache License 2.0
- RockChip RGA：Apache License 2.0

## 贡献

欢迎提交 Issue 和 Pull Request 来改进本项目。

## 相关链接

- [FFmpeg 官网](https://ffmpeg.org/)
- [Zig 官网](https://ziglang.org/)
- [RockChip MPP](https://github.com/rockchip-linux/mpp)
- [RockChip RGA](https://github.com/airockchip/librga)
