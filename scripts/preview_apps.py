"""Plan non-publishing macOS preview apps. Building still requires Xcode."""
from pathlib import Path
import hashlib
import json
import shutil


ROOT = Path(__file__).resolve().parents[1]
POLISHED = ROOT / "output/icon-gradients/32-WhiteToClearSoftFade-Polished.icon"
BLUE_GREEN = ROOT / "output/icon-gradients/32-WhiteToClearSoftFadeBlueGreen.icon"
BLUE = ROOT / "output/icon-gradients/32-WhiteToClearSoftFadeBlue.icon"
RETENTION_DAYS = 14

VARIANTS = {
    "development": {
        "id": "development",
        "label": "blue-green development",
        "fixture": False,
        "app_name": "msgblast Dev.app",
        "bundle_id": "com.msgblast.development",
        "bundle_name": "msgblast Dev",
        "display_name": "msgblast Dev",
        "icon_name": "AppIcon",
        "icon_source": BLUE_GREEN,
        "replace_app_icon": True,
        "demo": False,
        "support_directory": "msgblast-Dev",
        "artifact_prefix": "msgblast-dev",
    },
    "demo": {
        "id": "demo",
        "label": "blue demo fixture",
        "fixture": True,
        "app_name": "msgblast Demo.app",
        "bundle_id": "com.msgblast.demo",
        "bundle_name": "msgblast Demo",
        "display_name": "msgblast Demo",
        "icon_name": "AppIconDemo",
        "icon_source": BLUE,
        "replace_app_icon": False,
        "demo": True,
        "support_directory": "msgblast-Demo",
        "artifact_prefix": "msgblast-demo",
    },
}


def icon_fill(directory):
    return json.loads((Path(directory) / "icon.json").read_text())["fill"]


def assert_committed_icons_unchanged():
    if icon_fill(ROOT / "msgblast/AppIcon.icon") != icon_fill(POLISHED):
        raise RuntimeError("Committed AppIcon.icon must stay the green production artwork")
    if icon_fill(ROOT / "msgblast/AppIconDemo.icon") != icon_fill(BLUE):
        raise RuntimeError("Committed AppIconDemo.icon must stay the saved blue artwork")
    if icon_fill(BLUE_GREEN) == icon_fill(POLISHED) or icon_fill(BLUE) == icon_fill(POLISHED):
        raise RuntimeError("Preview icon fills must differ from production green")


def stage_icons(workspace):
    """Select preview artwork only inside an isolated copy of the project."""
    workspace = Path(workspace)
    app_icon = workspace / "msgblast/AppIcon.icon"
    demo_icon = workspace / "msgblast/AppIconDemo.icon"
    if not app_icon.is_dir() or not demo_icon.is_dir():
        raise RuntimeError("Isolated workspace is missing icon resources")
    if Path(workspace).resolve() == ROOT.resolve():
        raise RuntimeError("Refusing to replace icons in the committed source tree")
    shutil.rmtree(app_icon)
    shutil.copytree(BLUE_GREEN, app_icon)
    if icon_fill(app_icon) != icon_fill(BLUE_GREEN):
        raise RuntimeError("Development workspace did not receive the blue-green icon")
    if icon_fill(demo_icon) != icon_fill(BLUE):
        raise RuntimeError("Demo workspace must keep the saved blue AppIconDemo artwork")
    assert_committed_icons_unchanged()


def configure_info(info, variant, source_revision):
    """Return the Info.plist fields that make a preview app unmistakable and isolated."""
    if variant["bundle_id"] == "com.msgblast.mac" or variant["app_name"] == "msgblast.app":
        raise RuntimeError("Preview apps cannot use the production identity")
    updated = dict(info)
    updated.update({
        "CFBundleIdentifier": variant["bundle_id"],
        "CFBundleName": variant["bundle_name"],
        "CFBundleDisplayName": variant["display_name"],
        "CFBundleIconName": variant["icon_name"],
        "SUFeedURL": "",
        "SUPublicEDKey": "",
        "SUEnableAutomaticChecks": False,
        "SUAutomaticallyUpdate": False,
        "SUAllowsAutomaticUpdates": False,
        "msgblastDisableUpdates": True,
        "msgblastDemo": variant["demo"],
        "msgblastSupportDirectory": variant["support_directory"],
        "msgblastPreviewVariant": variant["id"],
        "msgblastSourceRevision": source_revision,
    })
    if variant["fixture"] and updated["msgblastDemo"] is not True:
        raise RuntimeError("Fixture mode requires msgblastDemo, not only a blue icon")
    if not variant["fixture"] and updated["msgblastDemo"] is True:
        raise RuntimeError("The development preview must stay out of fixture mode")
    return updated


def verify_configured_info(info, variant, source_revision):
    expected = configure_info(info, variant, source_revision)
    for key, value in expected.items():
        if info.get(key) != value:
            raise RuntimeError(f"{variant['id']} Info.plist {key} is {info.get(key)!r}, expected {value!r}")
    feed = info.get("SUFeedURL") or ""
    if "updates.msgblast.app" in feed or info.get("SUPublicEDKey"):
        raise RuntimeError("Preview apps cannot carry the production update feed or key")
    if info.get("CFBundleIdentifier") == "com.msgblast.mac":
        raise RuntimeError("Preview bundle ID collided with production")


def classify_icon_color(red, green, blue):
    if green > red + 40 and green > blue + 40:
        return "green"
    if blue > red + 40 and blue > green + 20:
        return "blue"
    if blue > red + 20 and green > red + 20:
        return "blue-green"
    return "unknown"


def expected_icon_color(variant):
    return "blue-green" if variant["id"] == "development" else "blue"


def sha256_file(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def manifest(source_revision, run_url, variants):
    return {
        "source_revision": source_revision,
        "run_url": run_url,
        "retention_days": RETENTION_DAYS,
        "expiry": f"GitHub deletes these artifacts {RETENTION_DAYS} days after the workflow run.",
        "production_feed_used": False,
        "variants": variants,
    }


def copy_workspace(destination):
    destination = Path(destination).resolve()
    root = ROOT.resolve()
    if destination == root or root in destination.parents:
        raise RuntimeError("Isolated workspace must be outside the source tree")

    def ignore(directory, names):
        skipped = {".git", "build", ".venv", "node_modules", "__pycache__"}
        return [name for name in names if name in skipped]

    shutil.copytree(ROOT, destination, ignore=ignore, symlinks=True)
    stage_icons(destination)
    return destination
