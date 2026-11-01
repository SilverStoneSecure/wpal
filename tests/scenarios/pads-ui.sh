#!/usr/bin/env bash
# Key-free. Screenshots the panel with the Scratchpads row and a pad's editor,
# and checks the editor's slide toggle path (updatePad via IPC) round-trips.
# Screenshots land in tests/screenshots/ for a look, not pixel asserts.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

run_pads_ui() {
  harness_setup
  [[ -n $(harness_wait_seed) ]] || { echo "FAIL pads-ui: no seed" >&2; return 1; }
  harness_ipc setEnabled true >/dev/null
  harness_ipc setPad W '{"panes":[{"appId":"foot","args":""},{"appId":"foot","args":""}]}' >/dev/null
  sleep 1
  harness_ipc open >/dev/null; sleep 1.5
  harness_screenshot "pads-ui-panel"
  [[ $(harness_ipc openEditor 102) == true ]] || { echo "FAIL pads-ui: openEditor 102" >&2; return 1; }
  sleep 1.5
  harness_screenshot "pads-ui-editor-w"
  harness_ipc openEditor 101 >/dev/null; sleep 1.5
  harness_screenshot "pads-ui-editor-s"
  harness_ipc setPad S '{"slideFrom":"top"}' >/dev/null; sleep 1.5
  harness_screenshot "pads-ui-editor-s-flipped"
  [[ $(harness_entry_key pads | jq -r '.S.slideFrom') == top ]] || { echo "FAIL pads-ui: slide flip not stored" >&2; return 1; }
  if [[ -n $(harness_log_grep "TypeError") || -n $(harness_log_grep "ReferenceError") ]]; then
    echo "FAIL pads-ui: QML errors:" >&2; harness_log_grep "Error" >&2; return 1
  fi
  echo "PASS pads-ui: row + editors rendered (see tests/screenshots/pads-ui-*.png), slide flip stored"
}
