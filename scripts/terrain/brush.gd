extends Resource
class_name Brush

# =========================================================
# CONFIGURATION
# =========================================================

@export_category("General")
@export var radius_m: float = 4.0
@export var strength: float = 0.05

@export_enum("raise", "lower", "smooth", "flatten", "mountain", "erode", "cliff")
var paint_mode: String = "raise"

@export var flatten_height: float = 0.0

@export_enum("paint", "erase", "replace", "smooth")
var splat_mode: String = "paint"

# =========================================================
# FALLOFF
# =========================================================

@export_category("Falloff")
@export var falloff_type: String = "cosine"
@export var falloff_power: float = 1.0
@export var mask_texture: ImageTexture

# =========================================================
# SCATTER (PROPS)
# =========================================================

@export_category("Scatter")
@export var scatter_mode: String = "random"
@export var spacing_m: float = 1.0
@export var seed: int = 0
@export var scale_min: float = 0.9
@export var scale_max: float = 1.1

# =========================================================
# INTERNAL STATE
# =========================================================

var noise := FastNoiseLite.new()

# Stamp cache (for optimized painting)
var _stamp_image: Image
var _stamp_size: int = 0

# =========================================================
# FALL OFF
# =========================================================

func compute_falloff(distance: float) -> float:
	if distance >= radius_m:
		return 0.0

	var t = distance / max(radius_m, 1e-6)

	match falloff_type:
		"linear":
			return 1.0 - t

		"gaussian":
			var sigma = 0.5
			return exp(-(t * t) / (2.0 * sigma * sigma))

		"cosine":
			return 0.5 * (cos(t * PI) + 1.0)

		"constant":
			return 1.0

		"texture":
			return _sample_mask_texture(t)

		_:
			return pow(max(0.0, 1.0 - t), falloff_power)

func _sample_mask_texture(t: float) -> float:
	if not mask_texture:
		return 1.0

	var img = mask_texture.get_image()
	var uv = Vector2(0.5 + t * 0.5, 0.5)

	var px = uv.x * img.get_width()
	var py = uv.y * img.get_height()

	return img.get_interpolated_pixel(px, py).r

# =========================================================
# HEIGHTMAP PAINT
# =========================================================

func paint_heightmap(img: Image, world_pos: Vector3, radius: int, intensity: float, bounds: Dictionary):
	var center = world_to_map(world_pos, img, bounds)

	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):

			var px = center.x + dx
			var py = center.y + dz

			if not _is_inside(img, px, py):
				continue

			var dist = sqrt(dx * dx + dz * dz)
			if dist > radius:
				continue

			var falloff = compute_falloff(dist)
			var current = img.get_pixel(px, py).r

			var new_h = _apply_height_mode(img, px, py, current, intensity * falloff)

			img.set_pixel(px, py, Color(new_h, 0, 0))

# =========================================================
# SPLATMAP PAINT
# =========================================================

func paint_splatmap(img: Image, world_pos: Vector3, radius: int, color: Color, bounds: Dictionary):
	var center = world_to_map(world_pos, img, bounds)

	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):

			var px = center.x + dx
			var py = center.y + dz

			if not _is_inside(img, px, py):
				continue

			var dist = Vector2(dx, dz).length()
			if dist > radius:
				continue

			var falloff = compute_falloff(dist)

			var current = img.get_pixel(px, py)
			var new_color = _apply_splat_mode(current, color, falloff)

			img.set_pixel(px, py, new_color)

# =========================================================
# HEIGHT MODES
# =========================================================

func _apply_height_mode(img: Image, x: int, y: int, current: float, intensity: float) -> float:
	var min_h := -50.0
	var max_h := 50.0

	match paint_mode:

		"raise":
			return clamp(current + intensity, min_h, max_h)

		"lower":
			return clamp(current - intensity, min_h, max_h)

		"smooth":
			return _smooth_height(img, x, y, current)

		"flatten":
			return flatten_height

		"mountain":
			return _mountain_height(current, intensity, min_h, max_h)

		"erode":
			return _erode_height(img, x, y, current, intensity)

		"cliff":
			return _cliff_height(current, intensity, min_h, max_h)

		_:
			return current

func _smooth_height(img: Image, x: int, y: int, current: float) -> float:
	var sum := 0.0
	var count := 0

	for j in range(-1, 2):
		for i in range(-1, 2):
			var nx = x + i
			var ny = y + j

			if _is_inside(img, nx, ny):
				sum += img.get_pixel(nx, ny).r
				count += 1

	return lerp(current, sum / count, 0.5)

func _mountain_height(current: float, intensity: float, min_h: float, max_h: float) -> float:
	var detail = (randf() * 2.0 - 1.0) * 0.1 * intensity
	return clamp(current + intensity + detail, min_h, max_h)

func _erode_height(img: Image, x: int, y: int, current: float, intensity: float) -> float:
	var neighbors := []

	for j in range(-1, 2):
		for i in range(-1, 2):
			if i == 0 and j == 0:
				continue

			var nx = x + i
			var ny = y + j

			if _is_inside(img, nx, ny):
				neighbors.append(img.get_pixel(nx, ny).r)

	if neighbors.is_empty():
		return current

	var avg := 0.0
	var max_diff := 0.0

	for n in neighbors:
		avg += n
		max_diff = max(max_diff, current - n)

	avg /= neighbors.size()

	var factor = clamp(max_diff * 0.5, 0.0, 1.0) * intensity
	return lerp(current, avg, factor)

func _cliff_height(current: float, intensity: float, min_h: float, max_h: float) -> float:
	var target = 40.0
	var delta = (target - current) * 0.3 * intensity
	var noise_term = (randf() * 2.0 - 1.0) * 0.05 * intensity

	return clamp(current + delta + noise_term, min_h, max_h)

# =========================================================
# SPLAT MODES
# =========================================================

func _apply_splat_mode(current: Color, target: Color, amount: float) -> Color:
	match splat_mode:

		"paint":
			return current.lerp(target, amount)

		"erase":
			return current.lerp(Color(0, 0, 0, 1), amount)

		"replace":
			return target

		"smooth":
			return current

		_:
			return current

# =========================================================
# COORDINATE SPACE
# =========================================================

func world_to_map(world_pos: Vector3, img: Image, bounds: Dictionary, flip_z: bool = false) -> Vector2i:
	var world_w = bounds.max_x - bounds.min_x
	var world_h = bounds.max_z - bounds.min_z

	if world_w <= 0 or world_h <= 0:
		return Vector2i.ZERO

	var px = int(round((world_pos.x - bounds.min_x) * img.get_width() / world_w))
	var pz = int(round((world_pos.z - bounds.min_z) * img.get_height() / world_h))

	if flip_z:
		pz = img.get_height() - 1 - pz

	return Vector2i(
		clamp(px, 0, img.get_width() - 1),
		clamp(pz, 0, img.get_height() - 1)
	)

func _is_inside(img: Image, x: int, y: int) -> bool:
	return x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height()

# =========================================================
# STAMP (OPTIONAL OPTIMIZATION)
# =========================================================

func generate_stamp(size: int) -> Image:
	if _stamp_image and _stamp_size == size:
		return _stamp_image

	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)

	var center = (size - 1) * 0.5
	var meters_per_pixel = (radius_m * 2.0) / float(size)

	for y in range(size):
		for x in range(size):
			var dist = Vector2(x - center, y - center).length() * meters_per_pixel
			var val = clamp(compute_falloff(dist), 0.0, 1.0)

			img.set_pixel(x, y, Color(val, val, val, 1.0))

	_stamp_image = img
	_stamp_size = size

	return img

func clear_stamp_cache():
	_stamp_image = null
	_stamp_size = 0
