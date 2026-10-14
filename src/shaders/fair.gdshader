// Painted fair surfaces, no textures: vertex colour with a procedural finish chosen by `pattern`
// (index in Materials.FAIR_FINISHES): 0 painted boards, 1 canvas, 2 lacquer. Lacquer whose
// vertex alpha is below 0.5 is metal (gold or steel by its colour), so a model needs one
// surface for both (FairModels.METAL).
// Patterns use the model's local coordinates (metres), so they stay put on moving rides.
// The web renderer has no reflection probes: shiny finishes add a cheap sky reflection instead.
// Canvas whose vertex alpha is below 1 flutters in the wind (0 = free edge, 1 = fixed).
shader_type spatial;
render_mode diffuse_lambert;
#include "res://src/shaders/common.gdshaderinc"

global uniform float wind_strength;

uniform int pattern = 0;

varying vec3 v_local;
varying vec3 v_local_n;
varying float v_up;

void vertex() {
	v_local = VERTEX;
	v_local_n = NORMAL;
	v_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
	if (pattern == 1 && COLOR.a < 0.99) {
		vec3 wp = MODEL_MATRIX[3].xyz;
		float w = 1.0 - COLOR.a;
		float s = sin(TIME * 2.4 + VERTEX.x * 1.9 + wp.x * 0.4) + 0.5 * sin(TIME * 5.3 + VERTEX.x * 4.1 + wp.z);
		VERTEX.z += w * s * (0.025 + wind_strength * 0.06);
		VERTEX.y += w * abs(s) * 0.01;
	}
}

// Vertical boards on walls, boards along x on floors and counters; grooves, tone per board,
// a faint grain under the paint, darker and worn near the ground.
vec3 boards(vec3 c, vec3 l, vec3 n) {
	vec3 a = abs(n);
	bool flat_face = a.y > 0.7;
	float across = flat_face ? l.z : (a.x > a.z ? l.z : l.x);
	float along = flat_face ? l.x : l.y;
	float w = 0.17;
	float id = floor(across / w);
	float f = across - id * w;
	float edge = min(f, w - f);
	float near = detail(vec2(across, along), 0.06);
	float aa = max(fwidth(edge), 1e-4);
	float groove = 1.0 - smoothstep(0.006 - aa, 0.006 + aa, edge);
	c *= 1.0 + (hash_cell(vec2(id, 3.0)) - 0.5) * 0.12 * detail(vec2(across, along), 0.25);
	float grain = value_noise(vec2(across * 46.0, along * 1.3 + id * 7.0)) * 0.6 + value_noise(vec2(across * 90.0, along * 3.0)) * 0.4;
	c *= 1.0 + (grain - 0.5) * 0.12 * near;
	c *= 1.0 - (1.0 - smoothstep(0.0, 0.018, edge)) * 0.1 * near;
	c = mix(c, c * 0.45, groove * near);
	if (!flat_face) {
		c *= mix(0.8, 1.0, smoothstep(0.0, 0.45, l.y));
	}
	return c;
}

// Woven cotton with a soft mottle.
vec3 canvas(vec3 c, vec3 l, vec3 n) {
	vec3 a = abs(n);
	vec2 p = a.y > 0.7 ? l.xz : (a.x > a.z ? l.zy : l.xy);
	float fine = detail(p, 0.012);
	float weave = sin(p.x * 520.0) * sin(p.y * 520.0);
	c *= 1.0 + weave * 0.05 * fine;
	c *= 1.0 + (value_noise(p * 3.0) - 0.5) * 0.08 * detail(p, 0.3);
	return c;
}

void fragment() {
	vec3 c = COLOR.rgb;
	vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 r = normalize((INV_VIEW_MATRIX * vec4(reflect(-VIEW, NORMAL), 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	float rough = 0.85;
	float spec = 0.3;
	vec3 glint = vec3(0.0);
	if (pattern == 0) {
		c = boards(c, v_local, v_local_n);
		rough = 0.75;
	} else if (pattern == 1) {
		c = canvas(c, v_local, v_local_n);
		rough = 0.95;
		spec = 0.15;
	} else if (COLOR.a > 0.5) {
		rough = 0.28;
		spec = 0.6;
		glint = sky_env(r) * mix(0.04, 0.5, fres);
	} else {
		rough = 0.3;
		spec = 0.7;
		glint = sky_env(r) * c * mix(0.45, 0.9, fres) + c * 0.06;
		c *= 0.65;
	}
	c = apply_snow(c, v_up, 1.0);
	ALBEDO = apply_wet(c);
	ROUGHNESS = mix(rough, 0.35, wetness);
	SPECULAR = spec;
	EMISSION = glint * (1.0 - smoothstep(0.45, 0.85, n_world.y) * snow_amount);
}
