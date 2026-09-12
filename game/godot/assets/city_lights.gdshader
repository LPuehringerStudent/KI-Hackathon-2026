shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 lamp = texture(TEXTURE, UV);
	vec2 block = floor(UV * 128.0);
	float phase = dot(block, vec2(12.9898, 78.233));
	float shimmer = 0.84 + 0.09 * sin(TIME * 2.1 + phase) + 0.04 * sin(TIME * 4.3 + phase * 0.7);
	COLOR = vec4(lamp.rgb, lamp.a * strength * shimmer);
}
