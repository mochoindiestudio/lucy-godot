class_name InteractionArea
extends Area3D

## Sits on the player and detects nearby Interactable areas. Tracks the
## closest one in range and calls interact() on it when the "interact"
## action is pressed. HUD listens to nearest_interactable_changed to
## show/hide the prompt panel.

signal nearest_interactable_changed(interactable: Interactable)

var _candidates: Array[Interactable] = []
var _nearest: Interactable = null

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 2
	monitoring = true
	monitorable = false
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _unhandled_input(event: InputEvent) -> void:
	if _nearest != null and event.is_action_pressed("interact"):
		_nearest.interact()
		get_viewport().set_input_as_handled()

func _on_area_entered(area: Area3D) -> void:
	if area is Interactable:
		_candidates.append(area)
		_update_nearest()

func _on_area_exited(area: Area3D) -> void:
	if area is Interactable:
		_candidates.erase(area)
		_update_nearest()

func _update_nearest() -> void:
	var closest: Interactable = null
	var closest_dist_sq: float = INF
	for candidate in _candidates:
		var dist_sq: float = global_position.distance_squared_to(candidate.global_position)
		if dist_sq < closest_dist_sq:
			closest_dist_sq = dist_sq
			closest = candidate
	if closest != _nearest:
		_nearest = closest
		nearest_interactable_changed.emit(_nearest)
