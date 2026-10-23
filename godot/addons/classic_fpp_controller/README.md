# Classic FPP Controller

A dependency-free Godot 4 `CharacterBody3D` controller intended for reuse.

Features:

- camera-relative WASD;
- normalized diagonals;
- walk and sprint speeds;
- acceleration and deceleration;
- mouse yaw/pitch with configurable limits;
- capsule collision and optional debug body;
- configurable semantic input action names;
- hooks for game-specific state adapters.

The controller deliberately has no Fallout imports, hex logic, map state,
camera switching or interaction rules. This repository's
`fallout_player_controller.gd` extends it and adds those concerns.

This is currently an internal addon. Split it into a separately versioned
package only after its API is stable and a second project consumes it. A
standalone release also requires an explicit license review.
