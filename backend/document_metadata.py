"""
Book and comic metadata extraction for TTSPlayer indexer.

Lightweight stdlib-only enrichment (ADR-025):
- EPUB: OPF title / creator via zipfile + ElementTree
- PDF: filename stem only (no heavy PDF parsing in Phase 6.1)
- CBZ: optional ComicInfo.xml title / writer / series / page count

Failures always fall back to deterministic filename-based fields.
"""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

_COMIC_INFO_NAMES = frozenset({"comicinfo.xml"})


def normalize_text(value: str | None) -> str | None:
    if value is None:
        return None
    cleaned = value.strip()
    return cleaned if cleaned else None


def clean_title(stem: str) -> str:
    return stem.replace(".", " ").replace("_", " ").strip() or stem


def _local_name(tag: str) -> str:
    if "}" in tag:
        return tag.rsplit("}", 1)[-1]
    return tag


def _text_of(element: ET.Element | None) -> str | None:
    if element is None or element.text is None:
        return None
    return normalize_text(element.text)


def _find_child(parent: ET.Element, names: set[str]) -> ET.Element | None:
    wanted = {n.lower() for n in names}
    for child in parent:
        if _local_name(child.tag).lower() in wanted:
            return child
    return None


def _parse_int(value: str | None) -> int | None:
    text = normalize_text(value)
    if text is None:
        return None
    match = re.match(r"(\d+)", text)
    if not match:
        return None
    try:
        parsed = int(match.group(1))
        return parsed if parsed > 0 else None
    except ValueError:
        return None


def _read_epub_opf_metadata(file_path: Path) -> dict[str, str | None]:
    """Best-effort EPUB metadata. Returns empty dict on any failure."""
    try:
        with zipfile.ZipFile(file_path, "r") as zf:
            names = zf.namelist()
            container_name = next(
                (n for n in names if n.lower().endswith("meta-inf/container.xml")),
                None,
            )
            if container_name is None:
                return {}
            container_root = ET.fromstring(zf.read(container_name))
            rootfile = None
            for el in container_root.iter():
                if _local_name(el.tag).lower() == "rootfile":
                    rootfile = el.attrib.get("full-path") or el.attrib.get("fullPath")
                    break
            if not rootfile:
                return {}
            # EPUB paths use forward slashes inside the archive.
            opf_name = next(
                (n for n in names if n.replace("\\", "/") == rootfile.replace("\\", "/")),
                None,
            )
            if opf_name is None:
                # Try case-insensitive match.
                target = rootfile.replace("\\", "/").lower()
                opf_name = next(
                    (n for n in names if n.replace("\\", "/").lower() == target),
                    None,
                )
            if opf_name is None:
                return {}
            opf_root = ET.fromstring(zf.read(opf_name))
            metadata = _find_child(opf_root, {"metadata"})
            if metadata is None:
                for el in opf_root.iter():
                    if _local_name(el.tag).lower() == "metadata":
                        metadata = el
                        break
            if metadata is None:
                return {}

            title = None
            creator = None
            for el in metadata:
                local = _local_name(el.tag).lower()
                if local == "title" and title is None:
                    title = _text_of(el)
                elif local == "creator" and creator is None:
                    creator = _text_of(el)
            return {"title": title, "author": creator}
    except (OSError, zipfile.BadZipFile, ET.ParseError, KeyError, ValueError):
        return {}


def _read_comicinfo_from_zip(file_path: Path) -> dict[str, str | int | None]:
    """Best-effort ComicInfo.xml from a CBZ (ZIP) archive."""
    try:
        with zipfile.ZipFile(file_path, "r") as zf:
            info_name = next(
                (n for n in zf.namelist() if Path(n).name.lower() in _COMIC_INFO_NAMES),
                None,
            )
            if info_name is None:
                return {}
            root = ET.fromstring(zf.read(info_name))
            # ComicInfo root may be the document element itself.
            title = _text_of(_find_child(root, {"title"}))
            series = _text_of(_find_child(root, {"series"}))
            writer = _text_of(_find_child(root, {"writer"}))
            if writer is None:
                writer = _text_of(_find_child(root, {"penciller"}))
            page_count = _parse_int(_text_of(_find_child(root, {"pagecount"})))
            return {
                "title": title,
                "author": writer,
                "series": series,
                "page_count": page_count,
            }
    except (OSError, zipfile.BadZipFile, ET.ParseError, KeyError, ValueError):
        return {}


def build_book_metadata(file_path: Path) -> dict:
    """
    Emit optional book enrichment fields.

    Always includes a deterministic title (filename stem unless EPUB OPF title wins).
    """
    stem_title = clean_title(file_path.stem)
    suffix = file_path.suffix.lower()
    title = stem_title
    author = None

    if suffix == ".epub":
        opf = _read_epub_opf_metadata(file_path)
        embedded_title = normalize_text(opf.get("title"))
        if embedded_title:
            title = embedded_title
        author = normalize_text(opf.get("author"))

    result: dict = {
        "title": title,
    }
    if author is not None:
        result["author"] = author
    return result


def build_comic_metadata(file_path: Path) -> dict:
    """
    Emit optional comic enrichment fields.

    CBZ may include ComicInfo.xml.
    """
    stem_title = clean_title(file_path.stem)
    suffix = file_path.suffix.lower()
    title = stem_title
    author = None
    series = None
    page_count = None

    if suffix == ".cbz":
        info = _read_comicinfo_from_zip(file_path)
        embedded_title = normalize_text(
            info.get("title") if isinstance(info.get("title"), str) else None
        )
        if embedded_title:
            title = embedded_title
        author = normalize_text(
            info.get("author") if isinstance(info.get("author"), str) else None
        )
        series = normalize_text(
            info.get("series") if isinstance(info.get("series"), str) else None
        )
        raw_pages = info.get("page_count")
        if isinstance(raw_pages, int) and raw_pages > 0:
            page_count = raw_pages

    result: dict = {
        "title": title,
    }
    if author is not None:
        result["author"] = author
    if series is not None:
        result["series"] = series
    if page_count is not None:
        result["page_count"] = page_count
    return result
