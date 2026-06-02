#!/usr/bin/env bash
# 2026-06-02 — main 分支 ws-ckpt 增量测试 (v0.3.1 + v0.3.2, 14 commits)
# 覆盖: 577f3ff..main 自 v0.3.0 以来的全部 ws-ckpt commit
# 静态断言 Mac/Linux 均可; 集成测试需 Linux+root+btrfs, 否则 SKIP。
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../_lib/common.sh"

tc_log "main branch — v0.3.1 + v0.3.2 incremental coverage (2026-06-02)"

# 分支守卫: 仅在 main(或已合并 main 的 HEAD)源码上执行; 旧源码整体 SKIP。
if ! tc_require_branch "main 增量静态用例" "main"; then
  tc_summary; exit $?
fi

OPENCLAW_DIR="$TC_WSCKPT_SRC/plugins/openclaw"
HERMES_DIR="$TC_WSCKPT_SRC/plugins/hermes"
DAEMON_SRC="$TC_WSCKPT_SRC/crates/daemon/src"
SCRIPTS_DIR="$TC_WSCKPT_DIR/scripts"
SKILL_MD="$TC_SKILL_DIR/SKILL.md"
MANIFEST="$TC_WSCKPT_DIR/adapter-manifest.json"

# ============================================================
# 1. OpenClaw 集成健壮性 (7a208e6/13f51e1/2152a7d/79fd8d3)
# ============================================================
OC_PJSON="$OPENCLAW_DIR/openclaw.plugin.json"
if [ -f "$OC_PJSON" ]; then
  PJSON="$(cat "$OC_PJSON")"
  tc_assert_contains "1.1 plugin.json: onStartup" "onStartup" "$PJSON"
  tc_assert_contains "1.2 plugin.json: onStartup=true" "true" "$PJSON"
  tc_assert_contains "1.3 plugin.json: workspace in configSchema" '"workspace"' "$PJSON"
else
  tc_skip "1.1-1.3 openclaw plugin.json tests" "file not found: $OC_PJSON"
fi

OC_UNINST="$SCRIPTS_DIR/uninstall-openclaw.sh"
if [ -f "$OC_UNINST" ]; then
  tc_assert_contains "1.4 uninstall-openclaw: OPENCLAW_STATE_DIR" "OPENCLAW_STATE_DIR" "$(cat "$OC_UNINST")"
else
  tc_skip "1.4 uninstall-openclaw test" "file not found: $OC_UNINST"
fi

OC_HANDLERS="$OPENCLAW_DIR/src/handlers.ts"
if [ -f "$OC_HANDLERS" ]; then
  tc_assert_contains "1.5 handlers.ts: cwdInsideWorkspace 落点" "cwdInsideWorkspace" "$(cat "$OC_HANDLERS")"
else
  tc_skip "1.5 handlers.ts test" "file not found: $OC_HANDLERS"
fi

# ============================================================
# 2. cwd 父路径保护 (3f66bbd)
# ============================================================
if [ -f "$SKILL_MD" ]; then
  tc_assert_contains "2.1 SKILL.md: 禁止 workspace 为 cwd 父路径" "父路径" "$(cat "$SKILL_MD")"
else
  tc_skip "2.1 SKILL.md test" "file not found: $SKILL_MD"
fi

HERMES_TOOLS="$HERMES_DIR/tools.py"
if [ -f "$HERMES_TOOLS" ]; then
  HTOOLS="$(cat "$HERMES_TOOLS")"
  tc_assert_contains "2.2 tools.py: 结构化拒绝 retryable False" '"retryable": False' "$HTOOLS"
  REJECT_COUNT=$(grep -c "_reject_if_cwd_inside_workspace" "$HERMES_TOOLS" || true)
  if [ "$REJECT_COUNT" -ge 4 ]; then
    tc_pass "2.3 tools.py: _reject_if_cwd_inside_workspace ≥4 ($REJECT_COUNT)"
  else
    tc_fail "2.3 tools.py: _reject_if_cwd_inside_workspace 仅 $REJECT_COUNT 次 (期望 ≥4)"
  fi
else
  tc_skip "2.2-2.3 hermes tools tests" "file not found: $HERMES_TOOLS"
fi

if [ -f "$OC_HANDLERS" ]; then
  # main(v0.3.2) 用常量 CWD_INSIDE_WORKSPACE_REASON; 后续分支重构为函数 cwdInsideWorkspaceReason。
  # 两种形式都代表 openclaw handlers 接入了 cwd 拒绝原因, 故二者命中其一即 PASS。
  if grep -qE 'CWD_INSIDE_WORKSPACE_REASON|cwdInsideWorkspaceReason' "$OC_HANDLERS"; then
    tc_pass "2.4 handlers.ts: cwd 拒绝原因 (CWD_INSIDE_WORKSPACE_REASON / cwdInsideWorkspaceReason)"
  else
    tc_fail "2.4 handlers.ts: 未见 cwd 拒绝原因引用"
  fi
fi

OC_STATE="$OPENCLAW_DIR/src/state.ts"
if [ -f "$OC_STATE" ]; then
  tc_assert_contains "2.5 state.ts: cwdInsideWorkspace fn" "function cwdInsideWorkspace" "$(cat "$OC_STATE")"
else
  tc_skip "2.5 state.ts test" "file not found: $OC_STATE"
fi

# ============================================================
# 3. 卸载更彻底 (f08a457 + uninstall 脚本)
# ============================================================
if [ -f "$OC_UNINST" ]; then
  OCU="$(cat "$OC_UNINST")"
  tc_assert_contains "3.1 uninstall-openclaw: alsoAllow 清理" "alsoAllow" "$OCU"
  tc_assert_contains "3.2 uninstall-openclaw: ws-ckpt- 前缀过滤" "ws-ckpt-" "$OCU"
  tc_assert_contains "3.3 uninstall-openclaw: node -e 改写 config" "node -e" "$OCU"
fi

H_UNINST="$SCRIPTS_DIR/uninstall-hermes.sh"
if [ -f "$H_UNINST" ]; then
  HU="$(cat "$H_UNINST")"
  tc_assert_contains "3.4a uninstall-hermes: config.yaml 清理" "config.yaml" "$HU"
  tc_assert_contains "3.4b uninstall-hermes: python3 解析" "python3" "$HU"
else
  tc_skip "3.4 uninstall-hermes test" "file not found: $H_UNINST"
fi

# ============================================================
# 4. detect-openclaw.sh 探测脚本 (新增)
# ============================================================
DETECT="$SCRIPTS_DIR/detect-openclaw.sh"
tc_assert_file_exists "4.1 detect-openclaw.sh 存在" "$DETECT"
if [ -f "$DETECT" ]; then
  DET="$(cat "$DETECT")"
  tc_assert_contains "4.2 detect: source lib-discover.sh" "lib-discover.sh" "$DET"
  tc_assert_contains "4.3 detect: plugins list 查询" "plugins list" "$DET"
  tc_assert_contains "4.4 detect: OPENCLAW_STATE_DIR" "OPENCLAW_STATE_DIR" "$DET"
fi
if [ -f "$MANIFEST" ]; then
  tc_assert_contains "4.5 adapter-manifest: 收录 detect-openclaw.sh" "detect-openclaw.sh" "$(cat "$MANIFEST")"
else
  tc_skip "4.5 adapter-manifest test" "file not found: $MANIFEST"
fi

# ============================================================
# 5. 死代码 / fswatch / skill --force 回归 (c6fb08d/15ef957/6e8ad1a)
# ============================================================
tc_assert_file_missing "5.1 btrfs_ops.rs removed" "$DAEMON_SRC/btrfs_ops.rs"
if [ -f "$DAEMON_SRC/lib.rs" ]; then
  tc_assert_not_contains "5.2 lib.rs no mod btrfs_ops" "mod btrfs_ops" "$(cat "$DAEMON_SRC/lib.rs")"
fi

FSW="$DAEMON_SRC/fs_watcher.rs"
if [ -f "$FSW" ]; then
  FSWC="$(cat "$FSW")"
  tc_assert_contains "5.3 fs_watcher: AccessKind import" "AccessKind" "$FSWC"
  tc_assert_contains "5.4 fs_watcher: CLOSE_WRITE 清标志" "store(false" "$FSWC"
else
  tc_skip "5.3-5.4 fs_watcher tests" "file not found: $FSW"
fi

if [ -f "$SKILL_MD" ]; then
  DELETE_LINE=$(grep -n "\-\-force" "$SKILL_MD" | grep "delete" | head -1)
  if echo "$DELETE_LINE" | grep -q '\[--force\]'; then
    tc_fail "5.5 SKILL.md: delete --force 仍可选 (在 [] 内)"
  elif echo "$DELETE_LINE" | grep -q '\-\-force'; then
    tc_pass "5.5 SKILL.md: delete 必须 --force"
  else
    tc_fail "5.5 SKILL.md: delete 命令未见 --force"
  fi
fi

# ============================================================
# 6. 版本与打包一致性 (v0.3.1 / v0.3.2)
# ============================================================
if grep -q 'version = "0\.3\.2"' "$TC_WSCKPT_SRC/Cargo.toml" 2>/dev/null; then
  tc_pass "6.1 Cargo.toml: version 0.3.2"
else
  tc_fail "6.1 Cargo.toml: version 0.3.2 not found"
fi

if [ -f "$MANIFEST" ]; then
  tc_assert_contains "6.2 adapter-manifest: version 0.3.2" '"version": "0.3.2"' "$(cat "$MANIFEST")"
fi

if [ -f "$TC_SPEC_FILE" ]; then
  SPEC="$(cat "$TC_SPEC_FILE")"
  tc_assert_contains "6.3 spec.in: @VERSION@ 占位符" "@VERSION@" "$SPEC"
  tc_assert_contains "6.4 spec.in: 0.3.2 changelog 条目" "0.3.2-1" "$SPEC"
fi

if [ -f "$TC_WSCKPT_DIR/CHANGELOG.md" ]; then
  CL="$(cat "$TC_WSCKPT_DIR/CHANGELOG.md")"
  tc_assert_contains "6.5a CHANGELOG: 0.3.1 条目" "0.3.1" "$CL"
  tc_assert_contains "6.5b CHANGELOG: 0.3.2 条目" "0.3.2" "$CL"
fi

# 6.6 standalone adapter 入口齐备 (3b7168d #549)
if [ -f "$DETECT" ] && [ -f "$SCRIPTS_DIR/install-openclaw.sh" ] && [ -f "$OC_UNINST" ]; then
  tc_pass "6.6 standalone adapter 入口脚本齐备 (detect/install/uninstall)"
else
  tc_fail "6.6 standalone adapter 入口脚本不齐备"
fi

# ============================================================
# 7. 集成测试 (需 Linux + root + btrfs + 二进制)
# ============================================================
BIN="$(tc_find_wsckpt_bin 2>/dev/null || true)"
if [ -n "$BIN" ]; then
  VOUT="$("$BIN" --version 2>&1 || true)"
  tc_assert_contains "7.1 --version 显示 0.3.2" "0.3.2" "$VOUT"
else
  tc_skip "7.1 --version 0.3.2" "no ws-ckpt binary"
fi

if tc_require_root "7.2 cwd 父路径拒绝" && tc_require_btrfs "7.2 cwd 父路径拒绝" && tc_require_bin "7.2 cwd 父路径拒绝"; then
  BIN="$(tc_find_wsckpt_bin)"
  PARENT="${TC_WS_PATH:-/tmp/ws-ckpt-qa-parent-$$}"
  WS_PATH="$PARENT/ws"
  if tc_require_btrfs_path "7.2 cwd 父路径拒绝 (workspace fs)" "$WS_PATH"; then
    systemctl start ws-ckpt 2>/dev/null || true
    sleep 1
    mkdir -p "$WS_PATH"
    # cwd = $PARENT (workspace 的父路径), 对 workspace 操作时, 反过来若把 cwd 的父路径当 workspace 应被拒绝
    OUT="$(cd "$PARENT" && "$BIN" init -w "$PARENT" 2>&1)"; RC=$?
    if [ "$RC" != "0" ] && printf '%s' "$OUT" | grep -qiE 'cwd|parent|descendant|inside'; then
      tc_pass "7.2 cwd 父路径作为 workspace 被拒绝"
    else
      tc_fail "7.2 期望拒绝 cwd 父路径作为 workspace (rc=$RC, out=$OUT)"
    fi
    "$BIN" delete -w "$PARENT" --force >/dev/null 2>&1 || true
    rm -rf "$PARENT" 2>/dev/null || true
  fi
fi

# ============================================================
tc_summary
