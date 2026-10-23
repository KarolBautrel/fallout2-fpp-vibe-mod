# Data pipeline

## Source order

1. Locate the loading and coordinate code in `engine/fallout2-ce/src` with `rg`.
2. Confirm field sizes, byte order and coordinate transforms against actual owned files.
3. Check existing community documentation only after identifying the corresponding code path.
4. Write a minimal reader and a test fixture containing synthetic data; do not commit extracted retail data.

Likely starting points in `fallout2-ce`: `src/db.*`, `src/map.*`, `src/tile.*`, `src/object.*`, `src/art.*`, `src/proto.*` and the mapper sources.

## Existing project tools

Set `PYTHONPATH` to `src` when the package has not yet been installed editable.

```powershell
$env:PYTHONPATH = (Join-Path (Get-Location) 'src')
.\.venv\Scripts\python.exe -m fo2remix dat-list <master.dat> --suffix .map
.\.venv\Scripts\python.exe -m fo2remix map-extract <master.dat> <map-entry>
.\.venv\Scripts\python.exe -m fo2remix scene-export <master.dat> <map-entry> <output.json>
```

`DatArchive` is read-only and handles plain or zlib-compressed DAT entries.
`read_map_core` currently reads the fixed header, global/local variables and the
100 × 100 floor/roof layers. Scripts, objects, prototype records and FRM art are
not yet part of the supported subset.

## Intermediate schema

Version the exported schema from the first commit. At minimum include:

- source map identifier and elevation;
- coordinate-system metadata;
- walkable/blocking hexes;
- floor and roof tile identifiers;
- wall, scenery, door and critter records;
- source logical position and renderer transform;
- unresolved fields in a named `unknown` object rather than silently dropping them.

Prefer JSON for the first slice because it is inspectable and easy to diff. Move to a binary format only after size or load time becomes a measured problem.

The current `fo2remix.scene-v1` contains source metadata, map identity, spawn
hex and floor/roof ID arrays. Treat it as additive and experimental until
objects and collision semantics are represented.

## Proof requirements

- Parse at least two records of each claimed structure.
- Test boundary indices and all elevations represented by the chosen map.
- Save a coordinate table containing several known hexes and their projected screen/world positions.
- If implementing a writer, prove decode → encode → decode equivalence before using it on game data.

