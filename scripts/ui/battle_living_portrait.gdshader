shader_type canvas_item;
render_mode unshaded;
uniform sampler2D closed_eyes : source_color, filter_linear;
uniform float clock_seconds = 0.0;
uniform vec2 gaze = vec2(0.0);
uniform float blink = 0.0;
uniform float recoil = 0.0;
uniform float resolve_glow = 0.0;
uniform vec4 eye_a = vec4(0.4, 0.3, 0.04, 0.03);
uniform vec4 eye_b = vec4(0.6, 0.3, 0.04, 0.03);
uniform vec2 head_center = vec2(0.5, 0.33);
uniform vec2 neck = vec2(0.5, 0.65);
uniform float phase = 0.0;
uniform bool pixel_art = false;
varying vec4 vertex_tint;
float region(vec2 p, vec2 c, vec2 r) { return 1.0 - smoothstep(0.6, 1.0, length((p-c)/r)); }
void vertex() {
	vertex_tint = COLOR;
	float t = clock_seconds + phase;
	float head = region(UV, head_center, vec2(0.40, max(0.23, neck.y - head_center.y + 0.07)));
	float face = region(UV, (eye_a.xy + eye_b.xy) * 0.5 + vec2(0, 0.06), vec2(0.23, 0.16));
	float hair = head * (1.0 - face);
	float breath = sin(t * 1.55) * (1.0 - smoothstep(0.68, 1.0, UV.y));
	float angle = (gaze.x * 0.015 + sin(t * 0.68) * 0.006 - recoil * 0.035) * head;
	vec2 anchor = neck * vec2(462, 600);
	vec2 rel = VERTEX - anchor;
	vec2 rotated = vec2(rel.x*cos(angle)-rel.y*sin(angle),rel.x*sin(angle)+rel.y*cos(angle));
	vec2 offset = rotated - rel;
	offset.y += -breath * 2.5 + gaze.y * head * 1.4 + recoil * head * 5.0;
	offset.x += hair * sin(t * 1.9 + UV.y * 7.0) * 1.8 + gaze.x * head * 1.2;
	if (pixel_art) offset = round(vec2(sin(t * 1.55) * 0.8, -breath * 1.8));
	VERTEX += offset;
}
void fragment() {
	float eye = max(region(UV, eye_a.xy, eye_a.zw * 0.8), region(UV, eye_b.xy, eye_b.zw * 0.8));
	vec4 opened = texture(TEXTURE, UV - gaze * vec2(0.0022, 0.0015) * eye * (1.0 - blink) * float(!pixel_art));
	vec4 closed = texture(closed_eyes, UV);
	vec4 portrait = mix(opened, closed, smoothstep(0.1, 0.9, blink) * float(!pixel_art));
	COLOR = portrait * vertex_tint;
}
