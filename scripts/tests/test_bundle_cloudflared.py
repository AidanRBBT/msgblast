"""Downloaded helper bytes must be pinned and extracted without trusting archive paths."""
from pathlib import Path
import hashlib
import importlib.util
import io
import tarfile
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("bundle_cloudflared", ROOT / "scripts/bundle_cloudflared.py")
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


def archive(member="cloudflared", kind=tarfile.REGTYPE):
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode="w:gz") as tar:
        info = tarfile.TarInfo(member)
        info.type = kind
        info.size = 7 if kind == tarfile.REGTYPE else 0
        tar.addfile(info, io.BytesIO(b"fixture") if info.size else None)
    return stream.getvalue()


class BundledHelperTests(unittest.TestCase):
    def asset(self, data):
        return {"url": "https://github.com/cloudflare/cloudflared/releases/download/fixture/helper.tgz",
                "sha256": hashlib.sha256(data).hexdigest()}

    def test_verified_download_and_cache_return_identical_binary(self):
        data = archive()
        with tempfile.TemporaryDirectory() as temporary:
            cache = Path(temporary)
            with mock.patch.object(helper.urllib.request, "urlopen", return_value=io.BytesIO(data)):
                first = helper.fetch_binary(self.asset(data), cache)
            with mock.patch.object(helper.urllib.request, "urlopen", side_effect=AssertionError("Cache should avoid download")):
                second = helper.fetch_binary(self.asset(data), cache)
            self.assertEqual(first, b"fixture")
            self.assertEqual(second, first)

    def test_checksum_mismatch_never_returns_executable_bytes(self):
        data = archive()
        with tempfile.TemporaryDirectory() as temporary:
            with mock.patch.object(helper.urllib.request, "urlopen", return_value=io.BytesIO(b"tampered")):
                with self.assertRaisesRegex(RuntimeError, "checksum"):
                    helper.fetch_binary(self.asset(data), Path(temporary))

    def test_tampered_cache_is_checked_again(self):
        data = archive()
        with tempfile.TemporaryDirectory() as temporary:
            cache = Path(temporary)
            with mock.patch.object(helper.urllib.request, "urlopen", return_value=io.BytesIO(data)):
                helper.fetch_binary(self.asset(data), cache)
            next(cache.glob("*.tgz")).write_bytes(b"tampered")
            with self.assertRaisesRegex(RuntimeError, "checksum"):
                helper.fetch_binary(self.asset(data), cache)

    def test_unexpected_archive_paths_and_symlinks_are_rejected(self):
        for data in [archive("../cloudflared"), archive(kind=tarfile.SYMTYPE)]:
            with self.subTest(data=data[:8]), tempfile.TemporaryDirectory() as temporary:
                with mock.patch.object(helper.urllib.request, "urlopen", return_value=io.BytesIO(data)):
                    with self.assertRaisesRegex(RuntimeError, "archive"):
                        helper.fetch_binary(self.asset(data), Path(temporary))

    def test_supported_architectures_are_selected_without_duplicates(self):
        self.assertEqual(helper.architectures("arm64 x86_64 arm64"), ["arm64", "x86_64"])
        for value in ["", "i386", "arm64 i386"]:
            with self.assertRaisesRegex(RuntimeError, "architecture"):
                helper.architectures(value)
