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

## Subtle hand-held sway applied on top of the framed camera shot.
@export_group("Handheld Camera Shake")
@export var shake_enabled := true
@export_range(0.0, 0.05, 0.001, "suffix:m") var shake_position_amount := 0.008
@export_range(0.0, 3.0, 0.01, "suffix:deg") var shake_rotation_amount := 0.25
@export_range(0.0, 3.0, 0.01) var shake_speed := 0.6

@onready var _camera: Camera3D = $Camera3D
@onready var _light_warm: SpotLight3D = $SpotLightWarm
@onready var _light_cool: SpotLight3D = $SpotLightCool
@onready var _ui: Control = $UI/AnimationShowcaseUI

## Left/right order matches the characters' left-to-right placement in the scene.
@onready var _characters: Array[Node3D] = [$Lucy, $Mario, $Mia, $Oscar, $Bella, $Giorgio, $Lucca]

var _focus_index := 0
var _is_transitioning := false

## The clean, tween-driven camera shot, before shake is layered on top.
var _camera_base_transform := Transform3D()
var _shake_time := 0.0
## One noise per axis, each with a distinct seed, so the axes wander independently.
var _position_noise: Array[FastNoiseLite] = []
var _rotation_noise: Array[FastNoiseLite] = []

func _ready() -> void:
	_position_noise = [_make_shake_noise(1), _make_shake_noise(2), _make_shake_noise(3)]
	_rotation_noise = [_make_shake_noise(4), _make_shake_noise(5), _make_shake_noise(6)]

	var focused := _characters[_focus_index]
	_camera_base_transform = _camera_transform_for(focused)
	_camera.global_transform = _camera_base_transform
	_position_lights(focused)
	_light_warm.light_energy = LIGHT_ENERGY
	_light_cool.light_energy = LIGHT_ENERGY
	_ui.show_character(focused)

func _process(delta: float) -> void:
	if not shake_enabled:
		_camera.transform = _camera_base_transform
		return
	_shake_time += delta
	_camera.transform = _camera_base_transform * _handheld_offset()

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
	camera_tween.tween_property(self, "_camera_base_transform", _camera_transform_for(character), TRANSITION_TIME)

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

func _make_shake_noise(seed_value: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 1.0
	return noise

## A small local-space offset (position sway + rotation wobble) sampled from
## smooth noise, composed on top of _camera_base_transform each frame.
func _handheld_offset() -> Transform3D:
	var t := _shake_time * shake_speed
	var position_offset := Vector3(
		_position_noise[0].get_noise_1d(t),
		_position_noise[1].get_noise_1d(t),
		_position_noise[2].get_noise_1d(t)
	) * shake_position_amount
	var rotation_offset := Vector3(
		_rotation_noise[0].get_noise_1d(t),
		_rotation_noise[1].get_noise_1d(t),
		_rotation_noise[2].get_noise_1d(t)
	) * deg_to_rad(shake_rotation_amount)
	return Transform3D(Basis.from_euler(rotation_offset), position_offset)
