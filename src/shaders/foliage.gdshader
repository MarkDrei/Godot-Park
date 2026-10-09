// Tree crowns, bushes, grass: wind sway, season tint, falling foliage, blossom, snow.
shader_type spatial;
render_mode diffuse_lambert, cull_disabled;
#include "res://src/shaders/common.gdshaderinc"

global uniform vec4 season_tint;
global uniform vec4 grass_tint;
global uniform float foliage_amount;
global uniform float blossom_amount;
global uniform float wind_strength;

uniform bool deciduous = true;
uniform bool blossoms = false;
uniform bool seasonal = true;
uniform bool grass_tinted = false;
uniform float sway = 1.0;
uniform int leaf_pattern = 0;   // 0 none (grass, flowers), 1 leaf clusters, 2 needles

varying vec3 v_world;
varying float v_up;
varying vec3 v_rest;            // position without wind, so the pattern does not swim
varying vec3 v_rest_n;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = max(VERTEX.y, 0.0);
	float s = sin(TIME * 1.6 + wp.x * 0.31 + wp.z * 0.23) + 0.4 * sin(TIME * 3.7 + wp.x * 1.3);
	vec3 offset = vec3(s, 0.0, s * 0.6) * wind_strength * 0.035 * h * sway;
	VERTEX += (inverse(mat3(MODEL_MATRIX)) * offset);
	v_world = wp;
	v_rest = VERTEX + MODEL_MATRIX[3].xyz;
	v_rest_n = NORMAL;
	v_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}

// Leaf clusters or needle streaks on crowns, darker towards the underside.
vec3 leaves(vec3 c) {
	vec3 a = abs(v_rest_n);
	vec2 q = a.y > max(a.x, a.z) ? v_rest.xz : (a.x > a.z ? v_rest.zy : v_rest.xy);
	c *= mix(0.78, 1.0, smoothstep(-0.7, 0.4, v_up));
	if (leaf_pattern == 1) {
		float near = detail(q, 0.3);
		float s;
		float blob = pebbles(q, 4.2, 0.95, s);
		float s_b;
		float blob_b = pebbles(q + 0.119, 4.2, 0.95, s_b);   // second layer half a cell off fills the gaps
		float lit = max(blob * (0.88 + 0.26 * s), blob_b * (0.86 + 0.24 * s_b));
		c *= 1.0 + (mix(0.84, lit, max(blob, blob_b)) - 1.0) * near;
		float s2;
		float fine = pebbles(q + 2.3, 11.0, 0.7, s2);
		return c * (1.0 + (s2 - 0.5) * 0.22 * fine * detail(q, 0.12));
	}
	float near = detail(q, 0.12);
	float n = value_noise(vec2(q.x * 16.0, q.y * 3.0)) * 0.6 + value_noise(vec2(q.x * 31.0, q.y * 5.0)) * 0.4;
	return c * (1.0 + (n - 0.5) * 0.36 * near);
}

void fragment() {
	float h = hash13(floor(v_world * 1.7));
	if (deciduous && h >= foliage_amount) {
		discard;
	}
	vec3 c = COLOR.rgb;
	if (leaf_pattern > 0) {
		c = leaves(c);
	}
	if (grass_tinted) {
		c *= grass_tint.rgb;
	} else if (seasonal) {
		c *= season_tint.rgb;
	}
	if (blossoms) {
		float b = step(h, blossom_amount);
		c = mix(c, mix(vec3(1.0, 0.45, 0.62), vec3(1.0, 0.86, 0.9), hash13(floor(v_world * 3.1))), b);
	}
	c = apply_snow(c, v_up, 0.9);
	ALBEDO = apply_wet(c);
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}
