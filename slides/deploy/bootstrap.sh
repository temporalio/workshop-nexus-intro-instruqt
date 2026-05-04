#!/usr/bin/env bash
# Idempotent VPS bootstrap for the Replay 2026 Nexus workshop.
# Installs Node, pnpm, git, Caddy; clones both repos to /opt; configures
# the slidev systemd unit and Caddyfile; restarts services. Safe to re-run.
#
# Usage:
#   sudo bash bootstrap.sh --domain nexus.ziggy.codes
#
# All flags are optional; missing values are prompted for. Re-running with
# the same args reapplies config without breaking anything.

set -euo pipefail

DOMAIN="${DOMAIN:-}"
PRESENTER_USER="${PRESENTER_USER:-mason}"
PRESENTER_PASSWORD="${PRESENTER_PASSWORD:-}"
DECK_REPO="${DECK_REPO:-https://github.com/temporalio/workshop-nexus-intro}"
CODE_REPO="${CODE_REPO:-https://github.com/temporalio/workshop-nexus-intro-code}"
DECK_REF="${DECK_REF:-main}"
CODE_REF="${CODE_REF:-main}"

DECK_DIR=/opt/workshop-nexus-intro
CODE_DIR=/opt/workshop-nexus-intro-code

usage() {
    cat <<EOF
Usage: sudo bash $0 [options]

Options:
  --domain DOMAIN          Public domain (e.g. nexus.ziggy.codes). Prompted if absent.
  --user USERNAME          Presenter HTTP-basic-auth username. Default: mason.
  --password PASSWORD      Presenter password. Prompted if absent. Bcrypt-hashed before write.
  --deck-ref REF           Deck repo branch/tag/sha. Default: main.
  --code-ref REF           Code repo branch/tag/sha. Default: main.
  -h, --help               Show this help.

Environment variables (DOMAIN, PRESENTER_USER, etc.) are honored as defaults.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --domain) DOMAIN="$2"; shift 2 ;;
        --user) PRESENTER_USER="$2"; shift 2 ;;
        --password) PRESENTER_PASSWORD="$2"; shift 2 ;;
        --deck-ref) DECK_REF="$2"; shift 2 ;;
        --code-ref) CODE_REF="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

banner() {
    printf '\n\033[1;36m== %s ==\033[0m\n' "$1"
}

info() { printf '   %s\n' "$1"; }

# --------- pre-flight ---------

if [[ $EUID -ne 0 ]]; then
    echo "This script must run as root. Re-run with: sudo bash $0 ..." >&2
    exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
    echo "This bootstrap targets Debian 12 / Ubuntu 22.04+ (apt-based)." >&2
    exit 1
fi

if [[ -z "$DOMAIN" ]]; then
    read -rp "Public domain (e.g. nexus.ziggy.codes): " DOMAIN
fi
if [[ -z "$DOMAIN" ]]; then
    echo "Domain is required." >&2
    exit 1
fi

if [[ -z "$PRESENTER_PASSWORD" ]]; then
    read -rsp "Presenter password for user '$PRESENTER_USER': " PRESENTER_PASSWORD
    echo
    read -rsp "Confirm presenter password: " CONFIRM
    echo
    if [[ "$PRESENTER_PASSWORD" != "$CONFIRM" ]]; then
        echo "Passwords do not match." >&2
        exit 1
    fi
fi

# --------- 1. apt packages ---------

banner "Installing system packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl ca-certificates gnupg \
    debian-keyring debian-archive-keyring apt-transport-https \
    git rsync

# Node 22 via NodeSource
node_v="$(node -v 2>/dev/null || echo none)"
if [[ "$node_v" != v22* ]]; then
    info "Installing Node 22 (current: $node_v)"
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get install -y -qq nodejs
else
    info "Node 22 already installed ($node_v)"
fi

# pnpm
if ! command -v pnpm >/dev/null 2>&1; then
    info "Installing pnpm"
    npm install -g pnpm
else
    info "pnpm already installed ($(pnpm -v))"
fi

# Caddy
if ! command -v caddy >/dev/null 2>&1; then
    info "Installing Caddy"
    install -d -m 0755 /usr/share/keyrings
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
        | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
        > /etc/apt/sources.list.d/caddy-stable.list
    apt-get update -qq
    apt-get install -y -qq caddy
else
    info "Caddy already installed ($(caddy version | head -n1))"
fi

# --------- 2. slidev system user ---------

banner "Creating slidev user"
if ! id slidev >/dev/null 2>&1; then
    useradd --system --create-home --shell /bin/bash slidev
    info "Created slidev user"
else
    info "slidev user already exists"
fi

# --------- 3. clone repos ---------

banner "Cloning repositories"

clone_or_update() {
    local repo="$1" dir="$2" ref="$3"
    if [[ -d "$dir/.git" ]]; then
        info "Updating $dir"
        sudo -u slidev git -C "$dir" fetch --quiet origin
        sudo -u slidev git -C "$dir" checkout --quiet "$ref"
        sudo -u slidev git -C "$dir" pull --ff-only --quiet origin "$ref" || true
    else
        info "Cloning $repo -> $dir"
        install -d -m 0755 -o slidev -g slidev "$dir"
        sudo -u slidev git clone --quiet "$repo" "$dir"
        sudo -u slidev git -C "$dir" checkout --quiet "$ref"
    fi
}

clone_or_update "$DECK_REPO" "$DECK_DIR" "$DECK_REF"
clone_or_update "$CODE_REPO" "$CODE_DIR" "$CODE_REF"

# Caddy reads files directly from /opt; ensure world-readable.
chmod -R o+rX "$DECK_DIR" "$CODE_DIR"

# --------- 4. install slidev deps ---------

banner "Installing Slidev dependencies"
# Skip Playwright Chromium download: PDF is generated locally and synced.
sudo -u slidev env \
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    HOME=/home/slidev \
    bash -lc "cd $DECK_DIR/slides && pnpm install --frozen-lockfile --prefer-offline"

# --------- 5. systemd unit ---------

banner "Installing systemd unit"
install -m 0644 "$DECK_DIR/slides/deploy/slidev.service" /etc/systemd/system/slidev.service
systemctl daemon-reload
systemctl enable --quiet slidev

# --------- 6. Caddyfile ---------

banner "Configuring Caddy"

# Generate bcrypt hash. caddy hash-password --plaintext writes the hash to stdout.
HASH="$(caddy hash-password --plaintext "$PRESENTER_PASSWORD")"
if [[ -z "$HASH" ]]; then
    echo "caddy hash-password produced empty output." >&2
    exit 1
fi

# Render the shipped Caddyfile to /etc/caddy/Caddyfile with substitutions.
# `|` delimiter avoids escaping `/` in the bcrypt hash; `$` is literal in
# sed replacement, and bcrypt does not contain `&` or `\`.
TMPFILE="$(mktemp)"
trap 'rm -f "$TMPFILE"' EXIT
cp "$DECK_DIR/slides/deploy/Caddyfile" "$TMPFILE"
sed -i "s|nexus.example.com|$DOMAIN|g" "$TMPFILE"
sed -i "s|REPLACE_WITH_BCRYPT_HASH_FROM_CADDY_HASH_PASSWORD|$HASH|g" "$TMPFILE"
if [[ "$PRESENTER_USER" != "mason" ]]; then
    sed -i "s|        mason |        $PRESENTER_USER |g" "$TMPFILE"
fi

caddy validate --config "$TMPFILE" --adapter caddyfile >/dev/null
install -m 0644 "$TMPFILE" /etc/caddy/Caddyfile

install -d -m 0755 /var/log/caddy
chown caddy:caddy /var/log/caddy 2>/dev/null || true

# --------- 7. start services ---------

banner "Starting services"
systemctl restart slidev
systemctl reload caddy 2>/dev/null || systemctl restart caddy

sleep 2
if ! systemctl is-active --quiet slidev; then
    echo "slidev unit failed to start. Check: journalctl -u slidev -n 100" >&2
    exit 1
fi
if ! systemctl is-active --quiet caddy; then
    echo "caddy failed to start. Check: journalctl -u caddy -n 100" >&2
    exit 1
fi
info "slidev: active"
info "caddy:  active"

# --------- 8. summary ---------

banner "Done"
cat <<EOF

The workshop is now reachable at https://$DOMAIN/

Smoke tests (run once DNS has propagated and Let's Encrypt has issued the cert):

  curl -I https://$DOMAIN/
  curl -I https://$DOMAIN/slides
  curl -I https://$DOMAIN/slides/presenter                           # 401 expected
  curl -I -u $PRESENTER_USER:'<password>' https://$DOMAIN/slides/presenter   # 200
  curl -I https://$DOMAIN/game
  curl -I https://$DOMAIN/export                                     # 404 until first PDF sync

Next steps from your laptop (in the deck repo):

  cd slides
  pnpm export                  # writes slides/public/export.pdf
  cd ..
  slides/deploy/sync-to-vps.sh slidev@$DOMAIN

That uploads the PDF and any local edits. The room HMRs without a restart.

Logs:
  sudo journalctl -u slidev -f
  sudo journalctl -u caddy -f
EOF
