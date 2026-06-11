#!/usr/bin/env bash
# 2026-06-11 — feat/ckpt-overlayfs-backend 增量测试
# 主体: OverlayFS 第三后端 (动态分层 + 层数上限保护 + 错误码映射)
# 领先 commit: 42369bc temp (WIP OverlayFS backend, 688 行)
# 全部为静态源码契约断言, Mac/Linux 均可跑;
# 运行时层切换/上限触发需 Linux+DeltaFS 内核+二进制, 本轮不实跑。
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../_lib/common.sh"

tc_log "feat/ckpt-overlayfs-backend — OverlayFS dynamic-layer backend (2026-06-11)"

# 分支守卫: 仅在含本后端源码的分支(overlayfs 分支或已合并)上跑; 否则整体 SKIP。
if ! tc_require_branch "overlayfs 静态用例(2026-06-11)" "feat/ckpt-overlayfs-backend"; then
  tc_summary; exit $?
fi

COMMON_BACKEND="$TC_WSCKPT_SRC/crates/common/src/backend.rs"
COMMON_LIB="$TC_WSCKPT_SRC/crates/common/src/lib.rs"
CLI_MAIN="$TC_WSCKPT_SRC/crates/cli/src/main.rs"
DAEMON_DIR="$TC_WSCKPT_SRC/crates/daemon/src"
DETECT="$DAEMON_DIR/backend_detect.rs"
DISPATCHER="$DAEMON_DIR/dispatcher.rs"
BACKENDS_MOD="$DAEMON_DIR/backends/mod.rs"
OVERLAY="$DAEMON_DIR/backends/overlayfs.rs"

# ============================================================
# 1. common backend.rs — 枚举与类型
# ============================================================
if [ -f "$COMMON_BACKEND" ]; then
  C="$(cat "$COMMON_BACKEND")"
  tc_assert_contains "1.1 BackendType::OverlayFs 变体"   "OverlayFs"                   "$C"
  tc_assert_contains "1.2 Display 输出 overlayfs"        'write!(f, "overlayfs")'      "$C"
  tc_assert_contains "1.3 BackendError 枚举"             "enum BackendError"           "$C"
  tc_assert_contains "1.4 LayerLimitExceeded 变体"       "LayerLimitExceeded"          "$C"
  tc_assert_contains "1.5 LayerLimitExceeded 含 kind"    "kind: &'static str"          "$C"
else
  tc_skip "1.x common backend.rs" "file not found: $COMMON_BACKEND"
fi

# ============================================================
# 2. common lib.rs — 常量 / ErrorCode / 配置
# ============================================================
if [ -f "$COMMON_LIB" ]; then
  C="$(cat "$COMMON_LIB")"
  tc_assert_contains "2.1 DEFAULT_OVERLAYFS_DATA_ROOT"    '/var/lib/ws-ckpt/overlay'   "$C"
  tc_assert_contains "2.2 SOFT_LAYER_LIMIT=450"           "DEFAULT_OVERLAYFS_SOFT_LAYER_LIMIT: u32 = 450" "$C"
  tc_assert_contains "2.3 HARD_LAYER_LIMIT=500"           "DEFAULT_OVERLAYFS_HARD_LAYER_LIMIT: u32 = 500" "$C"
  tc_assert_contains "2.4 ErrorCode::LayerLimitExceeded"  "LayerLimitExceeded"         "$C"
  tc_assert_contains "2.5 DaemonConfig.overlayfs_config"  "overlayfs_config"           "$C"
  tc_assert_contains "2.6 OverlayfsConfig 结构"           "struct OverlayfsConfig"     "$C"
  tc_assert_contains "2.7 OverlayfsConfig.data_root"      "data_root: Option<String>"  "$C"
  tc_assert_contains "2.8 OverlayfsConfig.soft_layer_limit" "soft_layer_limit: Option<u32>" "$C"
  tc_assert_contains "2.9 BackendConfig.overlayfs 段"     'rename = "overlayfs"'       "$C"
  tc_assert_contains "2.10 from_backend_type overlayfs 分支" '"overlayfs" => Some(BackendType::OverlayFs)' "$C"
else
  tc_skip "2.x common lib.rs" "file not found: $COMMON_LIB"
fi

# ============================================================
# 3. daemon backend_detect.rs — 后端注册
# ============================================================
if [ -f "$DETECT" ]; then
  C="$(cat "$DETECT")"
  tc_assert_contains "3.1 import OverlayfsBackend"        "use crate::backends::overlayfs::OverlayfsBackend" "$C"
  tc_assert_contains "3.2 OverlayFs 创建分支"            "BackendType::OverlayFs =>"  "$C"
  tc_assert_contains "3.3 OverlayfsBackend::new 调用"     "OverlayfsBackend::new"      "$C"
  tc_assert_contains "3.4 data_root 默认回落"            "DEFAULT_OVERLAYFS_DATA_ROOT" "$C"
else
  tc_skip "3.x backend_detect.rs" "file not found: $DETECT"
fi

# ============================================================
# 4. daemon overlayfs.rs — 后端实现核心
# ============================================================
if [ -f "$BACKENDS_MOD" ]; then
  tc_assert_contains "4.1 mod.rs 注册 overlayfs"        "pub mod overlayfs"          "$(cat "$BACKENDS_MOD")"
else
  tc_skip "4.1 backends/mod.rs" "file not found: $BACKENDS_MOD"
fi
if [ -f "$OVERLAY" ]; then
  C="$(cat "$OVERLAY")"
  tc_assert_contains "4.2 struct OverlayfsBackend"        "struct OverlayfsBackend"    "$C"
  tc_assert_contains "4.3 层目录 upper"                   "fn upper_dir"               "$C"
  tc_assert_contains "4.4 层目录 work"                    "fn work_dir"                "$C"
  tc_assert_contains "4.5 merged 目录"                    "fn merged_dir"              "$C"
  tc_assert_contains "4.6 layer_count 统计"              "fn layer_count"             "$C"
  tc_assert_contains "4.7 hard 阈值检查"                  "count >= self.hard_layer_limit" "$C"
  tc_assert_contains "4.8 soft 阈值检查"                  "count >= self.soft_layer_limit" "$C"
  tc_assert_contains "4.9 返回 LayerLimitExceeded"        "BackendError::LayerLimitExceeded" "$C"
  tc_assert_contains "4.10 mount overlay 命令"            '"-t", "overlay"'            "$C"
  tc_assert_contains "4.11 DeltaFS ioctl STUB"            "DeltaFS"                    "$C"
  # 上限提示文案应引导用户 cleanup
  tc_assert_contains "4.12 上限提示引导 cleanup"          "ws-ckpt cleanup"            "$C"
else
  tc_skip "4.2-4.12 overlayfs.rs" "file not found: $OVERLAY"
fi

# ============================================================
# 5. daemon dispatcher.rs — 错误 downcast 映射
# ============================================================
if [ -f "$DISPATCHER" ]; then
  C="$(cat "$DISPATCHER")"
  tc_assert_contains "5.1 downcast BackendError"          "downcast::<ws_ckpt_common::backend::BackendError>" "$C"
  tc_assert_contains "5.2 映射 ErrorCode::LayerLimitExceeded" "ErrorCode::LayerLimitExceeded" "$C"
else
  tc_skip "5.x dispatcher.rs" "file not found: $DISPATCHER"
fi

# ============================================================
# 6. cli main.rs — 友好错误提示
# ============================================================
if [ -f "$CLI_MAIN" ]; then
  C="$(cat "$CLI_MAIN")"
  tc_assert_contains "6.1 CLI 处理 LayerLimitExceeded"    "ErrorCode::LayerLimitExceeded" "$C"
  tc_assert_contains "6.2 提示用户 cleanup --keep"        "cleanup -w <workspace> --keep" "$C"
  tc_assert_contains "6.3 daemon 传入 overlayfs_config"   "overlayfs_config"           "$C"
else
  tc_skip "6.x cli main.rs" "file not found: $CLI_MAIN"
fi

tc_summary
