// Creek and pond: gentle waves, ripple normals, freezes in winter.
shader_type spatial;
render_mode blend_mix, diffuse_lambert, specular_schlick_ggx, cull_back;
#include "res://src/shaders/common.gdshaderinc"

global uniform float ice_amount;

uniform vec4 water_color : source_color = vec4(0.18, 0.42, 0.5, 1.0);
uniform vec4 ice_color : source_color = vec4(0.78, 0.88, 0.93, 1.0);
uniform vec2 flow = vec2(0.0, 0.0);

varying vec3 v_world;

float waves(vec2 p, float t) {
	return sin(p.x * 0.9 + t * 1.3) * 0.5 + sin(p.y * 1.1 - t * 1.1) * 0.5
		+ sin((p.x + p.y) * 2.3 + t * 2.1) * 0.25 + value_noise(p * 1.7 + vec2(t * 0.6)) * 0.6;
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += (waves(v_world.xz, TIME) - 0.5) * 0.025 * (1.0 - ice_amount);
}

void fragment() {
	vec2 p = v_world.xz - flow * TIME;
	float e = 0.15;
	float t = TIME;
	float hx = waves(p + vec2(e, 0.0), t) - waves(p - vec2(e, 0.0), t);
	float hz = waves(p + vec2(0.0, e), t) - waves(p - vec2(0.0, e), t);
	float k = 0.35 * (1.0 - ice_amount);
	vec3 n = normalize(vec3(-hx * k, 1.0, -hz * k));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float sparkle = value_noise(p * 3.0 + vec2(t)) * 0.08;
	vec3 c = mix(water_color.rgb + sparkle, ice_color.rgb, ice_amount);
	c = mix(c, apply_snow(c, 1.0, 1.0), ice_amount);
	ALBEDO = c;
	ALPHA = mix(0.82, 0.97, ice_amount);
	ROUGHNESS = mix(0.06, 0.35, ice_amount);
	METALLIC = 0.0;
	SPECULAR = 0.7;
}
