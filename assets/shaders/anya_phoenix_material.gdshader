shader_type canvas_item;
render_mode unshaded;
uniform float intensity : hint_range(0.0, 1.0) = 0.6;
uniform bool health_fill = false;

void fragment() {
	vec4 art = texture(TEXTURE, UV) * COLOR;
	float sweep = pow(max(0.0, sin(UV.x * 9.0 - TIME * 0.65 + UV.y * 1.8)), 18.0);
	float gold = smoothstep(0.2, 0.75, art.r) * smoothstep(0.04, 0.3, art.r - art.b);
	float breath = 0.65 + 0.35 * sin(TIME * 1.4);
	art.rgb += vec3(0.24, 0.13, 0.035) * gold * (sweep + breath * 0.18) * intensity;
	if (health_fill) {
		vec3 ember = mix(vec3(0.38, 0.07, 0.09), vec3(0.93, 0.48, 0.19), UV.x);
		ember = mix(ember, vec3(1.0, 0.83, 0.46), pow(1.0 - UV.y, 5.0) * 0.65);
		float current = sin(UV.x * 35.0 + UV.y * 7.0 - TIME * 1.6) * 0.025;
		art.rgb = ember + current + sweep * vec3(0.1, 0.055, 0.015);
	}
	COLOR = art;
}
