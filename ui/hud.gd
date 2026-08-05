extends Control

## Wires gameplay state (currently just Lucy's energy pool) to the HUD
## widgets parented under this node. A plain scene-scoped script -- not an
## autoload -- since the state it displays belongs to this scene's Player.

@export var energy_component_path: NodePath

@onready var _energy_bar: LucyEnergyBar = %EnergyBar
@onready var _energy_component: EnergyComponent = get_node_or_null(energy_component_path)

func _ready() -> void:
	if _energy_component == null:
		push_warning("HUD: no EnergyComponent assigned; energy bar will not update.")
		return
	_on_energy_changed(_energy_component.current_energy(), _energy_component.max_energy)
	_energy_component.energy_changed.connect(_on_energy_changed)

func _on_energy_changed(current: float, max_value: float) -> void:
	_energy_bar.energy_percent = _to_percent(current, max_value)

func _to_percent(current: float, max_value: float) -> float:
	if max_value <= 0.0:
		return 0.0
	return (current / max_value) * 100.0
