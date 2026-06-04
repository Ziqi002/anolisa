#!/usr/bin/env bash
# 2026-06-04 — bug-fix-673 分支测试 (1 领先 commit, init 失败数据保全 #673)
# 覆盖: dc40b14(backup_path_for + cleanup_init_storage + restore_original_from_backup)
# 静态断言 Mac/Linux 均可跑。
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../_lib/common.sh"

tc_log "bug-fix-673 — init_workspace 失败时保留用户数据 (2026-06-04)"

if ! tc_require_branch "bug-fix-673 静态用例" "bug-fix-673"; then
  tc_summary; exit $?
fi

DAEMON_SRC="$TC_WSCKPT_SRC/crates/daemon/src"
BTRFS_COMMON="$DAEMON_SRC/backends/btrfs_common.rs"
BTRFS_BASE="$DAEMON_SRC/backends/btrfs_base.rs"
BTRFS_LOOP="$DAEMON_SRC/backends/btrfs_loop.rs"

# ============================================================
# 1. 静态源码断言
# ============================================================
if [ -f "$BTRFS_COMMON" ]; then
  BC="$(cat "$BTRFS_COMMON")"
  tc_assert_contains "1.1 btrfs_common.rs: backup_path_for 函数" "fn backup_path_for" "$BC"
  tc_assert_contains "1.2 btrfs_common.rs: cleanup_init_storage 函数" "fn cleanup_init_storage" "$BC"
  tc_assert_contains "1.3 btrfs_common.rs: restore_original_from_backup 函数" "fn restore_original_from_backup" "$BC"
else
  tc_skip "1.1-1.3 btrfs_common.rs tests" "file not found: $BTRFS_COMMON"
fi

if [ -f "$BTRFS_BASE" ]; then
  BB="$(cat "$BTRFS_BASE")"
  tc_assert_contains "1.4 btrfs_base.rs: 引用 backup_path_for" "backup_path_for" "$BB"
  # step 5: rename 替代 remove_dir_all
  if printf '%s' "$BB" | grep -q 'rename(original_path' && ! printf '%s' "$BB" | grep -q 'remove_dir_all(original_path)'; then
    tc_pass "1.5 btrfs_base.rs: rename 替代 remove_dir_all in step 5"
  else
    tc_fail "1.5 btrfs_base.rs: step 5 仍使用 remove_dir_all 或缺少 rename"
  fi
  tc_assert_contains "1.6 btrfs_base.rs: backup_owned 标记" "backup_owned" "$BB"
  tc_assert_contains "1.7 btrfs_base.rs: bail on pre-existing backup" "refusing to overwrite" "$BB"
  tc_assert_contains "1.8 btrfs_base.rs: step 8 移除备份" "remove_dir_all" "$BB"
else
  tc_skip "1.4-1.8 btrfs_base.rs tests" "file not found: $BTRFS_BASE"
fi

if [ -f "$BTRFS_LOOP" ]; then
  BL="$(cat "$BTRFS_LOOP")"
  tc_assert_contains "1.9 btrfs_loop.rs: 引用 backup_path_for + rename" "backup_path_for" "$BL"
  tc_assert_contains "1.10 btrfs_loop.rs: backup_owned 标记" "backup_owned" "$BL"
else
  tc_skip "1.9-1.10 btrfs_loop.rs tests" "file not found: $BTRFS_LOOP"
fi

# ============================================================
# 2. 逻辑一致性断言
# ============================================================
if [ -f "$BTRFS_COMMON" ]; then
  BC="$(cat "$BTRFS_COMMON")"
  # 2.1 backup_owned 参数为 bool
  if printf '%s' "$BC" | grep -q 'backup_owned: bool'; then
    tc_pass "2.1 cleanup_init_storage: backup_owned 参数为 bool"
  else
    tc_fail "2.1 cleanup_init_storage: backup_owned 参数类型不是 bool"
  fi
  # 2.2 ENOENT 处理 (warn, not panic)
  if printf '%s' "$BC" | grep -qE 'unexpectedly missing|NotFound'; then
    tc_pass "2.2 restore_original_from_backup: ENOENT 路径有 warn 处理"
  else
    tc_fail "2.2 restore_original_from_backup: 未见 ENOENT warn 处理"
  fi
  # 2.3 非 ENOENT abort
  tc_assert_contains "2.3 restore_original_from_backup: 非 ENOENT abort" "aborting restore" "$BC"
else
  tc_skip "2.1-2.3 btrfs_common.rs logic tests" "file not found: $BTRFS_COMMON"
fi

tc_summary
exit $?
