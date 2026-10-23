extends Node3D

const Coordinates = preload("res://scripts/fallout_coordinate_space.gd")
const PlayerController = preload("res://scripts/fallout_player_controller.gd")
const StateBridge = preload("res://scripts/fallout_state_bridge.gd")

const DEFAULT_MAP_KEY := "artemple"
const SCENE_PATHS := {
	"artemple": "res://../artifacts/artemple.scene-v1.json",
	"arcaves": "res://../artifacts/arcaves.scene-v1.json",
}
const EVIDENCE_PATH := "res://../artifacts/godot-iso-fpp-contract.json"
const MOVEMENT_RUNTIME_EVIDENCE_PATH := "res://../artifacts/godot-movement-runtime.json"
const BLOCKING_RUNTIME_EVIDENCE_PATH := "res://../artifacts/godot-blocking-runtime.json"
const INTERACTION_RUNTIME_EVIDENCE_PATH := "res://../artifacts/godot-interaction-runtime.json"
const BRIDGE_TRACE_PATH := "res://../artifacts/fallout2-ce-state.jsonl"
const BRIDGE_PROBE_TRACE_PATH := "res://../artifacts/godot-bridge-probe-input.jsonl"
const BRIDGE_RUNTIME_EVIDENCE_PATH := "res://../artifacts/godot-bridge-runtime.json"
const BRIDGE_LIVE_EVIDENCE_PATH := "res://../artifacts/godot-bridge-live-runtime.json"
const FALLOUT2_CE_COMMIT := "e97087b9582f37075db347a89898887320753f8b"

const FLOOR_CELL_COUNT := 100 * 100
const FLOOR_THICKNESS := 0.08
const BLOCKING_COLLIDER_HEIGHT := 2.4
const BLOCKING_COLLIDER_RADIUS := 0.42
const INTERACTION_DISTANCE := 1.75
const INTERACTION_RAY_DISTANCE := 2.25
const CAMERA_ISO := "ISO"
const CAMERA_FPP := "FPP"

var scene_data: Dictionary
var active_camera_mode := CAMERA_FPP
var map_geometry_root: Node3D
var floor_instances: MultiMeshInstance3D
var debug_object_counts := {"wall": 0, "door": 0, "scenery": 0}
var blocking_collision_count := 0
var object_records_by_instance_id := {}
var object_states := {}
var object_visuals := {}
var object_instance_colors := {}
var object_collision_shapes := {}
var interaction_status := "No object selected"
var player
var iso_camera: Camera3D
var fpp_camera: Camera3D
var state_label: Label
var crosshair: Label
var hud_refresh_timer := 0.0
var state_bridge
var bridge_authoritative := false
var bridge_transport_status := "OFF"
var bridge_parity_status := "No CE state received"
var bridge_events_observed := 0
var bridge_events_applied := 0
var bridge_map_supported := true
var bridge_map_name := ""
var loaded_scene_path := ""
var last_bridge_interaction := {}
var last_bridge_object_state := {}


func _ready() -> void:
	_load_scene_data()
	if scene_data.is_empty():
		return

	_create_environment()
	_create_map_geometry_root()
	_create_floor_grid()
	_create_ground_collision()
	_create_map_object_debug_geometry()
	_create_map_blocking_collisions()
	_create_player()
	_create_cameras()
	_create_hud()
	_register_input_actions()
	_create_state_bridge()
	_update_cameras()
	_run_contract_checks()
	_set_camera_mode(_requested_start_camera())
	_write_evidence()
	if _has_user_argument("--bridge-probe"):
		_run_bridge_probe()
	elif _has_user_argument("--interaction-probe"):
		_run_interaction_probe()
	elif _has_user_argument("--blocking-probe"):
		_run_blocking_collision_probe()
	elif _has_user_argument("--movement-probe"):
		_run_runtime_movement_probe()


func _process(delta: float) -> void:
	if player == null:
		return
	_update_cameras()
	hud_refresh_timer -= delta
	if hud_refresh_timer <= 0.0:
		hud_refresh_timer = 0.25
		_update_hud()


func _load_scene_data() -> void:
	if not _load_scene_data_from_path(_requested_scene_path()):
		get_tree().quit(2)


func _load_scene_data_from_path(path: String) -> bool:
	var absolute_path := ProjectSettings.globalize_path(path)
	var file := FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		push_error("Missing scene JSON: %s" % absolute_path)
		return false

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or parsed.get("schema", "") != "fo2remix.scene-v1":
		push_error("Unsupported or invalid scene JSON: %s" % absolute_path)
		return false
	scene_data = parsed
	loaded_scene_path = path
	return true


func _create_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("071018")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b7c9d6")
	environment.ambient_light_energy = 0.7
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "DebugSun"
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)


func _create_map_geometry_root() -> void:
	map_geometry_root = Node3D.new()
	map_geometry_root.name = "ActiveMapGeometry"
	add_child(map_geometry_root)


func _create_floor_grid() -> void:
	var tile_grid: Dictionary = scene_data["tile_grid"]
	assert(int(tile_grid["width"]) == Coordinates.FLOOR_GRID_WIDTH)
	assert(int(tile_grid["height"]) == Coordinates.FLOOR_GRID_HEIGHT)
	var layers: Array = tile_grid["layers"]
	assert(not layers.is_empty())
	var rendered_cell_count := 0
	for layer_value in layers:
		var layer: Dictionary = layer_value
		var floor_ids: Array = layer["floor_ids"]
		assert(floor_ids.size() == FLOOR_CELL_COUNT)
		for floor_id in floor_ids:
			if int(floor_id) != 1:
				rendered_cell_count += 1
	assert(rendered_cell_count > 0)

	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var cell_mesh := BoxMesh.new()
	cell_mesh.size = Vector3.ONE
	cell_mesh.material = material

	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.use_colors = true
	multi_mesh.mesh = cell_mesh
	multi_mesh.instance_count = rendered_cell_count

	var column_axis := Vector3(1.5, 0.0, -Coordinates.SQRT_3_OVER_2) * 0.992
	var row_axis := Vector3(1.0, 0.0, 2.0 * Coordinates.SQRT_3_OVER_2) * 0.992
	var cell_basis := Basis(column_axis, Vector3(0.0, FLOOR_THICKNESS, 0.0), row_axis)

	var instance_index := 0
	for layer_value in layers:
		var layer: Dictionary = layer_value
		var floor_ids: Array = layer["floor_ids"]
		for tile_index in FLOOR_CELL_COUNT:
			var floor_id := int(floor_ids[tile_index])
			if floor_id == 1:
				continue
			var column := Coordinates.FLOOR_GRID_WIDTH - 1 - (
				tile_index % Coordinates.FLOOR_GRID_WIDTH
			)
			var row := int(tile_index / Coordinates.FLOOR_GRID_WIDTH)
			var origin := Coordinates.square_grid_to_world(
				column,
				row,
				int(layer["elevation"])
			)
			origin.y -= FLOOR_THICKNESS * 0.5
			multi_mesh.set_instance_transform(instance_index, Transform3D(cell_basis, origin))
			multi_mesh.set_instance_color(instance_index, _debug_floor_color(floor_id))
			instance_index += 1

	floor_instances = MultiMeshInstance3D.new()
	floor_instances.name = "FloorGrid100x100"
	floor_instances.multimesh = multi_mesh
	map_geometry_root.add_child(floor_instances)


func _create_ground_collision() -> void:
	var ground := StaticBody3D.new()
	ground.name = "DebugGroundCollision"
	for layer_value in scene_data["tile_grid"]["layers"]:
		var layer: Dictionary = layer_value
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(600.0, 0.2, 600.0)
		collision.shape = shape
		collision.position.y = (
			float(layer["elevation"]) * Coordinates.ELEVATION_HEIGHT - 0.1
		)
		ground.add_child(collision)
	map_geometry_root.add_child(ground)


func _create_map_object_debug_geometry() -> void:
	var object_section: Dictionary = scene_data.get("objects", {})
	var records: Array = object_section.get("records", [])
	var walls: Array[Dictionary] = []
	var doors: Array[Dictionary] = []
	var scenery: Array[Dictionary] = []
	for value in records:
		var record: Dictionary = value
		var instance_id := int(record["instance_id"])
		object_records_by_instance_id[instance_id] = record
		if _is_interactable_record(record):
			var state := {"activated": false}
			if String(record.get("kind", "")) == "door":
				var door: Dictionary = record.get("door", {})
				state["open"] = bool(door.get("open", false))
				state["locked"] = bool(door.get("locked", false))
				state["jammed"] = bool(door.get("jammed", false))
				state["blocks_movement"] = not bool(state["open"])
			object_states[instance_id] = state
		match String(record.get("kind", "")):
			"wall":
				walls.append(record)
			"door":
				doors.append(record)
			"scenery":
				scenery.append(record)

	debug_object_counts["wall"] = walls.size()
	debug_object_counts["door"] = doors.size()
	debug_object_counts["scenery"] = scenery.size()
	_create_object_instances("DebugWalls", walls, Vector3(0.9, 2.2, 0.14), Color("6d8ca8"))
	_create_object_instances("DebugDoors", doors, Vector3(0.9, 2.1, 0.18), Color("d18152"))
	_create_object_instances(
		"DebugScenery",
		scenery,
		Vector3(0.48, 1.1, 0.48),
		Color("638a68")
	)


func _create_object_instances(
	node_name: String,
	records: Array[Dictionary],
	size: Vector3,
	color: Color
) -> void:
	if records.is_empty():
		return
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = material

	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.use_colors = true
	multi_mesh.mesh = mesh
	multi_mesh.instance_count = records.size()
	for index in records.size():
		var record := records[index]
		var instance_id := int(record["instance_id"])
		var tile := int(record["hex_index"])
		var elevation := int(record["elevation"])
		var rotation := int(record["rotation"])
		var direction := Coordinates.direction_to_world(tile, rotation)
		var yaw := atan2(-direction.x, -direction.z)
		var basis := Basis(Vector3.UP, yaw).scaled(size)
		var position := Coordinates.hex_index_to_world(tile, elevation)
		position.y += size.y * 0.5
		var base_transform := Transform3D(basis, position)
		multi_mesh.set_instance_transform(index, base_transform)
		multi_mesh.set_instance_color(index, color)
		object_visuals[instance_id] = {
			"multi_mesh": multi_mesh,
			"index": index,
			"base_transform": base_transform,
		}
		object_instance_colors[instance_id] = color

	var instances := MultiMeshInstance3D.new()
	instances.name = node_name
	instances.multimesh = multi_mesh
	map_geometry_root.add_child(instances)


func _create_map_blocking_collisions() -> void:
	var collision_section: Dictionary = scene_data.get("collision", {})
	var records: Array = collision_section.get("blocking_hexes", [])
	var body := StaticBody3D.new()
	body.name = "FalloutBlockingHexes"
	var shared_shape := CylinderShape3D.new()
	shared_shape.radius = BLOCKING_COLLIDER_RADIUS
	shared_shape.height = BLOCKING_COLLIDER_HEIGHT
	for value in records:
		var record: Dictionary = value
		var collision := CollisionShape3D.new()
		collision.shape = shared_shape
		collision.position = Coordinates.hex_index_to_world(
			int(record["hex_index"]),
			int(record["elevation"])
		)
		collision.position.y += BLOCKING_COLLIDER_HEIGHT * 0.5
		collision.set_meta("instance_ids", record.get("instance_ids", []))
		collision.set_meta("object_ids", record.get("object_ids", []))
		collision.set_meta("hex_index", int(record["hex_index"]))
		collision.set_meta("elevation", int(record["elevation"]))
		body.add_child(collision)
		for instance_id_value in record.get("instance_ids", []):
			var instance_id := int(instance_id_value)
			if not object_collision_shapes.has(instance_id):
				object_collision_shapes[instance_id] = []
			object_collision_shapes[instance_id].append(collision)
	map_geometry_root.add_child(body)
	blocking_collision_count = records.size()
	for instance_id in object_collision_shapes:
		_refresh_object_collisions(int(instance_id))


func _debug_floor_color(floor_id: int) -> Color:
	if floor_id == 0:
		return Color("20282a")
	var hue := fmod(0.24 + float(floor_id % 17) * 0.006, 1.0)
	var value := 0.31 + float(floor_id % 5) * 0.025
	return Color.from_hsv(hue, 0.18, value, 1.0)


func _count_rendered_floor_cells() -> int:
	var count := 0
	for layer_value in scene_data["tile_grid"]["layers"]:
		var layer: Dictionary = layer_value
		for floor_id in layer["floor_ids"]:
			if int(floor_id) != 1:
				count += 1
	return count


func _create_player() -> void:
	player = PlayerController.new()
	player.name = "AuthoritativePlayer"
	add_child(player)
	player.logical_state_changed.connect(_on_player_state_changed)
	player.initialize(scene_data["map"]["name"], scene_data["spawn"])


func _create_cameras() -> void:
	iso_camera = Camera3D.new()
	iso_camera.name = "IsoCamera"
	iso_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	iso_camera.size = 26.0
	iso_camera.near = 0.1
	iso_camera.far = 500.0
	add_child(iso_camera)

	fpp_camera = Camera3D.new()
	fpp_camera.name = "FppEyeCamera"
	fpp_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	fpp_camera.fov = 75.0
	fpp_camera.near = 0.05
	fpp_camera.far = 500.0
	add_child(fpp_camera)


func _create_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "DebugHud"
	add_child(canvas)

	var panel := ColorRect.new()
	panel.position = Vector2(16.0, 16.0)
	panel.size = Vector2(1100.0, 188.0)
	panel.color = Color(0.02, 0.03, 0.04, 0.82)
	canvas.add_child(panel)

	state_label = Label.new()
	state_label.position = Vector2(28.0, 26.0)
	state_label.add_theme_font_size_override("font_size", 18)
	state_label.add_theme_color_override("font_color", Color("d8edf5"))
	canvas.add_child(state_label)

	crosshair = Label.new()
	crosshair.text = "+"
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-12.0, -16.0)
	crosshair.size = Vector2(24.0, 32.0)
	crosshair.add_theme_font_size_override("font_size", 24)
	crosshair.add_theme_color_override("font_color", Color("ffd447"))
	canvas.add_child(crosshair)


func _register_input_actions() -> void:
	_register_key("toggle_camera", KEY_TAB)
	_register_key("move_forward", KEY_W)
	_register_key("move_backward", KEY_S)
	_register_key("move_left", KEY_A)
	_register_key("move_right", KEY_D)
	_register_key("sprint", KEY_SHIFT)
	_register_key("interact", KEY_E)


func _register_key(action: StringName, physical_keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)


func _unhandled_input(event: InputEvent) -> void:
	if bridge_authoritative:
		if event.is_action_pressed("toggle_camera"):
			_toggle_camera()
		elif event.is_action_pressed("ui_cancel") and active_camera_mode == CAMERA_FPP:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if event.is_action_pressed("toggle_camera"):
		_toggle_camera()
	elif event.is_action_pressed("interact"):
		_interact_from_active_camera()
	elif event.is_action_pressed("ui_cancel") and active_camera_mode == CAMERA_FPP:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and active_camera_mode == CAMERA_ISO
	):
		_select_iso_target(event.position)
	elif event is InputEventMouseButton and event.pressed and active_camera_mode == CAMERA_FPP:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif (
		event is InputEventMouseMotion
		and active_camera_mode == CAMERA_FPP
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	):
		player.add_mouse_look(event.relative)
		_update_cameras()
		_update_hud()


func _toggle_camera() -> void:
	var state_before: Dictionary = player.get_state_snapshot()
	_set_camera_mode(CAMERA_FPP if active_camera_mode == CAMERA_ISO else CAMERA_ISO)
	assert(
		player.get_state_snapshot() == state_before,
		"Camera switching changed authoritative player state"
	)


func _set_camera_mode(mode: String) -> void:
	active_camera_mode = mode
	iso_camera.current = mode == CAMERA_ISO
	fpp_camera.current = mode == CAMERA_FPP
	player.set_first_person(mode == CAMERA_FPP)
	crosshair.visible = mode == CAMERA_FPP
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = (
			Input.MOUSE_MODE_CAPTURED
			if mode == CAMERA_FPP and not bridge_authoritative
			else Input.MOUSE_MODE_VISIBLE
		)
	_update_hud()


func _update_cameras() -> void:
	if player == null or iso_camera == null or fpp_camera == null:
		return
	var player_position: Vector3 = player.global_position
	iso_camera.global_position = player_position + Vector3(14.0, 18.0, 14.0)
	iso_camera.look_at(player_position, Vector3.UP)
	fpp_camera.global_position = player.get_eye_position()
	fpp_camera.global_rotation = Vector3(player.view_pitch, player.view_yaw, 0.0)


func _on_player_state_changed(_state: Dictionary) -> void:
	_update_hud()


func _create_state_bridge() -> void:
	state_bridge = StateBridge.new()
	state_bridge.name = "Fallout2CeStateBridge"
	add_child(state_bridge)
	state_bridge.event_received.connect(_on_bridge_event)
	state_bridge.status_changed.connect(_on_bridge_status_changed)
	state_bridge.bridge_error.connect(_on_bridge_error)
	bridge_authoritative = (
		_has_user_argument("--bridge-live") or _has_user_argument("--bridge-probe")
	)
	player.movement_enabled = not bridge_authoritative
	var path := BRIDGE_PROBE_TRACE_PATH if _has_user_argument("--bridge-probe") else BRIDGE_TRACE_PATH
	state_bridge.configure(path, bridge_authoritative)
	bridge_transport_status = state_bridge.status


func _on_bridge_status_changed(value: String) -> void:
	bridge_transport_status = value
	_update_hud()


func _on_bridge_error(message: String) -> void:
	bridge_parity_status = message
	_update_hud()


func _on_bridge_event(event: Dictionary) -> void:
	bridge_events_observed += 1
	var event_name := String(event["event"])
	match event_name:
		"session_started":
			bridge_parity_status = "CE session connected"
		"map_loaded":
			_handle_bridge_map_loaded(event)
		"player_moved":
			_handle_bridge_player_moved(event)
		"interaction":
			_handle_bridge_interaction(event)
		"object_state":
			_handle_bridge_object_state(event)
		_:
			bridge_parity_status = "Ignored CE event: %s" % event_name
	_update_cameras()
	_update_hud()
	if bridge_authoritative and not _has_user_argument("--bridge-probe"):
		_write_bridge_live_evidence(event)


func _handle_bridge_map_loaded(event: Dictionary) -> void:
	if not event.get("map", {}) is Dictionary or not event.get("player", {}) is Dictionary:
		bridge_parity_status = "Invalid map_loaded payload"
		return
	var map_state: Dictionary = event["map"]
	var player_state: Dictionary = event["player"]
	bridge_map_name = String(map_state.get("name", ""))
	bridge_map_supported = _activate_scene_for_bridge_map(map_state)
	if not bridge_map_supported:
		var expected_map: Dictionary = scene_data["map"]
		player.set_selection(-1)
		interaction_status = "CE is on unsupported map %s; loaded scene is %s" % [
			bridge_map_name,
			expected_map["name"],
		]
		bridge_parity_status = "UNSUPPORTED MAP: %s (index %s)" % [
			bridge_map_name,
			map_state.get("index", -1),
		]
		return
	_apply_or_compare_bridge_player(String(map_state["name"]), player_state, "map_loaded")


func _activate_scene_for_bridge_map(map_state: Dictionary) -> bool:
	var map_key := _map_stem(String(map_state.get("name", "")))
	if not SCENE_PATHS.has(map_key):
		return false

	var expected_index := int(map_state.get("index", -1))
	var current_map: Dictionary = scene_data["map"]
	if (
		_map_stem(String(current_map["name"])) == map_key
		and int(current_map["index"]) == expected_index
	):
		return true

	var next_path := String(SCENE_PATHS[map_key])
	if not _load_scene_data_from_path(next_path):
		return false
	if int(scene_data["map"]["index"]) != expected_index:
		return false

	_rebuild_map_geometry()
	interaction_status = "Loaded %s from CE map boundary" % scene_data["map"]["name"]
	return true


func _rebuild_map_geometry() -> void:
	player.set_selection(-1)
	for child in map_geometry_root.get_children():
		child.free()
	object_records_by_instance_id.clear()
	object_states.clear()
	object_visuals.clear()
	object_instance_colors.clear()
	object_collision_shapes.clear()
	debug_object_counts = {"wall": 0, "door": 0, "scenery": 0}
	blocking_collision_count = 0
	floor_instances = null
	_create_floor_grid()
	_create_ground_collision()
	_create_map_object_debug_geometry()
	_create_map_blocking_collisions()


func _handle_bridge_player_moved(event: Dictionary) -> void:
	if not event.get("player", {}) is Dictionary:
		bridge_parity_status = "Invalid player_moved payload"
		return
	if not bridge_map_supported:
		bridge_parity_status = "IGNORED player_moved on unsupported map %s" % bridge_map_name
		return
	_apply_or_compare_bridge_player("", event["player"], "player_moved")


func _apply_or_compare_bridge_player(
	map_name: String,
	player_state: Dictionary,
	event_name: String
) -> void:
	if bridge_authoritative:
		if not player.apply_bridge_state(map_name, player_state):
			bridge_parity_status = "Invalid CE player state"
			return
		bridge_events_applied += 1
		bridge_parity_status = "APPLIED %s hex %d" % [
			event_name,
			int(player_state["hex_index"]),
		]
		return

	var local_state: Dictionary = player.logical_state
	var matches := (
		int(local_state["hex_index"]) == int(player_state.get("hex_index", -1))
		and int(local_state["elevation"]) == int(player_state.get("elevation", -1))
		and int(local_state["rotation"]) == int(player_state.get("rotation", -1))
	)
	bridge_parity_status = (
		"MATCH %s hex %d" % [event_name, int(player_state.get("hex_index", -1))]
		if matches
		else "OBSERVED CE hex %d / Godot hex %d" % [
			int(player_state.get("hex_index", -1)),
			int(local_state["hex_index"]),
		]
	)


func _handle_bridge_interaction(event: Dictionary) -> void:
	if not event.get("target", {}) is Dictionary:
		bridge_parity_status = "Invalid interaction payload"
		return
	if not bridge_map_supported:
		bridge_parity_status = "IGNORED interaction on unsupported map %s" % bridge_map_name
		interaction_status = "Interaction belongs to %s, not loaded scene %s" % [
			bridge_map_name,
			scene_data["map"]["name"],
		]
		return
	var target: Dictionary = event["target"]
	var instance_id := int(target.get("instance_id", -1))
	if not object_records_by_instance_id.has(instance_id):
		last_bridge_interaction = {
			"sequence": int(event["sequence"]),
			"map_name": bridge_map_name,
			"target": target.duplicate(true),
			"result": int(event.get("result", -1)),
			"identity_matches": false,
			"activated": false,
		}
		bridge_parity_status = "UNKNOWN CE instance %d" % instance_id
		return
	var record: Dictionary = object_records_by_instance_id[instance_id]
	var identity_matches := (
		int(record["object_id"]) == int(target.get("object_id", -1))
		and int(record["pid"]) == int(target.get("pid", -1))
		and int(record["hex_index"]) == int(target.get("hex_index", -1))
		and int(record["elevation"]) == int(target.get("elevation", -1))
	)
	if not identity_matches:
		last_bridge_interaction = {
			"sequence": int(event["sequence"]),
			"map_name": bridge_map_name,
			"target": target.duplicate(true),
			"result": int(event.get("result", -1)),
			"identity_matches": false,
			"activated": false,
		}
		bridge_parity_status = "INTERACTION IDENTITY MISMATCH instance %d" % instance_id
		return

	var result := int(event.get("result", -1))
	bridge_parity_status = "MATCH interaction instance %d result %d" % [instance_id, result]
	if bridge_authoritative and result == 0 and object_states.has(instance_id):
		object_states[instance_id]["activated"] = true
		player.set_selection(instance_id)
		interaction_status = "CE activated instance %d / Fallout object %d" % [
			instance_id,
			int(record["object_id"]),
		]
		bridge_events_applied += 1
		_refresh_object_colors()
	last_bridge_interaction = {
		"sequence": int(event["sequence"]),
		"map_name": bridge_map_name,
		"target": target.duplicate(true),
		"result": result,
		"identity_matches": true,
		"activated": bool(object_states.get(instance_id, {}).get("activated", false)),
	}


func _handle_bridge_object_state(event: Dictionary) -> void:
	if (
		not event.get("target", {}) is Dictionary
		or not event.get("state", {}) is Dictionary
	):
		bridge_parity_status = "Invalid object_state payload"
		return
	if not bridge_map_supported:
		bridge_parity_status = "IGNORED object_state on unsupported map %s" % bridge_map_name
		return

	var target: Dictionary = event["target"]
	var state: Dictionary = event["state"]
	var instance_id := int(target.get("instance_id", -1))
	if not object_records_by_instance_id.has(instance_id):
		bridge_parity_status = "UNKNOWN CE object_state instance %d" % instance_id
		return
	var record: Dictionary = object_records_by_instance_id[instance_id]
	var identity_matches := (
		int(record["object_id"]) == int(target.get("object_id", -1))
		and int(record["pid"]) == int(target.get("pid", -1))
		and int(record["hex_index"]) == int(target.get("hex_index", -1))
		and int(record["elevation"]) == int(target.get("elevation", -1))
	)
	if not identity_matches or String(record.get("kind", "")) != String(state.get("kind", "")):
		bridge_parity_status = "OBJECT STATE IDENTITY MISMATCH instance %d" % instance_id
		return

	if not object_states.has(instance_id):
		object_states[instance_id] = {"activated": false}
	var local_state: Dictionary = object_states[instance_id]
	local_state["activated"] = true
	local_state["open"] = bool(state.get("open", false))
	local_state["locked"] = bool(state.get("locked", false))
	local_state["jammed"] = bool(state.get("jammed", false))
	local_state["blocks_movement"] = bool(state.get("blocks_movement", true))
	player.set_selection(instance_id)
	_refresh_object_colors()
	_refresh_object_collisions(instance_id)
	bridge_events_applied += 1
	bridge_parity_status = "APPLIED door %d %s" % [
		instance_id,
		"OPEN" if bool(local_state["open"]) else "CLOSED",
	]
	interaction_status = "CE door instance %d: %s%s%s" % [
		instance_id,
		"OPEN" if bool(local_state["open"]) else "CLOSED",
		" LOCKED" if bool(local_state["locked"]) else "",
		" JAMMED" if bool(local_state["jammed"]) else "",
	]
	last_bridge_object_state = {
		"sequence": int(event["sequence"]),
		"map_name": bridge_map_name,
		"target": target.duplicate(true),
		"state": local_state.duplicate(true),
		"identity_matches": true,
	}


func _write_bridge_live_evidence(event: Dictionary) -> void:
	var target: Dictionary = event.get("target", {})
	var target_instance_id := int(target.get("instance_id", -1))
	var target_activated := false
	if object_states.has(target_instance_id):
		target_activated = bool(object_states[target_instance_id]["activated"])
	var evidence := {
		"schema": "fo2remix.godot-bridge-live-v1",
		"fallout2_ce_commit": FALLOUT2_CE_COMMIT,
		"bridge_schema": state_bridge.SCHEMA,
		"last_sequence": int(event["sequence"]),
		"last_event": String(event["event"]),
		"events_observed": bridge_events_observed,
		"events_applied": bridge_events_applied,
		"bridge_status": bridge_transport_status,
		"parity_status": bridge_parity_status,
		"player_state": player.logical_state.duplicate(true),
		"player_world": _vector_to_array(player.global_position),
		"active_camera": active_camera_mode,
		"local_movement_disabled": not player.movement_enabled,
		"loaded_scene": scene_data["map"].duplicate(true),
		"loaded_scene_path": loaded_scene_path,
		"bridge_map_name": bridge_map_name,
		"bridge_map_supported": bridge_map_supported,
		"last_interaction": last_bridge_interaction.duplicate(true),
		"last_object_state": last_bridge_object_state.duplicate(true),
		"target_instance_id": target_instance_id,
		"target_object_id": int(target.get("object_id", -1)),
		"target_result": int(event.get("result", -1)),
		"target_activated": target_activated,
	}
	var path := ProjectSettings.globalize_path(BRIDGE_LIVE_EVIDENCE_PATH)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write live bridge evidence: %s" % path)
		return
	file.store_string(JSON.stringify(evidence, "  "))
	file.close()


func _interact_from_active_camera() -> void:
	var instance_id := -1
	if active_camera_mode == CAMERA_FPP:
		instance_id = _resolve_fpp_target()
	else:
		instance_id = int(player.logical_state["selection"])
	if instance_id == -1:
		interaction_status = "No interactable object in range"
		_update_hud()
		return
	_interact_with_object(instance_id)


func _select_iso_target(screen_position: Vector2) -> void:
	var instance_id := _resolve_target_from_camera_screen(iso_camera, screen_position, 500.0)
	player.set_selection(instance_id)
	if instance_id == -1:
		interaction_status = "No object selected"
	else:
		interaction_status = "Selected instance %d; press E nearby" % instance_id
	_refresh_object_colors()
	_update_hud()


func _resolve_fpp_target() -> int:
	var center := get_viewport().get_visible_rect().size * 0.5
	return _resolve_target_from_camera_screen(
		fpp_camera,
		center,
		INTERACTION_RAY_DISTANCE
	)


func _resolve_target_from_camera_screen(
	camera: Camera3D,
	screen_position: Vector2,
	max_distance: float
) -> int:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position).normalized()
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * max_distance
	)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if _has_user_argument("--interaction-probe"):
		print("FO2REMIX_INTERACTION_RAY origin=%s direction=%s hit=%s" % [
			origin,
			direction,
			hit,
		])
	if hit.is_empty():
		return -1
	var collider: CollisionObject3D = hit.get("collider")
	if collider == null:
		return -1
	var shape_index := int(hit.get("shape", -1))
	if shape_index < 0:
		return -1
	var owner_id := collider.shape_find_owner(shape_index)
	var owner := collider.shape_owner_get_owner(owner_id)
	if owner == null or not owner.has_meta("instance_ids"):
		return -1
	return _first_interactable_instance_id(owner.get_meta("instance_ids"))


func _first_interactable_instance_id(instance_ids: Variant) -> int:
	if not instance_ids is Array:
		return -1
	for value in instance_ids:
		var instance_id := int(value)
		if object_states.has(instance_id):
			return instance_id
	return -1


func _is_interactable_record(record: Dictionary) -> bool:
	return String(record.get("kind", "")) in ["door", "scenery"]


func _interact_with_object(instance_id: int) -> bool:
	if not object_states.has(instance_id) or not object_records_by_instance_id.has(instance_id):
		interaction_status = "Instance %d is not interactable" % instance_id
		return false
	var record: Dictionary = object_records_by_instance_id[instance_id]
	if int(record["elevation"]) != int(player.logical_state["elevation"]):
		interaction_status = "Instance %d is on another elevation" % instance_id
		return false
	var object_world := Coordinates.hex_index_to_world(
		int(record["hex_index"]),
		int(record["elevation"])
	)
	var horizontal_distance := Vector2(
		object_world.x - player.global_position.x,
		object_world.z - player.global_position.z
	).length()
	if horizontal_distance > INTERACTION_DISTANCE:
		interaction_status = "Instance %d is too far away (%.2f)" % [
			instance_id,
			horizontal_distance,
		]
		return false
	object_states[instance_id]["activated"] = true
	player.set_selection(instance_id)
	interaction_status = "Activated instance %d / Fallout object %d from %s" % [
		instance_id,
		int(record["object_id"]),
		active_camera_mode,
	]
	_refresh_object_colors()
	_update_hud()
	return true


func _refresh_object_colors() -> void:
	var selected_id := int(player.logical_state["selection"])
	for instance_id in object_visuals:
		var visual: Dictionary = object_visuals[instance_id]
		var color: Color = object_instance_colors[instance_id]
		var transform: Transform3D = visual["base_transform"]
		if (
			object_states.has(instance_id)
			and bool(object_states[instance_id].get("open", false))
		):
			color = Color("56c271")
			transform.basis = transform.basis.rotated(Vector3.UP, deg_to_rad(82.0))
		elif object_states.has(instance_id) and bool(object_states[instance_id]["activated"]):
			color = Color("f4d35e")
		elif int(instance_id) == selected_id:
			color = Color("5ee7f4")
		var multi_mesh: MultiMesh = visual["multi_mesh"]
		multi_mesh.set_instance_transform(int(visual["index"]), transform)
		multi_mesh.set_instance_color(int(visual["index"]), color)


func _refresh_object_collisions(instance_id: int) -> void:
	for collision_value in object_collision_shapes.get(instance_id, []):
		var collision: CollisionShape3D = collision_value
		var should_block := false
		for blocker_id_value in collision.get_meta("instance_ids", []):
			var blocker_id := int(blocker_id_value)
			if object_states.has(blocker_id):
				if bool(object_states[blocker_id].get("blocks_movement", true)):
					should_block = true
					break
			elif object_records_by_instance_id.has(blocker_id):
				should_block = bool(
					object_records_by_instance_id[blocker_id].get("blocks_movement", true)
				)
				if should_block:
					break
		collision.disabled = not should_block


func _update_hud() -> void:
	if state_label == null or player == null:
		return
	var state: Dictionary = player.logical_state
	var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
	state_label.text = (
		"%s  |  %s  |  %d FPS  |  speed %.2f\n"
		+ "hex %d  grid (%d, %d)  elevation %d  direction %d\n"
		+ "walls %d  doors %d  scenery %d  blocking hexes %d  selected instance %d\n"
		+ "bridge %s  authority %s  events %d/%d  %s\n"
		+ "%s\n"
		+ "%s   TAB: ISO/FPP"
	) % [
		state["map_name"],
		active_camera_mode,
		Engine.get_frames_per_second(),
		horizontal_speed,
		state["hex_index"],
		state["hex_column"],
		state["hex_row"],
		state["elevation"],
		state["rotation"],
		debug_object_counts["wall"],
		debug_object_counts["door"],
		debug_object_counts["scenery"],
		blocking_collision_count,
		state["selection"],
		bridge_transport_status,
		"CE" if bridge_authoritative else "GODOT",
		bridge_events_observed,
		bridge_events_applied,
		bridge_parity_status,
		interaction_status,
		(
			"Mouse FREE (CE authority; drag title bar to move window)"
			if bridge_authoritative
			else "Mouse %s   ESC: release   click view: capture" % (
				"LOOK" if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else "FREE"
			)
		),
	]


func _run_contract_checks() -> void:
	assert(floor_instances.multimesh.instance_count == _count_rendered_floor_cells())
	assert(floor_instances.multimesh.instance_count >= 2)
	var object_section: Dictionary = scene_data["objects"]
	var object_records: Array = object_section["records"]
	assert(object_records.size() == int(object_section["exported_count"]))
	assert(int(object_section["wall_count"]) >= 2)
	assert(debug_object_counts["wall"] == int(object_section["wall_count"]))
	assert(debug_object_counts["door"] == int(object_section["door_count"]))
	assert(debug_object_counts["scenery"] == int(object_section["scenery_count"]))
	var blocking_records: Array = scene_data["collision"]["blocking_hexes"]
	assert(blocking_collision_count == blocking_records.size())
	assert(blocking_collision_count >= 2)
	for index in mini(2, object_records.size()):
		var record: Dictionary = object_records[index]
		var expected_world := Coordinates.hex_index_to_world(
			int(record["hex_index"]),
			int(record["elevation"])
		)
		var exported_world: Array = record["world"]
		var actual_world := Vector3(
			float(exported_world[0]),
			float(exported_world[1]),
			float(exported_world[2])
		)
		assert(expected_world.distance_to(actual_world) < 0.00001)
	var spawn: Dictionary = scene_data["spawn"]
	var spawn_hex := int(spawn["hex_index"])
	assert(Coordinates.tile_index_to_grid(spawn_hex) == Vector2i(
		int(spawn["hex_column"]),
		int(spawn["hex_row"])
	))
	assert(int(player.logical_state["hex_index"]) == spawn_hex)

	var spawn_world := Coordinates.hex_index_to_world(spawn_hex, int(spawn["elevation"]))
	assert(player.global_position.distance_to(spawn_world) < 0.00001)

	var round_trip_tiles := [spawn_hex, 0, 199, 39800, 39999]
	for rotation in 6:
		var neighbor := Coordinates.tile_in_direction(spawn_hex, rotation)
		round_trip_tiles.append(neighbor)
		var distance := spawn_world.distance_to(Coordinates.hex_index_to_world(neighbor))
		assert(absf(distance - 1.0) < 0.00001, "Hex neighbor distance mismatch")

	for tile in round_trip_tiles:
		var world := Coordinates.hex_index_to_world(tile)
		assert(
			Coordinates.world_to_nearest_hex(world) == tile,
			"hex -> world -> hex round trip failed for %d" % tile
		)

	var state_before: Dictionary = player.get_state_snapshot()
	_set_camera_mode(CAMERA_FPP)
	assert(player.get_state_snapshot() == state_before)
	var expected_eye: Vector3 = player.global_position + Vector3.UP * player.eye_height
	assert(fpp_camera.global_position.distance_to(expected_eye) < 0.00001)
	assert(Vector2(fpp_camera.global_position.x, fpp_camera.global_position.z).distance_to(
		Vector2(player.global_position.x, player.global_position.z)
	) < 0.00001)
	_set_camera_mode(CAMERA_ISO)
	assert(object_states.size() >= 2)
	assert(int(player.logical_state["selection"]) == -1)
	assert(player.get_state_snapshot() == state_before)

	var cardinal_inputs := [
		Vector2(0.0, -1.0),
		Vector2(0.0, 1.0),
		Vector2(-1.0, 0.0),
		Vector2(1.0, 0.0),
	]
	for input_vector in cardinal_inputs:
		var target_velocity: Vector3 = player.get_target_horizontal_velocity(input_vector, false)
		assert(absf(target_velocity.length() - player.walk_speed) < 0.00001)

	var diagonal_velocity: Vector3 = player.get_target_horizontal_velocity(
		Vector2(1.0, -1.0),
		false
	)
	assert(absf(diagonal_velocity.length() - player.walk_speed) < 0.00001)

	var yaw_before: float = player.view_yaw
	var strafe_velocity: Vector3 = player.get_target_horizontal_velocity(
		Vector2(1.0, 0.0),
		false
	)
	assert(absf(player.view_yaw - yaw_before) < 0.00001)
	assert(absf(strafe_velocity.length() - player.walk_speed) < 0.00001)

	_set_camera_mode(CAMERA_ISO)
	var iso_velocity: Vector3 = player.get_target_horizontal_velocity(Vector2(0.0, -1.0), false)
	var iso_target_hex := Coordinates.world_to_nearest_hex(
		spawn_world + iso_velocity * 0.5
	)
	_set_camera_mode(CAMERA_FPP)
	var fpp_velocity: Vector3 = player.get_target_horizontal_velocity(Vector2(0.0, -1.0), false)
	var fpp_target_hex := Coordinates.world_to_nearest_hex(
		spawn_world + fpp_velocity * 0.5
	)
	assert(iso_velocity.distance_to(fpp_velocity) < 0.00001)
	assert(iso_target_hex == fpp_target_hex)
	assert(player.get_state_snapshot() == state_before)

	_set_camera_mode(CAMERA_ISO)


func _requested_start_camera() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.to_lower() == "--camera=iso":
			return CAMERA_ISO
	return CAMERA_FPP


func _requested_scene_path() -> String:
	for argument in OS.get_cmdline_user_args():
		var normalized := argument.to_lower()
		if normalized.begins_with("--map="):
			var map_key := normalized.trim_prefix("--map=").get_basename()
			if SCENE_PATHS.has(map_key):
				return String(SCENE_PATHS[map_key])
			push_warning("Unknown debug map '%s'; using %s" % [map_key, DEFAULT_MAP_KEY])
	return String(SCENE_PATHS[DEFAULT_MAP_KEY])


func _map_stem(map_name: String) -> String:
	return map_name.to_lower().get_file().get_basename()


func _has_user_argument(expected: String) -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.to_lower() == expected:
			return true
	return false


func _run_bridge_probe() -> void:
	var spawn: Dictionary = scene_data["spawn"]
	var source_hex := int(spawn["hex_index"])
	var moved_hex := Coordinates.tile_in_direction(source_hex, 0)
	var target: Dictionary = {}
	for target_value in scene_data["objects"]["records"]:
		var candidate: Dictionary = target_value
		var candidate_id := int(candidate["instance_id"])
		if not object_states.has(candidate_id):
			continue
		target = candidate
		if String(candidate.get("kind", "")) == "door":
			break
	assert(not target.is_empty(), "Bridge probe needs an interactable target")
	var target_instance_id := int(target["instance_id"])
	assert(object_states.has(target_instance_id), "Bridge probe target is not interactable")

	var events := [
		{
			"schema": "fo2remix.bridge-v1",
			"sequence": 0,
			"event": "session_started",
		},
		{
			"schema": "fo2remix.bridge-v1",
			"sequence": 1,
			"event": "map_loaded",
			"map": scene_data["map"].duplicate(true),
			"player": {
				"object_id": 18000,
				"pid": 16777216,
				"hex_index": source_hex,
				"elevation": int(spawn["elevation"]),
				"rotation": int(spawn["rotation"]),
			},
		},
		{
			"schema": "fo2remix.bridge-v1",
			"sequence": 2,
			"event": "player_moved",
			"player": {
				"object_id": 18000,
				"pid": 16777216,
				"hex_index": moved_hex,
				"elevation": int(spawn["elevation"]),
				"rotation": 2,
			},
		},
		{
			"schema": "fo2remix.bridge-v1",
			"sequence": 3,
			"event": "interaction",
			"actor": {
				"object_id": 18000,
				"pid": 16777216,
				"hex_index": moved_hex,
				"elevation": int(spawn["elevation"]),
				"rotation": 2,
			},
			"target": {
				"instance_id": target_instance_id,
				"object_id": int(target["object_id"]),
				"pid": int(target["pid"]),
				"hex_index": int(target["hex_index"]),
				"elevation": int(target["elevation"]),
				"rotation": int(target["rotation"]),
			},
			"result": 0,
		},
	]
	var tests_door_state := String(target.get("kind", "")) == "door"
	if tests_door_state:
		events.append({
			"schema": "fo2remix.bridge-v1",
			"sequence": 4,
			"event": "object_state",
			"target": events[3]["target"].duplicate(true),
			"state": {
				"kind": "door",
				"open": true,
				"locked": false,
				"jammed": false,
				"blocks_movement": false,
			},
		})

	var trace_path := ProjectSettings.globalize_path(BRIDGE_PROBE_TRACE_PATH)
	var trace_file := FileAccess.open(trace_path, FileAccess.WRITE)
	assert(trace_file != null, "Could not write bridge probe trace")
	trace_file.store_line(JSON.stringify(events[0]))
	trace_file.store_line(JSON.stringify(events[1]))
	trace_file.close()
	state_bridge.poll_now()
	assert(state_bridge.events_received == 2, "Godot did not consume initial bridge events")

	var moved_line := JSON.stringify(events[2])
	var split_index := int(moved_line.length() / 2)
	var append_file := FileAccess.open(trace_path, FileAccess.READ_WRITE)
	assert(append_file != null, "Could not append partial bridge probe event")
	append_file.seek_end()
	append_file.store_string(moved_line.substr(0, split_index))
	append_file.close()
	state_bridge.poll_now()
	assert(state_bridge.events_received == 2, "Partial JSONL event was consumed too early")

	append_file = FileAccess.open(trace_path, FileAccess.READ_WRITE)
	assert(append_file != null, "Could not finish partial bridge probe event")
	append_file.seek_end()
	append_file.store_line(moved_line.substr(split_index))
	append_file.store_line(JSON.stringify(events[3]))
	if tests_door_state:
		append_file.store_line(JSON.stringify(events[4]))
	append_file.close()
	state_bridge.poll_now()

	assert(state_bridge.events_received == events.size(), "Godot did not consume all bridge events")
	assert(bridge_events_observed == events.size(), "Main scene did not observe all bridge events")
	assert(bridge_events_applied == events.size() - 1, "Unexpected applied bridge events")
	assert(int(player.logical_state["hex_index"]) == moved_hex)
	assert(int(player.logical_state["elevation"]) == int(spawn["elevation"]))
	assert(int(player.logical_state["rotation"]) == 2)
	assert(int(player.logical_state["selection"]) == target_instance_id)
	assert(bool(object_states[target_instance_id]["activated"]))
	if tests_door_state:
		assert(bool(object_states[target_instance_id]["open"]))
		assert(not bool(object_states[target_instance_id]["blocks_movement"]))
		for collision_value in object_collision_shapes.get(target_instance_id, []):
			var collision: CollisionShape3D = collision_value
			assert(collision.disabled, "Open CE door retained its Godot collision")
	var expected_world := Coordinates.hex_index_to_world(moved_hex, int(spawn["elevation"]))
	assert(player.global_position.distance_to(expected_world) < 0.00001)

	var state_before_camera_switch: Dictionary = player.get_state_snapshot()
	_toggle_camera()
	_toggle_camera()
	assert(player.get_state_snapshot() == state_before_camera_switch)

	var evidence := {
		"schema": "fo2remix.godot-bridge-runtime-v1",
		"bridge_schema": state_bridge.SCHEMA,
		"fallout2_ce_commit": FALLOUT2_CE_COMMIT,
		"events_received": state_bridge.events_received,
		"events_applied": bridge_events_applied,
		"source_hex": source_hex,
		"applied_hex": moved_hex,
		"applied_elevation": int(player.logical_state["elevation"]),
		"applied_rotation": int(player.logical_state["rotation"]),
		"applied_world": _vector_to_array(player.global_position),
		"target_instance_id": target_instance_id,
		"target_object_id": int(target["object_id"]),
		"interaction_activated": bool(object_states[target_instance_id]["activated"]),
		"door_state_verified": tests_door_state,
		"door_open": bool(object_states[target_instance_id].get("open", false)),
		"door_collision_disabled": (
			tests_door_state
			and not bool(object_states[target_instance_id].get("blocks_movement", true))
		),
		"camera_round_trip_preserved_bridge_state": true,
		"local_movement_disabled_under_ce_authority": not player.movement_enabled,
		"incremental_tail_verified": true,
		"partial_jsonl_buffering_verified": true,
		"passed": true,
	}
	var evidence_path := ProjectSettings.globalize_path(BRIDGE_RUNTIME_EVIDENCE_PATH)
	var evidence_file := FileAccess.open(evidence_path, FileAccess.WRITE)
	assert(evidence_file != null, "Could not write bridge runtime evidence")
	evidence_file.store_string(JSON.stringify(evidence, "  "))
	print("FO2REMIX_BRIDGE_RUNTIME %s" % JSON.stringify(evidence))
	get_tree().quit(0)


func _run_runtime_movement_probe() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var start_position: Vector3 = player.global_position
	var start_yaw: float = player.view_yaw
	var start_hex: int = int(player.logical_state["hex_index"])
	var right_axis := Coordinates.right_from_yaw(start_yaw)
	var forward_axis := Coordinates.forward_from_yaw(start_yaw)

	Input.action_press("move_right")
	for _frame in 30:
		await get_tree().physics_frame
	Input.action_release("move_right")

	var displacement: Vector3 = player.global_position - start_position
	var lateral_distance := displacement.dot(right_axis)
	var forward_drift := absf(displacement.dot(forward_axis))
	assert(lateral_distance > 0.5, "D did not move the CharacterBody to the right")
	assert(forward_drift < 0.05, "Strafe introduced forward drift")
	assert(absf(player.view_yaw - start_yaw) < 0.00001, "Strafe rotated the view")

	var evidence := {
		"schema": "fo2remix.godot-movement-runtime-v1",
		"input": "D",
		"physics_frames": 30,
		"start_hex": start_hex,
		"end_hex": int(player.logical_state["hex_index"]),
		"displacement": _vector_to_array(displacement),
		"lateral_distance": lateral_distance,
		"forward_drift": forward_drift,
		"yaw_unchanged": true,
		"passed": true,
	}
	var path := ProjectSettings.globalize_path(MOVEMENT_RUNTIME_EVIDENCE_PATH)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "Could not write runtime movement evidence")
	file.store_string(JSON.stringify(evidence, "  "))
	print("FO2REMIX_MOVEMENT_RUNTIME %s" % JSON.stringify(evidence))
	get_tree().quit(0)


func _run_blocking_collision_probe() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var blocking_records: Array = scene_data["collision"]["blocking_hexes"]
	var blocked := {}
	for value in blocking_records:
		var record: Dictionary = value
		blocked[_blocking_key(int(record["elevation"]), int(record["hex_index"]))] = true

	var target_record: Dictionary = {}
	var start_hex := -1
	for value in scene_data["objects"]["records"]:
		var candidate: Dictionary = value
		if String(candidate["kind"]) != "wall" or not bool(candidate["blocks_movement"]):
			continue
		var candidate_tile := int(candidate["hex_index"])
		var candidate_elevation := int(candidate["elevation"])
		for rotation in 6:
			var neighbor := Coordinates.tile_in_direction(candidate_tile, rotation)
			if neighbor == candidate_tile:
				continue
			if not blocked.has(_blocking_key(candidate_elevation, neighbor)):
				target_record = candidate
				start_hex = neighbor
				break
		if not target_record.is_empty():
			break

	assert(not target_record.is_empty(), "No accessible blocking wall found for probe")
	var elevation := int(target_record["elevation"])
	var target_hex := int(target_record["hex_index"])
	var start_world := Coordinates.hex_index_to_world(start_hex, elevation)
	var target_world := Coordinates.hex_index_to_world(target_hex, elevation)
	var direction := (target_world - start_world).normalized()
	player.global_position = start_world
	player.velocity = Vector3.ZERO
	player.set_view_angles(atan2(-direction.x, -direction.z), 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	Input.action_press("move_forward")
	for _frame in 90:
		await get_tree().physics_frame
	Input.action_release("move_forward")

	var end_hex := Coordinates.world_to_nearest_hex(player.global_position)
	var distance_to_blocker: float = player.global_position.distance_to(target_world)
	assert(end_hex != target_hex, "Player entered a Fallout-blocking wall hex")
	assert(distance_to_blocker > 0.68, "Player capsule penetrated blocking collision")
	var evidence := {
		"schema": "fo2remix.godot-blocking-runtime-v1",
		"map": scene_data["map"]["name"],
		"object_id": int(target_record["object_id"]),
		"start_hex": start_hex,
		"blocking_hex": target_hex,
		"end_hex": end_hex,
		"distance_to_blocker": distance_to_blocker,
		"physics_frames": 90,
		"passed": true,
	}
	var path := ProjectSettings.globalize_path(BLOCKING_RUNTIME_EVIDENCE_PATH)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "Could not write blocking runtime evidence")
	file.store_string(JSON.stringify(evidence, "  "))
	print("FO2REMIX_BLOCKING_RUNTIME %s" % JSON.stringify(evidence))
	get_tree().quit(0)


func _run_interaction_probe() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var setup := _find_interaction_probe_setup()
	assert(not setup.is_empty(), "No accessible blocking scenery found for interaction probe")
	var record: Dictionary = setup["record"]
	var instance_id := int(record["instance_id"])
	var target_hex := int(record["hex_index"])
	var elevation := int(record["elevation"])
	var start_hex := int(setup["start_hex"])
	var start_world := Coordinates.hex_index_to_world(start_hex, elevation)
	var target_world := Coordinates.hex_index_to_world(target_hex, elevation)
	var direction := (target_world - start_world).normalized()
	player.global_position = start_world
	player.velocity = Vector3.ZERO
	player.set_view_angles(atan2(-direction.x, -direction.z), 0.0)
	_update_cameras()
	await get_tree().physics_frame
	await get_tree().physics_frame

	_set_camera_mode(CAMERA_FPP)
	_update_cameras()
	var fpp_target := _resolve_fpp_target()
	assert(
		fpp_target == instance_id,
		"FPP ray selected instance %d instead of %d" % [fpp_target, instance_id]
	)
	assert(
		_interact_with_object(fpp_target),
		"FPP interaction failed: %s" % interaction_status
	)
	var fpp_result: Dictionary = object_states[instance_id].duplicate(true)
	assert(bool(fpp_result["activated"]))

	object_states[instance_id]["activated"] = false
	player.set_selection(-1)
	_refresh_object_colors()
	_set_camera_mode(CAMERA_ISO)
	_update_cameras()
	var target_screen := iso_camera.unproject_position(
		target_world + Vector3.UP * (BLOCKING_COLLIDER_HEIGHT * 0.5)
	)
	var iso_target := _resolve_target_from_camera_screen(iso_camera, target_screen, 500.0)
	assert(iso_target == instance_id, "ISO ray selected a different object instance")
	player.set_selection(iso_target)
	assert(_interact_with_object(iso_target), "ISO interaction failed")
	var iso_result: Dictionary = object_states[instance_id].duplicate(true)
	assert(iso_result == fpp_result, "ISO and FPP produced different object state")

	var state_before_switch: Dictionary = player.get_state_snapshot()
	var object_state_before_switch: Dictionary = iso_result.duplicate(true)
	_toggle_camera()
	_toggle_camera()
	assert(player.get_state_snapshot() == state_before_switch)
	assert(object_states[instance_id] == object_state_before_switch)

	var evidence := {
		"schema": "fo2remix.godot-interaction-runtime-v1",
		"map": scene_data["map"]["name"],
		"instance_id": instance_id,
		"object_id": int(record["object_id"]),
		"kind": record["kind"],
		"prototype": record["prototype"],
		"object_hex": target_hex,
		"start_hex": start_hex,
		"distance": start_world.distance_to(target_world),
		"fpp_target_instance_id": fpp_target,
		"iso_target_instance_id": iso_target,
		"shared_result": iso_result,
		"camera_round_trip_preserved_selection_and_object_state": true,
		"passed": true,
	}
	var path := ProjectSettings.globalize_path(INTERACTION_RUNTIME_EVIDENCE_PATH)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "Could not write interaction runtime evidence")
	file.store_string(JSON.stringify(evidence, "  "))
	print("FO2REMIX_INTERACTION_RUNTIME %s" % JSON.stringify(evidence))
	get_tree().quit(0)


func _find_interaction_probe_setup() -> Dictionary:
	var blocked := {}
	for value in scene_data["collision"]["blocking_hexes"]:
		var blocking_record: Dictionary = value
		blocked[_blocking_key(
			int(blocking_record["elevation"]),
			int(blocking_record["hex_index"])
		)] = true
	for value in scene_data["objects"]["records"]:
		var record: Dictionary = value
		if String(record["kind"]) != "scenery" or not bool(record["blocks_movement"]):
			continue
		var tile := int(record["hex_index"])
		var elevation := int(record["elevation"])
		for rotation in 6:
			var neighbor := Coordinates.tile_in_direction(tile, rotation)
			if neighbor != tile and not blocked.has(_blocking_key(elevation, neighbor)):
				return {"record": record, "start_hex": neighbor}
	return {}


func _blocking_key(elevation: int, tile: int) -> String:
	return "%d:%d" % [elevation, tile]


func _write_evidence() -> void:
	var state: Dictionary = player.logical_state
	var round_trip_count := 11
	var evidence := {
		"schema": "fo2remix.godot-scene-contract-v4",
		"fallout2_ce_commit": FALLOUT2_CE_COMMIT,
		"scene_schema": scene_data["schema"],
		"map": state["map_name"],
		"floor_instances": floor_instances.multimesh.instance_count,
		"map_objects": {
			"declared": int(scene_data["objects"]["declared_count"]),
			"walls": debug_object_counts["wall"],
			"doors": debug_object_counts["door"],
			"scenery": debug_object_counts["scenery"],
			"blocking_hexes": blocking_collision_count,
		},
		"player_state": state,
		"player_world": _vector_to_array(player.global_position),
		"fpp_camera_origin": _vector_to_array(fpp_camera.global_position),
		"eye_height": player.eye_height,
		"fpp_third_person_offset": 0.0,
		"controller": "CharacterBody3D",
		"starts_in_fpp": true,
		"camera_round_trip_preserved_state": true,
		"movement_same_target_in_iso_and_fpp": true,
		"interaction": {
			"input": "E",
			"maximum_distance": INTERACTION_DISTANCE,
			"fpp_targeting": "center camera ray",
			"iso_targeting": "mouse camera ray",
			"shared_object_state": true,
		},
		"state_bridge": {
			"schema": state_bridge.SCHEMA,
			"trace_path": BRIDGE_TRACE_PATH,
			"default_mode": "observe",
			"authoritative_argument": "--bridge-live",
			"probe_argument": "--bridge-probe",
		},
		"world_to_hex_round_trip_records": round_trip_count,
		"wasd": {
			"forward": "W",
			"backward": "S",
			"strafe_left": "A",
			"strafe_right": "D",
			"sprint": "Shift",
			"diagonal_speed_normalized": true,
		},
		"movement": {
			"walk_speed": player.walk_speed,
			"sprint_speed": player.sprint_speed,
			"acceleration": player.acceleration,
			"deceleration": player.deceleration,
		},
		"coordinate_system": {
			"units": "one world unit per adjacent logical hex",
			"up_axis": "+Y",
			"ground_axes": "X/Z",
			"hex_grid": "200x200 reversed-column Fallout index",
			"floor_grid": "100x100 reversed-column square tiles",
		},
	}
	var path := ProjectSettings.globalize_path(EVIDENCE_PATH)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write evidence: %s" % path)
		return
	file.store_string(JSON.stringify(evidence, "  "))
	print("FO2REMIX_MOVEMENT_CONTRACT %s" % JSON.stringify(evidence))


func _vector_to_array(vector: Vector3) -> Array[float]:
	return [vector.x, vector.y, vector.z]
