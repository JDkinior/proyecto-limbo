shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_lambert, specular_schlick_ggx;

// ==============================================================================
// SHADER DE POSESIÓN ESPECTRAL - PROYECTO LIMBO
// Transforma cualquier objeto físico (roca, plataforma, mecanismo) en una entidad
// espiritual translúcida dominada por el Fantasma, estilo Kirby/Mario Odyssey.
// ==============================================================================

group_uniforms EstiloEspectral;
uniform vec4 color_espiritual_base : source_color = vec4(0.06, 0.42, 0.78, 1.0);
uniform vec4 color_fresnel_brillante : source_color = vec4(0.28, 0.88, 1.0, 1.0);
uniform vec4 color_nucleo_brillo : source_color = vec4(0.55, 0.95, 1.0, 1.0);

group_uniforms PropiedadesMaterial;
uniform float opacidad_base : hint_range(0.2, 1.0, 0.05) = 0.78;
uniform float rugosidad : hint_range(0.0, 1.0, 0.05) = 0.25;
uniform float metalico : hint_range(0.0, 1.0, 0.05) = 0.10;
uniform float potencia_fresnel : hint_range(1.0, 6.0, 0.1) = 2.8;
uniform float energia_emision : hint_range(0.5, 4.0, 0.1) = 1.85;

group_uniforms PulsoOndas;
uniform float velocidad_pulso : hint_range(0.5, 6.0, 0.1) = 2.4;
uniform float frecuencia_ondas_y : hint_range(0.5, 8.0, 0.1) = 2.2;
uniform float amplitud_pulso : hint_range(0.0, 0.6, 0.05) = 0.22;

void fragment() {
	// 1. Efecto Fresnel en los bordes para definir la silueta brillante
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), potencia_fresnel);

	// 2. Ondas místicas que recorren la superficie verticalmente
	float onda_y = sin(TIME * velocidad_pulso + VERTEX.y * frecuencia_ondas_y) * 0.5 + 0.5;
	float pulso = 1.0 + (onda_y * amplitud_pulso);

	// 3. Mezcla armónica de color: Núcleo etéreo + Resalte exterior
	vec3 color_final = mix(color_espiritual_base.rgb, color_fresnel_brillante.rgb, fresnel * 0.75);
	color_final = mix(color_final, color_nucleo_brillo.rgb, onda_y * 0.25);

	ALBEDO = color_final;
	ROUGHNESS = rugosidad;
	METALLIC = metalico;

	// 4. Emisión espectral con pulso místico
	vec3 emision = color_fresnel_brillante.rgb * fresnel * energia_emision * pulso;
	emision += color_espiritual_base.rgb * 0.18 * pulso;
	EMISSION = emision;

	// 5. Translucidez estilizada
	ALPHA = clamp(opacidad_base + (fresnel * 0.22), 0.35, 0.95);
}
