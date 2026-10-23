"""Command-line inspection tools for the Fallout 2 perspective prototype."""

from __future__ import annotations

import argparse
import json
from io import BytesIO
from pathlib import Path

from .dat_archive import DatArchive
from .map_format import read_map_header
from .proto_format import PrototypeCatalog
from .scene_export import export_scene_v1


def _dat_list(args: argparse.Namespace) -> int:
    archive = DatArchive(args.archive)
    entries = archive.matching(args.suffix) if args.suffix else archive.entries
    for entry in entries:
        marker = "z" if entry.compressed else "-"
        print(f"{marker} {entry.uncompressed_size:>10} {entry.path}")
    print(f"{len(entries)} of {len(archive.entries)} entries")
    return 0


def _extract_map(args: argparse.Namespace) -> int:
    archive = DatArchive(args.archive)
    data = archive.read(args.entry)
    header = read_map_header(BytesIO(data))
    result = {
        "archive": str(Path(args.archive).resolve()),
        "entry": archive.find(args.entry).path,
        "header": {
            "version": header.version,
            "name": header.name,
            "entering_tile": header.entering_tile,
            "entering_elevation": header.entering_elevation,
            "entering_rotation": header.entering_rotation,
            "local_variables_count": header.local_variables_count,
            "script_index": header.script_index,
            "flags": header.flags,
            "darkness": header.darkness,
            "global_variables_count": header.global_variables_count,
            "map_index": header.map_index,
            "last_visit_time": header.last_visit_time,
        },
    }
    print(json.dumps(result, indent=2))

    if args.output:
        output = Path(args.output)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(data)
        print(f"wrote {len(data)} bytes to {output}")
    return 0


def _scene_export(args: argparse.Namespace) -> int:
    archive = DatArchive(args.archive)
    entry = archive.find(args.entry)
    prototypes = PrototypeCatalog(archive)
    scene = export_scene_v1(
        archive.read(entry),
        source={"archive": str(Path(args.archive).resolve()), "entry": entry.path},
        prototype_resolver=prototypes.resolve,
    )
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(scene, indent=2), encoding="utf-8")
    print(
        f"wrote {scene['map']['name']} with "
        f"{len(scene['tile_grid']['layers'])} tile layer(s), "
        f"{scene['objects']['wall_count']} wall(s), "
        f"{scene['objects']['door_count']} door(s), and "
        f"{len(scene['collision']['blocking_hexes'])} blocking hex(es) to {output}"
    )
    return 0


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="python -m fo2remix")
    commands = parser.add_subparsers(required=True)

    list_parser = commands.add_parser("dat-list", help="list DAT archive entries")
    list_parser.add_argument("archive", type=Path)
    list_parser.add_argument("--suffix", help="only paths ending in this suffix")
    list_parser.set_defaults(handler=_dat_list)

    map_parser = commands.add_parser(
        "map-extract", help="inspect and optionally extract one MAP from a DAT archive"
    )
    map_parser.add_argument("archive", type=Path)
    map_parser.add_argument("entry", help=r"archive path, e.g. maps\artemple.map")
    map_parser.add_argument("--output", type=Path)
    map_parser.set_defaults(handler=_extract_map)

    scene_parser = commands.add_parser(
        "scene-export", help="export MAP floor/roof layers as scene-v1 JSON"
    )
    scene_parser.add_argument("archive", type=Path)
    scene_parser.add_argument("entry", help=r"archive path, e.g. maps\artemple.map")
    scene_parser.add_argument("output", type=Path)
    scene_parser.set_defaults(handler=_scene_export)
    return parser


def main() -> int:
    args = _parser().parse_args()
    return args.handler(args)


if __name__ == "__main__":
    raise SystemExit(main())
