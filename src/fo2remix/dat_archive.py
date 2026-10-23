"""Read-only access to Fallout 2 DAT archives.

The layout follows the DBase reader in fallout2-ce's ``dfile.cc``. All archive
metadata is little-endian; individual game formats may use a different order.
"""

from __future__ import annotations

import zlib
from dataclasses import dataclass
from io import BytesIO
from pathlib import Path
from struct import Struct
from typing import BinaryIO

_U32 = Struct("<I")
_ENTRY_TAIL = Struct("<BIII")
_FOOTER = Struct("<II")


class DatFormatError(ValueError):
    """Raised when a DAT archive is malformed or unsupported."""


@dataclass(frozen=True, slots=True)
class DatEntry:
    path: str
    compressed: bool
    uncompressed_size: int
    stored_size: int
    data_offset: int


class DatArchive:
    """A validated, read-only view of a Fallout 2 DAT archive."""

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)
        self._payload: bytes | None = None
        self._file_size = self.path.stat().st_size
        self._data_base_offset = 0
        self.entries = self._read_directory()
        self._entries_by_name = {entry.path.casefold(): entry for entry in self.entries}

    @classmethod
    def from_bytes(cls, payload: bytes, name: str = "memory.dat") -> DatArchive:
        """Build an archive view from bytes, primarily for tests and tooling."""
        archive = cls.__new__(cls)
        archive.path = Path(name)
        archive._payload = payload
        archive._file_size = len(payload)
        archive._data_base_offset = 0
        archive.entries = archive._read_directory()
        archive._entries_by_name = {
            entry.path.casefold(): entry for entry in archive.entries
        }
        return archive

    def _open(self) -> BinaryIO:
        if self._payload is not None:
            return BytesIO(self._payload)
        return self.path.open("rb")

    def _read_directory(self) -> tuple[DatEntry, ...]:
        if self._file_size < _FOOTER.size:
            raise DatFormatError("DAT file is too small to contain a footer")

        with self._open() as stream:
            stream.seek(-_FOOTER.size, 2)
            table_size, archive_data_size = _FOOTER.unpack(stream.read(_FOOTER.size))

            table_offset = self._file_size - table_size - _FOOTER.size
            self._data_base_offset = self._file_size - archive_data_size
            if table_offset < 0 or self._data_base_offset < 0:
                raise DatFormatError("DAT footer points outside the archive")

            stream.seek(table_offset)
            count_bytes = stream.read(_U32.size)
            if len(count_bytes) != _U32.size:
                raise DatFormatError("DAT entry table is truncated")
            entry_count = _U32.unpack(count_bytes)[0]

            entries: list[DatEntry] = []
            for index in range(entry_count):
                path_length_bytes = stream.read(_U32.size)
                if len(path_length_bytes) != _U32.size:
                    raise DatFormatError(f"DAT entry {index} is truncated")
                path_length = _U32.unpack(path_length_bytes)[0]
                if path_length == 0 or path_length > 32_768:
                    raise DatFormatError(f"DAT entry {index} has an invalid path length")

                raw_path = stream.read(path_length)
                raw_tail = stream.read(_ENTRY_TAIL.size)
                if len(raw_path) != path_length or len(raw_tail) != _ENTRY_TAIL.size:
                    raise DatFormatError(f"DAT entry {index} is truncated")

                compressed, unpacked_size, stored_size, data_offset = _ENTRY_TAIL.unpack(
                    raw_tail
                )
                if compressed not in (0, 1):
                    raise DatFormatError(f"DAT entry {index} has an invalid compression flag")
                absolute_offset = self._data_base_offset + data_offset
                if absolute_offset < 0 or absolute_offset + stored_size > table_offset:
                    raise DatFormatError(f"DAT entry {index} points outside the data area")

                entries.append(
                    DatEntry(
                        path=raw_path.decode("cp1252"),
                        compressed=bool(compressed),
                        uncompressed_size=unpacked_size,
                        stored_size=stored_size,
                        data_offset=data_offset,
                    )
                )

        return tuple(entries)

    def find(self, archive_path: str) -> DatEntry:
        """Find an entry using Fallout's case-insensitive path semantics."""
        key = archive_path.replace("/", "\\").casefold()
        try:
            return self._entries_by_name[key]
        except KeyError as exc:
            raise KeyError(f"entry not found in {self.path.name}: {archive_path}") from exc

    def read(self, entry_or_path: DatEntry | str) -> bytes:
        """Read and, when necessary, decompress one archive entry."""
        entry = (
            entry_or_path
            if isinstance(entry_or_path, DatEntry)
            else self.find(entry_or_path)
        )
        with self._open() as stream:
            stream.seek(self._data_base_offset + entry.data_offset)
            stored = stream.read(entry.stored_size)
        if len(stored) != entry.stored_size:
            raise DatFormatError(f"data for {entry.path} is truncated")

        try:
            data = zlib.decompress(stored) if entry.compressed else stored
        except zlib.error as exc:
            raise DatFormatError(f"cannot decompress {entry.path}: {exc}") from exc
        if len(data) != entry.uncompressed_size:
            raise DatFormatError(
                f"unexpected size for {entry.path}: "
                f"got {len(data)}, expected {entry.uncompressed_size}"
            )
        return data

    def matching(self, suffix: str) -> tuple[DatEntry, ...]:
        """Return entries whose paths end with ``suffix`` (case-insensitive)."""
        folded = suffix.casefold()
        return tuple(entry for entry in self.entries if entry.path.casefold().endswith(folded))
