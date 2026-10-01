"""Exercise the installed portable shell, without host dotfiles or services."""

import argparse
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest


LAUNCHER: Path
MARKER = "REDFLAKE_SHELL_TEST_BEGIN\n"


class ShellConfigTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="redflake shell ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.cwd = self.root / "outside checkout"
        self.home.mkdir()
        self.cwd.mkdir()
        self.state = self.root / "state with spaces"
        self.cache = self.root / "cache with spaces"
        self.toolkit = self.root / "toolkit"
        self.toolkit.mkdir()
        self.write_command(self.toolkit / "redflake-priority", "toolkit")
        self.env = {
            "HOME": str(self.home),
            "XDG_STATE_HOME": str(self.state),
            "XDG_CACHE_HOME": str(self.cache),
            "PATH": str(self.toolkit) + ":" + os.environ.get("PATH", ""),
            "TERM": "xterm-256color",
            "LANG": "C.UTF-8",
        }
        poison = 'print -u2 HOST_CONFIG_WAS_SOURCED\n'
        for name in (".zshrc", ".zshenv", ".oh-my-zsh/custom/poison.zsh"):
            path = self.home / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(poison)
        self.env["ZSH_CUSTOM"] = str(self.home / ".oh-my-zsh/custom")
        self.env["ZDOTDIR"] = str(self.home)

    @staticmethod
    def write_command(path: Path, output: str):
        path.write_text(f"#!/bin/sh\nprintf '%s\\n' '{output}'\n")
        path.chmod(0o755)

    def run_zsh(self, code: str, env_overrides: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(LAUNCHER), "-i", "-c", code],
            env=self.env | (env_overrides or {}), cwd=self.cwd,
            text=True, capture_output=True, timeout=20,
        )

    def report(self, code: str, env_overrides=None, *, normal=True):
        result = self.run_zsh(
            'print -r -- "REDFLAKE_SHELL_TEST_BEGIN"\n'
            'function field() { printf "%s\\t%s\\n" "$1" "$2"; }\n' + code,
            env_overrides,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(MARKER, result.stdout)
        if normal:
            self.assertEqual(result.stderr, "", result.stderr)
            self.assertNotIn("plugin not found", result.stdout.lower())
            self.assertNotIn("read-only", result.stdout.lower())
        payload = result.stdout.split(MARKER, 1)[1]
        report = dict(line.split("\t", 1) for line in payload.splitlines())
        return report, result

    def host_files(self):
        return {
            str(p.relative_to(self.home)): (p.read_bytes(), stat.S_IMODE(p.stat().st_mode))
            for p in self.home.rglob("*") if p.is_file()
        }

    def test_theme_plugins_and_dependencies(self):
        report, _ = self.report('''
field theme "$ZSH_THEME"
field plugins "${(j: :)plugins}"
field colorize_tool "$ZSH_COLORIZE_TOOL"
zstyle -s ':omz:update' mode mode; field update_mode "$mode"
for name in git vim nvim pygmentize less man zsh; do
  field "$name" "${commands[$name]}"
done
field git_alias "${aliases[gst]}"
field theme_loaded "${+functions[theme_precmd]}"
field colorize_loaded "${+functions[colorize_cat]}"
field colored_man_loaded "$less_termcap[mb]"
colorized=$(printf '#!/usr/bin/env python3\nprint(1)\n' | colorize_cat)
[[ $colorized == *$'\\e['* ]]; field colorize_output "$?"
''')
        report["plugins"] = report["plugins"].split()
        report["commands"] = {name: report[name] for name in ("git", "vim", "nvim", "pygmentize", "less", "man")}
        self.assertEqual(report["theme"], "jonathan")
        self.assertEqual(report["plugins"], ["colored-man-pages", "git", "colorize"])
        self.assertEqual(report["colorize_tool"], "pygmentize")
        self.assertEqual(report["update_mode"], "disabled")
        self.assertTrue(all(report["commands"][name] for name in ("git", "vim", "nvim", "pygmentize", "less", "man")))
        self.assertEqual(report["git_alias"], "git status")
        self.assertEqual(report["theme_loaded"], "1")
        self.assertEqual(report["colorize_loaded"], "1")
        self.assertTrue(report["colored_man_loaded"])
        self.assertEqual(report["colorize_output"], "0")
        self.assertTrue(report["zsh"], "colorize_less requires zsh on PATH")

    def test_highlighting_and_completion(self):
        report, _ = self.report('''
field highlighters "${(j: :)ZSH_HIGHLIGHT_HIGHLIGHTERS}"
field arg0_style "$ZSH_HIGHLIGHT_STYLES[arg0]"
field bracket_error_style "$ZSH_HIGHLIGHT_STYLES[bracket-error]"
zstyle -s ':completion:*' matcher-list matcher; field completion_matcher "$matcher"
field highlighting_loaded "${+functions[_zsh_highlight]}"
zstyle -s ':completion:*:*:*:*:*' menu menu; field menu "$menu"
''')
        report["highlighters"] = report["highlighters"].split()
        self.assertEqual(report["highlighters"], ["main", "brackets", "pattern"])
        self.assertEqual(report["arg0_style"], "fg=cyan")
        self.assertEqual(report["bracket_error_style"], "fg=red,bold")
        self.assertEqual(report["completion_matcher"], "m:{a-zA-Z}={A-Za-z}")
        self.assertEqual(report["highlighting_loaded"], "1")
        self.assertEqual(report["menu"], "select")

    def test_local_and_ssh_editors(self):
        local_report, _ = self.report('field editor "$EDITOR"', {"SSH_CONNECTION": ""})
        ssh_report, _ = self.report('field editor "$EDITOR"', {"SSH_CONNECTION": "192.0.2.1 1234 192.0.2.2 22"})
        self.assertEqual(local_report["editor"], "nvim")
        self.assertEqual(ssh_report["editor"], "vim")

    def test_state_paths_and_repeated_startup(self):
        self.state.mkdir(mode=0o755)
        self.cache.mkdir(mode=0o755)
        parent_mode_before = [stat.S_IMODE(p.stat().st_mode) for p in (self.state, self.cache)]
        baseline = subprocess.run(
            [str(LAUNCHER), "-f", "-c", "umask"], env=self.env,
            cwd=self.cwd, text=True, capture_output=True, timeout=20, check=True,
        ).stdout.strip()
        code = '''
field history "$HISTFILE"
field cache "$ZSH_CACHE_DIR"
field compdump "$ZSH_COMPDUMP"
field umask_after "$(umask)"
'''
        report, _ = self.report(code)
        report["umask_before"] = baseline
        self.assertEqual(report["history"], str(self.state / "redflake/zsh/history"))
        self.assertEqual(report["cache"], str(self.cache / "redflake/zsh"))
        self.assertTrue(Path(report["compdump"]).is_file())
        self.assertIn(self.cache / "redflake/zsh", Path(report["compdump"]).parents)
        self.assertTrue(Path(report["history"]).is_file())
        for path in (self.state / "redflake", self.state / "redflake/zsh", Path(report["history"])):
            self.assertEqual(stat.S_IMODE(path.stat().st_mode) & 0o077, 0, str(path))
        parent_mode_after = [stat.S_IMODE(p.stat().st_mode) for p in (self.state, self.cache)]
        self.assertEqual(parent_mode_after, parent_mode_before)
        self.assertEqual(report["umask_after"], report["umask_before"])
        again, _ = self.report(code)
        self.assertEqual(again, {key: value for key, value in report.items() if key != "umask_before"})

    def test_default_state_paths(self):
        report, _ = self.report('field history "$HISTFILE"; field cache "$ZSH_CACHE_DIR"', {
            "XDG_STATE_HOME": "", "XDG_CACHE_HOME": "",
        })
        self.assertEqual(report["history"], str(self.home / ".local/state/redflake/zsh/history"))
        self.assertEqual(report["cache"], str(self.home / ".cache/redflake/zsh"))

    def test_host_configuration_is_untouched(self):
        host_files_before = self.host_files()
        report, result = self.report('field inherited "$REDFLAKE_TEST_INHERITED"', {"REDFLAKE_TEST_INHERITED": "kept"})
        self.assertEqual(report["inherited"], "kept")
        self.assertNotIn("HOST_CONFIG_WAS_SOURCED", result.stdout + result.stderr)
        host_files_after = self.host_files()
        self.assertEqual(host_files_after, host_files_before)

    def test_unwritable_state(self):
        for variable in ("XDG_STATE_HOME", "XDG_CACHE_HOME"):
            with self.subTest(variable=variable):
                blocked_path = self.root / (variable + " blocked")
                blocked_path.write_text("this is a regular file")
                host_files_before = self.host_files()
                report, result = self.report('''
field git_available "${commands[git]}"
field omz_loaded "${+functions[omz]}"
''', {variable: str(blocked_path)}, normal=False)
                self.assertIn(str(blocked_path), result.stderr)
                self.assertTrue(report["git_available"])
                self.assertEqual(report["omz_loaded"], "0")
                host_files_after = self.host_files()
                self.assertEqual(host_files_after, host_files_before)
                self.assertNotIn("HOST_CONFIG_WAS_SOURCED", result.stdout + result.stderr)
                self.assertEqual(blocked_path.read_text(), "this is a regular file")

    def test_local_bin_is_optional_and_keeps_toolkit_priority(self):
        local_bin = self.home / ".local/bin"
        report, _ = self.report('field path "$PATH"')
        self.assertFalse(local_bin.exists())
        self.assertNotIn(str(local_bin), report["path"].split(":"))
        local_bin.mkdir(parents=True)
        self.write_command(local_bin / "redflake-priority", "host")
        code = '''
field path "$PATH"
field priority "$(redflake-priority)"
'''
        for inherited in (self.env["PATH"], self.env["PATH"] + ":" + str(local_bin)):
            report, _ = self.report(code, {"PATH": inherited})
            self.assertEqual(report["path"].split(":").count(str(local_bin)), 1)
            self.assertEqual(report["priority"], "toolkit")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--launcher", required=True, type=Path)
    args = parser.parse_args()
    LAUNCHER = args.launcher.resolve()
    if not LAUNCHER.is_file() or not os.access(LAUNCHER, os.X_OK):
        parser.error(f"missing executable launcher: {LAUNCHER}")
    unittest.main(argv=[__file__, "-v"])
