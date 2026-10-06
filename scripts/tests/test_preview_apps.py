"""Preview planning stays free of production publishing and preserves committed icons."""
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


def load(name):
    path = ROOT / "scripts" / f"{name}.py"
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


preview = load("preview_apps")
evidence = load("check_pr_evidence")


class PreviewPlanTests(unittest.TestCase):
    def test_committed_icons_stay_green_and_blue(self):
        preview.assert_committed_icons_unchanged()

    def test_development_artwork_is_applied_only_in_an_isolated_workspace(self):
        before = preview.icon_fill(preview.ROOT / "msgblast/AppIcon.icon")
        with tempfile.TemporaryDirectory() as temporary:
            workspace = Path(temporary)
            shutil.copytree(preview.ROOT / "msgblast/AppIcon.icon", workspace / "msgblast/AppIcon.icon")
            shutil.copytree(preview.ROOT / "msgblast/AppIconDemo.icon", workspace / "msgblast/AppIconDemo.icon")
            preview.stage_icons(workspace)
            self.assertEqual(preview.icon_fill(workspace / "msgblast/AppIcon.icon"), preview.icon_fill(preview.BLUE_GREEN))
            self.assertEqual(preview.icon_fill(workspace / "msgblast/AppIconDemo.icon"), preview.icon_fill(preview.BLUE))
        self.assertEqual(preview.icon_fill(preview.ROOT / "msgblast/AppIcon.icon"), before)
        with self.assertRaises(RuntimeError):
            preview.stage_icons(preview.ROOT)

    def test_fixture_mode_is_explicit_and_production_identity_is_rejected(self):
        info = {"CFBundleIdentifier": "com.msgblast.mac", "CFBundleName": "msgblast"}
        demo = preview.configure_info(info, preview.VARIANTS["demo"], "a" * 40)
        self.assertTrue(demo["msgblastDemo"])
        self.assertEqual(demo["CFBundleIdentifier"], "com.msgblast.demo")
        self.assertEqual(demo["msgblastSupportDirectory"], "msgblast-Demo")
        self.assertEqual(demo["SUFeedURL"], "")
        self.assertFalse(demo["SUEnableAutomaticChecks"])
        development = preview.configure_info(info, preview.VARIANTS["development"], "b" * 40)
        self.assertFalse(development["msgblastDemo"])
        self.assertEqual(development["CFBundleIdentifier"], "com.msgblast.development")
        self.assertEqual(development["msgblastSupportDirectory"], "msgblast-Dev")
        self.assertNotEqual(development["CFBundleIdentifier"], demo["CFBundleIdentifier"])
        preview.verify_configured_info(development, preview.VARIANTS["development"], "b" * 40)
        self.assertFalse(development["SUAllowsAutomaticUpdates"])
        bad = dict(preview.VARIANTS["development"])
        bad["bundle_id"] = "com.msgblast.mac"
        with self.assertRaises(RuntimeError):
            preview.configure_info(info, bad, "a" * 40)

    def test_workspace_copy_refuses_the_source_tree(self):
        with self.assertRaises(RuntimeError):
            preview.copy_workspace(preview.ROOT / "build-preview-inside")

    def test_compiled_icon_colors_distinguish_the_three_artworks(self):
        self.assertEqual(preview.classify_icon_color(22, 196, 51), "green")
        self.assertEqual(preview.classify_icon_color(64, 140, 143), "blue-green")
        self.assertEqual(preview.classify_icon_color(44, 23, 193), "blue")
        self.assertEqual(preview.expected_icon_color(preview.VARIANTS["development"]), "blue-green")
        self.assertEqual(preview.expected_icon_color(preview.VARIANTS["demo"]), "blue")

    def test_manifest_records_sha_run_and_expiry_without_a_feed(self):
        document = preview.manifest("c" * 40, "https://github.com/mgalpert/msgblast/actions/runs/1", [])
        self.assertEqual(document["retention_days"], 14)
        self.assertIn("14 days", document["expiry"])
        self.assertFalse(document["production_feed_used"])
        self.assertNotIn("latest.zip", json_text(document))


def json_text(document):
    import json
    return json.dumps(document)


class EvidenceGateTests(unittest.TestCase):
    def body(self, sha):
        return f"""## Screenshots

<img alt="Preview workflow" src="https://example.com/preview.png" />

## Video

<video src="https://example.com/preview.mp4" controls></video>

Evidence-SHA: {sha}
"""

    def test_remote_embeds_for_the_reviewed_commit_pass(self):
        sha = "d" * 40
        self.assertEqual(evidence.problems(self.body(sha), sha), [])

    def test_text_placeholders_and_stale_or_local_evidence_fail(self):
        sha = "e" * 40
        self.assertTrue(evidence.problems("## Screenshots\n\nterminal output\n\n## Video\n\nno video\n", sha))
        stale = self.body("f" * 40)
        self.assertTrue(any("does not match" in item for item in evidence.problems(stale, sha)))
        local = self.body(sha).replace("https://example.com/preview.png", "file:///opt/cursor/artifacts/preview.png")
        self.assertTrue(any("local-only" in item for item in evidence.problems(local, sha)))
        placeholder = self.body(sha).replace("Preview workflow", "placeholder")
        self.assertTrue(any("placeholder" in item for item in evidence.problems(placeholder, sha)))

    def test_cursor_branch_previews_need_checksums_and_reject_the_production_zip(self):
        sha = "a" * 40
        ready = self.body(sha) + """
msgblast Dev and msgblast Demo fixture
https://github.com/mgalpert/msgblast/actions/runs/123
""" + ("b" * 64) + "\n"
        self.assertEqual(evidence.problems(ready, sha, require_preview=True), [])
        missing = self.body(sha)
        self.assertTrue(evidence.problems(missing, sha, require_preview=True))
        published = ready + "https://updates.msgblast.app/latest.zip\n"
        self.assertTrue(any("production update host" in item for item in evidence.problems(published, sha, require_preview=True)))

    def test_packaging_script_stays_nonpublishing(self):
        import sys
        sys.path.insert(0, str(ROOT / "scripts"))
        source = (ROOT / "scripts/build_preview_apps.py").read_text()
        self.assertIn("--sequesterRsrc", source)
        self.assertNotIn("automate_release", source)
        self.assertNotIn("MSGBLAST_SPARKLE_PRIVATE_KEY", source)
        self.assertNotIn("latest.zip", source)
        build = load("build_preview_apps")
        demo = build.instructions(preview.VARIANTS["demo"])
        development = build.instructions(preview.VARIANTS["development"])
        self.assertIn("Fixture mode", demo)
        self.assertIn("msgblastDemo", demo)
        self.assertIn("Full Disk Access", development)
        self.assertIn("not a fixture", development)
        self.assertIn("msgblast-Dev", development)
        self.assertIn("/Applications/msgblast.app", development)
