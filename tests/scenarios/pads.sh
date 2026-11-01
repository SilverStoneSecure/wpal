#!/usr/bin/env bash
# Key-free. Scratchpads end to end inside the nested desktop: configure both
# pads over IPC, check the plan files and Hyprland rules wpal writes, then
# drive scripts/wpal-pad.sh the way a bound key would and assert where
# windows land, which way the pad slides, and that "launch only if empty"
# holds. W uses foot (instead of really connecting gliff); S uses the real
# omawrite on a throwaway file.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

fail() { echo "FAIL pads: $*" >&2; return 1; }

wait_for() {  # wait_for <tries> <cmd...>: retry every 0.3s until cmd succeeds
  local n=$1; shift
  for _ in $(seq 1 "$n"); do "$@" && return 0; sleep 0.3; done
  return 1
}

run_pads() {
  harness_setup
  [[ -n $(harness_wait_seed) ]] || fail "fresh-install seed never landed" || return 1

  local scratch="$TEST_HOME/scratchpad.md"
  echo "# pad test" > "$scratch"
  harness_ipc setPad W '{"panes":[{"appId":"foot","args":"--app-id=wpaltest-pad-w"}]}' >/dev/null
  harness_ipc setPad S "{\"panes\":[{\"appId\":\"omawrite\",\"args\":\"$scratch\"}]}" >/dev/null

  # 1. settings persisted, plan files written by Service
  local plans="$TEST_HOME/.local/state/wpal/pads"
  wait_for 30 test -s "$plans/W.json" || fail "no plan file for W" || return 1
  wait_for 30 bash -c "jq -e '.panes[0].value == \"omawrite\"' '$plans/S.json' >/dev/null 2>&1" \
    || fail "S plan never picked up omawrite: $(cat "$plans/S.json" 2>/dev/null)" || return 1
  [[ $(jq -r .slideFrom "$plans/S.json") == bottom && $(jq -r .slideFrom "$plans/W.json") == top ]] \
    || fail "default slide directions wrong" || return 1
  [[ $(harness_entry_key pads | jq -r '.W.panes[0].appId') == foot ]] || fail "pads not stored in shell.json" || return 1

  # 2. one fixed rule per pad
  local rules; rules=$(harness_hyprctl workspacerules 2>&1)
  grep -q "wpal-pad.sh' launch W" <<<"$rules" || fail "no on_created_empty rule for W" || return 1
  grep -q "wpal-pad.sh' launch S" <<<"$rules" || fail "no on_created_empty rule for S" || return 1

  # 3. W opens empty -> foot launches into it, slide drops from the top
  harness_pad W
  wait_for 40 bash -c "[[ \$(HYPRLAND_INSTANCE_SIGNATURE=$NESTED_SIG hyprctl clients -j | jq '[.[]|select(.class==\"wpaltest-pad-w\" and .workspace.name==\"special:pad-w\")]|length') == 1 ]]" \
    || { harness_leaked_class wpaltest-pad-w && fail "W's window opened on the REAL desktop (closed it)"; fail "W never got its window"; return 1; }
  [[ $(harness_open_pad) == special:pad-w ]] || fail "W not showing after toggle" || return 1
  harness_hyprctl animations 2>&1 | grep -A6 'name: specialWorkspaceIn$' | grep -q 'style: slide top' \
    || fail "W did not set slide top" || return 1

  # 4. tuck, reopen with the window still there -> no second launch
  harness_pad W; sleep 0.5
  [[ $(harness_open_pad) == "" ]] || fail "W did not tuck away" || return 1
  harness_pad W; sleep 2
  [[ $(harness_count_class wpaltest-pad-w) == 1 ]] || fail "reopening a non-empty W launched again" || return 1

  # 5. close its last window, reopen -> launches again
  harness_close_class wpaltest-pad-w; sleep 1
  [[ $(harness_count_class wpaltest-pad-w) == 0 ]] || fail "couldn't close W's window" || return 1
  [[ $(harness_open_pad) == "" ]] || harness_pad W
  harness_pad W
  wait_for 40 bash -c "[[ \$(HYPRLAND_INSTANCE_SIGNATURE=$NESTED_SIG hyprctl clients -j | jq '[.[]|select(.class==\"wpaltest-pad-w\")]|length') == 1 ]]" \
    || fail "emptied W did not relaunch" || return 1
  harness_pad W; sleep 0.5

  # 6. S: omawrite on the file, rises from the bottom; tuck restores top-drop
  harness_pad S
  wait_for 60 bash -c "[[ \$(HYPRLAND_INSTANCE_SIGNATURE=$NESTED_SIG hyprctl clients -j | jq '[.[]|select(.class==\"omawrite\" and .workspace.name==\"special:scratchpad\")]|length') -ge 1 ]]" \
    || { harness_leaked_class omawrite && fail "omawrite opened on the REAL desktop (closed it)"; fail "S never got omawrite"; return 1; }
  harness_hyprctl animations 2>&1 | grep -A6 'name: specialWorkspaceIn$' | grep -q 'style: slide bottom' \
    || fail "S did not set slide bottom" || return 1
  harness_screenshot "pad-s-open"
  harness_pad S; sleep 2
  harness_hyprctl animations 2>&1 | grep -A6 'name: specialWorkspaceIn$' | grep -q 'style: slide top' \
    || fail "shared slide not restored to top after S tucked" || return 1

  # 7. a paused pad opens empty
  harness_ipc setPad W '{"autoLaunchEnabled":false}' >/dev/null
  wait_for 30 bash -c "jq -e '.panes == null' '$plans/W.json' >/dev/null 2>&1" || fail "pause not reflected in W plan" || return 1
  harness_close_class wpaltest-pad-w; sleep 1
  [[ $(harness_open_pad) == "" ]] || harness_pad W
  harness_pad W; sleep 2; harness_pad W
  [[ $(harness_count_class wpaltest-pad-w) == 0 ]] || fail "paused W still launched" || return 1

  harness_leaked_class wpaltest-pad-w && fail "a W test window leaked to the REAL desktop" && return 1
  echo "PASS pads: rules, plans, launch-if-empty, no double launch, relaunch, slide directions, pause"
}
