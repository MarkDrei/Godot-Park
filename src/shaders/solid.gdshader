// Static props: vertex colour + snow on upward faces + wet darkening.
shader_type spatial;
render_mode diffuse_lambert;
#include "res://src/shaders/common.gdshaderinc"

uniform float snow_factor = 1.0;
varying float v_up;

void vertex() {
	v_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}

void fragment() {
	vec3 c = apply_snow(COLOR.rgb, v_up, snow_factor);
	ALBEDO = apply_wet(c);
	ROUGHNESS = mix(0.88, 0.45, wetness);
	SPECULAR = 0.3;
}
