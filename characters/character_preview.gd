extends Node3D

const DEFAULT_STATE := "idle"

@onready var _anim_tree: AnimationTree = $AnimationTree

func _ready() -> void:
	add_to_group("character_anim_trees")
	_anim_tree.active = true
	_playback().start(DEFAULT_STATE)

## Crossfades into the given animation state ("idle", "walking", "slow_run",
## "talking_1" or "talking_2"). Every state can travel to every other state.
func play_state(state_name: String) -> void:
	_playback().travel(state_name)

func _playback() -> AnimationNodeStateMachinePlayback:
	return _anim_tree.get("parameters/playback")
