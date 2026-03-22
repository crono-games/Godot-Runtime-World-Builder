extends Node3D

@export
var gizmo : Gizmo3D
@export
var camera : Camera3D
@export
var player : CharacterBody3D
@export var world_manager : Node3D
var _add : bool

var selected_node : Node3D

func _ready() -> void:
	for i in get_children():
		if i is Chunk:
			i.world_manager = self
	camera = player.camera

func _input(event: InputEvent) -> void:
	if !gizmo.editing and Input.is_action_just_pressed("shortcut_selection"):
		gizmo.use_local_space = !gizmo.use_local_space
	if gizmo.hovering || gizmo.editing:
		return;
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		
		pick_vertex
		var dir := camera.project_ray_normal(event.position)
		var from := camera.project_ray_origin(event.position)
		var params = PhysicsRayQueryParameters3D.new()
		params.collision_mask = 2
		params.from = from
		params.to = from + dir * 1000.0
		var result = get_world_3d().direct_space_state.intersect_ray(params)
		if result.size() == 0:
			return
		var collider = result["collider"] as Node3D
		selected_node = collider
		if !_add:
			gizmo.clear_selection()
			gizmo.select(selected_node)
			return
		if !gizmo.deselect(selected_node):
			gizmo.select(selected_node)

func pick_vertex(ray_origin: Vector3, ray_dir: Vector3, vertex: Vector3, camera: Camera3D, radius: float = 0.1) -> bool:
	var cam_dir = (vertex - camera.global_transform.origin).normalized()
	var up = camera.global_transform.basis.y
	var right = cam_dir.cross(up).normalized()
	
	var v0 = vertex + right * radius
	var v1 = vertex - right * radius
	var v2 = vertex + up * radius
	
	var intersect = Geometry3D.ray_intersects_triangle(ray_origin, ray_dir, v0, v1, v2)
	return intersect != null
