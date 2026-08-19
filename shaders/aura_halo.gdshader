shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

uniform vec4 color_halo : source_color = vec4(0.10, 0.70, 1.0, 1.0);

void fragment() {
    vec2 centro = UV * 2.0 - vec2(1.0);
    float distancia = length(centro);
    float borde_externo = 1.0 - smoothstep(0.78, 1.0, distancia);
    float borde_interno = smoothstep(0.48, 0.76, distancia);
    float anillo = borde_externo * borde_interno;

    ALBEDO = color_halo.rgb * anillo;
    EMISSION = color_halo.rgb * anillo * 2.0;
    ALPHA = anillo * 0.42;
}