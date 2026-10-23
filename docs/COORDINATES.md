# Coordinate contract

The Godot controller uses continuous world position as the movement authority
and deterministically resolves the nearest Fallout logical hex after every
physics step. Cameras observe this one state and never maintain separate player
positions.

## Source grids

- logical hex grid: 200 × 200;
- floor/roof square grid: 100 × 100;
- both grids reverse the stored column: `column = width - 1 - index % width`;
- rows increase with integer division of the stored index;
- elevation is an explicit state value, not inferred from height.

For hex `18492`, this gives column `107`, row `92`, elevation `0`.

## Fallout basis and Godot transform

Pinned `fallout2-ce` commit
`e97087b9582f37075db347a89898887320753f8b` defines the screen-space bases in
`src/tile.cc::tileToScreenXY` and `src/tile.cc::squareTileToScreenXY`.

The renderer retains those bases, normalizes adjacent hexes to one world unit,
and maps the ground to Godot X/Z with +Y up. For hex column `c`, row `r` and
column parity `p = c & 1`:

```text
u = 0.75*c + 0.25*p + 0.5*r
v = -0.5*c + 0.5*p + r

world_x = u - center_u
world_z = (v - center_v) * sqrt(3)/2
world_y = elevation * 3.0
```

For square-floor column `s`, row `t`:

```text
u = 1.5*s + t
v = -s + 2*t
```

This makes square tile `(s, t)` coincide with even logical hex `(2s, 2t)` and
makes all six logical neighbors exactly one world unit apart. The current map
center is square coordinate `(49.5, 49.5)`.

The transform is renderer metadata. It does not replace or mutate the Fallout
hex index used by gameplay state.

## Inverse world-to-hex transform

Given a Godot position, first recover the source basis:

```text
u = world_x + center_u
v = world_z / (sqrt(3)/2) + center_v
```

The continuous column estimate simplifies to:

```text
c = u - 0.5*v
```

For candidate integer column `c` and parity `p = c & 1`:

```text
r = v + 0.5*c - 0.5*p
```

The resolver checks the nearby integer candidates and selects the center with
minimum X/Z distance. Contract tests prove `hex -> world -> hex` for the
Arroyo spawn, all six neighbors and the four logical grid corners.
