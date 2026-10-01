# Portable Oh My Zsh shell for redflake

## Purpose and agreed behavior

Redflake provides a familiar AD-first toolkit on fresh or temporary x86_64
Linux machines. The user supplied `zshconfig` and approved automatic entry into
a custom Oh My Zsh shell with all existing profiles. Preserve its Jonathan
theme, three plugins, syntax-highlighting colors, completion preferences, and
choice of Neovim locally and Vim over SSH.

Interactive `nix develop`, including named profiles, enters this configured
zsh. Explicit `nix develop --command ...` runs the requested command without
an automatic shell switch. Exiting the interactive shell returns to the
calling environment. Activation must work from any working directory.

## Architecture and package boundary

Add a shell package in `packages/shell.nix` and a maintained configuration
template in `shell/zshrc`. Adapt that template from the supplied `zshconfig`,
retaining active user preferences and removing unused template comments.
Leave the supplied file available as the original reference.

Use zsh, Oh My Zsh, zsh-syntax-highlighting, Neovim, Pygments, and less from
the existing locked Nixpkgs package set. Vim and Git already belong to core.
Include the shell package and required executable dependencies in every
profile through the existing core group. Export the shell package as
`packages.x86_64-linux.redflake-shell` for targeted builds and checks.

The package contains a generated `.zshrc` in a store directory and a
`redflake-zsh` launcher. Substitute Nix store paths for Oh My Zsh and
syntax-highlighting while building the configuration. The launcher sets
`ZDOTDIR` to the packaged configuration directory and executes the packaged
zsh with arguments forwarded unchanged. Configure a dedicated, empty custom
directory so host Oh My Zsh custom files do not change the selected setup.

Use a shared `shellHook` to execute the launcher only when Bash is interactive.
Noninteractive commands must not execute it or create shell state as a side
effect of the hook. Verify this distinction using actual Nix invocations.
The launcher also permits deliberate startup with
`nix develop --command redflake-zsh`.

## Configuration and startup

Load the Jonathan theme and `colored-man-pages`, `git`, and `colorize` plugins.
Select Pygments explicitly for colorize so an unrelated host Chroma
installation does not change its backend. Disable Oh My Zsh automatic updates
before sourcing it; package updates follow the repository's Nix lock.

Let Oh My Zsh run `compinit` once. Set its completion dump location before
sourcing it, then apply the supplied completion styles. Load the Nix-provided
syntax-highlighting script after other initialization and preserve the supplied
highlighters and color mappings.

Preserve the editor rule: use `vim` when `SSH_CONNECTION` is nonempty and `nvim`
otherwise. Include both commands. Retain access to `$HOME/.local/bin` if it
exists, appending it only if absent so toolkit commands keep their Nix ordering.
Keep existing Git plugin aliases and theme behavior. Add no unrelated theme,
plugin, alias collection, or global shell preference.

Do not write to the host's `.zshrc`, `.zshenv`, Oh My Zsh installation, or login
shell setting. Inherited environment variables remain available. Host-wide zsh
startup files are outside the repository's ownership; the portable configuration
does not provide a security sandbox.

## Writable state

Keep history at `${XDG_STATE_HOME:-$HOME/.local/state}/redflake/zsh/history`.
Keep Oh My Zsh caches and completion dumps under
`${XDG_CACHE_HOME:-$HOME/.cache}/redflake/zsh`.

Configure these paths before Oh My Zsh initializes. Use a completion dump name
that distinguishes the host and zsh version. All profiles share the redflake
history. Preserve Oh My Zsh's default history options and sizes.

Create missing directories during interactive zsh startup, with private
permissions for newly created history directories and files. Do not change
permissions on existing parent directories or the user's shell-wide umask.
Keep every writable path outside the Nix store and outside the checkout.
If state directories cannot be created, report the affected path and stop
custom configuration initialization. The inherited toolkit environment remains
available in zsh. Do not redirect writes to host dotfiles or store paths.

## Verification

Use isolated temporary homes and XDG directories for shell checks. Establish
these behaviors with assertions and an interactive pseudo-terminal where needed:

- Plain interactive `nix develop .#core` reaches zsh, loads the Jonathan theme
  and all three plugins, and returns to its caller after `exit`.
- The generated configuration loads without missing plugin or dependency errors
  and exposes syntax-highlighting and the supplied completion settings.
- Neovim is selected locally and Vim with a simulated SSH connection.
- Host `.zshrc` and `.zshenv` sentinel files are neither sourced nor modified by
  the portable configuration; an existing host Oh My Zsh tree is untouched.
- Writable state follows the requested XDG paths, including paths with spaces;
  first startup creates the needed state and repeated startup reuses it.
- An unwritable state location produces the documented diagnostic without attempts
  to write to the store or host dotfiles.
- A launcher invoked outside the checkout loads the same configuration.
- Explicit `--command` invocations preserve their requested shell and exit
  status, create no interactive shell state, and run existing smoke checks.

Add package configuration checks to `nix flake check`, including zsh syntax
validation and isolated startup assertions. Add the new executable requirements
to every profile's smoke checks. Exercise the interactive Nix startup through a
bounded pseudo-terminal test with a timeout, so a broken startup cannot hang CI.
Run existing bootstrap tests, Bash syntax/ShellCheck checks, flake checks, and
all profile smoke checks. Tests must not contact assessment targets or start
services.

## Documentation and relationship to the script package

Update README setup, profile, and shell documentation with automatic zsh entry,
the launcher, editor behavior, state locations, and the Nix-controlled update
process. Update the zsh wishlist status in `tools.md`.

Keep the Zerologon package as a separate component described in
`2026-10-01-zerologon-package-design.md`. This shell design extends core and web
with the portable shell; the script design's instruction to leave those
profiles unchanged applies only to inclusion of the Zerologon commands.
Preserve the existing default full-toolkit selection.

## Review boundary

The user approved the conversational shell design. This written spec requires
review before the implementation plan is written. Review of the implementation
plan and selection of its execution method precede product code changes.
