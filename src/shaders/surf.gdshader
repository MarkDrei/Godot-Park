// Surf along the beach: foam bands running up the sand and fading. UV.x along the shore,
// UV.y from the water's edge (0) out to the sea (1).
shader_type spatial;
render_mode blend_mix, diffuse_lambert, cull_disabled, depth_draw_never;
#include "res://src/shaders/common.gdshaderinc"

void fragment() {
	float t = TIME;
	float y = UV.y;
	float wobble = value_noise(vec2(UV.x * 0.15, t * 0.2)) * 0.25 + sin(UV.x * 0.07 + t * 0.3) * 0.08;
	// Two waves a cycle, each running towards the shore and thinning out.
	float phase = fract(t * 0.16 + wobble);
	float band = 0.0;
	for (int k = 0; k < 2; k++) {
		float ph = fract(phase + float(k) * 0.5);
		float front = 1.0 - ph;
		float d = y - front;
		band += smoothstep(0.12, 0.0, abs(d)) * (1.0 - ph * 0.6);
		band += smoothstep(0.0, 0.25, d) * smoothstep(0.55, 0.25, d) * 0.25 * (1.0 - ph);
	}
	float lace = value_noise(vec2(UV.x * 1.3, y * 9.0 - t * 0.9));
	float foam = clamp(band * (0.55 + 0.6 * lace), 0.0, 1.0);
	foam *= smoothstep(0.0, 0.06, y) * smoothstep(1.0, 0.6, y);
	ALBEDO = vec3(0.95, 0.97, 0.97);
	ALPHA = foam * 0.85;
	ROUGHNESS = 0.4;
}
