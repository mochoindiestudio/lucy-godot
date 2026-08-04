extends Node3D

func TurnOn() -> void:
	$OmniLight3D.visible = true
	$OmniLight3D2.visible = true
	$OmniLight3D3.visible = true
	$OmniLight3D4.visible = true
	
func TurnOff() -> void:
	$OmniLight3D.visible = false
	$OmniLight3D2.visible = false
	$OmniLight3D3.visible = false
	$OmniLight3D4.visible = false
