extends Node3D

## Very subtle idle bob/roll/pitch to sell the ship sitting on moving water.
## Deliberately not synced to the ocean shader's actual wave height (addons/terrain_3d/extras/shaders/ocean_shader.gdshader) —
## that would require porting its noise function to GDScript for a barely-visible effect.
@export_range(0.0, 1.0, 0.01, "suffix:m") var bob_height := 0.08
@export_range(0.0, 15.0, 0.1, "suffix:deg") var roll_amount := 1.5
@export_range(0.0, 15.0, 0.1, "suffix:deg") var pitch_amount := 1.0
@export_range(0.0, 2.0, 0.01, "suffix:Hz") var sway_speed := 0.35

## Roll/pitch run at slightly different multiples of sway_speed so the ship
## doesn't bob, roll, and pitch in perfect lockstep, which would read as robotic.
const ROLL_FREQUENCY_MULT := 0.8
const PITCH_FREQUENCY_MULT := 0.6

@export_group("Flag Wind")
## Only mesh nodes whose name contains this (case-insensitive) get the flag
## wave shader — matches the "flag"/"flag.001" nodes the ship model's flags
## were split into. Everything else (hull, sails, rigging) is left alone.
@export var flag_node_name_contains := "flag"
@export_range(0.0, 10.0, 0.01, "suffix:Hz") var flag_wave_speed := 3.0
## Number of full wave cycles from the pole edge to the flag's farthest point.
@export_range(0.5, 20.0, 0.1) var flag_wave_cycle_count := 3.0
## Max displacement along the flag's flap axis (its narrowest local
## dimension, i.e. face-normal direction), as a fraction of the flag's
## pole-to-tip length — scale-independent, and reaches full strength only
## at the tip, so the pole edge stays put.
@export_range(0.0, 0.5, 0.005) var flag_wave_strength_fraction := 0.15

## Editor-converted copy of the ship's actual material (Inspector ->
## material -> Convert to ShaderMaterial), with the flag_wind vertex
## displacement added directly into it -- not a from-scratch reconstruction,
## so its non-wind uniforms (texture_albedo, texture_metallic, etc.) are
## Godot's own generated names, not ones we chose.
const FLAG_WIND_SHADER := preload("res://materials/ship_flag.gdshader")

## BaseMaterial3D.TextureChannel -> one-hot vec4 mask, matching how the
## editor's "Convert to ShaderMaterial" bakes texture_metallic_channel.
const _TEXTURE_CHANNEL_MASKS := [
	Vector4(1.0, 0.0, 0.0, 0.0), # RED
	Vector4(0.0, 1.0, 0.0, 0.0), # GREEN
	Vector4(0.0, 0.0, 1.0, 0.0), # BLUE
	Vector4(0.0, 0.0, 0.0, 1.0), # ALPHA
	Vector4(1.0, 0.0, 0.0, 0.0), # GRAYSCALE (reads red, matching how the source texture is authored)
]

var _base_position: Vector3
var _time := 0.0

func _ready() -> void:
	_base_position = position
	_apply_flag_wind()

func _process(delta: float) -> void:
	_time += delta
	var t := _time * sway_speed * TAU
	position.y = _base_position.y + sin(t) * bob_height
	rotation.z = deg_to_rad(sin(t * ROLL_FREQUENCY_MULT) * roll_amount)
	rotation.x = deg_to_rad(cos(t * PITCH_FREQUENCY_MULT) * pitch_amount)

func _apply_flag_wind() -> void:
	for mesh_instance in _find_flag_mesh_instances(self):
		var mesh := mesh_instance.mesh
		if mesh == null:
			continue
		for surface_idx in mesh.get_surface_count():
			var source := mesh_instance.get_active_material(surface_idx)
			if source is BaseMaterial3D:
				mesh_instance.set_surface_override_material(surface_idx, _build_flag_wind_material(mesh_instance, source))

func _find_flag_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D and node.name.to_lower().contains(flag_node_name_contains.to_lower()):
		found.append(node)
	for child in node.get_children():
		found.append_array(_find_flag_mesh_instances(child))
	return found

func _build_flag_wind_material(mesh_instance: MeshInstance3D, source: BaseMaterial3D) -> ShaderMaterial:
	var aabb := mesh_instance.get_aabb()
	# Flap along the mesh's narrowest local axis (the flag's face-normal
	# direction); the wave travels along its longest axis (pole to tip).
	var extents := [aabb.size.x, aabb.size.y, aabb.size.z]
	var length_idx := extents.find(extents.max())
	var flap_idx := extents.find(extents.min())
	var length_axis := Vector3.ZERO
	length_axis[length_idx] = 1.0
	var flap_axis := Vector3.ZERO
	flap_axis[flap_idx] = 1.0

	var proj_min: float = aabb.position[length_idx]
	var proj_max: float = aabb.position[length_idx] + aabb.size[length_idx]
	# The end closer to the local-space origin is assumed to be the pole
	# edge (masts sit near the ship's centerline); the far end is the tip.
	var anchor_coord: float = proj_min if absf(proj_min) < absf(proj_max) else proj_max
	var tip_coord: float = proj_max if anchor_coord == proj_min else proj_min
	var span := absf(tip_coord - anchor_coord)

	var material := ShaderMaterial.new()
	material.shader = FLAG_WIND_SHADER
	material.set_shader_parameter("albedo", source.albedo_color)
	material.set_shader_parameter("texture_albedo", source.albedo_texture)
	material.set_shader_parameter("roughness", source.roughness)
	material.set_shader_parameter("texture_metallic", source.metallic_texture)
	material.set_shader_parameter("metallic_texture_channel", _TEXTURE_CHANNEL_MASKS[source.metallic_texture_channel])
	material.set_shader_parameter("texture_roughness", source.roughness_texture)
	material.set_shader_parameter("specular", source.metallic_specular)
	material.set_shader_parameter("metallic", source.metallic)
	material.set_shader_parameter("texture_emission", source.emission_texture)
	material.set_shader_parameter("emission", source.emission)
	material.set_shader_parameter("emission_energy", source.emission_energy_multiplier)
	material.set_shader_parameter("texture_normal", source.normal_texture)
	material.set_shader_parameter("normal_scale", source.normal_scale)
	material.set_shader_parameter("uv1_scale", source.uv1_scale)
	material.set_shader_parameter("uv1_offset", source.uv1_offset)
	material.set_shader_parameter("uv2_scale", source.uv2_scale)
	material.set_shader_parameter("uv2_offset", source.uv2_offset)
	material.set_shader_parameter("flap_axis", flap_axis)
	material.set_shader_parameter("length_axis", length_axis)
	material.set_shader_parameter("anchor_coord", anchor_coord)
	material.set_shader_parameter("tip_coord", tip_coord)
	material.set_shader_parameter("wave_speed", flag_wave_speed)
	material.set_shader_parameter("wave_frequency", flag_wave_cycle_count / max(span, 0.001))
	material.set_shader_parameter("wave_strength", flag_wave_strength_fraction * span)
	return material
