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
ENABLE_DEMOS=false
LIBDRM_VERSION="2.4.125"

# 解析命令行参数
for arg in "$@"; do
  case $arg in
    --target=*)
      TARGET="${arg#*=}"
      shift
      ;;
    --version=*)
      LIBDRM_VERSION="${arg#*=}"
      shift
      ;;
    --optimize-size)
      OPTIMIZE_SIZE=true
      shift
      ;;
    --enable-demos)
      ENABLE_DEMOS=true
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
      echo "  --target=<目标>       指定目标架构 (默认: x86_64-linux-gnu)"
      echo "  --version=<版本>      指定libdrm版本 (默认: 2.4.125)"
      echo "  --optimize-size       启用库文件大小优化 (保持性能)"
      echo "  --enable-demos        启用示例程序编译"
      echo "  --help                显示此帮助信息"
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

# 参数配置
PROJECT_ROOT_DIR="$(pwd)"
LIBDRM_SOURCE_DIR="${PROJECT_ROOT_DIR}/libdrm-${LIBDRM_VERSION}"
BUILD_TYPE="release"
INSTALL_DIR="$PROJECT_ROOT_DIR/libdrm_install/Release/${TARGET}"
BUILD_DIR="$PROJECT_ROOT_DIR/libdrm_build/${TARGET}"

# 函数：下载并解压 libdrm 源码
download_libdrm() {
    local version="$1"
    local source_dir="$2"
    local archive_name="libdrm-${version}.tar.xz"
    local download_url="https://dri.freedesktop.org/libdrm/${archive_name}"
    
    echo -e "${YELLOW}检查 libdrm-${version} 源码目录...${NC}"
    
    # 检查源码目录是否存在
    if [ -d "$source_dir" ]; then
        echo -e "${GREEN}源码目录已存在: $source_dir${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}源码目录不存在，开始下载 libdrm-${version}...${NC}"
    
    # 检查必要的工具
    if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
        echo -e "${RED}错误: 需要 wget 或 curl 来下载文件${NC}"
        exit 1
    fi
    
    if ! command -v tar &> /dev/null; then
        echo -e "${RED}错误: 需要 tar 来解压文件${NC}"
        exit 1
    fi
    
    # 创建临时下载目录
    # local temp_dir=$(mktemp -d)
    local temp_dir=$PROJECT_ROOT_DIR
    local archive_path="${temp_dir}/${archive_name}"
    
    echo -e "${BLUE}下载地址: $download_url${NC}"
    echo -e "${BLUE}下载到: $archive_path${NC}"
    
    # 下载文件
    if command -v wget &> /dev/null; then
        wget -O "$archive_path" "$download_url"
    elif command -v curl &> /dev/null; then
        curl -L -o "$archive_path" "$download_url"
    fi
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载失败: $download_url${NC}"
        rm -rf "$archive_path"
        exit 1
    fi
    
    echo -e "${GREEN}下载完成，开始解压...${NC}"
    
    # 解压到项目根目录
    tar -xf "$archive_path" -C "$PROJECT_ROOT_DIR"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}解压失败: $archive_path${NC}"
        rm -rf "$archive_path"
        exit 1
    fi
    
    # 清理临时文件
    rm -rf "$archive_path"
    
    # 验证解压结果
    if [ -d "$source_dir" ]; then
        echo -e "${GREEN}libdrm-${version} 源码准备完成: $source_dir${NC}"
    else
        echo -e "${RED}解压后未找到预期的源码目录: $source_dir${NC}"
        exit 1
    fi
}

# 下载并准备 libdrm 源码
download_libdrm "$LIBDRM_VERSION" "$LIBDRM_SOURCE_DIR"


# patch meson 源码 fix_clock_skew_issues
echo "Patching meson to skip clock skew checks..."
python3 patch_meson_clockskew.py
echo "✅ Clock skew 修复完成"


if [ "$OPTIMIZE_SIZE" = true ]; then
    # 大小优化标志
    ZIG_OPTIMIZE_FLAGS="-Os -DNDEBUG -ffunction-sections -fdata-sections -fvisibility=hidden $ARCH_DEFINES"
    export LDFLAGS="-Wl,--gc-sections -Wl,--strip-all"
else
    ZIG_OPTIMIZE_FLAGS="-O2 -DNDEBUG $ARCH_DEFINES"
    export LDFLAGS=""
fi

# 处理清理动作
if [ "$ACTION" = "clean" ]; then
    echo -e "${YELLOW}清理构建目录和缓存...${NC}"
    rm -rf "$PROJECT_ROOT_DIR/libdrm_build"
    echo -e "${GREEN}构建目录已清理!${NC}"
    exit 0
elif [ "$ACTION" = "clean-dist" ]; then
    echo -e "${YELLOW}清理构建目录和安装目录...${NC}"
    rm -rf "$PROJECT_ROOT_DIR/libdrm_build"
    rm -rf "$PROJECT_ROOT_DIR/libdrm_install"
    echo -e "${GREEN}构建目录和安装目录已清理!${NC}"
    exit 0
fi

# 检查Zig是否安装
if ! command -v zig &> /dev/null; then
    echo -e "${RED}错误: 未找到Zig。请安装Zig: https://ziglang.org/download/${NC}"
    exit 1
fi

# 检查Meson是否安装
if ! command -v meson &> /dev/null; then
    echo -e "${RED}错误: 未找到meson。请安装meson: https://mesonbuild.com/Getting-meson.html${NC}"
    exit 1
fi


# 检查meson.build是否存在
if [ ! -f "$LIBDRM_SOURCE_DIR/meson.build" ]; then
    echo -e "${RED}错误: LIBDRM meson.build文件不存在: $LIBDRM_SOURCE_DIR/meson.build${NC}"
    exit 1
fi

# 创建安装目录
mkdir -p "$INSTALL_DIR"

# 创建LIBDRM构建目录（每次都清理，避免 Meson 缓存污染）
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 进入构建目录
cd "$BUILD_DIR"

# 使用 Zig 作为编译器
ZIG_PATH=$(command -v zig)

# 函数：根据目标架构获取系统信息
get_target_info() {
    local target="$1"
    
    case "$target" in
        x86_64-linux-gnu|x86_64-linux-android|x86_64-linux-harmonyos)
            echo "linux x86_64 x86_64 little"
            ;;
        aarch64-linux-gnu|aarch64-linux-android|aarch64-linux-harmonyos|aarch64-macos)
            echo "linux aarch64 aarch64 little"
            ;;
        arm-linux-gnueabihf|arm-linux-android|arm-linux-harmonyos)
            echo "linux arm arm little"
            ;;
        x86-linux-android)
            echo "linux x86 i386 little"
            ;;
        x86_64-windows-gnu)
            echo "windows x86_64 x86_64 little"
            ;;
        aarch64-windows-gnu)
            echo "windows aarch64 aarch64 little"
            ;;
        x86_64-macos)
            echo "darwin x86_64 x86_64 little"
            ;;
        riscv64-linux-gnu)
            echo "linux riscv64 riscv64 little"
            ;;
        loongarch64-linux-gnu)
            echo "linux loongarch64 loongarch64 little"
            ;;
        *)
            echo "linux unknown unknown little"
            ;;
    esac
}

# 设置交叉编译配置
export PKG_CONFIG=""
export PKG_CONFIG_PATH=""
export PKG_CONFIG_LIBDIR=""
echo -e "${YELLOW}交叉编译模式：已禁用pkg-config以避免主机系统库冲突${NC}"

# 获取目标架构信息
TARGET_INFO=($(get_target_info "$TARGET"))
TARGET_SYSTEM="${TARGET_INFO[0]}"
TARGET_CPU_FAMILY="${TARGET_INFO[1]}"
TARGET_CPU="${TARGET_INFO[2]}"
TARGET_ENDIAN="${TARGET_INFO[3]}"

# 根据优化设置确定编译参数
LDFLAGS_OPTIMIZE=""
if [ "$OPTIMIZE_SIZE" = true ]; then
    # 大小优化标志
    ZIG_OPTIMIZE_FLAGS="-Os -DNDEBUG -ffunction-sections -fdata-sections -fvisibility=hidden $ARCH_DEFINES"
    export LDFLAGS="-Wl,--gc-sections -Wl,--strip-all"
    LDFLAGS_OPTIMIZE="-Wl,--gc-sections -Wl,--strip-all"
else
    ZIG_OPTIMIZE_FLAGS="-O2 -DNDEBUG $ARCH_DEFINES"
    LDFLAGS_OPTIMIZE=""    
    export LDFLAGS=""
fi


CROSS_FILE=""
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

# 创建动态交叉编译配置文件
CROSS_FILE="$PROJECT_ROOT_DIR/cross-build.txt"
cat > "$CROSS_FILE" << EOF
[binaries]
c = '${TOOLCHAIN}/bin/${ANDROID_TARGET}${API_LEVEL}-clang'
cpp = '${TOOLCHAIN}/bin/${ANDROID_TARGET}${API_LEVEL}-clang++'
ar = '${TOOLCHAIN}/bin/llvm-ar'
strip = '${TOOLCHAIN}/bin/llvm-strip'
pkgconfig = 'pkg-config'

[host_machine]
system = '$TARGET_SYSTEM'
cpu_family = '$TARGET_CPU_FAMILY'
cpu = '$TARGET_CPU'
endian = '$TARGET_ENDIAN'

[built-in options]
c_std = 'c11'
default_library = 'both'
EOF
elif [[ "$TARGET" == *"-linux-harmonyos"* ]]; then
    # 检查 HarmonyOS SDK
    export HARMONYOS_SDK_ROOT="${HARMONYOS_SDK_HOME:-~/sdk/harmonyos/ohos-sdk/linux/native-linux-x64-4.1.9.4-Release/native}"
    if [ ! -d "$HARMONYOS_SDK_ROOT" ]; then
        echo -e "${RED}错误: HarmonyOS SDK 未找到: $HARMONYOS_SDK_ROOT${NC}"
        echo -e "${RED}请设置 HARMONYOS_SDK_HOME 环境变量${NC}"
        exit 1
    fi
    HARMONYOS_API_LEVEL=9
    
    case "$TARGET" in
        aarch64-linux-harmonyos)
            OHOS_ARCH=arm64-v8a
            TARGET=aarch64-linux-musl
            NDK_ARCH_DIR=aarch64
            ;;
        arm-linux-harmonyos)
            OHOS_ARCH=armeabi-v7a
            TARGET=arm-linux-musleabi
            NDK_ARCH_DIR=arm
            ;;
        x86_64-linux-harmonyos)
            OHOS_ARCH=x86_64
            TARGET=x86_64-linux-musl
            NDK_ARCH_DIR=x86_64
            ;;
        x86-linux-harmonyos)
            OHOS_ARCH=x86
            TARGET=x86-linux-musl
            NDK_ARCH_DIR=x86
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
    # 使用 Zig 作为编译器，配合 HarmonyOS SDK 的 libc
    # 避免使用 --sysroot 和 -L 同时，因为 Zig 会错误地连接路径
    # 使用 --sysroot 主要用于 headers 和 system libraries    
    # 设置 LDFLAGS 来指定额外的库搜索路径
    export LDFLAGS="-L$HARMONYOS_LIB $LDFLAGS_OPTIMIZE"
    # 创建动态交叉编译配置文件
    CROSS_FILE="$PROJECT_ROOT_DIR/cross-build.txt"
cat > "$CROSS_FILE" << EOF
[binaries]
c = ['zig', 'cc', '-target', '$TARGET','--sysroot', '$HARMONYOS_SYSROOT']
cpp = ['zig', 'c++', '-target', '$TARGET','--sysroot', '$HARMONYOS_SYSROOT']
ar = ['zig', 'ar']
strip = ['zig', 'strip']
pkg-config = 'pkg-config'

[host_machine]
system = '$TARGET_SYSTEM'
cpu_family = '$TARGET_CPU_FAMILY'
cpu = '$TARGET_CPU'
endian = '$TARGET_ENDIAN'

[built-in options]
c_std = 'c11'
default_library = 'both'
EOF

else
# 创建动态交叉编译配置文件
CROSS_FILE="$PROJECT_ROOT_DIR/cross-build.txt"
cat > "$CROSS_FILE" << EOF
[binaries]
c = ['zig', 'cc', '-target', '$TARGET']
cpp = ['zig', 'c++', '-target', '$TARGET']
ar = ['zig', 'ar']
strip = ['zig', 'strip']
pkg-config = 'pkg-config'

[host_machine]
system = '$TARGET_SYSTEM'
cpu_family = '$TARGET_CPU_FAMILY'
cpu = '$TARGET_CPU'
endian = '$TARGET_ENDIAN'

[built-in options]
c_std = 'c11'
default_library = 'both'
EOF
fi

echo -e "${BLUE}动态生成交叉编译配置文件: $CROSS_FILE${NC}"
echo -e "${BLUE}  系统: $TARGET_SYSTEM${NC}"
echo -e "${BLUE}  CPU族: $TARGET_CPU_FAMILY${NC}"
echo -e "${BLUE}  CPU: $TARGET_CPU${NC}"
echo -e "${BLUE}  字节序: $TARGET_ENDIAN${NC}"

export CC="$ZIG_PATH cc -target $TARGET $ZIG_OPTIMIZE_FLAGS"
export CXX="$ZIG_PATH c++ -target $TARGET $ZIG_OPTIMIZE_FLAGS"

echo -e "${BLUE}Zig 编译器配置:${NC}"
echo -e "${BLUE}  原始目标: $TARGET${NC}"
echo -e "${BLUE}  Zig 目标: $TARGET${NC}"
echo -e "${BLUE}  Meson 系统名: $MESON_SYSTEM_NAME${NC}"
echo -e "${BLUE}  Meson 处理器: $MESON_SYSTEM_PROCESSOR${NC}"
echo -e "${BLUE}  大小优化: $OPTIMIZE_SIZE${NC}"
echo -e "${BLUE}  启用示例: $ENABLE_DEMOS${NC}"
echo -e "${BLUE}  CC: $CC${NC}"
echo -e "${BLUE}  CXX: $CXX${NC}"

# Configure build options based on target
meson_options=""

# Set test and demo options based on user preferences
if [ "$ENABLE_DEMOS" = true ]; then
    test_options="-Dtests=true -Dinstall-test-programs=true"
else
    test_options="-Dtests=false -Dinstall-test-programs=false"
fi

case "$TARGET" in
    *android*|*harmonyos*)
        # Mobile/embedded platforms - focus on mobile GPU drivers
        meson_options=""
        meson_options+=" -Dintel=disabled"
        meson_options+=" -Dradeon=disabled"
        meson_options+=" -Damdgpu=disabled"
        meson_options+=" -Dnouveau=disabled"
        meson_options+=" -Dvmwgfx=disabled"
        meson_options+=" -Domap=auto"
        meson_options+=" -Dexynos=auto"
        meson_options+=" -Dfreedreno=auto"
        meson_options+=" -Dtegra=auto"
        meson_options+=" -Dvc4=auto"
        meson_options+=" -Detnaviv=auto"
        meson_options+=" $test_options"
        meson_options+=" -Dman-pages=disabled"
        meson_options+=" -Dvalgrind=disabled"
        meson_options+=" -Dcairo-tests=disabled"
        meson_options+=" -Dudev=false"
        meson_options+=" -Dfreedreno-kgsl=true"
        ;;
    aarch64-linux-gnu|arm-linux-gnueabihf|arm-linux-gnu)
        # ARM Linux - enable ARM SoC and PCIe GPU drivers
        meson_options=""
        meson_options+=" -Dintel=disabled"
        meson_options+=" -Dradeon=auto"
        meson_options+=" -Damdgpu=auto"
        meson_options+=" -Dnouveau=auto"
        meson_options+=" -Dvmwgfx=disabled"
        meson_options+=" -Domap=auto"
        meson_options+=" -Dexynos=auto"
        meson_options+=" -Dfreedreno=auto"
        meson_options+=" -Dtegra=auto"
        meson_options+=" -Dvc4=auto"
        meson_options+=" -Detnaviv=auto"
        meson_options+=" $test_options"
        meson_options+=" -Dman-pages=disabled"
        meson_options+=" -Dvalgrind=disabled"
        meson_options+=" -Dcairo-tests=disabled"
        meson_options+=" -Dudev=true"
        meson_options+=" -Dfreedreno-kgsl=false"
        ;;
    x86_64-linux-gnu|x86-linux-gnu)
        # x86 Linux - enable all desktop GPU drivers
        meson_options=""
        meson_options+=" -Dintel=auto"
        meson_options+=" -Dradeon=auto"
        meson_options+=" -Damdgpu=auto"
        meson_options+=" -Dnouveau=auto"
        meson_options+=" -Dvmwgfx=auto"
        meson_options+=" -Domap=disabled"
        meson_options+=" -Dexynos=disabled"
        meson_options+=" -Dfreedreno=disabled"
        meson_options+=" -Dtegra=disabled"
        meson_options+=" -Dvc4=disabled"
        meson_options+=" -Detnaviv=disabled"
        meson_options+=" $test_options"
        meson_options+=" -Dman-pages=disabled"
        meson_options+=" -Dvalgrind=disabled"
        meson_options+=" -Dcairo-tests=disabled"
        meson_options+=" -Dudev=true"
        meson_options+=" -Dfreedreno-kgsl=false"
        ;;
    *loongarch64*|*riscv64*)
        # Alternative architectures - conservative GPU support
        meson_options=""
        meson_options+=" -Dintel=disabled"
        meson_options+=" -Dradeon=auto"
        meson_options+=" -Damdgpu=auto"
        meson_options+=" -Dnouveau=auto"
        meson_options+=" -Dvmwgfx=disabled"
        meson_options+=" -Domap=disabled"
        meson_options+=" -Dexynos=disabled"
        meson_options+=" -Dfreedreno=auto"
        meson_options+=" -Dtegra=auto"
        meson_options+=" -Dvc4=auto"
        meson_options+=" -Detnaviv=auto"
        meson_options+=" $test_options"
        meson_options+=" -Dman-pages=disabled"
        meson_options+=" -Dvalgrind=disabled"
        meson_options+=" -Dcairo-tests=disabled"
        meson_options+=" -Dudev=true"
        meson_options+=" -Dfreedreno-kgsl=false"
        ;;
    *windows*)
        # Windows - minimal support, no Linux-specific features
        meson_options=""
        meson_options+=" -Dintel=auto"
        meson_options+=" -Dradeon=auto"
        meson_options+=" -Damdgpu=auto"
        meson_options+=" -Dnouveau=auto"
        meson_options+=" -Dvmwgfx=auto"
        meson_options+=" -Domap=disabled"
        meson_options+=" -Dexynos=disabled"
        meson_options+=" -Dfreedreno=disabled"
        meson_options+=" -Dtegra=disabled"
        meson_options+=" -Dvc4=disabled"
        meson_options+=" -Detnaviv=disabled"
        meson_options+=" $test_options"
        meson_options+=" -Dman-pages=disabled"
        meson_options+=" -Dvalgrind=disabled"
        meson_options+=" -Dcairo-tests=disabled"
        meson_options+=" -Dudev=false"
        meson_options+=" -Dfreedreno-kgsl=false"
        ;;
    *macos*)
        # macOS - very minimal support, only basic functionality
        meson_options=""
        meson_options+=" -Dintel=disabled"
        meson_options+=" -Dradeon=disabled"
        meson_options+=" -Damdgpu=disabled"
        meson_options+=" -Dnouveau=disabled"
        meson_options+=" -Dvmwgfx=disabled"
        meson_options+=" -Domap=disabled"
        meson_options+=" -Dexynos=disabled"
        meson_options+=" -Dfreedreno=disabled"
        meson_options+=" -Dtegra=disabled"
        meson_options+=" -Dvc4=disabled"
        meson_options+=" -Detnaviv=disabled"
        meson_options+=" $test_options"
        meson_options+=" -Dman-pages=disabled"
        meson_options+=" -Dvalgrind=disabled"
        meson_options+=" -Dcairo-tests=disabled"
        meson_options+=" -Dudev=false"
        meson_options+=" -Dfreedreno-kgsl=false"
        ;;        
    *)
        # Default fallback - conservative settings
        meson_options=""
        meson_options+=" -Dintel=auto"
        meson_options+=" -Dradeon=auto"
        meson_options+=" -Damdgpu=auto"
        meson_options+=" -Dnouveau=auto"
        meson_options+=" -Dvmwgfx=auto"
        meson_options+=" -Domap=disabled"
        meson_options+=" -Dexynos=disabled"
        meson_options+=" -Dfreedreno=auto"
        meson_options+=" -Dtegra=auto"
        meson_options+=" -Dvc4=auto"
        meson_options+=" -Detnaviv=auto"
        meson_options+=" $test_options"
        meson_options+=" -Dman-pages=disabled"
        meson_options+=" -Dvalgrind=disabled"
        meson_options+=" -Dcairo-tests=disabled"
        meson_options+=" -Dudev=false"
        meson_options+=" -Dfreedreno-kgsl=false"
        ;;
esac

MESON_CMD="meson setup $BUILD_DIR $LIBDRM_SOURCE_DIR -Dprefix=$INSTALL_DIR -Dbuildtype=$BUILD_TYPE -Dlibdir=lib"
if [ -n "$CROSS_FILE" ]; then
    MESON_CMD="$MESON_CMD --cross-file=$CROSS_FILE"
fi
# Always add meson options
MESON_CMD="$MESON_CMD $meson_options"


# 打印配置信息
echo -e "${BLUE}LIBDRM 构建配置:${NC}"
echo -e "${BLUE}  目标架构: $TARGET${NC}"
echo -e "${BLUE}  源码目录: $LIBDRM_SOURCE_DIR${NC}"
echo -e "${BLUE}  构建目录: $BUILD_DIR${NC}"
echo -e "${BLUE}  构建类型: $BUILD_TYPE${NC}"
echo -e "${BLUE}  安装目录: $INSTALL_DIR${NC}"
echo -e "${BLUE}  Meson 选项: $meson_options${NC}"

# 执行Meson配置
echo -e "${GREEN}执行配置: $MESON_CMD${NC}"
eval "$MESON_CMD"

if [ $? -ne 0 ]; then
    echo -e "${RED}Meson配置失败!${NC}"
    exit 1
fi

# 编译
echo -e "${GREEN}开始编译LIBDRM...${NC}"
ninja -C $BUILD_DIR

if [ $? -ne 0 ]; then
    echo -e "${RED}编译LIBDRM失败!${NC}"
    exit 1
fi

# 安装
echo -e "${GREEN}开始安装...${NC}"
ninja -C $BUILD_DIR install

# 检查安装结果
if [ $? -eq 0 ]; then
    echo -e "${GREEN}安装成功!${NC}"
    
    # 如果启用了大小优化，进行额外的压缩处理
    if [ "$OPTIMIZE_SIZE" = true ]; then
        echo -e "${YELLOW}执行额外的库文件压缩...${NC}"
        
        # 检查strip工具是否可用
        STRIP_TOOL="strip"
        if command -v "${TARGET%-*}-strip" &> /dev/null; then
            STRIP_TOOL="${TARGET%-*}-strip"
        elif command -v "llvm-strip" &> /dev/null; then
            STRIP_TOOL="llvm-strip"
        fi
        
        # 压缩所有共享库
        if [ -d "$INSTALL_DIR/lib" ]; then
            find "$INSTALL_DIR/lib" -name "*.so*" -type f -exec $STRIP_TOOL --strip-unneeded {} \; 2>/dev/null || true
            find "$INSTALL_DIR/lib" -name "*.a" -type f -exec $STRIP_TOOL --strip-debug {} \; 2>/dev/null || true
            echo -e "${GREEN}库文件压缩完成!${NC}"
        fi
        
    fi
    
    echo -e "${GREEN}LIBDRM库文件位于: $INSTALL_DIR/lib/${NC}"
    echo -e "${GREEN}LIBDRM头文件位于: $INSTALL_DIR/include/${NC}"
    
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
    
    # 如果启用了示例，显示示例程序位置
    if [ "$ENABLE_DEMOS" = true ] && [ -d "$INSTALL_DIR/bin" ]; then
        echo -e "${BLUE}安装的示例程序:${NC}"
        find "$INSTALL_DIR/bin" -type f | head -10 | while read file; do
            size=$(du -h "$file" 2>/dev/null | cut -f1)
            echo "  $file ($size)"
        done
    fi
    
    # 返回到项目根目录
    cd "$PROJECT_ROOT_DIR"
else
    echo -e "${RED}安装LIBDRM失败!${NC}"
    exit 1
fi
