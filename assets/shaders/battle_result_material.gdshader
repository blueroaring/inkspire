shader_type canvas_item;
render_mode unshaded;

uniform vec2 surface_size = vec2(1360.0, 720.0);
uniform vec4 base_tint : source_color = vec4(0.92, 0.89, 0.81, 1.0);
uniform vec4 metal_tint : source_color = vec4(0.74, 0.57, 0.30, 1.0);
uniform int finish = 0;
uniform float radius = 14.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec4 modulation = COLOR;
	vec2 p = UV * surface_size;
	vec2 q = abs(p - surface_size * 0.5) - surface_size * 0.5 + radius;
	float sdf = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	float mask = 1.0 - smoothstep(-0.9, 0.5, sdf);
	float edge = 1.0 - smoothstep(0.0, 40.0, -sdf);
	float grain = hash21(floor(p / 1.55)) - 0.5;
	float cloud = noise2(p * 0.012) * 0.65 + noise2(p * 0.036) * 0.35;
	float fibres = noise2(vec2(p.x * 0.045, p.y * 0.65)) - 0.5;
	vec3 color = base_tint.rgb;
	if (finish == 0) {
		// Cotton paper: visible fibres, irregular sizing and tea-toned edge wear.
		float pulp = noise2(p * 0.21) - 0.5;
		color += vec3((cloud - 0.52) * 0.09 + pulp * 0.04 + grain * 0.045 + fibres * 0.04);
		float flecks = smoothstep(0.87, 0.98, hash21(floor(p / 2.4)));
		color -= vec3(0.11, 0.085, 0.045) * flecks * 0.35;
		color = mix(color, metal_tint.rgb * 0.78, edge * (0.13 + 0.10 * cloud));
		color += vec3(0.035) * exp(-pow((UV.x - 0.57) * 4.0, 2.0));
	} else if (finish == 1) {
		// Dark book cloth: interlaced threads and an embossed diamond weave.
		float warp = sin(p.x * 2.6) * sin(p.y * 2.8);
		vec2 cell = abs(fract(p / 56.0) - 0.5);
		float diamond = 1.0 - smoothstep(0.015, 0.065, abs(cell.x + cell.y - 0.5));
		float recessed = 1.0 - smoothstep(0.02, 0.08, abs(cell.x + cell.y - 0.43));
		color += (cloud - 0.5) * 0.065 + grain * 0.045 + warp * 0.022;
		color += metal_tint.rgb * diamond * 0.075 - recessed * 0.025;
		color *= 1.0 - edge * 0.23;
		color += vec3(0.025, 0.034, 0.033) * (1.0 - UV.y);
	} else if (finish == 2) {
		// Inset reward slip: satin coating over laid paper, with a pressed lip.
		color += (cloud - 0.5) * 0.10 + fibres * 0.07 + grain * 0.035;
		color += vec3(0.055) * exp(-pow((UV.y - 0.14) * 4.0, 2.0));
		color -= edge * 0.055;
	} else {
		// Brushed enamel: a broad reflection travels very slowly across the face.
		float brush = noise2(vec2(p.x * 0.028, p.y * 0.9)) - 0.5;
		float sheen = exp(-pow((UV.x + UV.y * 0.4 - 0.65 - sin(TIME * 0.42) * 0.22) * 3.5, 2.0));
		color += brush * 0.07 + grain * 0.025;
		color += metal_tint.rgb * sheen * 0.12;
		color -= edge * 0.07;
	}
	// Raised top edge and inset bottom shadow provide thickness without affecting text.
	color += vec3(0.10) * exp(-pow((-sdf - 1.7) * 0.85, 2.0)) * (1.0 - UV.y);
	color -= vec3(0.07) * exp(-pow((-sdf - 3.2) * 0.8, 2.0)) * UV.y;
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), mask) * modulation;
}
