"""Exercise config writes in temporary homes; never install host software."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "quickconfig.sh"


class QuickconfigTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.env = dict(os.environ, HOME=str(self.home),
                        XDG_CONFIG_HOME=str(self.home / "config"))

    def run_shell(self, code):
        return subprocess.run(["bash", "-c", 'source "$1"; ' + code, "test", str(SCRIPT)],
                              env=self.env, text=True, capture_output=True)

    def test_prerequisites_are_installed_for_each_supported_manager(self):
        for pm in ("apt-get", "dnf", "yum"):
            with self.subTest(pm=pm):
                result = self.run_shell('sudo() { printf "%s\\n" "$*"; }; install_misc ' + pm)
                self.assertEqual(result.returncode, 0, result.stderr)
                expected = f"{pm} install -y curl git ca-certificates\n"
                if pm == "apt-get":
                    expected = "apt-get update\n" + expected
                self.assertEqual(result.stdout, expected)

    def test_feature_config_preserves_existing_settings_and_is_repeatable(self):
        config = self.home / "config/nix/nix.conf"
        config.parent.mkdir(parents=True)
        config.write_text("experimental-features = ca-derivations\n")
        result = self.run_shell("enable_nix_features; enable_nix_features")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(config.read_text(), "experimental-features = ca-derivations\n\n"
                         "extra-experimental-features = nix-command flakes\n")

    def test_failed_download_does_not_execute_installer(self):
        result = self.run_shell('load_nix() { return 1; }; curl() { return 22; }; '
                                'sh() { echo "INSTALLER EXECUTED"; }; install_nix')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("INSTALLER EXECUTED", result.stdout)


if __name__ == "__main__":
    unittest.main()
