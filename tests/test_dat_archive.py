from __future__ import annotations

import zlib
from struct import pack

import pytest

from fo2remix.dat_archive import DatArchive, DatFormatError


def _make_archive() -> tuple[bytes, dict[str, bytes]]:
    files = {
        r"maps\plain.map": b"plain map data",
        r"maps\packed.map": b"compressed map data" * 16,
    }
    data = bytearray()
    rows = bytearray(pack("<I", len(files)))
    for name, content in files.items():
        compressed = name.endswith("packed.map")
        stored = zlib.compress(content) if compressed else content
        encoded_name = name.encode("cp1252")
        rows += pack("<I", len(encoded_name))
        rows += encoded_name
        rows += pack("<BIII", compressed, len(content), len(stored), len(data))
        data += stored

    table_size = len(rows)
    archive = data + rows + pack("<II", table_size, len(data) + table_size + 8)
    return bytes(archive), files


def test_lists_and_reads_plain_and_compressed_entries() -> None:
    payload, files = _make_archive()
    archive = DatArchive.from_bytes(payload)

    assert len(archive.entries) == 2
    assert archive.read(r"MAPS/PLAIN.MAP") == files[r"maps\plain.map"]
    assert archive.read(r"maps\packed.map") == files[r"maps\packed.map"]
    assert len(archive.matching(".map")) == 2


def test_rejects_too_small_archive() -> None:
    with pytest.raises(DatFormatError, match="too small"):
        DatArchive.from_bytes(b"tiny")


def test_reports_missing_entry() -> None:
    payload, _ = _make_archive()

    with pytest.raises(KeyError, match="entry not found"):
        DatArchive.from_bytes(payload).read("missing.map")
