"""Command-line inspection tools for the Fallout 2 perspective prototype."""

from __future__ import annotations

import argparse
import json
from io import BytesIO
from pathlib import Path, PureWindowsPath

from .art_format import ArtCatalog, ArtColorCatalog
from .dat_archive import DatArchive
from .frm_format import (
    encode_rgba_png,
    read_color_palette,
    read_frm_metadata,
    render_frm_rgba,
)
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
    art = ArtCatalog(archive)
    art_colors = ArtColorCatalog(archive, art)
    scene = export_scene_v1(
        archive.read(entry),
        source={"archive": str(Path(args.archive).resolve()), "entry": entry.path},
        prototype_resolver=prototypes.resolve,
        art_resolver=art.resolve,
        art_color_resolver=art_colors.resolve,
        art_metadata_resolver=art_colors.resolve_metadata,
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


def _frm_inspect(args: argparse.Namespace) -> int:
    archive = DatArchive(args.archive)
    entry = archive.find(args.entry)
    metadata = read_frm_metadata(archive.read(entry), path=entry.path)
    result = metadata.to_dict()
    result["source_archive"] = str(Path(args.archive).resolve())
    encoded = json.dumps(result, indent=2)
    if args.output:
        output = Path(args.output)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(encoded, encoding="utf-8")
        print(f"wrote FRM metadata for {entry.path} to {output}")
    else:
        print(encoded)
    return 0


def _frm_render(args: argparse.Namespace) -> int:
    archive = DatArchive(args.archive)
    entry = archive.find(args.entry)
    palette_entry = archive.find(args.palette_entry)
    palette = read_color_palette(archive.read(palette_entry))
    width, height, rgba = render_frm_rgba(
        archive.read(entry),
        palette,
        rotation=args.rotation,
        frame=args.frame,
        path=entry.path,
    )
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(encode_rgba_png(width, height, rgba))
    print(
        f"wrote {width}x{height} RGBA frame {args.frame}, rotation "
        f"{args.rotation} from {entry.path} to {output}"
    )
    return 0


def _scene_art_cache(args: argparse.Namespace) -> int:
    archive = DatArchive(args.archive)
    scene_path = Path(args.scene)
    scene = json.loads(scene_path.read_text(encoding="utf-8"))
    art_paths = {
        str(record.get("art", {}).get("path", "")).lower(): str(
            record.get("art", {}).get("path", "")
        )
        for record in scene["objects"]["records"]
        if record.get("art", {}).get("path")
    }
    palette = read_color_palette(archive.read(args.palette_entry))
    output_root = Path(args.output_dir)
    assets: list[dict[str, object]] = []
    for _key, art_path in sorted(art_paths.items()):
        entry = archive.find(art_path)
        payload = archive.read(entry)
        metadata = read_frm_metadata(payload, path=entry.path)
        source_path = PureWindowsPath(entry.path)
        frame_indices = range(metadata.frame_count) if args.all_frames else range(1)
        outputs: list[str] = []
        width = height = 0
        for frame_index in frame_indices:
            relative_output = (
                Path(source_path.parent.name.lower())
                / f"{source_path.stem.lower()}-r0-f{frame_index}.png"
            )
            output = output_root / relative_output
            width, height, rgba = render_frm_rgba(
                payload,
                palette,
                rotation=0,
                frame=frame_index,
                path=entry.path,
            )
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_bytes(encode_rgba_png(width, height, rgba))
            outputs.append(relative_output.as_posix())
        assets.append(
            {
                "source": entry.path,
                "outputs": outputs,
                "width": width,
                "height": height,
                "frame_count": metadata.frame_count,
                "frames_per_second": metadata.frames_per_second,
            }
        )

    manifest = {
        "schema": "fo2remix.art-cache-v1",
        "scene": str(scene_path.resolve()),
        "source_archive": str(Path(args.archive).resolve()),
        "asset_count": len(assets),
        "policy": (
            "unique art path, rotation 0, all frames"
            if args.all_frames
            else "unique art path, rotation 0, frame 0"
        ),
        "assets": assets,
    }
    output_root.mkdir(parents=True, exist_ok=True)
    manifest_path = output_root / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"cached {len(assets)} unique FRM assets to {output_root}")
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

    frm_parser = commands.add_parser(
        "frm-inspect", help="inspect FRM frame metadata without extracting its pixels"
    )
    frm_parser.add_argument("archive", type=Path)
    frm_parser.add_argument("entry", help=r"archive path, e.g. art\walls\temple19.frm")
    frm_parser.add_argument("--output", type=Path)
    frm_parser.set_defaults(handler=_frm_inspect)

    render_parser = commands.add_parser(
        "frm-render", help="render one FRM frame through Fallout's palette to PNG"
    )
    render_parser.add_argument("archive", type=Path)
    render_parser.add_argument("entry", help=r"archive path, e.g. art\walls\temple19.frm")
    render_parser.add_argument("output", type=Path)
    render_parser.add_argument("--palette-entry", default="color.pal")
    render_parser.add_argument("--rotation", type=int, default=0)
    render_parser.add_argument("--frame", type=int, default=0)
    render_parser.set_defaults(handler=_frm_render)

    cache_parser = commands.add_parser(
        "scene-art-cache",
        help="cache the first frame of every unique FRM referenced by a scene",
    )
    cache_parser.add_argument("archive", type=Path)
    cache_parser.add_argument("scene", type=Path)
    cache_parser.add_argument("output_dir", type=Path)
    cache_parser.add_argument("--palette-entry", default="color.pal")
    cache_parser.add_argument("--all-frames", action="store_true")
    cache_parser.set_defaults(handler=_scene_art_cache)
    return parser


def main() -> int:
    args = _parser().parse_args()
    return args.handler(args)


if __name__ == "__main__":
    raise SystemExit(main())
