#!/usr/bin/env bash
# Key-free. Regression test for PR #6: after a fresh install seeds only
# globalOverride, every later settings write was refused as a "stale
# snapshot" because the old guard guessed the entry was established from
# globalOverride alone. Flips two settings through wpal's own IPC verbs
# (same Panel functions the toggles call) and asserts both land in
# shell.json.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

run_settings_write() {
  harness_setup

  local seeded
  seeded=$(harness_wait_seed)
  if [[ -z "$seeded" ]]; then
    echo "FAIL settings-write: fresh-install seed never landed -- see $HYPR_LOG" >&2
    return 1
  fi

  harness_ipc setEnabled true >/dev/null
  harness_ipc setAutoLaunch false >/dev/null

  local enabled="" autolaunch=""
  for _ in $(seq 1 25); do
    enabled=$(harness_entry_key enabled)
    autolaunch=$(harness_entry_key autoLaunchEnabled)
    [[ "$enabled" == "true" && "$autolaunch" == "false" ]] && break
    sleep 0.2
  done

  if [[ "$enabled" != "true" || "$autolaunch" != "false" ]]; then
    echo "FAIL settings-write: writes after seed did not persist (enabled=$enabled autoLaunchEnabled=$autolaunch)" >&2
    harness_log_grep "refused a settings write" >&2
    return 1
  fi
  if [[ -n "$(harness_log_grep 'refused a settings write')" ]]; then
    echo "FAIL settings-write: guard logged a refusal on a fresh install" >&2
    return 1
  fi
  echo "PASS settings-write: enabled=true autoLaunchEnabled=false persisted after seed"
}
