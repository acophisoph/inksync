shader_type canvas_item;

uniform float saturation  : hint_range(0.0, 1.0) = 0.0;
uniform float alpha_scale : hint_range(0.0, 1.0) = 0.18;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float lum = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	col.rgb = mix(vec3(lum), col.rgb, saturation);
	col.a  *= alpha_scale;
	COLOR   = col;
}
