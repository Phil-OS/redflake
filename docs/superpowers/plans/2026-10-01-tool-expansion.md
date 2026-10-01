# AD-first Tool Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand redflake with the agreed AD/client/inspection tools, compact web set, wordlists, OpenSSH and Ncat, with an optional Burp profile.

**Architecture:** Reuse locked Nixpkgs applications and add one local pinned CE collector derivation. Extend existing groups with inspection/assets and expose GUI separately from the terminal full/default shell. Validate through package checks and the existing smoke/startup runners.

**Tech Stack:** Nix flakes, packaged Python applications, Bash smoke checks, Python shell integration checks.

**Spec:** `docs/superpowers/specs/2026-10-01-tool-expansion-design.md`

## Global Constraints

- Target x86_64 Linux and retain Nixpkgs revision `78e9c786dc08cd4f3420c2395cd977206a9b1da2`.
- Preserve all original tools, portable Oh My Zsh behavior, and top-level Zerologon packaging.
- BloodHound edition: Community Edition; command: `bloodhound-ce-python`; no legacy collector/server installation.
- CE source: `bloodhound_ce` version `1.9.1`, hash `sha256-CD3z3DrZmO3P+Ptj/dj1tGSqtf2sjgXMmztlICEPeas=`.
- Ncat comes from `pkgs.nmap`, with OpenSSH/Nmap/Ncat/dig in every profile.
- SecLists variable: `REDFLAKE_SECLISTS`; package path: `share/wordlists/seclists`.
- GUI profile: `gui`, containing web tools plus Burp; exclude GUI from full/default.
- No runtime downloads, target contact, services, captures, GUI launch, credential prompts or host-config writes during checks.

## Review Focus

- Collector edition mismatch: the selected executable must be the CE distribution, with no legacy collector command (Task 1).
- Host Python/path contamination: packaged CE help must still work and profile commands must resolve to their Nix providers (Tasks 1 and 2).
- Wordlist discovery: readable data must be available through a stable quoted path, including outside the checkout (Task 2).
- Inherited GUI/data state: clean core/full sessions must not accidentally expose a previous GUI shell's Burp or wordlist variable (Tasks 2 and 3; sanitize test environments).
- Headless machines: GUI realization/availability checks must finish without DISPLAY, without launching Java/Burp or entering zsh for `--command` (Task 3).

## File Structure and Execution Order

- Create `packages/bloodhound-ce-python.nix`: dedicated CE Python application and install checks.
- Modify `flake.nix`: CE package/check outputs, tool groups, profile composition and wordlist variable.
- Modify `scripts/smoke.sh`: safe executable/startup/data checks per profile.
- Modify `tests/check_nix_shell.py`: add the GUI profile to existing actual Nix startup checks.
- Modify `.github/workflows/check.yml`: realize/smoke-test all five profiles.
- Modify `README.md`, `tools.md`: delivered contents, CE edition, wordlists and optional GUI.

Execute after `2026-10-01-portable-zsh.md` and `2026-10-01-zerologon-package.md`. Reuse their isolated checkout and Nix runtime. Preserve their package outputs, checks and shared-file edits. Keep unrelated original files untouched.

### Task 1: Build a correctly pinned BloodHound CE Python collector

**Files:** Create `packages/bloodhound-ce-python.nix`; modify `flake.nix` package/check outputs only.

**Interfaces:**
- Consumes: Nix constructor `{ pkgs }`, using locked `pkgs.python3Packages`.
- Produces: derivation `bloodhoundCePackage`, `packages.x86_64-linux.bloodhound-ce-python`, executable `$out/bin/bloodhound-ce-python`.
- Check output: `checks.x86_64-linux.bloodhound-ce-python` references the checked application.

- [ ] **Confirm the edition distinction before coding.** Inspect the locked legacy collector definition and the published CE 1.9.1 source metadata. Verify its entry point is `bloodhound-ce-python=bloodhound:main`, dependencies match the spec, and CLI help exits before collection. Do not silently select `pkgs.bloodhound-py` or `pkgs.bloodhound-ce`.
- [ ] **Establish the failing package acceptance check.** Before adding outputs, run `nix build --no-update-lock-file .#bloodhound-ce-python`. Expected: the package attribute is missing. Define the install checks before filling in the package build, then verify them against the installed application once built; no collection is invoked.
- [ ] **Define focused install checks.** Use a temporary HOME/cwd and packaged interpreter; assert `importlib.metadata.version("bloodhound-ce") == "1.9.1"`. Run the generated command with `-h` under a 15-second timeout and require status 0 plus usage text. Repeat help with a poisoned `PYTHONPATH` containing a `bloodhound` module that raises; require help to succeed without loading it. Check `$out/bin/bloodhound-python` is absent. These checks must run in the package build and contact no target. Record the shell assertions as:

```bash
timeout 15 "$out/bin/bloodhound-ce-python" -h > help.txt
grep -qi 'usage:' help.txt
test ! -e "$out/bin/bloodhound-python"
```

The first command must exit 0. Run the metadata assertion with the installed application site-packages and its locked dependencies available to the interpreter. Repeat the CLI assertion with the poisoning fixture rather than importing that fixture into the test runner.
- [ ] **Implement `packages/bloodhound-ce-python.nix`.** Return `pkgs.python3Packages.buildPythonApplication` with `pname = "bloodhound-ce"`, `version = "1.9.1"`, `pyproject = true`, and `fetchPypi` source `bloodhound_ce` with the exact spec hash. Use setuptools and `dnspython`, `impacket`, `ldap3`, `pyasn1`, `pycryptodome`. Set `pythonImportsCheck = [ "bloodhound" ]` and metadata `mainProgram = "bloodhound-ce-python"`. Preserve dependency isolation rather than adding it to the shared Python environment.
- [ ] **Export and verify the application.** Define `bloodhoundCePackage = import ./packages/bloodhound-ce-python.nix { inherit pkgs; };`; add the package/check outputs alongside the existing outputs. Stage the new Nix file, then run `nix build --no-update-lock-file .#bloodhound-ce-python` and `nix build --no-update-lock-file .#checks.x86_64-linux.bloodhound-ce-python`. Expected: verified source hash, correct metadata, imports/help/poisoning checks pass. Do not change the Nixpkgs lock for compatibility; report any verified dependency failure before selecting a different source/version.
- [ ] **Commit the tested collector.** Stage the package and its output/check wiring; commit with `feat: package pinned BloodHound CE Python collector`. This task delivers an independently buildable application; profile inclusion follows in Task 2.

### Task 2: Deliver AD/client/inspection and compact web tools

**Files:** Modify `flake.nix` and `scripts/smoke.sh`.

**Interfaces:**
- Consumes: Task 1's `bloodhoundCePackage`, prior plans' `shellPackage` and `zerologonPackage`, and spec's package mapping.
- Produces: expanded core/AD/web/full, `groups.inspection`, `groups.assets`, and `REDFLAKE_SECLISTS` on asset-bearing profiles.
- Smoke interface remains `bash scripts/smoke.sh <profile>` with status 0 only on successful delivery.

- [ ] **Extend failing smoke requirements.** Common commands gain `ssh`, `scp`, `sftp`, `ssh-keygen`, `ssh-agent`, `ssh-add`, `nmap`, `ncat`, `dig`. AD/full gain `bloodhound-ce-python`, `bloodyAD`, `ldapdomaindump`, `enum4linux-ng`, `kinit`, `klist`, `kdestroy`, `ldapsearch`, `smbclient`, `rpcclient`, `tcpdump`, `tshark`. Web/full gain `ffuf`, `sqlmap`; preserve dirb and all existing commands. Require a nonempty readable `$REDFLAKE_SECLISTS/Discovery/Web-Content/common.txt` in AD/web/full. Run the existing profiles and observe missing-command/data failures before adding packages.
- [ ] **Add harmless startup checks.** Use precisely the spec's help/version commands, after confirming the pinned argument handling is network-free. Add no-target startup checks to the relevant smoke branches and retain the prior Zerologon expected-status checks. Apply a 15-second timeout to new Python help/version subprocesses and provide a tool-specific failure diagnostic. Never invoke `kinit`, `kdestroy` or `ldapsearch` without a validated no-target flag; command-path checks suffice for them.
- [ ] **Extend groups using the package mapping.** Append `pkgs.openssh`, `pkgs.nmap`, `pkgs.dig` to core; remove Nmap's redundant network/web entries. Append `bloodhoundCePackage`, `pkgs.python3Packages.toPythonApplication pkgs.python3Packages.bloodyad`, `pkgs.ldapdomaindump`, `pkgs.enum4linux-ng`, `pkgs.krb5`, `pkgs.openldap`, `pkgs.samba` to AD. Define inspection as `[ pkgs.tcpdump pkgs.wireshark-cli ]` and assets as `[ pkgs.seclists ]`. Append ffuf/sqlmap to web. AD includes inspection/assets; web includes assets; full includes all terminal groups and the original shared Python environment.
- [ ] **Expose wordlists without expanding core.** Add `REDFLAKE_SECLISTS = "${pkgs.seclists}/share/wordlists/seclists"` only to asset-bearing shell derivations. Use optional attributes during shell construction so the core derivation contains no SecLists reference. Quote all paths in smoke checks and do not copy data at startup.
- [ ] **Verify profile delivery, provider identity and wordlists.** Run flake checks and core/web/AD/full smoke commands. In clean profiles verify `command -v ssh` and `command -v ncat` resolve to the selected Nix OpenSSH/Nmap providers; check the actual `bloodyAD` capitalization. Run the smoke script from a temporary directory with the checkout path supplied explicitly. Under a sanitized inherited environment, verify core has no `REDFLAKE_SECLISTS` variable and no SecLists reference in its evaluated package list; verify asset profiles export the exact package path and can read `common.txt`.
- [ ] **Commit the tested terminal expansion.** Stage only the flake and smoke script; commit with `feat: expand AD tooling and shared client utilities`.

### Task 3: Add optional Burp profile, CI coverage and inventory

**Files:** Modify `flake.nix`, `scripts/smoke.sh`, `tests/check_nix_shell.py`, `.github/workflows/check.yml`, `README.md`, `tools.md`.

**Interfaces:**
- Consumes: Task 2's core/web/assets groups and shell construction.
- Produces: `devShells.x86_64-linux.gui`, `REDFLAKE_PROFILE=gui`, GUI smoke/startup coverage and final inventory.

- [ ] **Add failing GUI integration checks.** Add `gui` to the existing Nix integration runner with expected profile `gui`. Add a smoke case for GUI matching web's commands/data plus `burpsuite` command availability. Run `nix develop --no-update-lock-file .#gui --command bash scripts/smoke.sh gui`; expect a missing-profile failure before integration.
- [ ] **Integrate the optional GUI shell.** Define `groups.gui = [ pkgs.burpsuite ];` and GUI packages as core + web + assets + GUI. Use the existing shared shell constructor and interactive-only hook. Build full from all groups except GUI, retaining shared Python and default's mapping to full. Do not add graphical Wireshark or Remmina. Preserve Burp's existing Nixpkgs wrapper; never launch it as a build/smoke check.
- [ ] **Extend CI and headless verification.** Add GUI to the realization/smoke loop. Run GUI realization and smoke checks with `DISPLAY` and `WAYLAND_DISPLAY` unset, a temporary HOME, no automatic GUI process and a bounded timeout after realization. Verify Burp's resolved command is the Nix package wrapper. With GUI-related PATH entries removed from the parent environment, full must not expose Burp and its declared package list must exclude it. Interactive GUI startup must still reach configured zsh.
- [ ] **Update README and inventory.** Document all five profiles, CE collector edition/command, OpenSSH/Ncat command names, SecLists path and read-only assets, GUI selection and display requirement. Rework `tools.md` as tool/purpose/profile/source/status tables. Preserve remaining wishlist entries, mark delivered shell/Zerologon/new tools accurately, and keep corrected tool names without introducing extra installations.
- [ ] **Run final verification once after integration.**

```bash
python3 -B -m unittest discover -s tests -v
bash -n quickconfig.sh scripts/smoke.sh
nix flake check --no-update-lock-file
for profile in core web ad gui full; do
  nix develop --no-update-lock-file ".#$profile" --command bash scripts/smoke.sh "$profile"
done
python3 tests/check_nix_shell.py --flake "$PWD"
git diff --check
git diff --exit-code -- flake.lock
```

Expected: every command exits 0, all five profiles are realized and smoke-tested, shell integration checks pass, package-specific checks pass and the lock is unchanged. These establish installation/startup and asset availability, not success against a target or GUI rendering.
- [ ] **Commit final integration/docs.** Stage only the task files and commit with `feat: add optional Burp profile and document expanded toolkit`. Request a whole-change review using the execution method selected by the user, then correct verified findings and rerun only the checks affected by changes.
