extends Panel

const MosaicProcessor = preload("mosaic_processor.gd")

onready var _properties_container = get_node("VBoxContainer/HSplitContainer/Properties")
onready var _ratios_control = _properties_container.get_node("GridContainer/TileRatio")
onready var _main_image_control = _properties_container.get_node("MainImage")
onready var _images_folder_control = _properties_container.get_node("ImagesFolder")
onready var _tiles_x_control = _properties_container.get_node("GridContainer/HTiles")
onready var _tile_ratio_control = _properties_container.get_node("GridContainer/TileRatio")
onready var _upscale_control = _properties_container.get_node("GridContainer/UpscaleControl")
onready var _randomness_control = _properties_container.get_node("GridContainer/RandomnessControl")
onready var _output_path_control = _properties_container.get_node("OutputPath")
onready var _generate_button = _properties_container.get_node("GenerateButton")
onready var _show_output_button = _properties_container.get_node("ShowOutputButton")
onready var _preview_texture = get_node("VBoxContainer/HSplitContainer/Preview/CenterContainer/TextureRect")
onready var _preview_overlay = _preview_texture.get_node("Overlay")

onready var _image_dialog = get_node("ImageDialog")
onready var _folder_dialog = get_node("FolderDialog")
onready var _save_dialog = get_node("SaveDialog")

var _mosaic_processor = MosaicProcessor.new()
var _mosaic_images_paths = []
var _main_image_size_cache = Vector2()
var _adjusted_sizes_cache = null

var _ratios = [
	[16, 9],
	[4, 3],
	[1, 1],
	[3, 4]
]


func _ready():
	for i in len(_ratios):
		var r = _ratios[i]
		_ratios_control.add_item(str(r[0], ":", r[1]), i)
	_update_generate_button()
	_update_show_output_button()
	_update_preview()
	_preview_overlay.connect("draw", self, "_on_PreviewOverlay_draw")
	connect("resized", self, "_on_Main_resized")


func _on_Main_resized():
	# Have to wait one frame because apparently controls layout didn't run yet
	yield(get_tree(), "idle_frame")
	_update_preview()


func _on_MainImageButton_pressed():
	_image_dialog.popup_centered_ratio()


func _on_ImagesFolderButton_pressed():
	_folder_dialog.popup_centered_ratio()


func _on_HTiles_value_changed(value):
	_update_preview()


func _on_TileRatio_item_selected(id):
	_update_preview()


func _on_UpscaleControl_value_changed(value):
	_update_preview()


func _on_OutputPathButton_pressed():
	_save_dialog.popup_centered_ratio()


func _on_ImageDialog_file_selected(path):
	_main_image_control.text = path
	_update_generate_button()
	var im = Image.new()
	if im.load(path) == OK:
		_main_image_size_cache = im.get_size()
	_update_preview()


func _on_FolderDialog_dir_selected(dir):
	_mosaic_images_paths = get_images_in_folder(dir)
	_images_folder_control.text = dir
	_update_generate_button()


func _on_SaveDialog_file_selected(path):
	_output_path_control.text = path
	_update_generate_button()
	_update_show_output_button()


func _update_generate_button():
	_generate_button.disabled = \
		_main_image_control.text == "" \
		or len(_mosaic_images_paths) == 0 \
		or _output_path_control.text == ""


func _update_show_output_button():
	_show_output_button.disabled = _output_path_control.text == ""


func _update_preview():
	if _main_image_size_cache == Vector2():
		return
	
	var tiles_x = _tiles_x_control.value
	var tile_ratio = get_selected_ratio()
	var upscale = _upscale_control.value
	
	var sizes = _mosaic_processor.get_adjusted_sizes( \
		int(_main_image_size_cache.x), int(_main_image_size_cache.y), \
		tiles_x, tile_ratio, upscale)
	
	if sizes == null:
		return
	
	#print(sizes)
	_adjusted_sizes_cache = sizes
	
	var container_size = _preview_texture.get_parent().rect_size
	var main_ratio = float(sizes.main_width) / float(sizes.main_height)
	var preview_size = Vector2()
	if sizes.main_width > sizes.main_height:
		preview_size = Vector2(container_size.x, container_size.x / main_ratio)
	else:
		preview_size = Vector2(container_size.y * main_ratio, container_size.y)
	
	if preview_size.x > container_size.x:
		preview_size *= container_size.x / preview_size.x
	elif preview_size.y > container_size.y:
		preview_size *= container_size.y / preview_size.y
	
	_preview_texture.rect_size = preview_size
	_preview_texture.rect_position = (_preview_texture.get_parent().rect_size - _preview_texture.rect_size) / 2
	
	_preview_overlay.update()


func _on_PreviewOverlay_draw():
	if _adjusted_sizes_cache == null:
		return
	
	var ci = _preview_overlay
	var rs = _preview_overlay.rect_size
	var col = Color(1, 0.5, 0)
	var ts = rs / Vector2(_adjusted_sizes_cache.tiles_x, _adjusted_sizes_cache.tiles_y)
	
	for x in _adjusted_sizes_cache.tiles_x + 1:
		ci.draw_line(Vector2(x * ts.x, 0), Vector2(x * ts.x, rs.y), col)

	for y in _adjusted_sizes_cache.tiles_y + 1:
		ci.draw_line(Vector2(0, y * ts.y), Vector2(rs.x, y * ts.y), col)


func get_selected_ratio():
	var tile_ratio = _ratios[_tile_ratio_control.get_selected_id()]
	return float(tile_ratio[0]) / float(tile_ratio[1])


func _on_GenerateButton_pressed():
	
	var model_image_path = _main_image_control.text.strip_edges()
	var tiles_x = _tiles_x_control.value
	var tile_ratio = get_selected_ratio()
	var upscale = _upscale_control.value
	var output_path = _output_path_control.text.strip_edges()
	var randomness = _randomness_control.value
	
	_mosaic_processor.compute_mosaic( \
		model_image_path, \
		_mosaic_images_paths, \
		output_path, \
		tiles_x, \
		tile_ratio, \
		upscale, \
		randomness)


func _on_ShowOutputButton_pressed():
	var output_path = _output_path_control.text.strip_edges()
	OS.shell_open(output_path)


static func get_images_in_folder(folder_path: String):
	var result := []
	var d := Directory.new()
	var err := d.open(folder_path)
	if err != OK:
		print("Could not open directory ", folder_path, ", error ", err)
		return result
	d.list_dir_begin()
	var fname := d.get_next()
	while fname != "":
		if not d.current_is_dir():
			var ext := fname.get_extension()
			if ext == "png" or ext == "jpg":
				result.append(folder_path.plus_file(fname))
		fname = d.get_next()
	return result
