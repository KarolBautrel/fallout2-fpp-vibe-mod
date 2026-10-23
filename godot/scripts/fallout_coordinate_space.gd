extends RefCounted

const HEX_GRID_WIDTH := 200
const HEX_GRID_HEIGHT := 200
const FLOOR_GRID_WIDTH := 100
const FLOOR_GRID_HEIGHT := 100
const SQRT_3_OVER_2 := 0.8660254037844386
const ELEVATION_HEIGHT := 3.0

const FLOOR_CENTER_COLUMN := 49.5
const FLOOR_CENTER_ROW := 49.5
const CENTER_SOURCE_U := 1.5 * FLOOR_CENTER_COLUMN + FLOOR_CENTER_ROW
const CENTER_SOURCE_V := -FLOOR_CENTER_COLUMN + 2.0 * FLOOR_CENTER_ROW

const DIRECTION_OFFSETS := [
	[-1, 199, 200, 201, 1, -200],
	[-201, -1, 200, 1, -199, -200],
]


static func tile_index_to_grid(tile_index: int) -> Vector2i:
	assert(tile_index >= 0 and tile_index < HEX_GRID_WIDTH * HEX_GRID_HEIGHT)
	return Vector2i(
		HEX_GRID_WIDTH - 1 - (tile_index % HEX_GRID_WIDTH),
		tile_index / HEX_GRID_WIDTH
	)


static func grid_to_tile_index(column: int, row: int) -> int:
	assert(column >= 0 and column < HEX_GRID_WIDTH)
	assert(row >= 0 and row < HEX_GRID_HEIGHT)
	return row * HEX_GRID_WIDTH + (HEX_GRID_WIDTH - 1 - column)


static func hex_index_to_world(tile_index: int, elevation: int = 0) -> Vector3:
	var grid := tile_index_to_grid(tile_index)
	return hex_grid_to_world(grid.x, grid.y, elevation)


static func hex_grid_to_world(column: int, row: int, elevation: int = 0) -> Vector3:
	var parity := column & 1
	var source_u := 0.75 * column + 0.25 * parity + 0.5 * row
	var source_v := -0.5 * column + 0.5 * parity + row
	return Vector3(
		source_u - CENTER_SOURCE_U,
		float(elevation) * ELEVATION_HEIGHT,
		(source_v - CENTER_SOURCE_V) * SQRT_3_OVER_2
	)


static func square_grid_to_world(column: int, row: int, elevation: int = 0) -> Vector3:
	var source_u := 1.5 * column + row
	var source_v := -column + 2.0 * row
	return Vector3(
		source_u - CENTER_SOURCE_U,
		float(elevation) * ELEVATION_HEIGHT,
		(source_v - CENTER_SOURCE_V) * SQRT_3_OVER_2
	)


static func world_to_nearest_hex(world_position: Vector3) -> int:
	var source_u := world_position.x + CENTER_SOURCE_U
	var source_v := world_position.z / SQRT_3_OVER_2 + CENTER_SOURCE_V
	var approximate_column := source_u - 0.5 * source_v
	var center_column := int(round(approximate_column))
	var best_tile := -1
	var best_distance_squared := INF

	var first_column := maxi(0, center_column - 2)
	var last_column := mini(HEX_GRID_WIDTH - 1, center_column + 2)
	for column in range(first_column, last_column + 1):
		var parity := column & 1
		var approximate_row := source_v + 0.5 * column - 0.5 * parity
		var center_row := int(round(approximate_row))
		var first_row := maxi(0, center_row - 2)
		var last_row := mini(HEX_GRID_HEIGHT - 1, center_row + 2)
		for row in range(first_row, last_row + 1):
			var tile := grid_to_tile_index(column, row)
			var candidate := hex_grid_to_world(column, row, 0)
			var distance_squared := Vector2(
				candidate.x - world_position.x,
				candidate.z - world_position.z
			).length_squared()
			if distance_squared < best_distance_squared:
				best_distance_squared = distance_squared
				best_tile = tile

	return best_tile


static func tile_in_direction(tile_index: int, rotation: int) -> int:
	var parity := (tile_index % HEX_GRID_WIDTH) & 1
	var candidate := tile_index + int(DIRECTION_OFFSETS[parity][posmod(rotation, 6)])
	if candidate < 0 or candidate >= HEX_GRID_WIDTH * HEX_GRID_HEIGHT:
		return tile_index
	var distance := hex_index_to_world(tile_index).distance_to(hex_index_to_world(candidate))
	if absf(distance - 1.0) > 0.00001:
		return tile_index
	return candidate


static func direction_to_world(tile_index: int, rotation: int) -> Vector3:
	var next_tile := tile_in_direction(tile_index, rotation)
	if next_tile == tile_index:
		return Vector3.FORWARD
	return (hex_index_to_world(next_tile) - hex_index_to_world(tile_index)).normalized()


static func forward_from_yaw(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw)).normalized()


static func right_from_yaw(yaw: float) -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw)).normalized()


static func rotation_for_yaw(tile_index: int, yaw: float) -> int:
	var forward := forward_from_yaw(yaw)
	var best_rotation := 0
	var best_dot := -2.0
	for rotation in 6:
		var candidate := direction_to_world(tile_index, rotation)
		var alignment := forward.dot(candidate)
		if alignment > best_dot:
			best_dot = alignment
			best_rotation = rotation
	return best_rotation
