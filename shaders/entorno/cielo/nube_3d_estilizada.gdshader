shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_back;

// ===================================================================
// SHADER DE NUBE 3D ESTILIZADA FLOTANTE (GODOT 4)
// Proyecto Limbo - Optimizado para Mobile / Desktop
// ===================================================================

group_uniforms Colores;
uniform vec4 color_principal : source_color = vec4(0.98, 0.95, 0.92, 1.0);
uniform vec4 color_sombra : source_color = vec4(0.48, 0.42, 0.58, 1.0);
uniform vec4 color_borde_luz : source_color = vec4(1.0, 0.88, 0.65, 1.0);
uniform float gradiente_altura_min = -1.5;
uniform float gradiente_altura_max = 1.5;

group_uniforms Borde_y_Fresnel;
uniform float potencia_rim : hint_range(0.5, 8.0) = 2.5;
uniform float fuerza_rim : hint_range(0.0, 3.0) = 1.2;

group_uniforms Animacion_Organica;
uniform float velocidad_respiracion : hint_range(0.0, 5.0) = 1.2;
uniform float amplitud_respiracion : hint_range(0.0, 0.2) = 0.04;
uniform float frecuencia_onda : hint_range(0.1, 5.0) = 1.5;

group_uniforms Modo_Espiritual;
uniform bool es_espiritual = false;
uniform vec4 color_espiritual : source_color = vec4(0.3, 0.85, 1.0, 1.0);
uniform float energia_emision_espiritual : hint_range(0.0, 5.0) = 1.8;
uniform float velocidad_pulso_espiritual : hint_range(0.0, 5.0) = 2.0;

varying vec3 v_pos_local;
varying vec3 v_normal_mundo;

void vertex() {
	v_pos_local = VERTEX;
	
	// Pulsación orgánica suave de la nube (efecto esponjoso respirando)
	float onda1 = sin(TIME * velocidad_respiracion + (VERTEX.x + VERTEX.z) * frecuencia_onda);
	float onda2 = cos(TIME * (velocidad_respiracion * 0.75) + VERTEX.y * (frecuencia_onda * 1.2));
	float deformacion = (onda1 + onda2 * 0.5) * amplitud_respiracion;

	VERTEX += NORMAL * deformacion;
	v_normal_mundo = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	// 1. Gradiente vertical (la base de la nube recibe sombra ambiental / crepuscular)
	float t_altura = clamp((v_pos_local.y - gradiente_altura_min) / max(0.01, gradiente_altura_max - gradiente_altura_min), 0.0, 1.0);
	t_altura = smoothstep(0.15, 0.85, t_altura);

	vec3 color_base_nube = mix(color_sombra.rgb, color_principal.rgb, t_altura);

	// 2. Rim Light suave tipo algodón / silver lining
	vec3 view_dir = normalize(VIEW);
	float fresnel = 1.0 - clamp(dot(NORMAL, view_dir), 0.0, 1.0);
	float rim = pow(fresnel, potencia_rim) * fuerza_rim;
	vec3 color_final = color_base_nube + (color_borde_luz.rgb * rim * 0.6);

	// 3. Ajuste para Plano Espiritual
	if (es_espiritual) {
		float pulso = 0.8 + 0.2 * sin(TIME * velocidad_pulso_espiritual + v_pos_local.x * 2.0);
		vec3 color_esp = mix(color_base_nube, color_espiritual.rgb, 0.6);
		color_final = color_esp;
		EMISSION = color_espiritual.rgb * (energia_emision_espiritual * (rim * 0.8 + 0.25) * pulso);
	}

	ALBEDO = color_final;
	ROUGHNESS = 0.9;
	SPECULAR = 0.05;
}
