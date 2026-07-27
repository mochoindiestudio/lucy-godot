extends Node3D

const DEFAULT_STATE := "idle"

## Per-instance variation so identical animations don't visibly sync up
## across characters standing side by side: each character joins the idle
## loop at a different real point in time, so they settle into different
## phases of the same clip.
@export_range(0.0, 10.0, 0.01, "suffix:s") var start_offset: float = 0.0

@onready var _anim_tree: AnimationTree = $AnimationTree

func _ready() -> void:
	add_to_group("character_anim_trees")
	_anim_tree.active = true
	if start_offset > 0.0:
		await get_tree().create_timer(start_offset).timeout
	_playback().start(DEFAULT_STATE)

## Crossfades into the given animation state ("idle", "walking", "slow_run",
## "talking_1" or "talking_2"). Every state can travel to every other state.
func play_state(state_name: String) -> void:
	_playback().travel(state_name)

func _playback() -> AnimationNodeStateMachinePlayback:
	return _anim_tree.get("parameters/playback")
