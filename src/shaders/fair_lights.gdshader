// Fair bulbs: lit a little by day, bright at night, with a chase running through them
// (a wave along the model's local position, so a ring of bulbs on a turning wheel keeps it).
// With `chase` 0, or a vertex alpha of 0, they are steady lamps (light panels, tubes), brighter
// by day.
shader_type spatial;
render_mode diffuse_lambert;
#include "res://src/shaders/common.gdshaderinc"

uniform float strength = 2.6;
uniform float day = 0.35;
uniform float speed = 3.5;
uniform float chase = 1.0;

varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	float k = sin(dot(v_local, vec3(2.9, 2.3, 2.9)) - TIME * speed);
	float c = chase * COLOR.a;
	float lit = mix(1.0, mix(0.4, 1.0, smoothstep(-0.3, 0.5, k)), c);
	ALBEDO = COLOR.rgb * 0.7;
	EMISSION = COLOR.rgb * (mix(0.9, day, c) + night_amount * strength) * lit;
	ROUGHNESS = 0.4;
}
