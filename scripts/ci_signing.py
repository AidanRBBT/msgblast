#!/usr/bin/env python3
"""Install Developer ID credentials in a temporary CI keychain and remove them."""
import argparse
import base64
import binascii
import json
import os
from pathlib import Path
import re
import secrets
import shlex
import shutil
import subprocess
import sys
import tempfile
import uuid

import release


class SigningError(Exception):
    pass


def required(name, *, strip=True):
    value = os.environ.get(name, "")
    if strip:
        value = value.strip()
    if not value:
        raise SigningError("Missing signing configuration: " + name)
    return value


def run(arguments):
    result = subprocess.run(arguments, capture_output=True, text=True)
    if result.returncode:
        # Some tools repeat argv or credential input in diagnostics. Never echo it.
        raise SigningError(" ".join(arguments[:2]) + " failed during signing credential setup/cleanup")
    return result.stdout


def context():
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise SigningError("Credential installation is restricted to GitHub Actions runners")
    root = Path(required("RUNNER_TEMP")).resolve()
    if not root.is_dir() or root == Path("/"):
        raise SigningError("RUNNER_TEMP must name an existing runner directory")
    return root, root / "msgblast-signing-state.json"


def private_file(path, data):
    with open(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "wb") as file:
        file.write(data)


def setup():
    root, state_file = context()
    if state_file.exists():
        raise SigningError("Previous signing state needs cleanup before setup")
    identity = required("MSGBLAST_DEVELOPER_ID_IDENTITY")
    team = required("MSGBLAST_APPLE_TEAM_ID")
    if not release.developer_id_identity_matches(identity, team):
        raise SigningError("Developer ID Application identity must match the configured Apple team")
    password = required("MSGBLAST_DEVELOPER_ID_P12_PASSWORD", strip=False)
    key_id = required("MSGBLAST_NOTARY_KEY_ID")
    issuer = required("MSGBLAST_NOTARY_ISSUER_ID")
    if not re.fullmatch(r"[A-Za-z0-9]{10,}", key_id):
        raise SigningError("Notarization Key ID must contain at least 10 letters/digits")
    try:
        issuer = str(uuid.UUID(issuer))
        certificate = base64.b64decode(required("MSGBLAST_DEVELOPER_ID_P12"), validate=True)
    except (ValueError, binascii.Error):
        raise SigningError("Invalid certificate encoding or notarization Issuer ID") from None
    api_key = required("MSGBLAST_NOTARY_API_KEY").encode()
    if not certificate or b"-----BEGIN PRIVATE KEY-----" not in api_key or b"-----END PRIVATE KEY-----" not in api_key:
        raise SigningError("Certificate and notarization API private key are required")
    previous = shlex.split(run(["security", "list-keychains", "-d", "user"]))
    directory = Path(tempfile.mkdtemp(prefix="msgblast-signing-", dir=root)).resolve()
    keychain = directory / "signing.keychain-db"
    private_file(state_file, json.dumps({"directory": str(directory), "previous_keychains": previous}).encode())
    try:
        p12 = directory / "certificate.p12"
        key = directory / "notary.p8"
        private_file(p12, certificate)
        private_file(key, api_key)
        ephemeral_password = secrets.token_urlsafe(32)
        run(["security", "create-keychain", "-p", ephemeral_password, str(keychain)])
        run(["security", "set-keychain-settings", "-lut", "21600", str(keychain)])
        run(["security", "unlock-keychain", "-p", ephemeral_password, str(keychain)])
        run(["security", "import", str(p12), "-k", str(keychain), "-P", password,
             "-T", "/usr/bin/codesign", "-T", "/usr/bin/security"])
        run(["security", "set-key-partition-list", "-S", "apple-tool:,apple:,codesign:", "-s",
             "-k", ephemeral_password, str(keychain)])
        run(["security", "list-keychains", "-d", "user", "-s", str(keychain), *previous])
        identities = run(["security", "find-identity", "-v", "-p", "codesigning", str(keychain)])
        if '"' + identity + '"' not in identities:
            raise SigningError("The imported certificate does not provide the configured signing identity")
        profile = "msgblast-release"
        run(["xcrun", "notarytool", "store-credentials", profile, "--key", str(key),
             "--key-id", key_id, "--issuer", issuer, "--keychain", str(keychain)])
        # Credentials now live in the temporary keychain. Remove their import files.
        p12.unlink()
        key.unlink()
        with Path(required("GITHUB_ENV")).open("a") as file:
            file.write(f"MSGBLAST_NOTARY_PROFILE={profile}\nMSGBLAST_NOTARY_KEYCHAIN={keychain}\n")
    except Exception:
        cleanup()
        raise


def cleanup():
    root, state_file = context()
    if not state_file.exists():
        return
    state = json.loads(state_file.read_text())
    directory = Path(state["directory"]).resolve()
    if directory.parent != root or not directory.name.startswith("msgblast-signing-"):
        raise SigningError("Signing cleanup path is outside the runner credential directory")
    try:
        run(["security", "list-keychains", "-d", "user", "-s", *state["previous_keychains"]])
    finally:
        try:
            if (directory / "signing.keychain-db").exists():
                run(["security", "delete-keychain", str(directory / "signing.keychain-db")])
        finally:
            shutil.rmtree(directory)
            state_file.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("setup", "cleanup"))
    options = parser.parse_args()
    try:
        setup() if options.action == "setup" else cleanup()
        return 0
    except (SigningError, OSError, ValueError, KeyError) as error:
        print("Signing credentials: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
