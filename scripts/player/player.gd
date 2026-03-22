extends CharacterBody3D

# =========================================================
# CONFIG
# =========================================================
@export var camera: Camera3D
@export var pivot: Node3D

@export var move_speed: float = 10.0
@export var vertical_speed: float = 6.0
@export var rotation_speed: float = 8.0

# =========================================================
# NODES
# =========================================================
@onready var visual: Node3D = $AnimationLibrary_Godot_Standard/Rig/Skeleton3D
@onready var anim_player: AnimationPlayer = $AnimationLibrary_Godot_Standard/AnimationPlayer

# =========================================================
# STATE
# =========================================================
var input_dir: Vector3 = Vector3.ZERO

# =========================================================
# PHYSICS
# =========================================================
func _physics_process(delta: float) -> void:
	_read_input()
	_apply_movement(delta)
	_apply_rotation(delta)
	_update_animation()
	move_and_slide()

# =========================================================
# INPUT (camera-relative)
# =========================================================
func _read_input() -> void:
	input_dir = Vector3.ZERO
	var cam_forward = -camera.global_transform.basis.z
	var cam_right = camera.global_transform.basis.x
	
	cam_forward = cam_forward.normalized()
	cam_right = cam_right.normalized()

	if Input.is_action_pressed("move_forward"):
		input_dir += cam_forward
	if Input.is_action_pressed("move_back"):
		input_dir -= cam_forward
	if Input.is_action_pressed("move_right"):
		input_dir += cam_right
	if Input.is_action_pressed("move_left"):
		input_dir -= cam_right

	input_dir = input_dir.normalized()

	if Input.is_action_pressed("ui_accept"):
		input_dir.y = 1.0

# =========================================================
# MOVEMENT
# =========================================================
func _apply_movement(delta: float) -> void:
	var horizontal_dir = input_dir
	horizontal_dir.y = 0
	if horizontal_dir.length() > 0:
		velocity.x = horizontal_dir.normalized().x * move_speed
		velocity.z = horizontal_dir.normalized().z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

	velocity.y = input_dir.y * vertical_speed

# =========================================================
# ROTATION
# =========================================================
func _apply_rotation(delta: float) -> void:
	var horizontal_velocity = velocity
	horizontal_velocity.y = 0
	if horizontal_velocity.length() < 0.1:
		return

	var target_pos = global_position + horizontal_velocity
	var target_basis = Transform3D().looking_at(target_pos - global_position, Vector3.UP).basis
	visual.global_transform.basis = visual.global_transform.basis.slerp(target_basis, rotation_speed * delta)

# =========================================================
# ANIMATION
# =========================================================
func _update_animation() -> void:
	if velocity.length() > 0.5:
		anim_player.play("Sprint")
	else:
		anim_player.play("Idle")
