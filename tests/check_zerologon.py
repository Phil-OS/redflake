"""Offline acceptance checks for the installed Zerologon package."""

import argparse
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


PACKAGE = None


class ZerologonPackageTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="zerologon checks ")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.home = self.root / "home"
        self.cwd = self.root / "working directory"
        self.home.mkdir()
        self.cwd.mkdir()
        self.env = os.environ.copy()
        self.env.update(HOME=str(self.home), PYTHONDONTWRITEBYTECODE="1")
        self.env.pop("PYTHONUSERBASE", None)
        self.env.pop("PYTHONNOUSERSITE", None)

    def run_command(self, name, args, env_overrides=None):
        env = self.env.copy()
        env.update(env_overrides or {})
        return subprocess.run(
            [str(PACKAGE / "bin" / name), *args],
            cwd=self.cwd, env=env, text=True, capture_output=True, timeout=10,
        )

    def assert_safe_startup(self, env_overrides=None):
        exploit = self.run_command("zerologon-exploit", [], env_overrides)
        restore = self.run_command("zerologon-restore", ["-h"], env_overrides)
        self.assertEqual(exploit.returncode, 1, exploit.stdout + exploit.stderr)
        self.assertIn("Usage:", exploit.stdout)
        self.assertEqual(restore.returncode, 0, restore.stdout + restore.stderr)
        self.assertIn("usage:", restore.stdout.lower())
        self.assertIn("-hexpass", restore.stdout)
        self.assertNotIn("Traceback", exploit.stderr + restore.stderr)
        self.assertNotIn("HOST_PYTHON_WAS_IMPORTED", exploit.stderr + restore.stderr)

    def test_exploit_usage_without_target(self):
        result = self.run_command("zerologon-exploit", [])
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("Usage:", result.stdout)
        self.assertNotIn("Traceback", result.stderr)

    def test_restore_help_without_target(self):
        result = self.run_command("zerologon-restore", ["-h"])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("usage:", result.stdout.lower())
        self.assertIn("-hexpass", result.stdout)

    def test_restore_invalid_option_preserves_exit_status(self):
        result = self.run_command("zerologon-restore", ["--redflake-invalid-option"])
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn("usage:", result.stderr.lower())

    @staticmethod
    def poison_modules(directory):
        directory.mkdir(parents=True, exist_ok=True)
        for name in ("impacket", "Cryptodome"):
            package = directory / name
            package.mkdir()
            (package / "__init__.py").write_text(
                'raise RuntimeError("HOST_PYTHON_WAS_IMPORTED")\n'
            )

    def test_poisoned_python_environment(self):
        poison = self.root / "poison modules"
        self.poison_modules(poison)
        empty_home = self.root / "empty python home"
        empty_home.mkdir()
        user_site = self.home / ".local/lib" / (
            f"python{sys.version_info.major}.{sys.version_info.minor}/site-packages"
        )
        for label, overrides in (
            ("PYTHONPATH", {"PYTHONPATH": str(poison)}),
            ("PYTHONHOME", {"PYTHONHOME": str(empty_home)}),
        ):
            with self.subTest(environment=label):
                self.assert_safe_startup(overrides)
        self.poison_modules(user_site)
        with self.subTest(environment="user site packages"):
            self.assert_safe_startup()

    def test_installed_scope_and_network_free_imports(self):
        source = PACKAGE / "share/zerologon"
        self.assertEqual(
            {path.name for path in source.iterdir()},
            {"cve-2020-1472-exploit.py", "restorepassword.py"},
        )
        self.assertFalse((source / "relaying").exists())
        # A socket subclass also permits dependency class definitions at import.
        # Any attempt to create a socket still fails before network access.
        program = """
import pathlib, py_compile, runpy, socket, sys
def deny_network(*args, **kwargs):
    raise AssertionError("network access during import")
class OfflineSocket(socket.socket):
    def __new__(cls, *args, **kwargs):
        deny_network()
socket.socket = OfflineSocket
socket.create_connection = deny_network
sys.dont_write_bytecode = True
source, bytecode = map(pathlib.Path, sys.argv[1:])
for name in ("cve-2020-1472-exploit.py", "restorepassword.py"):
    script = source / name
    py_compile.compile(str(script), cfile=str(bytecode / (name + "c")), doraise=True)
    runpy.run_path(str(script), run_name="redflake_import_check")
print("Offline imports and compilation passed")
"""
        bytecode = self.root / "bytecode"
        bytecode.mkdir()
        result = subprocess.run(
            [sys.executable, "-B", "-c", program, str(source), str(bytecode)],
            cwd=self.cwd, env=self.env, text=True, capture_output=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Offline imports and compilation passed", result.stdout)
        self.assertEqual(len(list(bytecode.glob("*.pyc"))), 2)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, required=True)
    options, remaining = parser.parse_known_args()
    PACKAGE = options.package.resolve()
    unittest.main(argv=[sys.argv[0], *remaining])
