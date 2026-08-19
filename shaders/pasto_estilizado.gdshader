shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

// ==========================================
// SHADER DE PASTO ESTILIZADO 3D (GODOT 4)
// Proyecto Limbo - Optimizado para Mobile / PC
// ==========================================

group_uniforms Colores;
uniform vec4 color_base : source_color = vec4(0.38, 0.24, 0.02, 1.0);
uniform vec4 color_punta : source_color = vec4(0.66, 0.49, 0.07, 1.0);
uniform float suavizado_gradiente : hint_range(0.1, 1.0) = 0.78;
uniform float curva_gradiente : hint_range(0.2, 4.0) = 1.30;
uniform float saturacion : hint_range(0.0, 1.0) = 0.85;
uniform float brillo_puntas : hint_range(0.0, 1.0) = 0.02;
uniform float translucidencia : hint_range(0.0, 1.0) = 0.06;
uniform float oclusion_base : hint_range(0.0, 1.0) = 0.08;

group_uniforms Viento;
uniform vec2 direccion_viento = vec2(1.0, 0.4);
uniform float velocidad_viento : hint_range(0.0, 10.0) = 2.0;
uniform float fuerza_viento : hint_range(0.0, 2.0) = 0.18;
uniform float escala_onda : hint_range(0.1, 20.0) = 2.5;
uniform float turbulencia : hint_range(0.0, 2.0) = 0.35;

group_uniforms Interaccion_Suave;
uniform vec3 posicion_jugador = vec3(0.0, 9999.0, 0.0);
uniform vec3 posicion_fantasma = vec3(0.0, 9999.0, 0.0);
uniform float radio_interaccion : hint_range(0.1, 3.0) = 0.75;
uniform float fuerza_interaccion : hint_range(0.0, 2.0) = 0.45;

group_uniforms TexturaRuido;
uniform sampler2D textura_ruido : hint_default_white;
uniform bool usar_textura_ruido = false;

varying float factor_altura;

void vertex() {
	// factor_altura: 0.0 en la raíz (suelo), 1.0 en la punta afilada
	factor_altura = clamp(UV.y, 0.0, 1.0);

	// Posición global de la instancia y vértice
	vec3 pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	mat3 inv_rot = mat3(
		vec3(MODEL_MATRIX[0].x, MODEL_MATRIX[1].x, MODEL_MATRIX[2].x),
		vec3(MODEL_MATRIX[0].y, MODEL_MATRIX[1].y, MODEL_MATRIX[2].y),
		vec3(MODEL_MATRIX[0].z, MODEL_MATRIX[1].z, MODEL_MATRIX[2].z)
	);

	vec2 dir_viento = length(direccion_viento) > 0.001 ? normalize(direccion_viento) : vec2(1.0, 0.0);

	// 1. Simulación de Viento suave
	float tiempo = TIME * velocidad_viento;
	float coord_onda = (pos_mundo.x * dir_viento.x + pos_mundo.z * dir_viento.y) / escala_onda;
	float onda1 = sin(tiempo + coord_onda);
	float onda2 = cos(tiempo * 1.5 + (pos_mundo.x * dir_viento.y - pos_mundo.z * dir_viento.x) / (escala_onda * 0.7)) * turbulencia;

	float viento_magnitud = (onda1 + onda2) * fuerza_viento;

	if (usar_textura_ruido) {
		vec2 noise_uv = (pos_mundo.xz * 0.06) + dir_viento * (TIME * velocidad_viento * 0.04);
		float ruido = texture(textura_ruido, noise_uv).r * 2.0 - 1.0;
		viento_magnitud += ruido * fuerza_viento * 0.4;
	}

	float flexion_altura = pow(factor_altura, 1.4);

	vec3 viento_mundo = vec3(
		dir_viento.x * viento_magnitud,
		-abs(viento_magnitud) * 0.2,
		dir_viento.y * viento_magnitud
	) * flexion_altura;

	// 2. Interacción Suave con Personajes
	vec3 empuje_mundo = vec3(0.0);

	// Interacción Jugador
	vec3 dir_jugador = pos_mundo - posicion_jugador;
	dir_jugador.y = 0.0;
	float dist_jugador = length(dir_jugador);
	if (dist_jugador < radio_interaccion && dist_jugador > 0.001) {
		float factor_suave = smoothstep(radio_interaccion, 0.0, dist_jugador);
		float factor = factor_suave * factor_suave * fuerza_interaccion * flexion_altura;
		empuje_mundo += (normalize(dir_jugador) * factor * 0.35) + vec3(0.0, -factor * 0.75, 0.0);
	}

	// Interacción Fantasma
	vec3 dir_fantasma = pos_mundo - posicion_fantasma;
	dir_fantasma.y = 0.0;
	float dist_fantasma = length(dir_fantasma);
	if (dist_fantasma < radio_interaccion && dist_fantasma > 0.001) {
		float factor_suave_f = smoothstep(radio_interaccion, 0.0, dist_fantasma);
		float factor_f = factor_suave_f * factor_suave_f * fuerza_interaccion * flexion_altura;
		empuje_mundo += (normalize(dir_fantasma) * factor_f * 0.35) + vec3(0.0, -factor_f * 0.75, 0.0);
	}

	vec3 desplazamiento_local = inv_rot * (viento_mundo + empuje_mundo);
	VERTEX += desplazamiento_local;

	// Normales estilizadas hacia arriba (Upward Foliage Normals) para iluminación uniforme total sin sombras de espalda
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
}

void fragment() {
	// Forzar normal hacia arriba en vista para iluminación consistente y sin caras oscuras de contraplano
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;

	// Gradiente de color raíz→punta
	float factor_t = clamp(factor_altura / max(0.01, suavizado_gradiente), 0.0, 1.0);
	float factor_color = pow(factor_t, curva_gradiente);
	vec4 color_final = mix(color_base, color_punta, factor_color);

	// Brillo sutil en las puntas (contraluz solar)
	if (brillo_puntas > 0.01) {
		float brillo = smoothstep(0.75, 1.0, factor_altura) * brillo_puntas;
		color_final.rgb += color_punta.rgb * (brillo * 0.25);
	}

	// Desaturación explícita para contrarrestar el ambiente cálido/brillante de la escena
	float luma = dot(color_final.rgb, vec3(0.299, 0.587, 0.114));
	color_final.rgb = mix(vec3(luma), color_final.rgb, saturacion);

	ALBEDO = color_final.rgb;
	ROUGHNESS = 0.95;
	SPECULAR = 0.0;

	// AO sutil basado en altura para preservar variación suave entre briznas
	float ao_valor = mix(1.0 - oclusion_base, 1.0, pow(factor_altura, 0.70));
	AO = ao_valor;
	AO_LIGHT_AFFECT = 0.25;

	BACKLIGHT = color_punta.rgb * translucidencia * smoothstep(0.6, 1.0, factor_altura);
}

