extends CharacterBody3D

signal motion_state_changed(snapshot: Dictionary)

@export_group("Movement")
@export var walk_speed := 2.8
@export var sprint_speed := 5.0
@export var acceleration := 18.0
@export var deceleration := 22.0
@export var gravity := 18.0

@export_group("View")
@export var mouse_sensitivity := 0.0022
@export var minimum_pitch_degrees := -85.0
@export var maximum_pitch_degrees := 85.0
@export var eye_height := 1.68

@export_group("Body")
@export var body_height := 1.75
@export var body_radius := 0.30
@export var create_debug_body := true

@export_group("Input actions")
@export var move_forward_action: StringName = &"move_forward"
@export var move_backward_action: StringName = &"move_backward"
@export var move_left_action: StringName = &"move_left"
@export var move_right_action: StringName = &"move_right"
@export var sprint_action: StringName = &"sprint"

var view_yaw := 0.0
var view_pitch := 0.0
var movement_enabled := true
var body_mesh: MeshInstance3D
var forward_marker: MeshInstance3D


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	floor_snap_length = 0.25
	floor_max_angle = deg_to_rad(50.0)
	_create_collision_shape()
	if create_debug_body:
		_create_debug_visuals()


func _physics_process(delta: float) -> void:
	if not movement_enabled:
		return
	var input_vector := Input.get_vector(
		move_left_action,
		move_right_action,
		move_forward_action,
		move_backward_action
	)
	apply_movement(input_vector, Input.is_action_pressed(sprint_action), delta)


func apply_movement(input_vector: Vector2, sprinting: bool, delta: float) -> void:
	var target_velocity := get_target_horizontal_velocity(input_vector, sprinting)
	var rate := acceleration if not target_velocity.is_zero_approx() else deceleration
	velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)

	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = -0.5
	else:
		velocity.y -= gravity * delta

	move_and_slide()
	_after_motion_step()
	motion_state_changed.emit(get_motion_snapshot())


func get_target_horizontal_velocity(input_vector: Vector2, sprinting: bool) -> Vector3:
	var clamped_input := input_vector.limit_length(1.0)
	var forward := get_forward_vector()
	var right := get_right_vector()
	var wish_direction := right * clamped_input.x + forward * -clamped_input.y
	if wish_direction.length_squared() > 1.0:
		wish_direction = wish_direction.normalized()
	var speed := sprint_speed if sprinting else walk_speed
	return wish_direction * speed


func add_mouse_look(relative_motion: Vector2) -> void:
	set_view_angles(
		view_yaw - relative_motion.x * mouse_sensitivity,
		view_pitch - relative_motion.y * mouse_sensitivity
	)


func set_view_angles(yaw: float, pitch: float) -> void:
	view_yaw = yaw
	view_pitch = clampf(
		pitch,
		deg_to_rad(minimum_pitch_degrees),
		deg_to_rad(maximum_pitch_degrees)
	)
	rotation.y = view_yaw
	_after_view_changed()
	motion_state_changed.emit(get_motion_snapshot())


func get_forward_vector() -> Vector3:
	return Vector3(-sin(view_yaw), 0.0, -cos(view_yaw)).normalized()


func get_right_vector() -> Vector3:
	return Vector3(cos(view_yaw), 0.0, -sin(view_yaw)).normalized()


func get_eye_position() -> Vector3:
	return global_position + Vector3.UP * eye_height


func set_first_person(enabled: bool) -> void:
	if body_mesh != null:
		body_mesh.visible = not enabled
	if forward_marker != null:
		forward_marker.visible = not enabled


func get_motion_snapshot() -> Dictionary:
	return {
		"world_position": _vector_to_array(global_position),
		"velocity": _vector_to_array(velocity),
		"view_yaw": view_yaw,
		"view_pitch": view_pitch,
	}


func _after_motion_step() -> void:
	pass


func _after_view_changed() -> void:
	pass


func _create_collision_shape() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "PlayerCapsule"
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = body_radius
	capsule_shape.height = body_height
	collision.shape = capsule_shape
	collision.position.y = body_height * 0.5
	add_child(collision)


func _create_debug_visuals() -> void:
	body_mesh = MeshInstance3D.new()
	body_mesh.name = "DebugBody"
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = body_radius
	capsule_mesh.height = body_height
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color("ffd447")
	capsule_mesh.material = body_material
	body_mesh.mesh = capsule_mesh
	body_mesh.position.y = body_height * 0.5
	add_child(body_mesh)

	forward_marker = MeshInstance3D.new()
	forward_marker.name = "DebugForwardVector"
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.08, 0.08, 0.75)
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color("ff4d4d")
	marker_mesh.material = marker_material
	forward_marker.mesh = marker_mesh
	forward_marker.position = Vector3(0.0, 0.9, -0.55)
	add_child(forward_marker)


func _vector_to_array(vector: Vector3) -> Array[float]:
	return [vector.x, vector.y, vector.z]
