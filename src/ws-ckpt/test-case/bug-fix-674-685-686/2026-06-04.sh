#!/usr/bin/env bash
# 2026-06-04 — bug-fix-674-685-686 分支测试 (3 领先 commits)
# 覆盖: 72a10ac(#674 rsync bail), 5729b60(#685 registry write-lock), f376c17(#686 seccomp arch)
# 静态断言 Mac/Linux 均可跑。
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../_lib/common.sh"

tc_log "bug-fix-674-685-686 — rsync bail / registry lock-free / seccomp arch (2026-06-04)"

if ! tc_require_branch "bug-fix-674-685-686 静态用例" "bug-fix-674-685-686"; then
  tc_summary; exit $?
fi

DAEMON_SRC="$TC_WSCKPT_SRC/crates/daemon/src"
BTRFS_BASE="$DAEMON_SRC/backends/btrfs_base.rs"
BTRFS_LOOP="$DAEMON_SRC/backends/btrfs_loop.rs"
STATE_RS="$DAEMON_SRC/state.rs"
DISPATCHER="$DAEMON_SRC/dispatcher.rs"
WS_MGR="$DAEMON_SRC/workspace_mgr.rs"
SECCOMP="$DAEMON_SRC/seccomp.rs"

# ============================================================
# 1. #674 rsync bail 断言
# ============================================================
if [ -f "$BTRFS_BASE" ]; then
  BB="$(cat "$BTRFS_BASE")"
  # bail! 替代 error! 在 rsync 失败路径
  if printf '%s' "$BB" | grep -A2 'rsync_status.success()' | grep -q 'bail!'; then
    tc_pass "1.1 btrfs_base.rs: rsync 失败使用 bail!"
  else
    tc_fail "1.1 btrfs_base.rs: rsync 失败仍使用 error! 而非 bail!"
  fi
  tc_assert_contains "1.2 btrfs_base.rs: preserved for retry 消息" "preserved for retry" "$BB"
else
  tc_skip "1.1-1.2 btrfs_base.rs tests" "file not found: $BTRFS_BASE"
fi

if [ -f "$BTRFS_LOOP" ]; then
  BL="$(cat "$BTRFS_LOOP")"
  if printf '%s' "$BL" | grep -A2 'rsync_status.success()' | grep -q 'bail!' && printf '%s' "$BL" | grep -q 'preserved for retry'; then
    tc_pass "1.3 btrfs_loop.rs: rsync bail + preserved for retry"
  else
    tc_fail "1.3 btrfs_loop.rs: rsync 失败处理不正确"
  fi
else
  tc_skip "1.3 btrfs_loop.rs test" "file not found: $BTRFS_LOOP"
fi

# ============================================================
# 2. #685 workspace registry 断言
# ============================================================
if [ -f "$STATE_RS" ]; then
  ST="$(cat "$STATE_RS")"
  # 2.1 collect_workspace_entries 读取 path_to_wsid
  tc_assert_contains "2.1 state.rs: collect_workspace_entries 使用 path_to_wsid" "path_to_wsid" "$ST"
  # 2.2 collect_workspace_entries 不使用 try_read
  # 提取 collect_workspace_entries 函数体附近判断
  if printf '%s' "$ST" | sed -n '/fn collect_workspace_entries/,/^    }/p' | grep -q 'try_read'; then
    tc_fail "2.2 state.rs: collect_workspace_entries 仍包含 try_read"
  else
    tc_pass "2.2 state.rs: collect_workspace_entries 无 try_read"
  fi
  # 2.3 get_all_workspace_info 是 async
  if printf '%s' "$ST" | grep -q 'async.*fn get_all_workspace_info\|pub async fn get_all_workspace_info'; then
    tc_pass "2.3 state.rs: get_all_workspace_info 是 async 函数"
  else
    tc_fail "2.3 state.rs: get_all_workspace_info 不是 async"
  fi
  # 2.4 get_all_workspace_info 使用 .read().await
  if printf '%s' "$ST" | sed -n '/fn get_all_workspace_info/,/^    }/p' | grep -q '\.read()\.await'; then
    tc_pass "2.4 state.rs: get_all_workspace_info 使用 .read().await"
  else
    tc_fail "2.4 state.rs: get_all_workspace_info 未使用 .read().await"
  fi
  # 2.5 unregister_workspace 接受 path 参数
  if printf '%s' "$ST" | grep -q 'fn unregister_workspace.*path'; then
    tc_pass "2.5 state.rs: unregister_workspace 接受 path 参数"
  else
    tc_fail "2.5 state.rs: unregister_workspace 未接受 path 参数"
  fi
else
  tc_skip "2.1-2.5 state.rs tests" "file not found: $STATE_RS"
fi

if [ -f "$DISPATCHER" ]; then
  DP="$(cat "$DISPATCHER")"
  if printf '%s' "$DP" | grep -q 'get_all_workspace_info()\.await\|get_all_workspace_info().await'; then
    tc_pass "2.6 dispatcher.rs: get_all_workspace_info 调用带 .await"
  else
    tc_fail "2.6 dispatcher.rs: get_all_workspace_info 调用缺少 .await"
  fi
else
  tc_skip "2.6 dispatcher.rs test" "file not found: $DISPATCHER"
fi

if [ -f "$WS_MGR" ]; then
  WM="$(cat "$WS_MGR")"
  if printf '%s' "$WM" | grep -q 'unregister_workspace.*Path\|unregister_workspace.*path'; then
    tc_pass "2.7 workspace_mgr.rs: unregister_workspace 传入 path"
  else
    tc_fail "2.7 workspace_mgr.rs: unregister_workspace 未传入 path"
  fi
else
  tc_skip "2.7 workspace_mgr.rs test" "file not found: $WS_MGR"
fi

# ============================================================
# 3. #686 seccomp TargetArch 断言
# ============================================================
if [ -f "$SECCOMP" ]; then
  SC="$(cat "$SECCOMP")"
  tc_assert_contains "3.1 seccomp.rs: target_arch() 函数" "fn target_arch()" "$SC"
  # 3.2 filter 构造不再硬编码 x86_64
  if printf '%s' "$SC" | grep -v '^\s*//' | grep -v 'test' | grep 'SeccompFilter\|SeccompFilter::new\|filter' | grep -q 'target_arch()'; then
    tc_pass "3.2 seccomp.rs: filter 使用 target_arch() 而非硬编码"
  else
    # fallback: 只要 filter 行不包含 TargetArch::x86_64 直接赋值就算 PASS
    if printf '%s' "$SC" | grep -v '^\s*//' | grep -v '#\[test\]' | grep -v 'mod tests' | grep 'TargetArch::x86_64' | grep -qv 'return Ok'; then
      tc_fail "3.2 seccomp.rs: 仍有硬编码 TargetArch::x86_64"
    else
      tc_pass "3.2 seccomp.rs: 无硬编码 TargetArch::x86_64 (使用 target_arch)"
    fi
  fi
  tc_assert_contains "3.3 seccomp.rs: cfg aarch64" "target_arch = \"aarch64\"" "$SC"
  tc_assert_contains "3.4 seccomp.rs: deny-list 含 pidfd_open" "pidfd_open" "$SC"
  # 3.5 lookup_dcookie 已移除
  tc_assert_not_contains "3.5 seccomp.rs: deny-list 无 lookup_dcookie" "lookup_dcookie" "$SC"
else
  tc_skip "3.1-3.5 seccomp.rs tests" "file not found: $SECCOMP"
fi

tc_summary
exit $?
