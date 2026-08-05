class_name LoveLight
extends OmniLight3D

## Firefly light: stays off until activated, flickers organically while lit
## via 1D Perlin noise (deterministic per flicker_seed), and auto-shuts-off
## after AutoOffTimer elapses.

signal shine_started
signal shine_ended

@export_group("Flicker")
@export var flicker_enabled := true
@export var flicker_speed := 6.0
@export var flicker_intensity := 0.35
@export var flicker_seed := 0

@onready var _auto_off_timer: Timer = $AutoOffTimer

var _base_energy := 1.0
var _time := 0.0
## Built lazily in _process rather than _ready so a flicker_seed assigned
## by an owner after this node's _ready (e.g. Player forwarding its own
## export) still takes effect.
var _noise: FastNoiseLite

func _ready() -> void:
	_base_energy = light_energy
	_auto_off_timer.one_shot = true
	_auto_off_timer.timeout.connect(deactivate)

func _process(delta: float) -> void:
	if not visible or not flicker_enabled:
		return
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = flicker_seed
		_noise.frequency = 1.0
	_time += delta
	var flicker := _noise.get_noise_1d(_time * flicker_speed)
	light_energy = _base_energy * (1.0 + flicker_intensity * flicker)

func activate() -> void:
	visible = true
	_time = 0.0
	light_energy = _base_energy
	_auto_off_timer.start()
	shine_started.emit()

func deactivate() -> void:
	visible = false
	light_energy = _base_energy
	_auto_off_timer.stop()
	shine_ended.emit()

func is_active() -> bool:
	return visible
