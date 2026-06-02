#!/usr/bin/env bash
# 2026-06-02 — fix/ckpt/bug-fix-615 分支测试 (3 领先 commits)
# 覆盖: e5966cc (skill cwd 方法), 2890b2a (拒绝提示), 5bc4e2a (/proc cwd 守卫 issue#669)
# 全部静态断言, Mac/Linux 均可跑; 集成测试需 Linux+root+btrfs, 否则 SKIP。
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../_lib/common.sh"

tc_log "fix/ckpt/bug-fix-615 — cwd occupant guard + skill/prompt (2026-06-02)"

# 分支守卫: 仅在该分支(或已合并)源码上执行; 旧源码工作区整体 SKIP, 避免误报。
if ! tc_require_branch "fix/ckpt/bug-fix-615 静态用例" "fix/ckpt/bug-fix-615"; then
  tc_summary; exit $?
fi

DAEMON_SRC="$TC_WSCKPT_SRC/crates/daemon/src"
COMMON_SRC="$TC_WSCKPT_SRC/crates/common/src"
CLI_SRC="$TC_WSCKPT_SRC/crates/cli/src"
HERMES_DIR="$TC_WSCKPT_SRC/plugins/hermes"
OPENCLAW_DIR="$TC_WSCKPT_SRC/plugins/openclaw"
SKILL_MD="$TC_SKILL_DIR/SKILL.md"

# ============================================================
# 1. Skill 新增 cwd 查询方法 (e5966cc)
# ============================================================
if [ -f "$SKILL_MD" ]; then
  SKILL="$(cat "$SKILL_MD")"
  tc_assert_contains "1.1 SKILL.md: cwd 查询方法段落" "cwd 查询方法" "$SKILL"
  tc_assert_contains "1.2 SKILL.md: readlink /proc/\$PPID/cwd" 'readlink /proc/$PPID/cwd' "$SKILL"
  if printf '%s' "$SKILL" | grep -q '禁止猜测'; then
    tc_pass "1.3 SKILL.md: 禁止猜测 cwd"
  else
    tc_fail "1.3 SKILL.md: 缺少禁止猜测 cwd 说明"
  fi
else
  tc_skip "1.x SKILL.md tests" "file not found: $SKILL_MD"
fi

# ============================================================
# 2. 优化 cwd 拒绝提示 (2890b2a)
# ============================================================
HERMES_INIT="$HERMES_DIR/__init__.py"
HERMES_TOOLS="$HERMES_DIR/tools.py"

if [ -f "$HERMES_INIT" ]; then
  HINIT="$(cat "$HERMES_INIT")"
  tc_assert_contains "2.1 __init__.py: _cwd_inside_workspace_reason" "def _cwd_inside_workspace_reason" "$HINIT"
  tc_assert_contains "2.2 __init__.py: _cwd_inside_workspace fn" "def _cwd_inside_workspace" "$HINIT"
  tc_assert_contains "2.2b __init__.py: returns tuple[bool, str]" "tuple[bool, str]" "$HINIT"
  tc_assert_contains "2.3 __init__.py: 拒绝信息携带 cwd" "is inside workspace" "$HINIT"
else
  tc_skip "2.1-2.3 hermes __init__ tests" "file not found: $HERMES_INIT"
fi

if [ -f "$HERMES_TOOLS" ]; then
  tc_assert_contains "2.4 tools.py: cwd 拒绝逻辑" "_reject_if_cwd_inside_workspace" "$(cat "$HERMES_TOOLS")"
else
  tc_skip "2.4 hermes tools test" "file not found: $HERMES_TOOLS"
fi

# ============================================================
# 3. daemon /proc cwd 占用守卫 (5bc4e2a)
# ============================================================
UTIL_RS="$DAEMON_SRC/util.rs"
WS_MGR="$DAEMON_SRC/workspace_mgr.rs"
SNAP_MGR="$DAEMON_SRC/snapshot_mgr.rs"
COMMON_LIB="$COMMON_SRC/lib.rs"
CLI_MAIN="$CLI_SRC/main.rs"

if [ -f "$UTIL_RS" ]; then
  UTIL="$(cat "$UTIL_RS")"
  tc_assert_contains "3.1 util.rs: guard_cwd_occupants fn" "fn guard_cwd_occupants" "$UTIL"
  tc_assert_contains "3.2 util.rs: find_cwd_occupants fn" "fn find_cwd_occupants" "$UTIL"
  tc_assert_contains "3.3 util.rs: scans /proc/<pid>/cwd" "/cwd" "$UTIL"
  tc_assert_contains "3.4a util.rs: mountinfo alias" "mountinfo" "$UTIL"
  tc_assert_contains "3.4b util.rs: derive_workspace_aliases" "derive_workspace_aliases" "$UTIL"
  tc_assert_contains "3.5 util.rs: 跳过 (deleted) 孤儿 cwd" "(deleted)" "$UTIL"
  if printf '%s' "$UTIL" | grep -qE 'fail-closed|CwdScanFailed'; then
    tc_pass "3.6 util.rs: fail-closed 语义"
  else
    tc_fail "3.6 util.rs: 未见 fail-closed / CwdScanFailed"
  fi
else
  tc_skip "3.1-3.6 util.rs tests" "file not found: $UTIL_RS"
fi

if [ -f "$COMMON_LIB" ]; then
  CL="$(cat "$COMMON_LIB")"
  tc_assert_contains "3.7 common/lib.rs: CwdOccupied" "CwdOccupied" "$CL"
  tc_assert_contains "3.8 common/lib.rs: CwdScanFailed" "CwdScanFailed" "$CL"
else
  tc_skip "3.7-3.8 common/lib.rs tests" "file not found: $COMMON_LIB"
fi

if [ -f "$WS_MGR" ]; then
  tc_assert_contains "3.9 workspace_mgr.rs: init 调用守卫" "guard_cwd_occupants" "$(cat "$WS_MGR")"
else
  tc_skip "3.9 workspace_mgr.rs test" "file not found: $WS_MGR"
fi

# 3.10 —— 有意的缺陷探针: commit 声称守卫覆盖 init/rollback, 但 rollback 路径实际未接入。
#        期望(正确行为): rollback 也调用 guard_cwd_occupants → 当前在分支源码上会 FAIL。
#        见同目录 md 的「缺陷发现」。修复落地后此用例自动转 PASS。
if [ -f "$SNAP_MGR" ]; then
  if grep -q "guard_cwd_occupants" "$SNAP_MGR"; then
    tc_pass "3.10 snapshot_mgr.rs: rollback 调用守卫"
  else
    tc_fail "3.10 snapshot_mgr.rs: rollback 未调用 guard_cwd_occupants (KNOWN DEFECT, issue#669 声称覆盖 init/rollback)"
  fi
else
  tc_skip "3.10 snapshot_mgr.rs test" "file not found: $SNAP_MGR"
fi

if [ -f "$CLI_MAIN" ]; then
  CM="$(cat "$CLI_MAIN")"
  tc_assert_contains "3.11a cli/main.rs: 映射 CwdOccupied" "CwdOccupied" "$CM"
  tc_assert_contains "3.11b cli/main.rs: 映射 CwdScanFailed" "CwdScanFailed" "$CM"
  tc_assert_contains "3.12 cli/main.rs: recover 不守卫 WARNING" "does NOT check" "$CM"
else
  tc_skip "3.11-3.12 cli/main.rs tests" "file not found: $CLI_MAIN"
fi

# ============================================================
# 4. 插件错误信息转译一致性 (5bc4e2a)
# ============================================================
HERMES_CM="$HERMES_DIR/checkpoint_manager.py"
OPENCLAW_BTRFS="$OPENCLAW_DIR/src/btrfs-manager.ts"

if [ -f "$HERMES_CM" ]; then
  HCM="$(cat "$HERMES_CM")"
  tc_assert_contains "4.1 hermes: 转译 'cwd scan failed'" "cwd scan failed" "$HCM"
  tc_assert_contains "4.2a hermes: 转译 'have cwd inside workspace'" "have cwd inside workspace" "$HCM"
  tc_assert_contains "4.2b hermes: 'NOT retryable'" "NOT retryable" "$HCM"
else
  tc_skip "4.1-4.2 hermes checkpoint_manager tests" "file not found: $HERMES_CM"
fi

if [ -f "$OPENCLAW_BTRFS" ]; then
  OBT="$(cat "$OPENCLAW_BTRFS")"
  tc_assert_contains "4.3 openclaw: 转译 'cwd scan failed'" "cwd scan failed" "$OBT"
  tc_assert_contains "4.4 openclaw: 转译 'have cwd inside workspace'" "have cwd inside workspace" "$OBT"
else
  tc_skip "4.3-4.4 openclaw btrfs-manager tests" "file not found: $OPENCLAW_BTRFS"
fi

# ============================================================
# 5. 集成测试: init 守卫真实生效 (需 Linux + root + btrfs + 二进制)
# ============================================================
if tc_require_root "5.1 init cwd guard" && tc_require_btrfs "5.1 init cwd guard" && tc_require_bin "5.1 init cwd guard"; then
  BIN="$(tc_find_wsckpt_bin)"
  WS_PATH="${TC_WS_PATH:-/tmp/ws-ckpt-qa-615-$$}"
  if tc_require_btrfs_path "5.1 init cwd guard (workspace fs)" "$WS_PATH"; then
    systemctl start ws-ckpt 2>/dev/null || true
    sleep 1
    mkdir -p "$WS_PATH"
    "$BIN" init -w "$WS_PATH" >/dev/null 2>&1 || true
    "$BIN" checkpoint -w "$WS_PATH" -i base -m base >/dev/null 2>&1 || true
    # 在 workspace 内开一个持有 cwd 的后台进程
    ( cd "$WS_PATH" && sleep 30 ) &
    OCC_PID=$!
    sleep 1
    # 对该 ws 再次 init 应被守卫拒绝
    OUT="$(cd / && "$BIN" init -w "$WS_PATH" 2>&1)"; RC=$?
    if [ "$RC" != "0" ] && printf '%s' "$OUT" | grep -qiE 'cwd|occupied|occupant|inside workspace'; then
      tc_pass "5.1 init 守卫: cwd 占用时拒绝"
    else
      tc_fail "5.1 init 守卫: 期望非零退出且提示 cwd 占用 (rc=$RC, out=$OUT)"
    fi
    kill "$OCC_PID" >/dev/null 2>&1 || true
    "$BIN" delete -w "$WS_PATH" --force >/dev/null 2>&1 || true
    rm -rf "$WS_PATH" 2>/dev/null || true
  fi
fi

# ============================================================
tc_summary
