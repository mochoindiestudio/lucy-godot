// NOTE: Shader automatically converted from Godot Engine 4.7.1.stable's StandardMaterial3D.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform ivec2 albedo_texture_size;
uniform float point_size : hint_range(0.1, 128.0, 0.1);

uniform float roughness : hint_range(0.0, 1.0);
uniform sampler2D texture_metallic : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_g, filter_linear_mipmap, repeat_enable;

uniform float specular : hint_range(0.0, 1.0, 0.01);
uniform float metallic : hint_range(0.0, 1.0, 0.01);

uniform sampler2D texture_emission : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec4 emission : source_color;
uniform float emission_energy : hint_range(0.0, 100.0, 0.01);

uniform sampler2D texture_normal : hint_roughness_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_scale : hint_range(-16.0, 16.0);

uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;

// -- Flag wind addition (see prefabs/buildings/ship.gd) --------------------
// Displacement runs along flap_axis (the flag's narrowest local dimension,
// i.e. its face-normal direction) only, so it can't twist the mesh the way
// per-vertex NORMAL-based displacement did. It travels along length_axis
// (pole to tip) and fades to zero at anchor_coord (the pole edge) so the
// flag stays attached to its pole, reaching full strength at tip_coord.
group_uniforms flag_wind;
uniform vec3 flap_axis = vec3(0.0, 0.0, 1.0);
uniform vec3 length_axis = vec3(1.0, 0.0, 0.0);
uniform float anchor_coord = 0.0;
uniform float tip_coord = 1.0;
uniform float wave_speed = 3.0;
uniform float wave_frequency = 3.0;
uniform float wave_strength = 0.1;
group_uniforms;

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;

	float coord = dot(VERTEX, length_axis);
	float mask = clamp((coord - anchor_coord) / (tip_coord - anchor_coord), 0.0, 1.0);
	float wave = sin(coord * wave_frequency - TIME * wave_speed) * mask * wave_strength;
	VERTEX += flap_axis * wave;
}

void fragment() {
	vec2 base_uv = UV;

	vec4 albedo_tex = texture(texture_albedo, base_uv);
	ALBEDO = albedo.rgb * albedo_tex.rgb;

	float metallic_tex = dot(texture(texture_metallic, base_uv), metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	SPECULAR = specular;

	vec4 roughness_texture_channel = vec4(0.0, 1.0, 0.0, 0.0);
	float roughness_tex = dot(texture(texture_roughness, base_uv), roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;

	// Normal Map: Enabled
	NORMAL_MAP = texture(texture_normal, base_uv).rgb;
	NORMAL_MAP_DEPTH = normal_scale;

	// Emission: Enabled
	vec3 emission_tex = texture(texture_emission, base_uv).rgb;
	// Emission Operator: Multiply
	EMISSION = (emission.rgb * emission_tex) * emission_energy;
}
