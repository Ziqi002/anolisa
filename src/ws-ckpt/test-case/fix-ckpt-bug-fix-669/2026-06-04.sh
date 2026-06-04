#!/usr/bin/env bash
# 2026-06-04 — fix/ckpt/bug-fix-669 增量测试 (+1 commit 32dd1d8, plugin error mapper 加固)
# 覆盖: 32dd1d8(hermes/openclaw error mapper 优先级修复, cwd scan 不再被误报为 snapshot not found)
# 静态断言 Mac/Linux 均可跑。
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../_lib/common.sh"

tc_log "fix/ckpt/bug-fix-669 增量 — plugin error mapper hardening (2026-06-04)"

if ! tc_require_branch "fix/ckpt/bug-fix-669 增量用例" "fix/ckpt/bug-fix-669"; then
  tc_summary; exit $?
fi

HERMES_DIR="$TC_WSCKPT_SRC/plugins/hermes"
CKPT_MGR="$HERMES_DIR/checkpoint_manager.py"
OPENCLAW_DIR="$TC_WSCKPT_SRC/plugins/openclaw/src"
BTRFS_MGR="$OPENCLAW_DIR/btrfs-manager.ts"

# ============================================================
# 1. hermes plugin error mapper 断言
# ============================================================
if [ -f "$CKPT_MGR" ]; then
  CM="$(cat "$CKPT_MGR")"

  # 1.1 "not initialized" 不可达分支已移除
  tc_assert_not_contains "1.1 checkpoint_manager.py: 无 'not initialized' 分支" "not initialized" "$CM"

  # 1.2-1.4 新增 matcher
  tc_assert_contains "1.2 checkpoint_manager.py: 'already exists' matcher" "already exists" "$CM"
  tc_assert_contains "1.3 checkpoint_manager.py: 'active write' matcher" "active write" "$CM"
  tc_assert_contains "1.4 checkpoint_manager.py: 'insufficient' matcher" "insufficient" "$CM"

  # 1.5 精确 daemon matcher
  tc_assert_contains "1.5 checkpoint_manager.py: 'daemon is not running' matcher" "daemon is not running" "$CM"

  # 1.6 cwd scan failed 在 not found 之前 (行号比较)
  CWD_LINE=$(printf '%s' "$CM" | grep -n 'cwd scan failed' | head -1 | cut -d: -f1)
  NF_LINE=$(printf '%s' "$CM" | grep -n '"not found".*"snapshot"' | head -1 | cut -d: -f1)
  if [ -n "$CWD_LINE" ] && [ -n "$NF_LINE" ] && [ "$CWD_LINE" -lt "$NF_LINE" ]; then
    tc_pass "1.6 checkpoint_manager.py: cwd scan failed 在 not found+snapshot 之前"
  elif [ -z "$CWD_LINE" ]; then
    tc_fail "1.6 checkpoint_manager.py: 未找到 'cwd scan failed' matcher"
  elif [ -z "$NF_LINE" ]; then
    tc_pass "1.6 checkpoint_manager.py: 无 generic 'not found' (已精确化)"
  else
    tc_fail "1.6 checkpoint_manager.py: cwd scan failed (L$CWD_LINE) 在 not found (L$NF_LINE) 之后"
  fi

  # 1.7 not found 与 snapshot 组合
  if printf '%s' "$CM" | grep -q '"not found".*"snapshot"\|"snapshot".*"not found"'; then
    tc_pass "1.7 checkpoint_manager.py: 'not found' 与 'snapshot' 组合匹配"
  else
    tc_fail "1.7 checkpoint_manager.py: 'not found' 未与 'snapshot' 组合（可能仍是 generic）"
  fi
else
  tc_skip "1.1-1.7 checkpoint_manager.py tests" "file not found: $CKPT_MGR"
fi

# ============================================================
# 2. openclaw plugin error mapper 断言
# ============================================================
if [ -f "$BTRFS_MGR" ]; then
  BM="$(cat "$BTRFS_MGR")"

  tc_assert_contains "2.1 btrfs-manager.ts: 'daemon is not running' matcher" "daemon is not running" "$BM"
  tc_assert_contains "2.2 btrfs-manager.ts: 'cwd scan failed' matcher" "cwd scan failed" "$BM"
  tc_assert_contains "2.3 btrfs-manager.ts: inner io error leakage 注释" "inner io error" "$BM"
else
  tc_skip "2.1-2.3 btrfs-manager.ts tests" "file not found: $BTRFS_MGR"
fi

tc_summary
exit $?
