extends Node3D

const DEFAULT_STATE := "idle"

@onready var _anim_tree: AnimationTree = $AnimationTree

func _ready() -> void:
	_anim_tree.active = true
	_playback().start(DEFAULT_STATE)

## Crossfades into the given animation state. Every state can travel to
## every other state.
func play_state(state_name: String) -> void:
	_playback().travel(state_name)

## Returns this character's animation state names, sorted for a stable
## button order (each character has its own set, baked by
## tools/build_character_scenes.gd).
func get_state_names() -> PackedStringArray:
	var state_machine: AnimationNodeStateMachine = _anim_tree.tree_root
	var names := PackedStringArray()
	for state_name in state_machine.get_node_list():
		if state_name != "Start" and state_name != "End":
			names.append(state_name)
	names.sort()
	return names

func _playback() -> AnimationNodeStateMachinePlayback:
	return _anim_tree.get("parameters/playback")
