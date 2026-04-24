#!/bin/bash
set -euo pipefail

# === 环境检查 ===
command -v rpmbuild >/dev/null 2>&1 || { echo "错误：未安装 rpmbuild，请先安装 (yum install -y rpm-build rpmdevtools)"; exit 1; }
command -v cargo >/dev/null 2>&1 || { echo "错误：未找到 cargo，请确保 rust 环境已配置 (source ~/.cargo/env)"; exit 1; }
command -v btrfs >/dev/null 2>&1 || { echo "错误：未找到 btrfs 工具，请先安装 (yum install -y btrfs-progs)"; exit 1; }
command -v rsync >/dev/null 2>&1 || { echo "错误：未找到 rsync，请先安装 (yum install -y rsync)"; exit 1; }
grep -q btrfs /proc/filesystems 2>/dev/null || { echo "错误：内核未启用 btrfs 模块，请执行 modprobe btrfs"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
OUTPUT_DIR="${PROJECT_ROOT}/rpm-sources"

# 从 src/Cargo.toml workspace 中查找版本（取第一个 version 字段）
VERSION=$(grep -m1 '^version' "$PROJECT_ROOT/src/Cargo.toml" 2>/dev/null | sed 's/version = "\(.*\)"/\1/' || echo "")
if [ -z "$VERSION" ]; then
    # fallback：从各 crate 中取版本
    VERSION=$(grep -r -m1 '^version' "$PROJECT_ROOT/src/crates/" 2>/dev/null | head -1 | sed 's/.*version = "\(.*\)"/\1/' || echo "0.1.0")
fi

# === 前置文件校验 ===
if [ ! -f "$PROJECT_ROOT/ws-ckpt.spec.in" ]; then
    echo "错误：未找到 $PROJECT_ROOT/ws-ckpt.spec.in"
    exit 1
fi
if [ ! -f "$PROJECT_ROOT/src/systemd/ws-ckpt.service" ]; then
    echo "错误：未找到 systemd service 文件 $PROJECT_ROOT/src/systemd/ws-ckpt.service"
    exit 1
fi
if [ ! -f "$PROJECT_ROOT/src/config.toml" ]; then
    echo "错误：未找到配置文件 $PROJECT_ROOT/src/config.toml"
    exit 1
fi

echo "=== 构建 ws-ckpt RPM 包 ==="
echo "构建用户: $(whoami)"
echo "Rust 工具链: $(rustc --version 2>/dev/null || echo '未知')"
echo ""

# 1. 编译 release 二进制
echo "[1/4] 编译 release 二进制..."
cd "$PROJECT_ROOT/src"
cargo build --release

if [[ ! -f "target/release/ws-ckpt" ]]; then
    echo "错误：未找到编译产物 target/release/ws-ckpt"
    exit 1
fi

# 2. 准备 tarball 内容
echo "[2/4] 准备 tarball 内容..."
TARBALL_NAME="ws-ckpt-${VERSION}"
TARBALL_DIR="${OUTPUT_DIR}/${TARBALL_NAME}"
mkdir -p "$TARBALL_DIR"

cp "$PROJECT_ROOT/src/target/release/ws-ckpt" "$TARBALL_DIR/"
cp "$PROJECT_ROOT/src/systemd/ws-ckpt.service" "$TARBALL_DIR/"
cp "$PROJECT_ROOT/src/config.toml" "$TARBALL_DIR/"

# 3. 生成 tarball 并替换 spec
echo "[3/4] 打包 tarball 并生成 spec..."
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"
tar -czvf "${TARBALL_NAME}.tar.gz" "$TARBALL_NAME"

SPEC_FILE="${OUTPUT_DIR}/ws-ckpt.spec"
sed "s/@VERSION@/${VERSION}/g" "$PROJECT_ROOT/ws-ckpt.spec.in" > "$SPEC_FILE"

# 4. 构建 RPM
echo "[4/4] 构建 RPM 包..."
BUILD_DIR="${OUTPUT_DIR}/rpmbuild"
mkdir -p "$BUILD_DIR"/{BUILD,RPMS,SRPMS}

rpmbuild --define "_topdir $BUILD_DIR" \
         --define "_sourcedir $OUTPUT_DIR" \
         -bb "$SPEC_FILE"

# 输出结果
RPM_FILE=$(find "$BUILD_DIR/RPMS" -name "*.rpm" | head -1)
if [ -n "$RPM_FILE" ]; then
    cp "$RPM_FILE" "$OUTPUT_DIR/"
    RPM_PATH="${OUTPUT_DIR}/$(basename "$RPM_FILE")"
    echo ""
    echo "RPM 包位置：$RPM_PATH"
    echo ""
    echo "安装方式："
    echo "  rpm -ivh $RPM_PATH"
    echo ""
    echo "打入镜像时在 kickstart/packer 脚本中添加："
    echo "  rpm -ivh /path/to/$(basename "$RPM_FILE")"
    echo "  systemctl enable ws-ckpt"
else
    echo "错误：未找到生成的 RPM 包"
    exit 1
fi
