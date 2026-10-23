class_name FalloutProceduralProps
extends RefCounted


static func create_fire_pit(stone_color: Color) -> Node3D:
	var root := Node3D.new()
	var stone_material := _standard_material(stone_color.lightened(0.08), 0.96)
	for stone_index in 10:
		var angle := float(stone_index) * TAU / 10.0
		var stone_mesh := SphereMesh.new()
		stone_mesh.radius = 0.5
		stone_mesh.height = 1.0
		stone_mesh.radial_segments = 8
		stone_mesh.rings = 4
		var stone := _mesh_instance(stone_mesh, stone_material)
		stone.name = "RingStone%d" % stone_index
		stone.position = Vector3(cos(angle) * 0.46, 0.11, sin(angle) * 0.46)
		stone.scale = Vector3(0.31, 0.16, 0.23)
		stone.rotation.y = -angle
		root.add_child(stone)

	var coal_mesh := CylinderMesh.new()
	coal_mesh.height = 0.08
	coal_mesh.top_radius = 0.38
	coal_mesh.bottom_radius = 0.42
	coal_mesh.radial_segments = 12
	var coal := _mesh_instance(coal_mesh, _standard_material(Color("211510"), 1.0))
	coal.name = "Coals"
	coal.position.y = 0.10
	root.add_child(coal)

	_add_flame(root, Vector3(0.0, 0.47, 0.0), Vector3(0.26, 0.58, 0.26), Color("ff6a16"))
	_add_flame(root, Vector3(-0.11, 0.52, 0.02), Vector3(0.14, 0.72, 0.14), Color("ffc23a"))
	_add_flame(root, Vector3(0.12, 0.40, -0.03), Vector3(0.12, 0.42, 0.12), Color("ff8a1f"))
	return root


static func create_wall_torch(metal_color: Color) -> Node3D:
	var root := Node3D.new()
	var wood := _standard_material(metal_color.darkened(0.22), 0.92)
	var metal := _standard_material(Color("40362e"), 0.72)

	var handle_mesh := CylinderMesh.new()
	handle_mesh.height = 0.86
	handle_mesh.top_radius = 0.055
	handle_mesh.bottom_radius = 0.075
	handle_mesh.radial_segments = 8
	var handle := _mesh_instance(handle_mesh, wood)
	handle.name = "Handle"
	handle.position = Vector3(0.0, 1.16, 0.10)
	handle.rotation.x = deg_to_rad(-11.0)
	root.add_child(handle)

	var bracket_mesh := CylinderMesh.new()
	bracket_mesh.height = 0.38
	bracket_mesh.top_radius = 0.035
	bracket_mesh.bottom_radius = 0.035
	bracket_mesh.radial_segments = 8
	var bracket := _mesh_instance(bracket_mesh, metal)
	bracket.name = "WallBracket"
	bracket.position = Vector3(0.0, 0.90, 0.0)
	bracket.rotation.x = deg_to_rad(68.0)
	root.add_child(bracket)

	var cup_mesh := CylinderMesh.new()
	cup_mesh.height = 0.18
	cup_mesh.top_radius = 0.16
	cup_mesh.bottom_radius = 0.09
	cup_mesh.radial_segments = 10
	var cup := _mesh_instance(cup_mesh, metal)
	cup.name = "BrazierCup"
	cup.position = Vector3(0.0, 1.62, 0.20)
	root.add_child(cup)

	_add_flame(root, Vector3(0.0, 1.97, 0.20), Vector3(0.19, 0.54, 0.19), Color("ff7418"))
	_add_flame(root, Vector3(0.05, 2.04, 0.20), Vector3(0.10, 0.42, 0.10), Color("ffd34d"))
	return root


static func create_stairs(material: Material, width: float, depth: float, height: float) -> Node3D:
	var root := Node3D.new()
	var step_count := 7
	var step_depth := depth / float(step_count)
	var step_height := height / float(step_count)
	for step_index in step_count:
		var box_height := step_height * float(step_index + 1)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width, box_height, step_depth + 0.035)
		var step := _mesh_instance(mesh, material)
		step.name = "Step%d" % step_index
		step.position = Vector3(
			0.0,
			box_height * 0.5,
			depth * 0.5 - step_depth * (float(step_index) + 0.5)
		)
		root.add_child(step)
	return root


static func create_temple_exterior(material: Material) -> Node3D:
	# A single coherent blockout replaces the eight overlapping isometric
	# TEMPLE01-TEMPLE08 fragments. Local -Z points away from the entrance.
	var root := Node3D.new()
	root.name = "TempleExterior"
	var dark_material := _standard_material(Color("090807"), 1.0)
	var relief_material := _standard_material(Color("665040"), 0.94)

	# Raised base and deep building volume. These pieces share exact edges so
	# there are no gaps or z-fighting between independent sprite cards.
	_add_box(
		root,
		"Foundation",
		Vector3(16.8, 0.45, 10.8),
		Vector3(0.0, 0.225, 4.65),
		material
	)
	_add_box(
		root,
		"RaisedPlatform",
		Vector3(15.8, 0.75, 9.9),
		Vector3(0.0, 0.825, 4.45),
		material
	)
	_add_box(
		root,
		"TempleBody",
		Vector3(13.8, 5.7, 7.4),
		Vector3(0.0, 4.05, 5.15),
		material
	)

	# The stairs are real stepped geometry, not TEMPLE07/08 shadow artwork.
	_add_front_stairs(root, material, 5.2, 5.0, 1.2, 10)
	_add_stepped_rail(root, material, -3.15, "LeftStairRail")
	_add_stepped_rail(root, material, 3.15, "RightStairRail")

	# Cut the front silhouette into two masses and a lintel around a recessed
	# portal. The dark plane sits behind the opening, never in the same plane.
	var portal_width := 2.8
	var portal_height := 3.45
	var facade_depth := 1.25
	_add_box(
		root,
		"LeftFacade",
		Vector3(4.55, 5.7, facade_depth),
		Vector3(-3.675, 4.05, -0.025),
		material
	)
	_add_box(
		root,
		"RightFacade",
		Vector3(4.55, 5.7, facade_depth),
		Vector3(3.675, 4.05, -0.025),
		material
	)
	_add_box(
		root,
		"PortalLintel",
		Vector3(portal_width, 2.25, facade_depth),
		Vector3(0.0, 5.775, -0.025),
		material
	)
	_add_box(
		root,
		"PortalRecess",
		Vector3(portal_width - 0.18, portal_height, 0.12),
		Vector3(0.0, 1.2 + portal_height * 0.5, 1.38),
		dark_material
	)
	_add_box(
		root,
		"FrontCornice",
		Vector3(14.7, 0.34, 1.55),
		Vector3(0.0, 6.73, -0.02),
		material
	)
	_add_box(
		root,
		"RoofCap",
		Vector3(14.8, 0.42, 9.5),
		Vector3(0.0, 7.02, 4.45),
		material
	)

	# Twin battered towers reproduce the dominant silhouette visible in the
	# original location without pretending that a single isometric frame is a
	# complete 3D mesh.
	_add_tapered_tower(root, material, Vector3(-5.35, 4.65, -0.15), "LeftTower")
	_add_tapered_tower(root, material, Vector3(5.35, 4.65, -0.15), "RightTower")

	# A shallow geometric relief gives the entrance a readable focal point from
	# FPP while retaining depth and shadows from oblique angles.
	_add_sphere(
		root,
		"EntranceRelief",
		Vector3(1.85, 1.55, 0.32),
		Vector3(0.0, 5.15, -0.71),
		relief_material
	)
	_add_box(
		root,
		"ReliefBrow",
		Vector3(2.3, 0.30, 0.34),
		Vector3(0.0, 5.52, -0.92),
		relief_material
	)
	_add_box(
		root,
		"LeftWing",
		Vector3(1.6, 2.4, 5.8),
		Vector3(-7.25, 2.4, 3.4),
		material
	)
	_add_box(
		root,
		"RightWing",
		Vector3(1.6, 2.4, 5.8),
		Vector3(7.25, 2.4, 3.4),
		material
	)
	return root


static func _add_front_stairs(
	root: Node3D,
	material: Material,
	width: float,
	depth: float,
	height: float,
	step_count: int
) -> void:
	var step_depth := depth / float(step_count)
	var step_height := height / float(step_count)
	for step_index in step_count:
		var box_height := step_height * float(step_index + 1)
		var step := BoxMesh.new()
		step.size = Vector3(width, box_height, step_depth + 0.04)
		var instance := _mesh_instance(step, material)
		instance.name = "EntranceStep%02d" % step_index
		instance.position = Vector3(
			0.0,
			box_height * 0.5,
			-depth + step_depth * (float(step_index) + 0.5)
		)
		root.add_child(instance)


static func _add_stepped_rail(
	root: Node3D,
	material: Material,
	x_position: float,
	name_prefix: String
) -> void:
	var segment_count := 5
	for segment_index in segment_count:
		var segment_height := 0.50 + float(segment_index) * 0.24
		_add_box(
			root,
			"%s%02d" % [name_prefix, segment_index],
			Vector3(0.72, segment_height, 1.04),
			Vector3(
				x_position,
				segment_height * 0.5,
				-4.48 + float(segment_index) * 1.0
			),
			material
		)


static func _add_tapered_tower(
	root: Node3D,
	material: Material,
	position: Vector3,
	name: String
) -> void:
	var tower_mesh := CylinderMesh.new()
	tower_mesh.height = 6.9
	tower_mesh.top_radius = 1.18
	tower_mesh.bottom_radius = 1.82
	tower_mesh.radial_segments = 16
	var tower := _mesh_instance(tower_mesh, material)
	tower.name = name
	tower.position = position
	root.add_child(tower)

	var cap_mesh := CylinderMesh.new()
	cap_mesh.height = 0.34
	cap_mesh.top_radius = 1.32
	cap_mesh.bottom_radius = 1.48
	cap_mesh.radial_segments = 16
	var cap := _mesh_instance(cap_mesh, material)
	cap.name = "%sCap" % name
	cap.position = position + Vector3.UP * 3.55
	root.add_child(cap)


static func create_temple_gate(material: Material) -> Node3D:
	var root := Node3D.new()
	var gate_width := 4.8
	var gate_height := 3.8
	var gate_depth := 0.88
	var opening_width := 1.72
	var opening_height := 2.62
	var pillar_width := (gate_width - opening_width) * 0.5
	_add_box(
		root,
		"LeftGateMass",
		Vector3(pillar_width, gate_height, gate_depth),
		Vector3(-(opening_width + pillar_width) * 0.5, gate_height * 0.5, 0.0),
		material
	)
	_add_box(
		root,
		"RightGateMass",
		Vector3(pillar_width, gate_height, gate_depth),
		Vector3((opening_width + pillar_width) * 0.5, gate_height * 0.5, 0.0),
		material
	)
	_add_box(
		root,
		"GateLintel",
		Vector3(opening_width, gate_height - opening_height, gate_depth),
		Vector3(0.0, opening_height + (gate_height - opening_height) * 0.5, 0.0),
		material
	)
	_add_box(
		root,
		"TopCornice",
		Vector3(gate_width + 0.28, 0.20, gate_depth + 0.16),
		Vector3(0.0, gate_height - 0.10, 0.0),
		material
	)
	var darkness := _standard_material(Color("090807"), 1.0)
	_add_box(
		root,
		"DoorwayDarkness",
		Vector3(opening_width - 0.10, opening_height - 0.06, 0.08),
		Vector3(0.0, (opening_height - 0.06) * 0.5, -gate_depth * 0.47),
		darkness
	)
	return root


static func create_temple_mass(
	material: Material,
	width: float,
	height: float,
	depth: float
) -> Node3D:
	var root := Node3D.new()
	_add_box(
		root,
		"FacadeMass",
		Vector3(width, height, depth),
		Vector3(0.0, height * 0.5, 0.0),
		material
	)
	_add_box(
		root,
		"FacadeBase",
		Vector3(width + 0.16, 0.22, depth + 0.12),
		Vector3(0.0, 0.11, 0.0),
		material
	)
	_add_box(
		root,
		"FacadeCornice",
		Vector3(width + 0.20, 0.20, depth + 0.15),
		Vector3(0.0, height - 0.10, 0.0),
		material
	)
	return root


static func _add_flame(root: Node3D, position: Vector3, scale: Vector3, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.height = 1.0
	mesh.top_radius = 0.025
	mesh.bottom_radius = 0.46
	mesh.radial_segments = 9
	var flame := _mesh_instance(mesh, _emissive_material(color))
	flame.name = "Flame"
	flame.position = position
	flame.scale = scale
	root.add_child(flame)


static func _add_box(
	root: Node3D,
	name: String,
	size: Vector3,
	position: Vector3,
	material: Material
) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := _mesh_instance(mesh, material)
	instance.name = name
	instance.position = position
	root.add_child(instance)


static func _add_sphere(
	root: Node3D,
	name: String,
	scale: Vector3,
	position: Vector3,
	material: Material
) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 8
	var instance := _mesh_instance(mesh, material)
	instance.name = name
	instance.scale = scale
	instance.position = position
	root.add_child(instance)


static func _mesh_instance(mesh: PrimitiveMesh, material: Material) -> MeshInstance3D:
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	return instance


static func _standard_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


static func _emissive_material(color: Color) -> StandardMaterial3D:
	var material := _standard_material(color, 0.64)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.9
	return material
