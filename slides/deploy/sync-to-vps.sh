#!/usr/bin/env bash
# Sync the slides/ directory from this checkout to the VPS.
# Slidev's dev server picks up the changes via Vite HMR and pushes
# them to every connected attendee browser without restart.
#
# Usage:
#   slides/deploy/sync-to-vps.sh slidev@host
#   slides/deploy/sync-to-vps.sh slidev@host:/custom/path
#
# Defaults to /opt/workshop-nexus-intro/slides/ on the remote.

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 user@host[:/remote/path]" >&2
    exit 2
fi

target="$1"
case "$target" in
    *:*) ;;  # caller supplied a remote path
    *) target="${target}:/opt/workshop-nexus-intro/slides/" ;;
esac

# Resolve the repo root regardless of where the script is invoked from.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
cd "$repo_root"

if [ ! -d slides ]; then
    echo "Could not find slides/ at $repo_root. Aborting." >&2
    exit 1
fi

echo "Syncing slides/ to $target..."
rsync -azv --delete \
    --exclude node_modules \
    --exclude dist \
    --exclude .git \
    --exclude .DS_Store \
    --exclude '*.swp' \
    slides/ "$target"

echo "Done. Attendee browsers should HMR within a second or two."
