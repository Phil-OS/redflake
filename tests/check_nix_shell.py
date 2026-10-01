"""Check real Nix shell entry after realizing all profiles."""

import argparse
import errno
import fcntl
import os
from pathlib import Path
import pty
import select
import signal
import subprocess
import tempfile
import termios
import time
import unittest


FLAKE: Path
TIMEOUT = 45


class NixShellTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="redflake nix shell ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.state = self.root / "state with spaces"
        self.cache = self.root / "cache with spaces"
        self.outside = self.root / "outside checkout"
        self.outside.mkdir()
        self.env = os.environ | {
            "HOME": str(self.home),
            "XDG_STATE_HOME": str(self.state),
            "XDG_CACHE_HOME": str(self.cache),
            "TERM": "xterm-256color",
        }

    @staticmethod
    def stop_process(process):
        """Stop the shell and descendants, then reap the direct child."""
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            pass
        finally:
            # A descendant can retain the PTY even after the direct child exits.
            # Kill any remaining members of the session before reaping it.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        process.wait()

    def run_interactive(self, profile: str) -> tuple[int, str]:
        target = str(FLAKE) if profile == "default" else f"{FLAKE}#{profile}"
        master, slave = pty.openpty()
        process = None
        output = bytearray()

        def attach_terminal():
            os.setsid()
            fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

        try:
            process = subprocess.Popen(
                ["nix", "develop", "--no-update-lock-file", target],
                stdin=slave, stdout=slave, stderr=slave,
                env=self.env, cwd=self.outside, preexec_fn=attach_terminal,
            )
            os.close(slave)
            slave = None
            # Split the marker so terminal input echo cannot satisfy assertions.
            code = (
                "printf 'AUTO_%s version=%s theme=%s profile=%s\\n' "
                "ZSH_STARTED \"${ZSH_VERSION:-unset}\" "
                "\"${ZSH_THEME:-unset}\" \"${REDFLAKE_PROFILE:-unset}\"\n"
                "case $REDFLAKE_PROFILE in ad|full) "
                "python3 -c 'import impacket, pwnlib, certipy; "
                "print(\"TOOLKIT_\" + \"PYTHON_IMPORTS_OK\")' || exit 1;; esac\n"
                "exit\n"
            )
            os.write(master, code.encode())
            deadline = time.monotonic() + TIMEOUT
            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    self.fail(f"{profile} startup timed out after {TIMEOUT}s:\n"
                              + output.decode(errors="replace"))
                ready, _, _ = select.select([master], [], [], remaining)
                if not ready:
                    continue
                try:
                    chunk = os.read(master, 65536)
                except OSError as error:
                    if error.errno != errno.EIO:
                        raise
                    break
                if not chunk:
                    break
                output.extend(chunk)
            status = process.wait(timeout=max(0.01, deadline - time.monotonic()))
            return status, output.decode(errors="replace")
        finally:
            if process is not None:
                self.stop_process(process)
            os.close(master)
            if slave is not None:
                os.close(slave)

    def test_interactive_profiles_enter_configured_zsh(self):
        for profile, expected in (
            ("core", "core"), ("web", "web"), ("ad", "ad"),
            ("full", "full"), ("default", "full"),
        ):
            with self.subTest(profile=profile):
                status, output = self.run_interactive(profile)
                self.assertEqual(status, 0, output)
                self.assertRegex(
                    output,
                    rf"AUTO_ZSH_STARTED version=\d[^\s]* theme=jonathan profile={expected}(?:\r?\n)",
                )
                if expected in ("ad", "full"):
                    self.assertIn("TOOLKIT_PYTHON_IMPORTS_OK", output)

    def test_explicit_command_preserves_shell_status_and_has_no_state(self):
        for profile in ("core", "web", "ad", "full", "default"):
            with self.subTest(profile=profile):
                target = str(FLAKE) if profile == "default" else f"{FLAKE}#{profile}"
                result = subprocess.run(
                    ["nix", "develop", "--no-update-lock-file", target,
                     "--command", "bash", "-c",
                     'printf "REQUESTED_BASH_COMMAND\\n"; '
                     'if test -n "${ZSH_VERSION:-}"; then '
                     'printf "AUTO_ZSH_STARTED\\n"; exit 1; fi; exit 23'],
                    env=self.env, cwd=self.outside, text=True,
                    capture_output=True, timeout=TIMEOUT,
                )
                self.assertEqual(result.returncode, 23, result.stdout + result.stderr)
                self.assertIn("REQUESTED_BASH_COMMAND", result.stdout)
                self.assertNotIn("AUTO_ZSH_STARTED", result.stdout + result.stderr)
                self.assertFalse((self.state / "redflake/zsh").exists())
                self.assertFalse((self.cache / "redflake/zsh").exists())

    def test_launcher_outside_checkout_loads_configured_theme(self):
        result = subprocess.run(
            ["nix", "develop", "--no-update-lock-file", f"{FLAKE}#core",
             "--command", "redflake-zsh", "-i", "-c",
             'printf "LAUNCHER_THEME=%s\\n" "$ZSH_THEME"'],
            env=self.env, cwd=self.outside, text=True,
            capture_output=True, timeout=TIMEOUT,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("LAUNCHER_THEME=jonathan", result.stdout)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flake", required=True, type=Path)
    args = parser.parse_args()
    FLAKE = args.flake.resolve()
    if not (FLAKE / "flake.nix").is_file():
        parser.error(f"missing flake.nix in {FLAKE}")
    unittest.main(argv=[__file__, "-v"])
