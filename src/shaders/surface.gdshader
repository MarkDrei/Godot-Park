// Paths, curbs, plazas, sidewalks, streets, bridges and bark: vertex colour with a procedural surface pattern, no textures.
// Paths and curbs carry UV (u along the path, v across from the middle, in metres);
// plazas carry the offset from their centre; bridges and trunks use their local coordinates
// (x along the bridge). Detail fades out with distance.
shader_type spatial;
render_mode diffuse_lambert;
#include "res://src/shaders/common.gdshaderinc"

uniform int pattern = 0;   // index in Materials.PATTERNS

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

// Per-stone tone, grain, worn edges and dark joints for any stone layout.
vec3 shade_stones(vec3 c, vec2 p, vec2 id, float edge, float joint, float joint_dark, float tone, float size) {
	float aa = max(fwidth(edge), 1e-4);
	float j = 1.0 - smoothstep(joint - aa, joint + aa, edge);
	float near = detail(p, 0.07);
	float mid = detail(p, size);
	c *= 1.0 + (hash_cell(id) - 0.5) * tone * mid;
	c *= 1.0 + (value_noise(p * 7.0) - 0.5) * 0.12 * near;
	c *= 1.0 - (1.0 - smoothstep(0.0, 0.06, edge)) * 0.12 * near;   // worn, rounded stone edges
	return mix(c, c * joint_dark, j * near);
}

vec3 paved(vec3 c, vec2 p, vec2 size, float joint, float joint_dark, float tone) {
	vec2 id;
	float edge;
	stones(p, size, joint, id, edge);
	return shade_stones(c, p, id, edge, joint, joint_dark, tone, size.x);
}

// Stones laid in rings around a plaza's centre (p = offset from the centre, metres);
// every sixth ring is darker.
vec3 rings(vec3 c, vec2 p) {
	float w = 0.42;
	float r = length(p);
	float row = floor(r / w);
	float rc = (row + 0.5) * w;
	float n = max(3.0, floor(TAU * rc / 0.5));
	float a = (atan(p.y, p.x) / TAU + 0.5) * n + mod(row, 2.0) * 0.5;
	float fa = fract(a);
	float fr = r - row * w;
	float edge = min(min(fa, 1.0 - fa) * TAU * rc / n, min(fr, w - fr));
	if (mod(row, 6.0) == 5.0) {
		c *= 0.86;
	}
	return shade_stones(c, p, vec2(floor(a), row), edge, 0.018, 0.66, 0.16, 0.5);
}

vec3 bark(vec3 c, vec3 l) {
	float near = detail(vec2(l.x + l.z, l.y), 0.15);
	float f = value_noise(vec2(l.x * 11.0, l.y * 1.4)) * 0.5 + value_noise(vec2(l.z * 11.0, l.y * 1.4 + 7.0)) * 0.5;
	c *= 1.0 + (f - 0.5) * 0.8 * near;
	return c * (1.0 - 0.18 * near * smoothstep(0.62, 0.8, value_noise(vec2((l.x + l.z) * 4.0, l.y * 5.0))));
}

vec3 asphalt(vec3 c, vec2 w) {
	float mid = detail(w, 0.6);
	c *= 1.0 + (value_noise(w * 0.9) * 0.6 + value_noise(w * 3.1) * 0.4 - 0.5) * 0.16 * mid;
	float s;
	float fleck = pebbles(w, 26.0, 0.5, s);
	return mix(c, c * (0.75 + 0.6 * s), fleck * detail(w, 0.06));
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
	} else if (pattern == 6) {
		c = masonry(c, v_local, v_local_n);
	} else if (pattern == 7) {
		c = rings(c, UV);
	} else if (pattern == 8) {
		c = bark(c, v_local);
	} else {
		c = asphalt(c, v_world.xz);
	}
	c = apply_snow(c, v_up, 1.0);
	ALBEDO = apply_wet(c);
	ROUGHNESS = mix(0.9, 0.45, wetness);
	SPECULAR = 0.3;
}
