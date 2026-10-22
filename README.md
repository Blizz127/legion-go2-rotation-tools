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
- `y1-wrapper.sh` — loads the InputPlumber profile that presents the Legion's
  Y1 button as keyboard F7 while a helper runs, restoring the previous profile
  on exit. The verified profile from the 2026-10-19 deployment lives on the
  Legion; `deploy.sh` keeps that copy if the kit's one is missing.

Game Mode note: the helpers read the game window through X11 screenshots, so
they must run in Desktop Mode (launch them from the Steam library or the
desktop there). In Game Mode each app is isolated by gamescope and the helper
cannot see the game.
