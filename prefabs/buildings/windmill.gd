extends Node3D

## Spins the windmill's sail around its hub. Positive speed spins the
## RotorPivot node placed by tools/build_windmill_scene.gd; negative reverses
## the direction.
@export_range(-720.0, 720.0, 1.0, "suffix:deg/s") var rotation_speed_deg := 90.0

@onready var _rotor_pivot: Node3D = $RotorPivot

func _process(delta: float) -> void:
	_rotor_pivot.rotation.z += deg_to_rad(rotation_speed_deg) * delta
