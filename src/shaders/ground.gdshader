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
	c = mix(c, c * grass_tint.rgb, grass);
	c = apply_snow(c, v_up, mix(0.75, 1.0, grass));
	ALBEDO = apply_wet(c);
	ROUGHNESS = mix(0.95, 0.5, wetness * (1.0 - grass));
	SPECULAR = 0.25;
}
