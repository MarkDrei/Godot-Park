// Navigation arrow over the player's car (RouteArrow): glows in the job's colour, a light
// band runs from tail to tip.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.82, 0.3, 1.0);
uniform float t = 0.0;

varying float v_z;

void vertex() {
	v_z = VERTEX.z;
}

void fragment() {
	float band = smoothstep(0.75, 1.0, sin(v_z * 2.6 - t * 6.0));
	// The light top glows in the job's colour, the dark plate stays dark.
	vec3 lit = mix(color.rgb, vec3(1.0), 0.18) * (1.0 + 0.3 * band);
	ALBEDO = COLOR.r > 0.5 ? lit : color.rgb * COLOR.r * 1.5;
}
