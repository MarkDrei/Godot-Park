// Light pillar over a driving job's target (DriveJob): visible from afar, fades upwards.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.82, 0.3, 1.0);
uniform float t = 0.0;

void fragment() {
	float fade = 1.0 - UV.y;
	float pulse = 0.75 + 0.25 * sin(t * 3.0 - UV.y * 8.0);
	ALBEDO = color.rgb;
	ALPHA = clamp(fade * fade * 0.55 * pulse, 0.0, 1.0);
}
