"""Minimal prototype metadata needed to decode MAP object payloads."""

from __future__ import annotations

from dataclasses import dataclass
from struct import Struct

from .dat_archive import DatArchive

OBJECT_TYPE_NAMES = (
    "item",
    "critter",
    "scenery",
    "wall",
    "tile",
    "misc",
)
ITEM_SUBTYPE_NAMES = (
    "armor",
    "container",
    "drug",
    "weapon",
    "ammo",
    "misc",
    "key",
)
SCENERY_SUBTYPE_NAMES = (
    "door",
    "stairs",
    "elevator",
    "ladder_up",
    "ladder_down",
    "generic",
)

_PROTOTYPE_LIST_PATHS = {
    0: ("ITEMS", "items.lst"),
    1: ("CRITTERS", "critters.lst"),
    2: ("SCENERY", "scenery.lst"),
    3: ("WALLS", "walls.lst"),
    4: ("TILES", "tiles.lst"),
    5: ("MISC", "MISC.LST"),
}
_COMMON_NON_TILE = Struct(">8i")
_INT32 = Struct(">i")


@dataclass(frozen=True, slots=True)
class PrototypeSummary:
    pid: int
    object_type: int
    object_type_name: str
    fid: int
    flags: int
    extended_flags: int
    subtype: int | None
    subtype_name: str | None
    path: str


def pid_type(pid: int) -> int:
    """Match fallout2-ce's ``PID_TYPE`` macro for valid prototype ids."""

    return pid >> 24


def parse_prototype_summary(
    payload: bytes,
    *,
    path: str,
    expected_pid: int | None = None,
) -> PrototypeSummary:
    """Read the common `.pro` prefix and the item/scenery subtype field."""

    if len(payload) < 12:
        raise EOFError(f"prototype {path} is shorter than its 12-byte identity")

    stored_pid, _message_id, fid = Struct(">3i").unpack_from(payload)
    if expected_pid is not None and stored_pid != expected_pid:
        raise ValueError(
            f"prototype {path} stores pid {stored_pid:#x}, expected {expected_pid:#x}"
        )

    object_type = pid_type(stored_pid)
    if object_type not in _PROTOTYPE_LIST_PATHS:
        raise ValueError(f"prototype {path} has unsupported object type {object_type}")

    flags = 0
    extended_flags = 0
    subtype: int | None = None
    subtype_name: str | None = None
    if object_type in {0, 1, 2, 3}:
        if len(payload) < _COMMON_NON_TILE.size:
            raise EOFError(
                f"prototype {path} is shorter than its {_COMMON_NON_TILE.size}-byte prefix"
            )
        common = _COMMON_NON_TILE.unpack_from(payload)
        flags = common[5]
        extended_flags = common[6]

    if object_type in {0, 2}:
        if len(payload) < _COMMON_NON_TILE.size + _INT32.size:
            raise EOFError(f"prototype {path} is missing its subtype")
        subtype = _INT32.unpack_from(payload, _COMMON_NON_TILE.size)[0]
        names = ITEM_SUBTYPE_NAMES if object_type == 0 else SCENERY_SUBTYPE_NAMES
        if subtype < 0 or subtype >= len(names):
            raise ValueError(f"prototype {path} has invalid subtype {subtype}")
        subtype_name = names[subtype]

    return PrototypeSummary(
        pid=stored_pid,
        object_type=object_type,
        object_type_name=OBJECT_TYPE_NAMES[object_type],
        fid=fid,
        flags=flags,
        extended_flags=extended_flags,
        subtype=subtype,
        subtype_name=subtype_name,
        path=path,
    )


class PrototypeCatalog:
    """Resolve prototype ids through the same 1-based `.lst` lookup as fallout2-ce."""

    def __init__(self, archive: DatArchive) -> None:
        self.archive = archive
        self._lists: dict[int, tuple[str, ...]] = {}
        self._cache: dict[int, PrototypeSummary] = {}

    def resolve(self, pid: int) -> PrototypeSummary:
        cached = self._cache.get(pid)
        if cached is not None:
            return cached

        object_type = pid_type(pid)
        try:
            folder, list_name = _PROTOTYPE_LIST_PATHS[object_type]
        except KeyError as exc:
            raise ValueError(f"unsupported prototype object type {object_type} for {pid:#x}") from exc

        lines = self._lists.get(object_type)
        if lines is None:
            list_path = rf"proto\{folder}\{list_name}"
            text = self.archive.read(list_path).decode("cp1252")
            lines = tuple(text.splitlines())
            self._lists[object_type] = lines

        list_index = pid & 0xFFFFFF
        if list_index <= 0 or list_index > len(lines):
            raise ValueError(
                f"prototype id {pid:#x} selects line {list_index}, "
                f"but proto/{folder}/{list_name} has {len(lines)} lines"
            )

        line = lines[list_index - 1].strip()
        if not line:
            raise ValueError(f"prototype id {pid:#x} selects an empty list line")
        file_name = line.split(maxsplit=1)[0]
        path = rf"proto\{folder}\{file_name}"
        summary = parse_prototype_summary(
            self.archive.read(path),
            path=path,
            expected_pid=pid,
        )
        self._cache[pid] = summary
        return summary
