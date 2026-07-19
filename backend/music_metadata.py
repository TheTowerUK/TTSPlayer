"""
Music metadata extraction and normalisation for TTSPlayer indexer.

Uses ffprobe (already required for video duration) for embedded tags — no extra
pip dependencies. Extraction failures fall back to folder/filename heuristics.
"""

from __future__ import annotations

import json
import re
import subprocess
import unicodedata
from pathlib import Path

UNKNOWN_TRACK = "Unknown Track"
UNKNOWN_ARTIST = "Unknown Artist"
UNKNOWN_ALBUM = "Unknown Album"

_TRACK_PREFIX_RE = re.compile(
    r"^\s*(\d{1,3})[\s._\-]+",
    re.IGNORECASE,
)


def normalize_text(value: str | None) -> str | None:
    """Trim and treat empty strings as missing."""
    if value is None:
        return None
    cleaned = value.strip()
    return cleaned if cleaned else None


def normalize_group_key(value: str | None) -> str:
    """Case- and whitespace-normalised key for deterministic grouping."""
    text = normalize_text(value) or ""
    folded = unicodedata.normalize("NFKC", text).casefold()
    return " ".join(folded.split())


def parse_int_tag(value: str | None) -> int | None:
    if value is None:
        return None
    raw = value.strip()
    if not raw:
        return None
    if "/" in raw:
        raw = raw.split("/", 1)[0].strip()
    try:
        parsed = int(raw)
        return parsed if parsed > 0 else None
    except ValueError:
        return None


def parse_year_tag(value: str | None) -> int | None:
    text = normalize_text(value)
    if not text:
        return None
    match = re.match(r"(\d{4})", text)
    if not match:
        return None
    try:
        return int(match.group(1))
    except ValueError:
        return None


def parse_track_number_from_filename(stem: str) -> int | None:
    match = _TRACK_PREFIX_RE.match(stem)
    if not match:
        return None
    return parse_int_tag(match.group(1))


def clean_title(stem: str) -> str:
    """Turn a filename stem into a human-readable title."""
    without_prefix = _TRACK_PREFIX_RE.sub("", stem).strip()
    base = without_prefix or stem
    return base.replace(".", " ").replace("_", " ").strip() or UNKNOWN_TRACK


def folder_context(file_path: Path) -> tuple[str | None, str | None]:
    """
    Derive (artist_folder, album_folder) hints from path components.

    Artist/Album/track layout requires at least six path parts on Windows
    (drive + 4 folders + file). Shallow Album/track uses album folder only.
    """
    parts = file_path.parts
    album_folder = normalize_text(parts[-2]) if len(parts) >= 2 else None
    artist_folder = normalize_text(parts[-3]) if len(parts) >= 6 else None
    return artist_folder, album_folder


def extract_ffprobe_tags(file_path: str) -> dict[str, str]:
    """Read format/stream tags via ffprobe JSON. Returns empty dict on failure."""
    try:
        result = subprocess.run(
            [
                "ffprobe",
                "-v",
                "quiet",
                "-print_format",
                "json",
                "-show_format",
                "-show_streams",
                file_path,
            ],
            capture_output=True,
            text=True,
            timeout=15,
        )
        if result.returncode != 0 or not result.stdout.strip():
            return {}
        data = json.loads(result.stdout)
    except Exception:
        return {}

    tags: dict[str, str] = {}
    fmt_tags = (data.get("format") or {}).get("tags") or {}
    for key, value in fmt_tags.items():
        tags[str(key).lower()] = str(value).strip()

    for stream in data.get("streams") or []:
        if stream.get("codec_type") != "audio":
            continue
        stream_tags = stream.get("tags") or {}
        for key, value in stream_tags.items():
            lowered = str(key).lower()
            if lowered not in tags:
                tags[lowered] = str(value).strip()
        break

    return tags


def _first_tag(tags: dict[str, str], *keys: str) -> str | None:
    for key in keys:
        if key in tags:
            found = normalize_text(tags[key])
            if found:
                return found
    return None


def build_music_metadata(file_path: Path, tags: dict[str, str] | None = None) -> dict:
    """
    Resolve catalogue music fields and grouping keys for an audio file.

    Returns a dict suitable for merging into a media item (snake_case keys).
    """
    tag_map = tags if tags is not None else extract_ffprobe_tags(str(file_path))
    stem = file_path.stem
    artist_folder, album_folder = folder_context(file_path)

    embedded_title = _first_tag(tag_map, "title", "track")
    embedded_artist = _first_tag(tag_map, "artist", "performer")
    embedded_album = _first_tag(tag_map, "album")
    embedded_album_artist = _first_tag(
        tag_map,
        "album_artist",
        "albumartist",
        "band",
    )
    embedded_genre = _first_tag(tag_map, "genre")
    embedded_year = parse_year_tag(
        _first_tag(tag_map, "date", "year", "originaldate", "originalyear")
    )
    track_number = parse_int_tag(
        _first_tag(tag_map, "track", "tracknumber", "track_number")
    )
    if track_number is None:
        track_number = parse_track_number_from_filename(stem)
    disc_number = parse_int_tag(
        _first_tag(tag_map, "disc", "discnumber", "disc_number")
    )

    title = embedded_title or clean_title(stem) or UNKNOWN_TRACK

    artist = (
        embedded_artist
        or embedded_album_artist
        or artist_folder
        or UNKNOWN_ARTIST
    )
    album_artist = (
        embedded_album_artist
        or embedded_artist
        or artist_folder
        or UNKNOWN_ARTIST
    )
    album = embedded_album or album_folder or UNKNOWN_ALBUM

    artist_group_key = normalize_group_key(artist)
    parent_scope = normalize_group_key(str(file_path.parent))
    album_group_key = "|".join(
        [
            normalize_group_key(album_artist or artist),
            normalize_group_key(album),
            parent_scope,
        ]
    )

    payload: dict = {
        "media_kind": "audio",
        "title": title,
        "artist": artist,
        "album": album,
        "album_artist": album_artist,
        "track_number": track_number,
        "disc_number": disc_number,
        "genre": embedded_genre,
        "artist_group_key": artist_group_key,
        "album_group_key": album_group_key,
    }
    if embedded_year is not None:
        payload["year"] = embedded_year
    return payload
