#!/usr/bin/env bash
# 2026-05-20 — main 分支 ws-ckpt 全量初始化测试
# 覆盖: main 上全部 26 个 ws-ckpt commits
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../_lib/common.sh"

tc_log "main branch — full baseline coverage (2026-05-20)"

# ============================================================
# 1. 骨架 (683eb36)
# ============================================================
for p in \
  "$TC_WSCKPT_SRC/Cargo.toml" \
  "$TC_WSCKPT_SRC/crates/cli/Cargo.toml" \
  "$TC_WSCKPT_SRC/crates/daemon/Cargo.toml" \
  "$TC_WSCKPT_SRC/crates/common/Cargo.toml" \
  "$TC_WSCKPT_DIR/README.md" \
  "$TC_WSCKPT_DIR/CHANGELOG.md" \
  "$TC_WSCKPT_DIR/LICENSE" \
  "$TC_SPEC_FILE"; do
  tc_assert_file_exists "skeleton: $(basename "$p")" "$p"
done

# ============================================================
# 2. Skill 存在 (4f4e75a)
# ============================================================
tc_assert_file_exists "SKILL.md present" "$TC_SKILL_DIR/SKILL.md"
if [ -f "$TC_SKILL_DIR/SKILL.md" ]; then
  SKILL="$(cat "$TC_SKILL_DIR/SKILL.md")"
  tc_assert_contains "skill references ws-ckpt checkpoint" "ws-ckpt checkpoint" "$SKILL"
  tc_assert_contains "skill references ws-ckpt rollback"   "ws-ckpt rollback"   "$SKILL"
  tc_assert_contains "skill references ws-ckpt list"       "ws-ckpt list"       "$SKILL"
fi

# ============================================================
# 3. RPM spec 契约 (09ba005, 7c3be59, 01f801f, 4eccdb2)
# ============================================================
if [ -f "$TC_SPEC_FILE" ]; then
  SPEC="$(cat "$TC_SPEC_FILE")"
  tc_assert_contains "spec: Source1 vendor.tar.gz"    "vendor.tar.gz"                "$SPEC"
  tc_assert_contains "spec: BuildRequires cargo"      "cargo"                        "$SPEC"
  tc_assert_contains "spec: %{_bindir}/ws-ckpt"      '%{_bindir}/ws-ckpt'           "$SPEC"
  tc_assert_not_contains "spec: no /usr/local/bin"    "/usr/local/bin/ws-ckpt"       "$SPEC"
  tc_assert_contains "spec: cargo --offline"          "--offline"                    "$SPEC"
  tc_assert_not_contains "spec: no modprobe btrfs"    "modprobe btrfs"               "$SPEC"
  tc_assert_not_contains "spec: no overlayfs"         "overlayfs"                    "$SPEC"
  tc_assert_contains "spec: config.toml.sample"       "/etc/ws-ckpt/config.toml.sample" "$SPEC"

  if printf '%s' "$SPEC" | grep -qE 'systemctl[[:space:]]+restart[[:space:]]+ws-ckpt'; then
    tc_pass "spec: %post uses systemctl restart"
  else
    tc_fail "spec: %post missing systemctl restart"
  fi
fi

# ============================================================
# 4. Config sample 字段 (d1e9213, dfdcde0, 62b7f3c, f906964)
# ============================================================
if [ -f "$TC_SAMPLE_CFG" ]; then
  CFG="$(cat "$TC_SAMPLE_CFG")"
  tc_assert_contains     "sample: img_size"              "img_size"              "$CFG"
  tc_assert_contains     "sample: img_max_percent"       "img_max_percent"       "$CFG"
  tc_assert_not_contains "sample: no img_min_size_gb"    "img_min_size_gb"       "$CFG"
  tc_assert_not_contains "sample: no img_capacity_pct"   "img_capacity_percent"  "$CFG"
  tc_assert_contains     "sample: auto_cleanup"          "auto_cleanup"          "$CFG"
  tc_assert_contains     "sample: auto_cleanup_keep"     "auto_cleanup_keep"     "$CFG"
  tc_assert_not_contains "sample: no fs_warn_threshold"  "fs_warn_threshold_percent" "$CFG"
  tc_assert_not_contains "sample: no overlayfs"          "overlayfs"             "$CFG"
fi

# ============================================================
# 5. systemd unit (02a113a, dffa3a4)
# ============================================================
SVC=""
for c in "$TC_WSCKPT_SRC/systemd/ws-ckpt.service" "$TC_WSCKPT_SRC/systemd/ws-ckpt.service.in"; do
  [ -f "$c" ] && SVC="$c" && break
done
if [ -n "$SVC" ]; then
  UNIT="$(cat "$SVC")"
  tc_assert_contains "unit: StateDirectory=ws-ckpt"   "StateDirectory=ws-ckpt"   "$UNIT"
  tc_assert_contains "unit: RuntimeDirectory=ws-ckpt" "RuntimeDirectory=ws-ckpt" "$UNIT"
  if printf '%s' "$UNIT" | grep -qE 'ExecReload=.*ws-ckpt[[:space:]]+reload'; then
    tc_pass "unit: ExecReload= ws-ckpt reload"
  else
    tc_fail "unit: ExecReload missing"
  fi
else
  tc_skip "systemd unit checks" "file not found"
fi

# ============================================================
# 6. 源码结构 (77c0e51, dffa3a4, 070be6a, 61d5969, f548458, 0f4dd1f, e927b05)
# ============================================================
COMMON_SRC="$TC_WSCKPT_SRC/crates/common/src"
DAEMON_SRC="$TC_WSCKPT_SRC/crates/daemon/src"
CLI_SRC="$TC_WSCKPT_SRC/crates/cli/src"

tc_assert_file_missing "no bootstrap.rs (refactored to trait)" "$DAEMON_SRC/bootstrap.rs"
tc_assert_file_missing "no overlayfs.rs" "$DAEMON_SRC/backends/overlayfs.rs"

# persist + migration + lockfile + util 模块存在
for mod in persist migration; do
  if [ -f "$COMMON_SRC/${mod}.rs" ] || grep -rq "mod $mod" "$COMMON_SRC" 2>/dev/null; then
    tc_pass "common: ${mod} module"
  else
    tc_fail "common: ${mod} module not found"
  fi
done
for mod in lockfile util; do
  if [ -f "$DAEMON_SRC/${mod}.rs" ] || grep -rq "mod $mod" "$DAEMON_SRC" 2>/dev/null; then
    tc_pass "daemon: ${mod} module"
  else
    tc_fail "daemon: ${mod} module not found"
  fi
done

# bootstrap trait default method
if grep -rEn 'fn bootstrap' "$COMMON_SRC" >/dev/null 2>&1; then
  tc_pass "common: bootstrap trait method"
else
  tc_fail "common: bootstrap trait method not found"
fi

# is_mounted helper
if grep -rEn 'fn is_mounted|async fn is_mounted' "$DAEMON_SRC" >/dev/null 2>&1; then
  tc_pass "daemon: is_mounted helper"
else
  tc_fail "daemon: is_mounted helper not found"
fi

# 常量
if grep -rn 'BTRFS_IMG_PATH' "$COMMON_SRC" | grep -q '/var/lib/ws-ckpt/btrfs-data.img'; then
  tc_pass "BTRFS_IMG_PATH = /var/lib/ws-ckpt/btrfs-data.img"
else
  tc_fail "BTRFS_IMG_PATH wrong or missing"
fi

if grep -rn 'LEGACY_BTRFS_IMG_PATH' "$COMMON_SRC" | grep -q '/data/ws-ckpt/btrfs-data.img'; then
  tc_pass "LEGACY_BTRFS_IMG_PATH = /data/ws-ckpt/btrfs-data.img"
else
  tc_fail "LEGACY_BTRFS_IMG_PATH wrong or missing"
fi

# img_path 不在 common/lib.rs (f548458)
if grep -n 'img_path' "$COMMON_SRC/lib.rs" 2>/dev/null | grep -qv '//'; then
  tc_fail "common/lib.rs still has img_path field"
else
  tc_pass "common/lib.rs: img_path removed from Config/Report"
fi

# HealthAdvisory (0f4dd1f)
if grep -rn 'HealthAdvisory' "$COMMON_SRC" >/dev/null 2>&1; then
  tc_pass "common: HealthAdvisory variant"
else
  tc_fail "common: HealthAdvisory not found"
fi

# ReloadConfig (02a113a)
if grep -rn 'ReloadConfig' "$COMMON_SRC" >/dev/null 2>&1; then
  tc_pass "common: ReloadConfig variant"
else
  tc_fail "common: ReloadConfig not found"
fi

# SIGHUP handler (02a113a)
if grep -rn 'SIGHUP\|SignalKind::hangup' "$DAEMON_SRC" >/dev/null 2>&1; then
  tc_pass "daemon: SIGHUP handler installed"
else
  tc_fail "daemon: SIGHUP handler not found"
fi

# Notify push-based scheduler (dfdcde0)
if grep -rn 'Notify' "$DAEMON_SRC" >/dev/null 2>&1; then
  tc_pass "daemon: scheduler uses Notify"
else
  tc_fail "daemon: scheduler Notify not found"
fi

# CleanupRetention + parse_duration_secs (62b7f3c, 49376a1)
if grep -rn 'CleanupRetention' "$COMMON_SRC" >/dev/null 2>&1; then
  tc_pass "common: CleanupRetention enum"
else
  tc_fail "common: CleanupRetention not found"
fi
if grep -rn 'fn parse_duration_secs' "$COMMON_SRC" >/dev/null 2>&1; then
  tc_pass "common: parse_duration_secs"
else
  tc_fail "common: parse_duration_secs not found"
fi
if grep -rn 'fn validate_file_config' "$COMMON_SRC" >/dev/null 2>&1; then
  tc_pass "common: validate_file_config"
else
  tc_fail "common: validate_file_config not found"
fi

# ensure_btrfs_support (01f801f)
if grep -rn 'ensure_btrfs_support' "$DAEMON_SRC" >/dev/null 2>&1; then
  tc_pass "daemon: ensure_btrfs_support"
else
  tc_fail "daemon: ensure_btrfs_support not found"
fi

# decide_effective_img_path (61d5969)
if grep -rn 'decide_effective_img_path' "$DAEMON_SRC" >/dev/null 2>&1; then
  tc_pass "daemon: decide_effective_img_path"
else
  tc_fail "daemon: decide_effective_img_path not found"
fi

# Version (1eecd08 + later bumps)
# Accept any 0.x line; specific minor is enforced by ckpt-dev prepare flow.
if grep -rEn '^version = "0\.[0-9]+\.' "$TC_WSCKPT_SRC" --include='Cargo.toml' >/dev/null 2>&1; then
  CUR_VER="$(grep -rEh '^version = "0\.[0-9]+\.' "$TC_WSCKPT_SRC" --include='Cargo.toml' | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
  tc_pass "Cargo.toml: version 0.x.y (current: $CUR_VER)"
else
  tc_fail "Cargo.toml: no 0.x version line found"
fi

# ============================================================
# 7. CLI 行为 (需二进制)
# ============================================================
BIN="$(tc_find_wsckpt_bin 2>/dev/null || true)"
if [ -n "$BIN" ]; then
  # 7.1 --help 子命令列表
  HELP="$("$BIN" --help 2>&1 || true)"
  for sub in init checkpoint rollback delete list diff cleanup status config reload; do
    tc_assert_contains "help: $sub" "$sub" "$HELP"
  done

  # 7.2 --version
  VOUT="$("$BIN" --version 2>&1 || true)"
  tc_assert_contains "version starts with 0." "0." "$VOUT"

  # 7.3 config --help flag
  CFG_HELP="$("$BIN" config --help 2>&1 || true)"
  for flag in --img-size --img-max-percent --enable-auto-cleanup --disable-auto-cleanup --auto-cleanup-keep --auto-cleanup-interval; do
    tc_assert_contains "config flag: $flag" "$flag" "$CFG_HELP"
  done

  # 7.4 拒绝旧 flag (使用 tc_run_cli_expect_fail 避免 `|| true; RC=$?` 永远 0 的坑)
  tc_run_cli_expect_fail "rejects --img-min-size-gb"          "$BIN" config --img-min-size-gb 2
  tc_run_cli_expect_fail "rejects --img-capacity-percent"     "$BIN" config --img-capacity-percent 80
  tc_run_cli_expect_fail "rejects --fs-warn-threshold-percent" "$BIN" config --fs-warn-threshold-percent 80

  # 7.5 互斥
  tc_run_cli_expect_fail "enable+disable mutual exclusion"    "$BIN" config --enable-auto-cleanup --disable-auto-cleanup

  # 7.6 非法 duration
  tc_run_cli_expect_fail "rejects --auto-cleanup-keep 30y"    "$BIN" config --auto-cleanup-keep "30y"

  # 7.7 空/根 workspace
  tc_run_cli_expect_fail "init rejects empty workspace"       "$BIN" init -w ""
  tc_run_cli_expect_fail "init rejects / as workspace"        "$BIN" init -w "/"
else
  tc_skip "CLI behavior tests" "no ws-ckpt binary"
fi

# ============================================================
# 8. Daemon 集成 (需 root + btrfs + service)
# ============================================================
if tc_require_root "daemon integration" && tc_require_btrfs "daemon integration" && tc_require_service "daemon integration"; then
  BIN="$(tc_find_wsckpt_bin)"
  # 允许通过环境变量注入 workspace 路径,默认 /tmp,但若 /tmp 不是 btrfs 则 SKIP
  WS_PATH="${TC_WS_PATH:-/tmp/ws-ckpt-qa-$$}"
  if ! tc_require_btrfs_path "daemon integration (workspace fs)" "$WS_PATH"; then
    tc_summary; exit $?
  fi

  # 确保 daemon 运行
  systemctl start ws-ckpt || { tc_fail "cannot start ws-ckpt"; tc_summary; exit 1; }
  sleep 1

  # init
  OUT="$("$BIN" init -w "$WS_PATH" 2>&1)"; RC=$?
  tc_assert_exit "init workspace" "0" "$RC"

  # checkpoint
  OUT="$("$BIN" checkpoint -w "$WS_PATH" -i qa1 -m "qa test" 2>&1)"; RC=$?
  tc_assert_exit "checkpoint qa1" "0" "$RC"

  # 写入变更 + 第二次 checkpoint
  echo "hello" > "$WS_PATH/test.txt"
  OUT="$("$BIN" checkpoint -w "$WS_PATH" -i qa2 -m "second" 2>&1)"; RC=$?
  tc_assert_exit "checkpoint qa2" "0" "$RC"

  # list
  OUT="$("$BIN" list -w "$WS_PATH" 2>&1)"; RC=$?
  tc_assert_exit "list" "0" "$RC"
  tc_assert_contains "list shows qa1" "qa1" "$OUT"
  tc_assert_contains "list shows qa2" "qa2" "$OUT"

  # list --format json (有 jq 则做结构性校验,否则退化为字符串包含)
  JOUT="$("$BIN" list -w "$WS_PATH" --format json 2>&1)"; RC=$?
  tc_assert_exit "list json" "0" "$RC"
  if command -v jq >/dev/null 2>&1; then
    if printf '%s' "$JOUT" | jq -e 'map(select(.id=="qa1" or .name=="qa1")) | length > 0' >/dev/null 2>&1; then
      tc_pass "list json: qa1 present (jq structural)"
    else
      tc_fail "list json: qa1 not found via jq"
    fi
  else
    tc_assert_contains "list json contains qa1 (no jq, string match)" "qa1" "$JOUT"
  fi

  # diff
  OUT="$("$BIN" diff -w "$WS_PATH" -f qa1 -t qa2 2>&1)"; RC=$?
  tc_assert_exit "diff qa1..qa2" "0" "$RC"
  tc_assert_contains "diff shows test.txt" "test.txt" "$OUT"

  # diff nonexistent snapshot
  tc_run_cli_expect_fail "diff rejects unknown snapshot"  "$BIN" diff -w "$WS_PATH" -f nosuch -t qa2

  # rollback
  OUT="$("$BIN" rollback -w "$WS_PATH" -s qa1 2>&1)"; RC=$?
  tc_assert_exit "rollback to qa1" "0" "$RC"
  if [ ! -f "$WS_PATH/test.txt" ]; then
    tc_pass "file removed after rollback"
  else
    tc_fail "file still present after rollback"
  fi

  # status
  OUT="$("$BIN" status -w "$WS_PATH" 2>&1)"; RC=$?
  tc_assert_exit "status" "0" "$RC"

  # config view (no Image path: output)
  OUT="$("$BIN" config 2>&1)"; RC=$?
  tc_assert_exit "config view" "0" "$RC"
  tc_assert_not_contains "config: no Image path:" "Image path:" "$OUT"

  # reload
  OUT="$("$BIN" reload 2>&1)"; RC=$?
  tc_assert_exit "reload" "0" "$RC"

  # SIGHUP no-op
  PID="$(pidof ws-ckpt 2>/dev/null || systemctl show ws-ckpt -p MainPID --value)"
  if [ -n "$PID" ] && [ "$PID" != "0" ]; then
    kill -HUP "$PID" 2>/dev/null
    sleep 1
    if kill -0 "$PID" 2>/dev/null; then
      tc_pass "SIGHUP does not kill daemon"
    else
      tc_fail "daemon died on SIGHUP"
    fi
  fi

  # cleanup
  "$BIN" delete -w "$WS_PATH" --force >/dev/null 2>&1 || true
  rm -rf "$WS_PATH" 2>/dev/null || true
fi

# ============================================================
tc_summary
