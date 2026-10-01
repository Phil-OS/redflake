# AD-first tool expansion for redflake

## Purpose and agreed scope

The user primarily works with Active Directory and wants a smaller web toolkit
available when needed. Expand the existing profiles with the agreed AD tools,
protocol clients, packet inspection, web tools and wordlists. The user explicitly
added the OpenSSH client and Ncat and selected BloodHound Community Edition.

This is the third work item alongside the approved portable-zsh and Zerologon
plans. The user requested both a design and an implementation plan before
execution; prepare them together for review. No product implementation is
authorized by these documents until the execution handoff is complete.

## Packaging approach and source evidence

Use applications supplied by the existing locked Nixpkgs wherever possible,
plus one local derivation for the CE Python collector. This minimizes custom
packaging while preserving reproducibility and per-application dependencies.
A single expanded Python environment would couple unrelated tools; maintaining
custom copies of all packages would duplicate Nixpkgs maintenance.

Read-only evaluation confirmed the package attributes below against Nixpkgs
revision `78e9c786dc08cd4f3420c2395cd977206a9b1da2`. Its source is already cached
in this workspace. Package availability was evaluated; the additional tools
have not been built or operationally tested.

Ncat exists at `bin/ncat` in the cached Nmap 7.99 package. Supply it through
`pkgs.nmap`; do not substitute an unrelated `nc` implementation or add an alias
that changes its identity. Move Nmap into core so Ncat is available in all
profiles, then remove redundant direct Nmap entries elsewhere.

| Requested tool | Package expression | Required commands or assets |
| --- | --- | --- |
| OpenSSH client | `pkgs.openssh` | `ssh`, `scp`, `sftp`, `ssh-keygen`, `ssh-agent`, `ssh-add` |
| Ncat and Nmap | `pkgs.nmap` | `ncat`, `nmap` |
| DNS utilities | `pkgs.dig` | `dig` |
| MIT Kerberos clients | `pkgs.krb5` | `kinit`, `klist`, `kdestroy` |
| LDAP client | `pkgs.openldap` | `ldapsearch` |
| SMB/RPC clients | `pkgs.samba` | `smbclient`, `rpcclient` |
| BloodHound CE Python collector | Local `packages/bloodhound-ce-python.nix` | `bloodhound-ce-python` |
| bloodyAD | `pkgs.python3Packages.toPythonApplication pkgs.python3Packages.bloodyad` | `bloodyAD` |
| ldapdomaindump | `pkgs.ldapdomaindump` | `ldapdomaindump` |
| enum4linux-ng | `pkgs.enum4linux-ng` | `enum4linux-ng` |
| Packet capture | `pkgs.tcpdump` | `tcpdump` |
| Terminal packet analysis | `pkgs.wireshark-cli` | `tshark` |
| Web fuzzing | `pkgs.ffuf` | `ffuf` |
| SQL injection assessment | `pkgs.sqlmap` | `sqlmap` |
| Web proxy GUI | `pkgs.burpsuite` | `burpsuite` |
| Wordlists | `pkgs.seclists` | `share/wordlists/seclists` |

Package outputs may also contain server binaries, but the flake starts no
servers, agents, listeners or captures, and changes no host service configuration.
Retain the existing shared Python environment for Impacket, pwntools and Certipy.
New Python applications use their own packaged wrappers.

## BloodHound CE collector

The locked `pkgs.bloodhound-py` is the legacy collector. Do not use it for CE
and do not add `pkgs.bloodhound-ce`, which is a different application rather
than the selected Python collector. Upstream distinguishes the CE command
`bloodhound-ce-python` from legacy `bloodhound-python`:
https://github.com/dirkjanm/BloodHound.py#installation

Build the CE collector as a Python application using the published
`bloodhound-ce` 1.9.1 source distribution. Its release page records SHA-256
`083df3dc3ad998edcff8fb63fdd8f5b464aab5fdac8e05cc9b3b6520210f79ab`:
https://pypi.org/project/bloodhound-ce/1.9.1/

Use `fetchPypi` with source name `bloodhound_ce`, version `1.9.1` and SRI hash
`sha256-CD3z3DrZmO3P+Ptj/dj1tGSqtf2sjgXMmztlICEPeas=`. Build with setuptools
and the locked Python packages `dnspython`, `impacket`, `ldap3`, `pyasn1` and
`pycryptodome`. Validate these against the actual published source during
implementation. Include the application in AD/full only; install neither a
standalone legacy collector nor the BloodHound server, databases or GUI.

Export it as `packages.x86_64-linux.bloodhound-ce-python` and reference its
checked derivation from `checks.x86_64-linux.bloodhound-ce-python`. Verify
imports and CLI help without supplying a domain or credentials. Never install
dependencies with pip when entering the shell or follow a moving branch.

## Groups and profiles

Extend existing groups and introduce `inspection`, `assets` and `gui` groups:

- Core gains OpenSSH, Nmap/Ncat and dig, in addition to the portable shell.
- AD gains the CE collector, bloodyAD, ldapdomaindump, enum4linux-ng, Kerberos,
  LDAP and SMB/RPC clients.
- Inspection contains tcpdump and wireshark-cli; include it in AD/full.
- Web gains ffuf and sqlmap while retaining dirb.
- Assets contains SecLists; include it in AD, web, GUI and full.
- GUI contains Burp Suite, exposed in a new optional `gui` profile.

| Profile | Resulting scope |
| --- | --- |
| `core` | Shared utilities, OpenSSH, Nmap/Ncat, DNS and portable zsh |
| `ad` | Core, existing AD/network/Python tools, new AD clients/collector, inspection, SecLists, Zerologon |
| `web` | Core, dirb, ffuf, sqlmap and SecLists |
| `gui` | Web profile plus Burp Suite, with portable zsh |
| `full` / default | All terminal groups, shared Python and Zerologon; preserves every original tool |

Exclude the new GUI group from full's group flattening. Burp remains available
with explicit `nix develop .#gui` rather than becoming a mandatory download
for default/headless sessions. Preserve the interactive-only zsh startup
hook for every profile and the explicit `--command` behavior.

The GUI package is included and realized but never started by shell activation
or CI. Document that launching it needs a graphical session. No Remmina or
graphical Wireshark addition is part of this expansion.

## Wordlist location and mutable settings

Expose `REDFLAKE_SECLISTS` in profiles that include the asset group, pointing
to `${pkgs.seclists}/share/wordlists/seclists`. Example usage in documentation:
`ls "$REDFLAKE_SECLISTS/Discovery/Web-Content"`.

Verify that `Discovery/Web-Content/common.txt` is readable and nonempty.
Keep wordlists read-only in the store; outputs and modified copies belong
in the user's working directory. Do not copy them into `/usr/share` or the
user's home at startup. Core must not acquire a SecLists dependency just
because other shells expose that variable.

Leave SSH keys/configuration, Kerberos realm configuration and ticket cache
selection, DNS and capture privileges under the user's existing control.
Do not write host configuration or request credentials during validation.

## Validation and documentation

Extend the existing smoke script, using the real command names in the table.
Check core commands on every profile; run the new AD checks only on AD/full,
web checks only on web/GUI/full, asset checks on AD/web/GUI/full, and Burp
executable availability only on GUI.

Use safe CLI versions/help, including `ssh -V`, `ncat --version`, `dig -v`,
`klist -V`, `smbclient --version`, `rpcclient --version`, `tcpdump --version`,
`tshark --version`, `bloodhound-ce-python -h`, `bloodyAD --help`,
`ldapdomaindump -h`, `enum4linux-ng -h`, `ffuf -V` and `sqlmap --version`.
Do not run default LDAP searches, ticket initialization/destruction, captures,
scans, collection, or GUI launch as a check.

Before choosing any help/version flag, inspect the pinned source to confirm
its handling precedes network actions. Apply timeouts to Python/GUI-related
packaging checks. Burp gets a command-path check, not an automated GUI launch.

CI realizes and smoke-tests `core`, `web`, `ad`, `gui`, `full`; the existing
interactive integration runner also exercises GUI. Run the bootstrap tests,
syntax/ShellCheck validation, flake checks and shell-startup regressions.
Check representative commands resolve into the profile's Nix package paths,
rather than accidentally accepting host installations. Verify SecLists and
the GUI split under sanitized inherited environments.

Update README with the profile table, CE collector edition, utility command
names, wordlist path, GUI requirements and verification limits. Convert
`tools.md` into an inventory with tool, purpose, profile, source and delivered
status; preserve unimplemented wishlist entries as wishlist entries. The
initial recommendations beyond the agreed list remain outside this change.

## Integration and review boundary

Execute after the approved shell and Zerologon plans. Only this work item
extends their profile coverage with GUI and adds the broader tools; the
already approved shell/script behavior remains intact.

The spec and third plan are presented together because the user explicitly
requested both artifacts before execution. Obtain review of these documents
and selection of the execution method before implementation.
