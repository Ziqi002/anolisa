#!/usr/bin/env bash
# ws-ckpt QA 公共辅助库
# 目标执行环境: Linux (btrfs + root)
# 本文件 source 引入，不直接执行。
set -u

# ---- 颜色输出 ----
if [ -t 1 ]; then
  TC_RED=$'\033[31m'; TC_GRN=$'\033[32m'; TC_YEL=$'\033[33m'; TC_DIM=$'\033[2m'; TC_END=$'\033[0m'
else
  TC_RED=""; TC_GRN=""; TC_YEL=""; TC_DIM=""; TC_END=""
fi

TC_PASS=0
TC_FAIL=0
TC_SKIP=0
TC_FAIL_NAMES=""

tc_log()  { printf '%s[INFO]%s %s\n'  "$TC_DIM" "$TC_END" "$*"; }
tc_warn() { printf '%s[WARN]%s %s\n'  "$TC_YEL" "$TC_END" "$*" >&2; }
tc_err()  { printf '%s[ERR ]%s %s\n'  "$TC_RED" "$TC_END" "$*" >&2; }

tc_pass() {
  TC_PASS=$((TC_PASS+1))
  printf '%s[PASS]%s %s\n' "$TC_GRN" "$TC_END" "$1"
}
tc_fail() {
  TC_FAIL=$((TC_FAIL+1))
  TC_FAIL_NAMES="${TC_FAIL_NAMES}
  - $1"
  printf '%s[FAIL]%s %s\n' "$TC_RED" "$TC_END" "$1" >&2
}
tc_skip() {
  TC_SKIP=$((TC_SKIP+1))
  printf '%s[SKIP]%s %s (%s)\n' "$TC_YEL" "$TC_END" "$1" "${2:-no reason}"
}

# ---- 断言函数 ----

# tc_assert_eq "name" "expected" "actual"
tc_assert_eq() {
  if [ "$2" = "$3" ]; then tc_pass "$1"; else
    tc_fail "$1"; printf '   expected: %q\n   actual:   %q\n' "$2" "$3" >&2
  fi
}

# tc_assert_contains "name" "needle" "haystack"
tc_assert_contains() {
  case "$3" in *"$2"*) tc_pass "$1" ;; *)
    tc_fail "$1"; printf '   needle:   %q\n' "$2" >&2 ;; esac
}

# tc_assert_not_contains "name" "needle" "haystack"
tc_assert_not_contains() {
  case "$3" in *"$2"*)
    tc_fail "$1"; printf '   forbidden: %q\n' "$2" >&2 ;; *) tc_pass "$1" ;; esac
}

# tc_assert_file_exists "name" "path"
tc_assert_file_exists() {
  if [ -e "$2" ]; then tc_pass "$1"; else tc_fail "$1 (missing: $2)"; fi
}

# tc_assert_file_missing "name" "path"
tc_assert_file_missing() {
  if [ ! -e "$2" ]; then tc_pass "$1"; else tc_fail "$1 (should not exist: $2)"; fi
}

# tc_assert_exit "name" "expected_code" "actual_code"
tc_assert_exit() {
  if [ "$2" = "$3" ]; then tc_pass "$1"; else
    tc_fail "$1"; printf '   expected exit: %s  actual: %s\n' "$2" "$3" >&2
  fi
}

# tc_assert_nonzero_exit "name" "actual_code"
tc_assert_nonzero_exit() {
  if [ "$2" != "0" ]; then
    tc_pass "$1"
  else
    tc_fail "$1"
    printf '   expected: non-zero  actual: %s\n' "$2" >&2
  fi
}

# tc_run_cli_expect_fail "name" cmd [args...]
# Run a command, capture its exit code without the `|| true; RC=$?` pitfall
# (which silently swallows the real RC and sets it to 0), and assert non-zero.
tc_run_cli_expect_fail() {
  local name="$1"; shift
  local rc=0
  "$@" >/dev/null 2>&1 || rc=$?
  tc_assert_nonzero_exit "$name" "$rc"
}

# ---- 平台检测 (布尔，不产生 SKIP) ----
tc_is_linux() { [ "$(uname -s)" = "Linux" ]; }
tc_is_mac()   { [ "$(uname -s)" = "Darwin" ]; }
tc_is_root()  { [ "$(id -u)" = "0" ]; }
tc_has_btrfs() { grep -qw btrfs /proc/filesystems 2>/dev/null; }

# ---- 环境前置检查 (带 SKIP) ----
tc_require_linux() {
  if ! tc_is_linux; then
    tc_skip "$1" "requires Linux"; return 1
  fi
  return 0
}

tc_require_root() {
  if ! tc_is_root; then
    tc_skip "$1" "requires root"; return 1
  fi
  return 0
}

# tc_require_branch "test-label" "branch-name"
# PASS if:
#   - HEAD is on the branch, OR
#   - branch ref exists and is an ancestor of HEAD (merged), OR
#   - branch ref no longer exists anywhere (local + origin/) — treat as "已合并并删除分支",
#     仍然在 main/release 上执行回归断言,避免删了分支就漏测。
# SKIP only when branch still exists but HEAD diverges from it.
tc_require_branch() {
  local label="$1" branch="$2"
  local cur
  cur="$(git -C "$TC_REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
  if [ "$cur" = "$branch" ]; then return 0; fi
  local local_exists=0 remote_exists=0
  git -C "$TC_REPO_ROOT" show-ref --verify --quiet "refs/heads/$branch"          && local_exists=1
  git -C "$TC_REPO_ROOT" show-ref --verify --quiet "refs/remotes/origin/$branch" && remote_exists=1
  if [ "$local_exists" = "1" ] && git -C "$TC_REPO_ROOT" merge-base --is-ancestor "$branch" HEAD 2>/dev/null; then
    return 0
  fi
  if [ "$remote_exists" = "1" ] && git -C "$TC_REPO_ROOT" merge-base --is-ancestor "origin/$branch" HEAD 2>/dev/null; then
    return 0
  fi
  if [ "$local_exists" = "0" ] && [ "$remote_exists" = "0" ]; then
    tc_log "branch $branch absent (assumed merged + deleted); running regression on $cur"
    return 0
  fi
  tc_skip "$label" "not on branch $branch (current: $cur)"; return 1
}

tc_require_btrfs() {
  if ! grep -qw btrfs /proc/filesystems 2>/dev/null; then
    tc_skip "$1" "kernel lacks btrfs"; return 1
  fi
  return 0
}

# tc_require_btrfs_path "label" "/some/path"
# SKIP if the filesystem hosting <path>'s parent dir is not btrfs.
# Needed because /tmp is usually tmpfs and ws-ckpt init refuses non-btrfs paths.
tc_require_btrfs_path() {
  local label="$1" path="$2"
  local probe="$path"
  while [ -n "$probe" ] && [ ! -e "$probe" ]; do
    probe="$(dirname "$probe")"
    [ "$probe" = "/" ] && break
  done
  local fstype=""
  if command -v findmnt >/dev/null 2>&1; then
    fstype="$(findmnt -no FSTYPE -T "$probe" 2>/dev/null || true)"
  fi
  if [ "$fstype" = "btrfs" ]; then return 0; fi
  tc_skip "$label" "path $path not on btrfs (fstype=${fstype:-unknown}); set TC_WS_PATH to a btrfs dir"
  return 1
}

tc_require_service() {
  if ! systemctl list-unit-files 2>/dev/null | grep -q "ws-ckpt"; then
    tc_skip "$1" "ws-ckpt.service not installed"; return 1
  fi
  return 0
}

tc_require_bin() {
  if ! tc_find_wsckpt_bin >/dev/null 2>&1; then
    tc_skip "$1" "ws-ckpt binary not found"; return 1
  fi
  return 0
}

# ---- 路径常量 ----
# _lib 位于: <anolisa>/src/ws-ckpt/test-case/_lib
TC_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TC_REPO_ROOT="$(cd "$TC_LIB_DIR/../../../.." && pwd)"   # .../anolisa
TC_WSCKPT_DIR="$TC_REPO_ROOT/src/ws-ckpt"               # .../anolisa/src/ws-ckpt
TC_WSCKPT_SRC="$TC_WSCKPT_DIR/src"                       # Cargo workspace root

TC_SKILL_DIR="$TC_WSCKPT_SRC/skills/ws-ckpt"
TC_OPENCLAW_PLUGIN_DIR="$TC_WSCKPT_SRC/plugins/openclaw"
TC_SPEC_FILE="$TC_WSCKPT_DIR/ws-ckpt.spec.in"
TC_SAMPLE_CFG="$TC_WSCKPT_SRC/config.toml.sample"

# 定位 ws-ckpt 二进制
tc_find_wsckpt_bin() {
  if command -v ws-ckpt >/dev/null 2>&1; then
    command -v ws-ckpt; return 0
  fi
  for c in "$TC_WSCKPT_SRC/target/release/ws-ckpt" "$TC_WSCKPT_SRC/target/debug/ws-ckpt"; do
    if [ -x "$c" ]; then echo "$c"; return 0; fi
  done
  return 1
}

# ---- 汇总 ----
tc_summary() {
  echo
  echo "=================================================="
  printf ' passed: %s  failed: %s  skipped: %s\n' "$TC_PASS" "$TC_FAIL" "$TC_SKIP"
  if [ "$TC_FAIL" -gt 0 ]; then
    printf '%sFailures:%s%s\n' "$TC_RED" "$TC_END" "$TC_FAIL_NAMES"
    return 1
  fi
  return 0
}

# run_all.sh 使用: 按文件名排序执行该目录下所有日期命名的 .sh
# 通过解析每个子脚本的 summary 行,把 pass/fail/skip 跨脚本累加并打印聚合汇总。
tc_run_all_in_dir() {
  local dir="${1:?}"
  local rc=0
  local agg_pass=0 agg_fail=0 agg_skip=0
  local tmp; tmp="$(mktemp -t wsckpt-qa-runall-XXXXXX.log)"
  shopt -s nullglob
  for f in "$dir"/[0-9]*.sh; do
    echo
    echo "=================================================="
    echo "RUN: $(basename "$f")"
    echo "=================================================="
    # tee 会吞掉左侧退出码,改用 PIPESTATUS 取真实 bash 返回值
    bash "$f" 2>&1 | tee "$tmp"
    [ "${PIPESTATUS[0]}" -eq 0 ] || rc=1
    # summary 形如: " passed: 12  failed: 0  skipped: 2"
    local line p ff s
    line="$(grep -E '^[[:space:]]*passed: [0-9]+[[:space:]]+failed: [0-9]+[[:space:]]+skipped: [0-9]+' "$tmp" | tail -1)"
    if [ -n "$line" ]; then
      p="$(printf '%s' "$line" | sed -nE 's/.*passed: ([0-9]+).*/\1/p')"
      ff="$(printf '%s' "$line" | sed -nE 's/.*failed: ([0-9]+).*/\1/p')"
      s="$(printf '%s' "$line" | sed -nE 's/.*skipped: ([0-9]+).*/\1/p')"
      agg_pass=$((agg_pass + ${p:-0}))
      agg_fail=$((agg_fail + ${ff:-0}))
      agg_skip=$((agg_skip + ${s:-0}))
    fi
  done
  shopt -u nullglob
  rm -f "$tmp"
  echo
  echo "=================================================="
  printf ' AGGREGATE  passed: %s  failed: %s  skipped: %s\n' "$agg_pass" "$agg_fail" "$agg_skip"
  echo "=================================================="
  [ "$agg_fail" -gt 0 ] && rc=1
  return $rc
}
