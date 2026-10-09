// Terrain: vertex colour (alpha = grass mask), season tint, noise variation, snow.
shader_type spatial;
render_mode diffuse_lambert;
#include "res://src/shaders/common.gdshaderinc"

global uniform vec4 grass_tint;

varying vec3 v_world;
varying float v_up;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}

void fragment() {
	float grass = COLOR.a;
	vec3 c = COLOR.rgb;
	float n = value_noise(v_world.xz * 0.12) * 0.6 + value_noise(v_world.xz * 0.9) * 0.4;
	c *= mix(1.0, 0.82 + n * 0.36, grass);
	// Up close: blade streaks and clover patches in the grass.
	float near = detail(v_world.xz, 0.16);
	float blades = value_noise(v_world.xz * vec2(9.0, 23.0)) * 0.5 + value_noise(v_world.xz * vec2(23.0, 8.0)) * 0.5;
	float s;
	float clover = pebbles(v_world.xz, 1.6, 0.3, s);
	c *= mix(1.0, (0.8 + blades * 0.4) * (1.0 - clover * (0.06 + 0.08 * s)), grass * near);
	// Bare ground (gravel yards, sand, banks): a little grain instead of a flat colour.
	c *= mix(0.9 + value_noise(v_world.xz * 2.7) * 0.2, 1.0, grass);
	c = mix(c, c * grass_tint.rgb, grass);
	c = apply_snow(c, v_up, mix(0.75, 1.0, grass));
	ALBEDO = apply_wet(c);
	ROUGHNESS = mix(0.95, 0.5, wetness * (1.0 - grass));
	SPECULAR = 0.25;
}
