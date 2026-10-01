#!/usr/bin/env bash
set -euo pipefail

profile=${1:-${REDFLAKE_PROFILE:-full}}
commands=(git curl jq rg fzf tmux vim)
case "$profile" in
    core) ;;
    web) commands+=(dirb nmap) ;;
    ad) commands+=(nxc responder kerbrute evil-winrm nmap xfreerdp ligolo-proxy proxychains4 sshuttle python3) ;;
    full|default) commands+=(dirb nmap nxc responder kerbrute evil-winrm xfreerdp ligolo-proxy proxychains4 sshuttle hydra hashcat john msfconsole python3) ;;
    *) echo "Unknown profile: $profile" >&2; exit 1 ;;
esac
for command in "${commands[@]}"; do
    command -v "$command" >/dev/null || { echo "Missing executable: $command" >&2; exit 1; }
done
git --version
curl --version >/dev/null
jq --version
if [[ "$profile" == ad || "$profile" == full || "$profile" == default ]]; then
    python3 -c 'import impacket, pwnlib, certipy; print("Python imports OK")'
fi
printf 'Smoke checks passed: %s\n' "$profile"
