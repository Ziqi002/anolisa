#!/usr/bin/env bash
# 2026-06-03 — fix/ckpt/bug-fix-669 分支测试 (4 领先 commits, issue#669 cwd 守卫收口)
# 覆盖: 5f3a6ac(拒绝提示), ef4c0dc(/proc cwd 守卫 init/rollback), 247d4dd(RPM), cf54782(skill 去重)
# 关键: 2.2 回归验证上一轮 615/3.10 标注的 "rollback 未接守卫" 缺陷已修复。
# 静态断言 Mac/Linux 均可跑; 集成测试需 Linux+root+btrfs, 否则 SKIP。
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../_lib/common.sh"

tc_log "fix/ckpt/bug-fix-669 — cwd occupant guard 收口 + rollback 回归 (2026-06-03)"

if ! tc_require_branch "fix/ckpt/bug-fix-669 静态用例" "fix/ckpt/bug-fix-669"; then
  tc_summary; exit $?
fi

DAEMON_SRC="$TC_WSCKPT_SRC/crates/daemon/src"
COMMON_SRC="$TC_WSCKPT_SRC/crates/common/src"
CLI_SRC="$TC_WSCKPT_SRC/crates/cli/src"
HERMES_DIR="$TC_WSCKPT_SRC/plugins/hermes"
SKILL_MD="$TC_SKILL_DIR/SKILL.md"
SPEC="$TC_SPEC_FILE"

UTIL_RS="$DAEMON_SRC/util.rs"
WS_MGR="$DAEMON_SRC/workspace_mgr.rs"
SNAP_MGR="$DAEMON_SRC/snapshot_mgr.rs"
COMMON_LIB="$COMMON_SRC/lib.rs"
CLI_MAIN="$CLI_SRC/main.rs"
HERMES_INIT="$HERMES_DIR/__init__.py"

# ============================================================
# 1. daemon /proc cwd 占用守卫核心 (ef4c0dc)
# ============================================================
if [ -f "$UTIL_RS" ]; then
  UTIL="$(cat "$UTIL_RS")"
  tc_assert_contains "1.1 util.rs: guard_cwd_occupants fn" "fn guard_cwd_occupants" "$UTIL"
  tc_assert_contains "1.2 util.rs: find_cwd_occupants fn" "fn find_cwd_occupants" "$UTIL"
  tc_assert_contains "1.3 util.rs: 扫描 /proc/<pid>/cwd" "/cwd" "$UTIL"
  tc_assert_contains "1.4a util.rs: mountinfo 别名" "mountinfo" "$UTIL"
  tc_assert_contains "1.4b util.rs: derive_workspace_aliases" "derive_workspace_aliases" "$UTIL"
  tc_assert_contains "1.5 util.rs: 跳过 (deleted) 孤儿 cwd" "(deleted)" "$UTIL"
  if printf '%s' "$UTIL" | grep -qE 'fail-closed|CwdScanFailed'; then
    tc_pass "1.6 util.rs: fail-closed 语义"
  else
    tc_fail "1.6 util.rs: 未见 fail-closed / CwdScanFailed"
  fi
else
  tc_skip "1.1-1.6 util.rs tests" "file not found: $UTIL_RS"
fi

if [ -f "$COMMON_LIB" ]; then
  CL="$(cat "$COMMON_LIB")"
  tc_assert_contains "1.7 common/lib.rs: CwdOccupied" "CwdOccupied" "$CL"
  tc_assert_contains "1.8 common/lib.rs: CwdScanFailed" "CwdScanFailed" "$CL"
else
  tc_skip "1.7-1.8 common/lib.rs tests" "file not found: $COMMON_LIB"
fi

# ============================================================
# 2. init / rollback 双路径接入 (含旧缺陷回归)
# ============================================================
if [ -f "$WS_MGR" ]; then
  tc_assert_contains "2.1 workspace_mgr.rs: init 调用守卫" "guard_cwd_occupants" "$(cat "$WS_MGR")"
else
  tc_skip "2.1 workspace_mgr.rs test" "file not found: $WS_MGR"
fi

# 2.2 —— 关键回归: 上一轮 615/3.10 标注 rollback 未接守卫 (issue#669 声称覆盖 init/rollback)。
#        本分支 ef4c0dc 应已把守卫接入 rollback -> 期望 PASS。
if [ -f "$SNAP_MGR" ]; then
  if grep -q "guard_cwd_occupants" "$SNAP_MGR"; then
    tc_pass "2.2 snapshot_mgr.rs: rollback 调用守卫 (旧缺陷 615/3.10 已修复)"
  else
    tc_fail "2.2 snapshot_mgr.rs: rollback 仍未调用 guard_cwd_occupants (issue#669 回归未完成)"
  fi
else
  tc_skip "2.2 snapshot_mgr.rs test" "file not found: $SNAP_MGR"
fi

if [ -f "$CLI_MAIN" ]; then
  CM="$(cat "$CLI_MAIN")"
  tc_assert_contains "2.3 cli/main.rs: 映射 CwdOccupied" "CwdOccupied" "$CM"
  tc_assert_contains "2.4 cli/main.rs: 映射 CwdScanFailed" "CwdScanFailed" "$CM"
  tc_assert_contains "2.5 cli/main.rs: recover 不守卫 WARNING" "does NOT check" "$CM"
else
  tc_skip "2.3-2.5 cli/main.rs tests" "file not found: $CLI_MAIN"
fi

# ============================================================
# 3. hermes 拒绝提示优化 (5f3a6ac)
# ============================================================
if [ -f "$HERMES_INIT" ]; then
  HINIT="$(cat "$HERMES_INIT")"
  tc_assert_contains "3.1 __init__.py: _cwd_inside_workspace_reason" "def _cwd_inside_workspace_reason" "$HINIT"
  tc_assert_contains "3.2 __init__.py: 返回 tuple[bool, str]" "tuple[bool, str]" "$HINIT"
  tc_assert_contains "3.3 __init__.py: 拒绝信息携带 cwd" "is inside workspace" "$HINIT"
else
  tc_skip "3.1-3.3 hermes __init__ tests" "file not found: $HERMES_INIT"
fi

# ============================================================
# 4. skill 层去重 + Linux-only (cf54782)
# ============================================================
if [ -f "$SKILL_MD" ]; then
  SKILL="$(cat "$SKILL_MD")"
  tc_assert_contains "4.1 SKILL.md: daemon 层统一拦截说明" "daemon" "$SKILL"
  tc_assert_not_contains "4.2 SKILL.md: 移除冗余 cwd 父路径告警" "绝对禁止工作区路径是 cwd" "$SKILL"
  tc_assert_contains "4.3 SKILL.md: 标注仅限 Linux" "仅限 Linux" "$SKILL"
else
  tc_skip "4.1-4.3 SKILL.md tests" "file not found: $SKILL_MD"
fi

# ============================================================
# 5. RPM 打包收口 (247d4dd)
# ============================================================
if [ -f "$SPEC" ]; then
  SP="$(cat "$SPEC")"
  tc_assert_contains "5.1 spec.in: %dir /etc/ws-ckpt" "%dir /etc/ws-ckpt" "$SP"
  tc_assert_contains "5.2 spec.in: rpm -qf 归属校验" "rpm -qf" "$SP"
else
  tc_skip "5.1-5.2 spec.in tests" "file not found: $SPEC"
fi

# ============================================================
# 6. 集成测试: rollback 守卫真实生效 (需 Linux+root+btrfs+二进制)
# ============================================================
if tc_require_root "6.1 rollback cwd guard" && tc_require_btrfs "6.1 rollback cwd guard" && tc_require_bin "6.1 rollback cwd guard"; then
  BIN="$(tc_find_wsckpt_bin)"
  WS_PATH="${TC_WS_PATH:-/tmp/ws-ckpt-qa-669-$$}"
  if tc_require_btrfs_path "6.1 rollback cwd guard (workspace fs)" "$WS_PATH"; then
    systemctl start ws-ckpt 2>/dev/null || true
    sleep 1
    mkdir -p "$WS_PATH"
    "$BIN" init -w "$WS_PATH" >/dev/null 2>&1 || true
    "$BIN" checkpoint -w "$WS_PATH" -i base -m base >/dev/null 2>&1 || true
    # 在 workspace 内开后台进程持有 cwd
    ( cd "$WS_PATH" && sleep 30 ) &
    OCC_PID=$!
    sleep 1
    OUT="$(cd / && "$BIN" rollback -w "$WS_PATH" -s base 2>&1)"; RC=$?
    if [ "$RC" != "0" ] && printf '%s' "$OUT" | grep -qiE 'cwd|occupied|occupant|inside workspace'; then
      tc_pass "6.1 rollback 守卫: cwd 占用时拒绝 (issue#669 端到端)"
    else
      tc_fail "6.1 rollback 守卫: 期望非零退出且提示 cwd 占用 (rc=$RC, out=$OUT)"
    fi
    kill "$OCC_PID" >/dev/null 2>&1 || true
    "$BIN" delete -w "$WS_PATH" --force >/dev/null 2>&1 || true
    rm -rf "$WS_PATH" 2>/dev/null || true
  fi
fi

# ============================================================
tc_summary
