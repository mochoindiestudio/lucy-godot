extends Control

@onready var _buttons: Control = %Buttons
@onready var _character_name: Label = %CharacterName

## Rebuilds the button row and name label for the given character.
func show_character(character: Node3D) -> void:
	_character_name.text = character.name

	for child in _buttons.get_children():
		child.queue_free()

	for state_name in character.get_state_names():
		var button := Button.new()
		button.text = state_name.capitalize()
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(character.play_state.bind(state_name))
		_buttons.add_child(button)

## Fades the name label to the given alpha over duration seconds.
func fade_name(target_alpha: float, duration: float) -> void:
	create_tween().tween_property(_character_name, "modulate:a", target_alpha, duration)
