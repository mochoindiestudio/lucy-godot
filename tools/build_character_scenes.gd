## Regenerates the per-character animation libraries and preview scenes under
## res://characters/. Each character owns its own dedicated animation clips
## (baked on its own rig), so libraries are not shared across characters.
## Run with:
##   Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tools/build_character_scenes.gd
extends SceneTree

const XFADE_TIME := 0.35
const LIBRARY_NAME := "moves"
const PREVIEW_SCRIPT_PATH := "res://characters/character_preview.gd"

const CHARACTERS := [
	{
		"id": "lucy",
		"source": "res://models/lucy.fbx",
		"out": "res://characters/lucy.tscn",
		"anim_sources": {
			"idle": "res://animations/idle.fbx",
			"walking": "res://animations/walking.fbx",
			"slow_run": "res://animations/slow_run.fbx",
			"talking_1": "res://animations/talking_1.fbx",
			"talking_2": "res://animations/talking_2.fbx",
		},
	},
	{
		"id": "bella",
		"source": "res://models/npcs/bella_rigged.fbx",
		"out": "res://characters/npcs/bella.tscn",
		"albedo": "res://models/npcs/bella_albedo.png",
		"anim_sources": {
			"idle": "res://animations/bella_idle.fbx",
			"talk": "res://animations/bella_talk.fbx",
		},
	},
	{
		"id": "giorgio",
		"source": "res://models/npcs/giorgio_rigged.fbx",
		"out": "res://characters/npcs/giorgio.tscn",
		"albedo": "res://models/npcs/giorgio_albedo.png",
		"anim_sources": {
			"idle": "res://animations/giorgio_idle.fbx",
			"talking": "res://animations/giorgio_talking.fbx",
			"bubbles": "res://animations/giorgio_bubbles.fbx",
		},
	},
	{
		"id": "lucca",
		"source": "res://models/npcs/lucca_rigged.fbx",
		"out": "res://characters/npcs/lucca.tscn",
		"albedo": "res://models/npcs/lucca_albedo.png",
		"anim_sources": {
			"idle": "res://animations/lucca_idle.fbx",
			"walking": "res://animations/lucca_walking.fbx",
			"running": "res://animations/lucca_running.fbx",
		},
	},
	{
		"id": "mario",
		"source": "res://models/npcs/mario_rigged.fbx",
		"out": "res://characters/npcs/mario.tscn",
		"albedo": "res://models/npcs/mario_albedo.png",
		"anim_sources": {
			"idle": "res://animations/mario_idle.fbx",
			"talking": "res://animations/mario_talking.fbx",
		},
	},
	{
		"id": "mia",
		"source": "res://models/npcs/mia_rigged.fbx",
		"out": "res://characters/npcs/mia.tscn",
		"albedo": "res://models/npcs/mia_albedo.png",
		"anim_sources": {
			"idle": "res://animations/mia_idle.fbx",
			"idle_alt": "res://animations/mia_idle_alt.fbx",
			"talking": "res://animations/mia_talking.fbx",
		},
	},
	{
		"id": "oscar",
		"source": "res://models/npcs/oscar_rigged.fbx",
		"out": "res://characters/npcs/oscar.tscn",
		"albedo": "res://models/npcs/oscar_albedo.png",
		"anim_sources": {
			"idle": "res://animations/oscar_idle.fbx",
			"talking": "res://animations/oscar_talking.fbx",
		},
	},
]

func _initialize():
	for data in CHARACTERS:
		var library := _build_animation_library(data.anim_sources)
		_build_character_scene(data, library)

	print("Done.")
	quit()

func _build_animation_library(anim_sources: Dictionary) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	for state_name in anim_sources:
		var path: String = anim_sources[state_name]
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

## The rigged fbx source has no embedded texture, so every mesh surface gets
## a fresh material pointing at the character's albedo texture (recovered
## from the original unrigged model/glb). Descendants of the instanced model
## need their owner set to the packed scene's root for the override to
## actually persist on save (same as toggling "Editable Children" in the
## editor before overriding a property on an instanced scene's child).
func _apply_albedo_texture(node: Node, texture: Texture2D, owner: Node) -> void:
	node.owner = owner
	if node is MeshInstance3D:
		var mesh: Mesh = node.mesh
		for i in mesh.get_surface_count():
			var material := StandardMaterial3D.new()
			material.albedo_texture = texture
			node.set_surface_override_material(i, material)
	for child in node.get_children():
		_apply_albedo_texture(child, texture, owner)

func _build_character_scene(data: Dictionary, library: AnimationLibrary) -> void:
	var source_packed: PackedScene = load(data.source)
	var model := source_packed.instantiate()
	model.name = "Model"

	var root := Node3D.new()
	root.name = data.id.capitalize().replace(" ", "")
	root.set_script(load(PREVIEW_SCRIPT_PATH))
	root.add_child(model)
	model.owner = root

	if data.has("albedo"):
		# Overriding materials on descendants of an instanced sub-scene only
		# sticks if those descendants are packed as plain owned nodes rather
		# than re-collapsed back into an "instance=" reference, so drop the
		# link to the source PackedScene before flattening ownership.
		model.scene_file_path = ""
		_apply_albedo_texture(model, load(data.albedo), root)

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
	anim_tree.tree_root = _build_state_machine(data.anim_sources.keys())

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
## XFADE_TIME seconds.
func _build_state_machine(state_names: Array) -> AnimationNodeStateMachine:
	var sm := AnimationNodeStateMachine.new()

	for i in state_names.size():
		var state_name: String = state_names[i]
		var anim_node := AnimationNodeAnimation.new()
		anim_node.animation = "%s/%s" % [LIBRARY_NAME, state_name]
		sm.add_node(state_name, anim_node, Vector2(i * 220, (i % 2) * 140))

	for from_name in state_names:
		for to_name in state_names:
			if from_name == to_name:
				continue
			var transition := AnimationNodeStateMachineTransition.new()
			transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
			transition.xfade_time = XFADE_TIME
			transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_DISABLED
			sm.add_transition(from_name, to_name, transition)

	return sm
