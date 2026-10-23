from __future__ import annotations

import zlib
from struct import pack

from fo2remix.dat_archive import DatArchive
from fo2remix.proto_format import PrototypeCatalog, parse_prototype_summary


def _scenery_proto(pid: int, subtype: int) -> bytes:
    return pack(
        ">9i",
        pid,
        100,
        0x02000001,
        8,
        65_536,
        0x10,
        0x20,
        -1,
        subtype,
    )


def _archive(files: dict[str, bytes]) -> DatArchive:
    data = bytearray()
    rows = bytearray(pack("<I", len(files)))
    for name, content in files.items():
        compressed = name.endswith("00000002.pro")
        stored = zlib.compress(content) if compressed else content
        encoded_name = name.encode("cp1252")
        rows += pack("<I", len(encoded_name))
        rows += encoded_name
        rows += pack("<BIII", compressed, len(content), len(stored), len(data))
        data += stored
    table_size = len(rows)
    payload = data + rows + pack("<II", table_size, len(data) + table_size + 8)
    return DatArchive.from_bytes(bytes(payload))


def test_parses_two_scenery_prototype_subtypes() -> None:
    door_pid = 0x02000001
    generic_pid = 0x02000002

    door = parse_prototype_summary(
        _scenery_proto(door_pid, 0),
        path=r"proto\SCENERY\00000001.pro",
        expected_pid=door_pid,
    )
    generic = parse_prototype_summary(
        _scenery_proto(generic_pid, 5),
        path=r"proto\SCENERY\00000002.pro",
        expected_pid=generic_pid,
    )

    assert door.object_type_name == "scenery"
    assert door.subtype_name == "door"
    assert generic.subtype_name == "generic"


def test_catalog_uses_one_based_list_order_for_two_records() -> None:
    door_pid = 0x02000001
    generic_pid = 0x02000002
    archive = _archive(
        {
            r"proto\SCENERY\scenery.lst": b"00000001.pro\n00000002.pro metadata\n",
            r"proto\SCENERY\00000001.pro": _scenery_proto(door_pid, 0),
            r"proto\SCENERY\00000002.pro": _scenery_proto(generic_pid, 5),
        }
    )
    catalog = PrototypeCatalog(archive)

    assert catalog.resolve(door_pid).subtype_name == "door"
    assert catalog.resolve(generic_pid).subtype_name == "generic"
