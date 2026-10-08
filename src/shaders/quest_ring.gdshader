// Soft glowing ring on the ground under quest givers, quest items and minigames.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.82, 0.3, 1.0);
uniform float strength = 1.0;

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float ring = smoothstep(0.6, 0.78, d) * (1.0 - smoothstep(0.82, 1.0, d));
	float inner = (1.0 - smoothstep(0.2, 0.8, d)) * 0.15;
	ALBEDO = color.rgb;
	ALPHA = clamp((ring * 0.9 + inner) * strength, 0.0, 1.0);
}
