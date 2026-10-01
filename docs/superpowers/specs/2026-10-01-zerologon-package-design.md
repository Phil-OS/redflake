# Zerologon script package for redflake

## Purpose and agreed scope

Redflake provides a reproducible, AD-first professional toolkit on fresh or
temporary x86_64 Linux machines. Add the two top-level scripts from
https://github.com/dirkjanm/CVE-2020-1472 as native commands in the existing
`ad` and `full` development shells. The user selected the top-level scripts;
the `relaying/` helpers are outside this change.

Success means the commands work from any working directory with dependencies
supplied by Nix, without manual cloning or pip installation. Packaging validation
must never contact a domain controller.

## Approach

Use a dedicated Nix derivation in `packages/zerologon.nix`, imported by
`flake.nix` and appended to `groups.ad`. This automatically includes it in
`ad`, `full`, and the existing default shell. Keep `core` and `web` unchanged.

Fetching scripts during shell startup would make startup depend on the network
and bypass source pinning. Adding scripts to the existing shared Python
environment would couple their dependencies to pwntools and Certipy. A separate
derivation preserves an explicit boundary and provides a pattern for later
GitHub tools without adding a general packaging framework.

## Source and dependencies

Use `fetchFromGitHub` with the upstream commit resolved at implementation time
and its verified content hash. Record the literal revision and hash in the
derivation; normal builds must never follow a moving branch. Retain the current
Nixpkgs lock and do not update it to add this tool.

Create a dedicated Python environment from the locked Nixpkgs Python package
set, containing Impacket and the package providing `Cryptodome` imports
(`pycryptodomex`). Verify this environment against both scripts. Do not install
dependencies at shell startup or downgrade the shared Python environment.

Preserve upstream script behavior. If the locked dependencies prove
incompatible, identify the failed import/API and propose the smallest explicit
compatibility change before modifying upstream code or adding another source
pin. Packaging success alone does not establish operational compatibility.

## Commands and runtime behavior

Install only `cve-2020-1472-exploit.py` and `restorepassword.py` under the
package's `share/zerologon` directory. Expose these launchers in `bin`:

- `zerologon-exploit`: execute `cve-2020-1472-exploit.py`.
- `zerologon-restore`: execute `restorepassword.py`.

Launchers use absolute store paths to their interpreter and script, forward
arguments unchanged, preserve the caller's working directory, and propagate
the script's exit status. Clear ambient `PYTHONPATH` and `PYTHONHOME` and disable
user site packages before invoking the packaged interpreter, whose Nix wrapper
supplies its own dependency paths.
Launchers do not introduce prompts, services, automatic exploitation, or
automatic restoration.

The exploit's no-argument invocation prints usage and returns status 1.
Restoration supports `-h` through argparse. Preserve those behaviors and make
verification handle their expected statuses explicitly.

## Validation

Add package build checks that compile both Python files and import them under
non-main module names with the package interpreter. Static inspection confirms
that their network actions are guarded by their main entry points. Disable
bytecode writes during import checks and use a writable temporary directory
for compilation output.

Extend `scripts/smoke.sh` for `ad` and `full` to check both command paths and
invoke only the exploit with zero arguments and restoration with `-h`. Require
usage text and exit status 1 for the former and help text and status 0 for the
latter. No target arguments are supplied. Execute the launchers from a temporary
working directory to verify independence from the repository directory.

Verify isolation by repeating these harmless invocations with a temporary
`PYTHONPATH` containing an Impacket module that raises an error on import.
Successful usage/help output demonstrates that ambient modules are ignored.

Expose the derivation as `packages.x86_64-linux.zerologon` and reference it in
`checks.x86_64-linux.zerologon` so `nix flake check` realizes its build checks.
Run the existing bootstrap tests, shell syntax/ShellCheck validation, flake
checks, and all four profile smoke checks. These establish packaging and CLI
startup, not successful exploitation or restoration.

## Documentation

Update README profile/tool documentation and describe the two command names,
upstream source, source pinning, isolated dependencies, and verification limits.
Add this repository and its packaging status to `tools.md` without implementing
other wishlist entries.

Document upstream's material behavior: the exploit resets a domain controller's
machine-account password and can disrupt communication with other domain
controllers. The restoration script requires the original password; restoration
is not guaranteed by including the helper. Do not describe this as a passive
vulnerability checker or include a live-target verification procedure.

## Review boundary

This document describes the proposed implementation. The brainstorming workflow
requires review of this written spec, then review of an implementation plan and
selection of its execution method, before product code changes begin.
