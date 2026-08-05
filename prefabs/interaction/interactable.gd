class_name Interactable
extends Area3D

## Generic "this can be interacted with" marker. Drop as a child of any
## object -- the CollisionShape3D on this node defines how close Lucy
## needs to be. InteractionArea (on the player) detects it and calls
## interact() when the player presses the interact action; this node
## only broadcasts the result, it has no opinion on what happens next.

@export var prompt_text: String = "Interagir"

signal interacted

func _ready() -> void:
	collision_layer = 1 << 2
	collision_mask = 0
	monitoring = false
	monitorable = true

func interact() -> void:
	interacted.emit()
