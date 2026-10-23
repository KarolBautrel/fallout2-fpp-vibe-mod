"""Minimal, evidence-backed pieces of the Fallout 2 MAP format."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass
from struct import Struct
from typing import BinaryIO

from .proto_format import PrototypeSummary, pid_type

MAP_VERSIONS = frozenset({19, 20})
MAP_HEADER_STRUCT = Struct(">i16s9iI44i")
MAP_HEADER_SIZE = MAP_HEADER_STRUCT.size
SQUARE_GRID_WIDTH = 100
SQUARE_GRID_HEIGHT = 100
SQUARE_GRID_SIZE = SQUARE_GRID_WIDTH * SQUARE_GRID_HEIGHT
ELEVATION_ABSENT_FLAGS = (2, 4, 8)
_INT32 = Struct(">i")
_TILE_LAYER = Struct(f">{SQUARE_GRID_SIZE}I")
_OBJECT_BASE = Struct(">18i")

SCRIPT_TYPE_COUNT = 5
SCRIPT_LIST_EXTENT_SIZE = 16
OBJECT_TYPE_CRITTER = 1
OBJECT_TYPE_SCENERY = 2
OBJECT_TYPE_WALL = 3
OBJECT_HIDDEN = 0x01
OBJECT_NO_BLOCK = 0x10
OBJECT_MULTIHEX = 0x800
OBJECT_OPEN_DOOR = 0xA0000010
DOOR_OPEN = 0x01
DOOR_LOCKED = 0x02000000
DOOR_JAMMED = 0x04000000
FIRST_EXIT_GRID_PID = 0x05000010
LAST_EXIT_GRID_PID = 0x05000017
_MAX_COLLECTION_LENGTH = 1_000_000


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


@dataclass(frozen=True, slots=True)
class MapInventoryItem:
    quantity: int
    item: MapObject


@dataclass(frozen=True, slots=True)
class MapObject:
    object_id: int
    tile: int
    x: int
    y: int
    screen_x: int
    screen_y: int
    frame: int
    rotation: int
    fid: int
    flags: int
    elevation: int
    stored_elevation: int
    pid: int
    cid: int
    light_distance: int
    light_intensity: int
    unknown_field_74: int
    sid: int
    script_index: int
    inventory_capacity: int
    data_flags: int | None
    type_data: tuple[int, ...]
    prototype: PrototypeSummary
    inventory: tuple[MapInventoryItem, ...]

    @property
    def fid_type(self) -> int:
        return (self.fid & 0x0F000000) >> 24

    @property
    def flags_u32(self) -> int:
        return self.flags & 0xFFFFFFFF

    @property
    def hidden(self) -> bool:
        return bool(self.flags & OBJECT_HIDDEN)

    @property
    def no_block(self) -> bool:
        return bool(self.flags & OBJECT_NO_BLOCK)

    @property
    def multihex(self) -> bool:
        return bool(self.flags & OBJECT_MULTIHEX)

    @property
    def blocks_movement(self) -> bool:
        return (
            not self.hidden
            and not self.no_block
            and self.fid_type in {OBJECT_TYPE_CRITTER, OBJECT_TYPE_SCENERY, OBJECT_TYPE_WALL}
        )

    @property
    def is_door(self) -> bool:
        return self.prototype.object_type == OBJECT_TYPE_SCENERY and self.prototype.subtype == 0

    @property
    def door_open_flags(self) -> int | None:
        return self.type_data[0] if self.is_door and self.type_data else None


@dataclass(frozen=True, slots=True)
class MapFile:
    core: MapCore
    script_counts: tuple[int, ...]
    declared_object_count: int
    objects: tuple[MapObject, ...]


PrototypeResolver = Callable[[int], PrototypeSummary]


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
    if count < 0 or count > _MAX_COLLECTION_LENGTH:
        raise ValueError(f"invalid {label} count: {count}")
    raw = stream.read(count * _INT32.size)
    if len(raw) != count * _INT32.size:
        raise EOFError(f"expected {count} {label}, got {len(raw) // _INT32.size}")
    if count == 0:
        return ()
    return Struct(f">{count}i").unpack(raw)


def _read_int32(stream: BinaryIO, label: str) -> int:
    raw = stream.read(_INT32.size)
    if len(raw) != _INT32.size:
        raise EOFError(f"expected 4 bytes for {label}, got {len(raw)}")
    return _INT32.unpack(raw)[0]


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


def read_map(stream: BinaryIO, prototype_resolver: PrototypeResolver) -> MapFile:
    """Read MAP tiles, skip serialized scripts, and decode all object records."""

    core = read_map_core(stream)
    script_counts = _skip_scripts(stream)
    declared_object_count = _read_int32(stream, "total object count")
    if declared_object_count < 0 or declared_object_count > _MAX_COLLECTION_LENGTH:
        raise ValueError(f"invalid total object count: {declared_object_count}")

    objects: list[MapObject] = []
    for elevation in range(3):
        count = _read_int32(stream, f"elevation {elevation} object count")
        if count < 0 or count > declared_object_count:
            raise ValueError(f"invalid elevation {elevation} object count: {count}")
        for _index in range(count):
            objects.append(
                _read_object(
                    stream,
                    map_version=core.header.version,
                    elevation=elevation,
                    prototype_resolver=prototype_resolver,
                )
            )

    if len(objects) != declared_object_count:
        raise ValueError(
            f"declared {declared_object_count} map objects, decoded {len(objects)}"
        )

    return MapFile(
        core=core,
        script_counts=script_counts,
        declared_object_count=declared_object_count,
        objects=tuple(objects),
    )


def _skip_scripts(stream: BinaryIO) -> tuple[int, ...]:
    counts: list[int] = []
    for script_type in range(SCRIPT_TYPE_COUNT):
        count = _read_int32(stream, f"script type {script_type} count")
        if count < 0 or count > _MAX_COLLECTION_LENGTH:
            raise ValueError(f"invalid script type {script_type} count: {count}")
        counts.append(count)
        extent_count = (count + SCRIPT_LIST_EXTENT_SIZE - 1) // SCRIPT_LIST_EXTENT_SIZE
        for extent_index in range(extent_count):
            for script_index in range(SCRIPT_LIST_EXTENT_SIZE):
                sid = _read_int32(
                    stream,
                    f"script type {script_type} extent {extent_index} record {script_index} sid",
                )
                _read_int32(stream, "script next field")
                serialized_type = sid >> 24
                if serialized_type == 1:
                    _read_int32_values(stream, 2, "spatial script fields")
                elif serialized_type == 2:
                    _read_int32(stream, "timed script field")
                _read_int32_values(stream, 14, "script common fields")
            _read_int32(stream, "script extent length")
            _read_int32(stream, "script extent next pointer")
    return tuple(counts)


def _read_object(
    stream: BinaryIO,
    *,
    map_version: int,
    elevation: int,
    prototype_resolver: PrototypeResolver,
) -> MapObject:
    raw_base = stream.read(_OBJECT_BASE.size)
    if len(raw_base) != _OBJECT_BASE.size:
        raise EOFError(
            f"expected {_OBJECT_BASE.size} bytes for object base, got {len(raw_base)}"
        )
    values = _OBJECT_BASE.unpack(raw_base)
    pid = values[11]
    prototype = prototype_resolver(pid)
    serialized_pid_type = pid_type(pid)
    if prototype.object_type != serialized_pid_type:
        raise ValueError(
            f"object pid {pid:#x} type {serialized_pid_type} disagrees with "
            f"prototype type {prototype.object_type}"
        )

    inventory_length = _read_int32(stream, "inventory length")
    inventory_capacity = _read_int32(stream, "inventory capacity")
    _read_int32(stream, "serialized inventory pointer")
    if inventory_length < 0 or inventory_length > _MAX_COLLECTION_LENGTH:
        raise ValueError(f"invalid inventory length: {inventory_length}")
    if inventory_capacity < inventory_length:
        raise ValueError(
            f"inventory capacity {inventory_capacity} is below length {inventory_length}"
        )

    data_flags: int | None = None
    type_data: tuple[int, ...]
    if serialized_pid_type == OBJECT_TYPE_CRITTER:
        type_data = _read_int32_values(stream, 11, "critter object data")
    else:
        data_flags = _read_int32(stream, "object data flags")
        extra_count = _object_type_data_count(
            pid=pid,
            object_type=serialized_pid_type,
            subtype=prototype.subtype,
            map_version=map_version,
        )
        type_data = _read_int32_values(stream, extra_count, "typed object data")

    inventory: list[MapInventoryItem] = []
    for _index in range(inventory_length):
        quantity = _read_int32(stream, "inventory item quantity")
        item = _read_object(
            stream,
            map_version=map_version,
            elevation=elevation,
            prototype_resolver=prototype_resolver,
        )
        inventory.append(MapInventoryItem(quantity=quantity, item=item))

    return MapObject(
        object_id=values[0],
        tile=values[1],
        x=values[2],
        y=values[3],
        screen_x=values[4],
        screen_y=values[5],
        frame=values[6],
        rotation=values[7],
        fid=values[8],
        flags=values[9],
        elevation=elevation,
        stored_elevation=values[10],
        pid=pid,
        cid=values[12],
        light_distance=values[13],
        light_intensity=values[14],
        unknown_field_74=values[15],
        sid=values[16],
        script_index=values[17],
        inventory_capacity=inventory_capacity,
        data_flags=data_flags,
        type_data=type_data,
        prototype=prototype,
        inventory=tuple(inventory),
    )


def _object_type_data_count(
    *,
    pid: int,
    object_type: int,
    subtype: int | None,
    map_version: int,
) -> int:
    if object_type == 0:
        if subtype == 3:
            return 2
        if subtype in {4, 5, 6}:
            return 1
        return 0
    if object_type == OBJECT_TYPE_SCENERY:
        if subtype == 0:
            return 1
        if subtype in {1, 2}:
            return 2
        if subtype in {3, 4}:
            return 1 if map_version == 19 else 2
        return 0
    if object_type == 5 and FIRST_EXIT_GRID_PID <= pid <= LAST_EXIT_GRID_PID:
        return 4
    return 0


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


def tile_in_direction(tile: int, rotation: int) -> int:
    """Return one adjacent tile using fallout2-ce's parity-specific offsets."""

    if rotation < 0 or rotation >= 6:
        raise ValueError(f"rotation must be in [0, 5], got {rotation}")
    column, row = tile_index_to_grid(tile)
    parity = (tile % 200) & 1
    offsets = (
        (-1, 199, 200, 201, 1, -200),
        (-201, -1, 200, 1, -199, -200),
    )
    candidate = tile + offsets[parity][rotation]
    if candidate < 0 or candidate >= 40_000:
        return tile
    candidate_column, candidate_row = tile_index_to_grid(candidate)
    if abs(candidate_column - column) > 1 or abs(candidate_row - row) > 1:
        return tile
    return candidate


def hex_index_to_world(tile: int, elevation: int = 0) -> tuple[float, float, float]:
    """Project a Fallout hex to the Godot debug renderer's X/Y/Z space."""

    column, row = tile_index_to_grid(tile)
    parity = column & 1
    source_u = 0.75 * column + 0.25 * parity + 0.5 * row
    source_v = -0.5 * column + 0.5 * parity + row
    center_u = 123.75
    center_v = 49.5
    return (
        source_u - center_u,
        float(elevation) * 3.0,
        (source_v - center_v) * 0.8660254037844386,
    )

