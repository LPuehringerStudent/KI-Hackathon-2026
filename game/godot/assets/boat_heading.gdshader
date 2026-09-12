shader_type canvas_item;

uniform float heading = 0.0;

void fragment() {
	vec2 local_uv = clamp(UV * 8.0, TEXTURE_PIXEL_SIZE * 4.0, vec2(1.0) - TEXTURE_PIXEL_SIZE * 4.0);
	float first = mod(floor(heading), 64.0);
	float second = mod(first + 1.0, 64.0);
	vec2 first_cell = vec2(mod(first, 8.0), floor(first / 8.0));
	vec2 second_cell = vec2(mod(second, 8.0), floor(second / 8.0));
	vec4 a = texture(TEXTURE, (first_cell + local_uv) / 8.0);
	vec4 b = texture(TEXTURE, (second_cell + local_uv) / 8.0);
	vec4 blended = mix(vec4(a.rgb * a.a, a.a), vec4(b.rgb * b.a, b.a), fract(heading));
	COLOR = vec4(blended.rgb / max(blended.a, 0.00001), blended.a);
}
