shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(0.84, 0.72, 1.0, 1.0);
varying vec4 body_tint;

void vertex() {
	body_tint = COLOR;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 source = texture(TEXTURE, UV) * body_tint;
	// Break the silhouette into irregular pieces as the erosion moves downward.
	float grain = hash(floor(UV * vec2(94.0, 112.0)));
	float threshold = UV.y * 0.62 + grain * 0.32 + 0.03;
	float remaining = threshold - progress;
	float edge = (1.0 - smoothstep(0.0, 0.075, remaining)) * step(0.0, remaining);
	source.rgb = mix(source.rgb, edge_color.rgb, edge * 0.9);
	source.a *= smoothstep(0.0, 0.025, remaining);
	COLOR = source;
}
