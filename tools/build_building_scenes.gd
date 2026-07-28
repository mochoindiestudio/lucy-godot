## Regenerates the per-building preview scenes under res://buildings/. Each
## building is a single static mesh with its albedo already wired up inside
## the fbx material, so unlike tools/build_character_scenes.gd there is no
## animation library or texture override to bake — only a vertical offset so
## the model's own bounding box rests on the floor (y = 0) instead of at
## whatever off-center pivot the source fbx happens to use.
## Run with:
##   Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tools/build_building_scenes.gd
extends SceneTree

const OUT_DIR := "res://buildings/"

const BUILDINGS := [
	"cat_statue",
	"house_01", "house_02", "house_03", "house_04", "house_05",
	"house_06", "house_07", "house_08", "house_09",
	"architect", "market_shop", "market_stand", "pharmacy", "toy_shop",
	"wall_lamp_1", "wall_lamp_2",
]

func _initialize():
	for id in BUILDINGS:
		_build_building_scene(id)

	print("Done.")
	quit()

func _build_building_scene(id: String) -> void:
	var source_path := "res://models/buildings/%s.fbx" % id
	var source_packed: PackedScene = load(source_path)
	var model := source_packed.instantiate()
	model.name = "Model"

	var root := Node3D.new()
	root.name = id.capitalize()
	root.add_child(model)
	model.owner = root

	var min_y: float = _local_min_y(model, Transform3D())
	model.transform.origin.y = -min_y

	var scene := PackedScene.new()
	var pack_err := scene.pack(root)
	if pack_err != OK:
		push_error("Failed to pack scene for %s: %s" % [id, pack_err])
		root.free()
		return

	var out_path := "%s%s.tscn" % [OUT_DIR, id]
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var save_err := ResourceSaver.save(scene, out_path)
	if save_err != OK:
		push_error("Failed to save scene for %s: %s" % [id, save_err])
	else:
		print("Saved ", out_path)
	root.free()

## Lowest Y reached by any mesh surface under node, in the space of
## parent_xform (pass an identity Transform3D for node's own local space).
func _local_min_y(node: Node, parent_xform: Transform3D) -> float:
	var xform := parent_xform
	if node is Node3D:
		xform = parent_xform * node.transform

	var min_y := INF
	if node is MeshInstance3D:
		var aabb: AABB = node.mesh.get_aabb()
		for i in 8:
			min_y = minf(min_y, (xform * aabb.get_endpoint(i)).y)

	for child in node.get_children():
		min_y = minf(min_y, _local_min_y(child, xform))

	return min_y
