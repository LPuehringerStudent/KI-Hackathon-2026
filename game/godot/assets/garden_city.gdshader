shader_type canvas_item;

vec3 recolor(vec3 source, vec3 original, vec3 replacement) {
	float weight = 1.0 - smoothstep(0.001, 0.008, distance(source, original));
	return (replacement - original) * weight;
}

void fragment() {
	vec4 sample_color = texture(TEXTURE, UV);
	vec3 c = sample_color.rgb;
	vec3 result = c;
	if (c.g > c.r * 1.15 && c.g > c.b * 1.1) {
		result *= vec3(0.9, 1.07, 0.85);
	}
	result += recolor(c, vec3(233,227,213)/255.0, vec3(227,237,212)/255.0);
	result += recolor(c, vec3(168,202,222)/255.0, vec3(72,172,205)/255.0);
	result += recolor(c, vec3(146,184,208)/255.0, vec3(51,143,178)/255.0);
	result += recolor(c, vec3(169,199,149)/255.0, vec3(107,167,70)/255.0);
	result += recolor(c, vec3(188,214,168)/255.0, vec3(137,191,84)/255.0);
	result += recolor(c, vec3(194,216,174)/255.0, vec3(157,201,107)/255.0);
	result += recolor(c, vec3(201,220,181)/255.0, vec3(177,211,127)/255.0);
	result += recolor(c, vec3(194,185,166)/255.0, vec3(214,178,130)/255.0);
	result += recolor(c, vec3(205,197,180)/255.0, vec3(225,201,162)/255.0);
	result += recolor(c, vec3(208,195,176)/255.0, vec3(225,231,222)/255.0);
	result += recolor(c, vec3(184,170,150)/255.0, vec3(163,189,190)/255.0);
	result += recolor(c, vec3(244,239,230)/255.0, vec3(250,247,238)/255.0);
	result += recolor(c, vec3(237,230,217)/255.0, vec3(212,147,120)/255.0);
	result += recolor(c, vec3(229,222,208)/255.0, vec3(131,164,177)/255.0);
	COLOR = vec4(clamp(result, vec3(0.0), vec3(1.0)), sample_color.a);
}
