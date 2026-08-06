extends Control

## Wires gameplay state (Lucy's energy pool and world position) to the HUD
## widgets parented under this node. A plain scene-scoped script -- not an
## autoload -- since the state it displays belongs to this scene's Player.

@export var energy_component_path: NodePath
@export var player_path: NodePath
@export var interaction_area_path: NodePath

## Relative to player_path -- where the Player's active Camera3D lives.
@export var camera_relative_path: NodePath = ^"CameraPivot/SpringArm3D/Camera3D"

@onready var _energy_bar: LucyEnergyBar = %EnergyBar
@onready var _energy_component: EnergyComponent = get_node_or_null(energy_component_path)
@onready var _minimap: Minimap = %Minimap
@onready var _player: Node3D = get_node_or_null(player_path)
@onready var _interact_panel: InteractPanel = %InteractPanel
@onready var _toast: Toast = %Toast
@onready var _interaction_area: InteractionArea = get_node_or_null(interaction_area_path)
@onready var _camera: Camera3D = _get_camera()

var _tracked_interactable: Interactable = null

func _ready() -> void:
	if _energy_component == null:
		push_warning("HUD: no EnergyComponent assigned; energy bar will not update.")
	else:
		_on_energy_changed(_energy_component.current_energy(), _energy_component.max_energy)
		_energy_component.energy_changed.connect(_on_energy_changed)
	if _player == null:
		push_warning("HUD: no player assigned; minimap will not scroll.")
	if _interaction_area == null:
		push_warning("HUD: no InteractionArea assigned; interact panel will not show.")
	else:
		_interaction_area.nearest_interactable_changed.connect(_on_nearest_interactable_changed)
	if _camera == null:
		push_warning("HUD: no camera assigned; interact panel will not track its target.")

func _process(_delta: float) -> void:
	if _player != null:
		_minimap.set_world_position(_player.global_position)
	_update_interact_panel_position()

func _on_nearest_interactable_changed(interactable: Interactable) -> void:
	if _tracked_interactable != null:
		_tracked_interactable.interacted.disconnect(_on_tracked_interactable_interacted)
	_tracked_interactable = interactable
	if interactable == null:
		_interact_panel.hide_prompt()
	else:
		_interact_panel.show_prompt(interactable.prompt_text)
		interactable.interacted.connect(_on_tracked_interactable_interacted)

func _on_tracked_interactable_interacted() -> void:
	if _tracked_interactable != null and not _tracked_interactable.message.is_empty():
		_toast.show_message(_tracked_interactable.message)

func _get_camera() -> Camera3D:
	if _player == null:
		return null
	return _player.get_node_or_null(camera_relative_path)

func _update_interact_panel_position() -> void:
	if _tracked_interactable == null or _camera == null:
		return
	var offset: Vector3 = _tracked_interactable.label_offset
	var world_pos: Vector3 = _tracked_interactable.global_position + offset
	if _camera.is_position_behind(world_pos):
		_interact_panel.visible = false
		return
	_interact_panel.visible = true
	var screen_pos: Vector2 = _camera.unproject_position(world_pos)
	var panel_size: Vector2 = _interact_panel.size
	_interact_panel.position = screen_pos - Vector2(panel_size.x / 2.0, panel_size.y)

func _on_energy_changed(current: float, max_value: float) -> void:
	_energy_bar.energy_percent = _to_percent(current, max_value)

func _to_percent(current: float, max_value: float) -> float:
	if max_value <= 0.0:
		return 0.0
	return (current / max_value) * 100.0
