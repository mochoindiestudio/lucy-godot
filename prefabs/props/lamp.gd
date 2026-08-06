@tool
extends Node3D

@onready var _lights: Array[OmniLight3D] = _collect_lights()

func _ready() -> void:
	var sky := _find_sky3d(get_tree().root)
	if sky == null:
		push_warning("Lamp '%s' found no Sky3D node in the scene tree; lights will not toggle with time of day." % name)
		return
	set_lit(sky.is_night())
	if not sky.sky.day_night_changed.is_connected(_on_day_night_changed):
		sky.sky.day_night_changed.connect(_on_day_night_changed)

func _on_day_night_changed(is_day: bool) -> void:
	set_lit(not is_day)

func set_lit(lit: bool) -> void:
	for light in _lights:
		light.visible = lit

func _collect_lights() -> Array[OmniLight3D]:
	var lights: Array[OmniLight3D] = []
	for child in get_children():
		if child is OmniLight3D:
			lights.append(child)
	return lights

func _find_sky3d(node: Node) -> Sky3D:
	if node is Sky3D:
		return node
	for child in node.get_children():
		var found := _find_sky3d(child)
		if found:
			return found
	return null
