shader_type canvas_item;
render_mode unshaded;

uniform vec2 surface_size = vec2(400.0, 200.0);
uniform vec4 accent : source_color = vec4(0.5, 0.65, 0.7, 1.0);
uniform int family = 0;
uniform float strength = 1.0;

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
	float cloud = noise2(UV * vec2(4.2, 5.1)) * 0.7 + noise2(UV * 13.0) * 0.3;
	float grain = hash21(floor(p / 1.4)) - 0.5;
	float edge = 1.0 - smoothstep(0.0, 0.28, min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y)));
	// The broad face stays quiet; material relief gathers around its perimeter.
	float relief = (cloud - 0.5) * 0.27 + grain * 0.045;
	float sheen = exp(-pow((UV.x + UV.y * 0.34 - 0.28) * 5.0, 2.0));
	vec3 light = vec3(0.93, 0.91, 0.80);
	vec3 dark = mix(vec3(0.12, 0.20, 0.26), accent.rgb, 0.32);
	float weave = sin(p.x * 2.1) * sin(p.y * 1.7);
	if (family == 1) {
		// Long paper fibres and irregular amber sizing, without repeating stamps.
		float fibre = noise2(vec2(p.x * 0.026, p.y * 0.55));
		relief += (fibre - 0.5) * 0.12 + sin(UV.y * 15.0 + cloud * 7.0) * 0.047;
		light = vec3(1.0, 0.89, 0.66);
		dark = vec3(0.44, 0.24, 0.10);
	} else if (family == 2) {
		// Frosted enamel: a cool brushed face with a restrained diagonal reflection.
		float brush = noise2(vec2(p.x * 0.018, p.y * 0.8)) - 0.5;
		relief += brush * 0.085 + (sheen - 0.46) * 0.22;
		float score = 1.0 - smoothstep(0.0, 1.1, abs(mod(p.x + p.y * 0.36, 46.0) - 23.0));
		relief -= score * edge * 0.065;
		light = vec3(0.74, 0.96, 1.0);
		dark = vec3(0.06, 0.30, 0.47);
	} else if (family == 3) {
		// Nacre follows slow, curved layers; no animated glare under the text.
		float flow = UV.x * 13.0 + UV.y * 8.0 + cloud * 8.0;
		relief += sin(flow) * 0.13 + sin(flow * 2.3) * 0.027;
		light = mix(vec3(0.74, 1.0, 0.88), vec3(1.0, 0.85, 0.79), cloud);
		dark = vec3(0.12, 0.39, 0.33);
	} else if (family == 4) {
		// Silk jacquard: crossed threads and a woven lozenge at the edges.
		vec2 cell = abs(fract((p / 76.0) + vec2(0.0, 0.5)) - 0.5);
		float brocade = 1.0 - smoothstep(0.016, 0.045, abs(cell.x + cell.y - 0.5));
		relief += weave * 0.037 + (sheen - 0.5) * 0.16 - brocade * edge * 0.09;
		light = vec3(0.96, 0.83, 1.0);
		dark = vec3(0.30, 0.16, 0.45);
	} else if (family == 5) {
		// Brushed blue steel with inset protective ribs around a quiet face.
		relief += (noise2(vec2(p.x * 0.7, p.y * 0.025)) - 0.5) * 0.10;
		relief += sin((UV.x + abs(UV.y - 0.5) * 0.4) * 44.0) * edge * 0.05;
		light = vec3(0.73, 0.84, 0.96);
		dark = vec3(0.15, 0.24, 0.44);
	} else if (family == 6) {
		// Sportswear mesh and embossed running-lane grooves.
		relief += weave * 0.048;
		float lane = 1.0 - smoothstep(0.7, 1.7, abs(mod(p.x + p.y * 0.55, 28.0) - 14.0));
		relief -= lane * edge * 0.10;
		light = vec3(1.0, 0.82, 0.61);
		dark = vec3(0.45, 0.22, 0.10);
	} else if (family == 7) {
		// Jade enamel with staggered scale etching, concentrated at the border.
		vec2 scales = p / vec2(22.0, 16.0);
		scales.x += mod(floor(scales.y), 2.0) * 0.5;
		vec2 tile = fract(scales) - vec2(0.5, 0.0);
		float etch = 1.0 - smoothstep(0.025, 0.085, abs(length(tile) - 0.52));
		relief += (sheen - 0.4) * 0.13 - etch * edge * 0.13;
		light = vec3(0.62, 0.91, 0.72);
		dark = mix(vec3(0.10, 0.30, 0.22), vec3(0.32, 0.18, 0.39), UV.y);
	} else {
		// Pressed cotton stock for common controls and the archive backing.
		relief += weave * 0.025 + (noise2(vec2(p.x * 0.06, p.y * 0.43)) - 0.5) * 0.06;
	}
	relief *= mix(0.38, 1.0, edge);
	relief += (sheen - 0.35) * 0.07 * edge;
	// A paired light/dark lip gives the surface a pressed, physical edge.
	float distance_px = min(min(p.x, surface_size.x - p.x), min(p.y, surface_size.y - p.y));
	relief += exp(-pow((distance_px - 3.0) * 0.8, 2.0)) * 0.18;
	relief -= exp(-pow((distance_px - 5.0) * 0.8, 2.0)) * 0.13;
	COLOR = vec4(relief > 0.0 ? light : dark, min(abs(relief) * strength, 0.28)) * modulation;
}
