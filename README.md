# Legion Go 2 rotation tools

Deployment kit that copies the rotation helpers from the Alienware to the
Legion Go 2 (`blizz@100.127.215.80` over Tailscale) and installs launchers,
Y1 wiring and Steam shortcuts there.

- `deploy.sh` — rsync `aion2-cleric-macro`, `everquest-legends-rotation`,
  `gw2-1button` and this kit to `~/Projects` on the Legion, then run
  `install.sh` there. `--restart-steam` lets it close and restart Steam so the
  shortcuts get written (Steam only reads `shortcuts.vdf` at start).
- `install.sh` — runs on the Legion: desktop/menu launchers named "(Y1)",
  sets AION's `controls.json` toggle to `KEY_F7`, points the GW2/GW Reforged
  windows at trigger `F7`, and adds non-Steam shortcuts.
- `steam_shortcuts.py` — dependency-free binary VDF reader/writer that adds or
  updates non-Steam shortcuts by name and backs up the file first.
- `integration/with-rotation-y1.sh -- <command>` — the Y1 wrapper recovered
  from the 2026-10-19 deployment: loads `integration/rotation-y1.json` into
  InputPlumber (Legion Go 2 `LeftPaddle1` = Y1 -> keyboard F7, other defaults
  preserved), keeps it loaded while the helper runs, restores the previous
  profile on exit, and refuses to run two Y1 helpers at once. For commands
  whose path contains `aion2` it loads `rotation-y1-f12.json` instead (Y1 ->
  F12), because AION 2 uses F1-F8 as consumable quickslots and F7 holds a
  scroll; `Y1_PROFILE=<file>` overrides the choice.
- The 2026-10-19 nested layout on the Legion is moved aside to
  `legion-go2-rotation-tools.old-20261019`, not deleted.

Game Mode note: the helpers read the game window through X11 screenshots, so
they must run in Desktop Mode (launch them from the Steam library or the
desktop there). In Game Mode each app is isolated by gamescope and the helper
cannot see the game.

## Starting a helper from SSH

The Legion's logind has `KillUserProcesses=true`, so a helper started from an
SSH shell is killed when that shell closes. Use `remote-launch.sh <name>` on
the Legion (names: `aion2`, `aion2-craft`, `eq`, `gw2`, `gw1`); it starts the
same (Y1) launcher as a transient `systemd --user` service with the desktop
session's environment, logging to `~/.local/state/rotation-<name>.log`.
`remote-launch.sh stop <name>` ends it (and the Y1 profile is restored).
