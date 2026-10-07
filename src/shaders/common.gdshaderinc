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
