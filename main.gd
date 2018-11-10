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
onready var _progress_bar = get_node("VBoxContainer/ProgressBar")

onready var _image_dialog = get_node("ImageDialog")
onready var _folder_dialog = get_node("FolderDialog")
onready var _save_dialog = get_node("SaveDialog")

var _mosaic_processor = MosaicProcessor.new()
var _mosaic_images_paths = []
var _main_image_size_cache = Vector2()
var _adjusted_sizes_cache = null
var _thread = null

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
	_mosaic_processor.get_progress_reporter().connect("progress_reported", self, "_on_MosaicProcessor_progress_reported")


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
	_preview_texture.get_parent().set_ratio(main_ratio)
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
	
	if _thread != null and _thread.is_active():
		print("Thread already running")
		return
	
	var params = {
		model_image_path = _main_image_control.text.strip_edges(),
		mosaic_images_paths = _mosaic_images_paths,
		tiles_x = _tiles_x_control.value,
		tile_ratio = get_selected_ratio(),
		upscale = _upscale_control.value,
		output_path = _output_path_control.text.strip_edges(),
		randomness = _randomness_control.value
	}
	
	_thread = Thread.new()
	_thread.start(self, "_compute_mosaic_thread_func", params)


func _compute_mosaic_thread_func(params):
	print("Running the thing")
	_mosaic_processor.compute_mosaic( \
		params.model_image_path, \
		params.mosaic_images_paths, \
		params.output_path, \
		params.tiles_x, \
		params.tile_ratio, \
		params.upscale, \
		params.randomness)
	print("Finished the thing")
	call_deferred("_thread_finished")


# Had to do this extra bit, because `Thread.is_active()` reports true
# even when the function has finished executing...
func _thread_finished():
	_thread.wait_to_finish()


func _on_MosaicProcessor_progress_reported(percent, text):
	_progress_bar.value = percent
	

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
