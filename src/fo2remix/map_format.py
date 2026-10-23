"""Minimal, evidence-backed pieces of the Fallout 2 MAP format."""

from __future__ import annotations

from dataclasses import dataclass
from struct import Struct
from typing import BinaryIO

MAP_VERSIONS = frozenset({19, 20})
MAP_HEADER_STRUCT = Struct(">i16s9iI44i")
MAP_HEADER_SIZE = MAP_HEADER_STRUCT.size


@dataclass(frozen=True, slots=True)
class MapHeader:
    version: int
    name: str
    entering_tile: int
    entering_elevation: int
    entering_rotation: int
    local_variables_count: int
    script_index: int
    flags: int
    darkness: int
    global_variables_count: int
    map_index: int
    last_visit_time: int
    reserved: tuple[int, ...]


def read_map_header(stream: BinaryIO, *, validate_version: bool = True) -> MapHeader:
    """Read the fixed 236-byte big-endian Fallout 2 map header."""

    raw = stream.read(MAP_HEADER_SIZE)
    if len(raw) != MAP_HEADER_SIZE:
        raise EOFError(f"expected {MAP_HEADER_SIZE} header bytes, got {len(raw)}")

    values = MAP_HEADER_STRUCT.unpack(raw)
    version = values[0]
    if validate_version and version not in MAP_VERSIONS:
        raise ValueError(f"unsupported Fallout 2 map version: {version}")

    name = values[1].split(b"\0", 1)[0].decode("ascii", errors="strict")
    return MapHeader(
        version=version,
        name=name,
        entering_tile=values[2],
        entering_elevation=values[3],
        entering_rotation=values[4],
        local_variables_count=values[5],
        script_index=values[6],
        flags=values[7],
        darkness=values[8],
        global_variables_count=values[9],
        map_index=values[10],
        last_visit_time=values[11],
        reserved=tuple(values[12:]),
    )


def tile_index_to_grid(tile: int, *, width: int = 200, height: int = 200) -> tuple[int, int]:
    """Return the reversed-column grid coordinates used by fallout2-ce."""

    if tile < 0 or tile >= width * height:
        raise ValueError(f"tile {tile} is outside a {width}x{height} grid")
    return width - 1 - (tile % width), tile // width


def grid_to_tile_index(column: int, row: int, *, width: int = 200, height: int = 200) -> int:
    """Inverse of :func:`tile_index_to_grid`."""

    if column < 0 or column >= width or row < 0 or row >= height:
        raise ValueError(f"grid position ({column}, {row}) is outside a {width}x{height} grid")
    return row * width + (width - 1 - column)

