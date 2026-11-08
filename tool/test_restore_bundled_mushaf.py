import hashlib
from pathlib import Path
import stat
import struct
import tempfile
import unittest
from unittest import mock
import warnings
from zipfile import ZIP_STORED, BadZipFile, ZipFile, ZipInfo

import restore_bundled_mushaf as bootstrap


class RestoreBundledMushafTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "pubspec.yaml").write_text("name: test_reader\n")
        self.archive = self.root / "bundle.zip"
        self.target = self.root / "assets/asset_packs/16_line"

    def build_archive(self, replace_first=None, extra=None):
        with ZipFile(self.archive, "w", compression=ZIP_STORED) as archive:
            for number, name in enumerate(sorted(bootstrap.PAGE_NAMES)):
                payload = b"RIFF" + struct.pack("<I", 12) + b"WEBP" + struct.pack("<Q", number)
                member = ZipInfo(f"16_line/mobile-app-source/{name}")
                member.external_attr = (stat.S_IFREG | 0o644) << 16
                if number == 0 and replace_first is not None:
                    member = replace_first(member)
                archive.writestr(member, payload)
            if extra is not None:
                with warnings.catch_warnings():
                    warnings.simplefilter("ignore", UserWarning)
                    archive.writestr(extra, b"test")

    def pinned_fixture(self):
        return mock.patch.multiple(bootstrap,
            EXPECTED_ARCHIVE_SIZE=self.archive.stat().st_size,
            EXPECTED_SHA256=hashlib.sha256(self.archive.read_bytes()).hexdigest())

    def test_restores_all_pages_then_preserves_existing_files_without_network(self):
        self.build_archive()
        with self.pinned_fixture():
            self.assertTrue(bootstrap.restore(self.root, self.archive))
        page = self.target / "mobile-app-source/001.webp"
        before = page.read_bytes(), page.stat().st_mtime_ns
        with mock.patch.object(bootstrap, "urlopen", side_effect=AssertionError("network used")):
            self.assertFalse(bootstrap.restore(self.root))
        self.assertEqual((page.read_bytes(), page.stat().st_mtime_ns), before)
        self.assertEqual(len(list((self.target / "mobile-app-source").iterdir())), 550)

    def test_nonempty_user_folder_is_never_replaced(self):
        self.target.mkdir(parents=True)
        keep = self.target / "keep.txt"
        keep.write_text("User asset")
        with self.assertRaises(bootstrap.RestoreError):
            bootstrap.restore(self.root)
        self.assertEqual(keep.read_text(), "User asset")
        self.assertEqual(list(self.target.iterdir()), [keep])

    def test_wrong_checksum_cannot_publish_assets(self):
        self.build_archive()
        with mock.patch.object(bootstrap, "EXPECTED_ARCHIVE_SIZE", self.archive.stat().st_size):
            with self.assertRaisesRegex(bootstrap.RestoreError, "SHA-256"):
                bootstrap.restore(self.root, self.archive)
        self.assertFalse(self.target.exists())

    def test_unsafe_and_duplicate_paths_cannot_escape_staging(self):
        for path in ["../outside.txt", "16_line/mobile-app-source/001.webp"]:
            self.build_archive(extra=path)
            with self.pinned_fixture(), self.assertRaises(bootstrap.RestoreError):
                bootstrap.restore(self.root, self.archive)
            self.assertFalse(self.target.exists())
            self.assertFalse((self.root / "outside.txt").exists())

    def test_archive_symlink_is_rejected(self):
        def symlink(member):
            member.create_system = 3
            member.external_attr = (stat.S_IFLNK | 0o777) << 16
            return member
        self.build_archive(replace_first=symlink)
        with self.pinned_fixture(), self.assertRaisesRegex(bootstrap.RestoreError, "links"):
            bootstrap.restore(self.root, self.archive)
        self.assertFalse(self.target.exists())

    def test_uncompressed_limit_is_checked_before_publication(self):
        self.build_archive()
        with self.pinned_fixture(), mock.patch.object(bootstrap, "MAX_UNCOMPRESSED_SIZE", 100):
            with self.assertRaisesRegex(bootstrap.RestoreError, "size limit"):
                bootstrap.restore(self.root, self.archive)
        self.assertFalse(self.target.exists())

    def test_crc_failure_leaves_no_partial_bundle(self):
        self.build_archive()
        with ZipFile(self.archive) as archive:
            first = archive.infolist()[0]
            offset = first.header_offset + 30 + len(first.filename.encode()) + len(first.extra) + 12
        data = bytearray(self.archive.read_bytes())
        data[offset] ^= 1
        self.archive.write_bytes(data)
        with self.pinned_fixture(), self.assertRaises(BadZipFile):
            bootstrap.restore(self.root, self.archive)
        self.assertFalse(self.target.exists())
        self.assertEqual(list(self.target.parent.glob(".16-line-restore-*")), [])


if __name__ == "__main__":
    unittest.main()
