#!/bin/bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

usage() {
    local cmd
    cmd="$(basename "$0")"
    cat <<USAGE
Usage:
  $cmd [options] <username>

Options:
  -h, --help               Show this help and exit
  -y, --yes                Non-interactive mode; auto-confirm prompts
      --dry-run            Print actions without executing
      --verbose            Verbose output
      --easyrsa-dir PATH   Path to easy-rsa directory (overrides auto-detect and EASYRSA_DIR)
      --crl-path PATH      Destination path of CRL (default: /etc/openvpn/crl.pem)
      --service NAME       OpenVPN systemd service to reload (default: auto-detect, then openvpn@server/openvpn)

Examples:
  $cmd --yes alice
  $cmd --easyrsa-dir /etc/openvpn/easy-rsa bob
USAGE
}

log_ts() { date '+%Y-%m-%d %H:%M:%S'; }
log_info() { printf '[%s] [INFO] %s\n' "$(log_ts)" "$*"; }
log_warn() { printf '[%s] [WARN] %s\n' "$(log_ts)" "$*" >&2; }
log_error() { printf '[%s] [ERROR] %s\n' "$(log_ts)" "$*" >&2; }
log_debug() { if [ "${VERBOSE:-false}" = true ]; then printf '[%s] [DEBUG] %s\n' "$(log_ts)" "$*"; fi; }

run_cmd() {
    if [ "${DRY_RUN:-false}" = true ]; then
        log_info "DRY-RUN: $*"
    else
        "$@"
    fi
}

ensure_root() {
    if [ "${EUID:-$(id -u)}" -ne 0 ]; then
        log_error 'This script must be run as root. Try: sudo -- $0 ...'
        exit 10
    fi
}

validate_username() {
    local name="$1"
    if [ -z "$name" ]; then
        log_error 'Username is required.'
        exit 11
    fi
    if ! printf '%s' "$name" | grep -Eq '^[A-Za-z0-9._-]+$'; then
        log_error "Invalid username: '$name'. Allowed: A-Za-z0-9._-"
        exit 12
    fi
}

detect_easyrsa_dir() {
    if [ -n "${EASYRSA_DIR_OVERRIDE:-}" ]; then
        printf '%s' "$EASYRSA_DIR_OVERRIDE"
        return 0
    fi
    if [ -n "${EASYRSA_DIR:-}" ] && [ -d "$EASYRSA_DIR" ]; then
        printf '%s' "$EASYRSA_DIR"
        return 0
    fi

    local candidates=(
        '/etc/openvpn/easy-rsa'
        '/usr/share/easy-rsa'
        '/usr/local/share/easy-rsa'
        '/etc/easy-rsa'
    )
    local doc_candidates
    # shellcheck disable=SC2207
    doc_candidates=($(ls -d /usr/share/doc/openvpn*/easy-rsa/2.0 2>/dev/null || true))

    for p in "${candidates[@]}" "${doc_candidates[@]}"; do
        if [ -d "$p" ]; then
            printf '%s' "$p"
            return 0
        fi
    done
    return 1
}

detect_easyrsa_version() {
    local dir="$1"
    if [ -x "$dir/easyrsa" ]; then
        printf 'v3'
        return 0
    fi
    if [ -f "$dir/vars" ] && [ -x "$dir/revoke-full" ]; then
        printf 'v2'
        return 0
    fi
    printf 'unknown'
    return 1
}

ensure_prereqs() {
    if ! command -v openssl >/dev/null 2>&1; then
        log_warn 'openssl not found in PATH; easy-rsa may require it.'
    fi
    if ! command -v systemctl >/dev/null 2>&1; then
        log_warn 'systemctl not found; OpenVPN service reload will be skipped.'
    fi
}

find_user_cert_path() {
    local dir="$1" version="$2" user="$3"
    if [ "$version" = 'v3' ]; then
        if [ -f "$dir/pki/issued/${user}.crt" ]; then
            printf '%s' "$dir/pki/issued/${user}.crt"
            return 0
        fi
    else
        if [ -f "$dir/keys/${user}.crt" ]; then
            printf '%s' "$dir/keys/${user}.crt"
            return 0
        fi
    fi
    return 1
}

generate_and_deploy_crl() {
    local dir="$1" version="$2" dest_crl="$3"
    local src_crl
    if [ "$version" = 'v3' ]; then
        log_info 'Generating CRL (v3)'
        (cd "$dir" && run_cmd ./easyrsa gen-crl)
        src_crl="$dir/pki/crl.pem"
    else
        log_info 'Generating CRL (v2)'
        # v2: revoke-full usually generates CRL, but generate explicitly to be safe
        if [ -x "$dir/clean-all" ]; then :; fi
        src_crl="$dir/keys/crl.pem"
        if [ ! -f "$src_crl" ]; then
            log_warn 'CRL not found after revoke; attempting to regenerate via index.txt processing.'
        fi
    fi

    if [ ! -f "$src_crl" ]; then
        log_error "CRL source not found at: $src_crl"
        return 20
    fi

    local dest_dir
    dest_dir="$(dirname "$dest_crl")"
    if [ ! -d "$dest_dir" ]; then
        run_cmd mkdir -p "$dest_dir"
    fi
    run_cmd cp -f "$src_crl" "$dest_crl"
    run_cmd chmod 640 "$dest_crl"
    if command -v chown >/dev/null 2>&1; then
        run_cmd chown root:root "$dest_crl"
    fi
    log_info "CRL deployed to $dest_crl"
}

reload_openvpn_service() {
    local explicit_service="$1"
    if ! command -v systemctl >/dev/null 2>&1; then
        log_warn 'systemctl not available; skip reloading OpenVPN service.'
        return 0
    fi
    local candidates=()
    if [ -n "$explicit_service" ]; then
        candidates+=("$explicit_service")
    else
        candidates+=(
            'openvpn@server'
            'openvpn'
            'openvpn-server@server'
        )
    fi

    local svc
    for svc in "${candidates[@]}"; do
        if systemctl list-unit-files | grep -q "^${svc}\.service"; then
            log_info "Reloading service: $svc"
            if [ "${DRY_RUN:-false}" = true ]; then
                log_info "DRY-RUN: systemctl reload $svc"
                return 0
            fi
            if systemctl reload "$svc"; then
                log_info 'Service reloaded.'
                return 0
            else
                log_warn "Failed to reload $svc; trying next candidate if any."
            fi
        fi
    done
    log_warn 'No OpenVPN service reloaded (none matched or reload failed).'
}

main() {
    local USERNAME='' EASYRSA_DIR_DETECTED='' EASYRSA_VERSION='unknown'
    local SERVICE_NAME='' CRL_PATH='/etc/openvpn/crl.pem'
    VERBOSE=false
    DRY_RUN=false
    local AUTO_YES=false

    # Parse args
    while [ $# -gt 0 ]; do
        case "$1" in
        -h | --help)
            usage
            exit 0
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -y | --yes)
            AUTO_YES=true
            shift
            ;;
        --easyrsa-dir)
            [ $# -ge 2 ] || {
                log_error '--easyrsa-dir requires a PATH'
                exit 2
            }
            EASYRSA_DIR_OVERRIDE="$2"
            shift 2
            ;;
        --crl-path)
            [ $# -ge 2 ] || {
                log_error '--crl-path requires a PATH'
                exit 2
            }
            CRL_PATH="$2"
            shift 2
            ;;
        --service)
            [ $# -ge 2 ] || {
                log_error '--service requires a NAME'
                exit 2
            }
            SERVICE_NAME="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        -*)
            log_error "Unknown option: $1"
            usage
            exit 2
            ;;
        *)
            if [ -z "$USERNAME" ]; then USERNAME="$1"; else
                log_error 'Multiple usernames provided.'
                exit 2
            fi
            shift
            ;;
        esac
    done

    if [ -z "$USERNAME" ]; then
        usage
        exit 2
    fi

    ensure_root
    validate_username "$USERNAME"
    ensure_prereqs

    if ! EASYRSA_DIR_DETECTED="$(detect_easyrsa_dir)"; then
        log_error 'Failed to locate easy-rsa directory. Use --easyrsa-dir PATH.'
        exit 3
    fi
    log_info "Using easy-rsa dir: $EASYRSA_DIR_DETECTED"

    if ! EASYRSA_VERSION="$(detect_easyrsa_version "$EASYRSA_DIR_DETECTED")"; then
        log_error 'Failed to detect easy-rsa version.'
        exit 4
    fi
    log_info "Detected easy-rsa $EASYRSA_VERSION"

    if ! find_user_cert_path "$EASYRSA_DIR_DETECTED" "$EASYRSA_VERSION" "$USERNAME" >/dev/null 2>&1; then
        log_error "Certificate for user '$USERNAME' not found."
        exit 5
    fi

    # Backup index and keys/pki
    local ts backup_dir
    ts="$(date '+%Y%m%d-%H%M%S')"
    backup_dir="/var/backups/easy-rsa-revoke-$ts"
    log_info "Creating backup at $backup_dir"
    if [ "$EASYRSA_VERSION" = 'v3' ]; then
        run_cmd mkdir -p "$backup_dir" && run_cmd cp -a "$EASYRSA_DIR_DETECTED/pki/index.txt" "$backup_dir/index.txt" 2>/dev/null || true
    else
        run_cmd mkdir -p "$backup_dir" && run_cmd cp -a "$EASYRSA_DIR_DETECTED/keys/index.txt" "$backup_dir/index.txt" 2>/dev/null || true
    fi

    # Revoke
    if [ "$EASYRSA_VERSION" = 'v3' ]; then
        if [ "$AUTO_YES" = true ]; then
            log_info "Revoking (v3) user: $USERNAME (batch)"
            (cd "$EASYRSA_DIR_DETECTED" && run_cmd ./easyrsa --batch revoke "$USERNAME")
        else
            log_info "Revoking (v3) user: $USERNAME"
            (cd "$EASYRSA_DIR_DETECTED" && run_cmd ./easyrsa revoke "$USERNAME")
        fi
    else
        log_info "Revoking (v2) user: $USERNAME"
        if [ "$AUTO_YES" = true ]; then
            (cd "$EASYRSA_DIR_DETECTED" && run_cmd bash -c 'source ./vars && yes | ./revoke-full "$0"' "$USERNAME")
        else
            (cd "$EASYRSA_DIR_DETECTED" && run_cmd bash -c 'source ./vars && ./revoke-full "$0"' "$USERNAME")
        fi
    fi

    generate_and_deploy_crl "$EASYRSA_DIR_DETECTED" "$EASYRSA_VERSION" "$CRL_PATH"

    reload_openvpn_service "$SERVICE_NAME"

    log_info 'Finish.'
}

main "$@"
