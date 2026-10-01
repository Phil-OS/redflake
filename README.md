## Wow, this repo is AI slop!
Rude. But also not entirely wrong- this was an abandoned project of mine, im using it to 
test obra/superpowers and agentic coding assistants. I am intentionally giving the AI
much more control than I would give it over a normal project to help determine
the quality and skill of the toolchain and agents, and figure out where else I may
want to incorperate it into my work.
# redflake

A reproducible red-team toolkit for professional use on fresh or temporary
**x86_64 Linux** machines.
Nix supplies the tools on your existing distribution; NixOS is not required.
The default environment preserves the original full toolkit.

## Setup

Clone the complete repository, including `flake.lock`, instead of downloading
`flake.nix` alone:

```bash
git clone https://github.com/Phil-OS/redflake.git
cd redflake
bash quickconfig.sh
```

Install Git with your host package manager first if it is missing. Run the script
as your normal user. It supports apt-get, dnf, and yum hosts with sudo and a
working multi-user Nix installation environment. It installs curl, Git,
and certificates through the host package manager; installs upstream Nix
in daemon mode if missing; and enables flakes for your user. It respects
`XDG_CONFIG_HOME` for the Nix configuration.
The Nix installer may prompt for confirmation and sudo credentials.

The script can be rerun: it preserves existing Nix configuration and avoids
duplicating the feature settings. Enter the toolkit explicitly with `nix develop`.

**Already ran the old script?** Keep your existing Nix installation and clone
this complete repository. You do not need to reinstall Nix. Rerunning the revised
script repairs missing prerequisites and adds the feature settings if
needed. The old `minipekka` directory is left alone.

For other distributions, install [Nix](https://nix.dev/install-nix) yourself. Enable these Nix
features in `~/.config/nix/nix.conf` (or `$XDG_CONFIG_HOME/nix/nix.conf`):

```ini
extra-experimental-features = nix-command flakes
```

Open a new terminal after installation, then enter the checkout and run:

```bash
nix develop
```

Interactive `nix develop` automatically enters the configured zsh shell.
`exit` returns to your calling environment. Downloads remain cached in the Nix
store for reuse.
The first full environment can require substantial download time and disk space.
You can move to other directories to work on engagement files while the toolkit
stays available; its lifetime follows the shell session.

## Profiles and tools

| Profile | Contents |
| --- | --- |
| `core` | Git, curl, jq, ripgrep, fzf, tmux, Vim, Neovim, portable zsh, Pygments, less, man, OpenSSH, Nmap/Ncat, dig |
| `web` | Core plus dirb, ffuf, sqlmap and SecLists |
| `ad` | Core, NetExec, Responder, Kerbrute, Evil-WinRM, BloodHound CE collector, bloodyAD, ldapdomaindump, enum4linux-ng, Kerberos/LDAP/SMB/RPC clients, network tools, tcpdump, tshark, Python environment and SecLists |
| `gui` | Web profile plus Burp Suite; select explicitly for a graphical session |
| `full` / default | All terminal groups, shared Python and SecLists, including Hydra, Hashcat, John and Metasploit |

Network tools include FreeRDP, Ligolo-ng, proxychains and sshuttle.
OpenSSH supplies `ssh`, `scp`, `sftp`, `ssh-keygen`, `ssh-agent` and `ssh-add`
in every profile. Ncat is `ncat`, supplied by Nmap alongside `nmap`; DNS
queries use `dig`. AD/full also supply `kinit`, `klist`, `kdestroy`,
`ldapsearch`, `smbclient` and `rpcclient`.
The Python environment contains Impacket, pwntools, and Certipy AD.
The selected collector is [BloodHound Community Edition Python 1.9.1](https://pypi.org/project/bloodhound-ce/1.9.1/),
with command `bloodhound-ce-python` in AD/full. Its source is pinned in a local
Nix derivation and its dependencies use the locked Nixpkgs. New Python
applications have isolated packaged wrappers. This installs the CE collector;
the legacy collector and BloodHound server/database are separate applications.
`flake.nix` owns the named tool groups and uses `mkShell.packages` for executables.
Add tools to the appropriate group, then run validation before updating the lock.
Unfree packages are allowed by this flake; each tool retains its own license.

```bash
nix develop .#core
nix develop .#web
nix develop .#ad
nix develop .#gui
nix develop .#full
```

Burp is available only in `gui`, through the Nixpkgs `burpsuite` wrapper. Run
`burpsuite` from that profile when a graphical session/display is available.
Shell activation starts no GUI application. Full/default exclude Burp so
terminal sessions avoid its additional download.

Web, AD, GUI and full export `REDFLAKE_SECLISTS`, pointing to the selected
package's `/nix/store/...-seclists-.../share/wordlists/seclists` directory:

```bash
ls "$REDFLAKE_SECLISTS/Discovery/Web-Content"
```

Wordlists are read-only Nix store assets. Put outputs and modified copies in
your working directory. Core does not include these assets or set the variable.
SSH keys/configuration, Kerberos realms/ticket caches and tool settings remain
under your control. See [the tool inventory](tools.md) for package sources and
pending wishlist entries.

Only x86_64 Linux is advertised. ARM Linux, macOS, and native Windows are not
validated targets. WSL needs a Linux environment with working Nix daemon support.

## Shell experience

Interactive `nix develop`, with any profile, enters the packaged Oh My Zsh
configuration with the Jonathan theme and `colored-man-pages`, `git`, and
`colorize` plugins. It includes the supplied completion preferences and syntax
highlighting. Colorize uses Pygments. `EDITOR` is `nvim` locally and `vim` when
`SSH_CONNECTION` is set.

Your host `.zshrc`, `.zshenv`, Oh My Zsh installation, and login shell stay
untouched. The launcher selects the packaged configuration through `ZDOTDIR`;
host-wide zsh startup files still apply. An existing `~/.local/bin` remains
available after the toolkit commands on PATH.

Explicit commands keep their requested shell and exit status, without starting
zsh or creating its interactive state. You can also start zsh deliberately with
the `redflake-zsh` launcher, from any working directory:

```bash
nix develop .#core --command bash -c 'git --version'
nix develop .#core --command redflake-zsh
# Outside the checkout, use its absolute path:
nix develop /absolute/path/to/redflake#core --command redflake-zsh
```

All profiles share history at
`${XDG_STATE_HOME:-$HOME/.local/state}/redflake/zsh/history`. Oh My Zsh caches
and completion dumps live under
`${XDG_CACHE_HOME:-$HOME/.cache}/redflake/zsh`. Startup creates missing state
directories and makes new history directories and files private. If a state
path cannot be created, startup reports that path and stops custom configuration
initialization; the toolkit remains available in zsh.

Oh My Zsh self-updates are disabled. Update zsh, its plugins, and the rest of
the toolkit through the Nix lock update process below.

## Updating and reproducing an environment

`flake.nix` selects the Nixpkgs release line; `flake.lock` records its exact
revision and content hash. Keep both in Git. Normal use follows the lock file.

```bash
nix flake update nixpkgs
nix flake check --no-update-lock-file
for profile in core web ad gui full; do
  nix build --no-update-lock-file --no-link ".#devShells.x86_64-linux.$profile"
  nix develop --no-update-lock-file ".#$profile" --command bash scripts/smoke.sh "$profile"
done
git diff -- flake.lock
```

Review and commit the lock update after validation. Changing release lines also
requires editing `inputs.nixpkgs.url`. Restore the previous flake and lock file
from Git to return to an earlier package set; writable tool state is not rolled
back. When adding new files used by the flake, stage them in Git before using
Git-backed flake commands: Nix omits untracked files from that source snapshot.

## Validation

```bash
python3 -B -m unittest discover -s tests -v
bash -n quickconfig.sh scripts/smoke.sh
nix flake check --no-update-lock-file
for profile in core web ad gui full; do
  nix build --no-update-lock-file --no-link ".#devShells.x86_64-linux.$profile"
  env -u DISPLAY -u WAYLAND_DISPLAY HOME="$(mktemp -d)" \
    timeout 45 nix --extra-experimental-features 'nix-command flakes' develop --no-update-lock-file ".#$profile" --command bash scripts/smoke.sh "$profile"
done
python3 tests/check_nix_shell.py --flake "$PWD"
```

GitHub Actions evaluates the flake, runs ShellCheck and isolated bootstrap
regression tests and packaged zsh startup checks, then realizes and smoke-tests
all five profiles. Smoke checks run with a temporary HOME and no display,
with a timeout after each profile is realized. A bounded PTY test verifies
automatic zsh entry for all profiles and the default, explicit command behavior,
and startup outside the checkout. It also checks that GUI resolves Burp to its
Nix wrapper and that full excludes it under a sanitized inherited PATH and in
its declared package list. Burp gets only a command-path check; validation never
launches Burp or Java. Smoke checks verify executable availability, harmless
help/version startup, read-only wordlist availability and Python imports. They
do not contact targets, test GUI rendering or establish that every tool's
operational features work. Shell realization is separate from `nix flake check` because
evaluating a shell does not build its complete dependency closure.

## Host requirements and troubleshooting

- **Nix not found after installation:** open a new terminal to load the Nix
  profile. The bootstrap also attempts to load existing installer profile scripts.
- **Flakes disabled:** check your user Nix config and any `NIX_CONFIG` or
  `NIX_USER_CONF_FILES` overrides. The script preserves existing experimental
  features and adds `nix-command flakes`.
- **Permission failures:** raw packet operations, packet capture, tunnels, and
  privileged ports can require host privileges or capabilities. Nix does not
  grant them; sudo may also reset PATH. Configure privileges on the host for the
  specific operation rather than running the entire environment as root.
- **Hashcat GPU support:** requires compatible host GPU drivers and compute
  runtimes. Installing the executable does not configure the GPU.
- **FreeRDP:** requires access to a graphical session. A successful package build
  does not provide a display server.
- **Burp Suite:** enter `nix develop .#gui` and use a working graphical session
  before launching `burpsuite`. It is absent from full/default and is never
  launched automatically.
- **Metasploit and other stateful tools:** databases, credentials, workspaces,
  and service startup remain host/user responsibilities. This flake starts no
  services and isolates no network or filesystem access.

## Why keep a bootstrap script?

The script handles the small, host-specific prerequisites that must exist before
Nix can run. The flake handles the toolkit, and the lock file handles its versions.
Keeping those responsibilities separate makes an existing Nix machine usable
without rerunning host setup and avoids silently replacing local project files.
