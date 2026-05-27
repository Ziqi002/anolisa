#!/usr/bin/env bash
# 2026-05-27 — feat/ckpt/bug-fix 分支测试 (5 bug-fix commits)
# 覆盖: feat/ckpt/bug-fix 领先 main 的 5 个 commits
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../_lib/common.sh"

tc_log "feat/ckpt/bug-fix — 5 bug-fix commits (2026-05-27)"

# 前置：确认分支上下文（允许在 main 上回归执行）
tc_require_branch "branch context" "feat/ckpt/bug-fix" || true

# ============================================================
# 1. 死代码清理 (fc6c98e): remove unused btrfs_ops.rs
# ============================================================
DAEMON_SRC="$TC_WSCKPT_SRC/crates/daemon/src"

tc_assert_file_missing "1.1 btrfs_ops.rs removed" "$DAEMON_SRC/btrfs_ops.rs"
tc_assert_file_exists  "1.2 btrfs_common still exists" "$DAEMON_SRC/backends/btrfs_common.rs"

if [ -f "$DAEMON_SRC/lib.rs" ]; then
  LIB_RS="$(cat "$DAEMON_SRC/lib.rs")"
  tc_assert_not_contains "1.3 lib.rs no btrfs_ops mod" "mod btrfs_ops" "$LIB_RS"
fi

if [ -f "$DAEMON_SRC/scheduler.rs" ]; then
  SCHED="$(cat "$DAEMON_SRC/scheduler.rs")"
  tc_assert_contains "1.4 scheduler uses btrfs_common" "btrfs_common" "$SCHED"
fi

# ============================================================
# 2. fswatch CLOSE_WRITE 修复 (1f56d12)
# ============================================================
FS_WATCHER="$DAEMON_SRC/fs_watcher.rs"

if [ -f "$FS_WATCHER" ]; then
  FSW="$(cat "$FS_WATCHER")"
  tc_assert_contains     "2.1 fs_watcher imports AccessKind" "AccessKind" "$FSW"
  tc_assert_contains     "2.2 fs_watcher imports AccessMode" "AccessMode" "$FSW"
  tc_assert_contains     "2.3 CLOSE_WRITE clears flag" "store(false" "$FSW"
  tc_assert_contains     "2.4 write events set flag" "store(true" "$FSW"
  tc_assert_not_contains "2.5 old is_write_event removed" "fn is_write_event" "$FSW"
else
  tc_skip "2.x fs_watcher tests" "file not found: $FS_WATCHER"
fi

# ============================================================
# 3. cwd 保护逻辑 (605e478)
# ============================================================
HERMES_DIR="$TC_WSCKPT_SRC/plugins/hermes"
HERMES_INIT="$HERMES_DIR/__init__.py"
HERMES_TOOLS="$HERMES_DIR/tools.py"

if [ -f "$HERMES_INIT" ]; then
  HINIT="$(cat "$HERMES_INIT")"
  tc_assert_contains     "3.1 __init__.py: CWD_INSIDE_WORKSPACE_REASON" "CWD_INSIDE_WORKSPACE_REASON" "$HINIT"
  tc_assert_contains     "3.2 __init__.py: _cwd_inside_workspace fn" "def _cwd_inside_workspace" "$HINIT"
  tc_assert_not_contains "3.3 __init__.py: old fn removed" "_cwd_invalidation_warning" "$HINIT"
  tc_assert_contains     "3.4 __init__.py: disable auto-ckpt on cwd inside" "set_auto_checkpoint(False)" "$HINIT"
else
  tc_skip "3.1-3.4 hermes __init__ tests" "file not found: $HERMES_INIT"
fi

if [ -f "$HERMES_TOOLS" ]; then
  HTOOLS="$(cat "$HERMES_TOOLS")"
  tc_assert_contains "3.5 tools.py: _require_workspace fn" "def _require_workspace" "$HTOOLS"
  tc_assert_contains "3.6 tools.py: _reject_if_cwd_inside fn" "def _reject_if_cwd_inside_workspace" "$HTOOLS"

  # checkpoint/rollback/config 三处都应调用 _reject_if_cwd_inside_workspace
  REJECT_COUNT=$(grep -c "_reject_if_cwd_inside_workspace" "$HERMES_TOOLS" || true)
  # 定义处 1 次 + 调用至少 3 次 = 至少 4 次出现
  if [ "$REJECT_COUNT" -ge 4 ]; then
    tc_pass "3.7 tools.py: checkpoint uses reject"
    tc_pass "3.8 tools.py: rollback uses reject"
    tc_pass "3.9 tools.py: config autoCheckpoint uses reject"
  elif [ "$REJECT_COUNT" -ge 3 ]; then
    tc_pass "3.7 tools.py: checkpoint uses reject"
    tc_pass "3.8 tools.py: rollback uses reject"
    tc_fail "3.9 tools.py: config autoCheckpoint uses reject (only $REJECT_COUNT occurrences, expected >=4)"
  else
    tc_fail "3.7-3.9 _reject_if_cwd_inside_workspace occurrences ($REJECT_COUNT, expected >=4)"
  fi
else
  tc_skip "3.5-3.9 hermes tools tests" "file not found: $HERMES_TOOLS"
fi

# ============================================================
# 4. skill delete 必须 --force (d2382c1)
# ============================================================
SKILL_MD="$TC_SKILL_DIR/SKILL.md"

if [ -f "$SKILL_MD" ]; then
  SKILLCONTENT="$(cat "$SKILL_MD")"
  # delete 命令行中 --force 不在 [] 内（即不是可选参数）
  # 旧写法: ws-ckpt delete -s <snapshot> [--force] [-w <workspace>]
  # 新写法: ws-ckpt delete -s <snapshot> --force [-w <workspace>]
  DELETE_LINE=$(grep -n "\-\-force" "$SKILL_MD" | grep "delete" | head -1)
  if echo "$DELETE_LINE" | grep -q '\[--force\]'; then
    tc_fail "4.1 SKILL.md: --force required (still optional in brackets)"
  elif echo "$DELETE_LINE" | grep -q '\-\-force'; then
    tc_pass "4.1 SKILL.md: --force required"
  else
    tc_fail "4.1 SKILL.md: --force not found in delete command"
  fi

  tc_assert_contains "4.2 SKILL.md: agent必须跳过确认" "agent" "$SKILLCONTENT"
else
  tc_skip "4.x skill md tests" "file not found: $SKILL_MD"
fi

# ============================================================
# 5. 插件自动加载 (353b595)
# ============================================================
OPENCLAW_PJSON="$TC_WSCKPT_SRC/plugins/openclaw/openclaw.plugin.json"

if [ -f "$OPENCLAW_PJSON" ]; then
  PJSON="$(cat "$OPENCLAW_PJSON")"
  tc_assert_contains "5.1 openclaw: onStartup activation" "onStartup" "$PJSON"
  tc_assert_contains "5.2 openclaw: onStartup = true" "true" "$PJSON"
else
  tc_skip "5.1-5.2 openclaw plugin.json tests" "file not found: $OPENCLAW_PJSON"
fi

INSTALL_HERMES="$TC_WSCKPT_DIR/scripts/install-hermes.sh"

if [ -f "$INSTALL_HERMES" ]; then
  INST="$(cat "$INSTALL_HERMES")"
  tc_assert_contains "5.3 install-hermes: plugins enable" "hermes plugins enable" "$INST"
  tc_assert_contains "5.4 install-hermes: enable ws-ckpt" "plugins enable ws-ckpt" "$INST"
else
  tc_skip "5.3-5.4 install-hermes tests" "file not found: $INSTALL_HERMES"
fi

# ============================================================
tc_summary
