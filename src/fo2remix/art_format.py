"""Resolve Fallout art FIDs through the original per-type ``.lst`` files."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from .dat_archive import DatArchive
from .frm_format import read_color_palette, read_frm_metadata, render_frm_rgba

ART_TYPE_NAMES = (
    "items",
    "critters",
    "scenery",
    "walls",
    "tiles",
    "misc",
    "intrface",
    "inven",
    "heads",
    "backgrnd",
    "skilldex",
)


@dataclass(frozen=True, slots=True)
class ArtReference:
    object_type: int
    object_type_name: str
    list_index: int
    file_name: str
    path: str


def fid_type(fid: int) -> int:
    """Match fallout2-ce's ``FID_TYPE`` macro."""

    return (fid & 0x0F000000) >> 24


def fid_list_index(fid: int) -> int:
    """Return the zero-based art-list index used by ``artBuildFilePath``."""

    return fid & 0xFFF


def fid_animation(fid: int) -> int:
    """Match fallout2-ce's ``FID_ANIM_TYPE`` macro."""

    return (fid & 0x00FF0000) >> 16


def fid_weapon_animation(fid: int) -> int:
    """Return the critter weapon-animation nibble used by ``_art_get_code``."""

    return (fid & 0x0000F000) >> 12


def _first_list_token(line: str) -> str:
    end = len(line)
    for separator in " ,;\r\t\n":
        position = line.find(separator)
        if position >= 0:
            end = min(end, position)
    return line[:end][:12]


class ArtCatalog:
    """Resolve FIDs using fallout2-ce's ``artBuildFilePath`` rules."""

    def __init__(self, archive: DatArchive) -> None:
        self.archive = archive
        self._lists: dict[int, tuple[str, ...]] = {}
        self._cache: dict[int, ArtReference] = {}

    def resolve(self, fid: int) -> ArtReference:
        cached = self._cache.get(fid)
        if cached is not None:
            return cached

        object_type = fid_type(fid)
        if object_type < 0 or object_type >= len(ART_TYPE_NAMES):
            raise ValueError(f"FID {fid:#x} has unsupported art type {object_type}")
        if object_type == 8:
            raise ValueError(
                f"FID {fid:#x} needs animated head filename expansion"
            )

        type_name = ART_TYPE_NAMES[object_type]
        lines = self._lists.get(object_type)
        if lines is None:
            list_path = rf"art\{type_name}\{type_name}.lst"
            lines = tuple(self.archive.read(list_path).decode("cp1252").splitlines())
            self._lists[object_type] = lines

        list_index = fid_list_index(fid)
        if list_index >= len(lines):
            raise ValueError(
                f"FID {fid:#x} selects line {list_index}, but "
                f"art/{type_name}/{type_name}.lst has {len(lines)} lines"
            )
        file_name = _first_list_token(lines[list_index])
        if not file_name:
            raise ValueError(f"FID {fid:#x} selects an empty art-list line")

        if object_type == 1:
            animation = fid_animation(fid)
            if animation in {27, 29, 30, 33, 55, 57, 58, 64}:
                file_name = _critter_alias_base(lines, list_index)
            first_code, second_code = _critter_animation_code(
                animation,
                fid_weapon_animation(fid),
            )
            rotation_file = (fid & 0x70000000) >> 28
            extension = f".fr{rotation_file - 1}" if rotation_file else ".frm"
            file_name = f"{file_name}{first_code}{second_code}{extension}"

        reference = ArtReference(
            object_type=object_type,
            object_type_name=type_name,
            list_index=list_index,
            file_name=file_name,
            path=rf"art\{type_name}\{file_name}",
        )
        self._cache[fid] = reference
        return reference


def _critter_alias_base(lines: tuple[str, ...], list_index: int) -> str:
    """Resolve the alias column consumed by ``artAliasFid`` for special art."""

    fields = lines[list_index].split(",")
    if len(fields) >= 2 and fields[1].strip():
        alias_index = int(fields[1].strip())
    else:
        alias_index = next(
            (
                index
                for index, line in enumerate(lines)
                if _first_list_token(line).lower() == "hmjmps"
            ),
            list_index,
        )
    if alias_index < 0 or alias_index >= len(lines):
        raise ValueError(f"critter alias {alias_index} is outside the art list")
    return _first_list_token(lines[alias_index])


def _critter_animation_code(animation: int, weapon_type: int) -> tuple[str, str]:
    """Port fallout2-ce's ``_art_get_code`` critter filename suffix."""

    if weapon_type < 0 or weapon_type >= 11:
        raise ValueError(f"unsupported critter weapon animation {weapon_type}")
    if 38 <= animation <= 47:
        if weapon_type == 0:
            raise ValueError("weapon animation requires a weapon type")
        return chr(ord("d") + weapon_type - 1), chr(ord("c") + animation - 38)
    if animation == 36:
        return "c", "h"
    if animation == 37:
        return "c", "j"
    if animation == 64:
        return "n", "a"
    if animation >= 48:
        return "r", chr(ord("a") + animation - 48)
    if animation >= 20:
        return "b", chr(ord("a") + animation - 20)
    if animation == 18:
        if weapon_type == 1:
            return "d", "m"
        if weapon_type == 4:
            return "g", "m"
        return "a", "s"
    if animation == 13:
        return ("a", "n") if weapon_type <= 0 else (
            chr(ord("d") + weapon_type - 1),
            "e",
        )
    if animation < 0 or animation > 64:
        raise ValueError(f"unsupported critter animation {animation}")
    first_code = chr(ord("d") + weapon_type - 1) if animation <= 1 and weapon_type > 0 else "a"
    return first_code, chr(ord("a") + animation)


class ArtColorCatalog:
    """Derive a cached representative RGB color from each source FRM."""

    def __init__(self, archive: DatArchive, art_catalog: ArtCatalog) -> None:
        self.archive = archive
        self.art_catalog = art_catalog
        self._palette: tuple[tuple[int, int, int, int], ...] | None = None
        self._cache: dict[int, tuple[int, int, int]] = {}
        self._metadata_cache: dict[int, dict[str, Any]] = {}

    def resolve(self, fid: int) -> tuple[int, int, int]:
        cached = self._cache.get(fid)
        if cached is not None:
            return cached
        if self._palette is None:
            self._palette = read_color_palette(self.archive.read("color.pal"))
        reference = self.art_catalog.resolve(fid)
        payload = self.archive.read(reference.path)
        metadata = read_frm_metadata(payload, path=reference.path)
        width, height, rgba = render_frm_rgba(
            payload,
            self._palette,
            path=reference.path,
        )
        opaque = [
            rgba[index : index + 3]
            for index in range(0, len(rgba), 4)
            if rgba[index + 3] != 0
        ]
        if not opaque:
            color = (0, 0, 0)
        else:
            color = tuple(
                round(sum(pixel[channel] for pixel in opaque) / len(opaque))
                for channel in range(3)
            )
        self._cache[fid] = color
        self._metadata_cache[fid] = {
            "width": width,
            "height": height,
            "frame_count": metadata.frame_count,
            "frames_per_second": metadata.frames_per_second,
            "action_frame": metadata.action_frame,
            "rotation_offsets_x": list(metadata.rotation_offsets_x),
            "rotation_offsets_y": list(metadata.rotation_offsets_y),
            "rotations": [
                [
                    {
                        "width": frame.width,
                        "height": frame.height,
                        "offset_x": frame.offset_x,
                        "offset_y": frame.offset_y,
                    }
                    for frame in frames
                ]
                for frames in metadata.rotations
            ],
        }
        return color

    def resolve_metadata(self, fid: int) -> dict[str, Any]:
        if fid not in self._metadata_cache:
            self.resolve(fid)
        return self._metadata_cache[fid]
