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

`exit` leaves the shell. Downloads remain cached in the Nix store for reuse.
The first full environment can require substantial download time and disk space.
You can move to other directories to work on engagement files while the toolkit
stays available; its lifetime follows the shell session.

## Profiles and tools

| Profile | Contents |
| --- | --- |
| `core` | Git, curl, jq, ripgrep, fzf, tmux, Vim |
| `web` | Core plus dirb and Nmap |
| `ad` | Core, NetExec, Responder, Kerbrute, Evil-WinRM, network tools, Python environment |
| `full` / default | All groups, including Hydra, Hashcat, John, and Metasploit |

Network tools are Nmap, FreeRDP, Ligolo-ng, proxychains, and sshuttle.
The Python environment contains Impacket, pwntools, and Certipy AD.
`flake.nix` owns the named tool groups and uses `mkShell.packages` for executables.
Add tools to the appropriate group, then run validation before updating the lock.
Unfree packages are allowed by this flake; each tool retains its own license.

```bash
nix develop .#core
nix develop .#web
nix develop .#ad
nix develop .#full
```

Only x86_64 Linux is advertised. ARM Linux, macOS, and native Windows are not
validated targets. WSL needs a Linux environment with working Nix daemon support.

## Shell experience

`nix develop` starts an interactive Bash session with the selected toolkit.
A portable zsh configuration and launcher can be added later to provide a
familiar prompt, aliases, plugins, and keybindings on fresh machines.

## Updating and reproducing an environment

`flake.nix` selects the Nixpkgs release line; `flake.lock` records its exact
revision and content hash. Keep both in Git. Normal use follows the lock file.

```bash
nix flake update nixpkgs
nix flake check --no-update-lock-file
for profile in core web ad full; do
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
nix develop --no-update-lock-file .#full --command bash scripts/smoke.sh full
```

GitHub Actions evaluates the flake, runs ShellCheck and isolated bootstrap
regression tests, then realizes and smoke-tests every profile. Smoke checks
verify executable availability, run basic core commands, and import the Python
libraries. They do not contact targets or establish that every tool's operational
features work. Full-shell realization is separate from `nix flake check` because
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
- **Metasploit and other stateful tools:** databases, credentials, workspaces,
  and service startup remain host/user responsibilities. This flake starts no
  services and isolates no network or filesystem access.

## Why keep a bootstrap script?

The script handles the small, host-specific prerequisites that must exist before
Nix can run. The flake handles the toolkit, and the lock file handles its versions.
Keeping those responsibilities separate makes an existing Nix machine usable
without rerunning host setup and avoids silently replacing local project files.
