class_name LucyEnergyBar
extends Control

## Threshold at/below which Lucy's portrait switches to the sad expression.
const SAD_THRESHOLD_PERCENT := 30.0

## Native width of the track's inner (masked) fill area, in pixels.
const FILL_FULL_WIDTH := 128.0

const HAPPY_PORTRAIT := preload("res://ui/images/portraits/lucy_happy.png")
const SAD_PORTRAIT := preload("res://ui/images/portraits/lucy_sad.png")

## Emitted whenever the displayed energy percentage changes.
signal energy_changed(value_percent: float)
## Emitted whenever Lucy's portrait mood flips (crossing SAD_THRESHOLD_PERCENT).
signal mood_changed(is_sad: bool)

@export_range(0.0, 100.0, 0.1) var energy_percent: float = 100.0:
	set(value):
		var clamped: float = clampf(value, 0.0, 100.0)
		if is_equal_approx(clamped, energy_percent):
			return
		energy_percent = clamped
		if is_node_ready():
			_refresh()
		energy_changed.emit(energy_percent)

@onready var _fill_clip: Control = %FillClip
@onready var _portrait: TextureRect = %Portrait

var _is_sad: bool = false

func _ready() -> void:
	_refresh()

func _refresh() -> void:
	_fill_clip.size.x = FILL_FULL_WIDTH * (energy_percent / 100.0)
	var should_be_sad: bool = energy_percent <= SAD_THRESHOLD_PERCENT
	if should_be_sad == _is_sad:
		return
	_is_sad = should_be_sad
	_portrait.texture = SAD_PORTRAIT if _is_sad else HAPPY_PORTRAIT
	mood_changed.emit(_is_sad)
