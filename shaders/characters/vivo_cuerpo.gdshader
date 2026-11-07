shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
stencil_mode write, compare_always, 1;

// ==============================================================================
// SHADER DE CUERPO DEL VIVO (PROYECTO LIMBO)
// Permite desacoplar el tono cálido de la sombra del amarillo limón de la luz,
// manteniendo el destello especular y el efecto Rim intactos.
// ==============================================================================

group_uniforms PaletaCuerpo;
uniform vec4 color_luz : source_color = vec4(0.86, 0.805, 0.23, 1.0);
uniform vec4 color_sombra : source_color = vec4(0.862, 0.716, 0.242, 1.0);
uniform float umbral_luz : hint_range(-1.0, 1.0) = -0.05;
uniform float suavizado_transicion : hint_range(0.05, 1.0) = 0.45;

group_uniforms Superficie;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform float roughness : hint_range(0.0, 1.0) = 0.35;
uniform float rim : hint_range(0.0, 1.0) = 0.2;
uniform float rim_tint : hint_range(0.0, 1.0) = 0.4;

// Dirección del sol principal en mundo (apunta hacia la fuente de luz)
uniform vec3 dir_sol_mundo = vec3(-0.25, 0.8660254, -0.4330127);

void fragment() {
	vec3 normal_mundo = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float ndotl = dot(normal_mundo, normalize(dir_sol_mundo));
	float factor_luz = smoothstep(umbral_luz - suavizado_transicion, umbral_luz + suavizado_transicion, ndotl);
	
	ALBEDO = mix(color_sombra.rgb, color_luz.rgb, factor_luz);
	SPECULAR = specular;
	ROUGHNESS = roughness;
	RIM = rim;
	RIM_TINT = rim_tint;
}
