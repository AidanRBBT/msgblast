"""The feedback package must stay local, opt-in, and free of message content."""
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
CORE = ROOT / "msgblast/Core/DiagnosticReport.swift"
FACTS = ROOT / "msgblast/App/FeedbackFacts.swift"
VIEW = ROOT / "msgblast/Windows/FeedbackView.swift"
APP = ROOT / "msgblast/App/msgblastApp.swift"
TESTS = ROOT / "msgblastTests/DiagnosticReportTests.swift"
IMPLEMENTATION = [CORE, FACTS, VIEW]

KEYS = [
    "agentCount", "attachmentCount", "buildNumber", "bundleIdentifier", "comparisonCount",
    "fixtureMode", "hasDraft", "lastErrorCategory", "messagesStatus", "operatingSystem",
    "permissionStage", "personalAgent", "stateFileBytes", "stateFilePresent", "supportFolder",
    "updatesEnabled", "updatesReason", "variant", "version", "webProviderCounts", "windowStyle",
]
EXCLUDED = [
    "message text",
    "contacts and phone numbers",
    "drafts and prompts",
    "attachments",
    "chat history and chat.db",
    "cookies, tokens, and saved website sessions",
    "the contents of state.json",
    "home-directory paths",
]


class FeedbackDiagnosticTests(unittest.TestCase):
    def test_diagnostics_are_opt_in_and_never_uploaded(self):
        core = CORE.read_text()
        view = VIEW.read_text()
        app = APP.read_text()
        self.assertIn("includeDiagnostics: Bool = false", core)
        self.assertIn("@Published var includeDiagnostics = false", view)
        self.assertIn("msgblast does not upload this report.", core)
        self.assertIn("Reports aren’t sent to msgblast automatically.", view)
        self.assertIn('Button("Send Feedback…")', app)
        self.assertIn("FeedbackWindowController.show", app)
        self.assertNotIn("URLSession", view)
        self.assertNotIn("mailto:", view)
        for path in IMPLEMENTATION:
            text = path.read_text()
            for forbidden in ["URLSession", "Data(contentsOf", "String(contentsOf", "sqlite", "CNContact", "WKWebsiteDataStore", "HTTPCookie"]:
                self.assertNotIn(forbidden, text, f"{path.name} references {forbidden}")

    def test_diagnostic_file_is_an_allowlist(self):
        core = CORE.read_text()
        facts = FACTS.read_text()
        for key in KEYS:
            self.assertIn(f'"{key}"', core)
        self.assertIn("static let diagnosticKeys = [", core)
        for topic in EXCLUDED:
            self.assertIn(topic, core)
        self.assertIn('"README.txt", "feedback.txt", "diagnostics.json"', core)
        for rejected in ["chat.db", "state.json"]:
            self.assertIn(f'"{rejected}"', TESTS.read_text())
        self.assertIn("does not read state.json", facts)
        self.assertNotIn("local.load", facts)
        self.assertNotIn("webAgents", facts)
        self.assertIn("resourceValues", facts)
        self.assertIn("includeDiagnostics: false", TESTS.read_text())
        self.assertIn("includeDiagnostics: true", TESTS.read_text())
