# Verification

## Evidence per experiment

Record:

- exact `fallout2-ce` commit;
- game build/store and data path without copying data;
- command and configuration;
- input hex/elevation/object ID;
- exported position and Godot position;
- screenshot or machine-readable assertion;
- result and next decision.

## Acceptance tests

1. Load the selected map without missing required records.
2. Known logical points appear at the expected relative positions.
3. Walls marked blocking prevent traversal in the debug scene.
4. ISO → TPP → ISO keeps player hex, elevation and selection unchanged.
5. A movement command reaches the same target hex in both views.
6. One door/object interaction targets the same object ID in both views.
7. Running without access to the user's Fallout 2 data fails clearly and never downloads substitute assets.

## Oracle strategy

Prefer state comparison over visual resemblance. Where possible, instrument a debug build of `fallout2-ce` to emit map ID, elevation, object IDs, hex positions and movement results. Replay identical commands in the prototype and compare traces.

If a mismatch repeats three times, stop tweaking constants. Trace the source transform and document the unresolved assumption.

