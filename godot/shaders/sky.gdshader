shader_type sky;
// Cielo pintado con nubes procedurales para lo que se ve, y foto HDRI (CC0, Poly Haven)
// solo para los reflejos y la luz ambiente del metal y la piel.

uniform vec3 top_color : source_color = vec3(0.3, 0.45, 0.66);
uniform vec3 horizon_color : source_color = vec3(0.93, 0.72, 0.55);
uniform vec3 ground_color : source_color = vec3(0.22, 0.3, 0.38);
uniform vec3 cloud_color : source_color = vec3(1.0, 0.9, 0.8);
uniform vec3 cloud_shade : source_color = vec3(0.55, 0.45, 0.45);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.5;
uniform float sun_size = 0.03;
uniform float sun_glow = 1.0;
uniform float energy = 1.0;
uniform sampler2D hdri : filter_linear, hint_default_black;
uniform float hdri_mix : hint_range(0.0, 1.0) = 0.5;
uniform float hdri_energy = 0.35;
uniform vec3 hdri_tint : source_color = vec3(1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return v;
}

vec3 painted(vec3 dir) {
	float y = dir.y;
	vec3 col;
	if (y >= 0.0) {
		float t = pow(1.0 - y, 4.0);
		col = mix(top_color, horizon_color, t);
	} else {
		col = mix(horizon_color, ground_color, clamp(-y * 4.0, 0.0, 1.0));
	}
	// sol y halo
	vec3 sd = LIGHT0_DIRECTION;
	float sa = dot(dir, sd);
	float halo = pow(max(sa, 0.0), 8.0) * 0.35 + pow(max(sa, 0.0), 64.0) * 0.6;
	col += LIGHT0_COLOR * halo * sun_glow * 0.5;
	col += LIGHT0_COLOR * smoothstep(1.0 - sun_size * 0.02, 1.0 - sun_size * 0.012, sa) * 4.0;
	// nubes en una cúpula
	if (y > 0.0) {
		vec2 uv = dir.xz / (y + 0.12) * 1.2;
		float n = fbm(uv * 1.3);
		float d = fbm(uv * 1.3 + sd.xz * 0.08);
		float c = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.35, n);
		float lit = clamp((n - d) * 4.0 + 0.6, 0.0, 1.0);
		vec3 cc = mix(cloud_shade, cloud_color, lit) + LIGHT0_COLOR * pow(max(sa, 0.0), 6.0) * 0.6;
		float fade = smoothstep(0.0, 0.25, y);
		col = mix(col, cc, c * fade * 0.9);
	}
	return col * energy;
}

void sky() {
	vec3 col = painted(EYEDIR);
	if (AT_CUBEMAP_PASS) {
		vec2 uv = vec2(atan(EYEDIR.x, -EYEDIR.z) / 6.2831853 + 0.5, acos(clamp(EYEDIR.y, -1.0, 1.0)) / 3.14159265);
		vec3 h = texture(hdri, uv).rgb * hdri_energy * hdri_tint;
		h = h / (1.0 + h * 0.15);
		col = mix(col, h, hdri_mix);
	}
	COLOR = col;
}
