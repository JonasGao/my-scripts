#!/usr/bin/env bash
set -euo pipefail

# Ensure running as root (re-exec with sudo if available)
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
        exec sudo -E bash "$0" "$@"
    else
        echo "This script must be run as root (sudo not found)." >&2
        exit 1
    fi
fi

DEST_DIR="/usr/local/share/ca-certificates"
GOLH_URL="https://ptcdnoss.fengmoyun.com/artifacts/ca/golh_CA.crt"
MM_URL="https://ptcdnoss.fengmoyun.com/artifacts/ca/mm_CA.crt"
GOLH_DST="$DEST_DIR/golh_CA.crt"
MM_DST="$DEST_DIR/mm_CA.crt"

mkdir -p "$DEST_DIR"

download() {
    local url="$1"
    local dst="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --retry 3 --retry-delay 1 -o "$dst" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$dst" "$url"
    else
        echo "Neither curl nor wget is installed." >&2
        exit 1
    fi

    if [[ ! -s "$dst" ]]; then
        echo "Failed to download or empty file: $url" >&2
        exit 1
    fi
}

echo "Downloading CA certificates..."
download "$GOLH_URL" "$GOLH_DST"
download "$MM_URL" "$MM_DST"

echo "Setting ownership and permissions..."
chown root:root "$GOLH_DST" "$MM_DST"
chmod 0644 "$GOLH_DST" "$MM_DST"

echo "Updating system CA store..."
if command -v update-ca-certificates >/dev/null 2>&1; then
    update-ca-certificates
elif command -v update-ca-trust >/dev/null 2>&1; then
    # RHEL/CentOS/Fedora
    cp -f "$GOLH_DST" /etc/pki/ca-trust/source/anchors/
    cp -f "$MM_DST" /etc/pki/ca-trust/source/anchors/
    update-ca-trust extract
else
    echo "No known CA update tool found (update-ca-certificates/update-ca-trust)." >&2
    exit 1
fi

echo "Done."
