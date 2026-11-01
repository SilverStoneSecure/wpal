#!/usr/bin/env bash
# Entry point for wpal's click-through test suite.
# Usage: tests/run.sh [all|keyed|everything|<scenario-name>]
# No args = all key-free scenarios. Keyed scenarios need
# ss-onboard-remote-screen-control run on this machine (ydotool calibration).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

source lib/harness.sh

# Key-free scenarios drive wpal through its IPC verbs and read state back
# from shell.json / hyprctl only -- safe to run while someone is using the
# desktop. Keyed scenarios fake keypresses with ydotool, which land in
# whatever window has focus on the REAL session: only run those when nobody
# is at the keyboard. `all` = key-free only; `keyed` / `everything` opt in.
KEYFREE_SCENARIOS=(fresh-install replacement-bar settings-write pads pads-ui)
KEYED_SCENARIOS=(escape-cascade)
TARGET="${1:-all}"

case "$TARGET" in
  all)        SCENARIOS=("${KEYFREE_SCENARIOS[@]}") ;;
  keyed)      SCENARIOS=("${KEYED_SCENARIOS[@]}") ;;
  everything) SCENARIOS=("${KEYFREE_SCENARIOS[@]}" "${KEYED_SCENARIOS[@]}") ;;
  *)          SCENARIOS=("$TARGET") ;;
esac

for s in "${SCENARIOS[@]}"; do
  for k in "${KEYED_SCENARIOS[@]}"; do
    if [[ "$s" == "$k" ]]; then
      harness_load_calibration
      break 2
    fi
  done
done

run_one() {
  local name=$1
  source "scenarios/$name.sh"
  echo "--- running $name ---"
  local fn="run_${name//-/_}"
  trap harness_teardown EXIT
  if "$fn"; then
    trap - EXIT
    harness_teardown
    return 0
  else
    trap - EXIT
    harness_teardown
    return 1
  fi
}

failures=0
for s in "${SCENARIOS[@]}"; do
  run_one "$s" || failures=$((failures + 1))
done

echo "---"
if [[ $failures -eq 0 ]]; then
  echo "all scenarios passed"
else
  echo "$failures scenario(s) failed"
fi
exit $failures
