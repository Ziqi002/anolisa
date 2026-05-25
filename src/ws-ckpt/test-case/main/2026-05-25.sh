#!/usr/bin/env bash
# 2026-05-25 — main 分支 ws-ckpt 增量测试 (v0.3.0 新增功能+修复)
# 覆盖: main 上自 2026-05-20 以来 17 个 ws-ckpt commits
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../_lib/common.sh"

tc_log "main branch — v0.3.0 incremental coverage (2026-05-25)"

# ============================================================
# 1. OpenClaw 插件骨架 (096b744, 530b951)
# ============================================================
OPENCLAW_DIR="$TC_WSCKPT_SRC/plugins/openclaw"

tc_assert_file_exists "openclaw: plugin.json" "$OPENCLAW_DIR/openclaw.plugin.json"
tc_assert_file_exists "openclaw: package.json" "$OPENCLAW_DIR/package.json"
tc_assert_file_exists "openclaw: tsconfig.json" "$OPENCLAW_DIR/tsconfig.json"
tc_assert_file_exists "openclaw: index.ts" "$OPENCLAW_DIR/src/index.ts"
tc_assert_file_exists "openclaw: btrfs-manager.ts" "$OPENCLAW_DIR/src/btrfs-manager.ts"
tc_assert_file_exists "openclaw: tool-registry.ts" "$OPENCLAW_DIR/src/tool-registry.ts"
tc_assert_file_exists "openclaw: handlers.ts" "$OPENCLAW_DIR/src/handlers.ts"
tc_assert_file_exists "openclaw: hooks.ts" "$OPENCLAW_DIR/src/hooks.ts"
tc_assert_file_exists "openclaw: whitelist.ts" "$OPENCLAW_DIR/src/whitelist.ts"

if [ -f "$OPENCLAW_DIR/openclaw.plugin.json" ]; then
  PJSON="$(cat "$OPENCLAW_DIR/openclaw.plugin.json")"
  tc_assert_contains "openclaw: plugin id=ws-ckpt" '"id": "ws-ckpt"' "$PJSON"
  tc_assert_contains "openclaw: plugin kind=tool" '"kind": "tool"' "$PJSON"
fi

if [ -f "$OPENCLAW_DIR/package.json" ]; then
  PKGJSON="$(cat "$OPENCLAW_DIR/package.json")"
  tc_assert_contains "openclaw: package name" "@openclaw/ws-ckpt" "$PKGJSON"
  tc_assert_contains "openclaw: version 0.3" "0.3." "$PKGJSON"
fi

# ============================================================
# 2. Hermes 插件骨架 (fe12905)
# ============================================================
HERMES_DIR="$TC_WSCKPT_SRC/plugins/hermes"

tc_assert_file_exists "hermes: plugin.yaml" "$HERMES_DIR/plugin.yaml"
tc_assert_file_exists "hermes: __init__.py" "$HERMES_DIR/__init__.py"
tc_assert_file_exists "hermes: checkpoint_manager.py" "$HERMES_DIR/checkpoint_manager.py"
tc_assert_file_exists "hermes: tools.py" "$HERMES_DIR/tools.py"
tc_assert_file_exists "hermes: config.py" "$HERMES_DIR/config.py"

if [ -f "$HERMES_DIR/plugin.yaml" ]; then
  PYAML="$(cat "$HERMES_DIR/plugin.yaml")"
  tc_assert_contains "hermes: yaml name=ws-ckpt" "name: ws-ckpt" "$PYAML"
  tc_assert_contains "hermes: yaml version 0.3.0" '"0.3.0"' "$PYAML"
  tc_assert_contains "hermes: provides_tools checkpoint" "ws-ckpt-checkpoint" "$PYAML"
  tc_assert_contains "hermes: provides_tools rollback" "ws-ckpt-rollback" "$PYAML"
  tc_assert_contains "hermes: provides_tools list" "ws-ckpt-list" "$PYAML"
  tc_assert_contains "hermes: provides_tools diff" "ws-ckpt-diff" "$PYAML"
  tc_assert_contains "hermes: provides_hooks on_session_start" "on_session_start" "$PYAML"
fi

# ============================================================
# 3. Makefile 与 adapter-manifest (0de7b61, e113cc1, d96a5e0, 306d3c8, 5a9f67e)
# ============================================================
TC_MAKEFILE="$TC_WSCKPT_DIR/Makefile"
TC_MANIFEST="$TC_WSCKPT_DIR/adapter-manifest.json"

tc_assert_file_exists "Makefile exists" "$TC_MAKEFILE"

if [ -f "$TC_MAKEFILE" ]; then
  MK="$(cat "$TC_MAKEFILE")"
  tc_assert_contains "Makefile: build target" "build:" "$MK"
  tc_assert_contains "Makefile: install target" "install:" "$MK"
  tc_assert_contains "Makefile: uninstall target" "uninstall:" "$MK"
  tc_assert_contains "Makefile: DESTDIR support" "DESTDIR" "$MK"
  tc_assert_contains "Makefile: cargo build --release" "cargo build --release" "$MK"
  tc_assert_contains "Makefile: npm run build" "npm run build" "$MK"
  tc_assert_contains "Makefile: install openclaw" "openclaw" "$MK"
  tc_assert_contains "Makefile: install hermes" "hermes" "$MK"
fi

tc_assert_file_exists "adapter-manifest.json exists" "$TC_MANIFEST"

if [ -f "$TC_MANIFEST" ]; then
  MANIFEST="$(cat "$TC_MANIFEST")"
  tc_assert_contains "manifest: schemaVersion 1" '"schemaVersion": "1"' "$MANIFEST"
  tc_assert_contains "manifest: component ws-ckpt" '"component": "ws-ckpt"' "$MANIFEST"
  tc_assert_contains "manifest: version 0.3.0" '"version": "0.3.0"' "$MANIFEST"
  tc_assert_contains "manifest: target openclaw" '"openclaw"' "$MANIFEST"
  tc_assert_contains "manifest: target hermes" '"hermes"' "$MANIFEST"
  tc_assert_contains "manifest: install-openclaw.sh" "install-openclaw.sh" "$MANIFEST"
  tc_assert_contains "manifest: install-hermes.sh" "install-hermes.sh" "$MANIFEST"
fi

# ============================================================
# 4. 安装/卸载脚本与 lib-discover (d96a5e0, 306d3c8, 5a9f67e)
# ============================================================
SCRIPTS_DIR="$TC_WSCKPT_DIR/scripts"

tc_assert_file_exists "scripts: lib-discover.sh" "$SCRIPTS_DIR/lib-discover.sh"
tc_assert_file_exists "scripts: install-openclaw.sh" "$SCRIPTS_DIR/install-openclaw.sh"
tc_assert_file_exists "scripts: uninstall-openclaw.sh" "$SCRIPTS_DIR/uninstall-openclaw.sh"
tc_assert_file_exists "scripts: install-hermes.sh" "$SCRIPTS_DIR/install-hermes.sh"
tc_assert_file_exists "scripts: uninstall-hermes.sh" "$SCRIPTS_DIR/uninstall-hermes.sh"

if [ -f "$SCRIPTS_DIR/lib-discover.sh" ]; then
  LIB="$(cat "$SCRIPTS_DIR/lib-discover.sh")"
  tc_assert_contains "lib-discover: discover_dir func" "discover_dir" "$LIB"
  tc_assert_contains "lib-discover: find_plugin_src func" "find_plugin_src" "$LIB"
  tc_assert_contains "lib-discover: find_skill_src func" "find_skill_src" "$LIB"
  tc_assert_contains "lib-discover: ANOLISA_TARGET_DIR" "ANOLISA_TARGET_DIR" "$LIB"
fi

# 检查脚本可执行权限
if [ -x "$SCRIPTS_DIR/install-openclaw.sh" ]; then
  tc_pass "install-openclaw: executable"
else
  tc_fail "install-openclaw: not executable"
fi
if [ -x "$SCRIPTS_DIR/install-hermes.sh" ]; then
  tc_pass "install-hermes: executable"
else
  tc_fail "install-hermes: not executable"
fi

# ============================================================
# 5. RPM Spec v0.3.0 更新 (80d0b67, d96a5e0, 306d3c8, 577f3ff)
# ============================================================
if [ -f "$TC_SPEC_FILE" ]; then
  SPEC="$(cat "$TC_SPEC_FILE")"

  # 80d0b67: 不应单独声明 %dir %{_datadir}/anolisa（不含子路径）
  # 该行只写 %dir %{_datadir}/anolisa 末尾无 /runtime 等后缀
  if printf '%s' "$SPEC" | grep -qP '^%dir\s+%\{_datadir\}/anolisa\s*$'; then
    tc_fail "spec: still declares %dir %{_datadir}/anolisa alone"
  else
    tc_pass "spec: no standalone %dir %{_datadir}/anolisa"
  fi

  tc_assert_contains "spec: BuildRequires nodejs" "nodejs" "$SPEC"
  tc_assert_contains "spec: BuildRequires npm" "npm" "$SPEC"
  tc_assert_contains "spec: npm run build" "npm run build" "$SPEC"
  tc_assert_contains "spec: plugins/openclaw dir" "plugins/openclaw" "$SPEC"
  tc_assert_contains "spec: plugins/hermes dir" "plugins/hermes" "$SPEC"
  tc_assert_contains "spec: adapters/ws-ckpt dir" "adapters/ws-ckpt" "$SPEC"
  tc_assert_contains "spec: Version @VERSION@" "@VERSION@" "$SPEC"
  tc_assert_contains "spec: _localbindir /usr/local/bin" '%global _localbindir /usr/local/bin' "$SPEC"
  tc_assert_contains "spec: remove legacy binary on upgrade" 'rm -f %{_bindir}/ws-ckpt' "$SPEC"
fi

# ============================================================
# 6. Skill 更新 (2eeccf1)
# ============================================================
if [ -f "$TC_SKILL_DIR/SKILL.md" ]; then
  SKILL="$(cat "$TC_SKILL_DIR/SKILL.md")"
  # 检查 workspace 路径说明
  if printf '%s' "$SKILL" | grep -qi '工作区路径\|workspace'; then
    tc_pass "skill: workspace path section"
  else
    tc_fail "skill: missing workspace path guidance"
  fi
  tc_assert_not_contains "skill: no hardcoded agent name" "copilot-shell" "$SKILL"
  if printf '%s' "$SKILL" | grep -qi '触发\|trigger'; then
    tc_pass "skill: trigger table"
  else
    tc_fail "skill: missing trigger table"
  fi
  tc_assert_contains "skill: -w param mandatory" "-w" "$SKILL"
fi

# ============================================================
# 7. 源码结构断言：diff 解析增强 (162311a, 021edc1)
# ============================================================
DAEMON_SRC="$TC_WSCKPT_SRC/crates/daemon/src"

if [ -f "$DAEMON_SRC/backends/btrfs_common.rs" ]; then
  BTRFS_COMMON="$(cat "$DAEMON_SRC/backends/btrfs_common.rs")"
  tc_assert_contains "btrfs_common: symlink handling" "symlink" "$BTRFS_COMMON"
  if printf '%s' "$BTRFS_COMMON" | grep -qi 'Renamed\|rename'; then
    tc_pass "btrfs_common: rename detection"
  else
    tc_fail "btrfs_common: rename detection not found"
  fi
  tc_assert_contains "btrfs_common: resolve_path helper" "resolve_path" "$BTRFS_COMMON"
  if printf '%s' "$BTRFS_COMMON" | grep -qi 'change_precedence\|precedence'; then
    tc_pass "btrfs_common: change_precedence"
  else
    tc_fail "btrfs_common: change_precedence not found"
  fi
else
  tc_skip "btrfs_common checks" "file not found"
fi

if [ -f "$DAEMON_SRC/snapshot_mgr.rs" ]; then
  tc_assert_contains "snapshot_mgr: SnapshotNotFound" "SnapshotNotFound" "$(cat "$DAEMON_SRC/snapshot_mgr.rs")"
else
  tc_skip "snapshot_mgr: SnapshotNotFound" "file not found"
fi

# ============================================================
# 8. 源码结构断言：daemon 鲁棒性 (1c0e230, dcef1e6)
# ============================================================
if [ -f "$DAEMON_SRC/workspace_mgr.rs" ]; then
  WS_MGR="$(cat "$DAEMON_SRC/workspace_mgr.rs")"
  if printf '%s' "$WS_MGR" | grep -qi 'idempotent\|already.*init\|AlreadyInitialized'; then
    tc_pass "workspace_mgr: idempotent init"
  else
    tc_fail "workspace_mgr: idempotent init not found"
  fi
else
  tc_skip "workspace_mgr checks" "file not found"
fi

if [ -f "$DAEMON_SRC/backends/btrfs_loop.rs" ]; then
  tc_assert_contains "btrfs_loop: loop_img_state" "loop_img_state" "$(cat "$DAEMON_SRC/backends/btrfs_loop.rs")"
else
  tc_skip "btrfs_loop: loop_img_state" "file not found"
fi

COMMON_SRC="$TC_WSCKPT_SRC/crates/common/src"
if [ -f "$COMMON_SRC/backend.rs" ]; then
  tc_assert_contains "backend trait: loop_img_state" "loop_img_state" "$(cat "$COMMON_SRC/backend.rs")"
else
  tc_skip "backend trait: loop_img_state" "file not found"
fi

# ============================================================
# 9. 源码结构断言：时区显示 (0e89c0d)
# ============================================================
CLI_SRC="$TC_WSCKPT_SRC/crates/cli"
if [ -f "$CLI_SRC/Cargo.toml" ]; then
  tc_assert_contains "cli: chrono dependency" "chrono" "$(cat "$CLI_SRC/Cargo.toml")"
else
  tc_skip "cli: chrono dependency" "Cargo.toml not found"
fi

if [ -f "$CLI_SRC/src/main.rs" ]; then
  CLI_MAIN="$(cat "$CLI_SRC/src/main.rs")"
  if printf '%s' "$CLI_MAIN" | grep -qi 'Local\|local.*time\|FixedOffset'; then
    tc_pass "cli: Local timezone usage"
  else
    tc_fail "cli: Local timezone usage not found"
  fi
else
  tc_skip "cli: Local timezone" "main.rs not found"
fi

# ============================================================
# 10. 版本号一致性 (577f3ff)
# ============================================================
if grep -q 'version = "0\.3\.0"' "$TC_WSCKPT_SRC/Cargo.toml" 2>/dev/null; then
  tc_pass "Cargo.toml: version 0.3.0"
else
  tc_fail "Cargo.toml: version 0.3.0 not found"
fi

if [ -f "$TC_SPEC_FILE" ]; then
  if grep -q '@VERSION@' "$TC_SPEC_FILE"; then
    tc_pass "spec: Version @VERSION@ placeholder"
  else
    tc_fail "spec: Version @VERSION@ not found"
  fi
fi

if [ -f "$TC_MANIFEST" ]; then
  tc_assert_contains "manifest: version 0.3.0 (recheck)" '"version": "0.3.0"' "$(cat "$TC_MANIFEST")"
fi

if [ -f "$TC_WSCKPT_DIR/CHANGELOG.md" ]; then
  tc_assert_contains "CHANGELOG: 0.3.0 entry" "0.3.0" "$(cat "$TC_WSCKPT_DIR/CHANGELOG.md")"
fi

# ============================================================
# 11. CLI 行为测试 v0.3.0 (需二进制)
# ============================================================
BIN="$(tc_find_wsckpt_bin 2>/dev/null || true)"
if [ -n "$BIN" ]; then
  # 11.1 --version
  VOUT="$("$BIN" --version 2>&1 || true)"
  tc_assert_contains "version contains 0.3" "0.3" "$VOUT"

  # 11.2 list --help includes json
  LIST_HELP="$("$BIN" list --help 2>&1 || true)"
  tc_assert_contains "list --help: json format" "json" "$LIST_HELP"

  # 11.3 diff --help includes -f and -t
  DIFF_HELP="$("$BIN" diff --help 2>&1 || true)"
  tc_assert_contains "diff --help: -f arg" "-f" "$DIFF_HELP"
  tc_assert_contains "diff --help: -t arg" "-t" "$DIFF_HELP"
else
  tc_skip "CLI behavior tests v0.3.0" "no ws-ckpt binary"
fi

# ============================================================
# 12. Daemon 集成测试 v0.3.0 (需 root + btrfs + service)
# ============================================================
if tc_require_root "daemon integration v0.3.0" && tc_require_btrfs "daemon integration v0.3.0" && tc_require_service "daemon integration v0.3.0"; then
  BIN="$(tc_find_wsckpt_bin)"
  WS_PATH="${TC_WS_PATH:-/tmp/ws-ckpt-qa-v3-$$}"
  if ! tc_require_btrfs_path "daemon integration v0.3.0 (workspace fs)" "$WS_PATH"; then
    tc_summary; exit $?
  fi

  # 确保 daemon 运行
  systemctl start ws-ckpt || { tc_fail "cannot start ws-ckpt"; tc_summary; exit 1; }
  sleep 1

  # 12.1 idempotent init —— 必须先验证首次 init 成功,否则第二次"成功"会变成假阳性
  OUT="$("$BIN" init -w "$WS_PATH" 2>&1)"; RC=$?
  tc_assert_exit "init (first call, setup)" "0" "$RC"
  OUT="$("$BIN" init -w "$WS_PATH" 2>&1)"; RC=$?
  tc_assert_exit "init idempotent (second call)" "0" "$RC"

  # checkpoint for further tests
  "$BIN" checkpoint -w "$WS_PATH" -i base -m "base snapshot" >/dev/null 2>&1

  # 12.2 diff symlink detection
  ln -sf /tmp "$WS_PATH/link_to_tmp"
  "$BIN" checkpoint -w "$WS_PATH" -i sym1 -m "with symlink" >/dev/null 2>&1
  DIFF_OUT="$("$BIN" diff -w "$WS_PATH" -f base -t sym1 2>&1 || true)"
  tc_assert_contains "diff symlink detection" "link_to_tmp" "$DIFF_OUT"

  # 12.3 diff rename detection
  echo "rename-test" > "$WS_PATH/original.txt"
  "$BIN" checkpoint -w "$WS_PATH" -i pre_mv -m "before rename" >/dev/null 2>&1
  mv "$WS_PATH/original.txt" "$WS_PATH/renamed.txt"
  "$BIN" checkpoint -w "$WS_PATH" -i post_mv -m "after rename" >/dev/null 2>&1
  DIFF_OUT="$("$BIN" diff -w "$WS_PATH" -f pre_mv -t post_mv 2>&1 || true)"
  if printf '%s' "$DIFF_OUT" | grep -qi 'rename\|original.txt\|renamed.txt'; then
    tc_pass "diff rename detection"
  else
    tc_fail "diff rename detection"
  fi

  # 12.4 diff nonexistent returns SnapshotNotFound
  ERR_OUT="$("$BIN" diff -w "$WS_PATH" -f nosuch -t base 2>&1 || true)"
  if printf '%s' "$ERR_OUT" | grep -qi 'not.found\|SnapshotNotFound'; then
    tc_pass "diff nonexistent returns SnapshotNotFound"
  else
    tc_fail "diff nonexistent: expected 'not found' in error output"
  fi

  # 12.5 list shows local time (timezone offset)
  LIST_OUT="$("$BIN" list -w "$WS_PATH" 2>&1 || true)"
  if printf '%s' "$LIST_OUT" | grep -qE '[+-][0-9]{2}:[0-9]{2}|[+-][0-9]{4}'; then
    tc_pass "list shows local time offset"
  else
    tc_fail "list: no timezone offset found in output"
  fi

  # 12.6 list with metadata no bincode err
  "$BIN" checkpoint -w "$WS_PATH" -i meta1 -m "metadata test" >/dev/null 2>&1
  OUT="$("$BIN" list -w "$WS_PATH" 2>&1)"; RC=$?
  tc_assert_exit "list with metadata no bincode err" "0" "$RC"

  # cleanup
  "$BIN" delete -w "$WS_PATH" --force >/dev/null 2>&1 || true
  rm -rf "$WS_PATH" 2>/dev/null || true
fi

# ============================================================
tc_summary
