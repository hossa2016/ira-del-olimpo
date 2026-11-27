shader_type spatial;
render_mode cull_disabled;
// Agua: dos capas de normales que se desplazan, fresnel hacia el cielo y brillo del sol.
uniform vec3 deep : source_color = vec3(0.05, 0.16, 0.22);
uniform vec3 shallow : source_color = vec3(0.16, 0.32, 0.36);
uniform sampler2D nmap : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float scale = 0.035;
uniform float speed = 0.02;
uniform float roughness_v = 0.06;
uniform vec3 glow : source_color = vec3(0.0);

varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 uv = wpos.xz * scale;
	vec3 n1 = texture(nmap, uv + vec2(TIME * speed, TIME * speed * 0.6)).rgb;
	vec3 n2 = texture(nmap, uv * 2.3 - vec2(TIME * speed * 0.7, -TIME * speed)).rgb;
	NORMAL_MAP = normalize(mix(n1, n2, 0.5));
	NORMAL_MAP_DEPTH = 0.6;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(deep, shallow, fres);
	ROUGHNESS = roughness_v;
	METALLIC = 0.0;
	SPECULAR = 0.7;
	EMISSION = glow;
}
