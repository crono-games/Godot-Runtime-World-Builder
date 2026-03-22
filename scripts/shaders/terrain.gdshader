	shader_type spatial;
	render_mode blend_mix, depth_draw_opaque, cull_back, specular_disabled, vertex_lighting, specular_occlusion_disabled;


	// === Uniforms ===
	uniform sampler2D heightmap : repeat_disable, filter_linear;
	uniform float height_scale = 1.0;


	uniform sampler2D splatmap : repeat_disable;
	uniform sampler2D tex_grass : source_color, filter_linear, repeat_enable;
	uniform sampler2D tex_rock : source_color, filter_linear, repeat_enable;

	uniform float tex_scale = 8.0;


	// === Varyings ===
	varying vec3 v_vertex_ws;
	varying vec2 v_uv;


	// === Vertex ===
	void vertex() {
	// Coordenadas en UV del mesh
	v_uv = UV;


	// Altura desde el heightmap
	float h = texture(heightmap, v_uv).r;
	VERTEX.y = h * height_scale;

	// Guardar posición en mundo
	v_vertex_ws = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	}


	// === Fragment ===
	void fragment() {
	// Splatmap (usamos R y G)
	vec4 splat = texture(splatmap, v_uv);


	// Muestreo de texturas repetidas
	vec4 grass = texture(tex_grass, v_uv * tex_scale);
	vec4 rock = texture(tex_rock, v_uv * tex_scale);


	// Combinación simple
	vec4 color = grass * splat.r + rock * splat.g;


	ALBEDO = color.rgb;
	ROUGHNESS = 0.8;
	}