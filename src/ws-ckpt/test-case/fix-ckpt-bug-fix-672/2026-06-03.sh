#!/usr/bin/env bash
# 2026-06-03 — fix/ckpt/bug-fix-672 分支测试 (1 领先 commit, snapshot id 校验)
# 覆盖: 42940b2 (checkpoint -i 解析层拒绝 空白/路径分隔符/. .. id, issue#672)
# Section 1 静态断言 Mac/Linux 均可跑; Section 2 实跑二进制(无需 root/btrfs), 无二进制则 SKIP。
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../_lib/common.sh"

tc_log "fix/ckpt/bug-fix-672 — snapshot id 解析层校验 (2026-06-03)"

if ! tc_require_branch "fix/ckpt/bug-fix-672 静态用例" "fix/ckpt/bug-fix-672"; then
  tc_summary; exit $?
fi

CLI_MAIN="$TC_WSCKPT_SRC/crates/cli/src/main.rs"

# ============================================================
# 1. 解析层校验存在性 (静态, 42940b2)
# ============================================================
if [ -f "$CLI_MAIN" ]; then
  CM="$(cat "$CLI_MAIN")"
  tc_assert_contains "1.1 main.rs: snapshot_id_value_parser fn" "fn snapshot_id_value_parser" "$CM"
  tc_assert_contains "1.2 main.rs: 拒绝空白 id" "must not be empty or whitespace" "$CM"
  tc_assert_contains "1.3 main.rs: 拒绝路径分隔符" "must not contain path separators" "$CM"
  tc_assert_contains "1.4 main.rs: checkpoint id 挂 value_parser" "value_parser = snapshot_id_value_parser" "$CM"
  tc_assert_contains "1.5 main.rs: 含 . / .. 判定" 's == "." || s == ".."' "$CM"
else
  tc_skip "1.1-1.5 main.rs tests" "file not found: $CLI_MAIN"
fi

# ============================================================
# 2. CLI 行为断言 (实跑二进制, 无需 root/btrfs)
# ============================================================
if tc_require_bin "2.x snapshot id CLI 校验"; then
  BIN="$(tc_find_wsckpt_bin)"

  # 2.1-2.5: 非法 id 应让 checkpoint 以非零退出失败 (解析层 ValueValidation)
  tc_run_cli_expect_fail "2.1 空 id 被拒"        "$BIN" checkpoint -w /ws -i ""
  tc_run_cli_expect_fail "2.2 空白 id 被拒"      "$BIN" checkpoint -w /ws -i "   "
  tc_run_cli_expect_fail "2.3 含 / 被拒"         "$BIN" checkpoint -w /ws -i "foo/bar"
  tc_run_cli_expect_fail "2.4 .. 被拒"           "$BIN" checkpoint -w /ws -i ".."
  tc_run_cli_expect_fail "2.5 含 \\ 被拒"        "$BIN" checkpoint -w /ws -i 'a\b'

  # 2.6: 合法 id 不应被解析层拒绝 (可能因无 daemon 在后续阶段失败, 但不应出现解析拒绝文案)
  OUT="$("$BIN" checkpoint -w /ws -i "snap-1" 2>&1)"; RC=$?
  if printf '%s' "$OUT" | grep -q "snapshot id must not"; then
    tc_fail "2.6 合法 id snap-1 不应被解析层拒绝 (rc=$RC, out=$OUT)"
  else
    tc_pass "2.6 合法 id snap-1 未被解析层拒绝"
  fi
fi

# ============================================================
tc_summary
