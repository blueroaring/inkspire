shader_type canvas_item;
uniform vec4 old_pigment : source_color = vec4(0.15, 0.18, 0.18, 1.0);
uniform vec4 pigment : source_color = vec4(0.15, 0.18, 0.18, 1.0);
uniform float old_strength = 0.0;
uniform float strength = 1.0;
uniform float old_rainbow = 0.0;
uniform float rainbow = 0.0;
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform vec2 region_origin = vec2(0.0);

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float density = (1.0 - dot(source.rgb, vec3(0.299, 0.587, 0.114))) * source.a;
	vec2 local = (UV - region_origin) * vec2(3.0, 2.0);
	float grain = fract(sin(dot(UV * 1024.0, vec2(12.9898, 78.233))) * 43758.5453);
	float stroke = smoothstep(local.x * 0.70 + local.y * 0.12 + grain * 0.08,
		local.x * 0.70 + local.y * 0.12 + grain * 0.08 + 0.1, progress);
	stroke = mix(stroke, 1.0, step(0.999, progress));
	vec3 multicolor = mix(vec3(0.67, 0.20, 0.15), vec3(0.70, 0.47, 0.10), smoothstep(0.0, 0.5, local.x));
	multicolor = mix(multicolor, vec3(0.15, 0.40, 0.52), smoothstep(0.45, 1.0, local.x));
	vec3 before = mix(old_pigment.rgb, multicolor, old_rainbow);
	vec3 after = mix(pigment.rgb, multicolor, rainbow);
	COLOR = vec4(mix(before, after, stroke), density * mix(old_strength, strength, stroke));
}
