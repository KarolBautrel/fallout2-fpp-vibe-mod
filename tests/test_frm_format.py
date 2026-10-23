from struct import pack
from zlib import decompress

from fo2remix.frm_format import (
    encode_rgba_png,
    read_color_palette,
    read_frm_metadata,
    render_frm_rgba,
)


def _frame(width: int, height: int, offset_x: int, offset_y: int) -> bytes:
    pixels = bytes(range(width * height))
    return pack(">hhihh", width, height, len(pixels), offset_x, offset_y) + pixels


def test_reads_shared_and_distinct_rotation_frame_metadata() -> None:
    first_rotation = _frame(2, 2, -1, 3) + _frame(1, 2, 4, -2)
    second_rotation = _frame(3, 1, 2, 5) + _frame(1, 1, -3, 7)
    data_offsets = (0, 0, len(first_rotation), len(first_rotation), 0, 0)
    header = pack(
        ">i3h6h6h6ii",
        4,
        10,
        1,
        2,
        *(1, 2, 3, 4, 5, 6),
        *(-1, -2, -3, -4, -5, -6),
        *data_offsets,
        len(first_rotation) + len(second_rotation),
    )

    metadata = read_frm_metadata(
        header + first_rotation + second_rotation,
        path=r"art\walls\test.frm",
    )

    assert metadata.version == 4
    assert metadata.frame_count == 2
    assert metadata.rotation_offsets_x == (1, 2, 3, 4, 5, 6)
    assert metadata.rotations[0][0].width == 2
    assert metadata.rotations[0][1].offset_y == -2
    assert metadata.rotations[1] is metadata.rotations[0]
    assert metadata.rotations[2][0].width == 3
    assert metadata.rotations[3] is metadata.rotations[2]


def test_renders_palette_indices_to_transparent_rgba_png() -> None:
    pixels = bytes((0, 1, 2, 1))
    frame = pack(">hhihh", 2, 2, len(pixels), 0, 0) + pixels
    header = pack(
        ">i3h6h6h6ii",
        4,
        1,
        0,
        1,
        *(0,) * 6,
        *(0,) * 6,
        *(0,) * 6,
        len(frame),
    )
    palette_payload = bytearray(768)
    palette_payload[3:6] = bytes((63, 0, 0))
    palette_payload[6:9] = bytes((0, 63, 0))
    palette = read_color_palette(bytes(palette_payload))

    width, height, rgba = render_frm_rgba(header + frame, palette)
    png = encode_rgba_png(width, height, rgba)

    assert (width, height) == (2, 2)
    assert rgba[:4] == bytes((0, 0, 0, 0))
    assert rgba[4:8] == bytes((255, 0, 0, 255))
    assert rgba[8:12] == bytes((0, 255, 0, 255))
    assert png.startswith(b"\x89PNG\r\n\x1a\n")
    idat_length = int.from_bytes(png[33:37], "big")
    assert decompress(png[41 : 41 + idat_length]) == (
        b"\0" + rgba[:8] + b"\0" + rgba[8:]
    )
