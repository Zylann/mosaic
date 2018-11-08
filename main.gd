extends Panel

const ProgressReporter = preload("progress_reporter.gd")

const PROGRESS_STAGE_LOADING_MODEL = 0
const PROGRESS_STAGE_LOADING_TILES = 1
const PROGRESS_STAGE_COMPOSING = 2
const PROGRESS_STAGE_SAVING = 3

var _progress_reporter = ProgressReporter.new()


func _ready():
	_progress_reporter.configure([
		{"name": "Loading model", "weight": 1},
		{"name": "Loading tiles", "weight": 3},
		{"name": "Composing", "weight": 8},
		{"name": "Saving", "weight": 2}
	])
	
	var mosaic_images_paths = get_images_in_folder("D:/PROJETS/IMAGE/mijto")
	if len(mosaic_images_paths) == 0:
		return
	compute_mosaic("D:/PROJETS/IMAGE/kwaam2.png", mosaic_images_paths, "mosaic.png")


func get_images_in_folder(folder_path: String):
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


class ColorDistanceTileSorter:
	var tile_colors = null
	var target_color = null
	
	func sort(a, b):
		return color_distance(tile_colors[a], target_color) < color_distance(tile_colors[b], target_color)
	
	func color_distance(a, b):
		return sqrt(sq(a.r - b.r) + sq(a.g - b.g) + sq(a.b - b.b))

	func sq(x):
		return x * x


func compute_mosaic(model_image_path, mosaic_images_paths, output_path):
	
	# I'm cheating a little here, but it works well for my needs :)
	
	# Load model image
	_progress_reporter.set_stage(PROGRESS_STAGE_LOADING_MODEL)
	var model_image = Image.new()
	if true:
		var err = model_image.load(model_image_path)
		if err != OK:
			printerr("Could not load image ", model_image_path, ", error ", err)
			return
	
	# Scale it up optionally
	_progress_reporter.set_progress(0.2)
	var scale_factor = 32
	model_image.resize(model_image.get_width() * scale_factor, model_image.get_height() * scale_factor, Image.INTERPOLATE_NEAREST)
	
	var model_width = model_image.get_width()
	var model_height = model_image.get_height()
	var model_ratio = float(model_width) / float(model_height)
	
	# Calculate tile sizes
	var tile_ratio = 3.0 / 4.0
	var tiles_x = 30
	var tile_width = float(model_width / tiles_x)
	var tile_height = tile_width / tile_ratio
	tile_width = int(tile_width)
	tile_height = int(tile_height)
	var tiles_y = model_height / tile_height
	
	# Resize result a little to fit tiles perfectly
	_progress_reporter.set_progress(0.5)
	model_image.resize(tiles_x * tile_width, tiles_y * tile_height, Image.INTERPOLATE_CUBIC)
	var model_index = Image.new()
	
	# Build model color index
	_progress_reporter.set_stage(PROGRESS_STAGE_LOADING_TILES)
	model_index.create(tiles_x, tiles_y, false, Image.FORMAT_RGB8)
	
	model_image.lock()
	model_index.lock()
	
	var tile_area = tile_width * tile_height
	for ty in model_index.get_height():
		for tx in model_index.get_width():
			
			var px0 = tx * tile_width
			var py0 = ty * tile_height
			var sum = Color(0,0,0)
			
			for py in range(py0, py0 + tile_height):
				for px in range(px0, px0 + tile_width):
					sum += model_image.get_pixel(px, py)
					
			model_index.set_pixel(tx, ty, sum / tile_area)
	
	model_index.unlock()
	model_image.unlock()
	
	model_index.save_png("model_index.png")
	
	# Load tile images
	_progress_reporter.set_progress(0.5)
	var tile_images = []
	var tile_color = []
	for path in mosaic_images_paths:
		
		var im = Image.new()
		var err = im.load(path)
		if err != OK:
			printerr("Could not load image ", path, ", error ", err)
			continue
		im.resize(tile_width, tile_height, Image.INTERPOLATE_CUBIC)
		tile_images.append(im)
		
		im.lock()
		var sum = Color()
		for y in im.get_height():
			for x in im.get_width():
				sum += im.get_pixel(x, y)
		tile_color.append(sum / tile_area)
		im.unlock()
	
	# Paste tiles
	_progress_reporter.set_stage(PROGRESS_STAGE_COMPOSING)
	model_image.lock()
	model_index.lock()
	
	var extra_lerps = [0.2, 0.3, 0.4, 0.5]
	
	for ty in model_index.get_height():
		_progress_reporter.set_progress(float(ty) / float(model_index.get_height()))
		
		for tx in model_index.get_width():
			
			var m = model_index.get_pixel(tx, ty)
			var px0 = tx * tile_width
			var py0 = ty * tile_height
			
			var tile_image = null
			var sorter = ColorDistanceTileSorter.new()
			sorter.tile_colors = tile_color
			sorter.target_color = m
			var tiles_order = []
			tiles_order.resize(len(tile_color))
			for i in len(tiles_order):
				tiles_order[i] = i
			tiles_order.sort_custom(sorter, "sort")
			
			var ri = randi() % len(extra_lerps)
			if ri >= len(tiles_order):
				ri = len(tiles_order) - 1
			var extra_lerp = extra_lerps[ri]
			tile_image = tile_images[tiles_order[ri]]
			#var tile_image = tile_images[randi() % len(tile_images)]
			
			tile_image.lock()
			
			for py in tile_height:
				for px in tile_width:
					
					var c = tile_image.get_pixel(px, py)
					c = c.linear_interpolate(m, extra_lerp)
					model_image.set_pixel(px0 + px, py0 + py, c)
			
			tile_image.unlock()
	
	model_index.unlock()
	model_image.unlock()
	
	# Save
	_progress_reporter.set_stage(PROGRESS_STAGE_SAVING)
	model_image.save_png(output_path)

	_progress_reporter.finished()

