from io import BytesIO

import pytest

from fo2remix.map_format import (
    MAP_HEADER_SIZE,
    MAP_HEADER_STRUCT,
    grid_to_tile_index,
    read_map_header,
    tile_index_to_grid,
)


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

