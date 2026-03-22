@tool
extends Node3D
class_name ChunkManager

# =========================================================
# ENUMS / MODES
# =========================================================

enum EditorMode { TERRAIN, TEXTURE, PROP, SELECTION, WATER }

var current_mode: EditorMode = EditorMode.TERRAIN

# =========================================================
# CONFIG
# =========================================================

@export_dir var output_path
@export var player: CharacterBody3D
@export var chunk_size_meters: float = 64.0

@export var brush: Brush
@export var chunk_scene: PackedScene

@export var global_heightmap: Image
@export var global_splatmap: Image

@export var view_distance_chunks := 2

# =========================================================
# REFERENCES
# =========================================================

@export var cursor: MeshInstance3D

var camera: Camera3D

# =========================================================
# STATE
# =========================================================

var chunks: Array[Node] = []
var active_coords: Array[Vector2i] = []

var current_color: Color = Color(1, 0, 0, 0)

# Cached input mapping (initialized once)
var input_map := {}

# =========================================================
# LIFECYCLE
# =========================================================

func _ready():
	_initialize_chunks()
	_initialize_input_map()
	camera = player.camera

# =========================================================
# INITIALIZATION
# =========================================================

func _initialize_chunks() -> void:
	chunks = get_tree().get_nodes_in_group("chunk")

	for c: Chunk in chunks:
		c.world_manager = self

	if chunks.is_empty():
		build_chunks()
	else:
		reload_all_chunks()

func _initialize_input_map() -> void:
	input_map = {
		EditorMode.TERRAIN: {
			"mouse_left_button": {"paint_mode": brush.paint_mode},
			"mouse_right_button": {"paint_mode": "lower"},
			"mouse_middle_button": {"paint_mode": "smooth"},
		},
		EditorMode.TEXTURE: {
			"mouse_left_button": {"splat_mode": "paint"},
			"mouse_right_button": {"splat_mode": "erase"},
		},
		EditorMode.PROP: {
			"mouse_left_button": {"prop_mode": "place"},
			"mouse_right_button": {"prop_mode": "remove"},
		}
	}

# =========================================================
# PROCESS
# =========================================================

func _process(_delta):
	if Engine.is_editor_hint():
		return

	_update_cursor()

	_handle_mode_shortcuts()

	var active_modes = _get_active_modes()
	var cursor_info = _get_cursor_info()

	_apply_tools(cursor_info, active_modes)

	if Input.is_action_just_pressed("save"):
		save_world()

# =========================================================
# INPUT / MODES
# =========================================================

func _get_active_modes() -> Dictionary:
	var result := {}

	if not input_map.has(current_mode):
		return result

	for action in input_map[current_mode]:
		if Input.is_action_pressed(action):
			result.merge(input_map[current_mode][action])

	return result

func _handle_mode_shortcuts():
	var shortcuts = {
		"shortcut_terrain": EditorMode.TERRAIN,
		"shortcut_texture": EditorMode.TEXTURE,
		"shortcut_props": EditorMode.PROP,
	}

	for action in shortcuts:
		if Input.is_action_just_pressed(action):
			current_mode = shortcuts[action]
			break

# =========================================================
# CURSOR / RAYCAST
# =========================================================

func _get_cursor_info(max_distance := 1000.0) -> Dictionary:
	var mouse = get_viewport().get_mouse_position()

	var from = camera.project_ray_origin(mouse)
	var to = from + camera.project_ray_normal(mouse) * max_distance

	var result = get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, to)
	)

	if not result:
		return {"position": to, "chunk": null}

	var chunk = _find_chunk_from_collider(result.collider)

	return {
		"position": result.position,
		"chunk": chunk
	}

func _find_chunk_from_collider(node: Node) -> Chunk:
	while node:
		if node.is_in_group("chunk"):
			return node
		node = node.get_parent()
	return null

func _update_cursor():
	var info = _get_cursor_info()
	if info.chunk:
		cursor.global_position = info.position
		cursor.visible = true
	else:
		cursor.visible = false

# =========================================================
# TOOL APPLICATION
# =========================================================

func _apply_tools(cursor_info: Dictionary, modes: Dictionary):
	var world_pos = cursor_info.position

	# HEIGHTMAP
	if modes.has("paint_mode"):
		brush.paint_mode = modes.paint_mode
		_apply_height_paint(world_pos)

	# SPLATMAP
	if modes.has("splat_mode"):
		brush.splat_mode = modes.splat_mode
		_apply_texture_paint(world_pos)

	# PROPS
	if modes.has("prop_mode") and modes.prop_mode == "place":
		_place_prop(world_pos)

# =========================================================
# PAINT SYSTEM
# =========================================================

func _apply_height_paint(world_pos: Vector3):
	var affected = _get_chunks_in_radius(world_pos, brush.radius_m)

	brush.paint_heightmap(global_heightmap, world_pos, brush.radius_m, brush.strength, get_bounds())

	for c in affected:
		c.reload_heightmap(global_heightmap)

func _apply_texture_paint(world_pos: Vector3):
	var bounds = get_bounds()
	var affected = _get_chunks_in_radius(world_pos, brush.radius_m)

	brush.paint_splatmap(global_splatmap, world_pos, brush.radius_m, current_color, bounds)

	for c in affected:
		c.reload_splatmap(global_splatmap, bounds)

# =========================================================
# PROPS
# =========================================================

func _place_prop(world_pos: Vector3):
	#var scene = preload("res://assets/props/wall.tscn")
	var scene : = ""
	for chunk in _get_chunks_in_radius(world_pos, brush.radius_m):
		chunk.add_prop(scene, world_pos)

# =========================================================
# CHUNKS
# =========================================================

func build_chunks():
	var center = global_transform.origin

	for dz in range(-view_distance_chunks, view_distance_chunks + 1):
		for dx in range(-view_distance_chunks, view_distance_chunks + 1):
			_create_chunk(Vector2i(dx, dz), center)

func _create_chunk(coord: Vector2i, origin: Vector3) -> Chunk:
	var chunk: Chunk = chunk_scene.instantiate()

	add_child(chunk)
	chunk.owner = get_parent_node_3d()

	chunk.global_position = Vector3(
		coord.x * chunk_size_meters,
		0,
		coord.y * chunk_size_meters
	)

	chunk.id = chunk.generate_id_from_position(chunk.global_position, chunk_size_meters)

	chunks.append(chunk)
	return chunk

func reload_all_chunks():
	var bounds = get_bounds()

	for c in chunks:
		c.reload_heightmap(global_heightmap)
		c.reload_splatmap(global_splatmap, bounds)

# =========================================================
# STREAMING (BASIC)
# =========================================================

func ensure_chunk(coord: Vector2i) -> Chunk:
	var existing = get_chunk_at(coord)
	if existing:
		return existing

	return _create_chunk(coord, Vector3.ZERO)

func get_chunk_at(coord: Vector2i) -> Chunk:
	for c in chunks:
		var pos = c.global_position
		var cx = int(floor(pos.x / chunk_size_meters))
		var cz = int(floor(pos.z / chunk_size_meters))

		if Vector2i(cx, cz) == coord:
			return c

	return null

# =========================================================
# BOUNDS
# =========================================================

func get_bounds() -> Dictionary:
	if chunks.is_empty():
		return {"min_x":0, "max_x":0, "min_z":0, "max_z":0}

	var min_x = INF
	var max_x = -INF
	var min_z = INF
	var max_z = -INF

	for c in chunks:
		var pos = c.global_position

		min_x = min(min_x, pos.x)
		max_x = max(max_x, pos.x + chunk_size_meters)
		min_z = min(min_z, pos.z)
		max_z = max(max_z, pos.z + chunk_size_meters)

	return {
		"min_x": min_x,
		"max_x": max_x,
		"min_z": min_z,
		"max_z": max_z
	}

func _get_chunks_in_radius(world_pos: Vector3, radius: float) -> Array:
	var result := []

	for c in chunks:
		if c.contains_circle(world_pos.x, world_pos.z, radius):
			result.append(c)

	return result

# =========================================================
# SAVE
# =========================================================

func save_world():
	var scene = PackedScene.new()
	scene.pack(get_tree().current_scene)

	ResourceSaver.save(scene, "res://worlds/world_01/world4.tscn")
