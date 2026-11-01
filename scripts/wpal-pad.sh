#!/bin/bash
# Scratchpad toggle + auto-launch for wpal (io.github.silverstone.wpal).
#
#   wpal-pad.sh <KEY>          Toggle pad KEY (S, W). Bind a key to this in
#                              your own Hyprland config, e.g. bindings.lua:
#                                o.bind("SUPER + W", "Scratchpad W",
#                                  "~/.config/omarchy/plugins/io.github.silverstone.wpal/scripts/wpal-pad.sh W")
#   wpal-pad.sh launch <KEY>   Furnish pad KEY with its configured panes. Run
#                              by the pad's Hyprland on_created_empty rule
#                              (Service.applyPadRules) -- i.e. only when the
#                              pad opens with nothing on it.
#
# Each pad's settings are resolved by Service.qml (Model.padPlan) and written
# to $XDG_STATE_HOME/wpal/pads/<KEY>.json whenever they change, so this script
# never re-implements the settings logic. Without that file (wpal not running
# yet) a pad still toggles, using its default name and slide direction, and
# simply opens empty.
set -u

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/wpal/pads"
here=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)

mode=toggle
if [[ ${1:-} == launch ]]; then mode=launch; shift; fi
key=$(tr '[:lower:]' '[:upper:]' <<<"${1:-}")
if [[ ! $key =~ ^[A-Z]$ ]]; then
  echo "usage: wpal-pad.sh [launch] <S|W>" >&2
  exit 2
fi

# Defaults, kept in step with Model.padWorkspace / Model.padDefaultSlide.
if [[ $key == S ]]; then
  ws="special:scratchpad"; slide=bottom
else
  ws="special:pad-${key,,}"; slide=top
fi

plan="$state_dir/$key.json"
if [[ -f $plan ]]; then
  ws=$(jq -r --arg d "$ws" '.workspace // $d' "$plan" 2>/dev/null || echo "$ws")
  slide=$(jq -r --arg d "$slide" '.slideFrom // $d' "$plan" 2>/dev/null || echo "$slide")
fi

if [[ $mode == launch ]]; then
  [[ -f $plan ]] || exit 0
  panes=$(jq -c '.panes // empty' "$plan" 2>/dev/null)
  [[ -n $panes ]] || exit 0
  layout=$(jq -r '.layout // 0' "$plan")
  fs=$(jq -r '.fullScreenIndex // -1' "$plan")
  exec bash "$here/workspace-autolaunch.sh" "$ws" "$(printf '%s' "$panes" | base64 -w0)" "$layout" "$fs"
fi

# Hyprland has ONE special-workspace animation, shared by every pad (and
# Omarchy's qconsole). Set it to this pad's direction just before the pad
# moves. Per Omarchy's qconsole.lua: the style names the edge the motion is
# measured from -- In "slide top" drops down into view and Out "slide
# bottom" retracts back up -- so a bottom pad is the mirror image.
set_slide() {
  local in out
  if [[ $1 == bottom ]]; then in="slide bottom"; out="slide top"; else in="slide top"; out="slide bottom"; fi
  hyprctl eval "hl.animation({ leaf = \"specialWorkspaceIn\", enabled = true, speed = 3, bezier = \"easeOutQuint\", style = \"$in\" })
hl.animation({ leaf = \"specialWorkspaceOut\", enabled = true, speed = 2, bezier = \"easeInOutCubic\", style = \"$out\" })" >/dev/null 2>&1
}

open_now=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .specialWorkspace.name')
set_slide "$slide"
hyprctl dispatch "hl.dsp.workspace.toggle_special(\"${ws#special:}\")" >/dev/null

# Tucking away: once the slide-out has played, put the shared animation back
# to Omarchy's own (drop from the top) so qconsole on Super+` isn't left
# rising from the bottom.
if [[ $open_now == "$ws" && $slide != top ]]; then
  ( sleep 1; set_slide top ) </dev/null >/dev/null 2>&1 &
  disown
fi
exit 0
