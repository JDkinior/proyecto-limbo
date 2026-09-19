shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_toon, specular_toon;

// ===================================================================
// SHADER DE ORBE ESPIRITUAL (PROYECTO LIMBO)
// Resplandor Fresnel espectral, pulsación vital de alma y ondas de energía
// ===================================================================

group_uniforms Colores;
uniform vec4 color_base : source_color = vec4(0.08, 0.35, 0.88, 0.82);
uniform vec4 color_borde_fresnel : source_color = vec4(0.35, 0.88, 1.0, 1.0);
uniform vec4 color_nucleo : source_color = vec4(0.75, 0.96, 1.0, 1.0);

group_uniforms Efectos;
uniform float fuerza_fresnel : hint_range(0.0, 6.0) = 2.8;
uniform float exponente_fresnel : hint_range(0.5, 6.0) = 2.2;
uniform float fuerza_emision : hint_range(0.0, 5.0) = 2.2;
uniform float velocidad_pulso : hint_range(0.0, 8.0) = 2.8;
uniform float amplitud_pulso : hint_range(0.0, 1.0) = 0.35;
uniform float velocidad_onda : hint_range(0.0, 8.0) = 2.2;
uniform float escala_onda : hint_range(0.5, 10.0) = 3.5;
uniform float deformacion_vertice : hint_range(0.0, 0.1) = 0.025;

varying float pos_y_local;
varying vec3 normal_local;

void vertex() {
	pos_y_local = VERTEX.y;
	normal_local = NORMAL;
	
	// Respiración sutil del orbe
	float pulso_latido = sin(TIME * velocidad_pulso) * deformacion_vertice;
	VERTEX += NORMAL * pulso_latido;
}

void fragment() {
	// Resplandor Fresnel en los bordes (halo espectral)
	float dot_nv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - dot_nv, exponente_fresnel) * fuerza_fresnel;
	
	// Pulso de respiración del alma
	float pulso = sin(TIME * velocidad_pulso) * 0.5 + 0.5;
	float factor_pulso = mix(1.0 - amplitud_pulso, 1.0 + amplitud_pulso * 0.5, pulso);
	
	// Onda etérea que recorre las facetas
	float onda = sin(TIME * velocidad_onda + pos_y_local * escala_onda + (UV.x + UV.y) * 3.14159) * 0.5 + 0.5;
	
	// Mezcla de color base con el núcleo luminoso
	vec3 color_albedo = mix(color_base.rgb, color_nucleo.rgb, onda * 0.25);
	
	// Emisión compuesta: bordes fresnel brillantes + núcleo pulsante + onda energética
	vec3 emision_total = (
		color_borde_fresnel.rgb * fresnel * 0.9 +
		color_nucleo.rgb * (1.0 - clamp(dot_nv * 1.5, 0.0, 0.8)) * 0.5 +
		color_borde_fresnel.rgb * onda * 0.4
	) * fuerza_emision * factor_pulso;
	
	ALBEDO = color_albedo;
	EMISSION = emision_total;
	ALPHA = clamp(color_base.a + fresnel * 0.35 + onda * 0.1, 0.0, 1.0);
	ROUGHNESS = 0.12;
	METALLIC = 0.25;
}
