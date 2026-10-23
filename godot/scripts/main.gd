extends Node3D

const Coordinates = preload("res://scripts/fallout_coordinate_space.gd")
const PlayerController = preload("res://scripts/fallout_player_controller.gd")
const StateBridge = preload("res://scripts/fallout_state_bridge.gd")
const ProceduralProps = preload("res://scripts/fallout_procedural_props.gd")
const StoneWallShader = preload("res://shaders/fallout_stone_wall.gdshader")
const CaveWallShader = preload("res://shaders/fallout_cave_wall.gdshader")
const StoneCeilingShader = preload("res://shaders/fallout_stone_ceiling.gdshader")

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
const RENDER_PERFORMANCE_EVIDENCE_PATH := "res://../artifacts/godot-render-performance.json"
const ART_PROFILE_PATH := "res://data/fallout_art_profiles.json"
const FALLOUT2_CE_COMMIT := "e97087b9582f37075db347a89898887320753f8b"

const FLOOR_CELL_COUNT := 100 * 100
const FLOOR_THICKNESS := 0.08
const CEILING_WALL_OVERLAP := 0.08
const BLOCKING_COLLIDER_HEIGHT := 2.4
const BLOCKING_COLLIDER_RADIUS := 0.42
const INTERACTION_DISTANCE := 1.75
const INTERACTION_RAY_DISTANCE := 2.25
const INFERRED_CEILING_MIN_HEXES := 16
const INTERIOR_CEILING_MIN_WALLS := 100
const INTERIOR_CEILING_WALL_DENSITY := 0.08
const PROP_PIXELS_PER_METER := 48.0
const PROP_MAX_HEIGHT := 2.85
const PROP_LIGHT_LIMIT := 12
const CAMERA_ISO := "ISO"
const CAMERA_FPP := "FPP"

var scene_data: Dictionary
var art_profiles: Array = []
var active_camera_mode := CAMERA_FPP
var map_geometry_root: Node3D
var floor_instances: Array[MultiMeshInstance3D] = []
var ceiling_instances: Array[MultiMeshInstance3D] = []
var inferred_ceiling_instances: Array[MeshInstance3D] = []
var inferred_ceiling_cell_count := 0
var inferred_ceiling_component_count := 0
var ceiling_strategy := "roof_tiles"
var elevation_roots := {}
var active_elevation := -1
var debug_object_counts := {"wall": 0, "door": 0, "scenery": 0, "item": 0}
var wall_mesh_face_count := 0
var wall_mesh_elevation_count := 0
var wall_profile_match_count := 0
var blocking_collision_count := 0
var object_records_by_instance_id := {}
var object_states := {}
var object_visuals := {}
var object_instance_colors := {}
var object_collision_shapes := {}
var door_art_overlays := {}
var prop_art_overlays: Array[Dictionary] = []
var prop_light_sources: Array[Dictionary] = []
var tile_art_by_id := {}
var image_texture_cache := {}
var door_art_overlay_count := 0
var prop_art_overlay_count := 0
var active_prop_light_count := 0
var prop_animation_time := 0.0
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
	_load_art_profiles()
	_load_scene_data()
	if scene_data.is_empty():
		return

	_create_environment()
	_create_map_geometry_root()
	_create_floor_grid()
	_create_ceiling_grid()
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
	if _has_user_argument("--performance-probe"):
		_run_render_performance_probe()
	elif _has_user_argument("--screenshot-probe"):
		_run_screenshot_probe()
	elif _has_user_argument("--bridge-probe"):
		_run_bridge_probe()
	elif _has_user_argument("--interaction-probe"):
		_run_interaction_probe()
	elif _has_user_argument("--blocking-probe"):
		_run_blocking_collision_probe()
	elif _has_user_argument("--movement-probe"):
		_run_runtime_movement_probe()


func _run_screenshot_probe() -> void:
	for _frame in 30:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if image.is_empty():
		push_error("Viewport screenshot is empty")
		get_tree().quit(2)
		return
	var map_key := _map_stem(String(scene_data["map"]["name"]))
	var camera_key := active_camera_mode.to_lower()
	var path := "res://../artifacts/godot-%s-%s-material-preview.png" % [
		map_key,
		camera_key,
	]
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Unable to save screenshot: %s" % error_string(error))
		get_tree().quit(2)
		return
	print("FO2REMIX_SCREENSHOT %s" % ProjectSettings.globalize_path(path))
	get_tree().quit()


func _run_render_performance_probe() -> void:
	for _frame in 30:
		await get_tree().process_frame
	var measured_frames := 180
	var started_usec := Time.get_ticks_usec()
	for _frame in measured_frames:
		await get_tree().process_frame
	var elapsed_seconds := float(Time.get_ticks_usec() - started_usec) / 1000000.0
	var average_fps := float(measured_frames) / elapsed_seconds
	var evidence := {
		"schema": "fo2remix.godot-render-performance-v1",
		"map": scene_data["map"]["name"],
		"camera": active_camera_mode,
		"renderer": RenderingServer.get_current_rendering_method(),
		"measured_frames": measured_frames,
		"elapsed_seconds": elapsed_seconds,
		"average_fps": average_fps,
		"wall_mesh_faces": wall_mesh_face_count,
		"inferred_ceiling_cells": inferred_ceiling_cell_count,
		"ceiling_strategy": ceiling_strategy,
		"passed_30_fps": average_fps >= 30.0,
	}
	var file := FileAccess.open(
		ProjectSettings.globalize_path(RENDER_PERFORMANCE_EVIDENCE_PATH),
		FileAccess.WRITE
	)
	assert(file != null, "Could not write render performance evidence")
	file.store_string(JSON.stringify(evidence, "  "))
	print("FO2REMIX_RENDER_PERFORMANCE %s" % JSON.stringify(evidence))
	get_tree().quit(0 if average_fps >= 30.0 else 3)


func _process(delta: float) -> void:
	if player == null:
		return
	_update_cameras()
	_update_prop_animations(delta)
	hud_refresh_timer -= delta
	if hud_refresh_timer <= 0.0:
		hud_refresh_timer = 0.25
		_refresh_prop_lights()
		_update_hud()


func _load_scene_data() -> void:
	if not _load_scene_data_from_path(_requested_scene_path()):
		get_tree().quit(2)


func _load_art_profiles() -> void:
	var file := FileAccess.open(ART_PROFILE_PATH, FileAccess.READ)
	if file == null:
		push_error("Missing art profiles: %s" % ProjectSettings.globalize_path(ART_PROFILE_PATH))
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or parsed.get("schema", "") != "fo2remix.art-profiles-v1":
		push_error("Unsupported or invalid art profile catalog")
		return
	art_profiles = parsed.get("profiles", [])


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
	environment.ambient_light_energy = 0.42
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "DebugSun"
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	add_child(sun)


func _create_map_geometry_root() -> void:
	map_geometry_root = Node3D.new()
	map_geometry_root.name = "ActiveMapGeometry"
	add_child(map_geometry_root)


func _get_elevation_root(elevation: int) -> Node3D:
	if elevation_roots.has(elevation):
		return elevation_roots[elevation]
	var root := Node3D.new()
	root.name = "Elevation%d" % elevation
	root.visible = active_elevation < 0 or active_elevation == elevation
	map_geometry_root.add_child(root)
	elevation_roots[elevation] = root
	return root


func _set_active_elevation(elevation: int) -> void:
	active_elevation = elevation
	for elevation_value in elevation_roots:
		var layer_elevation := int(elevation_value)
		var root: Node3D = elevation_roots[layer_elevation]
		var layer_active := layer_elevation == active_elevation
		root.visible = layer_active
		for collision_value in root.find_children("*", "CollisionObject3D", true, false):
			var collision_object: CollisionObject3D = collision_value
			collision_object.collision_layer = 1 if layer_active else 0


func _create_floor_grid() -> void:
	var tile_grid: Dictionary = scene_data["tile_grid"]
	tile_art_by_id.clear()
	for art_value in tile_grid.get("art", []):
		var art_record: Dictionary = art_value
		tile_art_by_id[int(art_record["tile_id"])] = art_record
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

	var column_axis := Vector3(1.5, 0.0, -Coordinates.SQRT_3_OVER_2) * 1.004
	var row_axis := Vector3(1.0, 0.0, 2.0 * Coordinates.SQRT_3_OVER_2) * 1.004
	var cell_basis := Basis(column_axis, Vector3.UP, row_axis)
	for layer_value in layers:
		var layer: Dictionary = layer_value
		var floor_ids: Array = layer["floor_ids"]
		var indices_by_floor_id := {}
		for tile_index in FLOOR_CELL_COUNT:
			var floor_id := int(floor_ids[tile_index])
			if floor_id == 1:
				continue
			if not indices_by_floor_id.has(floor_id):
				indices_by_floor_id[floor_id] = []
			indices_by_floor_id[floor_id].append(tile_index)

		for floor_id_value in indices_by_floor_id:
			var floor_id := int(floor_id_value)
			var tile_indices: Array = indices_by_floor_id[floor_id]
			var material := _create_floor_material(floor_id)
			var cell_mesh := _create_floor_cell_mesh(material)
			var multi_mesh := MultiMesh.new()
			multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
			multi_mesh.mesh = cell_mesh
			multi_mesh.instance_count = tile_indices.size()
			for instance_index in tile_indices.size():
				var tile_index := int(tile_indices[instance_index])
				var column := Coordinates.FLOOR_GRID_WIDTH - 1 - (
					tile_index % Coordinates.FLOOR_GRID_WIDTH
				)
				var row := int(tile_index / Coordinates.FLOOR_GRID_WIDTH)
				var origin := Coordinates.square_grid_to_world(
					column,
					row,
					int(layer["elevation"])
				)
				origin.y += 0.012
				multi_mesh.set_instance_transform(
					instance_index,
					Transform3D(cell_basis, origin)
				)

			var layer_instances := MultiMeshInstance3D.new()
			var elevation := int(layer["elevation"])
			layer_instances.name = "Floor%dElevation%d" % [floor_id, elevation]
			layer_instances.multimesh = multi_mesh
			floor_instances.append(layer_instances)
			_get_elevation_root(elevation).add_child(layer_instances)


func _create_floor_material(floor_id: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.roughness = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var art: Dictionary = tile_art_by_id.get(floor_id, {})
	var source_path := String(art.get("path", ""))
	if not source_path.is_empty():
		var map_key := _map_stem(String(scene_data["map"]["name"]))
		var file_stem := source_path.replace("\\", "/").get_file().get_basename().to_lower()
		var cache_path := "res://../artifacts/art-cache/%s/tiles/%s-r0-f0.png" % [
			map_key,
			file_stem,
		]
		var texture := _load_cached_image_texture(cache_path)
		if texture != null:
			material.albedo_texture = texture
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			return material
	material.albedo_color = _debug_floor_color(floor_id)
	return material


func _create_floor_cell_mesh(material: Material) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices := [
		Vector3(-0.5, 0.0, -0.5),
		Vector3(0.5, 0.0, -0.5),
		Vector3(0.5, 0.0, 0.5),
		Vector3(-0.5, 0.0, 0.5),
	]
	var uvs := [
		Vector2(46.5 / 80.0, 0.5 / 36.0),
		Vector2(78.5 / 80.0, 22.5 / 36.0),
		Vector2(33.5 / 80.0, 34.5 / 36.0),
		Vector2(0.5 / 80.0, 11.5 / 36.0),
	]
	for index in [0, 2, 1, 0, 3, 2]:
		surface.set_normal(Vector3.UP)
		surface.set_uv(uvs[index])
		surface.add_vertex(vertices[index])
	var mesh := surface.commit()
	mesh.surface_set_material(0, material)
	return mesh


func _create_ground_collision() -> void:
	for layer_value in scene_data["tile_grid"]["layers"]:
		var layer: Dictionary = layer_value
		var elevation := int(layer["elevation"])
		var ground := StaticBody3D.new()
		ground.name = "DebugGroundCollisionElevation%d" % elevation
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(600.0, 0.2, 600.0)
		collision.shape = shape
		collision.position.y = (
			float(elevation) * Coordinates.ELEVATION_HEIGHT - 0.1
		)
		ground.add_child(collision)
		_get_elevation_root(elevation).add_child(ground)


func _create_ceiling_grid() -> void:
	var column_axis := Vector3(1.5, 0.0, -Coordinates.SQRT_3_OVER_2) * 1.006
	var row_axis := Vector3(1.0, 0.0, 2.0 * Coordinates.SQRT_3_OVER_2) * 1.006
	var cell_basis := Basis(column_axis, Vector3(0.0, FLOOR_THICKNESS, 0.0), row_axis)
	var use_floor_footprint := _should_use_floor_footprint_ceiling()
	for layer_value in scene_data["tile_grid"]["layers"]:
		var layer: Dictionary = layer_value
		var roof_ids: Array = layer["roof_ids"]
		var roof_cell_count := 0
		for roof_id in roof_ids:
			if int(roof_id) != 1:
				roof_cell_count += 1
		if roof_cell_count == 0:
			if use_floor_footprint:
				ceiling_strategy = "floor_footprint"
				_create_floor_footprint_ceiling(layer, cell_basis)
			else:
				ceiling_strategy = "outdoor_none"
			continue

		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.95
		var cell_mesh := BoxMesh.new()
		cell_mesh.size = Vector3.ONE
		cell_mesh.material = material

		var multi_mesh := MultiMesh.new()
		multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
		multi_mesh.use_colors = true
		multi_mesh.mesh = cell_mesh
		multi_mesh.instance_count = roof_cell_count

		var instance_index := 0
		for tile_index in FLOOR_CELL_COUNT:
			var roof_id := int(roof_ids[tile_index])
			if roof_id == 1:
				continue
			var column := Coordinates.FLOOR_GRID_WIDTH - 1 - (
				tile_index % Coordinates.FLOOR_GRID_WIDTH
			)
			var row := int(tile_index / Coordinates.FLOOR_GRID_WIDTH)
			var elevation := int(layer["elevation"])
			var origin := Coordinates.square_grid_to_world(column, row, elevation)
			origin.y += Coordinates.ELEVATION_HEIGHT - FLOOR_THICKNESS * 0.5
			multi_mesh.set_instance_transform(
				instance_index,
				Transform3D(cell_basis, origin)
			)
			multi_mesh.set_instance_color(instance_index, _debug_ceiling_color(roof_id))
			instance_index += 1

		var elevation := int(layer["elevation"])
		var layer_instances := MultiMeshInstance3D.new()
		layer_instances.name = "CeilingGrid100x100Elevation%d" % elevation
		layer_instances.multimesh = multi_mesh
		ceiling_instances.append(layer_instances)
		_get_elevation_root(elevation).add_child(layer_instances)
	_refresh_ceiling_visibility()


func _should_use_floor_footprint_ceiling() -> bool:
	var wall_count := int(scene_data.get("objects", {}).get("wall_count", 0))
	if wall_count < INTERIOR_CEILING_MIN_WALLS:
		return false
	var floor_count := 0
	for layer_value in scene_data["tile_grid"]["layers"]:
		var layer: Dictionary = layer_value
		for floor_id in layer["floor_ids"]:
			if int(floor_id) != 1:
				floor_count += 1
	return float(wall_count) / float(maxi(floor_count, 1)) >= INTERIOR_CEILING_WALL_DENSITY


func _create_floor_footprint_ceiling(layer: Dictionary, cell_basis: Basis) -> void:
	var floor_ids: Array = layer["floor_ids"]
	var cell_count := 0
	for floor_id in floor_ids:
		if int(floor_id) != 1:
			cell_count += 1
	if cell_count == 0:
		return

	var material := ShaderMaterial.new()
	material.shader = StoneCeilingShader
	var cell_mesh := BoxMesh.new()
	cell_mesh.size = Vector3.ONE
	cell_mesh.material = material

	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.use_colors = true
	multi_mesh.mesh = cell_mesh
	multi_mesh.instance_count = cell_count

	var elevation := int(layer["elevation"])
	var instance_index := 0
	for tile_index in FLOOR_CELL_COUNT:
		var floor_id := int(floor_ids[tile_index])
		if floor_id == 1:
			continue
		var column := Coordinates.FLOOR_GRID_WIDTH - 1 - (
			tile_index % Coordinates.FLOOR_GRID_WIDTH
		)
		var row := int(tile_index / Coordinates.FLOOR_GRID_WIDTH)
		var origin := Coordinates.square_grid_to_world(column, row, elevation)
		origin.y += Coordinates.ELEVATION_HEIGHT - FLOOR_THICKNESS * 0.5
		multi_mesh.set_instance_transform(instance_index, Transform3D(cell_basis, origin))
		multi_mesh.set_instance_color(instance_index, Color("352f29"))
		instance_index += 1

	var instances := MultiMeshInstance3D.new()
	instances.name = "FloorFootprintCeilingElevation%d" % elevation
	instances.multimesh = multi_mesh
	ceiling_instances.append(instances)
	_get_elevation_root(elevation).add_child(instances)
	inferred_ceiling_cell_count += cell_count
	inferred_ceiling_component_count += 1


func _create_inferred_ceiling(elevation: int) -> void:
	var hex_count := Coordinates.HEX_GRID_WIDTH * Coordinates.HEX_GRID_HEIGHT
	var blocked := PackedByteArray()
	blocked.resize(hex_count)
	for record_value in scene_data["collision"]["blocking_hexes"]:
		var record: Dictionary = record_value
		if int(record["elevation"]) == elevation:
			blocked[int(record["hex_index"])] = 1

	var outside := PackedByteArray()
	outside.resize(hex_count)
	var queue: Array[int] = []
	for row in Coordinates.HEX_GRID_HEIGHT:
		for column in [0, Coordinates.HEX_GRID_WIDTH - 1]:
			var tile := Coordinates.grid_to_tile_index(column, row)
			if blocked[tile] == 0 and outside[tile] == 0:
				outside[tile] = 1
				queue.append(tile)
	for column in Coordinates.HEX_GRID_WIDTH:
		for row in [0, Coordinates.HEX_GRID_HEIGHT - 1]:
			var tile := Coordinates.grid_to_tile_index(column, row)
			if blocked[tile] == 0 and outside[tile] == 0:
				outside[tile] = 1
				queue.append(tile)

	var queue_index := 0
	while queue_index < queue.size():
		var tile := queue[queue_index]
		queue_index += 1
		for direction_index in 6:
			var neighbor := Coordinates.tile_in_direction(tile, direction_index)
			if neighbor != tile and blocked[neighbor] == 0 and outside[neighbor] == 0:
				outside[neighbor] = 1
				queue.append(neighbor)

	var visited := PackedByteArray()
	visited.resize(hex_count)
	var ceiling_components: Array[Array] = []
	for seed in hex_count:
		if blocked[seed] != 0 or outside[seed] != 0 or visited[seed] != 0:
			continue
		var component: Array[int] = []
		queue = [seed]
		queue_index = 0
		visited[seed] = 1
		while queue_index < queue.size():
			var tile := queue[queue_index]
			queue_index += 1
			component.append(tile)
			for direction_index in 6:
				var neighbor := Coordinates.tile_in_direction(tile, direction_index)
				if (
					neighbor != tile
					and blocked[neighbor] == 0
					and outside[neighbor] == 0
					and visited[neighbor] == 0
				):
					visited[neighbor] = 1
					queue.append(neighbor)
		if component.size() >= INFERRED_CEILING_MIN_HEXES:
			ceiling_components.append(component)

	if ceiling_components.is_empty():
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var emitted_tiles := {}
	for component_index in ceiling_components.size():
		var component: Array = ceiling_components[component_index]
		var color := Color.from_hsv(
			0.075 + float(component_index % 5) * 0.008,
			0.24,
			0.27,
			1.0
		)
		for tile_value in component:
			var tile := int(tile_value)
			if not emitted_tiles.has(tile):
				_add_ceiling_hex(surface, tile, elevation, color)
				emitted_tiles[tile] = true
				inferred_ceiling_cell_count += 1
			for direction_index in 6:
				var neighbor := Coordinates.tile_in_direction(tile, direction_index)
				if neighbor != tile and blocked[neighbor] != 0 and not emitted_tiles.has(neighbor):
					_add_ceiling_hex(surface, neighbor, elevation, color.darkened(0.04))
					emitted_tiles[neighbor] = true
					inferred_ceiling_cell_count += 1
		inferred_ceiling_component_count += 1

	surface.generate_normals()
	var mesh := surface.commit()
	if mesh == null:
		return
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = "InferredCeilingElevation%d" % elevation
	instance.mesh = mesh
	inferred_ceiling_instances.append(instance)
	_get_elevation_root(elevation).add_child(instance)


func _add_ceiling_hex(
	surface: SurfaceTool,
	tile: int,
	elevation: int,
	color: Color
) -> void:
	var center := Coordinates.hex_index_to_world(tile, elevation)
	center.y += Coordinates.ELEVATION_HEIGHT - CEILING_WALL_OVERLAP
	for direction_index in 6:
		var first_direction := Coordinates.direction_to_world(tile, direction_index)
		var second_direction := Coordinates.direction_to_world(
			tile,
			(direction_index + 1) % 6
		)
		var corner_a := center + (first_direction + second_direction) / 3.0
		var next_first := second_direction
		var next_second := Coordinates.direction_to_world(tile, (direction_index + 2) % 6)
		var corner_b := center + (next_first + next_second) / 3.0
		_add_colored_triangle(surface, center, corner_a, corner_b, color)


func _create_map_object_debug_geometry() -> void:
	var object_section: Dictionary = scene_data.get("objects", {})
	var records: Array = object_section.get("records", [])
	var walls: Array[Dictionary] = []
	var doors: Array[Dictionary] = []
	var scenery: Array[Dictionary] = []
	var items: Array[Dictionary] = []
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
			"item":
				items.append(record)

	debug_object_counts["wall"] = walls.size()
	debug_object_counts["door"] = doors.size()
	debug_object_counts["scenery"] = scenery.size()
	debug_object_counts["item"] = items.size()
	wall_profile_match_count = 0
	for wall in walls:
		if not _art_profile_for_record(wall).is_empty():
			wall_profile_match_count += 1
	_create_wall_topology_mesh(walls)
	_create_object_instances("DebugDoors", doors, Vector3(0.9, 2.1, 0.18), Color("d18152"))
	_create_door_art_overlays(doors)
	var billboard_records: Array[Dictionary] = []
	billboard_records.append_array(scenery)
	billboard_records.append_array(items)
	var rendered_scenery := _create_scenery_art_overlays(billboard_records)
	var fallback_scenery: Array[Dictionary] = []
	for record in billboard_records:
		var instance_id := int(record["instance_id"])
		if not rendered_scenery.has(instance_id) and not _is_hidden_scenery(record):
			fallback_scenery.append(record)
	_create_object_instances(
		"DebugSceneryFallback",
		fallback_scenery,
		Vector3(0.48, 1.1, 0.48),
		Color("638a68")
	)


func _create_wall_topology_mesh(records: Array[Dictionary]) -> void:
	var records_by_elevation := {}
	for record in records:
		if String(_art_profile_for_record(record).get("render_mode", "geometry")) == "hidden":
			continue
		var elevation := int(record["elevation"])
		if not records_by_elevation.has(elevation):
			records_by_elevation[elevation] = []
		records_by_elevation[elevation].append(record)

	wall_mesh_face_count = 0
	wall_mesh_elevation_count = records_by_elevation.size()
	for elevation_value in records_by_elevation:
		var elevation := int(elevation_value)
		var occupied_cells := {}
		var records_by_material := {}
		for record_value in records_by_elevation[elevation]:
			var record: Dictionary = record_value
			occupied_cells[int(record["hex_index"])] = true
			var material_key := _wall_material_key(record)
			if not records_by_material.has(material_key):
				records_by_material[material_key] = []
			records_by_material[material_key].append(record)

		for material_key_value in records_by_material:
			var material_key := String(material_key_value)
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			_add_wall_cell_volume(
				surface,
				records_by_material[material_key],
				elevation,
				occupied_cells
			)
			surface.generate_normals()
			var mesh := surface.commit()
			if mesh == null:
				continue
			var material := ShaderMaterial.new()
			material.shader = StoneWallShader if material_key == "stone" else CaveWallShader
			mesh.surface_set_material(0, material)
			var instance := MeshInstance3D.new()
			instance.name = "WallTopology%sElevation%d" % [material_key.capitalize(), elevation]
			instance.mesh = mesh
			_get_elevation_root(elevation).add_child(instance)


func _wall_material_key(record: Dictionary) -> String:
	var art: Dictionary = record.get("art", {})
	var art_path := String(art.get("path", "")).replace("\\", "/").to_lower()
	return "stone" if art_path.begins_with("art/walls/temple") else "cave"


func _add_wall_cell_volume(
	surface: SurfaceTool,
	records: Array,
	elevation: int,
	occupied_cells: Dictionary
) -> void:
	var records_by_cell := {}
	for record_value in records:
		var record: Dictionary = record_value
		records_by_cell[int(record["hex_index"])] = record
	for tile_value in records_by_cell:
		var tile := int(tile_value)
		var center := Coordinates.hex_index_to_world(tile, elevation)
		var color := _debug_wall_color(records_by_cell[tile])
		for direction_index in 6:
			var neighbor := Coordinates.tile_in_direction(tile, direction_index)
			if neighbor != tile and occupied_cells.has(neighbor):
				continue
			var outward := Coordinates.direction_to_world(tile, direction_index)
			var tangent := Vector3(-outward.z, 0.0, outward.x)
			var face_center := center + outward * 0.5
			var half_side := 0.292
			var start := face_center - tangent * half_side
			var end := face_center + tangent * half_side
			var start_top := start + Vector3.UP * Coordinates.ELEVATION_HEIGHT
			var end_top := end + Vector3.UP * Coordinates.ELEVATION_HEIGHT
			_add_colored_triangle(surface, start, end_top, end, color)
			_add_colored_triangle(surface, start, start_top, end_top, color)
			wall_mesh_face_count += 2


func _add_colored_triangle(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	color: Color
) -> void:
	surface.set_color(color)
	surface.add_vertex(a)
	surface.set_color(color)
	surface.add_vertex(b)
	surface.set_color(color)
	surface.add_vertex(c)


func _debug_wall_color(record: Dictionary) -> Color:
	var profile := _art_profile_for_record(record)
	if profile.has("albedo"):
		return Color(String(profile["albedo"]))
	var art: Dictionary = record.get("art", {})
	var average_rgb: Array = art.get("opaque_average_rgb", [])
	if average_rgb.size() == 3:
		var average_color := Color(
			float(average_rgb[0]) / 255.0,
			float(average_rgb[1]) / 255.0,
			float(average_rgb[2]) / 255.0,
			1.0
		)
		return Color.from_hsv(
			average_color.h,
			average_color.s,
			maxf(average_color.v, 0.22),
			1.0
		)
	var fid := int(record.get("fid", 0))
	var wall_art_index := fid & 0xFFF
	var hue := fmod(0.56 + float(wall_art_index % 11) * 0.008, 1.0)
	var value := 0.42 + float(wall_art_index % 4) * 0.035
	return Color.from_hsv(hue, 0.22, value, 1.0)


func _art_profile_for_record(record: Dictionary) -> Dictionary:
	var kind := String(record.get("kind", ""))
	var art: Dictionary = record.get("art", {})
	var art_path := String(art.get("path", "")).to_lower()
	for profile_value in art_profiles:
		var profile: Dictionary = profile_value
		if kind != String(profile.get("kind", "")):
			continue
		var prefix := String(profile.get("art_path_prefix", "")).to_lower()
		if not prefix.is_empty() and art_path.begins_with(prefix):
			return profile
	return {}


func _create_object_instances(
	node_name: String,
	records: Array[Dictionary],
	size: Vector3,
	color: Color
) -> void:
	if records.is_empty():
		return
	var records_by_elevation := {}
	for record in records:
		var elevation := int(record["elevation"])
		if not records_by_elevation.has(elevation):
			records_by_elevation[elevation] = []
		records_by_elevation[elevation].append(record)

	for elevation_value in records_by_elevation:
		var elevation := int(elevation_value)
		var layer_records: Array = records_by_elevation[elevation]
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		mesh.material = material

		var multi_mesh := MultiMesh.new()
		multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
		multi_mesh.use_colors = true
		multi_mesh.mesh = mesh
		multi_mesh.instance_count = layer_records.size()
		for index in layer_records.size():
			var record: Dictionary = layer_records[index]
			var instance_id := int(record["instance_id"])
			var tile := int(record["hex_index"])
			var rotation := int(record["rotation"])
			var direction := Coordinates.direction_to_world(tile, rotation)
			var yaw := atan2(-direction.x, -direction.z)
			var basis := Basis(Vector3.UP, yaw).scaled(size)
			var position := Coordinates.hex_index_to_world(tile, elevation)
			position.y += size.y * 0.5
			var base_transform := Transform3D(basis, position)
			var record_color := _record_source_color(record, color)
			multi_mesh.set_instance_transform(index, base_transform)
			multi_mesh.set_instance_color(index, record_color)
			object_visuals[instance_id] = {
				"multi_mesh": multi_mesh,
				"index": index,
				"base_transform": base_transform,
			}
			object_instance_colors[instance_id] = record_color

		var instances := MultiMeshInstance3D.new()
		instances.name = "%sElevation%d" % [node_name, elevation]
		instances.multimesh = multi_mesh
		_get_elevation_root(elevation).add_child(instances)


func _record_source_color(record: Dictionary, fallback: Color) -> Color:
	var art: Dictionary = record.get("art", {})
	var average_rgb: Array = art.get("opaque_average_rgb", [])
	if average_rgb.size() != 3:
		return fallback
	var color := Color(
		float(average_rgb[0]) / 255.0,
		float(average_rgb[1]) / 255.0,
		float(average_rgb[2]) / 255.0,
		1.0
	)
	return Color.from_hsv(color.h, color.s, maxf(color.v, 0.24), 1.0)


func _create_door_art_overlays(records: Array[Dictionary]) -> void:
	var map_key := _map_stem(String(scene_data["map"]["name"]))
	door_art_overlay_count = 0
	for record in records:
		var art: Dictionary = record.get("art", {})
		var source_path := String(art.get("path", ""))
		var frame: Dictionary = art.get("frame", {})
		var frame_count := int(frame.get("frame_count", 1))
		if source_path.is_empty() or frame_count <= 0:
			continue
		var normalized_path := source_path.replace("\\", "/").to_lower()
		var file_stem := normalized_path.get_file().get_basename()
		var art_type := String(art.get("type", "scenery")).to_lower()
		var textures: Array[Texture2D] = []
		for frame_index in frame_count:
			var cache_path := (
				"res://../artifacts/art-cache/%s/%s/%s-r0-f%d.png" % [
					map_key,
					art_type,
					file_stem,
					frame_index,
				]
			)
			var texture := _load_cached_image_texture(cache_path)
			if texture == null:
				textures.clear()
				break
			textures.append(texture)
		if textures.is_empty():
			continue

		var material := StandardMaterial3D.new()
		material.albedo_texture = textures[0]
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.5
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.roughness = 0.9
		var quad := QuadMesh.new()
		quad.size = Vector2(1.35, 2.2)
		quad.material = material
		var instance := MeshInstance3D.new()
		var instance_id := int(record["instance_id"])
		instance.name = "DoorArt%d" % instance_id
		instance.mesh = quad
		var tile := int(record["hex_index"])
		var elevation := int(record["elevation"])
		var direction := Coordinates.direction_to_world(tile, int(record["rotation"]))
		var tangent := Vector3(direction.z, 0.0, -direction.x)
		instance.transform = Transform3D(
			Basis(tangent, Vector3.UP, direction),
			Coordinates.hex_index_to_world(tile, elevation) + Vector3.UP * 1.1
		)
		_get_elevation_root(elevation).add_child(instance)
		door_art_overlays[instance_id] = {
			"instance": instance,
			"material": material,
			"textures": textures,
			"current_frame": 0,
		}
		door_art_overlay_count += 1
		_refresh_door_art_frame(instance_id)


func _create_scenery_art_overlays(records: Array[Dictionary]) -> Dictionary:
	var rendered := {}
	var map_key := _map_stem(String(scene_data["map"]["name"]))
	prop_art_overlays.clear()
	prop_light_sources.clear()
	prop_art_overlay_count = 0
	for record in records:
		var profile := _art_profile_for_record(record)
		var render_mode := String(profile.get("render_mode", "hidden"))
		if render_mode == "hidden":
			var hidden_elevation := int(record["elevation"])
			var hidden_light_position := Coordinates.hex_index_to_world(
				int(record["hex_index"]),
				hidden_elevation
			) + Vector3.UP * 1.15
			_create_prop_light(record, profile, hidden_light_position)
			continue
		if render_mode.begins_with("proxy_"):
			if _create_proxy_visual(record, profile, render_mode):
				rendered[int(record["instance_id"])] = true
				prop_art_overlay_count += 1
			continue
		var art: Dictionary = record.get("art", {})
		var source_path := String(art.get("path", ""))
		var frame: Dictionary = art.get("frame", {})
		var frame_count := int(frame.get("frame_count", 1))
		if source_path.is_empty() or frame_count <= 0:
			continue
		var normalized_path := source_path.replace("\\", "/").to_lower()
		var file_stem := normalized_path.get_file().get_basename()
		var art_type := String(art.get("type", "scenery")).to_lower()
		var textures: Array[Texture2D] = []
		for frame_index in frame_count:
			var cache_path := (
				"res://../artifacts/art-cache/%s/%s/%s-r0-f%d.png" % [
					map_key,
					art_type,
					file_stem,
					frame_index,
				]
			)
			var texture := _load_cached_image_texture(cache_path)
			if texture == null:
				textures.clear()
				break
			textures.append(texture)
		if textures.is_empty():
			continue

		var pixels_per_meter := float(profile.get("pixels_per_meter", PROP_PIXELS_PER_METER))
		var width := float(textures[0].get_width()) / pixels_per_meter
		var height := float(textures[0].get_height()) / pixels_per_meter
		if height > PROP_MAX_HEIGHT:
			var scale_factor := PROP_MAX_HEIGHT / height
			width *= scale_factor
			height = PROP_MAX_HEIGHT
		var material := StandardMaterial3D.new()
		material.albedo_texture = textures[0]
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.34
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.roughness = 0.82
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.billboard_keep_scale = true
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		var quad := QuadMesh.new()
		quad.size = Vector2(width, height)
		quad.material = material
		var instance := MeshInstance3D.new()
		var instance_id := int(record["instance_id"])
		instance.name = "SceneryArt%d_%s" % [instance_id, file_stem]
		instance.mesh = quad
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var elevation := int(record["elevation"])
		var vertical_offset := float(profile.get("vertical_offset", 0.0))
		instance.position = Coordinates.hex_index_to_world(
			int(record["hex_index"]),
			elevation
		) + Vector3.UP * (height * 0.5 + vertical_offset)
		_get_elevation_root(elevation).add_child(instance)
		var initial_frame := posmod(int(record.get("frame", 0)), textures.size())
		material.albedo_texture = textures[initial_frame]
		prop_art_overlays.append({
			"instance_id": instance_id,
			"instance": instance,
			"material": material,
			"textures": textures,
			"frames_per_second": maxf(float(frame.get("frames_per_second", 1)), 1.0),
			"frame_offset": initial_frame,
			"current_frame": initial_frame,
			"animate": bool(profile.get("animate", false)),
		})
		object_visuals[instance_id] = {
			"kind": "prop",
			"instance": instance,
			"material": material,
		}
		object_instance_colors[instance_id] = Color.WHITE
		rendered[instance_id] = true
		prop_art_overlay_count += 1
		_create_prop_light(record, profile, instance.position)
	return rendered


func _create_proxy_visual(
	record: Dictionary,
	profile: Dictionary,
	render_mode: String
) -> bool:
	var art: Dictionary = record.get("art", {})
	var frame: Dictionary = art.get("frame", {})
	var source_width := float(frame.get("width", 32))
	var source_height := float(frame.get("height", 48))
	var pixels_per_meter := float(profile.get("pixels_per_meter", PROP_PIXELS_PER_METER))
	var width := clampf(source_width / pixels_per_meter, 0.25, 2.4)
	var height := clampf(source_height / pixels_per_meter, 0.25, 2.85)
	var depth := float(profile.get("depth", maxf(width * 0.55, 0.24)))
	width = float(profile.get("width", width))
	height = float(profile.get("height", height))
	var source_color := (
		Color(String(profile["albedo"]))
		if profile.has("albedo")
		else _record_source_color(record, Color("655848"))
	)
	var instance_id := int(record["instance_id"])
	var material: Material
	var selection_tint := true
	var instance: Node3D
	match render_mode:
		"proxy_fire_pit":
			instance = ProceduralProps.create_fire_pit(source_color)
			material = _create_standard_proxy_material(source_color)
			selection_tint = false
		"proxy_torch":
			instance = ProceduralProps.create_wall_torch(source_color)
			material = _create_standard_proxy_material(source_color)
			selection_tint = false
		"proxy_stairs":
			material = _create_stone_proxy_material(source_color)
			instance = ProceduralProps.create_stairs(material, width, depth, height)
			selection_tint = false
		"proxy_temple_gate":
			material = _create_stone_proxy_material(source_color)
			instance = ProceduralProps.create_temple_gate(material)
			selection_tint = false
		"proxy_temple_mass":
			material = _create_stone_proxy_material(source_color)
			instance = ProceduralProps.create_temple_mass(material, width, height, depth)
			selection_tint = false
		_:
			material = _create_standard_proxy_material(source_color)
			var mesh: PrimitiveMesh
			match render_mode:
				"proxy_tree":
					var cylinder := CylinderMesh.new()
					cylinder.height = maxf(height, 1.8)
					cylinder.top_radius = maxf(width * 0.10, 0.06)
					cylinder.bottom_radius = maxf(width * 0.18, 0.12)
					cylinder.radial_segments = 7
					mesh = cylinder
					height = cylinder.height
				"proxy_rock":
					var sphere := SphereMesh.new()
					sphere.radius = 0.5
					sphere.height = 1.0
					sphere.radial_segments = 10
					sphere.rings = 6
					mesh = sphere
				"proxy_vase":
					var vase := CylinderMesh.new()
					vase.height = maxf(height, 0.55)
					vase.top_radius = maxf(width * 0.28, 0.10)
					vase.bottom_radius = maxf(width * 0.42, 0.16)
					vase.radial_segments = 10
					mesh = vase
					height = vase.height
				_:
					var box := BoxMesh.new()
					box.size = Vector3(width, height, depth)
					mesh = box
			mesh.material = material
			if render_mode == "proxy_tree":
				instance = _create_tree_proxy(mesh, material, height, width, instance_id)
			else:
				var mesh_instance := MeshInstance3D.new()
				mesh_instance.mesh = mesh
				mesh_instance.position.y = height * 0.5
				if render_mode == "proxy_rock":
					mesh_instance.scale = Vector3(
						maxf(width, 0.35),
						maxf(height, 0.25),
						maxf(depth, 0.35)
					)
				instance = mesh_instance
	var elevation := int(record["elevation"])
	instance.name = "Proxy%d_%s" % [instance_id, render_mode]
	var direction := Coordinates.direction_to_world(
		int(record["hex_index"]),
		int(record.get("rotation", 0))
	)
	var right := Vector3(direction.z, 0.0, -direction.x)
	instance.position = (
		Coordinates.hex_index_to_world(int(record["hex_index"]), elevation)
		+ direction * float(profile.get("forward_offset", 0.0))
		+ right * float(profile.get("right_offset", 0.0))
		+ Vector3.UP * float(profile.get("vertical_offset", 0.0))
	)
	instance.rotation.y = atan2(-direction.x, -direction.z)
	_get_elevation_root(elevation).add_child(instance)
	object_visuals[instance_id] = {
		"kind": "prop",
		"instance": instance,
		"material": material,
		"selection_tint": selection_tint,
	}
	object_instance_colors[instance_id] = source_color.lightened(0.08)
	_create_prop_light(record, profile, instance.position)
	return true


func _create_standard_proxy_material(source_color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = source_color.lightened(0.08)
	material.roughness = 0.9
	return material


func _create_stone_proxy_material(source_color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = StoneWallShader
	material.set_shader_parameter("material_tint", source_color.lightened(0.24))
	return material


func _create_tree_proxy(
	trunk_mesh: PrimitiveMesh,
	material: Material,
	height: float,
	width: float,
	seed: int
) -> Node3D:
	var root := Node3D.new()
	var trunk := MeshInstance3D.new()
	trunk.name = "Trunk"
	trunk.mesh = trunk_mesh
	trunk.position.y = height * 0.5
	root.add_child(trunk)
	var phase := fmod(float(seed % 97) * 0.071, TAU)
	for branch_index in 5:
		var angle := float(branch_index) * TAU / 5.0 + phase
		var lift := 0.60 + 0.08 * float((seed + branch_index) % 3)
		var direction := Vector3(cos(angle) * 0.72, lift, sin(angle) * 0.72).normalized()
		var branch_length := height * (0.22 + float((seed + branch_index * 3) % 5) * 0.025)
		var branch_mesh := CylinderMesh.new()
		branch_mesh.height = branch_length
		branch_mesh.top_radius = maxf(width * 0.035, 0.025)
		branch_mesh.bottom_radius = maxf(width * 0.075, 0.045)
		branch_mesh.radial_segments = 6
		branch_mesh.material = material
		var branch := MeshInstance3D.new()
		branch.name = "Branch%d" % branch_index
		branch.mesh = branch_mesh
		var base := Vector3.UP * height * (0.42 + float(branch_index) * 0.095)
		branch.position = base + direction * branch_length * 0.5
		branch.basis = Basis(Quaternion(Vector3.UP, direction))
		root.add_child(branch)
	return root


func _is_hidden_scenery(record: Dictionary) -> bool:
	var profile := _art_profile_for_record(record)
	return String(profile.get("render_mode", "hidden")) == "hidden"


func _create_prop_light(record: Dictionary, profile: Dictionary, position: Vector3) -> void:
	var light_data: Dictionary = record.get("light", {})
	var distance := int(light_data.get("distance", 0))
	var intensity := int(light_data.get("intensity", 0))
	var profile_emits := bool(profile.get("emits_light", false))
	if distance <= 0 and profile_emits:
		distance = int(profile.get("fallback_light_distance", 4))
	if intensity <= 0 and profile_emits:
		intensity = int(profile.get("fallback_light_intensity", 49152))
	if distance <= 0 or intensity <= 0:
		return
	var light := OmniLight3D.new()
	light.name = "SourceLight%d" % int(record["instance_id"])
	light.position = position + Vector3.UP * float(profile.get("light_height_offset", 0.0))
	light.omni_range = maxf(2.0, float(distance) * 1.25)
	light.light_energy = clampf(float(intensity) / 65536.0 * 2.2, 0.35, 2.4)
	light.omni_attenuation = 1.6
	light.light_color = Color(String(profile.get("light_color", "ffd19a")))
	light.shadow_enabled = false
	light.visible = false
	_get_elevation_root(int(record["elevation"])).add_child(light)
	prop_light_sources.append({
		"node": light,
		"elevation": int(record["elevation"]),
		"base_energy": light.light_energy,
		"phase": float(int(record["instance_id"]) % 17) * 0.37,
	})


func _update_prop_animations(delta: float) -> void:
	prop_animation_time += delta
	for overlay in prop_art_overlays:
		if not bool(overlay.get("animate", false)):
			continue
		var textures: Array = overlay["textures"]
		if textures.size() <= 1:
			continue
		var frame_index := int(
			floor(prop_animation_time * float(overlay["frames_per_second"]))
			+ int(overlay["frame_offset"])
		) % textures.size()
		if frame_index == int(overlay["current_frame"]):
			continue
		var material: StandardMaterial3D = overlay["material"]
		material.albedo_texture = textures[frame_index]
		overlay["current_frame"] = frame_index


func _refresh_prop_lights() -> void:
	if player == null:
		return
	var player_elevation := int(player.logical_state["elevation"])
	var ranked: Array[Dictionary] = []
	for source in prop_light_sources:
		var light: OmniLight3D = source["node"]
		light.visible = false
		if int(source["elevation"]) != player_elevation:
			continue
		ranked.append({
			"source": source,
			"distance_squared": light.global_position.distance_squared_to(player.global_position),
		})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance_squared"]) < float(b["distance_squared"])
	)
	active_prop_light_count = mini(PROP_LIGHT_LIMIT, ranked.size())
	for index in active_prop_light_count:
		var source: Dictionary = ranked[index]["source"]
		var light: OmniLight3D = source["node"]
		light.visible = true
		light.light_energy = float(source["base_energy"])


func _load_cached_image_texture(path: String) -> Texture2D:
	if image_texture_cache.has(path):
		return image_texture_cache[path]
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	image_texture_cache[path] = texture
	return texture


func _create_map_blocking_collisions() -> void:
	var collision_section: Dictionary = scene_data.get("collision", {})
	var records: Array = collision_section.get("blocking_hexes", [])
	var bodies_by_elevation := {}
	var shared_shape := CylinderShape3D.new()
	shared_shape.radius = BLOCKING_COLLIDER_RADIUS
	shared_shape.height = BLOCKING_COLLIDER_HEIGHT
	for value in records:
		var record: Dictionary = value
		var elevation := int(record["elevation"])
		if not bodies_by_elevation.has(elevation):
			var body := StaticBody3D.new()
			body.name = "FalloutBlockingHexesElevation%d" % elevation
			bodies_by_elevation[elevation] = body
			_get_elevation_root(elevation).add_child(body)
		var collision := CollisionShape3D.new()
		collision.shape = shared_shape
		collision.position = Coordinates.hex_index_to_world(
			int(record["hex_index"]),
			elevation
		)
		collision.position.y += BLOCKING_COLLIDER_HEIGHT * 0.5
		collision.set_meta("instance_ids", record.get("instance_ids", []))
		collision.set_meta("object_ids", record.get("object_ids", []))
		collision.set_meta("hex_index", int(record["hex_index"]))
		collision.set_meta("elevation", elevation)
		var elevation_body: StaticBody3D = bodies_by_elevation[elevation]
		elevation_body.add_child(collision)
		for instance_id_value in record.get("instance_ids", []):
			var instance_id := int(instance_id_value)
			if not object_collision_shapes.has(instance_id):
				object_collision_shapes[instance_id] = []
			object_collision_shapes[instance_id].append(collision)
	blocking_collision_count = records.size()
	for instance_id in object_collision_shapes:
		_refresh_object_collisions(int(instance_id))


func _debug_floor_color(floor_id: int) -> Color:
	if floor_id == 0:
		return Color("20282a")
	var hue := fmod(0.24 + float(floor_id % 17) * 0.006, 1.0)
	var value := 0.31 + float(floor_id % 5) * 0.025
	return Color.from_hsv(hue, 0.18, value, 1.0)


func _debug_ceiling_color(roof_id: int) -> Color:
	var hue := fmod(0.08 + float(roof_id % 13) * 0.007, 1.0)
	var value := 0.24 + float(roof_id % 5) * 0.018
	return Color.from_hsv(hue, 0.24, value, 1.0)


func _count_rendered_floor_cells() -> int:
	var count := 0
	for layer_value in scene_data["tile_grid"]["layers"]:
		var layer: Dictionary = layer_value
		for floor_id in layer["floor_ids"]:
			if int(floor_id) != 1:
				count += 1
	return count


func _count_floor_instances() -> int:
	var count := 0
	for instances in floor_instances:
		count += instances.multimesh.instance_count
	return count


func _count_rendered_ceiling_cells() -> int:
	var count := 0
	for layer_value in scene_data["tile_grid"]["layers"]:
		var layer: Dictionary = layer_value
		var layer_roof_count := 0
		for roof_id in layer["roof_ids"]:
			if int(roof_id) != 1:
				layer_roof_count += 1
		if layer_roof_count > 0:
			count += layer_roof_count
		elif ceiling_strategy == "floor_footprint":
			for floor_id in layer["floor_ids"]:
				if int(floor_id) != 1:
					count += 1
	return count


func _count_ceiling_instances() -> int:
	var count := 0
	for instances in ceiling_instances:
		count += instances.multimesh.instance_count
	return count


func _count_wall_elevations() -> int:
	var elevations := {}
	for record_value in scene_data["objects"]["records"]:
		var record: Dictionary = record_value
		if (
			String(record.get("kind", "")) == "wall"
			and String(_art_profile_for_record(record).get("render_mode", "geometry")) != "hidden"
		):
			elevations[int(record["elevation"])] = true
	return elevations.size()


func _count_visible_elevations() -> int:
	var count := 0
	for root_value in elevation_roots.values():
		var root: Node3D = root_value
		if root.visible:
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
	_refresh_ceiling_visibility()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = (
			Input.MOUSE_MODE_CAPTURED
			if mode == CAMERA_FPP and not bridge_authoritative
			else Input.MOUSE_MODE_VISIBLE
		)
	_update_hud()


func _refresh_ceiling_visibility() -> void:
	for instances in ceiling_instances:
		instances.visible = active_camera_mode == CAMERA_FPP
	for instance in inferred_ceiling_instances:
		instance.visible = active_camera_mode == CAMERA_FPP


func _ceilings_have_visibility(expected: bool) -> bool:
	for instances in ceiling_instances:
		if instances.visible != expected:
			return false
	for instance in inferred_ceiling_instances:
		if instance.visible != expected:
			return false
	return true


func _update_cameras() -> void:
	if player == null or iso_camera == null or fpp_camera == null:
		return
	var player_position: Vector3 = player.global_position
	iso_camera.global_position = player_position + Vector3(14.0, 18.0, 14.0)
	iso_camera.look_at(player_position, Vector3.UP)
	fpp_camera.global_position = player.get_eye_position()
	fpp_camera.global_rotation = Vector3(player.view_pitch, player.view_yaw, 0.0)


func _on_player_state_changed(state: Dictionary) -> void:
	_set_active_elevation(int(state["elevation"]))
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
	player.set_selection(-1)
	interaction_status = "CE map snapshot: %s" % bridge_map_name
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
	door_art_overlays.clear()
	prop_art_overlays.clear()
	prop_light_sources.clear()
	tile_art_by_id.clear()
	image_texture_cache.clear()
	door_art_overlay_count = 0
	prop_art_overlay_count = 0
	active_prop_light_count = 0
	debug_object_counts = {"wall": 0, "door": 0, "scenery": 0, "item": 0}
	wall_mesh_face_count = 0
	wall_mesh_elevation_count = 0
	wall_profile_match_count = 0
	blocking_collision_count = 0
	floor_instances.clear()
	ceiling_instances.clear()
	inferred_ceiling_instances.clear()
	inferred_ceiling_cell_count = 0
	inferred_ceiling_component_count = 0
	ceiling_strategy = "roof_tiles"
	elevation_roots.clear()
	_create_floor_grid()
	_create_ceiling_grid()
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
	var is_snapshot := bool(event.get("snapshot", false))
	var local_state: Dictionary = object_states[instance_id]
	local_state["activated"] = false if is_snapshot else true
	local_state["open"] = bool(state.get("open", false))
	local_state["locked"] = bool(state.get("locked", false))
	local_state["jammed"] = bool(state.get("jammed", false))
	local_state["blocks_movement"] = bool(state.get("blocks_movement", true))
	if not is_snapshot:
		player.set_selection(instance_id)
	_refresh_object_colors()
	_refresh_object_collisions(instance_id)
	bridge_events_applied += 1
	bridge_parity_status = "%s door %d %s" % [
		"SYNCED" if is_snapshot else "APPLIED",
		instance_id,
		"OPEN" if bool(local_state["open"]) else "CLOSED",
	]
	interaction_status = "CE door %s instance %d: %s%s%s" % [
		"snapshot" if is_snapshot else "delta",
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
		"snapshot": is_snapshot,
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
		if String(visual.get("kind", "multimesh")) == "prop":
			if not bool(visual.get("selection_tint", true)):
				continue
			if object_states.has(instance_id) and bool(object_states[instance_id]["activated"]):
				color = Color("f4d35e")
			elif int(instance_id) == selected_id:
				color = Color("8ff5ff")
			var prop_material: Material = visual["material"]
			if prop_material is StandardMaterial3D:
				prop_material.albedo_color = color
			elif prop_material is ShaderMaterial:
				prop_material.set_shader_parameter("material_tint", color)
			continue
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
		_refresh_door_art_frame(int(instance_id))


func _refresh_door_art_frame(instance_id: int) -> void:
	if not door_art_overlays.has(instance_id):
		return
	var overlay: Dictionary = door_art_overlays[instance_id]
	var textures: Array = overlay["textures"]
	var frame_index := 0
	if (
		object_states.has(instance_id)
		and bool(object_states[instance_id].get("open", false))
	):
		frame_index = textures.size() - 1
	var material: StandardMaterial3D = overlay["material"]
	material.albedo_texture = textures[frame_index]
	overlay["current_frame"] = frame_index
	var instance: MeshInstance3D = overlay["instance"]
	instance.visible = frame_index == 0 or textures.size() > 1


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
		+ "walls %d  doors %d  scenery %d  items %d  props %d  lights %d  blocking %d  selected %d\n"
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
		debug_object_counts["item"],
		prop_art_overlay_count,
		active_prop_light_count,
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
	assert(_count_floor_instances() == _count_rendered_floor_cells())
	assert(_count_floor_instances() >= 2)
	assert(_count_ceiling_instances() == _count_rendered_ceiling_cells())
	assert(elevation_roots.has(active_elevation))
	var visible_elevation_count := 0
	for elevation_value in elevation_roots:
		var elevation := int(elevation_value)
		var root: Node3D = elevation_roots[elevation]
		if root.visible:
			visible_elevation_count += 1
		assert(root.visible == (elevation == active_elevation))
	assert(visible_elevation_count == 1)
	var object_section: Dictionary = scene_data["objects"]
	var object_records: Array = object_section["records"]
	assert(object_records.size() == int(object_section["exported_count"]))
	assert(int(object_section["wall_count"]) >= 2)
	assert(debug_object_counts["wall"] == int(object_section["wall_count"]))
	assert((wall_mesh_face_count > 0) == (wall_mesh_elevation_count > 0))
	assert(wall_mesh_elevation_count == _count_wall_elevations())
	assert(wall_profile_match_count <= debug_object_counts["wall"])
	assert(debug_object_counts["door"] == int(object_section["door_count"]))
	assert(door_art_overlay_count <= debug_object_counts["door"])
	assert(
		prop_art_overlay_count
		<= debug_object_counts["scenery"] + debug_object_counts["item"]
	)
	assert(debug_object_counts["scenery"] == int(object_section["scenery_count"]))
	assert(debug_object_counts["item"] == int(object_section.get("item_count", 0)))
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
	assert(_ceilings_have_visibility(true))
	assert(player.get_state_snapshot() == state_before)
	var expected_eye: Vector3 = player.global_position + Vector3.UP * player.eye_height
	assert(fpp_camera.global_position.distance_to(expected_eye) < 0.00001)
	assert(Vector2(fpp_camera.global_position.x, fpp_camera.global_position.z).distance_to(
		Vector2(player.global_position.x, player.global_position.z)
	) < 0.00001)
	_set_camera_mode(CAMERA_ISO)
	assert(_ceilings_have_visibility(false))
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

	var tests_door_state := String(target.get("kind", "")) == "door"
	var target_payload := {
		"instance_id": target_instance_id,
		"object_id": int(target["object_id"]),
		"pid": int(target["pid"]),
		"hex_index": int(target["hex_index"]),
		"elevation": int(target["elevation"]),
		"rotation": int(target["rotation"]),
	}
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
	]
	if tests_door_state:
		events.append({
			"schema": "fo2remix.bridge-v1",
			"sequence": events.size(),
			"event": "object_state",
			"snapshot": true,
			"target": target_payload.duplicate(true),
			"state": {
				"kind": "door",
				"open": false,
				"locked": false,
				"jammed": false,
				"blocks_movement": true,
			},
		})
	var initial_event_count := events.size()
	var moved_event_index := events.size()
	events.append({
		"schema": "fo2remix.bridge-v1",
		"sequence": events.size(),
		"event": "player_moved",
		"player": {
			"object_id": 18000,
			"pid": 16777216,
			"hex_index": moved_hex,
			"elevation": int(spawn["elevation"]),
			"rotation": 2,
		},
	})
	var interaction_event_index := events.size()
	events.append({
		"schema": "fo2remix.bridge-v1",
		"sequence": events.size(),
		"event": "interaction",
		"actor": {
			"object_id": 18000,
			"pid": 16777216,
			"hex_index": moved_hex,
			"elevation": int(spawn["elevation"]),
			"rotation": 2,
		},
		"target": target_payload.duplicate(true),
		"result": 0,
	})
	if tests_door_state:
		events.append({
			"schema": "fo2remix.bridge-v1",
			"sequence": events.size(),
			"event": "object_state",
			"snapshot": false,
			"target": target_payload.duplicate(true),
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
	for index in initial_event_count:
		trace_file.store_line(JSON.stringify(events[index]))
	trace_file.close()
	state_bridge.poll_now()
	assert(
		state_bridge.events_received == initial_event_count,
		"Godot did not consume initial bridge events"
	)
	if tests_door_state:
		assert(not bool(object_states[target_instance_id]["open"]))
		assert(bool(object_states[target_instance_id]["blocks_movement"]))
		assert(not bool(object_states[target_instance_id]["activated"]))
		assert(int(player.logical_state["selection"]) == -1)

	var moved_line := JSON.stringify(events[moved_event_index])
	var split_index := int(moved_line.length() / 2)
	var append_file := FileAccess.open(trace_path, FileAccess.READ_WRITE)
	assert(append_file != null, "Could not append partial bridge probe event")
	append_file.seek_end()
	append_file.store_string(moved_line.substr(0, split_index))
	append_file.close()
	state_bridge.poll_now()
	assert(
		state_bridge.events_received == initial_event_count,
		"Partial JSONL event was consumed too early"
	)

	append_file = FileAccess.open(trace_path, FileAccess.READ_WRITE)
	assert(append_file != null, "Could not finish partial bridge probe event")
	append_file.seek_end()
	append_file.store_line(moved_line.substr(split_index))
	append_file.store_line(JSON.stringify(events[interaction_event_index]))
	if tests_door_state:
		append_file.store_line(JSON.stringify(events[events.size() - 1]))
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
		if door_art_overlays.has(target_instance_id):
			var overlay: Dictionary = door_art_overlays[target_instance_id]
			assert(int(overlay["current_frame"]) == overlay["textures"].size() - 1)
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
		"door_snapshot_closed_verified": tests_door_state,
		"door_open": bool(object_states[target_instance_id].get("open", false)),
		"door_collision_disabled": (
			tests_door_state
			and not bool(object_states[target_instance_id].get("blocks_movement", true))
		),
		"door_art_open_frame": (
			int(door_art_overlays[target_instance_id]["current_frame"])
			if tests_door_state and door_art_overlays.has(target_instance_id)
			else -1
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
		"schema": "fo2remix.godot-scene-contract-v5",
		"fallout2_ce_commit": FALLOUT2_CE_COMMIT,
		"scene_schema": scene_data["schema"],
		"map": state["map_name"],
		"floor_instances": _count_floor_instances(),
		"floor_art_families": tile_art_by_id.size(),
		"ceiling_instances": _count_ceiling_instances(),
		"inferred_ceiling_cells": inferred_ceiling_cell_count,
		"inferred_ceiling_components": inferred_ceiling_component_count,
		"ceiling_strategy": ceiling_strategy,
		"ceilings_visible_in_fpp": active_camera_mode == CAMERA_FPP,
		"active_elevation": active_elevation,
		"visible_elevation_count": _count_visible_elevations(),
		"map_objects": {
			"declared": int(scene_data["objects"]["declared_count"]),
			"walls": debug_object_counts["wall"],
			"wall_mesh_faces": wall_mesh_face_count,
			"wall_mesh_elevations": wall_mesh_elevation_count,
			"wall_profile_matches": wall_profile_match_count,
			"wall_material": (
				"mixed_procedural_temple_stone_and_cave_rock"
				if _map_stem(String(scene_data["map"]["name"])) == "arcaves"
				else "procedural_stone_from_source_palette"
			),
			"doors": debug_object_counts["door"],
			"door_art_overlays": door_art_overlay_count,
			"scenery": debug_object_counts["scenery"],
			"items": debug_object_counts["item"],
			"scenery_art_overlays": prop_art_overlay_count,
			"source_lights": prop_light_sources.size(),
			"active_light_budget": PROP_LIGHT_LIMIT,
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
