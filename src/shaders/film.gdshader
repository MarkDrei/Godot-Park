// The drive-in cinema's film: five little cartoon scenes drawn procedurally (Cinema).
// scene -1: the blank screen by day; 0 title, 1 duck in the park, 2 moonlit chase,
// 3 car race through town, 4 happy end.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform int scene = -1;
uniform float t = 0.0;

float circle(vec2 p, vec2 c, float r) {
	return 1.0 - smoothstep(r - 0.004, r + 0.004, length(p - c));
}

float box(vec2 p, vec2 c, vec2 h) {
	vec2 d = abs(p - c) - h;
	return 1.0 - smoothstep(-0.003, 0.003, max(d.x, d.y));
}

void fragment() {
	vec2 p = vec2(UV.x * 2.2, 1.0 - UV.y);   // x 0..2.2, y 0 (bottom)..1
	vec3 col = vec3(0.16, 0.16, 0.18);
	if (scene == 0) {
		col = vec3(0.35, 0.05, 0.08);
		for (int i = 0; i < 3; i++) {
			float a = sin(t * 0.8 + float(i) * 2.1) * 0.6;
			vec2 d = p - vec2(0.4 + float(i) * 0.7, 0.0);
			float beam = smoothstep(0.12, 0.0, abs(d.x - d.y * a) - d.y * 0.05);
			col += vec3(0.9, 0.8, 0.5) * beam * 0.35;
		}
		col += vec3(0.95, 0.75, 0.2) * box(p, vec2(1.1, 0.55), vec2(0.7, 0.16)) * 0.35;
	} else if (scene == 1) {
		col = mix(vec3(0.55, 0.78, 0.95), vec3(0.85, 0.93, 1.0), p.y);
		col = mix(col, vec3(0.42, 0.68, 0.32), step(p.y, 0.3 + 0.03 * sin(p.x * 6.0)));
		col = mix(col, vec3(1.0, 0.9, 0.4), circle(p, vec2(1.9, 0.82), 0.09));
		float x = mod(t * 0.25, 2.6) - 0.2;
		float hop = abs(sin(t * 6.0)) * 0.02;
		col = mix(col, vec3(0.95, 0.95, 0.9), circle(p, vec2(x, 0.33 + hop), 0.07));
		col = mix(col, vec3(0.2, 0.55, 0.3), circle(p, vec2(x + 0.06, 0.43 + hop), 0.045));
		col = mix(col, vec3(1.0, 0.6, 0.1), box(p, vec2(x + 0.11, 0.43 + hop), vec2(0.03, 0.01)));
		// The donut it is after.
		float dx = x + 0.45;
		float ring = circle(p, vec2(dx, 0.34), 0.05) - circle(p, vec2(dx, 0.34), 0.02);
		col = mix(col, vec3(0.95, 0.55, 0.7), clamp(ring, 0.0, 1.0));
	} else if (scene == 2) {
		col = mix(vec3(0.03, 0.05, 0.15), vec3(0.1, 0.12, 0.3), p.y);
		col = mix(col, vec3(0.95, 0.95, 0.8), circle(p, vec2(0.4, 0.8), 0.08));
		col = mix(col, vec3(0.02, 0.03, 0.06), step(p.y, 0.25));
		for (int i = 0; i < 2; i++) {
			float x = mod(t * 0.4 + float(i) * 0.35, 2.6) - 0.2;
			float hop = abs(sin(t * 7.0 + float(i))) * 0.06;
			col = mix(col, vec3(0.0), circle(p, vec2(x, 0.33 + hop), 0.06));
			col = mix(col, vec3(0.0), circle(p, vec2(x, 0.43 + hop), 0.035));
		}
		for (int s = 0; s < 12; s++) {
			vec2 c = vec2(fract(float(s) * 0.37) * 2.2, 0.5 + fract(float(s) * 0.71) * 0.5);
			col += vec3(0.8) * circle(p, c, 0.004 + 0.003 * sin(t * 3.0 + float(s)));
		}
	} else if (scene == 3) {
		col = mix(vec3(0.95, 0.6, 0.35), vec3(0.6, 0.75, 0.95), p.y);
		col = mix(col, vec3(0.3, 0.3, 0.33), step(p.y, 0.32));
		float stripe = step(0.5, fract(p.x * 4.0 + t * 3.0)) * box(p, vec2(1.1, 0.16), vec2(1.2, 0.01));
		col = mix(col, vec3(0.95), stripe);
		for (int h = 0; h < 6; h++) {
			float hx = mod(float(h) * 0.5 - t * 0.6, 3.0) - 0.4;
			col = mix(col, vec3(0.75, 0.55, 0.45), box(p, vec2(hx, 0.45), vec2(0.18, 0.13)));
			col = mix(col, vec3(0.5, 0.25, 0.2), box(p, vec2(hx, 0.6), vec2(0.2, 0.03)));
		}
		float bounce = sin(t * 9.0) * 0.006;
		col = mix(col, vec3(0.85, 0.15, 0.15), box(p, vec2(0.8, 0.24 + bounce), vec2(0.16, 0.04)));
		col = mix(col, vec3(0.85, 0.15, 0.15), box(p, vec2(0.78, 0.3 + bounce), vec2(0.08, 0.03)));
		col = mix(col, vec3(0.1), circle(p, vec2(0.7, 0.19), 0.03) + circle(p, vec2(0.9, 0.19), 0.03));
		col = mix(col, vec3(0.95, 0.85, 0.3), box(p, vec2(1.35 + sin(t) * 0.1, 0.23), vec2(0.15, 0.035)));
	} else if (scene == 4) {
		col = mix(vec3(0.95, 0.75, 0.8), vec3(1.0, 0.9, 0.85), p.y);
		for (int i = 0; i < 9; i++) {
			float x = fract(float(i) * 0.31) * 2.2;
			float y = fract(t * 0.15 + float(i) * 0.23);
			vec2 c = vec2(x + sin(t + float(i)) * 0.05, y);
			float heart = circle(p, c + vec2(-0.02, 0.01), 0.025) + circle(p, c + vec2(0.02, 0.01), 0.025)
				+ box(p, c - vec2(0.0, 0.015), vec2(0.02, 0.02));
			col = mix(col, vec3(0.9, 0.2, 0.35), clamp(heart, 0.0, 1.0));
		}
	}
	// Projector flicker and a dark frame.
	float flick = 0.94 + 0.06 * sin(t * 47.0);
	float edge = smoothstep(0.0, 0.02, UV.x) * smoothstep(1.0, 0.98, UV.x) * smoothstep(0.0, 0.03, UV.y) * smoothstep(1.0, 0.97, UV.y);
	ALBEDO = col * flick * edge;
}
