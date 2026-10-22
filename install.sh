#!/usr/bin/env bash
# Runs ON the Legion Go 2: launchers, Y1 toggle wiring, Steam shortcuts.
set -euo pipefail

restart_steam=0
[ "${1:-}" = "--restart-steam" ] && restart_steam=1
P="$HOME/Projects"
kit="$P/legion-go2-rotation-tools"
apps="$HOME/.local/share/applications"
mkdir -p "$apps" "$HOME/Desktop"

# 1. Dependencies the helpers need (Bazzite ships most of them).
for t in python3 import wmctrl xprop xwininfo; do
  command -v "$t" >/dev/null || echo "WARNING: $t not found on this device"
done
python3 -c "import evdev, PySide6" 2>/dev/null || \
  echo "WARNING: python evdev/PySide6 missing: python3 -m pip install --user evdev PySide6"

# 2. AION 2: Y1 arrives as F7 through the Y1 wrapper, so make it the toggle.
python3 - "$P/aion2-cleric-macro/controls.json" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
data = json.loads(p.read_text()) if p.exists() else {}
data.setdefault("combat_on", "KEY_F8"); data.setdefault("combat_off", "KEY_F9")
data["combat_toggle"] = "KEY_F12"  # Y1 -> F12 for AION (F7 is a scroll slot)
p.write_text(json.dumps(data, indent=2) + "\n")
print("controls.json:", data)
PY

# 3. Launchers. The Y1 wrapper (InputPlumber profile that maps Y1 -> F7) is
#    used when present; otherwise the plain launcher runs and F7/F8/F9 work
#    from a keyboard.
y1="$kit/integration/with-rotation-y1.sh"
mkdir -p "$kit/integration/.kept"
wrap() { if [ -x "$y1" ]; then echo "$y1 -- $1"; else echo "$1"; fi; }

# Old (2026-10-19) desktop symlinks pointed into the nested kit layout and
# now dangle; drop them so the new launchers can be written.
for f in "$HOME/Desktop"/*.desktop "$apps"/*.desktop; do
  [ -L "$f" ] || continue
  target=$(readlink -- "$f" || true)
  case "$target" in
    *legion-go2-rotation-tools*) rm -f -- "$f"; echo "removed stale launcher $f";;
  esac
done
mk() { # name, exec, comment
  local file="$apps/$4"
  rm -f -- "$file" "$HOME/Desktop/$4"
  cat > "$file" <<D
[Desktop Entry]
Type=Application
Name=$1
Comment=$3
Exec=$2
Icon=applications-games
Terminal=false
Categories=Game;
StartupNotify=true
X-KDE-Autostart-enabled=false
D
  cp "$file" "$HOME/Desktop/$4"; chmod +x "$HOME/Desktop/$4"
  echo "launcher: $1"
}
mk "AION 2 Cleric Rotation (Y1)" "$(wrap "$P/aion2-cleric-macro/launch-aion2-cleric.sh")" \
   "Blizz Cleric solo assist; Y1 (as F12) toggles combat, F8 on, F9 off" aion2-cleric-rotation-y1.desktop
mk "EQ Legends Solo Assist (Y1)" "$(wrap "$P/everquest-legends-rotation/launch.sh")" \
   "Paladin/Cleric 1-50; Y1 as F7, F8 on, F9 off, F10 heal" eql-solo-assist-y1.desktop
mk "GW2 1-Button Rotation (Y1)" "$(wrap "$P/gw2-1button/launch-gw2-gui.sh --key F7")" \
   "Guild Wars 2 one-button rotation; Y1 starts/stops" gw2-1button-gui-y1.desktop
mk "AION 2 Crafting Assistant (Y1)" "$(wrap "$P/aion2-crafting-assistant/launch-aion2-crafting.sh")" \
   "Bounded repeat-craft helper; F8 start, Y1 (as F12) toggles, F9 stop" aion2-crafting-assistant-y1.desktop
mk "GW Reforged 1-Button Rotation (Y1)" "$(wrap "$P/gw2-1button/launch-gw1-gui.sh --key F7")" \
   "Guild Wars: Reforged one-button rotation; Y1 starts/stops" gw1-1button-gui-y1.desktop
update-desktop-database "$apps" 2>/dev/null || true

# 4. Steam shortcuts (non-Steam games). Steam only reads shortcuts.vdf at start.
add_shortcuts() {
  local s="$kit/steam_shortcuts.py"
  python3 "$s" add --name "AION 2 Cleric Rotation (Y1)" --exe "$(wrap "$P/aion2-cleric-macro/launch-aion2-cleric.sh")" --dir "$P/aion2-cleric-macro" --tag Rotation
  python3 "$s" add --name "EQ Legends Solo Assist (Y1)" --exe "$(wrap "$P/everquest-legends-rotation/launch.sh")" --dir "$P/everquest-legends-rotation" --tag Rotation
  python3 "$s" add --name "GW2 1-Button Rotation (Y1)" --exe "$(wrap "$P/gw2-1button/launch-gw2-gui.sh --key F7")" --dir "$P/gw2-1button" --tag Rotation
  python3 "$s" add --name "AION 2 Crafting Assistant (Y1)" --exe "$(wrap "$P/aion2-crafting-assistant/launch-aion2-crafting.sh")" --dir "$P/aion2-crafting-assistant" --tag Rotation
  python3 "$s" add --name "GW Reforged 1-Button Rotation (Y1)" --exe "$(wrap "$P/gw2-1button/launch-gw1-gui.sh --key F7")" --dir "$P/gw2-1button" --tag Rotation
}
if pgrep -f 'steam.sh|steamwebhelper' >/dev/null; then
  if [ "$restart_steam" = 1 ]; then
    echo "closing Steam to write shortcuts"; steam -shutdown || true
    for _ in $(seq 1 30); do pgrep -f 'steam.sh' >/dev/null || break; sleep 1; done
    add_shortcuts
    (setsid steam >/dev/null 2>&1 &) ; echo "Steam restarted"
  else
    echo "Steam is running: shortcuts NOT written. Re-run with --restart-steam or close Steam first."
  fi
else
  add_shortcuts
fi
echo "install done"
