---
name: fallout2-fpp-vibe-mod
description: Develop or investigate the Fallout 2 ISO/FPP vibe-mod project, including reading owned game data, tracing fallout2-ce map logic, exporting a neutral scene, building the Godot first-person prototype, and verifying coordinate or behavior parity. Do not use for unrelated Fallout mods.
---

# Fallout 2 FPP Vibe Mod

Preserve Fallout 2's logical world while adding a first-person 3D presentation. Keep the first deliverable to one map, one player, ISO/FPP cameras and one interaction. FPP means a camera at the character's eyes, never a trailing third-person camera.

## Select the relevant path

- For install detection, `.dat`/`.map`/`.frm` research, coordinate discovery or parser work, read [references/data-pipeline.md](references/data-pipeline.md).
- For Godot scene generation, camera switching or interaction architecture, read [references/renderer.md](references/renderer.md).
- For correctness checks, parity traces, screenshots or acceptance criteria, read [references/verification.md](references/verification.md).

Read only the references needed by the current task.

## Shared invariants

- Treat `C:\Program Files (x86)\Steam\steamapps\common\Fallout 2` as read-only unless the user explicitly changes the path.
- Use `fallout2-ce` source as the first authority for format and behavior; do not reverse the retail EXE when source answers the question.
- Never commit or distribute original `.dat`, `.map`, `.frm`, audio, movies or extracted assets. Commit code, schemas, tests and converters.
- Make coordinate systems explicit: units, axis direction, origin, elevation, hex orientation and rotation.
- Record confirmed findings in `docs/` and leave reproducible evidence in ignored `artifacts/`.
- Change one boundary at a time: parse first, render debug geometry second, add camera/control third, integrate simulation last.

## Definition of done for the vertical slice

The same player state is visible in ISO and FPP, switching cameras does not move the player, the FPP camera remains anchored to eye height, movement resolves to the same logical hex, and one door/object interaction gives the same result in both views.

