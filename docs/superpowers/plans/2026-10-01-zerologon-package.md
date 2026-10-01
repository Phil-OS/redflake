# Zerologon Package Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the two selected top-level upstream scripts available as pinned native commands in redflake's AD/full profiles.

**Architecture:** Fetch one immutable upstream revision, install only the selected scripts, and launch them with a dedicated Nix Python environment. Package checks exercise imports and harmless CLI handling, then existing profile smoke checks verify delivery.

**Tech Stack:** Nix flakes, Python 3, Impacket, pycryptodomex, Python unittest, Bash.

**Spec:** `docs/superpowers/specs/2026-10-01-zerologon-package-design.md`

## Global Constraints

- Support x86_64 Linux; retain the existing Nixpkgs lock and shared Python environment.
- Source: `https://github.com/dirkjanm/CVE-2020-1472`; use a literal commit and verified content hash.
- Install only `cve-2020-1472-exploit.py` and `restorepassword.py`; exclude `relaying/` helpers.
- Commands: `zerologon-exploit` and `zerologon-restore`; profiles: `ad`, `full`, default.
- Preserve upstream arguments, working directory and exit status.
- Clear ambient `PYTHONPATH`/`PYTHONHOME`; disable user site packages.
- No live-target checks, runtime dependency downloads, automatic exploitation or restoration.
- Exploit with zero arguments: usage and status 1. Restoration with `-h`: help and status 0.
- Checks establish packaging/startup, not operational exploitation or restoration.

## Review Focus

- Ambient Python modules: poisoned `PYTHONPATH` must not replace packaged dependencies (Task 1).
- Host Python configuration: poisoned `PYTHONHOME` and user site packages must not affect commands (Task 1).
- Different working directories, including spaces: command startup must not depend on the checkout (Task 1).
- Legacy API imports: both scripts must import with the locked dependencies without network activity (Task 1).
- Expected nonzero usage status: smoke checks must accept only the exploit's documented status 1 (Task 2).

## File Structure and Execution Order

- `packages/zerologon.nix`: source pin, dedicated interpreter, installed scripts, wrappers and install checks.
- `tests/check_zerologon.py`: explicit package-level unittest runner, excluded from bootstrap test discovery.
- `flake.nix`: package/check outputs and inclusion in `groups.ad`.
- `scripts/smoke.sh`: AD/full command and harmless CLI checks.
- `README.md`, `tools.md`: commands, source, behavior and verification limits.

Execute after `2026-10-01-portable-zsh.md`. Preserve that plan's exports, checks, core dependencies, shell hook and documentation when modifying shared files. The package can be built independently, but integration changes are sequential.

## Preflight

- [ ] Read both the spec and current shared files. Keep the shell implementation intact. Use the existing isolated execution checkout if present. Do not stage unrelated user files.
- [ ] Select the existing Nix runtime as described in the shell plan. Resolve the upstream commit once with `git ls-remote https://github.com/dirkjanm/CVE-2020-1472.git refs/heads/master`; fetch and inspect the two scripts at that literal revision. Calculate the unpacked source hash with Nix's source-prefetch tools and verify it in a fixed-output build. Record literal values in the derivation; do not commit a fake hash or a branch reference.

### Task 1: Package the selected scripts with isolated Python dependencies

**Files:** Create `packages/zerologon.nix`, `tests/check_zerologon.py`; modify `flake.nix` package/check outputs only.

**Interfaces:**
- Consumes: `packages/zerologon.nix` takes `{ pkgs }` from locked Nixpkgs.
- Produces: derivation `zerologonPackage`, output `packages.x86_64-linux.zerologon`, wrappers `$out/bin/zerologon-exploit` and `$out/bin/zerologon-restore`, source files under `$out/share/zerologon`.
- Test CLI: package interpreter executes `tests/check_zerologon.py --package /absolute/store/output`; exit 0 means all cases passed.
- Test helper: `run_command(name: str, args: list[str], env_overrides: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]`; captures stdout/stderr with a 10-second timeout and a temporary cwd containing spaces.

- [ ] **Write `ZerologonPackageTests`.** Supply its package root through argparse. Use temporary HOME and cwd for every case. Include these named tests and assertions:

```python
# test_exploit_usage_without_target
self.assertEqual(result.returncode, 1)
self.assertIn("Usage:", result.stdout)
self.assertNotIn("Traceback", result.stderr)
# test_restore_help_without_target
self.assertEqual(result.returncode, 0)
self.assertIn("usage:", result.stdout.lower())
self.assertIn("-hexpass", result.stdout)
# test_poisoned_python_environment (repeat both invocations)
self.assertEqual(poisoned_exploit.returncode, 1)
self.assertEqual(poisoned_restore.returncode, 0)
self.assertNotIn("HOST_PYTHON_WAS_IMPORTED", poisoned_exploit.stderr + poisoned_restore.stderr)
# test_installed_scope_and_network_free_imports
self.assertEqual(installed_scripts, {"cve-2020-1472-exploit.py", "restorepassword.py"})
self.assertFalse((package / "share/zerologon/relaying").exists())
self.assertEqual(import_result.returncode, 0)
```

For poisoned-environment cases, independently test `PYTHONPATH` with raising Impacket/Cryptodome modules, `PYTHONHOME` pointing at an empty directory, and user site packages containing raising modules. The import check runs under the package interpreter with `socket.socket` and `socket.create_connection` replaced by functions that raise; load scripts using `runpy.run_path(..., run_name="redflake_import_check")`. Compile to a writable temporary bytecode directory; suppress source-directory bytecode writes during imports.

Also define `test_restore_invalid_option_preserves_exit_status`: invoke only `--redflake-invalid-option`, require status 2 and argparse's `usage:` diagnostic. This exercises argument forwarding and failure propagation without supplying a target.

- [ ] **Observe failure before implementation.** Run `python3 tests/check_zerologon.py --package /nonexistent/zerologon`. Expect missing files/commands to fail, not skip tests.
- [ ] **Implement `packages/zerologon.nix`.** Use `fetchFromGitHub` with the resolved revision/hash and `stdenvNoCC`. Build `pythonEnv = pkgs.python3.withPackages (ps: [ ps.impacket ps.pycryptodomex ])`. Copy only the two top-level files to `share/zerologon`. Generate executable wrappers that unset ambient Python path/home, set `PYTHONNOUSERSITE=1`, and `exec` the absolute packaged interpreter/script with forwarded arguments. Verify the interpreter wrapper actually restores its packaged dependency paths after ambient variables are cleared. Do not invent upstream license metadata.
- [ ] **Wire package outputs and install checks.** Define `zerologonPackage = import ./packages/zerologon.nix { inherit pkgs; };`. Export it under `packages.x86_64-linux.zerologon`; reference it from `checks.x86_64-linux.zerologon`. Enable install checks that run `check_zerologon.py` under `pythonEnv` against `$out` with bytecode writes disabled. Stage the new package/test files before Git-backed evaluation.
- [ ] **Verify the fixed-output source and package.** Run `nix build --no-update-lock-file .#zerologon` and `nix build --no-update-lock-file .#checks.x86_64-linux.zerologon`. Expected: verified source hash, passing imports/compilation, both harmless CLI cases and all poisoning cases pass. On API incompatibility, identify the actual failing import/API and present the smallest compatibility change before altering upstream scripts or adding dependency pins.
- [ ] **Commit the tested package.** Stage this task's files and commit with `feat: package pinned Zerologon scripts`.

### Task 2: Deliver commands in AD/full and document their behavior

**Files:** Modify `flake.nix`, `scripts/smoke.sh`, `README.md`, `tools.md`.

**Interfaces:**
- Consumes: Task 1's `zerologonPackage` and two installed commands.
- Produces: both commands in `ad`, `full` and default, with targeted smoke checks.

- [ ] **Add failing delivery checks.** Extend AD/full expected commands with both wrapper names. Add harmless CLI checks inside only the AD/full/default branch: capture no-argument exploit output and require status exactly 1 plus `Usage:`; require restoration `-h` status 0 plus help text. Use a temporary cwd and a subshell so the caller's cwd remains unchanged. Clean the temporary directory on exit. Run the AD smoke check before profile integration; expect a missing-command failure.
- [ ] **Integrate the package.** Append `zerologonPackage` to `groups.ad`. Retain the existing Python environment and shell package. Confirm `full` and default receive it through the existing group composition. Do not add Zerologon to core/web.
- [ ] **Document the delivered tool.** Add command names, upstream URL, pin location, isolation, affected profiles and verification limits to README. State that the exploit resets the DC machine-account password and can disrupt domain-controller communication; restoration requires the original password and is not guaranteed. Provide no live-target verification command. Add this GitHub source and implemented status to `tools.md`, preserving the shell entry and unrelated wishlist items.
- [ ] **Verify delivery and regressions.** Run:

```bash
python3 -B -m unittest discover -s tests -v
bash -n quickconfig.sh scripts/smoke.sh
nix flake check --no-update-lock-file
for profile in core web ad full; do
  nix develop --no-update-lock-file ".#$profile" --command bash scripts/smoke.sh "$profile"
done
python3 tests/check_nix_shell.py --flake "$PWD"
git diff --check
git diff --exit-code -- flake.lock
```

Additionally run isolated `--command bash -c` availability checks: `ad`, `full`, and default must find both commands; `core` and `web` must not expose them from their Nix profile. Eliminate inherited PATH entries pointing at another redflake shell before testing absence. Expected: all checks exit 0 and the lock is unchanged. Do not run either script against a target.
- [ ] **Commit the tested integration and docs.** Stage only this task's files and commit with `feat: expose Zerologon commands in AD profiles`.
