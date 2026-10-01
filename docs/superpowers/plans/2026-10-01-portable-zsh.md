# Portable Oh My Zsh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every interactive redflake profile enter the user's portable Oh My Zsh configuration while preserving explicit command execution.

**Architecture:** Package the adapted configuration and a `redflake-zsh` launcher as one derivation. Integrate it through the shared core group and an interactive-only shell hook. Keep writable state under user XDG directories.

**Tech Stack:** Nix flakes, zsh, Oh My Zsh, zsh-syntax-highlighting, Python unittest and pseudo-terminals.

**Spec:** `docs/superpowers/specs/2026-10-01-portable-zsh-design.md`

## Global Constraints

- Support x86_64 Linux and retain the existing Nixpkgs revision and default full toolkit.
- Theme: `jonathan`; plugins: `colored-man-pages`, `git`, `colorize`.
- Use Pygments explicitly; disable Oh My Zsh self-updates.
- Use `vim` when `SSH_CONNECTION` is nonempty and `nvim` otherwise.
- History: `${XDG_STATE_HOME:-$HOME/.local/state}/redflake/zsh/history`.
- Cache: `${XDG_CACHE_HOME:-$HOME/.cache}/redflake/zsh`.
- Preserve supplied syntax-highlighting and completion preferences; initialize completion once.
- Preserve host dotfiles, Oh My Zsh installation, login shell, and existing parent-directory permissions.
- Plain interactive `nix develop` enters zsh; `--command` runs its requested command.

## Review Focus

- Paths with spaces: state and configuration paths must remain single arguments (Task 1).
- Existing host customization: host startup files/custom plugins must not enter the portable configuration (Task 1).
- Existing state and umask: repeated startup must preserve parent permissions and the caller's umask (Task 1).
- Unwritable state: report the path, stop custom initialization, and leave toolkit commands usable (Task 1).
- Explicit command failures: preserve exit status without starting interactive zsh or creating its state (Task 2).

## File Structure and Execution Order

- `packages/shell.nix`: shell derivation, generated config, launcher and runtime dependencies.
- `shell/zshrc`: adapted configuration template with store-path placeholders.
- `tests/check_zsh.py`: explicit package-level unittest runner; does not match bootstrap test discovery.
- `tests/check_nix_shell.py`: explicit Nix/PTY integration runner.
- `flake.nix`: package output, package checks, core dependencies and interactive hook.
- `scripts/smoke.sh`: common shell executable availability.
- `.github/workflows/check.yml`: real Nix startup integration check.
- `README.md`, `tools.md`: delivered behavior and wishlist status.

Execute this plan before `2026-10-01-zerologon-package.md`. That plan must retain these shell changes when extending shared files.

## Preflight

- [ ] Read the spec, `zshconfig`, current flake, smoke script and CI workflow. Use the worktree skill at execution time; preserve the supplied untracked `zshconfig` and `tools.md` in an isolated checkout if one is created. Leave `.tools.md.swp` and `codex-design-context.md` untouched.
- [ ] Select an existing Nix runtime. This workspace has `/tmp/redflake-tools/nix-portable` and `/tmp/redflake-nix`; when needed, prefix Nix commands with `NP_LOCATION=/tmp/redflake-nix NP_RUNTIME=bwrap /tmp/redflake-tools/nix-portable`. Do not install host Nix through `quickconfig.sh` to test this feature.

### Task 1: Package and validate the portable shell

**Files:** Create `packages/shell.nix`, `shell/zshrc`, `tests/check_zsh.py`; modify `flake.nix` package/check outputs only.

**Interfaces:**
- Consumes: `packages/shell.nix` takes `{ pkgs }` from locked Nixpkgs.
- Produces: derivation `shellPackage`, output `packages.x86_64-linux.redflake-shell`, executable `$out/bin/redflake-zsh`, config `$out/share/redflake/zsh/.zshrc`.
- Test CLI: `python3 tests/check_zsh.py --launcher /absolute/path/to/redflake-zsh`; exit 0 means all checks passed.
- Test helper: `run_zsh(code: str, env_overrides: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]`; uses a temporary home and working directory, packaged launcher with `-i -c`, captured output and a 20-second timeout. Parse output only after an explicit test marker.

- [ ] **Write package-level tests.** Define `ShellConfigTests` with temporary HOME/XDG fixtures and a test-only launcher supplied through argparse. Include these named cases and assertions:

```python
# test_theme_plugins_and_dependencies
self.assertEqual(report["theme"], "jonathan")
self.assertEqual(report["plugins"], ["colored-man-pages", "git", "colorize"])
self.assertEqual(report["colorize_tool"], "pygmentize")
self.assertEqual(report["update_mode"], "disabled")
self.assertTrue(all(report["commands"][name] for name in ("git", "vim", "nvim", "pygmentize", "less", "man")))
# test_highlighting_and_completion
self.assertEqual(report["highlighters"], ["main", "brackets", "pattern"])
self.assertEqual(report["arg0_style"], "fg=cyan")
self.assertEqual(report["bracket_error_style"], "fg=red,bold")
self.assertEqual(report["completion_matcher"], "m:{a-zA-Z}={A-Za-z}")
# test_local_and_ssh_editors
self.assertEqual(local_report["editor"], "nvim")
self.assertEqual(ssh_report["editor"], "vim")
# test_state_paths_and_repeated_startup (XDG paths include spaces)
self.assertEqual(report["history"], str(state / "redflake/zsh/history"))
self.assertEqual(report["cache"], str(cache / "redflake/zsh"))
self.assertTrue(Path(report["compdump"]).is_file())
self.assertEqual(parent_mode_after, parent_mode_before)
self.assertEqual(report["umask_after"], report["umask_before"])
# test_host_configuration_is_untouched
self.assertNotIn("HOST_CONFIG_WAS_SOURCED", result.stdout + result.stderr)
self.assertEqual(host_files_after, host_files_before)
# test_unwritable_state (use a regular file as a required directory)
self.assertIn(str(blocked_path), result.stderr)
self.assertTrue(report["git_available"])
self.assertEqual(host_files_after, host_files_before)
```

Create host `.zshrc`, `.zshenv`, and custom Oh My Zsh sentinels before startup. Obtain the pre-initialization umask using the same zsh binary with rc loading disabled. Check newly created history files/directories have no group/other permissions. Assert no plugin-not-found or read-only-store errors on normal startup. Test an absent `.local/bin` and a preexisting one: do not create it or duplicate it, and preserve toolkit command priority.

- [ ] **Observe failure before implementation.** Run `python3 tests/check_zsh.py --launcher /nonexistent/redflake-zsh`. Expect a missing-executable failure, never skipped tests.
- [ ] **Implement `packages/shell.nix` and `shell/zshrc`.** Use `stdenvNoCC`, substitution, and a launcher with an absolute zsh path. Template placeholders are `@ohMyZsh@` for the Oh My Zsh root directory and `@syntaxHighlighting@` for the highlighting script's absolute filename. Set `ZDOTDIR` to the packaged config. Provide runtime paths for Git, Vim, Neovim, Pygments, less, man-db and GNU utilities used by initialization; prepend their locked paths while retaining the inherited toolkit PATH. No runtime downloads.
- [ ] **Adapt initialization.** Set explicit Oh My Zsh/custom/cache/completion paths, disable updates, set `ZSH_COLORIZE_TOOL=pygmentize`, and load the approved theme/plugins. Initialize writable state with private creation permissions in a subshell so the interactive umask remains unchanged. On failure emit a path-specific stderr diagnostic and return from `.zshrc` before loading Oh My Zsh. Apply the provided editor/completion preferences and highlighting styles, sourcing highlighting last. Do not add a second `compinit` call.
- [ ] **Add build interfaces and package check.** Define `shellPackage = import ./packages/shell.nix { inherit pkgs; };`, export it under `packages`, and add a `checks.x86_64-linux.shell` derivation running zsh syntax validation and `check_zsh.py` with a Python unittest runner. Stage only the new files needed by Git-backed Nix evaluation.
- [ ] **Verify package delivery.** Run `nix build --no-update-lock-file .#redflake-shell` and `python3 tests/check_zsh.py --launcher ./result/bin/redflake-zsh` (resolve the launcher to an absolute path before changing test cwd), then `nix build --no-update-lock-file .#checks.x86_64-linux.shell`. Expected: exit 0, all named tests pass, no skipped package tests.
- [ ] **Commit the tested package and package checks.** Stage these exact task files and commit with `feat: package portable Oh My Zsh configuration`.

### Task 2: Integrate automatic startup and document the experience

**Files:** Create `tests/check_nix_shell.py`; modify `flake.nix`, `scripts/smoke.sh`, `.github/workflows/check.yml`, `README.md`, `tools.md`.

**Interfaces:**
- Consumes: Task 1's `shellPackage`, `redflake-zsh` and package output.
- Produces: interactive startup in all profiles; common command availability and unchanged explicit-command execution.
- Test CLI: `python3 tests/check_nix_shell.py --flake /absolute/path/to/checkout`; finds `nix` on PATH and exits 0 only when integration checks pass.
- Test helper: `run_interactive(profile: str) -> tuple[int, str]`; starts `nix develop --no-update-lock-file <flake>#<profile>` on a PTY, sends marker-printing assertions followed by `exit`, drains output with a 45-second startup timeout and terminates/reaps processes on failure. Use a temporary home and state directories. Realize profiles before this timed check.

- [ ] **Write integration tests.** For each of `core`, `web`, `ad`, `full` and default, assert PTY output contains the zsh/version marker, `theme=jonathan`, and the expected `REDFLAKE_PROFILE`; assert exit status 0. For explicit commands assert:

```python
# test_explicit_command_preserves_shell_status_and_has_no_state
self.assertEqual(result.returncode, 23)
self.assertIn("REQUESTED_BASH_COMMAND", result.stdout)
self.assertNotIn("AUTO_ZSH_STARTED", result.stdout + result.stderr)
self.assertFalse((state / "redflake/zsh").exists())
self.assertFalse((cache / "redflake/zsh").exists())
```

Use `--command bash -c` with a marker, a check that `ZSH_VERSION` is unset, and `exit 23`. Give this subprocess a 45-second timeout too. Default's expected `REDFLAKE_PROFILE` is `full`. An additional test invokes the packaged launcher from a directory outside the checkout and asserts the configured theme.

- [ ] **Observe missing integration.** Run `python3 tests/check_nix_shell.py --flake "$PWD"` with Nix on PATH after realizing the existing core shell. Expect interactive assertions to fail because the shell is still Bash.
- [ ] **Integrate the launcher.** Append `shellPackage` and `zsh`, `neovim`, `python3Packages.pygments`, `less`, `man-db` to `groups.core`. Add the same shell hook to all mapped profiles: when Bash's `$-` includes `i`, execute the absolute `redflake-zsh` launcher; otherwise do nothing. Keep default mapped to full.
- [ ] **Update common smoke requirements and CI.** Add `redflake-zsh`, `zsh`, `nvim`, `pygmentize`, `less`, and `man` to the common commands. Retain existing per-profile tools. Add a CI step after all profiles are realized to run `check_nix_shell.py` using the checkout's absolute path. Include Bash syntax and ShellCheck in the existing checks; shell config is checked by zsh, not ShellCheck.
- [ ] **Document delivered behavior.** Replace the Bash/future-zsh README text with automatic interactive startup, the explicit launcher, preserved host dotfiles, local/SSH editor selection, state paths and updates through Nix. Mark the zsh wishlist as implemented in `tools.md`, preserving other entries. Track `tools.md` when committing its authorized edits.
- [ ] **Verify integration and regression checks.** Run:

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

Expected: all commands exit 0, all profile smoke checks pass, interactive tests pass and the lock is unchanged. Report any runtime/sandbox blocker accurately; package startup is not proof of target-tool functionality.
- [ ] **Commit the tested integration and docs.** Stage only this task's files and commit with `feat: enter portable zsh in interactive redflake profiles`.
