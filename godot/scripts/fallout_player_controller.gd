extends "res://addons/classic_fpp_controller/first_person_controller.gd"

signal logical_state_changed(state: Dictionary)

const Coordinates = preload("res://scripts/fallout_coordinate_space.gd")

var logical_state := {
	"map_name": "",
	"hex_index": -1,
	"hex_column": -1,
	"hex_row": -1,
	"elevation": 0,
	"rotation": 0,
	"selection": -1,
}

var initialized := false


func _init() -> void:
	# Fallout's human FRM reference is about 1.75-1.83 m after the shared
	# 36 px/m actor calibration. Keep the camera below the top of that silhouette.
	eye_height = 1.62
	body_height = 1.75


func initialize(map_name: String, spawn: Dictionary) -> void:
	logical_state["map_name"] = map_name
	logical_state["hex_index"] = int(spawn["hex_index"])
	logical_state["hex_column"] = int(spawn["hex_column"])
	logical_state["hex_row"] = int(spawn["hex_row"])
	logical_state["elevation"] = int(spawn["elevation"])
	logical_state["rotation"] = int(spawn["rotation"]) % 6
	global_position = Coordinates.hex_index_to_world(
		int(logical_state["hex_index"]),
		int(logical_state["elevation"])
	)
	set_view_from_rotation(int(logical_state["rotation"]))
	velocity = Vector3.ZERO
	initialized = true
	_emit_logical_state()


func set_view_from_rotation(rotation_index: int) -> void:
	logical_state["rotation"] = posmod(rotation_index, 6)
	var direction := Coordinates.direction_to_world(
		int(logical_state["hex_index"]),
		int(logical_state["rotation"])
	)
	set_view_angles(atan2(-direction.x, -direction.z), 0.0)


func get_state_snapshot() -> Dictionary:
	var snapshot := get_motion_snapshot()
	snapshot["logical"] = logical_state.duplicate(true)
	return snapshot


func set_selection(instance_id: int) -> void:
	if int(logical_state["selection"]) == instance_id:
		return
	logical_state["selection"] = instance_id
	_emit_logical_state()


func apply_bridge_state(map_name: String, state: Dictionary) -> bool:
	var hex_index := int(state.get("hex_index", -1))
	var elevation := int(state.get("elevation", -1))
	var rotation_index := int(state.get("rotation", -1))
	if hex_index < 0 or hex_index >= Coordinates.HEX_GRID_WIDTH * Coordinates.HEX_GRID_HEIGHT:
		return false
	if elevation < 0 or elevation >= 3:
		return false
	if rotation_index < 0 or rotation_index >= 6:
		return false

	if not map_name.is_empty():
		logical_state["map_name"] = map_name
	logical_state["hex_index"] = hex_index
	var grid := Coordinates.tile_index_to_grid(hex_index)
	logical_state["hex_column"] = grid.x
	logical_state["hex_row"] = grid.y
	logical_state["elevation"] = elevation
	logical_state["rotation"] = rotation_index
	global_position = Coordinates.hex_index_to_world(hex_index, elevation)
	velocity = Vector3.ZERO
	var direction := Coordinates.direction_to_world(hex_index, rotation_index)
	view_yaw = atan2(-direction.x, -direction.z)
	rotation.y = view_yaw
	_emit_logical_state()
	motion_state_changed.emit(get_motion_snapshot())
	return true


func _after_motion_step() -> void:
	if initialized:
		_sync_logical_hex()


func _after_view_changed() -> void:
	if not initialized:
		return
	logical_state["rotation"] = Coordinates.rotation_for_yaw(
		int(logical_state["hex_index"]),
		view_yaw
	)
	_emit_logical_state()


func _sync_logical_hex() -> void:
	var resolved_hex := Coordinates.world_to_nearest_hex(global_position)
	if resolved_hex == -1 or resolved_hex == int(logical_state["hex_index"]):
		return
	logical_state["hex_index"] = resolved_hex
	var grid := Coordinates.tile_index_to_grid(resolved_hex)
	logical_state["hex_column"] = grid.x
	logical_state["hex_row"] = grid.y
	logical_state["rotation"] = Coordinates.rotation_for_yaw(resolved_hex, view_yaw)
	_emit_logical_state()


func _emit_logical_state() -> void:
	logical_state_changed.emit(logical_state.duplicate(true))
