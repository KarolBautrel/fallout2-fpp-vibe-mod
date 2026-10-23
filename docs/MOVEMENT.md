# FPP movement contract

The prototype uses continuous first-person movement while retaining a
deterministic projection onto Fallout's logical 200 × 200 hex grid.

## Reuse boundary

The dependency-free movement core lives in
`godot/addons/classic_fpp_controller/first_person_controller.gd`. It knows
nothing about Fallout, hexes, ISO cameras or map data. All Fallout-specific
state is added by `godot/scripts/fallout_player_controller.gd`.

Keep the addon internal until its API is stable and a second project consumes
it. At that point it can move to a separate versioned repository after an
explicit license review; the game project should then pin an exact release.

## Controls

- `W` / `S`: forward and backward relative to horizontal camera yaw;
- `A` / `D`: strafe left and right without changing yaw;
- diagonal input is normalized;
- `Shift`: sprint;
- mouse: unrestricted yaw and pitch clamped to ±85°;
- `Esc`: release captured mouse;
- `Tab`: ISO/FPP without changing player state.

There is deliberately no jump or crouch because Fallout 2 has neither movement
mode. Head bob is also disabled until coordinate and collision parity is stable.

## Authoritative state

A single `CharacterBody3D` owns:

- continuous world position and velocity;
- view yaw and pitch;
- elevation;
- nearest resolved Fallout hex;
- selection.

The cameras never own player position. The FPP origin is always the controller
position plus the explicit eye height. ISO observes the same controller.

Continuous world position is authoritative during movement. After every physics
step, `world_to_nearest_hex` resolves the current logical hex. Gameplay
commands and later integration with `fallout2-ce` use that resolved index.

## Prototype constants

- walk speed: 2.8 adjacent-hex units per second;
- sprint speed: 5.0 units per second;
- acceleration: 18.0 units per second squared;
- deceleration: 22.0 units per second squared;
- capsule height: 1.75 units;
- capsule radius: 0.30 units;
- eye height: 1.68 units.

These remain explicit prototype constants until critter dimensions and movement
timings are confirmed against `fallout2-ce`.

## Evidence

`artifacts/godot-iso-fpp-contract.json` verifies input mappings, normalized
diagonals, camera-independent target movement and coordinate round trips.

`artifacts/godot-movement-runtime.json` is a real physics probe: it holds
`D` for 30 physics frames and asserts lateral displacement, negligible
forward drift, unchanged yaw and an updated logical hex.
