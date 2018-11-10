
# Resizes the first child to have the given ratio, and make sure it fits

extends Container


var _ratio = 1.0


func set_ratio(r):
	_ratio = r


func _notification(what):
	if what == NOTIFICATION_SORT_CHILDREN:
		layout()


func layout():
	if get_child_count() == 0:
		return
	var child = get_child(0)
	
	var container_size = rect_size
	
	var child_size = Vector2()
	if _ratio >= 1.0:
		child_size = Vector2(container_size.x, container_size.x / _ratio)
	else:
		child_size = Vector2(container_size.y * _ratio, container_size.y)
	
	if child_size.x > container_size.x:
		child_size *= container_size.x / child_size.x
	elif child_size.y > container_size.y:
		child_size *= container_size.y / child_size.y
	
	var child_rect = Rect2((container_size - child_size) / 2, child_size)
	
	fit_child_in_rect(child, child_rect)
