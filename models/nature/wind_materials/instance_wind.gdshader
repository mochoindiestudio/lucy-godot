// Wind sway for MultiMesh-instanced vegetation.
//
// For single-surface meshes (grass, flowers, single-material foliage),
// assign a ShaderMaterial using this shader directly as the
// Terrain3DMeshAsset's Material Override in the Meshes dock.
//
// For multi-surface meshes (e.g. trees with separate bark/leaf materials),
// do NOT use Material Override -- that replaces every surface with one
// material, losing the distinct bark/leaf textures. Instead, override the
// per-material import setting on the source glTF/scene file (Advanced Import
// Settings -> material -> "Use External" -> a ShaderMaterial using this
// shader) so each surface keeps its own wind material while
// Terrain3DMeshAsset captures them individually. See
// M_instance_wind_bark_normaltree.tres / M_instance_wind_leaves_normaltree.tres
// and CommonTree_1.gltf.import for a working example. Note: these per-surface
// materials aren't reachable from the Meshes dock Inspector -- edit them
// directly via the FileSystem dock.
//
// Reads the per-vertex wind weight already baked into this asset pack's
// vertex color (COLOR.r: 0 at the root, ramping to 1 toward the tip) rather
// than guessing a height-based curve -- this matches the authored geometry
// exactly, including tapered/irregular meshes. Gusts come from a scrolling
// noise texture sampled in world space (like extras/particle_example's
// particles.gdshader), not a sine approximation.
//
// Uses skip_vertex_transform and does the model->view transform manually
// (like particle_example/grass.gdshader) so the wind offset -- computed in
// world space for consistent scale/direction -- is correct regardless of
// each instance's random rotation/scale. Applying a world-space offset to
// local VERTEX.xz directly (skipping this) looks wrong on rotated instances.

shader_type spatial;

render_mode skip_vertex_transform, cull_disabled, diffuse_burley, specular_schlick_ggx;

group_uniforms surface;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform bool alpha_scissor_enabled = false;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.2;
uniform bool normal_enabled = false;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;

group_uniforms wind;
uniform sampler2D wind_noise : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec2 wind_direction = vec2(1.0, 1.0);
uniform float wind_speed = 0.25;
// World-space distance for one noise cycle. Smaller = smaller gusts.
uniform float wind_noise_scale = 0.015;
// How far vertices are displaced at full bend/gust, in world units.
uniform float wind_strength = 0.3;
// Exponent applied to the baked wind weight before use. 1.0 = use it as
// authored. Raise this (e.g. 3-6) to suppress mid-range weight and isolate
// motion to only the highest-weighted vertices -- useful for a mesh like a
// tree where the trunk's baked weight ramps up faster than its geometry
// should actually flex, so the whole trunk sways instead of just the crown.
uniform float bend_curve : hint_range(0.5, 8.0) = 1.0;

// Stable per-instance hash (from world position) so instances sampling the
// same noise cell don't flutter in perfect unison.
float hash(vec2 v) {
	return fract(sin(dot(v, vec2(12.9898, 78.233))) * 43758.5453123);
}

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = hash(MODEL_MATRIX[3].xz) * TAU;

	// Authored wind weight: 0 at the root, ramping to 1 at the tip.
	float bend = pow(clamp(COLOR.r, 0.0, 1.0), bend_curve);

	vec2 dir = normalize(wind_direction);
	vec2 uv = world_pos.xz * wind_noise_scale + TIME * wind_speed * dir;
	float gust = textureLod(wind_noise, uv, 0.0).r * wind_strength;
	// Cheap jitter + non-linear response curve (ported from particle_example).
	gust -= fract(gust * 256.0) * gust * 0.05;
	float force = pow(max(gust * bend, 0.0), 0.707);

	// Lateral wobble perpendicular to the wind, plus the main lean.
	float lateral_wobble = sin(TIME * 2.0 + phase) * 0.25 * bend;
	world_pos.xz -= (vec2(-dir.y, dir.x) * lateral_wobble + dir) * force;

	VERTEX = (VIEW_MATRIX * vec4(world_pos, 1.0)).xyz;
	NORMAL = MODELVIEW_NORMAL_MATRIX * NORMAL;
	BINORMAL = MODELVIEW_NORMAL_MATRIX * BINORMAL;
	TANGENT = MODELVIEW_NORMAL_MATRIX * TANGENT;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = albedo.rgb * tex.rgb;
	ALPHA = albedo.a * tex.a;
	if (alpha_scissor_enabled) {
		ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	}
	if (normal_enabled) {
		NORMAL_MAP = texture(normal_texture, UV).rgb;
	}
	ROUGHNESS = roughness;
}
