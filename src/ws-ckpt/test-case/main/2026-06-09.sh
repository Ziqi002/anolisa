#!/usr/bin/env bash
# 2026-06-09 — main 分支增量测试 (v0.3.3 周期)
# 主体: per-workspace policy override 端到端 (common/daemon/cli + hermes skill + openclaw plugin)
# 附加: init 数据安全 (reflink/rename/backup) + 锁粒度/原子写收尾
# Section 1-6 为静态源码契约断言, Mac/Linux 均可跑; Section 7 为可选实跑(需二进制), 否则 SKIP。
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../_lib/common.sh"

tc_log "main — v0.3.3 per-workspace policy override (2026-06-09)"

# 分支守卫: 仅在 main(或已合并) 源码上执行; 在 ckpt-test 等不含 v0.3.3 源码的分支上整体 SKIP。
if ! tc_require_branch "main 静态用例(2026-06-09)" "main"; then
  tc_summary; exit $?
fi

COMMON_LIB="$TC_WSCKPT_SRC/crates/common/src/lib.rs"
CLI_MAIN="$TC_WSCKPT_SRC/crates/cli/src/main.rs"
WS_MGR="$TC_WSCKPT_SRC/crates/daemon/src/workspace_mgr.rs"
STATE_RS="$TC_WSCKPT_SRC/crates/daemon/src/state.rs"
SNAP_MGR="$TC_WSCKPT_SRC/crates/daemon/src/snapshot_mgr.rs"
PERSIST_RS="$TC_WSCKPT_SRC/crates/common/src/persist.rs"
BTRFS_BASE="$TC_WSCKPT_SRC/crates/daemon/src/backends/btrfs_base.rs"
BTRFS_LOOP="$TC_WSCKPT_SRC/crates/daemon/src/backends/btrfs_loop.rs"
BTRFS_COMMON="$TC_WSCKPT_SRC/crates/daemon/src/backends/btrfs_common.rs"
OC_CONFIG="$TC_OPENCLAW_PLUGIN_DIR/src/config.ts"
OC_HANDLERS="$TC_OPENCLAW_PLUGIN_DIR/src/handlers.ts"
HERMES_TOOLS="$TC_WSCKPT_SRC/plugins/hermes/tools.py"
SKILL_MD="$TC_SKILL_DIR/SKILL.md"
DESIGN_DOC="$TC_WSCKPT_DIR/docs/ws-ckpt-design.md"
PLUGIN_DOC="$TC_WSCKPT_DIR/docs/ws-ckpt-plugin-design.md"

# ============================================================
# 1. common 协议: versioned JSON schema + 新 IPC 变体 + 类型 (0e04853)
# ============================================================
if [ -f "$COMMON_LIB" ]; then
  C="$(cat "$COMMON_LIB")"
  tc_assert_contains "1.1 schema: ws-ckpt-policy/v1"   'WORKSPACE_POLICY_JSON_SCHEMA: &str = "ws-ckpt-policy/v1"' "$C"
  tc_assert_contains "1.2 schema: ws-ckpt-config/v1"   'GLOBAL_CONFIG_JSON_SCHEMA: &str = "ws-ckpt-config/v1"'   "$C"
  tc_assert_contains "1.3 schema: ws-ckpt-overview/v1" 'OVERVIEW_JSON_SCHEMA: &str = "ws-ckpt-overview/v1"'     "$C"
  tc_assert_contains "1.4 IPC: GetWorkspacePolicy"     "GetWorkspacePolicy"   "$C"
  tc_assert_contains "1.5 IPC: PatchWorkspacePolicy"   "PatchWorkspacePolicy" "$C"
  tc_assert_contains "1.6 IPC: ResetWorkspacePolicy"   "ResetWorkspacePolicy" "$C"
  tc_assert_contains "1.7 IPC: ReloadGlobalConfig"     "ReloadGlobalConfig"   "$C"
  tc_assert_contains "1.8 IPC: ReloadWorkspacePolicy"  "ReloadWorkspacePolicy" "$C"
  tc_assert_contains "1.9 IPC: ConfigOverview"         "ConfigOverview"       "$C"
  tc_assert_contains "1.10 type: WorkspacePolicy"      "WorkspacePolicy"      "$C"
  tc_assert_contains "1.11 type: EffectivePolicy"      "EffectivePolicy"      "$C"
  tc_assert_contains "1.12 type: PolicyFieldOp"        "PolicyFieldOp"        "$C"
  tc_assert_contains "1.13 EffectivePolicy::is_disabled" "is_disabled"        "$C"
  tc_assert_contains "1.14 inherit-global 语义注释"    "inherit-global"       "$C"
else
  tc_skip "1.x common 协议" "file not found: $COMMON_LIB"
fi

# ============================================================
# 2. CLI config 子命令重构 (0e04853)
# ============================================================
if [ -f "$CLI_MAIN" ]; then
  M="$(cat "$CLI_MAIN")"
  tc_assert_contains "2.1 struct ConfigArgs"            "struct ConfigArgs" "$M"
  tc_assert_contains "2.2 -g/--global flag"             "short = 'g'"       "$M"
  tc_assert_contains "2.3 -w/--workspace flag"          "short = 'w'"       "$M"
  tc_assert_contains "2.4 ArgGroup scope 互斥"          'ArgGroup::new("scope")' "$M"
  tc_assert_contains "2.5 --reset 与 set flag 互斥"     "conflicts_with_all" "$M"
  tc_assert_contains "2.6 handle_workspace_config_reset" "handle_workspace_config_reset" "$M"
  tc_assert_contains "2.7 overview 视图函数"            "handle_config_overview_view"   "$M"
  tc_assert_contains "2.8 --reset 错误串"               "--reset is only valid with -w/--workspace" "$M"
  tc_assert_contains "2.9 --format 校验错误串"          "unknown --format value" "$M"
  tc_assert_contains "2.10 PolicyFieldOp::Set 派发"     "PolicyFieldOp::Set" "$M"
else
  tc_skip "2.x CLI config" "file not found: $CLI_MAIN"
fi

# ============================================================
# 3. daemon: per-ws 状态与并发安全 (0e04853)
# ============================================================
if [ -f "$WS_MGR" ]; then
  W="$(cat "$WS_MGR")"
  tc_assert_contains "3.1 workspace_mgr: lock_wsid 串行化" "lock_wsid" "$W"
  tc_assert_contains "3.2 recover 清空 per-ws index dir"   "Remove the entire per-ws index dir" "$W"
else
  tc_skip "3.1-3.2 workspace_mgr" "file not found: $WS_MGR"
fi
if [ -f "$STATE_RS" ]; then
  S="$(cat "$STATE_RS")"
  tc_assert_contains "3.3 state: WorkspacePolicy 字段" "WorkspacePolicy" "$S"
  tc_assert_contains "3.4 state: policy_io_mu 串行写"  "policy_io_mu"    "$S"
  tc_assert_contains "3.5 state: wsid 生命周期锁"      "wsid"            "$S"
else
  tc_skip "3.3-3.5 state.rs" "file not found: $STATE_RS"
fi

# ============================================================
# 4. skill / plugin: 辨识联合解析 + 信任 is_disabled (44607ee)
# ============================================================
if [ -f "$OC_CONFIG" ]; then
  OC="$(cat "$OC_CONFIG")"
  tc_assert_contains "4.1 openclaw: kind parse-error" 'kind: "parse-error"' "$OC"
  tc_assert_contains "4.2 openclaw: kind disabled"    'kind: "disabled"'    "$OC"
  tc_assert_contains "4.3 openclaw: kind count"       'kind: "count"'       "$OC"
  tc_assert_contains "4.4 openclaw: kind age"         'kind: "age"'         "$OC"
  tc_assert_contains "4.5 openclaw: schema 校验"      'root.schema !== "ws-ckpt-policy/v1"' "$OC"
  tc_assert_contains "4.6 openclaw: 信任 is_disabled" "eff.is_disabled === true" "$OC"
  tc_assert_contains "4.7 openclaw: 严格整数(拒非整)" "Number.isInteger(keep.count)" "$OC"
else
  tc_skip "4.1-4.7 openclaw config.ts" "file not found: $OC_CONFIG"
fi
if [ -f "$HERMES_TOOLS" ]; then
  H="$(cat "$HERMES_TOOLS")"
  tc_assert_contains "4.8 hermes: schema 常量"        '_POLICY_JSON_SCHEMA = "ws-ckpt-policy/v1"' "$H"
  tc_assert_contains "4.9 hermes: 联合解析函数"       "_parse_workspace_policy_json" "$H"
  tc_assert_contains "4.10 hermes: parse-error 态"    '"kind": "parse-error"' "$H"
  tc_assert_contains "4.11 hermes: 信任 is_disabled"  'eff.get("is_disabled") is True' "$H"
else
  tc_skip "4.8-4.11 hermes tools.py" "file not found: $HERMES_TOOLS"
fi
if [ -f "$OC_HANDLERS" ]; then
  OH="$(cat "$OC_HANDLERS")"
  tc_assert_contains "4.12 openclaw: unset 恢复 inherit-global" "unset" "$OH"
else
  tc_skip "4.12 openclaw handlers.ts" "file not found: $OC_HANDLERS"
fi
if [ -f "$SKILL_MD" ]; then
  SK="$(cat "$SKILL_MD")"
  tc_assert_contains "4.13 SKILL.md: config 文档段"  "config" "$SK"
  tc_assert_contains "4.14 SKILL.md: --format json"  "--format json" "$SK"
  tc_assert_contains "4.15 SKILL.md: -w workspace 作用域" "-w" "$SK"
else
  tc_skip "4.13-4.15 SKILL.md" "file not found: $SKILL_MD"
fi

# ============================================================
# 5. init 数据安全 (b6155bb / 605a760 / 8952d60)
# ============================================================
if [ -f "$BTRFS_BASE" ]; then
  BB="$(cat "$BTRFS_BASE")"
  tc_assert_contains "5.1 btrfs_base: .pre-init-bak 备份" ".pre-init-bak" "$BB"
  tc_assert_contains "5.2 btrfs_base: cp --reflink=always" "--reflink=always" "$BB"
  tc_assert_not_contains "5.3 btrfs_base: move_contents 已移除" "fn move_contents" "$BB"
else
  tc_skip "5.1-5.3 btrfs_base.rs" "file not found: $BTRFS_BASE"
fi
if [ -f "$BTRFS_LOOP" ]; then
  BL="$(cat "$BTRFS_LOOP")"
  tc_assert_contains "5.4 btrfs_loop: rename 到 .pre-init-bak" ".pre-init-bak" "$BL"
else
  tc_skip "5.4 btrfs_loop.rs" "file not found: $BTRFS_LOOP"
fi
if [ -f "$BTRFS_COMMON" ]; then
  BC="$(cat "$BTRFS_COMMON")"
  tc_assert_contains "5.5 btrfs_common: restore_original_from_backup" "restore_original_from_backup" "$BC"
  tc_assert_contains "5.6 btrfs_common: 区分 NotFound/其它 stat 错误" "ErrorKind::NotFound" "$BC"
else
  tc_skip "5.5-5.6 btrfs_common.rs" "file not found: $BTRFS_COMMON"
fi

# ============================================================
# 6. 锁粒度 / 原子写收尾 (822bfda / 3c2f421 / a60d468 / d3089d3)
# ============================================================
if [ -f "$PERSIST_RS" ]; then
  PR="$(cat "$PERSIST_RS")"
  tc_assert_contains "6.1 persist: atomic_write helper(tmp+fsync+rename)" "pub fn atomic_write" "$PR"
else
  tc_skip "6.1 persist.rs" "file not found: $PERSIST_RS"
fi
if [ -f "$SNAP_MGR" ]; then
  SM="$(cat "$SNAP_MGR")"
  tc_assert_contains "6.2 snapshot_mgr: rollback cwd 守卫"   "guard_cwd_occupants" "$SM"
else
  tc_skip "6.2 snapshot_mgr.rs" "file not found: $SNAP_MGR"
fi

# ============================================================
# 7. 文档存在性 (e96822f / e94aba4)
# ============================================================
tc_assert_file_exists "7.1 ws-ckpt-design.md 存在"        "$DESIGN_DOC"
tc_assert_file_exists "7.2 ws-ckpt-plugin-design.md 存在" "$PLUGIN_DOC"

# ============================================================
# 8. (可选实跑) version + config scope 互斥 CLI 行为
# ============================================================
if BIN="$(tc_find_wsckpt_bin 2>/dev/null)"; then
  VER="$("$BIN" --version 2>&1 || true)"
  tc_assert_contains "8.1 --version 含 0.3.3" "0.3.3" "$VER"
  # -g 与 -w 同时给出应被 clap scope 互斥拒绝(非零退出)
  tc_run_cli_expect_fail "8.2 config -g -w 互斥拒绝" "$BIN" config -g -w /tmp/nonexistent-ws
else
  tc_skip "8.1 --version 含 0.3.3" "ws-ckpt binary not found"
  tc_skip "8.2 config -g -w 互斥拒绝" "ws-ckpt binary not found"
fi

tc_summary
exit $?
