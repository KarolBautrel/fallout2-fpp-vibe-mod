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
