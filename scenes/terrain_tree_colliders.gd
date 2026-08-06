class_name TerrainTreeColliders
extends Node3D
## Spawns static trunk colliders for Terrain3D-painted meshes whose asset name
## starts with one of solid_mesh_prefixes, so the player can't walk through them.
## Terrain3D's instancer is visual-only (MultiMesh) and exposes no collision API,
## so this reconstructs collider positions from the saved region instance data
## on load instead.

@export var terrain_path: NodePath
@export var solid_mesh_prefixes: Array[String] = []
@export var trunk_radius: float = 0.5
@export var trunk_height: float = 4.0


func _ready() -> void:
	var terrain := get_node_or_null(terrain_path) as Terrain3D
	if not terrain or not terrain.data:
		return
	var mesh_ids := _resolve_mesh_ids(terrain)
	if mesh_ids.is_empty():
		return
	var shape := CapsuleShape3D.new()
	shape.radius = trunk_radius
	shape.height = trunk_height
	for region in terrain.data.get_regions_active(false, false):
		_spawn_region_colliders(region, mesh_ids, shape)


func _resolve_mesh_ids(terrain: Terrain3D) -> Array[int]:
	var ids: Array[int] = []
	for asset in terrain.assets.mesh_list:
		for prefix in solid_mesh_prefixes:
			if asset.name.begins_with(prefix):
				ids.append(asset.id)
				break
	return ids


func _spawn_region_colliders(region: Terrain3DRegion, mesh_ids: Array[int], shape: CapsuleShape3D) -> void:
	var region_offset := Vector3(region.location.x, 0.0, region.location.y) * region.region_size * region.vertex_spacing
	for mesh_id in mesh_ids:
		if not region.instances.has(mesh_id):
			continue
		for cell_data in region.instances[mesh_id].values():
			for instance_transform: Transform3D in cell_data[0]:
				_spawn_trunk(region_offset + instance_transform.origin, shape)


func _spawn_trunk(base_position: Vector3, shape: CapsuleShape3D) -> void:
	var body := StaticBody3D.new()
	body.position = base_position + Vector3(0.0, trunk_height * 0.5, 0.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
