#!/usr/bin/env bash
set -euo pipefail

get_pacman() {
    local pm
    for pm in apt-get dnf yum; do
        if command -v "$pm" >/dev/null 2>&1; then
            printf '%s\n' "$pm"
            return
        fi
    done
    echo "Unsupported host: install Nix manually (see README.md)." >&2
    return 1
}

install_misc() {
    case "$1" in
        apt-get)
            sudo apt-get update
            sudo apt-get install -y curl git ca-certificates
            ;;
        dnf|yum) sudo "$1" install -y curl git ca-certificates ;;
        *) echo "Unsupported package manager: $1" >&2; return 1 ;;
    esac
}

load_nix() {
    local profile
    if command -v nix >/dev/null 2>&1; then return; fi
    for profile in /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
        "$HOME/.nix-profile/etc/profile.d/nix.sh"; do
        if [[ -r "$profile" ]]; then
            # Installer-managed profile scripts may reference unset variables.
            set +u
            # shellcheck disable=SC1090
            source "$profile"
            set -u
            command -v nix >/dev/null 2>&1 && return
        fi
    done
    return 1
}

install_nix() {
    if load_nix; then
        echo "Nix already installed."
        return
    fi
    local installer
    installer=$(mktemp)
    if ! curl --fail --location --show-error https://nixos.org/nix/install -o "$installer"; then
        rm -f "$installer"
        return 1
    fi
    local status=0
    sh "$installer" --daemon || status=$?
    rm -f "$installer"
    (( status == 0 )) || return "$status"
    if ! load_nix; then
        echo "Nix is not on PATH. Open a new terminal and rerun this script." >&2
        return 1
    fi
}

enable_nix_features() {
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/nix"
    local line='extra-experimental-features = nix-command flakes'
    mkdir -p "$config_dir"
    # Add to existing features; do not replace the user's configuration.
    if ! grep -Fxq "$line" "$config_dir/nix.conf" 2>/dev/null; then
        printf '\n%s\n' "$line" >> "$config_dir/nix.conf"
    fi
}

main() {
    local repo_dir pm
    repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
    if [[ ! -f "$repo_dir/flake.nix" || ! -f "$repo_dir/flake.lock" ]]; then
        echo "Run quickconfig.sh from a complete redflake checkout (see README.md)." >&2
        return 1
    fi
    if (( EUID == 0 )); then
        echo "Run as your normal user; the installer uses sudo when needed." >&2
        return 1
    fi
    pm=$(get_pacman)
    install_misc "$pm"
    install_nix
    enable_nix_features
    printf '\nHost setup complete. In a new terminal:\n  cd %q\n  nix develop\n' "$repo_dir"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
