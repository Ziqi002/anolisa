#!/usr/bin/env bash
# 2026-06-11 — feat/ckpt/cron-ckpt 增量测试
# 主体: 按工作区维度的 cron 定时快照 (hermes Python + openclaw TypeScript 双实现)
# 领先 commit: 3acc1cf feat(ckpt): add cron-based scheduled checkpoint snapshots
# Section 1-5 为静态源码契约断言, Mac/Linux 均可跑;
# Section 6 (python3) / Section 7 (node) 为纯函数动态行为验证, 缺运行时则 SKIP。
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../_lib/common.sh"

tc_log "feat/ckpt/cron-ckpt — cron scheduled checkpoint (2026-06-11)"

# 分支守卫: 仅在含本特性源码的分支(cron 分支或已合并)上跑; 否则整体 SKIP。
if ! tc_require_branch "cron 静态用例(2026-06-11)" "feat/ckpt/cron-ckpt"; then
  tc_summary; exit $?
fi

HERMES_DIR="$TC_WSCKPT_SRC/plugins/hermes"
HERMES_CRON="$HERMES_DIR/cron.py"
HERMES_CONFIG="$HERMES_DIR/config.py"
HERMES_TOOLS="$HERMES_DIR/tools.py"
OC_DIR="$TC_OPENCLAW_PLUGIN_DIR"
OC_CRON="$OC_DIR/src/cron.ts"
OC_COMMANDS="$OC_DIR/src/commands.ts"
OC_PLUGIN_JSON="$OC_DIR/openclaw.plugin.json"

# ============================================================
# 1. hermes cron.py 静态契约
# ============================================================
if [ -f "$HERMES_CRON" ]; then
  C="$(cat "$HERMES_CRON")"
  tc_assert_contains "1.1 validate_cron_expr 导出"      "def validate_cron_expr"      "$C"
  tc_assert_contains "1.2 parse_schedules_update 导出"  "def parse_schedules_update"  "$C"
  tc_assert_contains "1.3 class CrontabManager"         "class CrontabManager"        "$C"
  tc_assert_contains "1.4 5 字段 cron 正则"             '^\S+\s+\S+\s+\S+\s+\S+\s+\S+$' "$C"
  tc_assert_contains "1.5 shell 单引号转义"             "replace(\"'\", \"'\\\\''\")"  "$C"
  tc_assert_contains "1.6 checkpoint 行模板 -i cron-"   '-i "cron-'                   "$C"
  tc_assert_contains "1.7 metadata auto/cron 标记"      '\"type\":\"cron\"'           "$C"
  tc_assert_contains "1.8 flock 互斥导入"               "import fcntl"                "$C"
  tc_assert_contains "1.9 LOCK_EX 排它锁"               "fcntl.LOCK_EX"               "$C"
  tc_assert_contains "1.10 sync_with_retry 方法"        "def sync_with_retry"         "$C"
  tc_assert_contains "1.11 migrate 方法(ws 切换)"       "def migrate"                 "$C"
  tc_assert_contains "1.12 list_installed 方法"         "def list_installed"          "$C"
  tc_assert_contains "1.13 no crontab for 首次处理"     "no crontab for"              "$C"
else
  tc_skip "1.x hermes cron.py 契约" "file not found: $HERMES_CRON"
fi

# ============================================================
# 2. hermes config.py — cron_schedules 字段
# ============================================================
if [ -f "$HERMES_CONFIG" ]; then
  C="$(cat "$HERMES_CONFIG")"
  tc_assert_contains "2.1 cron_schedules 字段"          "cron_schedules"              "$C"
  tc_assert_contains "2.2 类型 Dict[str, List[str]]"    "Dict[str, List[str]]"        "$C"
  tc_assert_contains "2.3 加载时校验过滤非法表达式"     "validate_cron_expr"          "$C"
  tc_assert_contains "2.4 非法表达式告警打印"           "Ignoring invalid cron"       "$C"
else
  tc_skip "2.x hermes config.py" "file not found: $HERMES_CONFIG"
fi

# ============================================================
# 3. openclaw cron.ts 静态契约 (与 hermes 镜像)
# ============================================================
if [ -f "$OC_CRON" ]; then
  C="$(cat "$OC_CRON")"
  tc_assert_contains "3.1 validateCronExpr 导出"        "export function validateCronExpr" "$C"
  tc_assert_contains "3.2 parseSchedulesUpdate 导出"    "export function parseSchedulesUpdate" "$C"
  tc_assert_contains "3.3 class CrontabManager"         "export class CrontabManager" "$C"
  tc_assert_contains "3.4 5 字段 cron 正则"             'CRON_RE'                     "$C"
  tc_assert_contains "3.5 shellQuote 转义"              "function shellQuote"         "$C"
  tc_assert_contains "3.6 buildCronLine -i cron-"       'cron-$(date +\\%s)'          "$C"
  tc_assert_contains "3.7 metadata auto/cron 标记"      '"auto":true,"type":"cron"'   "$C"
  tc_assert_contains "3.8 withLock 互斥(mkdir 锁)"      "mkdirSync(LOCK_DIR)"         "$C"
  tc_assert_contains "3.9 syncWithRetry 方法"           "syncWithRetry"               "$C"
  tc_assert_contains "3.10 migrate 方法(ws 切换)"       "static async migrate"        "$C"
  tc_assert_contains "3.11 listInstalled 方法"          "listInstalled"               "$C"
else
  tc_skip "3.x openclaw cron.ts 契约" "file not found: $OC_CRON"
fi

# ============================================================
# 4. openclaw commands.ts — runCrontab
# ============================================================
if [ -f "$OC_COMMANDS" ]; then
  C="$(cat "$OC_COMMANDS")"
  tc_assert_contains "4.1 runCrontab 导出"              "export async function runCrontab" "$C"
  tc_assert_contains "4.2 input 走临时文件"             "mkdtempSync"                 "$C"
  tc_assert_contains "4.3 crontab 文件参数执行"         'execFileAsync("crontab"'     "$C"
else
  tc_skip "4.x openclaw commands.ts" "file not found: $OC_COMMANDS"
fi

# ============================================================
# 5. manifest / 配置 schema
# ============================================================
if [ -f "$OC_PLUGIN_JSON" ]; then
  J="$(cat "$OC_PLUGIN_JSON")"
  tc_assert_contains "5.1 plugin.json cronSchedules 键"  '"cronSchedules"'            "$J"
  tc_assert_contains "5.2 cronSchedules 为 object"       '"type": "object"'           "$J"
  tc_assert_contains "5.3 additionalProperties array"    '"additionalProperties"'     "$J"
else
  tc_skip "5.1 openclaw.plugin.json" "file not found: $OC_PLUGIN_JSON"
fi
if [ -f "$HERMES_TOOLS" ]; then
  T="$(cat "$HERMES_TOOLS")"
  tc_assert_contains "5.4 hermes tools 暴露 cronSchedules" "cronSchedules"            "$T"
else
  tc_skip "5.4 hermes tools.py" "file not found: $HERMES_TOOLS"
fi

# ============================================================
# 6. 动态: hermes cron 纯函数 (需 python3)
# ============================================================
if command -v python3 >/dev/null 2>&1 && [ -f "$HERMES_CRON" ]; then
  PYOUT="$(python3 - "$HERMES_DIR" <<'PYEOF'
import sys, importlib.util, os
d = sys.argv[1]
spec = importlib.util.spec_from_file_location("ws_cron", os.path.join(d, "cron.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

def check(name, cond):
    print(f"{'OK' if cond else 'NO'} {name}")

# validate_cron_expr
check("valid_5field", m.validate_cron_expr("0 * * * *") is True)
check("invalid_4field", m.validate_cron_expr("0 * * *") is False)
check("invalid_empty", m.validate_cron_expr("") is False)

# parse_schedules_update
r, e = m.parse_schedules_update('add "0 * * * *"', [])
check("add_ok", e is None and r == ["0 * * * *"])
r, e = m.parse_schedules_update('add "0 * * * *"', ["0 * * * *"])
check("add_dedup", e is None and r == ["0 * * * *"])
r, e = m.parse_schedules_update('add "bad"', [])
check("add_invalid_err", r is None and e is not None)
r, e = m.parse_schedules_update('remove "0 * * * *"', ["0 * * * *"])
check("remove_ok", e is None and r == [])
r, e = m.parse_schedules_update('remove "x x x x x"', [])
check("remove_missing_err", r is None and e is not None)
r, e = m.parse_schedules_update('set ["0 0 * * *"]', ["0 * * * *"])
check("set_replace", e is None and r == ["0 0 * * *"])
r, e = m.parse_schedules_update('set notjson', [])
check("set_notarray_err", r is None and e is not None)
r, e = m.parse_schedules_update('bogus "x"', [])
check("unknown_action_err", r is None and e is not None)
PYEOF
)"
  while IFS= read -r line; do
    st="${line%% *}"; name="${line#* }"
    if [ "$st" = "OK" ]; then tc_pass "6.$name"; else tc_fail "6.$name"; fi
  done <<< "$PYOUT"
else
  tc_skip "6.x hermes cron 动态" "python3 不可用或 cron.py 缺失"
fi

# ============================================================
# 7. 动态: openclaw cron 纯函数 (需 node + 已编译 dist)
# ============================================================
OC_CRON_JS="$OC_DIR/dist/src/cron.js"
if command -v node >/dev/null 2>&1 && [ -f "$OC_CRON_JS" ]; then
  NODEOUT="$(node - "$OC_CRON_JS" <<'NODEEOF'
(async () => {
  const { pathToFileURL } = await import("url");
  const p = pathToFileURL(process.argv[2]).href;
  const m = await import(p);
  const check = (name, cond) => console.log(`${cond ? "OK" : "NO"} ${name}`);
  check("valid_5field", m.validateCronExpr("0 * * * *") === true);
  check("invalid_4field", m.validateCronExpr("0 * * *") === false);
  let r = m.parseSchedulesUpdate('add "0 * * * *"', []);
  check("add_ok", !r.error && JSON.stringify(r.schedules) === JSON.stringify(["0 * * * *"]));
  r = m.parseSchedulesUpdate('add "bad"', []);
  check("add_invalid_err", !!r.error);
  r = m.parseSchedulesUpdate('remove "0 * * * *"', ["0 * * * *"]);
  check("remove_ok", !r.error && JSON.stringify(r.schedules) === "[]");
  r = m.parseSchedulesUpdate('set ["0 0 * * *"]', ["0 * * * *"]);
  check("set_replace", !r.error && JSON.stringify(r.schedules) === JSON.stringify(["0 0 * * *"]));
  r = m.parseSchedulesUpdate('set notjson', []);
  check("set_notarray_err", !!r.error);
  r = m.parseSchedulesUpdate('bogus "x"', []);
  check("unknown_action_err", !!r.error);
})().catch(e => { console.error(e); process.exit(1); });
NODEEOF
)"
  if [ -n "$NODEOUT" ]; then
    while IFS= read -r line; do
      st="${line%% *}"; name="${line#* }"
      if [ "$st" = "OK" ]; then tc_pass "7.$name"; else tc_fail "7.$name"; fi
    done <<< "$NODEOUT"
  else
    tc_skip "7.x openclaw cron 动态" "node 执行无输出 (可能 dist 未编译)"
  fi
else
  tc_skip "7.x openclaw cron 动态" "node 不可用或 dist/src/cron.js 未编译"
fi

tc_summary
