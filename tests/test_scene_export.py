from __future__ import annotations

from struct import pack

from fo2remix.map_format import (
    MAP_HEADER_STRUCT,
    OBJECT_MULTIHEX,
    OBJECT_OPEN_DOOR,
    SQUARE_GRID_SIZE,
)
from fo2remix.proto_format import PrototypeSummary
from fo2remix.scene_export import export_scene_v1


def _signed_int32(value: int) -> int:
    return value if value < 0x80000000 else value - 0x100000000


def _object(
    object_id: int,
    tile: int,
    fid: int,
    flags: int,
    pid: int,
    *type_data: int,
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


def _prototype(pid: int, subtype: int | None = None) -> PrototypeSummary:
    object_type = pid >> 24
    name = "wall" if object_type == 3 else "scenery"
    return PrototypeSummary(
        pid=pid,
        object_type=object_type,
        object_type_name=name,
        fid=object_type << 24,
        flags=0,
        extended_flags=0,
        subtype=subtype,
        subtype_name="door" if subtype == 0 else None,
        path=rf"proto\{name}\{pid & 0xFFFFFF:08d}.pro",
    )


def test_exports_one_present_tile_layer() -> None:
    header = MAP_HEADER_STRUCT.pack(
        20,
        b"TEST.MAP\0\0\0\0\0\0\0\0",
        18492,
        0,
        2,
        0,
        10,
        12,
        1,
        0,
        42,
        0,
        *([0] * 44),
    )
    packed_tile = (3 << 28) | (7 << 16) | 5
    layer = pack(f">{SQUARE_GRID_SIZE}I", *([packed_tile] * SQUARE_GRID_SIZE))
    wall_pid = 0x03000001
    closed_door_pid = 0x02000001
    open_door_pid = 0x02000002
    prototypes = {
        wall_pid: _prototype(wall_pid),
        closed_door_pid: _prototype(closed_door_pid, 0),
        open_door_pid: _prototype(open_door_pid, 0),
    }
    scripts = pack(">5i", 0, 0, 0, 0, 0)
    object_records = b"".join(
        (
            _object(101, 18_490, 0x03000001, OBJECT_MULTIHEX, wall_pid),
            _object(201, 18_493, 0x02000001, 0, closed_door_pid, 0),
            _object(202, 18_494, 0x02000002, OBJECT_OPEN_DOOR, open_door_pid, 1),
        )
    )
    object_section = pack(">2i", 3, 3) + object_records + pack(">2i", 0, 0)

    scene = export_scene_v1(
        header + layer + scripts + object_section,
        source={"entry": r"maps\test.map"},
        prototype_resolver=prototypes.__getitem__,
    )

    assert scene["schema"] == "fo2remix.scene-v1"
    assert scene["spawn"]["hex_index"] == 18492
    assert len(scene["tile_grid"]["layers"]) == 1
    assert scene["tile_grid"]["layers"][0]["floor_ids"][0] == 5
    assert scene["tile_grid"]["layers"][0]["roof_ids"][0] == 7
    assert scene["tile_grid"]["layers"][0]["roof_flags"][0] == 3
    assert scene["objects"]["declared_count"] == 3
    assert scene["objects"]["wall_count"] == 1
    assert scene["objects"]["door_count"] == 2
    assert scene["objects"]["records"][1]["door"]["open"] is False
    assert scene["objects"]["records"][2]["door"]["open"] is True
    assert scene["objects"]["records"][0]["flags"]["multihex"] is True
    assert len(scene["collision"]["blocking_hexes"]) == 8
