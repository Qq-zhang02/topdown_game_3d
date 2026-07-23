shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_always;

uniform vec4 beam_color : source_color = vec4(0.3, 0.75, 1.0, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float edge_softness : hint_range(0.0, 0.5) = 0.08;
uniform float edge_fade : hint_range(0.0, 1.0) = 0.6;
uniform float scroll_speed : hint_range(-10.0, 10.0) = 6.0;
uniform float noise_scale : hint_range(1.0, 64.0) = 20.0;
uniform float intensity : hint_range(0.0, 10.0) = 4.0;

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash22(i).x;
	float b = hash22(i + vec2(1.0, 0.0)).x;
	float c = hash22(i + vec2(0.0, 1.0)).x;
	float d = hash22(i + vec2(1.0, 1.0)).x;
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	float v = UV.y;

	// 前缘生长
	float lead = 1.0 - smoothstep(progress - edge_softness, progress, v);
	// 根部淡入
	float tail = smoothstep(0.0, 0.1, v);

	// 沿柱身流动的能量噪声
	float n = value_noise(vec2(UV.x * noise_scale * 0.5, v * noise_scale)
	                      + vec2(0.0, TIME * scroll_speed));
	float energy = 0.35 + 0.65 * n;

	// 尖端更亮
	float tip = smoothstep(0.75, 1.0, v);

	// Fresnel 边缘淡出
	float fresnel = 1.0 - abs(dot(NORMAL, VIEW));
	float edge = 1.0 - smoothstep(0.0, 0.45, fresnel) * edge_fade;

	float alpha = lead * tail * energy * edge;
	vec3 col = beam_color.rgb * (1.0 + tip * 1.5);

	ALBEDO = col;
	EMISSION = col * intensity * (1.0 + tip * 0.8);
	ALPHA = alpha * beam_color.a;
}
