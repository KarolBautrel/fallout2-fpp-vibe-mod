from io import BytesIO
from struct import pack

import pytest

from fo2remix.map_format import (
    MAP_HEADER_SIZE,
    MAP_HEADER_STRUCT,
    OBJECT_HIDDEN,
    OBJECT_MULTIHEX,
    OBJECT_OPEN_DOOR,
    SQUARE_GRID_SIZE,
    grid_to_tile_index,
    hex_index_to_world,
    read_map,
    read_map_header,
    tile_index_to_grid,
)
from fo2remix.proto_format import PrototypeSummary


def make_header(*, version: int = 20) -> bytes:
    return MAP_HEADER_STRUCT.pack(
        version,
        b"ARROYO\0".ljust(16, b"\0"),
        20_123,
        1,
        4,
        12,
        7,
        0,
        50,
        8,
        3,
        0xFEDCBA98,
        *range(44),
    )


def test_map_header_matches_source_layout() -> None:
    header = read_map_header(BytesIO(make_header()))

    assert MAP_HEADER_SIZE == 236
    assert header.version == 20
    assert header.name == "ARROYO"
    assert header.entering_tile == 20_123
    assert header.entering_elevation == 1
    assert header.entering_rotation == 4
    assert header.last_visit_time == 0xFEDCBA98
    assert header.reserved == tuple(range(44))


def test_map_header_rejects_short_input() -> None:
    with pytest.raises(EOFError, match="expected 236"):
        read_map_header(BytesIO(make_header()[:-1]))


def test_map_header_rejects_unknown_version() -> None:
    with pytest.raises(ValueError, match="unsupported"):
        read_map_header(BytesIO(make_header(version=21)))


@pytest.mark.parametrize("tile", [0, 1, 199, 200, 20_123, 39_999])
def test_tile_grid_conversion_round_trips(tile: int) -> None:
    column, row = tile_index_to_grid(tile)
    assert grid_to_tile_index(column, row) == tile


@pytest.mark.parametrize("tile", [-1, 40_000])
def test_tile_grid_conversion_checks_bounds(tile: int) -> None:
    with pytest.raises(ValueError):
        tile_index_to_grid(tile)


def _signed_int32(value: int) -> int:
    return value if value < 0x80000000 else value - 0x100000000


def _map_object(
    *,
    object_id: int,
    tile: int,
    fid: int,
    flags: int,
    pid: int,
    type_data: tuple[int, ...] = (),
) -> bytes:
    base = pack(
        ">18i",
        object_id,
        tile,
        0,
        0,
        0,
        0,
        0,
        0,
        fid,
        _signed_int32(flags),
        0,
        pid,
        -1,
        0,
        0,
        0,
        -1,
        -1,
    )
    return base + pack(">4i", 0, 0, 0, 0) + pack(f">{len(type_data)}i", *type_data)


def _prototype(pid: int, *, subtype: int | None = None) -> PrototypeSummary:
    object_type = pid >> 24
    names = {2: "scenery", 3: "wall"}
    subtype_name = "door" if subtype == 0 else None
    return PrototypeSummary(
        pid=pid,
        object_type=object_type,
        object_type_name=names[object_type],
        fid=object_type << 24,
        flags=0,
        extended_flags=0,
        subtype=subtype,
        subtype_name=subtype_name,
        path=rf"proto\{names[object_type]}\{pid & 0xFFFFFF:08d}.pro",
    )


def test_reads_two_walls_and_two_doors_from_map_object_stream() -> None:
    wall_pid_1 = 0x03000001
    wall_pid_2 = 0x03000002
    door_pid_1 = 0x02000001
    door_pid_2 = 0x02000002
    prototypes = {
        wall_pid_1: _prototype(wall_pid_1),
        wall_pid_2: _prototype(wall_pid_2),
        door_pid_1: _prototype(door_pid_1, subtype=0),
        door_pid_2: _prototype(door_pid_2, subtype=0),
    }
    header = MAP_HEADER_STRUCT.pack(
        20,
        b"OBJECTS.MAP\0\0\0\0\0",
        18_492,
        0,
        0,
        0,
        -1,
        12,
        1,
        0,
        0,
        0,
        *([0] * 44),
    )
    layer = bytes(SQUARE_GRID_SIZE * 4)
    scripts = pack(">5i", 0, 0, 0, 0, 0)
    objects = b"".join(
        (
            _map_object(
                object_id=101,
                tile=18_490,
                fid=0x03000001,
                flags=OBJECT_MULTIHEX,
                pid=wall_pid_1,
            ),
            _map_object(
                object_id=102,
                tile=18_491,
                fid=0x03000002,
                flags=OBJECT_HIDDEN,
                pid=wall_pid_2,
            ),
            _map_object(
                object_id=201,
                tile=18_493,
                fid=0x02000001,
                flags=0,
                pid=door_pid_1,
                type_data=(0,),
            ),
            _map_object(
                object_id=202,
                tile=18_494,
                fid=0x02000002,
                flags=OBJECT_OPEN_DOOR,
                pid=door_pid_2,
                type_data=(1,),
            ),
        )
    )
    object_section = pack(">2i", 4, 4) + objects + pack(">2i", 0, 0)

    parsed = read_map(
        BytesIO(header + layer + scripts + object_section),
        prototypes.__getitem__,
    )

    assert parsed.declared_object_count == 4
    assert len(parsed.objects) == 4
    assert parsed.objects[0].blocks_movement
    assert parsed.objects[0].multihex
    assert not parsed.objects[1].blocks_movement
    assert parsed.objects[1].hidden
    assert parsed.objects[2].blocks_movement
    assert parsed.objects[2].is_door
    assert parsed.objects[2].door_open_flags == 0
    assert parsed.objects[3].is_door
    assert parsed.objects[3].door_open_flags == 1
    assert not parsed.objects[3].blocks_movement


def test_hex_world_projection_matches_godot_contract() -> None:
    assert hex_index_to_world(18_492) == pytest.approx((2.75, 0.0, -9.093266739736606))

