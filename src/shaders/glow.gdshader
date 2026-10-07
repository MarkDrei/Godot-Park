// Lamp bulbs, windows: glow at night.
shader_type spatial;
render_mode diffuse_lambert;
#include "res://src/shaders/common.gdshaderinc"

uniform float strength = 2.5;

void fragment() {
	ALBEDO = COLOR.rgb * 0.6;
	EMISSION = COLOR.rgb * night_amount * strength;
	ROUGHNESS = 0.6;
}
