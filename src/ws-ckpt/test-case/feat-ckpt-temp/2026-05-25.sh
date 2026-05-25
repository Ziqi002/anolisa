#!/usr/bin/env bash
# 2026-05-25 — feat/ckpt/temp 分支测试
# 覆盖: d65c2e0 fix(ckpt): remove unused btrfs_ops.rs
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../_lib/common.sh"

tc_log "feat/ckpt/temp — dead code removal (2026-05-25)"

# 前置检查：当前代码包含 d65c2e0 的变更
tc_require_branch "feat/ckpt/temp tests" "feat/ckpt/temp" || { tc_summary; exit 0; }

# ============================================================
# 1. 死代码移除验证 (d65c2e0)
# ============================================================
DAEMON_SRC="$TC_WSCKPT_SRC/crates/daemon/src"

# 1.1 btrfs_ops.rs 文件已删除
tc_assert_file_missing "no btrfs_ops.rs" "$DAEMON_SRC/backends/btrfs_ops.rs"

# 1.2 lib.rs 中不再声明 mod btrfs_ops
# 检查 backends 目录的 mod.rs 或 lib.rs
MOD_FOUND=0
for f in "$DAEMON_SRC/backends/mod.rs" "$DAEMON_SRC/backends.rs" "$DAEMON_SRC/lib.rs"; do
  if [ -f "$f" ] && grep -q 'mod btrfs_ops' "$f" 2>/dev/null; then
    MOD_FOUND=1
    break
  fi
done
if [ "$MOD_FOUND" -eq 0 ]; then
  tc_pass "no mod btrfs_ops declaration"
else
  tc_fail "mod btrfs_ops still declared in source"
fi

# 1.3 scheduler.rs 不含 btrfs_ops 引用
if [ -f "$DAEMON_SRC/scheduler.rs" ]; then
  if grep -q 'btrfs_ops' "$DAEMON_SRC/scheduler.rs" 2>/dev/null; then
    tc_fail "scheduler: still references btrfs_ops"
  else
    tc_pass "scheduler: no btrfs_ops import"
  fi
else
  tc_skip "scheduler check" "scheduler.rs not found"
fi

# 1.4 btrfs_common.rs 不含 btrfs_ops 引用
if [ -f "$DAEMON_SRC/backends/btrfs_common.rs" ]; then
  if grep -q 'btrfs_ops' "$DAEMON_SRC/backends/btrfs_common.rs" 2>/dev/null; then
    tc_fail "btrfs_common: still references btrfs_ops"
  else
    tc_pass "btrfs_common: no btrfs_ops ref"
  fi
else
  tc_skip "btrfs_common check" "file not found"
fi

# ============================================================
tc_summary
