# Copyright © 2023-2026 Cory Petkovsek, Roope Palmroos, and Contributors.
# Saveable collection of Terrain3DVegetationGroup, stored alongside a terrain's data directory.
extends Resource
class_name Terrain3DVegetationGroups

const VegetationGroup: Script = preload("res://addons/terrain_3d/menu/vegetation_group.gd")

@export var groups: Array[VegetationGroup] = []


static func get_save_path(p_data_directory: String) -> String:
	return p_data_directory.path_join("vegetation_groups.tres")


static func load_or_create(p_data_directory: String) -> Terrain3DVegetationGroups:
	var path: String = get_save_path(p_data_directory)
	if ResourceLoader.exists(path):
		var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res is Terrain3DVegetationGroups:
			return res
	return Terrain3DVegetationGroups.new()


func save(p_data_directory: String) -> void:
	ResourceSaver.save(self, get_save_path(p_data_directory))
