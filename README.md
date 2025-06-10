# LibDRM Zig 交叉编译工具链

一个强大的交叉编译工具链，使用 Zig 编译器在多个平台和架构上构建 libdrm（直接渲染管理器）库。

## 🚀 特性

- **多平台支持**：支持 Linux、Android、HarmonyOS、Windows 和 macOS
- **广泛的架构覆盖**：x86_64、ARM64、ARM32、RISC-V、LoongArch
- **Zig 驱动**：利用 Zig 出色的交叉编译能力
- **优化构建**：可选择的大小优化，同时保持性能
- **GPU 驱动支持**：可配置的各种 GPU 厂商支持（Intel、AMD、NVIDIA 等）
- **自动下载**：自动下载和解压 libdrm 源代码
- **时钟偏差修复**：内置的 meson 时钟偏差问题解决方案

## 📋 前置要求

### 必需工具
- **Zig**（最新稳定版）：[下载 Zig](https://ziglang.org/download/)
- **Meson**：构建系统
- **Python 3**：用于构建脚本和工具
- **标准构建工具**：make、ninja

### 安装命令
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install python3-pip ninja-build
pip3 install meson

# Arch Linux
sudo pacman -S meson ninja python

# macOS
brew install meson ninja python3
```

### 平台特定要求

#### Android 开发
```bash
# 设置 Android NDK 路径
export ANDROID_NDK_HOME=/path/to/android-ndk-r21e
```

#### HarmonyOS 开发
```bash
# 设置 HarmonyOS SDK 路径
export HARMONYOS_SDK_HOME=/path/to/ohos-sdk/native
```

## 🎯 支持的目标平台

### Linux 目标
- `x86_64-linux-gnu` - x86_64 Linux (GNU libc)
- `aarch64-linux-gnu` - ARM64 Linux (GNU libc)
- `arm-linux-gnueabihf` - ARM 32位 Linux (GNU libc)
- `riscv64-linux-gnu` - RISC-V 64位 Linux
- `loongarch64-linux-gnu` - LoongArch64 Linux

### Android 目标
- `aarch64-linux-android` - ARM64 Android
- `arm-linux-android` - ARM 32位 Android
- `x86_64-linux-android` - x86_64 Android
- `x86-linux-android` - x86 32位 Android

### HarmonyOS 目标
- `aarch64-linux-harmonyos` - ARM64 HarmonyOS
- `arm-linux-harmonyos` - ARM 32位 HarmonyOS
- `x86_64-linux-harmonyos` - x86_64 HarmonyOS

### 桌面目标
- `x86_64-windows-gnu` - x86_64 Windows (MinGW)
- `aarch64-windows-gnu` - ARM64 Windows (MinGW)
- `x86_64-macos` - x86_64 macOS
- `aarch64-macos` - ARM64 macOS (Apple Silicon)

## 🔧 使用方法

### 基本构建
```bash
# 为默认目标构建 (x86_64-linux-gnu)
./build_with_zig.sh

# 为特定目标构建
./build_with_zig.sh --target=aarch64-linux-gnu

# 使用位置参数构建
./build_with_zig.sh aarch64-linux-gnu
```

### 高级选项
```bash
# 启用大小优化构建
./build_with_zig.sh --target=aarch64-linux-android --optimize-size

# 启用示例程序构建
./build_with_zig.sh --target=x86_64-linux-gnu --enable-demos

# 构建特定的 libdrm 版本
./build_with_zig.sh --target=aarch64-linux-gnu --version=2.4.120

# 组合多个选项
./build_with_zig.sh --target=arm-linux-android --optimize-size --enable-demos --version=2.4.125
```

### 维护命令
```bash
# 清理构建目录
./build_with_zig.sh clean

# 清理构建和安装目录
./build_with_zig.sh clean-dist

# 显示帮助
./build_with_zig.sh --help
```

## 📂 项目结构

```
├── build_with_zig.sh           # 主构建脚本
├── patch_meson_clockskew.py    # Meson 时钟偏差修复工具
├── cross-build.txt             # 生成的交叉编译配置
├── libdrm-2.4.125/            # 下载的 libdrm 源码
├── libdrm_build/              # 构建目录（按目标分类）
│   └── <target>/
│       ├── libdrm.so          # 共享库
│       ├── libdrm.a           # 静态库
│       └── ...
└── libdrm_install/            # 安装目录
    └── Release/
        └── <target>/
            ├── lib/           # 库文件
            ├── include/       # 头文件
            └── bin/           # 示例程序（如果启用）
```

## 🎛️ 配置选项

### GPU 驱动支持

构建脚本根据目标平台自动配置 GPU 驱动支持：

#### 桌面 Linux (x86_64/x86)
- ✅ Intel 显卡
- ✅ AMD Radeon/AMDGPU
- ✅ NVIDIA Nouveau
- ✅ VMware SVGA

#### ARM Linux
- ✅ AMD Radeon/AMDGPU (PCIe)
- ✅ NVIDIA Nouveau (PCIe)
- ✅ ARM Mali (Etnaviv)
- ✅ Qualcomm Adreno (Freedreno)
- ✅ NVIDIA Tegra
- ✅ Broadcom VideoCore IV

#### 移动平台 (Android/HarmonyOS)
- ✅ Qualcomm Adreno (Freedreno)
- ✅ ARM Mali (Etnaviv)
- ✅ Samsung Exynos
- ✅ TI OMAP
- ✅ NVIDIA Tegra
- ✅ Broadcom VideoCore IV

### 构建优化

#### 大小优化 (`--optimize-size`)
- 编译器标志：`-Os -DNDEBUG -ffunction-sections -fdata-sections -fvisibility=hidden`
- 链接器标志：`-Wl,--gc-sections -Wl,--strip-all`
- 构建后剥离调试符号

#### 标准优化（默认）
- 编译器标志：`-O2 -DNDEBUG`
- 平衡性能和大小

## 🛠️ 故障排除

### 常见问题

#### 1. 找不到 Zig
```bash
# 安装 Zig
wget https://ziglang.org/download/0.11.0/zig-linux-x86_64-0.11.0.tar.xz
tar -xf zig-linux-x86_64-0.11.0.tar.xz
export PATH=$PWD/zig-linux-x86_64-0.11.0:$PATH
```

#### 2. Meson 时钟偏差问题
脚本会自动修补 meson 以处理时钟偏差问题。如果问题持续存在：
```bash
python3 patch_meson_clockskew.py
```

#### 3. Android NDK 路径问题
```bash
export ANDROID_NDK_HOME=/path/to/your/ndk
export ANDROID_NDK_ROOT=$ANDROID_NDK_HOME
```

#### 4. HarmonyOS SDK 问题
```bash
export HARMONYOS_SDK_HOME=/path/to/ohos-sdk/native
# 确保 SDK 结构符合预期
```

### 构建失败

#### 缺少依赖项
```bash
# Ubuntu/Debian
sudo apt install build-essential pkg-config

# Arch Linux
sudo pacman -S base-devel pkgconf

# macOS
xcode-select --install
```

#### 交叉编译问题
- 确保目标架构正确指定
- 检查所需的 SDK/NDK 已正确安装
- 验证环境变量设置正确

## 📊 性能基准

### 库文件大小（ARM64 Android，优化版）
- `libdrm.so`：约 45KB（未优化版约 120KB）
- `libdrm.a`：约 78KB（未优化版约 180KB）

### 构建时间
- 本地 x86_64：约 30 秒
- 交叉编译 ARM64：约 45 秒
- 完整 GPU 支持交叉编译：约 60 秒

## 🔍 技术细节

### 交叉编译策略
1. **Zig 作为通用编译器**：使用 Zig 内置的交叉编译功能
2. **动态配置**：为每个目标生成 meson 交叉编译文件
3. **SDK 集成**：与平台 SDK 无缝集成
4. **优化构建**：针对目标的优化策略

### GPU 驱动矩阵
| 平台 | Intel | AMD | NVIDIA | ARM Mali | Qualcomm | 其他 |
|------|-------|-----|--------|----------|----------|------|
| x86 Linux | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ |
| ARM Linux | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Android | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ |
| HarmonyOS | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ |
| Windows | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ |
| macOS | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

## 🤝 贡献

1. Fork 本仓库
2. 创建功能分支
3. 测试目标平台的交叉编译
4. 提交 Pull Request

### 添加新目标
1. 在 `get_target_info()` 中添加目标检测
2. 在主要 switch 语句中配置 GPU 驱动
3. 测试构建和功能
4. 更新文档

## 📄 许可证

本项目遵循与 libdrm 相同的许可证。构建脚本采用 MIT 许可证。

## 🔗 相关项目

- [libdrm](https://gitlab.freedesktop.org/mesa/drm) - 原始 libdrm 项目
- [Zig](https://ziglang.org/) - Zig 编程语言
- [Meson](https://mesonbuild.com/) - 构建系统

## 📧 支持

对于以下问题：
- **构建脚本**：在本仓库中创建 issue
- **libdrm 功能**：参考 [libdrm 文档](https://dri.freedesktop.org/wiki/DRM/)
- **Zig 交叉编译**：查看 [Zig 文档](https://ziglang.org/documentation/master/)

---

**注意**：这是一个交叉编译工具链。生成的库应在实际目标硬件上测试以进行完整验证。