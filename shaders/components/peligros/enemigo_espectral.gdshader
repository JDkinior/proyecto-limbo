shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_toon, specular_toon;

// ===================================================================
// SHADER DE ENEMIGO ESPECTRAL (PROYECTO LIMBO)
// Silueta oscura, morada/grisácea con resalte Fresnel plateado/violeta,
// ondulación etérea en las colas y ojos carmesí brillantes.
// Superficie dieléctrica mate para evitar reflejos especulares parásitos.
// ===================================================================

group_uniforms Colores;
uniform vec4 color_cuerpo : source_color = vec4(0.28, 0.30, 0.34, 1.0);
uniform vec4 color_fresnel : source_color = vec4(0.88, 0.92, 0.96, 1.0);
uniform vec4 color_nucleo_oscuro : source_color = vec4(0.08, 0.09, 0.11, 1.0);

group_uniforms Emision;
uniform float fuerza_emision : hint_range(0.0, 5.0) = 1.15;
uniform float exponente_fresnel : hint_range(0.5, 6.0) = 2.0;
uniform float velocidad_pulso : hint_range(0.1, 5.0) = 2.0;

group_uniforms DeformacionOndulante;
uniform float ondulacion_colas : hint_range(0.0, 0.2) = 0.04;
uniform float velocidad_colas : hint_range(0.5, 8.0) = 3.5;

group_uniforms Tangibilidad;
uniform float factor_tangible : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color_tangible_destello : source_color = vec4(0.3, 0.85, 1.0, 1.0);

group_uniforms PropiedadesSuperficie;
uniform float rugosidad : hint_range(0.0, 1.0) = 0.50;
uniform float metalico : hint_range(0.0, 1.0) = 0.0;
uniform float especular : hint_range(0.0, 1.0) = 0.25;

varying float pos_y_local;

void vertex() {
	pos_y_local = VERTEX.y;
	
	// Ondulación etérea más pronunciada en la parte inferior (colas)
	float factor_altura = clamp(-VERTEX.y - 0.35, 0.0, 1.5);
	float onda_x = sin(TIME * velocidad_colas + VERTEX.y * 3.0) * ondulacion_colas * factor_altura;
	float onda_z = cos(TIME * velocidad_colas * 0.8 + VERTEX.y * 2.5) * ondulacion_colas * factor_altura;
	
	VERTEX.x += onda_x;
	VERTEX.z += onda_z;
}

void fragment() {
	float dot_nv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - dot_nv, exponente_fresnel);
	
	// Pulso de respiración espectral
	float pulso = sin(TIME * velocidad_pulso) * 0.5 + 0.5;
	
	// Mezcla entre cuerpo gris-ahumado y borde plateado brillante
	vec3 albedo_base = mix(color_fresnel.rgb * 0.85, mix(color_nucleo_oscuro.rgb, color_cuerpo.rgb, pow(dot_nv, 0.65)), dot_nv);
	
	// Si se vuelve tangible por el aura, adquiere un resalte cian/blanco eléctrico
	vec3 albedo_final = mix(albedo_base, color_tangible_destello.rgb * 0.65, factor_tangible * 0.45);
	
	// Emisión compuesta por fresnel plateado + destello de aura
	vec3 emision_fresnel = color_fresnel.rgb * fresnel * fuerza_emision * (0.85 + pulso * 0.3);
	vec3 emision_tangible = color_tangible_destello.rgb * factor_tangible * 1.5;
	
	ALBEDO = albedo_final;
	EMISSION = emision_fresnel + emision_tangible;
	ROUGHNESS = rugosidad;
	METALLIC = metalico;
	SPECULAR = especular;
	ALPHA = 1.0;
}
