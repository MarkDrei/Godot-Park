// Shared helpers for the park shaders.
global uniform float snow_amount;
global uniform float wetness;
global uniform float night_amount;

float hash13(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

vec3 apply_snow(vec3 c, float up, float factor) {
	float s = smoothstep(0.45, 0.85, up) * snow_amount * factor;
	return mix(c, vec3(0.86, 0.9, 0.97), s);
}

vec3 apply_wet(vec3 c) {
	return c * (1.0 - wetness * 0.3);
}

// Hash without sin(), stable for large coordinates (path lengths, world metres).
float hash_cell(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// 1 while features of `size` metres are clearly visible, fading to 0 when a pixel covers them.
float detail(vec2 p, float size) {
	return 1.0 - smoothstep(size * 0.25, size, length(fwidth(p)));
}

// Running-bond stones of `size`: returns the joint mask (1 on the joint), the stone id and
// the distance to the stone's edge.
float stones(vec2 p, vec2 size, float joint, out vec2 id, out float edge) {
	float row = floor(p.y / size.y);
	p.x += mod(row, 2.0) * size.x * 0.5;
	id = vec2(floor(p.x / size.x), row);
	vec2 f = p - id * size;
	vec2 d = min(f, size - f);
	edge = min(d.x, d.y);
	float aa = max(fwidth(edge), 1e-4);
	return 1.0 - smoothstep(joint - aa, joint + aa, edge);
}

// Scattered round pebbles: mask and a random shade per pebble.
float pebbles(vec2 p, float scale, float density, out float shade) {
	vec2 q = p * scale;
	vec2 cell = floor(q);
	float h = hash_cell(cell);
	vec2 o = vec2(hash_cell(cell + 17.3), hash_cell(cell + 41.7)) - 0.5;
	float d = length(fract(q) - 0.5 - o * 0.35);
	float r = 0.22 + 0.14 * hash_cell(cell + 5.9);
	shade = hash_cell(cell + 7.1);
	float aa = max(fwidth(d), 1e-4);
	return h < density ? 1.0 - smoothstep(r - aa, r + aa, d) : 0.0;
}

