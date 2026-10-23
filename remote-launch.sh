#!/usr/bin/env bash
# Start (or stop) a helper ON the Legion from an SSH session.
#
# The Legion runs logind with KillUserProcesses=true, so anything started from
# an SSH session dies when that session closes. This starts the helper as a
# transient systemd --user service with the desktop session's environment, so
# it behaves exactly like launching the (Y1) shortcut from the desktop.
#
#   remote-launch.sh aion2 | aion2-craft | eq | gw2 | gw1
#   remote-launch.sh stop <same name>
set -euo pipefail
P="$HOME/Projects"
kit="$P/legion-go2-rotation-tools"
wrap="$kit/integration/with-rotation-y1.sh"
declare -A CMD=(
  [aion2]="$wrap -- $P/aion2-cleric-macro/launch-aion2-cleric.sh"
  [aion2-craft]="$wrap -- $P/aion2-crafting-assistant/launch-aion2-crafting.sh"
  [eq]="$wrap -- $P/everquest-legends-rotation/launch.sh"
  [gw2]="$wrap -- $P/gw2-1button/launch-gw2-gui.sh --key F7"
  [gw1]="$wrap -- $P/gw2-1button/launch-gw1-gui.sh --key F7"
)
if [ "${1:-}" = stop ]; then
  systemctl --user stop "rotation-${2:?name}.service"; echo "stopped rotation-$2"; exit 0
fi
name=${1:?usage: remote-launch.sh <aion2|aion2-craft|eq|gw2|gw1> | stop <name>}
[ -n "${CMD[$name]:-}" ] || { echo "unknown helper: $name" >&2; exit 2; }

pid=$(pgrep -u "$USER" -n plasmashell || pgrep -u "$USER" -n kwin_wayland)
args=()
while IFS= read -r line; do args+=(--setenv="$line"); done < <(
  tr '\0' '\n' < "/proc/$pid/environ" |
  grep -E '^(DISPLAY|WAYLAND_DISPLAY|XAUTHORITY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS|XDG_SESSION_TYPE|HOME|PATH|LANG|XDG_DATA_DIRS)=')
log="$HOME/.local/state/rotation-$name.log"
mkdir -p "$(dirname "$log")"
systemctl --user stop "rotation-$name.service" 2>/dev/null || true
systemd-run --user --unit="rotation-$name" --collect --description="rotation helper $name (Y1)" \
  "${args[@]}" \
  --property=StandardOutput=append:"$log" --property=StandardError=append:"$log" \
  bash -c "echo \"=== launch \$(date +%T)\"; exec ${CMD[$name]}"
sleep 3
systemctl --user is-active "rotation-$name.service"
echo "log: $log"
