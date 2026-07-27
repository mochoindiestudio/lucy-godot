extends Node3D

## Drives the character-focus camera and cross-lighting for the animation
## test ground. Left/right arrows step through _characters in order; camera
## framing and the warm/cool spotlights are derived purely from the focused
## character's X position, so no per-character tuning is needed.

const CAMERA_HEIGHT := 1.6
const CAMERA_DISTANCE := 3.5
const LOOK_AT_HEIGHT := 1.2

const TRANSITION_TIME := 0.8
const LIGHT_FADE_TIME := TRANSITION_TIME / 2.0
const LIGHT_ENERGY := 4.0

const LIGHT_HEIGHT := 3.2
const LIGHT_FORWARD_OFFSET := -1.0
const LIGHT_SIDE_OFFSET := 1.4
const LIGHT_CROSS_OFFSET := 0.6
const LIGHT_TARGET_HEIGHT := 0.3
const LIGHT_TARGET_FORWARD := 0.4

@onready var _camera: Camera3D = $Camera3D
@onready var _light_warm: SpotLight3D = $SpotLightWarm
@onready var _light_cool: SpotLight3D = $SpotLightCool
@onready var _ui: Control = $UI/AnimationShowcaseUI

## Left/right order matches the characters' left-to-right placement in the scene.
@onready var _characters: Array[Node3D] = [$Lucy, $Mario, $Mia, $Oscar, $Bella, $Giorgio, $Lucca]

var _focus_index := 0
var _is_transitioning := false

func _ready() -> void:
	var focused := _characters[_focus_index]
	_camera.global_transform = _camera_transform_for(focused)
	_position_lights(focused)
	_light_warm.light_energy = LIGHT_ENERGY
	_light_cool.light_energy = LIGHT_ENERGY
	_ui.show_character(focused)

func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning:
		return
	if event.is_action_pressed("ui_left"):
		_move_focus(1)
	elif event.is_action_pressed("ui_right"):
		_move_focus(-1)

## Left steps deeper into the lineup, right steps back; both stop at the ends.
func _move_focus(step: int) -> void:
	var target_index := _focus_index + step
	if target_index < 0 or target_index >= _characters.size():
		return
	_focus_index = target_index
	_transition_to(_characters[_focus_index])

func _transition_to(character: Node3D) -> void:
	_is_transitioning = true
	_ui.fade_name(0.0, LIGHT_FADE_TIME)

	var camera_tween := create_tween()
	camera_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	camera_tween.tween_property(_camera, "global_transform", _camera_transform_for(character), TRANSITION_TIME)

	var light_tween := create_tween()
	light_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	light_tween.tween_property(_light_warm, "light_energy", 0.0, LIGHT_FADE_TIME)
	light_tween.parallel().tween_property(_light_cool, "light_energy", 0.0, LIGHT_FADE_TIME)
	light_tween.tween_callback(_position_lights.bind(character))
	light_tween.tween_property(_light_warm, "light_energy", LIGHT_ENERGY, LIGHT_FADE_TIME)
	light_tween.parallel().tween_property(_light_cool, "light_energy", LIGHT_ENERGY, LIGHT_FADE_TIME)

	await light_tween.finished
	_is_transitioning = false
	_ui.show_character(character)
	_ui.fade_name(1.0, LIGHT_FADE_TIME)

func _camera_transform_for(character: Node3D) -> Transform3D:
	var char_x := character.global_position.x
	var eye := Vector3(char_x, CAMERA_HEIGHT, -CAMERA_DISTANCE)
	var look_at := Vector3(char_x, LOOK_AT_HEIGHT, 0.0)
	return Transform3D(Basis(), eye).looking_at(look_at, Vector3.UP)

## Two spots above opposite shoulders, each aimed past the character's
## centerline toward the other side, so their beams cross over the character.
func _position_lights(character: Node3D) -> void:
	var char_x := character.global_position.x
	_light_warm.global_transform = _spot_transform(char_x - LIGHT_SIDE_OFFSET, char_x + LIGHT_CROSS_OFFSET)
	_light_cool.global_transform = _spot_transform(char_x + LIGHT_SIDE_OFFSET, char_x - LIGHT_CROSS_OFFSET)

func _spot_transform(light_x: float, target_x: float) -> Transform3D:
	var eye := Vector3(light_x, LIGHT_HEIGHT, LIGHT_FORWARD_OFFSET)
	var look_at := Vector3(target_x, LIGHT_TARGET_HEIGHT, LIGHT_TARGET_FORWARD)
	return Transform3D(Basis(), eye).looking_at(look_at, Vector3.UP)
