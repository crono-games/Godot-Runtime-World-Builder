@tool
extends StaticBody3D
class_name Chunk

# =========================================================
# CONFIGURATION
# =========================================================

@export_file("*.gdshader") var shader_path
@export var chunk_size_meters: float = 64.0
@export var map_width: int = 128
@export var map_depth: int = 128

@export var prop_container: Node3D
@export var props: Array = []

@export var world_manager: Node3D

# =========================================================
# NODES
# =========================================================
@export var terrain_mesh: MeshInstance3D
@export var collision_shape: CollisionShape3D


# =========================================================
# INTERNAL STATE
# =========================================================

var id: String = ""
var material: ShaderMaterial

## Textures (used by splatmap)
var grass_texture = preload("res://assets/textures/ground.png")
var rock_texture = preload("res://assets/textures/ground2.png")

# =========================================================
# LIFECYCLE
# =========================================================

func _ready():
	_load_props()
	_initialize_material()
	_initialize_collision()

	if not world_manager:
		return

	var global_heightmap = world_manager.global_heightmap
	if global_heightmap:
		reload_heightmap(global_heightmap)

	_update_height_scale()

# =========================================================
# INITIALIZATION
# =========================================================

func _initialize_material() -> void:
	## Reuse material if already exists
	material = terrain_mesh.get_active_material(0) as ShaderMaterial

	if material and material.get_shader_parameter("heightmap") != null:
		return

	material = ShaderMaterial.new()
	material.shader = load(shader_path)
	terrain_mesh.set_surface_override_material(0, material)

func _initialize_collision() -> void:
	## Duplicate shape to avoid modifying shared resource
	if collision_shape.shape:
		collision_shape.shape = collision_shape.shape.duplicate(true)

func _update_height_scale() -> void:
	if material.get_shader_parameter("heightmap") != null:
		material.set_shader_parameter("height_scale", 1.0)
	else:
		material.set_shader_parameter("height_scale", 0.0)

# =========================================================
# HEIGHTMAP
# =========================================================

func reload_heightmap(global_heightmap: Image) -> void:
	if not global_heightmap:
		return

	var bounds = get_world_bounds()
	var pixels_per_meter = _get_pixels_per_meter(global_heightmap, bounds)

	var origin_px = _get_chunk_origin_px(bounds, pixels_per_meter)
	var chunk_px_size = int(chunk_size_meters) + 1

	var local_img = _create_or_reuse_heightmap(chunk_px_size)

	_copy_heightmap_region(global_heightmap, local_img, origin_px)

	var map_data = _image_to_height_array(local_img)

	_apply_collision(map_data, chunk_px_size)
	_apply_heightmap_texture(local_img)

	_update_height_scale()

# --- helpers ---

func _create_or_reuse_heightmap(size: int) -> Image:
	if material.get_shader_parameter("heightmap") != null:
		return material.get_shader_parameter("heightmap").get_image()

	return Image.create(size, size, false, Image.FORMAT_RF)

func _copy_heightmap_region(global_img: Image, local_img: Image, origin_px: Vector2i) -> void:
	var w = global_img.get_width()
	var h = global_img.get_height()

	for x in range(local_img.get_width()):
		for y in range(local_img.get_height()):
			var gx = clamp(origin_px.x + x, 0, w - 1)
			var gy = clamp(origin_px.y + y, 0, h - 1)

			var height = global_img.get_pixel(gx, gy).r
			local_img.set_pixel(x, y, Color(height, 0, 0))

func _image_to_height_array(img: Image) -> PackedFloat32Array:
	var size = img.get_width()
	var data: PackedFloat32Array
	data.resize(size * size)

	for y in range(size):
		for x in range(size):
			data[y * size + x] = img.get_pixel(x, y).r

	return data

func _apply_collision(map_data: PackedFloat32Array, size: int) -> void:
	var shape = collision_shape.shape
	shape.map_width = size
	shape.map_depth = size
	shape.map_data = map_data

func _apply_heightmap_texture(img: Image) -> void:
	var tex = ImageTexture.create_from_image(img)
	material.set_shader_parameter("heightmap", tex)

# =========================================================
# SPLATMAP
# =========================================================

func reload_splatmap(global_splatmap: Image, bounds: Dictionary, flip_z: bool = false) -> void:
	if not global_splatmap or not bounds:
		return

	var world_size = _get_world_size(bounds)
	if world_size.x <= 0 or world_size.y <= 0:
		push_warning("Invalid world bounds")
		return

	var scale = Vector2(
		global_splatmap.get_width() / world_size.x,
		global_splatmap.get_height() / world_size.y
	)

	var chunk_origin = _get_chunk_min_world()
	var origin_px = Vector2(
		(chunk_origin.x - bounds.min_x) * scale.x,
		(chunk_origin.z - bounds.min_z) * scale.y
	)

	var size_px = Vector2i(
		max(int(round(chunk_size_meters * scale.x)), 1) + 1,
		max(int(round(chunk_size_meters * scale.y)), 1) + 1
	)

	var local_img = _copy_splat_region(global_splatmap, origin_px, size_px, flip_z)

	_apply_splatmap(local_img)

# --- helpers ---

func _copy_splat_region(global_img: Image, origin_px: Vector2, size: Vector2i, flip_z: bool) -> Image:
	var img = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)

	var w = global_img.get_width()
	var h = global_img.get_height()

	for y in range(size.y):
		for x in range(size.x):
			var gx = int(origin_px.x) + x
			var gy = int(origin_px.y) + y

			if flip_z:
				gy = h - 1 - gy

			gx = clamp(gx, 0, w - 1)
			gy = clamp(gy, 0, h - 1)

			img.set_pixel(x, y, global_img.get_pixel(gx, gy))

	return img

func _apply_splatmap(img: Image) -> void:
	var tex = ImageTexture.create_from_image(img)

	material.set_shader_parameter("splatmap", tex)
	material.set_shader_parameter("tex_grass", grass_texture)
	material.set_shader_parameter("tex_rock", rock_texture)

# =========================================================
# PROPS
# =========================================================

func _load_props() -> void:
	for data in props:
		var scene = load(data["scene"])
		if not scene:
			continue

		var instance = scene.instantiate()
		prop_container.add_child(instance)

		instance.transform.origin = data["pos"]
		instance.rotation_degrees = data["rot"]
		instance.scale = data["scale"]

func add_prop(scene: PackedScene, world_pos: Vector3) -> void:
	var instance = scene.instantiate()

	var local_pos = prop_container.to_local(world_pos)
	instance.transform.origin = local_pos

	add_child(instance)
	instance.owner = get_tree().edited_scene_root

	props.append({
		"scene": instance.scene_file_path,
		"pos": local_pos,
		"rot": instance.rotation_degrees,
		"scale": instance.scale
	})

# =========================================================
# BOUNDS / SPACE
# =========================================================

func get_world_bounds() -> Dictionary:
	var chunks = get_tree().get_nodes_in_group("chunk")

	if chunks.is_empty():
		return {"min_x":0, "max_x":0, "min_z":0, "max_z":0}

	var min_x = INF
	var max_x = -INF
	var min_z = INF
	var max_z = -INF

	for chunk in chunks:
		var pos = chunk.global_transform.origin

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

func _get_world_size(bounds: Dictionary) -> Vector2:
	return Vector2(
		bounds.max_x - bounds.min_x,
		bounds.max_z - bounds.min_z
	)

func _get_pixels_per_meter(img: Image, bounds: Dictionary) -> float:
	return img.get_width() / (bounds.max_x - bounds.min_x)

func _get_chunk_origin_px(bounds: Dictionary, ppm: float) -> Vector2i:
	var min_world = _get_chunk_min_world()

	return Vector2i(
		int((min_world.x - bounds.min_x) * ppm),
		int((min_world.z - bounds.min_z) * ppm)
	)

func _get_chunk_min_world() -> Vector3:
	var half = chunk_size_meters * 0.5
	return Vector3(
		global_transform.origin.x - half,
		0,
		global_transform.origin.z - half
	)

# =========================================================
# UTILS
# =========================================================

func contains_circle(world_x: float, world_z: float, radius: float) -> bool:
	var half = chunk_size_meters * 0.5

	var min_x = global_transform.origin.x - half
	var max_x = global_transform.origin.x + half
	var min_z = global_transform.origin.z - half
	var max_z = global_transform.origin.z + half

	var nearest_x = clamp(world_x, min_x, max_x)
	var nearest_z = clamp(world_z, min_z, max_z)

	var dx = world_x - nearest_x
	var dz = world_z - nearest_z

	return (dx * dx + dz * dz) <= radius * radius

func generate_id_from_position(pos: Vector3, chunk_size: float) -> String:
	var x = int(floor(pos.x / chunk_size))
	var z = int(floor(pos.z / chunk_size))
	return "%d_%d" % [x, z]
