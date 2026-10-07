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

varying vec3 v_world;
varying float v_up;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = max(VERTEX.y, 0.0);
	float s = sin(TIME * 1.6 + wp.x * 0.31 + wp.z * 0.23) + 0.4 * sin(TIME * 3.7 + wp.x * 1.3);
	vec3 offset = vec3(s, 0.0, s * 0.6) * wind_strength * 0.035 * h * sway;
	VERTEX += (inverse(mat3(MODEL_MATRIX)) * offset);
	v_world = wp;
	v_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}

void fragment() {
	float h = hash13(floor(v_world * 1.7));
	if (deciduous && h >= foliage_amount) {
		discard;
	}
	vec3 c = COLOR.rgb;
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
