# Godot ISO/FPP debug slice

The project reads `../artifacts/artemple.scene-v1.json` at runtime. It does not
contain or download original Fallout 2 assets.

The debug renderer currently creates neutral geometry for exported walls and
scenery plus one physical collider for every Fallout-blocking hex. It does not
attempt to reconstruct proprietary prerendered artwork.

Initialize the pinned movement package after cloning the repository:

```powershell
git submodule update --init --recursive
```

Run it with the project Godot executable:

```powershell
& "$env:USERPROFILE\Desktop\Gierka\installers\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" `
  --path godot
```

Controls:

- the prototype starts in true first-person view;
- move the mouse to look around; press `Esc` to release it and click to capture again;
- `Tab`: switch ISO/FPP camera;
- `W` / `S`: move forward/backward;
- `A` / `D`: strafe left/right;
- `Shift`: sprint.
- `E`: interact with the targeted/selected object;
- in FPP, aim the center crosshair at nearby blocking scenery;
- in ISO, left-click blocking scenery to select it, approach it, then press `E`.

Both cameras observe the same `CharacterBody3D`. The FPP camera origin is exactly
the player position plus the explicit `1.68` world-unit eye height and has no
trailing or over-the-shoulder offset.

The reusable movement core comes from the pinned
[`godot-classic-fpp-controller`](https://github.com/KarolBautrel/godot-classic-fpp-controller)
submodule in `addons/classic_fpp_controller`. The project-specific
`scripts/fallout_player_controller.gd` adapter adds logical hex state.
The pinned `v0.2.0` package also provides configurable floor snapping,
walkable slopes and automatic step-up for low stairs.

Both camera paths resolve to the same exported `instance_id` and mutate one
shared object-state dictionary. Activated debug objects turn yellow; an ISO
selection turns cyan. The export retains Fallout's original `object_id`, but
does not use it as a unique key because real `ARTEMPLE.MAP` records repeat it.

## Live state bridge

The Godot client tails `../artifacts/fallout2-ce-state.jsonl` using the
`fo2remix.bridge-v1` contract. In the normal launch it only observes and reports
parity in the HUD; local WASD and interactions continue to work.

To make `fallout2-ce` authoritative, start Godot first:

```powershell
& "$env:USERPROFILE\Desktop\Gierka\installers\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe" `
  --path godot -- --bridge-live
```

Then start the instrumented engine from the repository root:

```powershell
.\scripts\run-fallout2-ce-bridge.ps1
```

In `--bridge-live` mode Godot disables local movement and applies
`map_loaded`, `player_moved`, and successful `interaction` events from CE to
the one shared player/object state. Camera switching remains local and cannot
change that state.

The deterministic receiver test covers incremental file growth and a JSONL
record split between two reads:

```powershell
& "$env:USERPROFILE\Desktop\Gierka\installers\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" `
  --headless --path godot -- --bridge-probe
```

Run the deterministic interaction parity probe with:

```powershell
& "$env:USERPROFILE\Desktop\Gierka\installers\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" `
  --headless --path godot -- --interaction-probe
```
