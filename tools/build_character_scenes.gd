## Regenerates the shared animation library and the per-character preview scenes
## under res://characters/. Run with:
##   Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tools/build_character_scenes.gd
extends SceneTree

const ANIM_SOURCES := {
	"idle": "res://animations/idle.fbx",
	"walking": "res://animations/walking.fbx",
	"slow_run": "res://animations/slow_run.fbx",
	"talking_1": "res://animations/talking_1.fbx",
	"talking_2": "res://animations/talking_2.fbx",
}
const STATE_NAMES := ["idle", "walking", "slow_run", "talking_1", "talking_2"]
const LIBRARY_NAME := "moves"
const LIBRARY_PATH := "res://animations/library/character_moves.tres"
const XFADE_TIME := 0.35
const PREVIEW_SCRIPT_PATH := "res://characters/character_preview.gd"

const CHARACTERS := [
	{"id": "lucy", "source": "res://models/lucy.fbx", "out": "res://characters/lucy.tscn"},
	{"id": "bella", "source": "res://models/npcs/bella.fbx", "out": "res://characters/npcs/bella.tscn"},
	{"id": "giorgio", "source": "res://models/npcs/giorgio.fbx", "out": "res://characters/npcs/giorgio.tscn"},
	{"id": "mario", "source": "res://models/npcs/mario.fbx", "out": "res://characters/npcs/mario.tscn"},
	{"id": "mia", "source": "res://models/npcs/mia.fbx", "out": "res://characters/npcs/mia.tscn"},
	{"id": "oscar", "source": "res://models/npcs/oscar.fbx", "out": "res://characters/npcs/oscar.tscn"},
	{"id": "spark", "source": "res://models/npcs/spark.fbx", "out": "res://characters/npcs/spark.tscn"},
]

func _initialize():
	var library := _build_animation_library()
	DirAccess.make_dir_recursive_absolute("res://animations/library")
	var err := ResourceSaver.save(library, LIBRARY_PATH)
	if err != OK:
		push_error("Failed to save animation library: %s" % err)
		quit(1)
		return
	print("Saved ", LIBRARY_PATH)

	# Reload from disk so every character scene references the same saved
	# resource (by uid/path) instead of an in-memory copy.
	var saved_library: AnimationLibrary = load(LIBRARY_PATH)

	for data in CHARACTERS:
		_build_character_scene(data, saved_library)

	print("Done.")
	quit()

func _build_animation_library() -> AnimationLibrary:
	var library := AnimationLibrary.new()
	for state_name in STATE_NAMES:
		var path: String = ANIM_SOURCES[state_name]
		var packed: PackedScene = load(path)
		var instance := packed.instantiate()
		var source_player := _find_animation_player(instance)
		var anim: Animation = source_player.get_animation("mixamo_com").duplicate(true)
		anim.loop_mode = Animation.LOOP_LINEAR
		anim.resource_name = state_name
		library.add_animation(state_name, anim)
		instance.free()
	return library

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _build_character_scene(data: Dictionary, library: AnimationLibrary) -> void:
	var source_packed: PackedScene = load(data.source)
	var model := source_packed.instantiate()
	model.name = "Model"

	var root := Node3D.new()
	root.name = data.id.capitalize().replace(" ", "")
	root.set_script(load(PREVIEW_SCRIPT_PATH))
	root.add_child(model)
	model.owner = root

	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	anim_player.root_node = NodePath("../Model")
	root.add_child(anim_player)
	anim_player.owner = root
	anim_player.add_animation_library(LIBRARY_NAME, library)

	var anim_tree := AnimationTree.new()
	anim_tree.name = "AnimationTree"
	root.add_child(anim_tree)
	anim_tree.owner = root
	anim_tree.anim_player = NodePath("../AnimationPlayer")
	anim_tree.tree_root = _build_state_machine()

	var scene := PackedScene.new()
	var pack_err := scene.pack(root)
	if pack_err != OK:
		push_error("Failed to pack scene for %s: %s" % [data.id, pack_err])
		root.free()
		return

	DirAccess.make_dir_recursive_absolute(data.out.get_base_dir())
	var save_err := ResourceSaver.save(scene, data.out)
	if save_err != OK:
		push_error("Failed to save scene for %s: %s" % [data.id, save_err])
	else:
		print("Saved ", data.out)
	root.free()

## Every state can transition directly to every other state, crossfading over
## XFADE_TIME seconds. (Per-character start-frame variation is applied at
## runtime via character_preview.gd's start_offset export, since
## AnimationNodeAnimation.start_offset is a runtime-only parameter and isn't
## persisted when the state machine resource is saved.)
func _build_state_machine() -> AnimationNodeStateMachine:
	var sm := AnimationNodeStateMachine.new()

	for i in STATE_NAMES.size():
		var state_name: String = STATE_NAMES[i]
		var anim_node := AnimationNodeAnimation.new()
		anim_node.animation = "%s/%s" % [LIBRARY_NAME, state_name]
		sm.add_node(state_name, anim_node, Vector2(i * 220, (i % 2) * 140))

	for from_name in STATE_NAMES:
		for to_name in STATE_NAMES:
			if from_name == to_name:
				continue
			var transition := AnimationNodeStateMachineTransition.new()
			transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
			transition.xfade_time = XFADE_TIME
			transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_DISABLED
			sm.add_transition(from_name, to_name, transition)

	return sm
