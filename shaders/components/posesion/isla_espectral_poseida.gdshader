shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

// ==============================================================================
// SHADER DE ISLA ESPECTRAL POSEÍDA - PROYECTO LIMBO
// Unifica la plataforma y el copete emergente como una sola entidad espiritual.
// Reproduce fielmente el color azul zafiro/eléctrico con silueta cian brillante
// de la Imagen 3 de referencia, sin desvíos morados ni sobreexposición.
// ==============================================================================

group_uniforms ColoresEspectrales;
// Colores calibrados directamente con la Imagen 3 de referencia
uniform vec4 color_cuerpo : source_color = vec4(0.065, 0.38, 0.90, 1.0);
uniform vec4 color_sombra : source_color = vec4(0.025, 0.20, 0.65, 1.0);
// Brillo de silueta en bordes (rim cian intenso y luminoso de la Imagen 3)
uniform vec4 color_rim_fresnel : source_color = vec4(0.28, 0.82, 1.0, 1.0);
uniform vec4 color_resalte_facetas : source_color = vec4(0.12, 0.55, 0.96, 1.0);

group_uniforms PropiedadesLuz;
uniform float potencia_fresnel : hint_range(1.0, 8.0, 0.1) = 2.6;
uniform float energia_emision_rim : hint_range(0.0, 3.0, 0.05) = 1.35;
uniform float energia_emision_base : hint_range(0.0, 1.0, 0.02) = 0.0;
uniform float rugosidad : hint_range(0.0, 1.0, 0.05) = 0.22;
uniform float metalico : hint_range(0.0, 1.0, 0.05) = 0.0;

group_uniforms PulsoMistico;
uniform float factor_pulso : hint_range(0.0, 0.5, 0.02) = 0.04;
uniform float velocidad_pulso : hint_range(0.2, 5.0, 0.1) = 1.2;

void fragment() {
	// 1. Color de cuerpo uniforme
	vec3 color_base = color_cuerpo.rgb;

	// 2. Efecto Fresnel silueta (brillo intenso en los bordes exteriores rasantes)
	float dot_nv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - dot_nv, potencia_fresnel);

	// 3. Sutil oscilación de energía uniforme
	float pulso = 1.0 + (sin(TIME * velocidad_pulso) * 0.5 + 0.5) * factor_pulso;

	// 4. Color albedo balanceado
	vec3 color_albedo = mix(color_base, color_resalte_facetas.rgb, fresnel * 0.20);
	ALBEDO = color_albedo;
	ROUGHNESS = rugosidad;
	METALLIC = metalico;

	// 5. Emisión luminosa de contorno ("brillo en los bordes" fiel a la Imagen 3)
	// Base cero para preservar las facetas y evitar sobre-saturación hacia lavanda en ACES
	vec3 emision = color_rim_fresnel.rgb * fresnel * energia_emision_rim * pulso;
	emision += color_base * energia_emision_base * pulso;
	EMISSION = emision;
}

void light() {
	// =========================================================================
	// ILUMINACIÓN ESTILIZADA UNIFICADA (HALF-LAMBERT + TOON SUAVE)
	// =========================================================================
	float n_dot_l = dot(NORMAL, LIGHT);
	float half_lambert = clamp(n_dot_l * 0.5 + 0.5, 0.0, 1.0);
	float factor_luz = smoothstep(0.18, 0.72, half_lambert);

	// Filtro espectral: eliminamos componente rojo de luces externas que causan morado
	vec3 luz_filtrada = LIGHT_COLOR;
	luz_filtrada.r = min(luz_filtrada.r, luz_filtrada.g * 0.08);

	// En Godot 4 Spatial, DIFFUSE_LIGHT acumula irradiancia pura (el motor la multiplica por ALBEDO).
	// Evitamos multiplicar por ALBEDO aquí para no elevar al cuadrado el color.
	vec3 irrad_sombra = color_sombra.rgb / max(vec3(0.05), color_cuerpo.rgb) * 0.45;
	vec3 irrad_luz = luz_filtrada * 1.05;
	vec3 irrad_difusa = mix(irrad_sombra, irrad_luz, factor_luz * ATTENUATION);
	DIFFUSE_LIGHT += irrad_difusa;

	// Brillo especular cian puro en los bordes y facetas
	vec3 h = normalize(VIEW + LIGHT);
	float n_dot_h = clamp(dot(NORMAL, h), 0.0, 1.0);
	float spec = pow(n_dot_h, 32.0) * smoothstep(0.20, 0.65, half_lambert) * ATTENUATION;
	vec3 specular = vec3(0.15, 0.85, 1.0) * spec * 0.45;
	SPECULAR_LIGHT += specular;
}
