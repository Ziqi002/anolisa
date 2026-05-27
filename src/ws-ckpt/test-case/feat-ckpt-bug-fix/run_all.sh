#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../_lib/common.sh"
tc_log "Running: feat-ckpt-bug-fix"
tc_run_all_in_dir "$HERE"
exit $?
