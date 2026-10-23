"""Minimal, evidence-backed pieces of the Fallout 2 MAP format."""

from __future__ import annotations

from dataclasses import dataclass
from struct import Struct
from typing import BinaryIO

MAP_VERSIONS = frozenset({19, 20})
MAP_HEADER_STRUCT = Struct(">i16s9iI44i")
MAP_HEADER_SIZE = MAP_HEADER_STRUCT.size
SQUARE_GRID_WIDTH = 100
SQUARE_GRID_HEIGHT = 100
SQUARE_GRID_SIZE = SQUARE_GRID_WIDTH * SQUARE_GRID_HEIGHT
ELEVATION_ABSENT_FLAGS = (2, 4, 8)
_INT32 = Struct(">i")
_TILE_LAYER = Struct(f">{SQUARE_GRID_SIZE}I")


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


@dataclass(frozen=True, slots=True)
class MapTile:
    floor_id: int
    roof_id: int
    roof_flags: int
    raw: int


@dataclass(frozen=True, slots=True)
class MapTileLayer:
    elevation: int
    tiles: tuple[MapTile, ...]


@dataclass(frozen=True, slots=True)
class MapCore:
    header: MapHeader
    global_variables: tuple[int, ...]
    local_variables: tuple[int, ...]
    tile_layers: tuple[MapTileLayer, ...]


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


def _read_int32_values(stream: BinaryIO, count: int, label: str) -> tuple[int, ...]:
    raw = stream.read(count * _INT32.size)
    if len(raw) != count * _INT32.size:
        raise EOFError(f"expected {count} {label}, got {len(raw) // _INT32.size}")
    if count == 0:
        return ()
    return Struct(f">{count}i").unpack(raw)


def read_map_core(stream: BinaryIO) -> MapCore:
    """Read the header, variables, and floor/roof tile layers of a MAP file."""
    header = read_map_header(stream)
    global_variables = _read_int32_values(
        stream, header.global_variables_count, "global variables"
    )
    local_variables = _read_int32_values(
        stream, header.local_variables_count, "local variables"
    )

    layers: list[MapTileLayer] = []
    for elevation, absent_flag in enumerate(ELEVATION_ABSENT_FLAGS):
        if header.flags & absent_flag:
            continue
        raw = stream.read(_TILE_LAYER.size)
        if len(raw) != _TILE_LAYER.size:
            raise EOFError(
                f"expected {_TILE_LAYER.size} bytes for elevation {elevation}, got {len(raw)}"
            )
        packed_tiles = _TILE_LAYER.unpack(raw)
        tiles = tuple(
            MapTile(
                floor_id=packed & 0xFFF,
                roof_id=(packed >> 16) & 0xFFF,
                roof_flags=(packed >> 28) & 0xF,
                raw=packed,
            )
            for packed in packed_tiles
        )
        layers.append(MapTileLayer(elevation=elevation, tiles=tiles))

    return MapCore(
        header=header,
        global_variables=global_variables,
        local_variables=local_variables,
        tile_layers=tuple(layers),
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

