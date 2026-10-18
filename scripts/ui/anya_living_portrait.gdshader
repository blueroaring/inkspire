shader_type canvas_item;
render_mode unshaded;

uniform sampler2D closed_eyes : source_color, filter_linear;
uniform float clock_seconds = 0.0;
uniform vec2 gaze = vec2(0.0);
uniform float blink : hint_range(0.0, 1.0) = 0.0;
uniform float recoil : hint_range(0.0, 1.0) = 0.0;
uniform float resolve_glow : hint_range(0.0, 1.0) = 0.0;
varying vec4 vertex_tint;

float ellipse(vec2 p, vec2 center, vec2 radius) {
	return 1.0 - smoothstep(0.68, 1.0, length((p - center) / radius));
}

void vertex() {
	vertex_tint = COLOR;
	vec2 p = UV;
	float t = clock_seconds;
	float breath = sin(t * 1.58);
	float head = ellipse(p, vec2(0.52, 0.255), vec2(0.26, 0.24));
	float face = ellipse(p, vec2(0.51, 0.29), vec2(0.145, 0.13));
	float body = ellipse(p, vec2(0.53, 0.66), vec2(0.36, 0.46));
	float wing = smoothstep(0.17, 0.38, abs(p.x - 0.52)) * (1.0 - smoothstep(0.58, 0.91, p.y));
	wing *= 1.0 - head * 0.95;
	float hair = ellipse(p, vec2(0.51, 0.27), vec2(0.35, 0.26)) * (1.0 - face) * (1.0 - wing * 0.75);
	float angle = (gaze.x * 0.022 + sin(t * 0.73) * 0.009 - recoil * 0.045) * head;
	vec2 relative = VERTEX - vec2(241.0, 242.0);
	vec2 rotated = vec2(relative.x * cos(angle) - relative.y * sin(angle), relative.x * sin(angle) + relative.y * cos(angle));
	vec2 offset = rotated - relative;
	offset.y -= breath * (body * 1.6 + head * 2.5);
	offset.x += gaze.x * head * 2.2;
	offset.y += gaze.y * head * 1.8;
	float side = sign(p.x - 0.52);
	offset.x += side * wing * (sin(t * 1.13 + p.y * 2.1) * 7.0 + breath * 1.8 + resolve_glow * 5.0);
	offset.y += wing * sin(t * 1.13 + p.x * 1.5) * 4.5;
	offset.x += hair * (sin(t * 1.79 + p.y * 6.0) * 2.5 + gaze.x * 1.8);
	offset.y += hair * sin(t * 1.36 + p.x * 4.0) * 1.2;
	float ribbon = ellipse(p, vec2(0.18, 0.77), vec2(0.22, 0.18)) + ellipse(p, vec2(0.89, 0.78), vec2(0.13, 0.19));
	offset.x += ribbon * sin(t * 2.05 + p.y * 7.0) * 4.0;
	offset.y += recoil * (head * 7.0 + body * 3.0);
	VERTEX += offset;
}

void fragment() {
	float eye = max(ellipse(UV, vec2(0.418, 0.262), vec2(0.026, 0.018)), ellipse(UV, vec2(0.533, 0.283), vec2(0.028, 0.020)));
	vec4 opened = texture(TEXTURE, UV - gaze * vec2(0.0022, 0.0012) * eye * (1.0 - blink));
	vec4 closed = texture(closed_eyes, UV);
	vec4 portrait = mix(opened, closed, smoothstep(0.12, 0.9, blink));
	float feather = smoothstep(0.25, 0.70, max(portrait.r, portrait.g)) * (1.0 - smoothstep(0.22, 0.47, abs(UV.x - 0.52)));
	portrait.rgb += vec3(0.055, 0.033, 0.008) * resolve_glow * feather;
	COLOR = portrait * vertex_tint;
}
