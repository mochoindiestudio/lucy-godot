extends Control

## Splash/title screen. Any key press or mouse click loads the game scene.

const GAME_SCENE_PATH := "res://scenes/game.scn"

func _unhandled_input(event: InputEvent) -> void:
	var is_key_press: bool = event is InputEventKey and event.pressed and not event.echo
	var is_mouse_click: bool = event is InputEventMouseButton and event.pressed
	if is_key_press or is_mouse_click:
		get_tree().change_scene_to_file(GAME_SCENE_PATH)
