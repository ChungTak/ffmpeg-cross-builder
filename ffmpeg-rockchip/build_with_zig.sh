#!/bin/bash

# 设置颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 默认参数
TARGET="x86_64-linux-gnu"
ACTION=""
FIRST_ARG_SET=""
OPTIMIZE_SIZE=false
FFMPEG_OPTIONS="rk_only"

# 解析命令行参数
for arg in "$@"; do
  case $arg in
    --target=*)
      TARGET="${arg#*=}"
      shift
      ;;
    --optimize-size)
      OPTIMIZE_SIZE=true
      shift
      ;;
    --ffmpeg-options=*)
      FFMPEG_OPTIONS="${arg#*=}"
      shift
      ;;
    clean)
      ACTION="clean"
      shift
      ;;
    clean-dist)
      ACTION="clean-dist"
      shift
      ;;
    --help)
      echo "用法: $0 [选项] [动作]"
      echo "选项:"
      echo "  --target=<目标>    指定目标架构 (默认: x86_64-linux-gnu)"
      echo "  --optimize-size    启用库文件大小优化 (保持性能)"
      echo "  --ffmpeg-options=<选项>  FFmpeg编译选项 (默认: rk_only)"
      echo "                     rk_only   - 仅编译RockChip硬件加速相关组件 (最小化)"
      echo "                     complete  - 完整编译选项"
      echo "  --help             显示此帮助信息"
      echo ""
      echo "动作:"
      echo "  clean              清除build目录和缓存"
      echo "  clean-dist         清除build目录和install目录"
      echo ""
      echo "支持的目标架构示例:"
      echo "  x86_64-linux-gnu      - x86_64 Linux (GNU libc)"
      echo "  arm-linux-gnueabihf     - ARM64 32-bit Linux (GNU libc)"
      echo "  aarch64-linux-gnu     - ARM64 Linux (GNU libc)"
      echo "  arm-linux-android         - ARM 32-bit Android"   
      echo "  aarch64-linux-android     - ARM64 Android"
      echo "  x86-linux-android         - x86 32-bit Android"      
      echo "  x86_64-linux-android     - x86_64 Android"
      echo "  x86_64-windows-gnu    - x86_64 Windows (MinGW)"
      echo "  aarch64-windows-gnu    - aarch64 Windows (MinGW)"
      echo "  x86_64-macos          - x86_64 macOS"
      echo "  aarch64-macos         - ARM64 macOS"
      echo "  riscv64-linux-gnu      - RISC-V 64-bit Linux"      
      echo "  loongarch64-linux-gnu   - LoongArch64 Linux"
      echo "  aarch64-linux-harmonyos     - ARM64 HarmonyOS"
      echo "  arm-linux-harmonyos         - ARM 32-bit HarmonyOS"  
      echo "  x86_64-linux-harmonyos     - x86_64 harmonyos"
      exit 0
      ;;
    *)
      # 处理位置参数 (第一个参数作为target)
      if [ -z "$FIRST_ARG_SET" ]; then
        TARGET="$arg"
        FIRST_ARG_SET=1
      fi
      ;;
  esac
done

# 参数配置 - 调整为根目录结构
PROJECT_ROOT_DIR="$(pwd)"
FFMPEG_SOURCE_DIR="$PROJECT_ROOT_DIR/ffmpeg"
BUILD_TYPE="Release"
INSTALL_DIR="$PROJECT_ROOT_DIR/ffmpeg_install/Release/${TARGET}"
BUILD_DIR="$PROJECT_ROOT_DIR/ffmpeg_build/${TARGET}"


# 设置 CMake 交叉编译变量 - 基于原始目标而不是 Zig 目标
case "$TARGET" in
    arm-*)
        ARCH="arm"
        ;;
    aarch64-*)
        ARCH="aarch64"
        ;;
    x86-*)
        ARCH="x86"
        ;;
    x86_64-*)
        ARCH="x86_64"
        ;;
    riscv64-*)
        ARCH="riscv64"
        ;;
    loongarch64-*)
        ARCH="loongarch64"
        ;;
esac

case "$TARGET" in
    *-android)
        TARGET_OS="android"
        ;;
    *-windows-*)
        TARGET_OS="windows"
        ;;
    *-macos)
        TARGET_OS="macos"
        ;;                   
    *)
        TARGET_OS="linux"
        ;;
esac
# 函数：下载并解压 ffmpeg 源码
download_ffmpeg() {
    local source_dir="$1"
    local download_url="https://github.com/nyanmisaka/ffmpeg-rockchip.git"
    
    echo -e "${YELLOW}检查 ffmpeg 源码目录...${NC}"
    
    # 检查源码目录是否存在
    if [ -d "$source_dir" ]; then
        echo -e "${GREEN}源码目录已存在: $source_dir${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}源码目录不存在，开始下载 ffmpeg...${NC}"
    
    # 检查必要的工具
    if ! command -v git &> /dev/null; then
        echo -e "${RED}错误: 需要 git 来下载文件${NC}"
        exit 1
    fi
    
    # 创建临时下载目录
    
    echo -e "${BLUE}下载地址: $download_url${NC}"
    echo -e "${BLUE}下载到: $source_dir${NC}"
    
    # 下载文件
    git clone --depth=1 $download_url $source_dir
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载失败: $download_url${NC}"
        rm -rf "$archive_path"
        exit 1
    fi
    
    
    # 验证解压结果
    if [ -d "$source_dir" ]; then
        echo -e "${GREEN}ffmpeg 源码准备完成: $source_dir${NC}"
    else
        echo -e "${RED}解压后未找到预期的源码目录: $source_dir${NC}"
        exit 1
    fi
}

# 下载并准备 ffmpeg 源码
download_ffmpeg "$FFMPEG_SOURCE_DIR"

# 函数：下载并解压依赖库
download_dependency() {
    local dep_name="$1"
    local target="$2"
    local deps_dir="$PROJECT_ROOT_DIR/build_deps/$dep_name"

    echo -e "${YELLOW}检查 $dep_name 依赖目录...${NC}" >&2
    
    # 检查必要的工具
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        echo -e "${RED}错误: 需要 curl 或 wget 来下载文件${NC}" >&2
        exit 1
    fi
    
    # GitHub releases API URL
    local api_url="https://api.github.com/repos/ChungTak/$dep_name-cross-builder/releases/latest"
    local download_url=""
    
    # 获取最新release信息
    echo -e "${BLUE}获取最新 $dep_name release 信息...${NC}" >&2
    if command -v curl &> /dev/null; then
        local release_info=$(curl -s "$api_url")
    else
        local release_info=$(wget -qO- "$api_url")
    fi
    
    if [ $? -ne 0 ] || [ -z "$release_info" ]; then
        echo -e "${RED}获取 $dep_name release 信息失败${NC}" >&2
        exit 1
    fi
    
    # 查找对应架构的压缩包URL
    if command -v jq &> /dev/null; then
        # 使用jq解析JSON
        download_url=$(echo "$release_info" | jq -r ".assets[] | select(.name | contains(\"$target\")) | .browser_download_url" | head -1)
    else
        # 使用grep和sed简单解析（备用方案）
        download_url=$(echo "$release_info" | grep -o "\"browser_download_url\"[^,]*$target[^\"]*" | sed 's/.*"browser_download_url": "//' | sed 's/"//' | head -1)
    fi
    
    if [ -z "$download_url" ]; then
        echo -e "${RED}未找到适合架构 $target 的 $dep_name 压缩包${NC}" >&2
        echo -e "${YELLOW}尝试使用通用版本...${NC}" >&2
        # 尝试获取第一个可用的压缩包
        if command -v jq &> /dev/null; then
            download_url=$(echo "$release_info" | jq -r ".assets[0].browser_download_url")
        else
            download_url=$(echo "$release_info" | grep -o "\"browser_download_url\"[^,]*\.tar\.gz[^\"]*" | sed 's/.*"browser_download_url": "//' | sed 's/"//' | head -1)
        fi
    fi
    
    if [ -z "$download_url" ]; then
        echo -e "${RED}无法获取 $dep_name 下载链接${NC}" >&2
        exit 1
    fi

    file_zip_name=$(basename "$download_url")
    filename="${file_zip_name%.tar.gz}"
    source_dir="$deps_dir/$filename"
    
    # 如果依赖目录已存在，直接返回
    if [ -d "$source_dir" ]; then
        echo -e "${GREEN}$dep_name 依赖源代码目录已存在: $source_dir${NC}" >&2
        echo "$source_dir"
        return 0
    fi
    
    echo -e "${YELLOW}$dep_name 依赖源代码目录不存在，开始下载...${NC}" >&2
    
    # 创建依赖源代码目录
    mkdir -p "$deps_dir"
    
    echo -e "${BLUE}下载地址: $download_url${NC}" >&2
    echo -e "${BLUE}下载到: $deps_dir/$file_zip_name${NC}" >&2
    
    # 下载文件
    if command -v curl &> /dev/null; then
        curl -L -o "$deps_dir/$file_zip_name" "$download_url"
    else
        wget -O "$deps_dir/$file_zip_name" "$download_url"
    fi
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载失败: $download_url${NC}" >&2
        rm -rf "$deps_dir/$file_zip_name"
        exit 1
    fi
    
    # 解压文件
    echo -e "${BLUE}解压 $dep_name...${NC}" >&2
    cd "$deps_dir"
    tar -xzf "$file_zip_name"
    if [ $? -ne 0 ]; then
        echo -e "${RED}解压失败: $deps_dir/$file_zip_name${NC}" >&2
        exit 1
    fi
    
    # 清理压缩包
    rm -f "$deps_dir/$file_zip_name"
    
    # 验证解压结果
    if [ -d "$source_dir/include" ] && [ -d "$source_dir/lib" ]; then
        echo -e "${GREEN}$dep_name 依赖准备完成: $source_dir${NC}" >&2
    else
        echo -e "${RED}解压后未找到预期的 $dep_name 目录结构${NC}" >&2
        exit 1
    fi
    
    cd "$PROJECT_ROOT_DIR"
    # 返回source_dir路径供外部使用
    echo "$source_dir"
}

# 下载依赖库
RKRGA_PATH=$(download_dependency "rkrga" "$TARGET")
RKMPP_PATH=$(download_dependency "rkmpp" "$TARGET")

# 设置依赖库路径
# 修复 pkg-config 文件中的路径
echo "修复 pkg-config 文件路径..."
find "${RKMPP_PATH}/lib/pkgconfig" -name "*.pc" -exec sed -i "s|^prefix=.*|prefix=${RKMPP_PATH}|g" {} \;
find "${RKRGA_PATH}/lib/pkgconfig" -name "*.pc" -exec sed -i "s|^prefix=.*|prefix=${RKRGA_PATH}|g" {} \;

# 设置编译环境变量 - 使用 Zig CC
export PKG_CONFIG_PATH="${RKMPP_PATH}/lib/pkgconfig:${RKRGA_PATH}/lib/pkgconfig:${PKG_CONFIG_PATH}"
export CFLAGS="-I${RKMPP_PATH}/include -I${RKRGA_PATH}/include -DHAVE_SYSCTL=0 ${CFLAGS}"
export LDFLAGS="-L${RKMPP_PATH}/lib -L${RKRGA_PATH}/lib"


# 处理清理动作
if [ "$ACTION" = "clean" ]; then
    echo -e "${YELLOW}清理构建目录和缓存...${NC}"
    rm -rf "$PROJECT_ROOT_DIR/ffmpeg_build"
    echo -e "${GREEN}构建目录已清理!${NC}"
    exit 0
elif [ "$ACTION" = "clean-dist" ]; then
    echo -e "${YELLOW}清理构建目录和安装目录...${NC}"
    rm -rf "$PROJECT_ROOT_DIR/ffmpeg_build"
    rm -rf "$PROJECT_ROOT_DIR/ffmpeg_install"
    echo -e "${GREEN}构建目录和安装目录已清理!${NC}"
    exit 0
fi

# 检查Zig是否安装
if ! command -v zig &> /dev/null; then
    echo -e "${RED}错误: 未找到Zig。请安装Zig: https://ziglang.org/download/${NC}"
    exit 1
fi

# 检查Make是否安装
if ! command -v make &> /dev/null; then
    echo -e "${RED}错误: 未找到make。请安装make{NC}"
    exit 1
fi

# 大小优化配置
if [ "$OPTIMIZE_SIZE" = true ]; then
    # 大小优化标志
    ZIG_OPTIMIZE_FLAGS="-Os -DNDEBUG -ffunction-sections -fdata-sections"
    export LDFLAGS="-Wl,--gc-sections -Wl,--strip-all"
else
    ZIG_OPTIMIZE_FLAGS="-O2 -DNDEBUG"
    export LDFLAGS=""
fi

# 创建安装目录
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# 创建FFMPEG构建目录（每次都清理，避免 CMake 缓存污染）
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 进入构建目录
cd "$BUILD_DIR"

# 根据目标平台配置编译器和工具链
if [[ "$TARGET" == *"-linux-android"* ]]; then
    export ANDROID_NDK_ROOT="${ANDROID_NDK_HOME:-~/sdk/android_ndk/android-ndk-r21e}"
    HOST_TAG=linux-x86_64
    TOOLCHAIN=$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/$HOST_TAG
    export PATH=$TOOLCHAIN/bin:$PATH
    API_LEVEL=23

    case "$TARGET" in
        aarch64-linux-android)
            ANDROID_ABI=arm64-v8a
            ANDROID_TARGET=aarch64-linux-android
            ;;
        arm-linux-android)
            ANDROID_ABI=armeabi-v7a
            ANDROID_TARGET=armv7a-linux-androideabi
            ;;
        x86_64-linux-android)
            ANDROID_ABI=x86_64
            ANDROID_TARGET=x86_64-linux-android
            ;;
        x86-linux-android)
            ANDROID_ABI=x86
            ANDROID_TARGET=i686-linux-android
            ;;
        *)
            echo -e "${RED}未知的 Android 架构: $TARGET${NC}"
            exit 1
            ;;
    esac
    
    # 设置编译器标志
    export CFLAGS="$ZIG_OPTIMIZE_FLAGS $CFLAGS"
    export CXXFLAGS="$ZIG_OPTIMIZE_FLAGS $CXXFLAGS"
    
    # toolchain 参数必须最前，其它参数和源码目录最后
    export CC="${TOOLCHAIN}/bin/${ANDROID_TARGET}${API_LEVEL}-clang"
    export CXX="${TOOLCHAIN}/bin/${ANDROID_TARGET}${API_LEVEL}-clang++"
    export AR="${TOOLCHAIN}/bin/llvm-ar"
    export RANLIB="${TOOLCHAIN}/bin/llvm-ranlib"    

elif [[ "$TARGET" == *"-linux-harmonyos"* ]]; then
    # 检查 HarmonyOS SDK
    export HARMONYOS_SDK_ROOT="${HARMONYOS_SDK_HOME:-~/sdk/harmonyos/ohos-sdk/linux/native-linux-x64-4.1.9.4-Release/native}"
    if [ ! -d "$HARMONYOS_SDK_ROOT" ]; then
        echo -e "${RED}错误: HarmonyOS SDK 未找到: $HARMONYOS_SDK_ROOT${NC}"
        echo -e "${RED}请设置 HARMONYOS_SDK_HOME 环境变量${NC}"
        exit 1
    fi
    
    # HarmonyOS 工具链路径
    HOST_TAG=linux-x86_64
    TOOLCHAIN=$HARMONYOS_SDK_ROOT/llvm/bin
    export PATH=$TOOLCHAIN:$PATH
    
    case "$TARGET" in
        aarch64-linux-harmonyos)
            OHOS_ARCH=aarch64
            HARMONYOS_TARGET=aarch64-linux-ohos
            NDK_ARCH_DIR=aarch64
            ;;
        arm-linux-harmonyos)
            OHOS_ARCH=armv7
            HARMONYOS_TARGET=arm-linux-ohos
            NDK_ARCH_DIR=arm
            ;;
        x86_64-linux-harmonyos)
            OHOS_ARCH=x86_64
            HARMONYOS_TARGET=x86_64-linux-ohos
            NDK_ARCH_DIR=x86_64
            ;;
        *)
            echo -e "${RED}未知的 HarmonyOS 架构: $TARGET${NC}"
            exit 1
            ;;
    esac
    
    # HarmonyOS SDK 路径 - 使用统一 sysroot
    HARMONYOS_SYSROOT="$HARMONYOS_SDK_ROOT/sysroot"
    HARMONYOS_INCLUDE="$HARMONYOS_SYSROOT/usr/include"
    # 库文件路径
    HARMONYOS_LIB="$HARMONYOS_SYSROOT/usr/lib/$NDK_ARCH_DIR-linux-ohos"
    
    # 检查必要的文件是否存在
    if [ ! -d "$HARMONYOS_INCLUDE" ]; then
        echo -e "${RED}错误: HarmonyOS SDK 包含目录未找到: $HARMONYOS_INCLUDE${NC}"
        exit 1
    fi
    
    if [ ! -d "$HARMONYOS_LIB" ]; then
        echo -e "${RED}错误: HarmonyOS SDK 库目录未找到: $HARMONYOS_LIB${NC}"
        exit 1
    fi
    
    # 检查工具链是否存在
    if [ ! -f "$TOOLCHAIN/clang" ]; then
        echo -e "${RED}错误: HarmonyOS clang 编译器未找到: $TOOLCHAIN/clang${NC}"
        exit 1
    fi
  
    # 设置编译器标志
    export CFLAGS="$ZIG_OPTIMIZE_FLAGS $CFLAGS"
    export CXXFLAGS="$ZIG_OPTIMIZE_FLAGS $CXXFLAGS"
    
    # toolchain 参数必须最前，其它参数和源码目录最后
    export CC="${TOOLCHAIN}/$OHOS_ARCH-unknown-linux-ohos-clang"
    export CXX="${TOOLCHAIN}/$OHOS_ARCH-unknown-linux-ohos-clang++"
    export AR="${TOOLCHAIN}/llvm-ar"
    export RANLIB="${TOOLCHAIN}/llvm-ranlib"  
else
    
    # 使用 Zig 作为编译器
    ZIG_PATH=$(command -v zig)
    
    export CC="$ZIG_PATH cc -target $TARGET $ZIG_OPTIMIZE_FLAGS"
    export CXX="$ZIG_PATH c++ -target $TARGET $ZIG_OPTIMIZE_FLAGS"
    export AR="zig ar"
    export RANLIB="zig ranlib"

    echo -e "${BLUE}Zig 编译器配置:${NC}"
    echo -e "${BLUE}  原始目标: $TARGET${NC}"
    echo -e "${BLUE}  Zig 目标: $TARGET${NC}"
    echo -e "${BLUE}  大小优化: $OPTIMIZE_SIZE${NC}"
    echo -e "${BLUE}  CC: $CC${NC}"
    echo -e "${BLUE}  CXX: $CXX${NC}"
fi

CONFIGURE_CMD="${FFMPEG_SOURCE_DIR}/configure"
CONFIGURE_CMD="$CONFIGURE_CMD --cross-prefix=''"
CONFIGURE_CMD="$CONFIGURE_CMD --arch=$ARCH"
CONFIGURE_CMD="$CONFIGURE_CMD --target-os=$TARGET_OS"
CONFIGURE_CMD="$CONFIGURE_CMD --enable-cross-compile"
CONFIGURE_CMD="$CONFIGURE_CMD --prefix=$INSTALL_DIR"
CONFIGURE_CMD="$CONFIGURE_CMD --cc='$CC'"
CONFIGURE_CMD="$CONFIGURE_CMD --cxx='$CXX'"
CONFIGURE_CMD="$CONFIGURE_CMD --ar='$AR'"
CONFIGURE_CMD="$CONFIGURE_CMD --ranlib='$RANLIB'"
CONFIGURE_CMD="$CONFIGURE_CMD --pkg-config=pkg-config"
CONFIGURE_CMD="$CONFIGURE_CMD --extra-cflags='$CFLAGS'"
CONFIGURE_CMD="$CONFIGURE_CMD --extra-ldflags='$LDFLAGS'"

# RK-only options for minimal RockChip-specific build
RK_ONLY_OPTIONS="--disable-everything \
    --disable-x86asm \
    --disable-programs \
    --disable-doc \
    --disable-avdevice \
    --disable-swscale \
    --disable-swresample \
    --disable-postproc \
    --disable-network \
    --disable-static \
    --disable-stripping \
    --enable-shared \
    --enable-version3 \
    --enable-ffmpeg \
    --enable-libdrm \
    --enable-rkrga \
    --enable-rkmpp \
    \
    --enable-protocol=file \
    \
    --enable-muxer=mp4 \
    --enable-muxer=avi \
    --enable-muxer=null \
    --enable-demuxer=mov \
    --enable-demuxer=matroska \
    --enable-demuxer=avi \
    \
    --enable-encoder=h264_rkmpp \
    --enable-encoder=hevc_rkmpp \
    --enable-encoder=mjpeg_rkmpp \
    \
    --enable-decoder=h264_rkmpp \
    --enable-decoder=av1_rkmpp \
    --enable-decoder=mjpeg_rkmpp \
    --enable-decoder=hevc_rkmpp \
    --enable-decoder=vp8_rkmpp \
    --enable-decoder=vp9_rkmpp \
    --enable-decoder=h263_rkmpp \
    --enable-decoder=mpeg1_rkmpp \
    --enable-decoder=mpeg2_rkmpp \
    --enable-decoder=mpeg4_rkmpp \
    \
    --enable-parser=h264 \
    --enable-parser=hevc \
    --enable-parser=mjpeg \
    --enable-parser=av1 \
    --enable-parser=vp8 \
    --enable-parser=vp9 \
    --enable-parser=h263 \
    --enable-parser=mpegvideo \
    --enable-parser=mpeg4video \
    \
    --enable-avfilter \
    --enable-filter=scale_rkrga \
    --enable-filter=vpp_rkrga"
# 完整的配置选项
COMPLETE_OPTIONS="--enable-gpl --enable-version3 --enable-libdrm --enable-rkmpp --enable-rkrga"

# 根据选择的FFmpeg选项设置configure命令
case "$FFMPEG_OPTIONS" in
    rk_only)
        CONFIGURE_CMD="$CONFIGURE_CMD $RK_ONLY_OPTIONS"
        echo -e "${BLUE}使用RockChip专用最小化编译选项${NC}"
        ;;
    complete)
        CONFIGURE_CMD="$CONFIGURE_CMD $COMPLETE_OPTIONS"
        echo -e "${BLUE}使用完整编译选项${NC}"
        ;;
    *)
        echo -e "${RED}错误: 不支持的FFmpeg选项: $FFMPEG_OPTIONS${NC}"
        echo -e "${RED}支持的选项: rk_only, complete${NC}"
        exit 1
        ;;
esac

# 打印配置信息
echo -e "${BLUE}FFMPEG 构建配置:${NC}"
echo -e "${BLUE}  目标架构: $TARGET${NC}"
echo -e "${BLUE}  FFmpeg选项: $FFMPEG_OPTIONS${NC}"
echo -e "${BLUE}  项目根目录: $PROJECT_ROOT_DIR${NC}"
echo -e "${BLUE}  源码目录: $FFMPEG_SOURCE_DIR${NC}"
echo -e "${BLUE}  构建目录: $BUILD_DIR${NC}"
echo -e "${BLUE}  构建类型: $BUILD_TYPE${NC}"
echo -e "${BLUE}  安装目录: $INSTALL_DIR${NC}"

# 执行CONFIGURE配置
echo -e "${GREEN}执行配置: $CONFIGURE_CMD${NC}"
eval "$CONFIGURE_CMD"

if [ $? -ne 0 ]; then
    echo -e "${RED}CONFIGURE配置失败!${NC}"
    exit 1
fi
# 修复 config.h 中的 HAVE_SYSCTL 定义
echo "修复 config.h 中的 SYSCTL 设置..."
sed -i 's/#define HAVE_SYSCTL 1/#define HAVE_SYSCTL 0/' config.h


# 编译
echo -e "${GREEN}开始编译FFMPEG...${NC}"
make

if [ $? -ne 0 ]; then
    echo -e "${RED}编译FFMPEG失败!${NC}"
    exit 1
fi

# 安装
echo -e "${GREEN}开始安装...${NC}"
make install

# 检查安装结果
if [ $? -eq 0 ]; then
    echo -e "${GREEN}安装成功!${NC}"
    # 复制build_deps依赖动态库到安装目录
    echo -e "${YELLOW}复制 RKRGA 库到安装目录...${NC}"
    if [ -d "$RKRGA_PATH/lib" ]; then
        cp -rf "$RKRGA_PATH/lib/"* "$INSTALL_DIR/lib/" 2>/dev/null || true            
    fi
    if [ -d "$RKRGA_PATH/include" ]; then
        cp -rf "$RKRGA_PATH/include/"* "$INSTALL_DIR/include/" 2>/dev/null || true
    fi
    echo -e "${GREEN}RKRGA 库已复制到: $INSTALL_DIR/lib/${NC}"

    echo -e "${YELLOW}复制 RKMPP 库到安装目录...${NC}"
    if [ -d "$RKMPP_PATH/lib" ]; then
        cp -rf "$RKMPP_PATH/lib/"* "$INSTALL_DIR/lib/" 2>/dev/null || true            
    fi
    if [ -d "$RKMPP_PATH/include" ]; then
        cp -rf "$RKMPP_PATH/include/"* "$INSTALL_DIR/include/" 2>/dev/null || true
    fi    
    echo -e "${GREEN}RKMPP 库已复制到: $INSTALL_DIR/lib/${NC}"

    if [ "$OPTIMIZE_SIZE" = true ]; then
        echo -e "${YELLOW}执行额外的库文件压缩...${NC}"
        
        # 检查strip工具是否可用，优先使用平台特定的工具
        STRIP_TOOL="strip"
        
        if [[ "$TARGET" == *"-linux-android"* ]]; then
            # Android 使用 NDK 的 strip 工具
            if [ -n "$TOOLCHAIN" ] && [ -f "$TOOLCHAIN/bin/llvm-strip" ]; then
                STRIP_TOOL="$TOOLCHAIN/bin/llvm-strip"
            elif command -v "llvm-strip" &> /dev/null; then
                STRIP_TOOL="llvm-strip"
            fi
        elif [[ "$TARGET" == *"-linux-harmonyos"* ]]; then
            # HarmonyOS 使用 SDK 的 strip 工具
            if [ -n "$TOOLCHAIN" ] && [ -f "$TOOLCHAIN/bin/llvm-strip" ]; then
                STRIP_TOOL="$TOOLCHAIN/bin/llvm-strip"
            elif command -v "llvm-strip" &> /dev/null; then
                STRIP_TOOL="llvm-strip"
            fi
        else
            # 其他平台使用通用的 strip 工具
            if command -v "${TARGET%-*}-strip" &> /dev/null; then
                STRIP_TOOL="${TARGET%-*}-strip"
            elif command -v "llvm-strip" &> /dev/null; then
                STRIP_TOOL="llvm-strip"
            fi
        fi
        
        echo -e "${BLUE}使用 strip 工具: $STRIP_TOOL${NC}"
        
        # 压缩所有共享库
        if [ -d "$INSTALL_DIR/lib" ]; then
            find "$INSTALL_DIR/lib" -name "*.so*" -type f -exec $STRIP_TOOL --strip-unneeded {} \; 2>/dev/null || true
            find "$INSTALL_DIR/lib" -name "*.a" -type f -exec $STRIP_TOOL --strip-debug {} \; 2>/dev/null || true
            echo -e "${GREEN}库文件压缩完成!${NC}"
        fi
        
    fi
    
    echo -e "${GREEN}FFMPEG库文件位于: $INSTALL_DIR/lib/${NC}"
    echo -e "${GREEN}FFMPEG头文件位于: $INSTALL_DIR/include/${NC}"
    
    # 显示安装的文件和大小
    if [ -d "$INSTALL_DIR/lib" ]; then
        echo -e "${BLUE}安装的库文件:${NC}"
        find "$INSTALL_DIR/lib" -name "*.so*" -o -name "*.a" | head -10 | while read file; do
            size=$(du -h "$file" 2>/dev/null | cut -f1)
            echo "  $file ($size)"
        done
    fi
    
    if [ -d "$INSTALL_DIR/include" ]; then
        echo -e "${BLUE}安装的头文件目录:${NC}"
        find "$INSTALL_DIR/include" -type d | head -5
    fi
    
    # 返回到项目根目录
    cd "$PROJECT_ROOT_DIR"
else
    echo -e "${RED}安装FFMPEG失败!${NC}"
    exit 1
fi
