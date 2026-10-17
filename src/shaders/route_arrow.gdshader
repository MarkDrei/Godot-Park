// Navigation arrow on the road in front of the player's car (RouteArrow): glows in the job's
// colour, light bands run from tail to tip (UV.x is metres from the tail).
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.82, 0.3, 1.0);
uniform float t = 0.0;

void fragment() {
	float band = smoothstep(0.7, 1.0, sin(UV.x * 1.2 - t * 6.0));
	// The light top glows in the job's colour, the dark rim stays dark.
	vec3 lit = mix(color.rgb, vec3(1.0), 0.18) * (1.0 + 0.35 * band);
	ALBEDO = COLOR.r > 0.5 ? lit : color.rgb * COLOR.r * 1.5;
}
