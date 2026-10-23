"""Read-only metadata parser for Fallout FRM art files."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from struct import Struct
from typing import Any
from zlib import compress, crc32

ROTATION_COUNT = 6
_HEADER = Struct(">i3h6h6h6ii")
_FRAME_HEADER = Struct(">hhihh")


@dataclass(frozen=True, slots=True)
class FrmFrame:
    width: int
    height: int
    pixel_count: int
    offset_x: int
    offset_y: int
    pixel_data_offset: int


@dataclass(frozen=True, slots=True)
class FrmMetadata:
    version: int
    frames_per_second: int
    action_frame: int
    frame_count: int
    rotation_offsets_x: tuple[int, ...]
    rotation_offsets_y: tuple[int, ...]
    data_offsets: tuple[int, ...]
    data_size: int
    rotations: tuple[tuple[FrmFrame, ...], ...]
    path: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def read_frm_metadata(payload: bytes, *, path: str = "") -> FrmMetadata:
    """Parse the FRM header and per-rotation frame descriptors without pixels."""

    if len(payload) < _HEADER.size:
        raise EOFError(f"FRM {path or '<memory>'} is shorter than {_HEADER.size} bytes")

    values = _HEADER.unpack_from(payload)
    version = values[0]
    frames_per_second, action_frame, frame_count = values[1:4]
    rotation_offsets_x = tuple(values[4:10])
    rotation_offsets_y = tuple(values[10:16])
    data_offsets = tuple(values[16:22])
    declared_data_size = values[22]

    if frame_count <= 0:
        raise ValueError(f"FRM {path or '<memory>'} has invalid frame count {frame_count}")

    parsed_by_offset: dict[int, tuple[FrmFrame, ...]] = {}
    rotations: list[tuple[FrmFrame, ...]] = []
    for data_offset in data_offsets:
        if data_offset < 0:
            raise ValueError(f"FRM {path or '<memory>'} has negative data offset")
        frames = parsed_by_offset.get(data_offset)
        if frames is None:
            cursor = _HEADER.size + data_offset
            parsed_frames: list[FrmFrame] = []
            for _frame_index in range(frame_count):
                if cursor + _FRAME_HEADER.size > len(payload):
                    raise EOFError(f"FRM {path or '<memory>'} has a truncated frame header")
                width, height, pixel_count, offset_x, offset_y = _FRAME_HEADER.unpack_from(
                    payload, cursor
                )
                pixel_data_offset = cursor + _FRAME_HEADER.size
                if width <= 0 or height <= 0 or pixel_count < 0:
                    raise ValueError(f"FRM {path or '<memory>'} has invalid frame dimensions")
                if pixel_data_offset + pixel_count > len(payload):
                    raise EOFError(f"FRM {path or '<memory>'} has truncated pixel data")
                parsed_frames.append(
                    FrmFrame(
                        width=width,
                        height=height,
                        pixel_count=pixel_count,
                        offset_x=offset_x,
                        offset_y=offset_y,
                        pixel_data_offset=pixel_data_offset,
                    )
                )
                cursor = pixel_data_offset + pixel_count
            frames = tuple(parsed_frames)
            parsed_by_offset[data_offset] = frames
        rotations.append(frames)

    data_size = declared_data_size if declared_data_size != 0 else len(payload)
    return FrmMetadata(
        version=version,
        frames_per_second=frames_per_second,
        action_frame=action_frame,
        frame_count=frame_count,
        rotation_offsets_x=rotation_offsets_x,
        rotation_offsets_y=rotation_offsets_y,
        data_offsets=data_offsets,
        data_size=data_size,
        rotations=tuple(rotations),
        path=path,
    )


def read_color_palette(payload: bytes) -> tuple[tuple[int, int, int, int], ...]:
    """Decode the 256 VGA colors at the start of Fallout's ``color.pal``."""

    if len(payload) < 256 * 3:
        raise EOFError("color palette is shorter than 768 bytes")
    colors: list[tuple[int, int, int, int]] = []
    for index in range(256):
        red, green, blue = payload[index * 3 : index * 3 + 3]
        if red > 63 or green > 63 or blue > 63:
            red = green = blue = 0
        colors.append(
            (
                round(red * 255 / 63),
                round(green * 255 / 63),
                round(blue * 255 / 63),
                0 if index == 0 else 255,
            )
        )
    return tuple(colors)


def render_frm_rgba(
    payload: bytes,
    palette: tuple[tuple[int, int, int, int], ...],
    *,
    rotation: int = 0,
    frame: int = 0,
    path: str = "",
) -> tuple[int, int, bytes]:
    """Decode one FRM frame into row-major RGBA pixels."""

    metadata = read_frm_metadata(payload, path=path)
    if rotation < 0 or rotation >= ROTATION_COUNT:
        raise IndexError(f"rotation {rotation} is outside 0..{ROTATION_COUNT - 1}")
    if frame < 0 or frame >= metadata.frame_count:
        raise IndexError(f"frame {frame} is outside 0..{metadata.frame_count - 1}")
    descriptor = metadata.rotations[rotation][frame]
    indices = payload[
        descriptor.pixel_data_offset : descriptor.pixel_data_offset
        + descriptor.pixel_count
    ]
    expected_count = descriptor.width * descriptor.height
    if len(indices) != expected_count:
        raise ValueError(
            f"FRM {path or '<memory>'} frame stores {len(indices)} pixels, "
            f"expected {expected_count}"
        )
    rgba = bytearray(expected_count * 4)
    for index, palette_index in enumerate(indices):
        rgba[index * 4 : index * 4 + 4] = bytes(palette[palette_index])
    return descriptor.width, descriptor.height, bytes(rgba)


def encode_rgba_png(width: int, height: int, rgba: bytes) -> bytes:
    """Encode an RGBA8 image as a minimal non-interlaced PNG."""

    if width <= 0 or height <= 0 or len(rgba) != width * height * 4:
        raise ValueError("invalid RGBA image dimensions or payload length")

    def chunk(kind: bytes, data: bytes) -> bytes:
        body = kind + data
        return Struct(">I").pack(len(data)) + body + Struct(">I").pack(crc32(body))

    scanlines = b"".join(
        b"\0" + rgba[row * width * 4 : (row + 1) * width * 4]
        for row in range(height)
    )
    header = Struct(">IIBBBBB").pack(width, height, 8, 6, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", compress(scanlines, level=9))
        + chunk(b"IEND", b"")
    )
