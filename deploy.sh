#!/usr/bin/env bash
# Copy the rotation helpers from this PC to the Legion Go 2 and install them.
#
#   ./deploy.sh                 # rsync + install launchers (Steam shortcuts if Steam is closed)
#   ./deploy.sh --restart-steam # also close Steam, write shortcuts, start Steam again
#
# Needs: ssh access to blizz@100.127.215.80 (Tailscale) and rsync on both ends.
set -euo pipefail

LEGION="${LEGION:-blizz@100.127.215.80}"
SSH="${SSH_CMD:-ssh}"
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
src=$(dirname -- "$here")

repos=(aion2-cleric-macro everquest-legends-rotation gw2-1button aion2-crafting-assistant legion-go2-rotation-tools)
for repo in "${repos[@]}"; do
  [ -d "$src/$repo" ] || { echo "missing $src/$repo" >&2; exit 1; }
done

echo "== preserving the 2026-10-19 layout if it is still there"
$SSH "$LEGION" 'set -e; old=~/Projects/legion-go2-rotation-tools
if [ -d "$old/aion2-cleric-macro" ] && [ ! -d "$old/integration/.kept" ]; then
  mv "$old" "$old.old-20261019"; echo "moved old kit to $old.old-20261019"; fi'

echo "== copying to $LEGION"
for repo in "${repos[@]}"; do
  rsync -az --delete -e "$SSH" \
    --exclude '__pycache__' --exclude '.pytest_cache' --exclude 'artifacts/' \
    "$src/$repo/" "$LEGION:Projects/$repo/"
done

echo "== installing on the Legion"
$SSH "$LEGION" "bash ~/Projects/legion-go2-rotation-tools/install.sh $*"
