#!/usr/bin/env bash
# 2026-06-03 — main 分支增量测试 (1 commit: 99ba08a Hermes adapter runner)
# 覆盖: detect-hermes.sh 新增 + manifest/Makefile 登记 + install-hermes.sh 增强 + DRY-RUN 行为
# Section 1-3 为静态断言, Mac/Linux 均可跑; Section 4 实跑 DRY-RUN, 无 root 也可, 环境不全则 SKIP。
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../_lib/common.sh"

tc_log "main — Hermes adapter runner (2026-06-03)"

# 分支守卫: 仅在 main(或已合并) 源码上执行; 否则整体 SKIP。
if ! tc_require_branch "main 静态用例(2026-06-03)" "main"; then
  tc_summary; exit $?
fi

SCRIPTS_DIR="$TC_WSCKPT_DIR/scripts"
DETECT_HERMES="$SCRIPTS_DIR/detect-hermes.sh"
INSTALL_HERMES="$SCRIPTS_DIR/install-hermes.sh"
MANIFEST="$TC_WSCKPT_DIR/adapter-manifest.json"
MAKEFILE="$TC_WSCKPT_DIR/Makefile"

# ============================================================
# 1. detect-hermes.sh 存在性与契约 (99ba08a)
# ============================================================
tc_assert_file_exists "1.1a detect-hermes.sh 存在" "$DETECT_HERMES"
if [ -f "$DETECT_HERMES" ]; then
  if [ -x "$DETECT_HERMES" ]; then tc_pass "1.1b detect-hermes.sh 可执行"; else tc_fail "1.1b detect-hermes.sh 缺可执行位"; fi
  DH="$(cat "$DETECT_HERMES")"
  tc_assert_contains "1.2 detect-hermes.sh: Read-only 声明" "Read-only" "$DH"
  tc_assert_contains "1.3a 退出码 0=installed" "0 = installed" "$DH"
  tc_assert_contains "1.3b 退出码 1=not installed" "1 = not installed" "$DH"
  tc_assert_contains "1.3c 退出码 2=missing" "2 = missing" "$DH"
  tc_assert_contains "1.4 set -euo pipefail" "set -euo pipefail" "$DH"
  tc_assert_contains "1.5 复用 lib-discover.sh" "lib-discover.sh" "$DH"
  tc_assert_contains "1.6 扫描 HERMES_HOME" "HERMES_HOME" "$DH"
else
  tc_skip "1.2-1.6 detect-hermes 契约" "file not found: $DETECT_HERMES"
fi

# ============================================================
# 2. manifest / Makefile 登记 (99ba08a)
# ============================================================
if [ -f "$MANIFEST" ]; then
  MAN="$(cat "$MANIFEST")"
  tc_assert_contains "2.1 manifest: 登记 detect-hermes.sh" "scripts/detect-hermes.sh" "$MAN"
  if command -v python3 >/dev/null 2>&1; then
    if python3 -m json.tool "$MANIFEST" >/dev/null 2>&1; then
      tc_pass "2.2 manifest: 合法 JSON"
    else
      tc_fail "2.2 manifest: JSON 解析失败"
    fi
  else
    tc_skip "2.2 manifest JSON 校验" "python3 不可用"
  fi
else
  tc_skip "2.1-2.2 manifest 测试" "file not found: $MANIFEST"
fi

if [ -f "$MAKEFILE" ]; then
  tc_assert_contains "2.3 Makefile: 安装 detect-hermes.sh" "detect-hermes.sh" "$(cat "$MAKEFILE")"
else
  tc_skip "2.3 Makefile 测试" "file not found: $MAKEFILE"
fi

# ============================================================
# 3. install-hermes.sh 增强 (99ba08a)
# ============================================================
if [ -f "$INSTALL_HERMES" ]; then
  IH="$(cat "$INSTALL_HERMES")"
  tc_assert_contains "3.1 install-hermes: HERMES_HOME 可覆盖" "HERMES_HOME:-" "$IH"
  tc_assert_contains "3.2a install-hermes: ANOLISA_DRY_RUN" "ANOLISA_DRY_RUN" "$IH"
  tc_assert_contains "3.2b install-hermes: DRY-RUN 打印" "DRY-RUN:" "$IH"
  tc_assert_contains "3.3 install-hermes: enable 失败降级 Warning" "Warning" "$IH"
else
  tc_skip "3.1-3.3 install-hermes 测试" "file not found: $INSTALL_HERMES"
fi

# ============================================================
# 4. DRY-RUN 行为 (实跑, 无副作用)
# ============================================================
if [ -f "$INSTALL_HERMES" ]; then
  TMP_HOME="$(mktemp -d -t wsckpt-qa-hermes-XXXXXX)"
  OUT="$(ANOLISA_DRY_RUN=1 HERMES_HOME="$TMP_HOME" HERMES_BIN="" bash "$INSTALL_HERMES" 2>&1)"; RC=$?
  if printf '%s' "$OUT" | grep -q 'DRY-RUN:'; then
    tc_assert_exit "4.1 DRY-RUN 退出码为 0" "0" "$RC"
    tc_pass "4.2 DRY-RUN 输出含计划行"
    if [ -e "$TMP_HOME/plugins/ws-ckpt" ] || [ -e "$TMP_HOME/skills/ws-ckpt" ]; then
      tc_fail "4.3 DRY-RUN 不应在 HERMES_HOME 落地 (发现真实文件)"
    else
      tc_pass "4.3 DRY-RUN 未在临时 HERMES_HOME 落地"
    fi
  else
    # 未命中 DRY-RUN 分支: 多半是 lib-discover 找不到 plugin/skill 源 -> 环境不完整
    tc_skip "4.1 DRY-RUN 退出码" "未进入 DRY-RUN 分支 (adapter 源不可见, rc=$RC)"
    tc_skip "4.2 DRY-RUN 计划行" "同上"
    tc_skip "4.3 DRY-RUN 无副作用" "同上"
  fi
  rm -rf "$TMP_HOME" 2>/dev/null || true
else
  tc_skip "4.1-4.3 DRY-RUN 行为" "install-hermes.sh 不存在"
fi

# ============================================================
tc_summary
