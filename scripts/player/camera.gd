extends Node3D

@export var zoom_min := 3.0
@export var zoom_max := 25.0

var zoom_distance := 10.0  
var yaw := 0.0
var pitch := -20.0
var distance := 8.0
var rotating := false

@export var camera: Camera3D

func _ready():
	rotation = Vector3(30, 180, 0)
	var cam_offset = global_transform.basis.z * zoom_distance
	camera.global_transform.origin = global_transform.origin - cam_offset
	camera.look_at(global_transform.origin, Vector3.UP)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if not Input.is_action_pressed("button_shift"):
			if event.button_index == MOUSE_BUTTON_RIGHT:
				rotating = event.pressed
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_distance = max(zoom_distance - 1, zoom_min)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_distance = min(zoom_distance + 1, zoom_max)

	if event is InputEventMouseMotion and rotating:
		var horizontal_delta = event.relative.x * 0.2
		yaw -= horizontal_delta

		var vertical_delta = event.relative.y * 0.2
		pitch = clamp(pitch - vertical_delta, -5, 75)

func _process(delta: float) -> void:
	rotation_degrees = Vector3(pitch, yaw, 0)
	var cam_offset = global_transform.basis.z * zoom_distance
	camera.global_transform.origin = global_transform.origin - cam_offset
	camera.look_at(global_transform.origin, Vector3.UP)
