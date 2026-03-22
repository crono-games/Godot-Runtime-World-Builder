# PropPalette.gd
extends CanvasLayer


signal prop_selected(scene: PackedScene)

@export_dir var texture_folder : String
@export_dir var props_folder : String = "res://props/"
@export var world_manager : Node3D


var brush_size: float = 10.0:
	set(v):
		brush_size = clamp(v, 0.5, 5.0) # limites ejemplo
		if brush_slider.value != v:
			brush_slider.value = v
	get:
		return brush_size

@onready var grid = $FoldableContainer/ScrollContainer/GridContainer
@onready var brush_slider = $HSlider  # tu HSlider en la UI
@onready var texture_container = $TexturePallete/ScrollContainer/GridContainer


func _ready():
	add_texture_to_pallete(texture_folder)

func add_props():
	var dir = DirAccess.open(props_folder)
	if not dir: return
	for file in dir.get_files():
		if file.ends_with(".tscn"):
			var scene := load(props_folder + "/" + file)
			if scene:
				_add_prop_item(scene, file)


func add_texture_to_pallete(path):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".png"):
				var texture_button : = TextureButton.new()
				texture_container.add_child(texture_button)
				var texture_path = texture_folder + "/"  + file_name
				texture_button.texture_normal = load(texture_path)
				texture_button.ignore_texture_size = true
				texture_button.stretch_mode = TextureButton.STRETCH_SCALE
				texture_button.custom_minimum_size = Vector2(64, 64)
				texture_button.connect("pressed", world_manager._update_texture.bind(texture_path))
				
			file_name = dir.get_next()

	else:
		print("An error occurred when trying to access the path.")

func _add_prop_item(scene: PackedScene, name: String):
	var viewport = null
	var instance = scene.instantiate()
	viewport.add_child(instance)
	
func _test():
	var scene 
	# === Viewport para renderizar el prop ===
	var viewport := SubViewport.new()
	viewport.size = Vector2(128, 128)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# Cámara
	var cam := Camera3D.new()
	cam.transform.origin = Vector3(0, 1, 3)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	viewport.add_child(cam)

	# Luz
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	viewport.add_child(light)

	# Instanciar prop
	var instance = scene.instantiate()
	viewport.add_child(instance)

	# Ajustar un poco el bounding box para centrar (opcional)
	if instance is Node3D:
		var aabb = instance.get_node("MeshInstance3D").mesh.get_aabb()
		cam.transform.origin = aabb.size.length() * Vector3(0, 0.5, 2)

	# === UI ===
	var preview := TextureRect.new()
	preview.texture = viewport.get_texture()
	preview.expand = true
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(128, 128)
	preview.tooltip_text = name

	# Click
	preview.connect("gui_input", func(event):
		if event is InputEventMouseButton and event.pressed:
			emit_signal("prop_selected", scene))

	grid.add_child(preview)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.shift_pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			brush_slider.value += brush_slider.step
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			brush_slider.value -= brush_slider.step

func _on_h_slider_value_changed(value: float) -> void:
	set("brush_size", value)
