# wpal click-through tests

Automated replacement for manually uninstalling/reinstalling and clicking
through wpal to check it still behaves. Runs the real plugin inside a
throwaway, isolated Hyprland+Quickshell instance (the
`ss-remote-screen-control` recipe in SilverStone-Hub) — nothing touches your
real desktop, settings, or wallpaper.

## Run it

```
./tests/run.sh               # key-free scenarios (safe while you use the desktop)
./tests/run.sh keyed         # scenarios that fake keypresses (hands off the keyboard)
./tests/run.sh everything    # both
./tests/run.sh settings-write   # any single scenario by name
```

**Key-free** scenarios drive wpal only through its IPC verbs
(`qs ipc call silverstone …`) and read results back from `shell.json` /
`hyprctl`. Nothing is typed or clicked on the real session, so they can run
while someone is working. **Keyed** scenarios use ydotool, whose keypresses
land in whatever window has focus — run them only when nobody's at the
keyboard.

## Requirements

- A live Hyprland session to nest inside (the T420).
- Keyed scenarios only: `ss-onboard-remote-screen-control` has been run on
  this machine (ydotool + `/dev/uinput` access), and a calibration file at
  `tests/lib/calibration/<hostname>.env` — see `T420.env`.

## IPC verbs (BarWidget.qml, target `silverstone`)

`open` · `close` · `toggle` · `isOpen` · `setEnabled <bool>` ·
`setAutoLaunch <bool>` · `getSettings` — the setters call the same Panel
functions as the panel's own toggles.

## Layout

- `run.sh` — entry point, runs one scenario or all.
- `lib/harness.sh` — shared setup (fresh throwaway HOME + shell.json each
  run, nested Hyprland launch) / teardown / ydotool+IPC helpers.
- `lib/calibration/` — per-machine ydotool scale, one file per hostname.
- `scenarios/` — one file per behavior being checked.
- `screenshots/` — left behind after each run for a human to glance at;
  not asserted on by the scripts themselves.

## Scenarios so far

- `settings-write` (key-free) — regression test for PR #6: after a fresh
  install's seed, flips `enabled` and `autoLaunchEnabled` over IPC and
  confirms both persist (the old guard refused every such write).

- `fresh-install` — boots from a bare `{"id": "io.github.silverstone.wpal"}` entry,
  confirms `globalOverride` seeds correctly with no clicks needed.
- `escape-cascade` — opens the per-workspace editor, double-taps Escape,
  confirms the panel closes in exactly 2 presses (regression test for the
  2026-10-05 bug where a fast double-tap needed a 3rd press — see
  `Panel.qml`'s `escapeGuardUntil`).
- `replacement-bar` — same as `fresh-install`, but boots under a cloned
  bar.id (`WPAL_TEST_REPLACEMENT_BAR=1` in `harness.sh`), reproducing
  SilverAsus's real `chad.bar` setup where `serviceFor()` always returns
  null. Regression test for the blank-wallpaper-preview bug fixed by
  `BarWidget.qml`'s `hostService`/`effectiveService` fallback.

## Adding a scenario

Drop a `scenarios/<name>.sh` defining `run_<name_with_underscores>`, source
`lib/harness.sh`, and add it to `SCENARIOS` in `run.sh`. Drive the panel via
its own IPC handler (`harness_ipc open|close|toggle|isOpen`, target
`silverstone` in `BarWidget.qml`) and keyboard nav where possible —
coordinate-clicking (`harness_click`) is the fallback, not the default, since
it breaks the moment a layout shifts.

## Not yet covered

- `duplicate-pane` (the auto-launch `gtk-launch` dedup bug, fixed in
  `5c77557`) — needs a way to count real windows inside the nested
  instance's own compositor (`hyprctl --instance <nested-sig> clients -j`),
  not yet wired up here.
- Anything on SilverAsus — this machine's calibration doesn't exist yet;
  onboard it first, then add `tests/lib/calibration/SilverAsus.env`.
