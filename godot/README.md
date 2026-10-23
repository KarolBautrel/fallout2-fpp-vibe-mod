# Godot ISO/FPP debug slice

The project reads `../artifacts/artemple.scene-v1.json` at runtime. It does not
contain or download original Fallout 2 assets.

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

Both cameras observe the same `CharacterBody3D`. The FPP camera origin is exactly
the player position plus the explicit `1.68` world-unit eye height and has no
trailing or over-the-shoulder offset.

The reusable movement core comes from the pinned
[`godot-classic-fpp-controller`](https://github.com/KarolBautrel/godot-classic-fpp-controller)
submodule in `addons/classic_fpp_controller`. The project-specific
`scripts/fallout_player_controller.gd` adapter adds logical hex state.
The pinned `v0.2.0` package also provides configurable floor snapping,
walkable slopes and automatic step-up for low stairs.
