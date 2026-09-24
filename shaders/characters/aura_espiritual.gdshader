shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

// ==============================================================================
// SHADER DE AURA ESPIRITUAL (PROYECTO LIMBO)
// - Espacio transparente constante en metros físicos alrededor del fantasma
//   (radio_hueco_metros), garantizando que no corte la malla del personaje
//   incluso conforme la habilidad se va encogiendo.
// - Degradado radial fluido y extenso hacia el exterior.
// - Anillo perimetral luminoso y bien definido en los bordes.
// ==============================================================================

uniform vec4 color_borde : source_color = vec4(0.20, 0.92, 1.0, 0.95);
uniform vec4 color_interior : source_color = vec4(0.12, 0.72, 1.0, 0.75);
uniform float radio_malla = 1.0;
uniform float radio_hueco_metros : hint_range(0.2, 2.0) = 0.85;
uniform float radio_actual = 10.0;
uniform float exponente_degradado : hint_range(0.3, 2.5) = 0.75;
uniform float ancho_anillo_borde : hint_range(0.1, 0.7) = 0.45;
uniform float intensidad_borde : hint_range(1.0, 3.0) = 1.30;
uniform float opacidad : hint_range(0.0, 1.0) = 1.0;

varying vec2 pos_local;
varying float es_tapa_superior;
varying float escala_mundo;

void vertex() {
	es_tapa_superior = NORMAL.y > 0.7 ? 1.0 : 0.0;
	pos_local = VERTEX.xz;
	escala_mundo = length(MODEL_MATRIX[0].xyz);
}

void fragment() {
	if (es_tapa_superior < 0.5) {
		discard;
	}

	float dist = length(pos_local) / max(0.001, radio_malla);
	if (dist > 1.0) {
		discard;
	}

	// 1. Radio de inicio normalizado dinámico:
	// Mantiene el hueco transparente exactamente constante en metros físicos (0.85m)
	// sin importar cuánto se encoja o expanda el radio de la habilidad.
	float r_efectivo = radio_actual > 0.01 ? radio_actual : max(0.01, escala_mundo);
	float radio_inicio = clamp(radio_hueco_metros / r_efectivo, 0.0, 0.85);

	// 2. Degradado desde el margen transparente hacia afuera
	float t_degradado = clamp((dist - radio_inicio) / max(0.001, 1.0 - radio_inicio), 0.0, 1.0);
	float factor_cuerpo = pow(t_degradado, exponente_degradado);

	// 3. Anillo exterior con transición continua
	float borde_externo = 1.0 - smoothstep(0.95, 1.0, dist);
	float borde_interno = smoothstep(1.0 - ancho_anillo_borde, 0.94, dist);
	float anillo_borde = borde_externo * borde_interno;

	// 4. Alpha compuesto
	float alpha_cuerpo = color_interior.a * factor_cuerpo;
	float alpha_anillo = color_borde.a * anillo_borde;
	float alpha_final = clamp(alpha_cuerpo + alpha_anillo * (1.0 - alpha_cuerpo * 0.5), 0.0, 1.0) * opacidad * borde_externo;

	if (alpha_final < 0.005) {
		discard;
	}

	// 5. Color compuesto
	float factor_mezcla_color = clamp(anillo_borde * 0.9 + factor_cuerpo * 0.55, 0.0, 1.0);
	vec3 color_final = mix(color_interior.rgb, color_borde.rgb * intensidad_borde, factor_mezcla_color);

	ALBEDO = color_final;
	ALPHA = alpha_final;
}
