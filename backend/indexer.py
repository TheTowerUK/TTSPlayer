"""
TTSPlayer — Filesystem Indexer
Crawls one or more media roots and writes a folder-tree catalog.json.
The folder structure itself is the source of truth — no hardcoded categories.

Usage — full scan (config-driven):
    python indexer.py --config ttsplayer.config.json

Usage — library rescan (merges one branch into existing catalog.json):
    python indexer.py --config ttsplayer.config.json --library-path "Y:\\Media\\Videos"

Usage — direct (quick testing, no config file):
    python indexer.py --root "Y:\\Media" --output "Y:\\Media\\catalog.json"

Standard library only — no third-party dependencies.
"""

import argparse
import hashlib
import json
import os
import secrets
import subprocess
import sys
import time
from pathlib import Path
from datetime import datetime, timezone

# Windows console (cp1252) cannot encode emoji or many Unicode characters.
# Reconfigure stdout/stderr to UTF-8 with replacement so filenames with
# emoji (e.g. 🔥) don't crash the process before the catalog is written.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

# ------------------------------------------------------------------
# Version constants
#
# SCANNER_VERSION   — semver string; bump when scanner behaviour changes.
# CATALOGUE_VERSION — integer; bump when the catalog.json schema changes
#                     in a way the client must detect. The app reads this
#                     to decide whether it understands the file.
# ------------------------------------------------------------------
SCANNER_VERSION = "0.3.3"
CATALOGUE_VERSION = 2

# ------------------------------------------------------------------
# Supported media extensions — single source for full and library scans.
# ------------------------------------------------------------------

_VIDEO_EXTENSIONS = frozenset({".mp4", ".mkv", ".mov", ".m4v", ".avi"})
_IMAGE_EXTENSIONS = frozenset({
    ".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".tif", ".tiff",
})
SUPPORTED_EXTENSIONS = _VIDEO_EXTENSIONS | _IMAGE_EXTENSIONS

# Lowercase names without the dot — written to catalog.json and shown in the client.
SUPPORTED_EXTENSIONS_SORTED: list[str] = sorted(
    ext.removeprefix(".") for ext in SUPPORTED_EXTENSIONS
)

# When True, unsupported file extensions are logged to stderr (never warnings).
_debug: bool = False


def make_catalogue_id(ts: datetime) -> str:
    """
    Generate a unique catalogue identity string.
    Format: <ISO-8601-UTC-second>-<6 uppercase hex chars>
    Example: 2026-07-01T20:14:53Z-8F2A1B

    The timestamp makes the ID human-readable and sortable.
    The random suffix makes concurrent runs on the same second distinct.
    Uses secrets.token_hex for cryptographic-quality randomness.
    """
    stamp = ts.strftime("%Y-%m-%dT%H:%M:%SZ")
    suffix = secrets.token_hex(3).upper()
    return f"{stamp}-{suffix}"


def make_catalogue_block(catalogue_id: str) -> dict:
    """Build the catalogue metadata block written to catalog.json."""
    return {
        "id": catalogue_id,
        "scanner_version": SCANNER_VERSION,
        "catalogue_version": CATALOGUE_VERSION,
        "supported_extensions": SUPPORTED_EXTENSIONS_SORTED,
    }


def _log_skipped_extension(path: Path) -> None:
    """Log an unsupported file extension in debug mode only."""
    if _debug:
        print(f"  [debug] skipped unsupported: {path.name}", file=sys.stderr)


def _log_skipped_sidecar(path: Path) -> None:
    """Log an artwork sidecar skipped from catalogue indexing."""
    if _debug:
        print(f"  [debug] skipped artwork sidecar: {path.name}", file=sys.stderr)


# Artwork sidecar basenames — keep aligned with ArtworkService named sidecars.
_ARTWORK_BASENAMES = frozenset({"poster", "folder", "cover", "thumb", "artwork"})
_SIDECAR_IMAGE_EXTENSIONS = frozenset({".jpg", ".jpeg", ".png", ".webp"})


def is_named_artwork_sidecar(filename: str) -> bool:
    """True for poster.jpg, cover.png, etc."""
    lower = filename.lower()
    for base in _ARTWORK_BASENAMES:
        for ext in _SIDECAR_IMAGE_EXTENSIONS:
            if lower == f"{base}{ext}":
                return True
    return False


def _folder_contains_video(file_entries: list[Path]) -> bool:
    return any(e.suffix.lower() in _VIDEO_EXTENSIONS for e in file_entries)


def _video_stems_in_folder(file_entries: list[Path]) -> set[str]:
    return {
        e.stem.lower()
        for e in file_entries
        if e.suffix.lower() in _VIDEO_EXTENSIONS
    }


def is_artwork_sidecar(entry: Path, file_entries: list[Path]) -> bool:
    """
    True when an image file is acting as artwork for sibling video media.

    Named sidecars (poster.jpg, cover.png, …) are excluded only when the
    folder also contains video files.  Stem-matched images (movie.jpg beside
    movie.mp4) are excluded whenever a video with the same stem exists.
    Standalone images in image libraries remain indexed.
    """
    if entry.suffix.lower() not in _IMAGE_EXTENSIONS:
        return False

    has_video = _folder_contains_video(file_entries)
    if is_named_artwork_sidecar(entry.name):
        return has_video

    return entry.stem.lower() in _video_stems_in_folder(file_entries)


def _index_files_in_folder(
    file_entries: list[Path],
    warnings: list[dict],
    counters: dict,
    indent: str = "",
) -> list[dict]:
    """Index supported media files, omitting artwork sidecars."""
    items: list[dict] = []
    for entry in file_entries:
        if is_artwork_sidecar(entry, file_entries):
            _log_skipped_sidecar(entry)
            continue
        item = _handle_media_file(entry, warnings, counters, indent=indent)
        if item is not None:
            items.append(item)
    return items


def _handle_media_file(
    entry: Path,
    warnings: list[dict],
    counters: dict,
    indent: str = "",
) -> dict | None:
    """Index a supported media file, or log/skip unsupported types."""
    suffix = entry.suffix.lower()
    if suffix not in SUPPORTED_EXTENSIONS:
        if suffix:
            _log_skipped_extension(entry)
        return None

    item = make_item(entry, warnings)
    if item is not None:
        counters["items"] += 1
        print(f"{indent}[file] {entry.name}")
    return item


# ------------------------------------------------------------------
# Path normalization
# ------------------------------------------------------------------

def normalize_path(path: str | Path) -> str:
    """Case-insensitive, separator-normalized path for stable comparisons."""
    return os.path.normcase(os.path.normpath(str(path)))


def _alternate_root_path(path_str: str, from_root: str, to_root: str) -> str:
    """Swap a path prefix between equivalent roots (e.g. Y: drive ↔ UNC)."""
    norm_path = normalize_path(path_str)
    norm_from = normalize_path(from_root)
    norm_to = normalize_path(to_root)
    if norm_path == norm_from:
        return norm_to
    prefix = norm_from + os.sep
    if norm_path.startswith(prefix):
        rel = norm_path[len(prefix):]
        return normalize_path(os.path.join(norm_to, rel))
    return norm_path


def resolve_library_path(path_str: str, config: dict | None = None) -> Path | None:
    """
    Resolve a library folder for rescan — same accessibility rules as full scan,
    including UNC ↔ drive-letter fallbacks from config media roots.
    """
    resolved = resolve_media_path(path_str)
    if resolved is not None:
        return resolved

    if not config:
        return None

    for root_cfg in config.get("mediaRoots", []):
        local = root_cfg.get("path")
        unc = root_cfg.get("uncPath")
        if not local or not unc:
            continue
        for alt in (
            _alternate_root_path(path_str, local, unc),
            _alternate_root_path(path_str, unc, local),
        ):
            if alt != normalize_path(path_str):
                resolved = resolve_media_path(alt)
                if resolved is not None:
                    return resolved

    return None


def _recalculate_item_count(node: dict) -> int:
    """Refresh item_count on a folder node and return the total."""
    count = len(node.get("items", []))
    for sub in node.get("subfolders", []):
        count += _recalculate_item_count(sub)
    node["item_count"] = count
    return count


def _replace_folder_in_tree(
    folders: list[dict],
    target_norm: str,
    new_node: dict,
) -> bool:
    """Replace a folder node anywhere in the catalogue tree."""
    for i, folder in enumerate(folders):
        if normalize_path(folder["path"]) == target_norm:
            folders[i] = new_node
            return True
        subfolders = folder.get("subfolders", [])
        if _replace_folder_in_tree(subfolders, target_norm, new_node):
            _recalculate_item_count(folder)
            return True
    return False


def _sum_item_counts(folders: list[dict]) -> int:
    return sum(f.get("item_count", 0) for f in folders)


def _walk_folder_nodes(folders: list[dict]):
    """Yield every folder node in the catalogue tree."""
    for folder in folders:
        yield folder
        for sub in folder.get("subfolders", []):
            yield from _walk_folder_nodes([sub])


def _build_added_at_lookup(folders: list[dict]) -> dict[str, str]:
    """Map item id → existing added_at from a catalogue tree."""
    lookup: dict[str, str] = {}
    for folder in _walk_folder_nodes(folders):
        for item in folder.get("items", []):
            item_id = item.get("id")
            added_at = item.get("added_at")
            if item_id and added_at:
                lookup[item_id] = added_at
    return lookup


def _apply_added_at_to_folders(
    folders: list[dict],
    lookup: dict[str, str],
    default_iso: str,
) -> None:
    """Stamp added_at on every item — preserve first-seen timestamps when known."""
    for folder in _walk_folder_nodes(folders):
        for item in folder.get("items", []):
            item_id = item.get("id")
            if not item_id:
                continue
            item["added_at"] = lookup.get(item_id, default_iso)


def _load_added_at_lookup(output_path: Path) -> dict[str, str]:
    """Read added_at values from an existing catalog.json if present."""
    if not output_path.is_file():
        return {}
    try:
        with open(output_path, encoding="utf-8") as f:
            catalog = json.load(f)
        return _build_added_at_lookup(catalog.get("folders", []))
    except Exception:
        return {}


# Filesystem errors that produce a warning and continue rather than abort.
_FS_ERRORS = (FileNotFoundError, PermissionError, OSError)

# ---------------------------------------------------------------------------
# Structured progress output
#
# Flutter reads stdout line by line.  Lines that start with "PROGRESS: "
# carry a JSON payload consumed by ScannerService.  All other lines are
# human-readable diagnostics that are captured but not parsed.
#
# Format:
#   PROGRESS: {"type":"folder","library":"Videos","folder":"Action","folders":12,"items":345,"warnings":0,"elapsed_seconds":5}
#   PROGRESS: {"type":"complete","library":"","folder":"","folders":734,"items":4681,"warnings":1,"elapsed_seconds":259}
# ---------------------------------------------------------------------------

_scan_started: datetime | None = None  # set by main() / _library_rescan()

# ---------------------------------------------------------------------------
# Progress throttle
#
# Emitting a PROGRESS line for every folder (734 in a typical scan) floods
# stdout and can overwhelm the Flutter debug pipe on Windows.
# We emit at most once per _PROGRESS_MIN_INTERVAL_S seconds OR every
# _PROGRESS_FOLDER_BATCH folders — whichever threshold is hit first.
# The final "complete" message is always emitted unthrottled.
# ---------------------------------------------------------------------------
_PROGRESS_MIN_INTERVAL_S: float = 0.25   # ≤ 4 messages per second
_PROGRESS_FOLDER_BATCH: int = 25          # flush after every 25 folders

_last_progress_time: float = 0.0
_folders_since_last_progress: int = 0


def _emit_progress(
    counters: dict,
    warnings: list,
    library: str = "",
    folder: str = "",
    ptype: str = "folder",
) -> None:
    """
    Print a structured PROGRESS line to stdout if the throttle window allows.
    "complete" messages are always emitted regardless of throttle state.
    """
    global _last_progress_time, _folders_since_last_progress

    is_complete = ptype == "complete"

    if not is_complete:
        _folders_since_last_progress += 1
        now = time.monotonic()
        time_elapsed = now - _last_progress_time
        if time_elapsed < _PROGRESS_MIN_INTERVAL_S and \
                _folders_since_last_progress < _PROGRESS_FOLDER_BATCH:
            return  # throttled — skip this emission
        _last_progress_time = now
        _folders_since_last_progress = 0

    elapsed_s = 0
    if _scan_started:
        elapsed_s = int((datetime.now(timezone.utc) - _scan_started).total_seconds())

    msg = json.dumps({
        "type": ptype,
        "library": library,
        "folder": folder,
        "folders": counters["folders"],
        "items": counters["items"],
        "warnings": len(warnings),
        "elapsed_seconds": elapsed_s,
    }, ensure_ascii=False)
    print(f"PROGRESS: {msg}", flush=True)


# ---------------------------------------------------------------------------
# Warning helpers
# ---------------------------------------------------------------------------

def _classify_exc(exc: Exception) -> tuple[str, str]:
    """
    Return (severity, reason) for a scan exception.

    severity — "info"    : informational; the path changed, not a fault.
               "warning" : something needs attention but the scan continues.

    reason   — "removed"    : path disappeared mid-scan (FileNotFoundError).
               "permission" : explicit access denial (PermissionError).
               "access"     : other OS / SMB-level access failure (OSError).
               "error"      : unexpected non-filesystem exception.
    """
    if isinstance(exc, FileNotFoundError):
        return "info", "removed"
    if isinstance(exc, PermissionError):
        return "warning", "permission"
    if isinstance(exc, OSError):
        return "warning", "access"
    return "warning", "error"


def _warn(warnings: list[dict], path: str, exc: Exception) -> None:
    """Append a classified warning entry and print a console line."""
    severity, reason = _classify_exc(exc)
    entry = {
        "path": path,
        "error": type(exc).__name__,
        "detail": str(exc),
        "severity": severity,
        "reason": reason,
    }
    warnings.append(entry)
    label = "INFO" if severity == "info" else "WARN"
    print(f"  [{label}] {type(exc).__name__} ({reason}) — {path}")


# ---------------------------------------------------------------------------
# Path resolution
# ---------------------------------------------------------------------------

def resolve_media_path(path_str: str, unc_fallback: str | None = None) -> Path | None:
    """
    Resolve a media root to an accessible directory.
    Tries path_str first, then unc_fallback.
    Both drive-letter and UNC paths are handled natively by pathlib on Windows.
    """
    candidates = [path_str]
    if unc_fallback:
        candidates.append(unc_fallback)

    for candidate in candidates:
        try:
            p = Path(candidate)
            if p.is_dir():
                print(f"  Resolved: {candidate}")
                return p
        except _FS_ERRORS:
            pass
        print(f"  Not accessible: {candidate}")

    return None


# ---------------------------------------------------------------------------
# Item helpers
# ---------------------------------------------------------------------------

def path_id(path: str) -> str:
    """Stable, collision-resistant ID derived from path string."""
    return hashlib.md5(path.encode()).hexdigest()


def get_duration_seconds(file_path: str) -> int | None:
    """Call ffprobe for duration. Returns None if ffprobe is absent or times out."""
    try:
        result = subprocess.run(
            [
                "ffprobe", "-v", "error",
                "-show_entries", "format=duration",
                "-of", "default=noprint_wrappers=1:nokey=1",
                file_path,
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )
        raw = result.stdout.strip()
        return int(float(raw)) if raw else None
    except Exception:
        return None


def clean_title(stem: str) -> str:
    """Turn a filename stem into a human-readable title."""
    return stem.replace(".", " ").replace("_", " ").strip()


def make_item(file_path: Path, warnings: list[dict]) -> dict | None:
    """
    Build a media item dict.

    Returns None (and logs a warning) for any failure — the file may have been
    deleted between iterdir() and this call, or the SMB share may have gone
    away mid-scan.  Both _FS_ERRORS and unexpected exceptions are caught so
    a single bad file never aborts the enclosing scan_folder call.

    The status field supports the planned item-status model:
    available / missing / restricted / …
    """
    str_path = str(file_path)
    suffix = file_path.suffix.lower()
    try:
        size = file_path.stat().st_size
        duration = (
            None
            if suffix in _IMAGE_EXTENSIONS
            else get_duration_seconds(str_path)
        )
        return {
            "id": path_id(str_path),
            "title": clean_title(file_path.stem),
            "year": None,
            "duration_seconds": duration,
            "file_path": str_path,
            "thumbnail_path": None,
            "size_bytes": size,
            "status": "available",
        }
    except _FS_ERRORS as exc:
        _warn(warnings, str_path, exc)
        return None
    except Exception as exc:
        _warn(warnings, str_path, exc)
        return None


# ---------------------------------------------------------------------------
# Recursive folder walker
# ---------------------------------------------------------------------------

def scan_folder(
    folder: Path,
    warnings: list[dict],
    counters: dict,
    depth: int = 0,
    library_name: str = "",
) -> dict | None:
    """
    Recursively scan *folder* and return a folder node, or None if the
    folder is inaccessible or contains no supported media at any depth.

    counters["folders"] and counters["items"] are incremented in place
    so main() has accurate totals for the scan statistics block.
    """
    items = []
    subfolders = []
    indent = "  " * depth

    try:
        entries = sorted(folder.iterdir(), key=lambda e: (e.is_file(), e.name.lower()))
    except _FS_ERRORS as exc:
        _warn(warnings, str(folder), exc)
        return None
    except Exception as exc:
        _warn(warnings, str(folder), exc)
        return None

    file_entries = [
        entry for entry in entries
        if not entry.name.startswith(".") and entry.is_file()
    ]

    for entry in entries:
        if entry.name.startswith("."):
            continue

        try:
            if entry.is_dir():
                child = scan_folder(entry, warnings, counters, depth + 1, library_name=library_name)
                if child is not None:
                    subfolders.append(child)

        except _FS_ERRORS as exc:
            _warn(warnings, str(entry), exc)
        except Exception as exc:
            _warn(warnings, str(entry), exc)

    items = _index_files_in_folder(
        file_entries,
        warnings,
        counters,
        indent=f"{indent}  ",
    )

    if not items and not subfolders:
        return None  # prune empty or fully-inaccessible folders

    item_count = len(items) + sum(f["item_count"] for f in subfolders)
    counters["folders"] += 1
    print(f"{indent}[folder] {folder.name}  ({item_count} items)")

    if library_name:
        _emit_progress(counters, warnings, library=library_name, folder=folder.name)

    return {
        "id": path_id(str(folder)),
        "name": folder.name,
        "path": str(folder),
        "item_count": item_count,
        "items": items,
        "subfolders": subfolders,
    }


def scan_root(
    root: Path,
    warnings: list[dict],
    counters: dict,
) -> tuple[list[dict], int]:
    """
    Scan a single media root. Returns (folders, total_items).
    Files directly in root are grouped under a node named after root itself.
    """
    folders = []
    root_level_items = []
    total_items = 0

    try:
        root_entries = sorted(root.iterdir(), key=lambda e: e.name.lower())
    except _FS_ERRORS as exc:
        _warn(warnings, str(root), exc)
        return [], 0
    except Exception as exc:
        _warn(warnings, str(root), exc)
        return [], 0

    root_files = [
        entry for entry in root_entries
        if not entry.name.startswith(".") and entry.is_file()
    ]

    for entry in root_entries:
        if entry.name.startswith("."):
            continue

        try:
            if entry.is_dir():
                _emit_progress(counters, warnings, library=entry.name, folder="")
                node = scan_folder(entry, warnings, counters, library_name=entry.name)
                if node:
                    folders.append(node)
                    total_items += node["item_count"]

        except _FS_ERRORS as exc:
            _warn(warnings, str(entry), exc)
        except Exception as exc:
            _warn(warnings, str(entry), exc)

    root_level_items = _index_files_in_folder(
        root_files,
        warnings,
        counters,
        indent="  ",
    )

    if root_level_items:
        root_node = {
            "id": path_id(str(root)),
            "name": root.name,
            "path": str(root),
            "item_count": len(root_level_items),
            "items": root_level_items,
            "subfolders": [],
        }
        folders.insert(0, root_node)
        total_items += len(root_level_items)
        counters["folders"] += 1

    return folders, total_items


# ---------------------------------------------------------------------------
# Atomic write
# ---------------------------------------------------------------------------

def write_atomic(data: dict, output_path: Path) -> None:
    """
    Write a JSON file atomically via a temp file.
    A failed or interrupted write never corrupts the existing file.
    """
    tmp_path = output_path.with_suffix(".tmp")
    try:
        with open(tmp_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        tmp_path.replace(output_path)  # atomic on POSIX; best-effort on Windows
    except Exception as exc:
        tmp_path.unlink(missing_ok=True)
        raise SystemExit(f"Error writing {output_path.name}: {exc}") from exc


# ---------------------------------------------------------------------------
# Scan history
# ---------------------------------------------------------------------------

MAX_HISTORY_ENTRIES = 50


def append_scan_history(history_path: Path, entry: dict, max_entries: int = MAX_HISTORY_ENTRIES) -> None:
    """
    Prepend *entry* to the scan history file at *history_path*.
    Creates the file if it does not exist.
    Caps the list at *max_entries* so the file never grows unboundedly.
    Uses the same atomic write as the catalogue — a failed history write
    never corrupts an existing history file.

    The history file is separate from catalog.json so that scan records
    survive each catalogue replacement.
    """
    if history_path.exists():
        try:
            with open(history_path, encoding="utf-8") as f:
                history = json.load(f)
        except Exception:
            # Corrupted history file — start fresh rather than abort the scan.
            print(f"  [WARN] Could not read history file — starting fresh: {history_path}")
            history = {"entries": []}
    else:
        history = {"entries": []}

    entries: list[dict] = history.get("entries", [])
    entries.insert(0, entry)          # newest first
    entries = entries[:max_entries]   # cap

    write_atomic(
        {"max_entries": max_entries, "entries": entries},
        history_path,
    )


# ---------------------------------------------------------------------------
# Library rescan (partial merge)
# ---------------------------------------------------------------------------

def _library_rescan(
    library_path_str: str,
    scan_started: datetime,
    output_path: Path,
    history_path: Path,
    max_entries: int,
    config: dict | None = None,
) -> None:
    """
    Rescan a single top-level library folder and merge the result into the
    existing catalog.json.  The rest of the catalogue is untouched.

    Steps
    -----
    1. Load the existing catalog.json  — fails hard if missing or corrupt so
       the caller (the app) sees a clear error rather than a silent full rewrite.
    2. Resolve and scan library_path via scan_folder().
    3. Locate the matching folder node by path.
    4. Replace it in-place (or append if the library is brand-new).
    5. Recalculate total_items.
    6. Assign a fresh catalogue ID so the app detects the change.
    7. Write atomically.  The existing catalog.json survives any failure.
    8. Append a history entry tagged mode=library.
    """
    global _scan_started
    _scan_started = scan_started

    warnings: list[dict] = []
    counters: dict = {"folders": 0, "items": 0}

    # ------------------------------------------------------------------
    # 1. Load existing catalog
    # ------------------------------------------------------------------
    if not output_path.is_file():
        raise SystemExit(
            f"No existing catalog found at {output_path}.\n"
            "Run a full scan first before using --library-path."
        )
    try:
        with open(output_path, encoding="utf-8") as f:
            catalog = json.load(f)
    except Exception as exc:
        raise SystemExit(f"Could not read existing catalog: {exc}") from exc

    # ------------------------------------------------------------------
    # 2. Resolve and scan the requested library path
    # ------------------------------------------------------------------
    library_path = resolve_library_path(library_path_str, config)
    if library_path is None:
        raise SystemExit(f"Library path is not accessible: {library_path_str}")

    print(f"\n[library rescan] {library_path}\n")
    _emit_progress(counters, warnings, library=library_path.name, folder="")
    new_node = scan_folder(library_path, warnings, counters, library_name=library_path.name)

    if new_node is None:
        raise SystemExit(
            f"Library scan produced no media for: {library_path_str}\n"
            "The folder may be empty or fully inaccessible."
        )

    # ------------------------------------------------------------------
    # 3 & 4. Merge — replace matching node anywhere in the tree, or append
    # ------------------------------------------------------------------
    existing_folders: list[dict] = catalog.get("folders", [])
    added_at_default = datetime.now(timezone.utc).isoformat()
    added_at_lookup = _build_added_at_lookup(existing_folders)
    _apply_added_at_to_folders([new_node], added_at_lookup, added_at_default)

    target_norm = normalize_path(library_path)
    merged = _replace_folder_in_tree(existing_folders, target_norm, new_node)

    if not merged:
        existing_folders.append(new_node)
        print(f"  [INFO] New library not previously indexed — added: {library_path.name}")

    # ------------------------------------------------------------------
    # 5. Recalculate total_items across all branches
    # ------------------------------------------------------------------
    total_items = _sum_item_counts(existing_folders)

    # ------------------------------------------------------------------
    # 6. Update catalogue identity and scan block
    # ------------------------------------------------------------------
    scan_completed = datetime.now(timezone.utc)
    duration_seconds = int((scan_completed - scan_started).total_seconds())
    catalogue_id = make_catalogue_id(scan_started)

    # Preserve existing catalogue block structure; refresh identity and metadata.
    if "catalogue" in catalog:
        catalog["catalogue"]["id"] = catalogue_id
        catalog["catalogue"]["scanner_version"] = SCANNER_VERSION
        catalog["catalogue"]["catalogue_version"] = CATALOGUE_VERSION
        catalog["catalogue"]["supported_extensions"] = SUPPORTED_EXTENSIONS_SORTED
    else:
        catalog["catalogue"] = make_catalogue_block(catalogue_id)

    catalog["folders"] = existing_folders
    catalog["total_items"] = total_items
    catalog["scan"] = {
        "started": scan_started.isoformat(),
        "completed": scan_completed.isoformat(),
        "duration_seconds": duration_seconds,
        "mode": "library",
        "library_path": str(library_path),
        "sources": 1,
        "folders": counters["folders"],
        "items": counters["items"],
        "warnings": len(warnings),
    }
    catalog["scan_warnings"] = warnings

    # ------------------------------------------------------------------
    # 7. Atomic write — existing catalog.json survives any failure here
    # ------------------------------------------------------------------
    write_atomic(catalog, output_path)
    _emit_progress(counters, warnings, library=str(library_path), ptype="complete")

    # ------------------------------------------------------------------
    # 8. Scan history
    # ------------------------------------------------------------------
    history_entry = {
        "catalogue_id": catalogue_id,
        "completed": scan_completed.isoformat(),
        "success": True,
        "mode": "library",
        "library_path": str(library_path),
        "sources": 1,
        "folders": counters["folders"],
        "items": counters["items"],
        "warnings": len(warnings),
        "duration_seconds": duration_seconds,
    }
    append_scan_history(history_path, history_entry, max_entries)

    print(f"\n{'─' * 48}")
    print(f"  Mode      library  ({library_path.name})")
    print(f"  ID        {catalogue_id}")
    print(f"  Folders   {counters['folders']:,}")
    print(f"  Items     {counters['items']:,}")
    print(f"  Warnings  {len(warnings)}")
    print(f"  Duration  {duration_seconds}s")
    print(f"  Output    {output_path}")
    print(f"{'─' * 48}\n")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description="TTSPlayer media indexer")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--config", metavar="PATH", help="Path to ttsplayer.config.json")
    mode.add_argument("--root", metavar="PATH", help="Single media root (use with --output)")
    parser.add_argument("--output", metavar="PATH", help="Output path for catalog.json (--root mode)")
    parser.add_argument(
        "--library-path", metavar="PATH",
        help="Rescan one library folder and merge it into the existing catalog.json. Requires --config.",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Log skipped unsupported file extensions to stderr (not scan warnings).",
    )
    args = parser.parse_args()

    global _debug
    _debug = args.debug

    if args.library_path and not args.config:
        raise SystemExit("--library-path requires --config")

    scan_started = datetime.now(timezone.utc)
    warnings: list[dict] = []
    counters: dict = {"folders": 0, "items": 0}  # incremented by scan helpers

    global _scan_started
    _scan_started = scan_started

    # Defaults — overridden by config block; used as-is in direct (--root) mode.
    history_path_cfg: Path | None = None
    max_entries_cfg: int = MAX_HISTORY_ENTRIES

    # -------------------------------------------------------------------------
    # Config-driven mode
    # -------------------------------------------------------------------------
    if args.config:
        config_path = Path(args.config)
        if not config_path.is_file():
            raise SystemExit(f"Config not found: {config_path}")

        with open(config_path, encoding="utf-8") as f:
            config = json.load(f)

        output_path = Path(config["cataloguePath"])
        history_path_cfg = Path(
            config.get("historyPath", str(output_path.parent / "scan.history.json"))
        )
        max_entries_cfg = int(config.get("maxHistoryEntries", MAX_HISTORY_ENTRIES))

        # -----------------------------------------------------------------------
        # Library rescan mode — scan one folder, merge into existing catalog.json
        # -----------------------------------------------------------------------
        if args.library_path:
            _library_rescan(
                args.library_path,
                scan_started,
                output_path,
                history_path_cfg,
                max_entries_cfg,
                config=config,
            )
            return

        media_roots_cfg = config.get("mediaRoots", [])

        all_folders: list[dict] = []
        total_items = 0
        sources_meta: list[dict] = []
        sources_scanned = 0

        for root_cfg in media_roots_cfg:
            if not root_cfg.get("enabled", True):
                print(f"[SKIP — disabled] {root_cfg.get('name', root_cfg.get('path'))}")
                continue

            name = root_cfg["name"]
            path_str = root_cfg["path"]
            unc_path = root_cfg.get("uncPath")
            root_type = root_cfg.get("type", "local")

            print(f"\n[source] {name}  ({root_type})")
            root = resolve_media_path(path_str, unc_path)

            if root is None:
                print(f"  [WARN] '{name}' is not accessible — skipping.")
                warnings.append({
                    "path": path_str,
                    "error": "SourceNotAccessible",
                    "detail": f"Neither '{path_str}' nor the UNC fallback resolved to an accessible directory.",
                })
                sources_meta.append({
                    "name": name, "root_path": path_str,
                    "type": root_type, "accessible": False,
                })
                continue

            print(f"  Scanning: {root}\n")
            folders, count = scan_root(root, warnings, counters)
            all_folders.extend(folders)
            total_items += count
            sources_scanned += 1
            sources_meta.append({
                "name": name, "root_path": str(root),
                "type": root_type, "accessible": True,
            })

    # -------------------------------------------------------------------------
    # Direct mode
    # -------------------------------------------------------------------------
    else:
        if not args.output:
            raise SystemExit("--output is required when using --root")

        root = resolve_media_path(args.root)
        if root is None:
            raise SystemExit(f"Error: '{args.root}' is not an accessible directory.")

        print(f"Scanning: {root}\n")
        all_folders, total_items = scan_root(root, warnings, counters)
        output_path = Path(args.output)
        sources_meta = [{
            "name": root.name, "root_path": str(root),
            "type": "local", "accessible": True,
        }]
        sources_scanned = 1

    # -------------------------------------------------------------------------
    # Assemble and write catalogue
    # -------------------------------------------------------------------------
    scan_completed = datetime.now(timezone.utc)
    duration_seconds = int((scan_completed - scan_started).total_seconds())

    output_path.parent.mkdir(parents=True, exist_ok=True)

    added_at_lookup = _load_added_at_lookup(output_path)
    _apply_added_at_to_folders(all_folders, added_at_lookup, scan_completed.isoformat())

    catalogue_id = make_catalogue_id(scan_started)

    catalog = {
        # -- Identity ----------------------------------------------------------
        # Every catalogue has a unique ID so the app can detect whether the
        # file on disk has changed since it was last loaded.
        "catalogue": make_catalogue_block(catalogue_id),
        # -- Scan run metadata -------------------------------------------------
        "scan": {
            "started": scan_started.isoformat(),
            "completed": scan_completed.isoformat(),
            "duration_seconds": duration_seconds,
            "sources": sources_scanned,
            "folders": counters["folders"],
            "items": counters["items"],
            "warnings": len(warnings),
        },
        # -- Data --------------------------------------------------------------
        "sources": sources_meta,
        "total_items": total_items,
        "folders": all_folders,
        "scan_warnings": warnings,
    }

    write_atomic(catalog, output_path)
    _emit_progress(counters, warnings, ptype="complete")

    # -------------------------------------------------------------------------
    # Append to scan history (separate file — survives catalogue replacement)
    # -------------------------------------------------------------------------
    history_path = history_path_cfg or (output_path.parent / "scan.history.json")
    max_entries = max_entries_cfg

    history_entry = {
        "catalogue_id": catalogue_id,
        "completed": scan_completed.isoformat(),
        "success": True,
        "sources": sources_scanned,
        "folders": counters["folders"],
        "items": counters["items"],
        "warnings": len(warnings),
        "duration_seconds": duration_seconds,
    }
    append_scan_history(history_path, history_entry, max_entries)

    print(f"\n{'─' * 48}")
    print(f"  ID        {catalogue_id}")
    print(f"  Scanner   {SCANNER_VERSION}  (catalogue v{CATALOGUE_VERSION})")
    print(f"  Sources   {sources_scanned}")
    print(f"  Folders   {counters['folders']:,}")
    print(f"  Items     {counters['items']:,}")
    print(f"  Warnings  {len(warnings)}")
    print(f"  Duration  {duration_seconds}s")
    print(f"  Output    {output_path}")
    print(f"  History   {history_path}")
    print(f"{'─' * 48}\n")


if __name__ == "__main__":
    main()
