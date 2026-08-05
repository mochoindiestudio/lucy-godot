extends Node3D

@onready var _interactable: Interactable = $Interactable

func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)

func _on_interacted() -> void:
	print("Directions signpost interacted with.")
