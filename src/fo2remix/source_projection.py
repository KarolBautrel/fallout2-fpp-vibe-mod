"""Build exact source-art composites for ISO-to-FPP texture projection."""

from __future__ import annotations

import hashlib
from collections.abc import Iterable
from dataclasses import dataclass
from pathlib import Path, PureWindowsPath
from typing import Any

HEX_GRID_WIDTH = 200


def _trunc_div(numerator: int, denominator: int) -> int:
    """Match C++ signed integer division (truncate toward zero)."""

    return int(numerator / denominator)


def tile_to_reference_screen(
    tile: int,
    *,
    tile_x: int = 100,
    tile_y: int = 100,
) -> tuple[int, int]:
    """Port ``fallout2-ce::tileToScreenXY`` without viewport scrolling."""

    column = HEX_GRID_WIDTH - 1 - tile % HEX_GRID_WIDTH
    row = tile // HEX_GRID_WIDTH
    column_delta = column - tile_x
    screen_x = 48 * _trunc_div(column_delta, 2)
    screen_y = 12 * _trunc_div(column_delta, -2)
    if column & 1:
        if column <= tile_x:
            screen_x -= 16
            screen_y += 12
        else:
            screen_x += 32
    row_delta = row - tile_y
    return screen_x + 16 * row_delta, screen_y + 12 * row_delta


@dataclass(frozen=True, slots=True)
class SourceRect:
    left: int
    top: int
    right: int
    bottom: int

    @property
    def width(self) -> int:
        return self.right - self.left + 1

    @property
    def height(self) -> int:
        return self.bottom - self.top + 1


def source_rect_for_record(record: dict[str, Any]) -> SourceRect:
    """Port the tiled-object branch of ``fallout2-ce::objectGetRect``."""

    art = record["art"]
    frame = art["frame"]
    rotation = int(record.get("rotation", 0)) % 6
    width = int(frame["width"])
    height = int(frame["height"])
    tile_screen_x, tile_screen_y = tile_to_reference_screen(int(record["hex_index"]))
    rotation_offsets_x = frame.get("rotation_offsets_x", [0] * 6)
    rotation_offsets_y = frame.get("rotation_offsets_y", [0] * 6)
    object_offset = record.get("screen_offset", [0, 0])
    anchor_x = tile_screen_x + 16 + int(rotation_offsets_x[rotation]) + int(object_offset[0])
    anchor_y = tile_screen_y + 8 + int(rotation_offsets_y[rotation]) + int(object_offset[1])
    left = anchor_x - width // 2
    top = anchor_y - height + 1
    return SourceRect(left, top, left + width - 1, anchor_y)


def select_art_family_records(
    scene: dict[str, Any],
    path_prefixes: Iterable[str],
    *,
    elevation: int | None = None,
) -> list[dict[str, Any]]:
    """Select visible records matching prefixes and optionally one elevation."""

    prefixes = tuple(prefix.replace("/", "\\").lower() for prefix in path_prefixes)
    selected: list[dict[str, Any]] = []
    for value in scene["objects"]["records"]:
        record = dict(value)
        if bool(record.get("flags", {}).get("hidden", False)):
            continue
        if elevation is not None and int(record.get("elevation", 0)) != elevation:
            continue
        path = str(record.get("art", {}).get("path", "")).replace("/", "\\").lower()
        if any(path.startswith(prefix) for prefix in prefixes):
            selected.append(record)
    return selected


def cached_frame_path(cache_root: Path, record: dict[str, Any]) -> Path:
    art = record["art"]
    source = PureWindowsPath(str(art["path"]))
    art_type = str(art.get("type", source.parent.name)).lower()
    rotation = int(record.get("rotation", 0)) if art_type == "critters" else 0
    frame = int(record.get("frame", 0))
    return cache_root / art_type / f"{source.stem.lower()}-r{rotation}-f{frame}.png"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()
