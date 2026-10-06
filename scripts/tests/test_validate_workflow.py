"""The validation workflow must stay unable to publish a release."""
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github/workflows/validate.yml"
RELEASE = ROOT / ".github/workflows/release-adhoc.yml"
INSTALL = ROOT / "scripts/cloud-agent-install.sh"
CHECKOUT = "actions/checkout@fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09"


class ValidateWorkflowTests(unittest.TestCase):
    def test_validation_workflow_does_not_publish(self):
        text = WORKFLOW.read_text()
        release = RELEASE.read_text()
        self.assertNotIn("automate_release", text)
        self.assertNotIn("MSGBLAST_SPARKLE_PRIVATE_KEY", text)
        self.assertNotIn("MSGBLAST_R2_ACCESS_KEY_ID", text)
        self.assertNotIn("MSGBLAST_R2_SECRET_ACCESS_KEY", text)
        self.assertNotIn("tags:", text)
        self.assertIn("runs-on: xcode-27", text)
        self.assertIn("DEVELOPER_DIR: /Applications/Xcode_27.0.app/Contents/Developer", text)
        self.assertIn("-only-testing:msgblastTests", text)
        self.assertIn("python3 scripts/test_updates.py --derived-data build/updater-validation", text)
        self.assertIn("ASSETCATALOG_COMPILER_APPICON_NAME=AppIconDemo", text)
        self.assertIn(CHECKOUT, text)
        self.assertIn(CHECKOUT, release)
        self.assertIn("automate_release.py", release)
        self.assertIn("tags: ['v*']", release)

    def test_linux_install_pins_a_virtualenv_and_does_not_build(self):
        text = INSTALL.read_text()
        self.assertIn("import ensurepip", text)
        self.assertIn("python3-venv", text)
        self.assertIn("python3 -m venv", text)
        self.assertIn("scripts/installer-requirements.txt", text)
        self.assertIn("npm ci --prefix", text)
        self.assertNotIn("xcodebuild", text)
        self.assertNotIn("automate_release", text)
        self.assertNotIn("pip install --user", text)
