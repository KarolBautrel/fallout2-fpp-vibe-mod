# Renderer and cameras

## First renderer

Use Godot only as a replaceable visualization client. It reads `scene-v1.json`; it does not own Fallout rules in the first milestone.

Generate simple primitives:

- floor/hex: flat mesh with a debug label or color;
- wall: extruded box along the logical edge;
- door/scenery: colored placeholder with object ID;
- critter: billboard initially, capsule for collision/debug;
- player: distinct ISO placeholder and visible forward vector; hide the head/body geometry that would obstruct the FPP camera.

Do not manufacture detailed geometry from the prerendered background until the logical layout passes validation.

## Camera contract

Maintain one authoritative player transform. Cameras observe it; they never each own a separate copy.

- ISO: orthographic, configurable pitch/yaw/zoom, mouse selection through a ground/hex query.
- FPP: perspective camera located at character eye height, with yaw/pitch look and no trailing boom or over-the-shoulder offset.
- Switch: changes active camera and input map only; it must not rewrite player position, selected object or current elevation.

In FPP, cast interaction rays from the center of the camera. Keep camera height and collision radius as explicit prototype constants until critter dimensions are decoded from game data.

Keep input actions semantic (`move`, `interact`, `toggle_camera`) so later integration can translate them to `fallout2-ce` commands.

## Integration decision

After the slice works, compare:

- external Godot client fed by a state bridge;
- Godot used only as a prototyping tool, followed by a native renderer inside `fallout2-ce`;
- manual per-map 3D metadata layered over automatic logical geometry.

Choose based on measured fidelity and synchronization cost, not visual preference alone.

