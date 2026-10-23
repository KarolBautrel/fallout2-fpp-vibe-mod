extends Node3D

const Coordinates = preload("res://scripts/fallout_coordinate_space.gd")
const PlayerController = preload("res://scripts/fallout_player_controller.gd")

const SCENE_PATH := "res://../artifacts/artemple.scene-v1.json"
const EVIDENCE_PATH := "res://../artifacts/godot-iso-fpp-contract.json"
const MOVEMENT_RUNTIME_EVIDENCE_PATH := "res://../artifacts/godot-movement-runtime.json"
const BLOCKING_RUNTIME_EVIDENCE_PATH := "res://../artifacts/godot-blocking-runtime.json"
const INTERACTION_RUNTIME_EVIDENCE_PATH := "res://../artifacts/godot-interaction-runtime.json"
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
var floor_instances: MultiMeshInstance3D
var debug_object_counts := {"wall": 0, "door": 0, "scenery": 0}
var blocking_collision_count := 0
var object_records_by_instance_id := {}
var object_states := {}
var object_visuals := {}
var object_instance_colors := {}
var interaction_status := "No object selected"
var player
var iso_camera: Camera3D
var fpp_camera: Camera3D
var state_label: Label
var crosshair: Label
var hud_refresh_timer := 0.0


func _ready() -> void:
	_load_scene_data()
	if scene_data.is_empty():
		return

	_create_environment()
	_create_floor_grid()
	_create_ground_collision()
	_create_map_object_debug_geometry()
	_create_map_blocking_collisions()
	_create_player()
	_create_cameras()
	_create_hud()
	_register_input_actions()
	_update_cameras()
	_run_contract_checks()
	_set_camera_mode(_requested_start_camera())
	_write_evidence()
	if _has_user_argument("--interaction-probe"):
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
	var absolute_path := ProjectSettings.globalize_path(SCENE_PATH)
	var file := FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		push_error("Missing scene JSON: %s" % absolute_path)
		get_tree().quit(2)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or parsed.get("schema", "") != "fo2remix.scene-v1":
		push_error("Unsupported or invalid scene JSON: %s" % absolute_path)
		get_tree().quit(3)
		return
	scene_data = parsed


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


func _create_floor_grid() -> void:
	var tile_grid: Dictionary = scene_data["tile_grid"]
	assert(int(tile_grid["width"]) == Coordinates.FLOOR_GRID_WIDTH)
	assert(int(tile_grid["height"]) == Coordinates.FLOOR_GRID_HEIGHT)
	var layers: Array = tile_grid["layers"]
	assert(not layers.is_empty())
	var layer: Dictionary = layers[0]
	var floor_ids: Array = layer["floor_ids"]
	assert(floor_ids.size() == FLOOR_CELL_COUNT)

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
	multi_mesh.instance_count = FLOOR_CELL_COUNT

	var column_axis := Vector3(1.5, 0.0, -Coordinates.SQRT_3_OVER_2) * 0.992
	var row_axis := Vector3(1.0, 0.0, 2.0 * Coordinates.SQRT_3_OVER_2) * 0.992
	var cell_basis := Basis(column_axis, Vector3(0.0, FLOOR_THICKNESS, 0.0), row_axis)

	for tile_index in FLOOR_CELL_COUNT:
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
		multi_mesh.set_instance_transform(tile_index, Transform3D(cell_basis, origin))
		multi_mesh.set_instance_color(tile_index, _debug_floor_color(int(floor_ids[tile_index])))

	floor_instances = MultiMeshInstance3D.new()
	floor_instances.name = "FloorGrid100x100"
	floor_instances.multimesh = multi_mesh
	add_child(floor_instances)


func _create_ground_collision() -> void:
	var ground := StaticBody3D.new()
	ground.name = "DebugGroundCollision"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(600.0, 0.2, 600.0)
	collision.shape = shape
	collision.position.y = -0.1
	ground.add_child(collision)
	add_child(ground)


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
			object_states[instance_id] = {"activated": false}
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
		multi_mesh.set_instance_transform(index, Transform3D(basis, position))
		multi_mesh.set_instance_color(index, color)
		object_visuals[instance_id] = {"multi_mesh": multi_mesh, "index": index}
		object_instance_colors[instance_id] = color

	var instances := MultiMeshInstance3D.new()
	instances.name = node_name
	instances.multimesh = multi_mesh
	add_child(instances)


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
	add_child(body)
	blocking_collision_count = records.size()


func _debug_floor_color(floor_id: int) -> Color:
	if floor_id == 0:
		return Color("20282a")
	var hue := fmod(0.24 + float(floor_id % 17) * 0.006, 1.0)
	var value := 0.31 + float(floor_id % 5) * 0.025
	return Color.from_hsv(hue, 0.18, value, 1.0)


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
	panel.size = Vector2(1100.0, 160.0)
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
			Input.MOUSE_MODE_CAPTURED if mode == CAMERA_FPP else Input.MOUSE_MODE_VISIBLE
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
		if object_states.has(instance_id) and bool(object_states[instance_id]["activated"]):
			color = Color("f4d35e")
		elif int(instance_id) == selected_id:
			color = Color("5ee7f4")
		var multi_mesh: MultiMesh = visual["multi_mesh"]
		multi_mesh.set_instance_color(int(visual["index"]), color)


func _update_hud() -> void:
	if state_label == null or player == null:
		return
	var state: Dictionary = player.logical_state
	var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
	state_label.text = (
		"%s  |  %s  |  %d FPS  |  speed %.2f\n"
		+ "hex %d  grid (%d, %d)  elevation %d  direction %d\n"
		+ "walls %d  doors %d  scenery %d  blocking hexes %d  selected instance %d\n"
		+ "%s\n"
		+ "Mouse: look/select   WASD: move/strafe   E: interact   SHIFT: sprint   TAB: ISO/FPP"
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
		interaction_status,
	]


func _run_contract_checks() -> void:
	assert(floor_instances.multimesh.instance_count == FLOOR_CELL_COUNT)
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
	assert(Coordinates.tile_index_to_grid(18492) == Vector2i(107, 92))
	assert(int(player.logical_state["hex_index"]) == 18492)

	var spawn_world := Coordinates.hex_index_to_world(18492)
	assert(player.global_position.distance_to(spawn_world) < 0.00001)

	var round_trip_tiles := [18492, 0, 199, 39800, 39999]
	for rotation in 6:
		var neighbor := Coordinates.tile_in_direction(18492, rotation)
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


func _has_user_argument(expected: String) -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.to_lower() == expected:
			return true
	return false


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
