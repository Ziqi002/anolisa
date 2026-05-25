#!/usr/bin/env bash
# run_all.sh — feat/ckpt/temp 分支全量测试入口
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../_lib/common.sh"
tc_log "Running: feat/ckpt/temp"
tc_run_all_in_dir "$HERE"
exit $?
