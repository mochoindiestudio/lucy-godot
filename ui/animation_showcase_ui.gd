extends Control

## Order must match the Buttons container's child order.
const STATE_NAMES := ["idle", "walking", "slow_run", "talking_1", "talking_2"]

@onready var _buttons: Control = %Buttons

func _ready() -> void:
	var children := _buttons.get_children()
	for i in children.size():
		if i >= STATE_NAMES.size():
			break
		var button: Button = children[i]
		button.pressed.connect(_on_state_button_pressed.bind(STATE_NAMES[i]))

func _on_state_button_pressed(state_name: String) -> void:
	for character in get_tree().get_nodes_in_group("character_anim_trees"):
		character.play_state(state_name)
