shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha, depth_draw_always;

uniform vec3 fog_color : source_color = vec3(0.8, 0.8, 0.85);
uniform float density : hint_range(0.0, 5.0) = 1.5;
uniform float scale : hint_range(0.1, 10.0) = 2.0;
uniform float speed : hint_range(0.0, 2.0) = 0.1;
uniform int steps : hint_range(1, 32) = 12;
uniform float height_falloff : hint_range(0.0, 5.0) = 2.0;
uniform float contrast : hint_range(0.1, 5.0) = 2.0;
uniform float edge_fade_radius : hint_range(0.1, 20.0) = 8.0;
uniform float step_size : hint_range(0.05, 1.0) = 0.2;
uniform bool enable_scatter = true;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898,78.233,45.164))) * 43758.5453);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float n000 = hash(i + vec3(0.0,0.0,0.0));
	float n100 = hash(i + vec3(1.0,0.0,0.0));
	float n010 = hash(i + vec3(0.0,1.0,0.0));
	float n110 = hash(i + vec3(1.0,1.0,0.0));
	float n001 = hash(i + vec3(0.0,0.0,1.0));
	float n101 = hash(i + vec3(1.0,0.0,1.0));
	float n011 = hash(i + vec3(0.0,1.0,1.0));
	float n111 = hash(i + vec3(1.0,1.0,1.0));

	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);

	float nxy0 = mix(nx00, nx10, f.y);
	float nxy1 = mix(nx01, nx11, f.y);

	return mix(nxy0, nxy1, f.z);
}

float fbm(vec3 p) {
	float f = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		f += amp * noise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return f;
}

void fragment() {
	vec3 ray_dir = normalize(VIEW);
	vec3 ray_pos = NODE_POSITION_WORLD;
	float fog_accum = 0.0;

	for (int i = 0; i < steps; i++) {
		float n = fbm(ray_pos * scale + vec3(TIME * speed, 0.0, TIME * speed));
		fog_accum += n * density / float(steps);
		ray_pos += ray_dir * step_size;
	}

	// Contraste y remapeo
	fog_accum = pow(fog_accum, contrast);
	fog_accum = smoothstep(0.2, 0.8, fog_accum);

	// Atenuación por altura
	float height_factor = exp(-NODE_POSITION_WORLD.y / height_falloff);
	fog_accum *= height_factor;

	// Fade en bordes (efecto volumen suave)
	vec3 local_pos = (NODE_POSITION_WORLD - NODE_POSITION_WORLD);
	float dist = length(local_pos);
	float fade = smoothstep(edge_fade_radius, edge_fade_radius * 0.6, dist);
	fog_accum *= fade;

	vec3 color = fog_color;

	// Dispersión simulada (opcional)
	if (enable_scatter) {
		float light_dir = dot(normalize(VIEW), vec3(0.0, -0.3, -1.0));
		float scatter = clamp(light_dir, 0.0, 1.0);
		color = mix(color, vec3(1.0), scatter * 0.3);
	}

	ALBEDO = color;
	ALPHA = clamp(fog_accum, 0.0, 1.0);
}
