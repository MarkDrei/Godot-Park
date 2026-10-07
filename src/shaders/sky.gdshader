// Day/night sky: gradient, sun and moon discs, clouds and stars.
shader_type sky;

uniform vec3 top_color = vec3(0.25, 0.48, 0.85);
uniform vec3 horizon_color = vec3(0.7, 0.82, 0.92);
uniform vec3 ground_color = vec3(0.32, 0.36, 0.3);
uniform float star_amount = 0.0;
uniform float cloud_amount = 0.35;
uniform vec3 cloud_color = vec3(1.0);
uniform float time_offset = 0.0;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 45758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), u.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(horizon_color, top_color, smoothstep(0.0, 0.55, h));
	if (h < 0.0) {
		col = mix(horizon_color, ground_color, smoothstep(0.0, -0.15, h));
	}
	if (LIGHT0_ENABLED) {
		float s = dot(d, LIGHT0_DIRECTION);
		col += LIGHT0_COLOR * (smoothstep(0.9993, 0.9997, s) * 6.0 + pow(max(s, 0.0), 24.0) * 0.35) * min(LIGHT0_ENERGY, 1.5);
	}
	if (LIGHT1_ENABLED) {
		float m = dot(d, LIGHT1_DIRECTION);
		col += vec3(0.9, 0.92, 1.0) * smoothstep(0.9990, 0.9994, m) * 1.5 + vec3(0.2, 0.25, 0.4) * pow(max(m, 0.0), 32.0) * 0.3;
	}
	if (h > 0.0) {
		vec2 sp = d.xz / max(h, 0.02);
		float stars = step(0.9975, h21(floor(d.xz / (h + 0.3) * 260.0))) * star_amount * smoothstep(0.0, 0.25, h);
		col += vec3(stars);
		float c = fbm(sp * 0.35 + vec2(TIME * 0.004 + time_offset, 0.0));
		float cover = smoothstep(1.0 - cloud_amount, 1.0 - cloud_amount + 0.25, c) * smoothstep(0.0, 0.18, h);
		col = mix(col, cloud_color, cover * 0.9);
	}
	COLOR = col;
}
