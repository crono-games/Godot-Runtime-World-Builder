shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back;

uniform sampler2D normal_map;
uniform float wave_speed = 0.1;
uniform float transparency = 0.7;

void fragment() {
    vec2 uv = UV;
    uv.x += TIME * wave_speed;
    vec3 n = texture(normal_map, uv).rgb * 2.0 - 1.0;

    ALBEDO = vec3(0.0, 0.3, 0.6); // azul aguas
    ALPHA = transparency;
    NORMAL = normalize(n);
}
