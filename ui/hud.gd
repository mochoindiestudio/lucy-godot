extends Control

## Wires gameplay state (Lucy's energy pool and world position) to the HUD
## widgets parented under this node. A plain scene-scoped script -- not an
## autoload -- since the state it displays belongs to this scene's Player.

@export var energy_component_path: NodePath
@export var player_path: NodePath

@onready var _energy_bar: LucyEnergyBar = %EnergyBar
@onready var _energy_component: EnergyComponent = get_node_or_null(energy_component_path)
@onready var _minimap: Minimap = %Minimap
@onready var _player: Node3D = get_node_or_null(player_path)

func _ready() -> void:
	if _energy_component == null:
		push_warning("HUD: no EnergyComponent assigned; energy bar will not update.")
	else:
		_on_energy_changed(_energy_component.current_energy(), _energy_component.max_energy)
		_energy_component.energy_changed.connect(_on_energy_changed)
	if _player == null:
		push_warning("HUD: no player assigned; minimap will not scroll.")

func _process(_delta: float) -> void:
	if _player != null:
		_minimap.set_world_position(_player.global_position)

func _on_energy_changed(current: float, max_value: float) -> void:
	_energy_bar.energy_percent = _to_percent(current, max_value)

func _to_percent(current: float, max_value: float) -> float:
	if max_value <= 0.0:
		return 0.0
	return (current / max_value) * 100.0
