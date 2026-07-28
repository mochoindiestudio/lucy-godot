## Regenerates res://buildings/windmill.tscn: the static tower
## (windmill_base.fbx) plus the rotating sail (windmill_rotor.fbx), mounted
## on a pivot near the top-front of the tower. windmill.gd spins the pivot
## at runtime; rotation_speed_deg is exposed on it as an Inspector variable.
## Run with:
##   Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tools/build_windmill_scene.gd
extends SceneTree

const OUT_PATH := "res://buildings/windmill.tscn"
const SCRIPT_PATH := "res://buildings/windmill.gd"

const BASE_PATH := "res://models/buildings/windmill_base.fbx"
const ROTOR_PATH := "res://models/buildings/windmill_rotor.glb"

## Where the sail's hub sits relative to the tower root, once the tower's
## own base has been rested on the floor (y = 0). windmill_rotor.fbx is
## already modeled with its hub at its own origin, so the pivot just needs
## placing at the mount point; the rotor mesh hangs off it at (0, 0, 0).
const ROTOR_MOUNT := Vector3(0.0, 0.85, -0.4)

func _initialize():
	var tower: Node3D = load(BASE_PATH).instantiate()
	tower.name = "Model"
	tower.transform.origin.y = -_local_min_y(tower, Transform3D())

	var rotor: Node3D = load(ROTOR_PATH).instantiate()
	rotor.name = "Model"

	var rotor_pivot := Node3D.new()
	rotor_pivot.name = "RotorPivot"
	rotor_pivot.transform.origin = ROTOR_MOUNT

	var root := Node3D.new()
	root.name = "Windmill"
	root.set_script(load(SCRIPT_PATH))

	root.add_child(tower)
	tower.owner = root

	root.add_child(rotor_pivot)
	rotor_pivot.owner = root
	rotor_pivot.add_child(rotor)
	rotor.owner = root

	var scene := PackedScene.new()
	var pack_err := scene.pack(root)
	if pack_err != OK:
		push_error("Failed to pack windmill scene: %s" % pack_err)
		root.free()
		quit()
		return

	DirAccess.make_dir_recursive_absolute(OUT_PATH.get_base_dir())
	var save_err := ResourceSaver.save(scene, OUT_PATH)
	if save_err != OK:
		push_error("Failed to save windmill scene: %s" % save_err)
	else:
		print("Saved ", OUT_PATH)
	root.free()
	quit()

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
