// Paths, curbs and bridges: vertex colour with a procedural surface pattern, no textures.
// Paths and curbs carry UV (u along the path, v across from the middle, in metres);
// bridges use their local coordinates (x along the bridge). Detail fades out with distance.
shader_type spatial;
render_mode diffuse_lambert;
#include "res://src/shaders/common.gdshaderinc"

uniform int pattern = 0;   // 0 pavers, 1 gravel, 2 earth, 3 curb, 4 planks, 5 cobbles, 6 masonry

varying vec3 v_local;
varying vec3 v_local_n;
varying vec3 v_world;
varying float v_up;

void vertex() {
	v_local = VERTEX;
	v_local_n = NORMAL;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
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

vec3 paved(vec3 c, vec2 p, vec2 size, float joint, float joint_dark, float tone) {
	vec2 id;
	float edge;
	float j = stones(p, size, joint, id, edge);
	float near = detail(p, 0.07);
	float mid = detail(p, size.x);
	c *= 1.0 + (hash_cell(id) - 0.5) * tone * mid;
	c *= 1.0 + (value_noise(p * 7.0) - 0.5) * 0.12 * near;
	c *= 1.0 - (1.0 - smoothstep(0.0, 0.06, edge)) * 0.12 * near;   // worn, rounded stone edges
	return mix(c, c * joint_dark, j * near);
}

vec3 gravel(vec3 c, vec2 w) {
	float near = detail(w, 0.14);
	float mid = detail(w, 0.4);
	c *= 1.0 + (value_noise(w * 2.3) - 0.5) * 0.18 * mid;
	float s;
	float p1 = pebbles(w, 11.0, 0.6, s);
	c = mix(c, c * (0.62 + 0.6 * s), p1 * near);
	float p2 = pebbles(w + 3.7, 19.0, 0.45, s);
	return mix(c, c * (0.78 + 0.45 * s), p2 * near);
}

vec3 earth(vec3 c, vec2 w, float across) {
	float near = detail(w, 0.12);
	float mid = detail(w, 0.5);
	float n = value_noise(w * 0.6) * 0.55 + value_noise(w * 2.1) * 0.45;
	c *= 1.0 + (n - 0.5) * 0.32 * mid;
	c *= 1.0 + 0.07 * (1.0 - smoothstep(0.15, 0.55, abs(across)));   // trodden middle
	float s;
	float stone = pebbles(w, 6.0, 0.14, s);
	c = mix(c, vec3(0.3, 0.29, 0.27) * (0.8 + 0.4 * s), stone * near * 0.7);
	float crumb = pebbles(w + 9.1, 14.0, 0.35, s);
	return mix(c, c * (0.7 + 0.4 * s), crumb * near);
}

vec3 planks(vec3 c, vec3 l) {
	vec2 g = vec2(l.x * 20.0, l.z * 0.7 + l.y * 0.7);
	float near = detail(l.xz, 0.2);
	float grain = value_noise(g) * 0.6 + value_noise(g * vec2(2.7, 1.3)) * 0.4;
	c *= 1.0 + (grain - 0.5) * 0.6 * near;
	c *= 1.0 + (value_noise(vec2(l.x * 9.0, l.z * 0.3)) - 0.5) * 0.25 * near;   // darker and lighter boards
	float s;
	float knot = pebbles(vec2(l.x * 3.0, l.z * 0.8), 2.0, 0.08, s);
	return mix(c, c * 0.62, knot * near);
}

vec3 masonry(vec3 c, vec3 l, vec3 n) {
	vec3 a = abs(n);
	vec2 p = a.y > 0.7 ? l.xz : (a.x > a.z ? vec2(l.z, l.y) : vec2(l.x, l.y));
	return paved(c, p, vec2(0.7, 0.32), 0.025, 0.65, 0.3);
}

void fragment() {
	vec3 c = COLOR.rgb;
	if (pattern == 0) {
		c = paved(c, UV, vec2(0.42, 0.28), 0.016, 0.68, 0.18);
	} else if (pattern == 1) {
		c = gravel(c, v_world.xz);
	} else if (pattern == 2) {
		c = earth(c, v_world.xz, UV.y);
	} else if (pattern == 3) {
		c = paved(c, vec2(UV.x, 0.5), vec2(0.9, 1000.0), 0.012, 0.6, 0.12);   // joints along the curb
	} else if (pattern == 4) {
		c = planks(c, v_local);
	} else if (pattern == 5) {
		c = paved(c, vec2(v_local.z, v_local.x), vec2(0.26, 0.2), 0.022, 0.6, 0.26);
	} else {
		c = masonry(c, v_local, v_local_n);
	}
	c = apply_snow(c, v_up, 1.0);
	ALBEDO = apply_wet(c);
	ROUGHNESS = mix(0.9, 0.45, wetness);
	SPECULAR = 0.3;
}
