#!/usr/bin/env python3
"""Restore the pinned 550-page default Mushaf before a clean Flutter build.

Run: python3 tool/restore_bundled_mushaf.py
Use --archive /path/to/16_line.zip to verify and restore an existing download.
Existing nonempty asset folders are validated and never replaced.
"""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path, PurePosixPath
import stat
import struct
import sys
import tempfile
from urllib.parse import urlsplit
from urllib.request import Request, urlopen
from zipfile import ZIP_DEFLATED, ZIP_STORED, BadZipFile, ZipFile, ZipInfo


PACK_URL = "https://quran.opplexify.com/assets/asset_packs/16_line.zip"
EXPECTED_SHA256 = "eabd9a084938d663fb8964299b261fbcc3ccd1fd851591ecbdf1fb22fa98655b"
EXPECTED_ARCHIVE_SIZE = 91_484_586
PAGE_NAMES = frozenset(f"{page:03}.webp" for page in range(1, 551))
MAX_FILE_SIZE = 2 * 1024 * 1024
MAX_UNCOMPRESSED_SIZE = 128 * 1024 * 1024
DIRECTORIES = {"16_line/", "16_line/mobile-app-source/"}


class RestoreError(Exception):
    pass


def _check_webp_header(header: bytes, size: int, name: str) -> None:
    if (len(header) != 12 or header[:4] != b"RIFF" or
            header[8:] != b"WEBP" or struct.unpack("<I", header[4:8])[0] + 8 != size):
        raise RestoreError(f"Invalid WebP page: {name}")


def validate_bundle(bundle: Path) -> None:
    if bundle.is_symlink() or not bundle.is_dir():
        raise RestoreError("The existing 16-line bundle must be a regular directory")
    if {path.name for path in bundle.iterdir()} != {"mobile-app-source"}:
        raise RestoreError("Existing 16-line assets have an unexpected layout; left untouched")
    pages = bundle / "mobile-app-source"
    if pages.is_symlink() or not pages.is_dir():
        raise RestoreError("The page directory must not be a link")
    entries = list(pages.iterdir())
    if {path.name for path in entries} != PAGE_NAMES:
        raise RestoreError("Existing 16-line assets are incomplete or different; left untouched")
    total = 0
    for page in entries:
        if page.is_symlink() or not page.is_file():
            raise RestoreError(f"Page must be a regular file: {page.name}")
        size = page.stat().st_size
        if size < 12 or size > MAX_FILE_SIZE:
            raise RestoreError(f"Page size is outside the bundle limits: {page.name}")
        total += size
        with page.open("rb") as source:
            _check_webp_header(source.read(12), size, page.name)
    if total > MAX_UNCOMPRESSED_SIZE:
        raise RestoreError("The bundle exceeds its uncompressed size limit")


def _target_for(project_root: Path) -> Path:
    root = project_root.resolve(strict=True)
    if not (root / "pubspec.yaml").is_file():
        raise RestoreError("Project root must contain pubspec.yaml")
    target = root / "assets" / "asset_packs" / "16_line"
    for ancestor in (root / "assets", target.parent, target):
        if ancestor.is_symlink() or not ancestor.resolve().is_relative_to(root):
            raise RestoreError("Asset path must stay inside the project without links")
    return target


def _verify_archive(path: Path) -> None:
    if path.stat().st_size != EXPECTED_ARCHIVE_SIZE:
        raise RestoreError("Archive size differs from the pinned 16-line backup")
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    if digest.hexdigest() != EXPECTED_SHA256:
        raise RestoreError("Archive SHA-256 differs from the pinned 16-line backup")


def _download(path: Path) -> None:
    request = Request(PACK_URL, headers={
        "Accept-Encoding": "identity", "User-Agent": "QuranReader-AssetBootstrap/1",
    })
    received = 0
    with urlopen(request, timeout=60) as response, path.open("xb") as output:
        if response.status != 200 or urlsplit(response.url).scheme != "https":
            raise RestoreError("Asset download requires a successful HTTPS response")
        for chunk in iter(lambda: response.read(1024 * 1024), b""):
            received += len(chunk)
            if received > EXPECTED_ARCHIVE_SIZE:
                raise RestoreError("Download exceeds the pinned archive size")
            output.write(chunk)
    _verify_archive(path)


def _validated_members(archive: ZipFile) -> list[ZipInfo]:
    members = archive.infolist()
    if len(members) > len(PAGE_NAMES) + len(DIRECTORIES):
        raise RestoreError("Archive has too many entries")
    seen: set[str] = set()
    pages: list[ZipInfo] = []
    total = 0
    for member in members:
        name = member.orig_filename
        parts = PurePosixPath(name).parts
        if (not name or "\\" in name or "\0" in name or ":" in name or
                name.startswith("/") or any(part in {".", ".."} for part in parts)):
            raise RestoreError("Unsafe archive path")
        identity = name.casefold()
        if identity in seen:
            raise RestoreError("Archive has duplicate paths")
        seen.add(identity)
        mode = stat.S_IFMT(member.external_attr >> 16)
        if mode not in {0, stat.S_IFREG, stat.S_IFDIR} or member.flag_bits & 1:
            raise RestoreError("Archive links, special files and encrypted entries are not allowed")
        if member.is_dir():
            if name not in DIRECTORIES or member.file_size != 0:
                raise RestoreError("Unexpected archive directory")
            continue
        if (len(parts) != 3 or parts[:2] != ("16_line", "mobile-app-source") or
                name != f"16_line/mobile-app-source/{parts[-1]}" or
                parts[2] not in PAGE_NAMES or mode == stat.S_IFDIR):
            raise RestoreError("Unexpected archive page path")
        if (member.compress_type not in {ZIP_STORED, ZIP_DEFLATED} or
                member.file_size < 12 or member.file_size > MAX_FILE_SIZE or
                member.file_size > max(1, member.compress_size) * 50):
            raise RestoreError("Archive page exceeds extraction limits")
        total += member.file_size
        if total > MAX_UNCOMPRESSED_SIZE:
            raise RestoreError("Archive exceeds its uncompressed size limit")
        pages.append(member)
    if {PurePosixPath(page.filename).name for page in pages} != PAGE_NAMES:
        raise RestoreError("Archive must contain exactly pages 001.webp through 550.webp")
    return pages


def _extract_archive(archive_path: Path, staged: Path) -> None:
    with ZipFile(archive_path) as archive:
        pages = _validated_members(archive)
        destination = staged / "mobile-app-source"
        destination.mkdir(parents=True)
        for member in pages:
            page_path = destination / PurePosixPath(member.filename).name
            written = 0
            with archive.open(member) as source, page_path.open("xb") as output:
                header = source.read(12)
                _check_webp_header(header, member.file_size, page_path.name)
                output.write(header)
                written += len(header)
                for chunk in iter(lambda: source.read(1024 * 1024), b""):
                    written += len(chunk)
                    if written > MAX_FILE_SIZE:
                        raise RestoreError("Decompressed page exceeds its size limit")
                    output.write(chunk)
            if written != member.file_size:
                raise RestoreError("Decompressed page is incomplete")
    validate_bundle(staged)


def restore(project_root: Path, archive_path: Path | None = None) -> bool:
    target = _target_for(project_root)
    if target.exists() and (not target.is_dir() or any(target.iterdir())):
        validate_bundle(target)
        print("Existing 550-page 16-line bundle validated; all files left untouched.")
        return False
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".16-line-restore-", dir=target.parent) as temporary:
        stage = Path(temporary)
        if archive_path is None:
            archive_path = stage / "16_line.zip"
            print("Downloading the pinned default 16-line Mushaf backup…")
            _download(archive_path)
        else:
            archive_path = archive_path.resolve(strict=True)
            _verify_archive(archive_path)
        staged = stage / "publish"
        _extract_archive(archive_path, staged)
        if target.exists():
            if not target.is_dir() or any(target.iterdir()):
                raise RestoreError("16-line assets appeared during restore; left untouched")
            target.rmdir()
        staged.rename(target)
    print("Restored 550 verified 16-line scan pages from the pinned backup.")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, help="Use a local copy of the pinned ZIP")
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    arguments = parser.parse_args()
    try:
        restore(arguments.project_root, arguments.archive)
    except (RestoreError, OSError, BadZipFile) as error:
        print(f"Asset restore failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
