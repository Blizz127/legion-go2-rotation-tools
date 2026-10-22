#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
profile="$script_dir/rotation-y1.json"
service=org.shadowblip.InputPlumber
object=/org/shadowblip/InputPlumber/CompositeDevice0
interface=org.shadowblip.Input.CompositeDevice
expected_name="Rotation Tools Y1 Toggle"

if [[ ${1:-} == -- ]]; then
  shift
fi
if [[ $# -eq 0 ]]; then
  printf '%s\n' "Usage: $0 -- command [args...]" >&2
  exit 2
fi

runtime_dir=${XDG_RUNTIME_DIR:-/tmp}
exec 9>"$runtime_dir/rotation-y1-profile-${UID}.lock"
if ! flock -n 9; then
  printf '%s\n' "Another Y1-enabled rotation helper is already running." >&2
  exit 1
fi

get_property() {
  local line
  line=$(busctl --system get-property "$service" "$object" "$interface" "$1" 2>/dev/null) || return 1
  line=${line#s \"}
  line=${line%\"}
  printf '%s\n' "$line"
}

load_profile() {
  busctl --system call "$service" "$object" "$interface" LoadProfilePath s "$1" >/dev/null
}

original_path=$(get_property ProfilePath || true)
if ! load_profile "$profile"; then
  printf '%s\n' "Warning: Y1 mapping could not be loaded; F8/F9 remain available." >&2
  exec "$@"
fi

child=""
monitor=""
restore_profile() {
  if [[ -n "$monitor" ]]; then
    kill "$monitor" 2>/dev/null || true
    wait "$monitor" 2>/dev/null || true
  fi
  if [[ -n "$original_path" && -f "$original_path" ]]; then
    load_profile "$original_path" 2>/dev/null || true
  fi
}
stop_child_and_exit() {
  local status=$1
  if [[ -n "$child" ]]; then
    kill -TERM "$child" 2>/dev/null || true
  fi
  exit "$status"
}
trap restore_profile EXIT
trap 'stop_child_and_exit 129' HUP
trap 'stop_child_and_exit 130' INT
trap 'stop_child_and_exit 143' TERM

"$@" &
child=$!
(
  exec 9>&-
  while kill -0 "$child" 2>/dev/null; do
    sleep 1
    current=$(get_property ProfileName || true)
    if [[ "$current" != "$expected_name" ]]; then
      load_profile "$profile" 2>/dev/null || true
    fi
  done
) &
monitor=$!

set +e
wait "$child"
status=$?
set -e
exit "$status"
