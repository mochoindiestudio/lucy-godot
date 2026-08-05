class_name EnergyComponent
extends Node

## Generic 0..max energy pool. Knows nothing about what spends or restores
## it (shining a light, recovery zones, etc.) -- callers decide that.

signal energy_changed(current: float, max: float)
signal energy_depleted

@export var max_energy := 100.0
@export var starting_energy := 100.0

var _current_energy := 0.0

func _ready() -> void:
	_current_energy = clamp(starting_energy, 0.0, max_energy)

func current_energy() -> float:
	return _current_energy

## Spends `amount` if there's enough energy available; returns false and
## leaves the pool untouched otherwise.
func try_spend(amount: float) -> bool:
	if _current_energy < amount:
		return false
	_set_energy(_current_energy - amount)
	return true

## Restores energy, e.g. while standing in a recovery region.
func recover(amount: float) -> void:
	_set_energy(_current_energy + amount)

func _set_energy(value: float) -> void:
	var clamped := clampf(value, 0.0, max_energy)
	if is_equal_approx(clamped, _current_energy):
		return
	_current_energy = clamped
	energy_changed.emit(_current_energy, max_energy)
	if _current_energy <= 0.0:
		energy_depleted.emit()
