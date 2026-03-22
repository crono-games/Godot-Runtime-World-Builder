extends CanvasLayer

@export var texture_rect: TextureRect

func clear_visuals():
	texture_rect.texture = null

func show_heightmap_image(img: Image):
	if not img: 
		texture_rect.texture = null
		return
	var tex = ImageTexture.create_from_image(img)
	texture_rect.texture = tex

func update_heightmap_texture(shape: HeightMapShape3D, max_height: float):
	var size_x = shape.map_width
	var size_z = shape.map_depth
	var img = Image.create(size_x, size_z, false, Image.FORMAT_RF)
	for z in range(size_z):
		for x in range(size_x):
			var idx = z * size_x + x
			var h = shape.map_data[idx] / max_height
			img.set_pixel(x, z, Color(h, 0, 0, 1))
	
	var tex = ImageTexture.create_from_image(img)
	texture_rect.texture = tex
