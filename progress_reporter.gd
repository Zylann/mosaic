
var _progress_config = []
var _current_stage = 0


func set_stage(s):
	assert(s < len(_progress_config))
	_current_stage = s
	set_progress(0.0)


func set_progress(stage_progress):
	var config = _progress_config[_current_stage]
	var p = stage_progress * config.weight + config.prev_cumulated_weight
	_report(p, config.name)


func _report(p, text):
	var pc = int(100.0 * p)
	print("[", str(pc).pad_zeros(2), "%] ", text)


func finished():
	_report(1.0, "Finished")


func configure(def):
	var sum = 0.0
	for d in def:
		sum += d.weight
	var cumul = 0.0
	for d in def:
		d.weight = float(d.weight) / sum
		d["prev_cumulated_weight"] = cumul
		cumul += d.weight
	_progress_config = def

