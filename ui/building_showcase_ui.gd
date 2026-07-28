extends Control

@onready var _item_name: Label = %ItemName

## Shows the given item's name in the label.
func show_item(item: Node3D) -> void:
	_item_name.text = item.name

## Fades the name label to the given alpha over duration seconds.
func fade_name(target_alpha: float, duration: float) -> void:
	create_tween().tween_property(_item_name, "modulate:a", target_alpha, duration)
