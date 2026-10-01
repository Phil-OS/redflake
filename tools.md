# redflake tool inventory

Delivered means available in the named x86_64 Linux profile and covered by
installation/startup checks. Target operations, privileges, graphical rendering
and host services remain outside those checks. `all` means core, web, ad, gui
and full/default. Every tool retains its own license. Nixpkgs sources follow
the exact revision in `flake.lock`.

| Tool / command | Purpose | Profile | Source | Status |
| --- | --- | --- | --- | --- |
| Git (`git`) | Version control | all | Nixpkgs `git` | Delivered |
| curl | HTTP/file transfer | all | Nixpkgs `curl` | Delivered |
| jq | JSON processing | all | Nixpkgs `jq` | Delivered |
| ripgrep (`rg`) | Text search | all | Nixpkgs `ripgrep` | Delivered |
| fzf | Interactive selection | all | Nixpkgs `fzf` | Delivered |
| tmux | Terminal sessions | all | Nixpkgs `tmux` | Delivered |
| Vim / Neovim (`vim`, `nvim`) | Editing | all | Nixpkgs `vim`, `neovim` | Delivered |
| zsh / `redflake-zsh` | Portable Oh My Zsh, Jonathan theme, interactive startup | all | Local `packages/shell.nix`; locked Nixpkgs zsh, Oh My Zsh and syntax highlighting | Delivered |
| Pygments (`pygmentize`) | Syntax coloring | all | Nixpkgs `python3Packages.pygments` | Delivered |
| less / man | Paging and documentation | all | Nixpkgs `less`, `man-db` | Delivered |
| OpenSSH (`ssh`, `scp`, `sftp`, `ssh-keygen`, `ssh-agent`, `ssh-add`) | SSH clients and key management | all | Nixpkgs `openssh` | Delivered |
| Nmap / Ncat (`nmap`, `ncat`) | Network assessment and connections | all | Nixpkgs `nmap` | Delivered |
| dig | DNS queries | all | Nixpkgs `dig` | Delivered |
| FreeRDP (`xfreerdp`) | Remote desktop client | ad, full | Nixpkgs `freerdp` | Delivered; graphical session required |
| Ligolo-ng (`ligolo-proxy`) | Network tunneling | ad, full | Nixpkgs `ligolo-ng` | Delivered |
| proxychains (`proxychains4`) | Proxy routing | ad, full | Nixpkgs `proxychains` | Delivered |
| sshuttle | SSH-based routing | ad, full | Nixpkgs `sshuttle` | Delivered |
| NetExec (`nxc`) | Network/AD assessment | ad, full | Nixpkgs `netexec` | Delivered |
| Responder (`responder`) | Network authentication assessment | ad, full | Nixpkgs `responder` | Delivered |
| Kerbrute (`kerbrute`) | Kerberos assessment | ad, full | Nixpkgs `kerbrute` | Delivered |
| Evil-WinRM (`evil-winrm`) | WinRM client | ad, full | Nixpkgs `evil-winrm` | Delivered |
| BloodHound CE Python (`bloodhound-ce-python`) | Community Edition AD collector | ad, full | Local `packages/bloodhound-ce-python.nix`; [PyPI bloodhound-ce 1.9.1](https://pypi.org/project/bloodhound-ce/1.9.1/) / [upstream](https://github.com/dirkjanm/BloodHound.py) | Delivered; pinned source/hash, isolated wrapper |
| bloodyAD (`bloodyAD`) | AD administration/assessment | ad, full | Nixpkgs `python3Packages.bloodyad` via `toPythonApplication` | Delivered |
| ldapdomaindump | LDAP inventory | ad, full | Nixpkgs `ldapdomaindump` | Delivered |
| enum4linux-ng | SMB/RPC enumeration | ad, full | Nixpkgs `enum4linux-ng` | Delivered |
| MIT Kerberos (`kinit`, `klist`, `kdestroy`) | Kerberos ticket clients | ad, full | Nixpkgs `krb5` | Delivered |
| OpenLDAP (`ldapsearch`) | LDAP client | ad, full | Nixpkgs `openldap` | Delivered |
| Samba (`smbclient`, `rpcclient`) | SMB/RPC clients | ad, full | Nixpkgs `samba` | Delivered |
| tcpdump | Packet capture | ad, full | Nixpkgs `tcpdump` | Delivered; capture privileges are host-managed |
| tshark | Terminal packet analysis | ad, full | Nixpkgs `wireshark-cli` | Delivered |
| Impacket suite | Protocol clients and Python library | ad, full | Shared Python environment, Nixpkgs `python3Packages.impacket` | Delivered |
| Certipy AD | AD certificate assessment and Python library | ad, full | Shared Python environment, Nixpkgs `python3Packages.certipy-ad` | Delivered |
| pwntools | Python assessment utilities | ad, full | Shared Python environment, Nixpkgs `python3Packages.pwntools` | Delivered |
| dirb | Web content discovery | web, gui, full | Nixpkgs `dirb` | Delivered |
| ffuf | Web fuzzing | web, gui, full | Nixpkgs `ffuf` | Delivered |
| sqlmap | SQL injection assessment | web, gui, full | Nixpkgs `sqlmap` | Delivered |
| Burp Suite (`burpsuite`) | Web proxy GUI | gui only | Nixpkgs `burpsuite` wrapper | Delivered; launch needs a graphical session; no automatic launch |
| SecLists | Read-only wordlists | web, ad, gui, full | Nixpkgs `seclists`; `$REDFLAKE_SECLISTS` = package `share/wordlists/seclists` | Delivered; copy modified data to your working directory |
| Hydra (`hydra`) | Authentication assessment | full | Nixpkgs `thc-hydra` | Delivered |
| Hashcat (`hashcat`) | Password recovery | full | Nixpkgs `hashcat` | Delivered; GPU setup is host-managed |
| John (`john`) | Password recovery | full | Nixpkgs `john` | Delivered |
| Metasploit (`msfconsole`) | Assessment framework | full | Nixpkgs `metasploit` | Delivered; services are not started |

Remaining wishlist entries are retained here; they are not included by these
profiles. Names correct the original `logolo-ng` to Ligolo-ng and
`openldap-clients` to the provided OpenLDAP clients. dirb and DirBuster are
distinct tools.

| Tool | Purpose | Profile | Source | Status |
| --- | --- | --- | --- | --- |
| FTP client (`ftp`) | FTP transfers | None | Package not selected | Wishlist; unimplemented |
| Remmina | Graphical remote desktop | None | Package not selected | Wishlist; unimplemented |
| DirBuster | Graphical web content discovery | None | Package not selected | Wishlist; unimplemented |
| Zerologon | Requested assessment tool | None | Requested upstream repository; no local package | Pending; unimplemented |
