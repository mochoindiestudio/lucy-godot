class_name Interactable
extends Area3D

## Generic "this can be interacted with" marker. Drop as a child of any
## object -- the CollisionShape3D on this node defines how close Lucy
## needs to be. InteractionArea (on the player) detects it and calls
## interact() when the player presses the interact action; this node
## only broadcasts the result, it has no opinion on what happens next.

@export var prompt_text: String = "Interagir"
## Shown in a Toast (or later, a dialog) when the player interacts.
## Left empty, interacting produces no message -- just the `interacted` signal.
@export_multiline var message: String = ""
## World-space offset (added to global_position) where the prompt panel
## should float -- tune per object so it clears the model's head/roofline.
@export var label_offset: Vector3 = Vector3(0, 2.0, 0)

signal interacted

func _ready() -> void:
	collision_layer = 1 << 2
	collision_mask = 0
	monitoring = false
	monitorable = true

func interact() -> void:
	interacted.emit()
