"""Temporary credential lifecycle; all Keychain/Apple calls are simulated."""
import base64
import importlib.util
import os
from pathlib import Path
import stat
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "ci_signing.py"
sys.path.insert(0, str(SCRIPT.parent))
spec = importlib.util.spec_from_file_location("ci_signing", SCRIPT)
signing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(signing)


class CISigningTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.identity = "Developer ID Application: Example (ABCDEFGHIJ)"
        self.environment = {
            "GITHUB_ACTIONS": "true", "RUNNER_TEMP": str(self.root), "GITHUB_ENV": str(self.root / "environment"),
            "MSGBLAST_APPLE_TEAM_ID": "ABCDEFGHIJ", "MSGBLAST_DEVELOPER_ID_IDENTITY": self.identity,
            "MSGBLAST_DEVELOPER_ID_P12": base64.b64encode(b"synthetic certificate").decode(),
            "MSGBLAST_DEVELOPER_ID_P12_PASSWORD": " password with whitespace ",
            "MSGBLAST_NOTARY_KEY_ID": "1234567890",
            "MSGBLAST_NOTARY_ISSUER_ID": "12345678-1234-1234-1234-123456789012",
            "MSGBLAST_NOTARY_API_KEY": "-----BEGIN PRIVATE KEY-----\nfixture\n-----END PRIVATE KEY-----",
        }
        self.commands = []
        self.current_keychains = []
        self.previous = '/runner/Library/Keychains/login.keychain-db'

    def command(self, arguments):
        self.commands.append(arguments)
        if arguments[1] == "list-keychains" and "-s" not in arguments:
            return '"' + self.previous + '"\n'
        if arguments[1] == "list-keychains" and "-s" in arguments:
            self.current_keychains = arguments[arguments.index("-s") + 1:]
        if arguments[1] == "create-keychain":
            Path(arguments[-1]).touch()
        if arguments[1] == "import":
            certificate = Path(arguments[2])
            self.assertEqual(stat.S_IMODE(certificate.stat().st_mode), 0o600)
            self.assertEqual(stat.S_IMODE(certificate.parent.stat().st_mode), 0o700)
            self.assertEqual(arguments[arguments.index("-P") + 1], self.environment['MSGBLAST_DEVELOPER_ID_P12_PASSWORD'])
        if arguments[1] == "find-identity":
            return '1) FIXTURE "' + self.identity + '"\n'
        if arguments[0] == "xcrun":
            key = Path(arguments[arguments.index("--key") + 1])
            self.assertEqual(stat.S_IMODE(key.stat().st_mode), 0o600)
        return ""

    def test_setup_and_cleanup_leave_no_credential_files_and_restore_keychain_search(self):
        with patch.dict(os.environ, self.environment, clear=True), patch.object(signing, "run", side_effect=self.command):
            signing.setup()
            directory = next(self.root.glob("msgblast-signing-*/"))
            self.assertFalse((directory / "certificate.p12").exists())
            self.assertFalse((directory / "notary.p8").exists())
            self.assertIn("MSGBLAST_NOTARY_KEYCHAIN=", (self.root / "environment").read_text())
            signing.cleanup()
            signing.cleanup()  # always() cleanup also runs after an early failure.
        self.assertFalse(directory.exists())
        self.assertFalse((self.root / "msgblast-signing-state.json").exists())
        self.assertIn(["security", "list-keychains", "-d", "user", "-s", self.previous], self.commands)

    def test_rejected_import_is_cleaned_without_exporting_a_profile(self):
        def failure(arguments):
            if arguments[1] == "import":
                raise signing.SigningError("Import failed")
            return self.command(arguments)
        with patch.dict(os.environ, self.environment, clear=True), patch.object(signing, "run", side_effect=failure):
            with self.assertRaises(signing.SigningError):
                signing.setup()
        self.assertFalse(list(self.root.glob("msgblast-signing-*")))
        self.assertFalse((self.root / "environment").exists())

    def test_late_failures_restore_search_list_and_remove_credentials(self):
        for phase in ("identity", "notary", "environment"):
            with self.subTest(phase=phase):
                environment = dict(self.environment)
                if phase == "environment":
                    blocked = self.root / "blocked-environment"
                    blocked.mkdir()
                    environment["GITHUB_ENV"] = str(blocked)
                def failure(arguments):
                    if phase == "identity" and arguments[1] == "find-identity":
                        return '1) FIXTURE "Developer ID Application: Wrong Team"'
                    if phase == "notary" and arguments[0] == "xcrun":
                        raise signing.SigningError("Notary credentials rejected")
                    return self.command(arguments)
                with patch.dict(os.environ, environment, clear=True), patch.object(signing, "run", side_effect=failure):
                    with self.assertRaises((signing.SigningError, OSError)):
                        signing.setup()
                self.assertEqual(self.current_keychains, [self.previous])
                self.assertFalse(list(self.root.glob("msgblast-signing-*")))
                self.assertFalse((self.root / "environment").exists())

    def test_installation_refuses_the_users_live_keychain_outside_ci(self):
        with patch.dict(os.environ, {}, clear=True), patch.object(signing, "run") as command:
            with self.assertRaisesRegex(signing.SigningError, "GitHub Actions"):
                signing.setup()
        command.assert_not_called()

    def test_tool_failure_never_repeats_password_or_private_key_diagnostics(self):
        result = signing.subprocess.CompletedProcess([], 1, "PRIVATE-KEY-MARKER", "PASSWORD-MARKER")
        with patch.object(signing.subprocess, "run", return_value=result):
            with self.assertRaises(signing.SigningError) as failure:
                signing.run(["security", "import", "fixture"])
        self.assertNotIn("MARKER", str(failure.exception))
