shader_type canvas_item;

// White = fill visible, black = clipped to the track's inner pill shape.
uniform sampler2D mask_texture : filter_linear;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	float mask_value = texture(mask_texture, UV).r;
	COLOR = tex_color;
	COLOR.a *= mask_value;
}
