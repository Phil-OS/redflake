#!/usr/bin/env bash
set -euo pipefail

profile=${1:-${REDFLAKE_PROFILE:-full}}
commands=(git curl jq rg fzf tmux vim redflake-zsh zsh nvim pygmentize less man ssh scp sftp ssh-keygen ssh-agent ssh-add nmap ncat dig)
ad_commands=(bloodhound-ce-python bloodyAD ldapdomaindump enum4linux-ng kinit klist kdestroy ldapsearch smbclient rpcclient tcpdump tshark)
web_commands=(dirb ffuf sqlmap)
case "$profile" in
    core) ;;
    web) commands+=("${web_commands[@]}") ;;
    gui) commands+=("${web_commands[@]}" burpsuite) ;;
    ad) commands+=(nxc responder kerbrute evil-winrm xfreerdp ligolo-proxy proxychains4 sshuttle python3 "${ad_commands[@]}") ;;
    full|default) commands+=(nxc responder kerbrute evil-winrm xfreerdp ligolo-proxy proxychains4 sshuttle hydra hashcat john msfconsole python3 "${ad_commands[@]}" "${web_commands[@]}") ;;
    *) echo "Unknown profile: $profile" >&2; exit 1 ;;
esac
for command in "${commands[@]}"; do
    command -v "$command" >/dev/null || { echo "Missing executable: $command" >&2; exit 1; }
done
if [[ "$profile" != core ]]; then
    if [[ -z "${REDFLAKE_SECLISTS:-}" || ! -r "$REDFLAKE_SECLISTS/Discovery/Web-Content/common.txt" || ! -s "$REDFLAKE_SECLISTS/Discovery/Web-Content/common.txt" ]]; then
        echo "Missing or unreadable SecLists common.txt: ${REDFLAKE_SECLISTS:-<unset>}" >&2
        exit 1
    fi
fi
git --version
curl --version >/dev/null
jq --version
ssh -V
ncat --version
dig -v

# Packaged Python applications must start promptly without contacting a target.
python_startup_check() {
    if ! timeout 15 "$@" >/dev/null; then
        echo "Startup check failed or timed out: $1" >&2
        exit 1
    fi
}

if [[ "$profile" == ad || "$profile" == full || "$profile" == default ]]; then
    python3 -c 'import impacket, pwnlib, certipy; print("Python imports OK")'
    python_startup_check bloodhound-ce-python -h
    python_startup_check bloodyAD --help
    python_startup_check ldapdomaindump -h
    python_startup_check enum4linux-ng -h
    klist -V
    smbclient --version
    rpcclient --version
    tcpdump --version
    tshark --version
fi
if [[ "$profile" == web || "$profile" == gui || "$profile" == full || "$profile" == default ]]; then
    ffuf -V
    python_startup_check sqlmap --version
fi
printf 'Smoke checks passed: %s\n' "$profile"
