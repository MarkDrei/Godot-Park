// The Möwenbucht's sea: swells rolling in from the south, ripples, deeper blue further out,
// a sky reflection; whiter crests in a storm.
shader_type spatial;
render_mode blend_mix, diffuse_lambert, specular_schlick_ggx, cull_back;
#include "res://src/shaders/common.gdshaderinc"

global uniform float ice_amount;

uniform vec4 shallow_color : source_color = vec4(0.2, 0.45, 0.5, 1.0);
uniform vec4 deep_color : source_color = vec4(0.07, 0.22, 0.36, 1.0);
uniform float shore_z = 176.0;
uniform float swell = 0.12;

varying vec3 v_world;

float swells(vec2 p, float t) {
	return sin(p.y * 0.42 + t * 1.25 + sin(p.x * 0.05) * 1.5) * 0.6
		+ sin(p.y * 0.23 - p.x * 0.11 + t * 0.8) * 0.4;
}

float ripples(vec2 p, float t) {
	return sin(p.x * 0.9 + t * 1.3) * 0.5 + sin(p.y * 1.1 - t * 1.1) * 0.5
		+ sin((p.x + p.y) * 2.3 + t * 2.1) * 0.25 + value_noise(p * 1.7 + vec2(t * 0.6)) * 0.6;
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float out_k = smoothstep(shore_z - 6.0, shore_z + 25.0, v_world.z);
	VERTEX.y += swells(v_world.xz, TIME) * swell * out_k + (ripples(v_world.xz, TIME) - 0.5) * 0.02;
}

void fragment() {
	vec2 p = v_world.xz;
	float t = TIME;
	float e = 0.2;
	float hx = ripples(p + vec2(e, 0.0), t) - ripples(p - vec2(e, 0.0), t);
	float hz = ripples(p + vec2(0.0, e), t) - ripples(p - vec2(0.0, e), t);
	float sx = swells(p + vec2(e, 0.0), t) - swells(p - vec2(e, 0.0), t);
	float sz = swells(p + vec2(0.0, e), t) - swells(p - vec2(0.0, e), t);
	vec3 n = normalize(vec3(-hx * 0.3 - sx * 0.6, 1.0, -hz * 0.3 - sz * 0.6));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float depth = smoothstep(shore_z, shore_z + 90.0, v_world.z);
	vec3 c = mix(shallow_color.rgb, deep_color.rgb, depth);
	float crest = smoothstep(0.75, 1.0, swells(p, t)) * smoothstep(shore_z + 5.0, shore_z + 30.0, v_world.z);
	c += vec3(0.08) * crest + value_noise(p * 3.0 + vec2(t)) * 0.025;
	vec3 view_dir = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 r = reflect(-view_dir, n);
	float fres = pow(1.0 - clamp(dot(n, view_dir), 0.0, 1.0), 4.0);
	c = mix(c, sky_env(r) * 0.85, fres * 0.4);
	ALBEDO = mix(c, vec3(0.78, 0.88, 0.93), ice_amount * 0.3);
	ALPHA = mix(0.84, 0.98, depth);
	ROUGHNESS = 0.16;
	METALLIC = 0.0;
	SPECULAR = 0.45;
}
