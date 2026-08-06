class_name Toast
extends Control

## Bottom-center popup message, flanked by mirrored decorative flourishes.
## Fades in, holds for display_seconds, then fades out. Callers just push
## text via show_message() -- this node owns its own timing and animation.

@export var display_seconds: float = 4.0

const _FADE_SECONDS: float = 0.3

@onready var _label: Label = %MessageLabel
@onready var _timer: Timer = %HideTimer

var _fade_tween: Tween = null

func _ready() -> void:
	visible = false
	modulate.a = 0.0
	_timer.wait_time = display_seconds
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)

func show_message(text: String) -> void:
	_label.text = text
	visible = true
	_start_fade(1.0)
	_timer.start()

func _on_timer_timeout() -> void:
	_start_fade(0.0)
	_fade_tween.finished.connect(_on_fade_out_finished)

func _on_fade_out_finished() -> void:
	visible = false

func _start_fade(target_alpha: float) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", target_alpha, _FADE_SECONDS)
