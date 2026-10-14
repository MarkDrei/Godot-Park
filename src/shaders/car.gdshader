// Cars of the Oststadt (CarModels): paint, lamps, glass, chrome and rubber on one surface (one
// draw call per car), chosen by the vertex alpha (CarModels.PAINT 1, LAMP 0.83, GLASS 0.66,
// CHROME 0.33, MATTE 0). Paint is a glossy clear coat, lamps glow at night like glow.gdshader,
// glass is a dark tinted mirror, chrome mirrors the sky in its own tint (sky_env: the web
// renderer has no reflection probes).
shader_type spatial;
render_mode diffuse_lambert;
#include "res://src/shaders/common.gdshaderinc"

varying float v_up;

void vertex() {
	v_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}

void fragment() {
	vec3 c = COLOR.rgb;
	float a = COLOR.a;
	vec3 r = normalize((INV_VIEW_MATRIX * vec4(reflect(-VIEW, NORMAL), 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	float rough = 0.9;
	float spec = 0.15;
	vec3 glint = vec3(0.0);
	if (a > 0.9) {
		rough = 0.22;
		spec = 0.55;
		glint = sky_env(r) * mix(0.05, 0.55, fres);
		c = apply_snow(c, v_up, 0.8);
	} else if (a > 0.75) {
		rough = 0.6;
		glint = c * (0.15 + night_amount * 2.5);
		c *= 0.6;
	} else if (a > 0.5) {
		rough = 0.08;
		spec = 0.7;
		glint = sky_env(r) * mix(0.2, 0.85, fres);
		c = apply_snow(c, v_up, 0.6);
	} else if (a > 0.17) {
		rough = 0.18;
		spec = 0.8;
		glint = sky_env(r) * c * mix(0.6, 1.0, fres) + c * 0.05;
		c *= 0.35;
	}
	ALBEDO = apply_wet(c);
	ROUGHNESS = mix(rough, rough * 0.6, wetness);
	SPECULAR = spec;
	EMISSION = glint * (1.0 - smoothstep(0.45, 0.85, v_up) * snow_amount);
}
