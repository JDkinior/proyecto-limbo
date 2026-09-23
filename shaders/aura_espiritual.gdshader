shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

// ==============================================================================
// SHADER DE AURA ESPIRITUAL (PROYECTO LIMBO)
// - Degradado radial extendido hacia el interior con presencia continua.
// - Conforme se acerca al fantasma, la opacidad disminuye suavemente hasta 0.
// - Anillo perimetral amplio, nítido y luminoso en los bordes.
// - Mezcla blend_mix limpia para mantener los tonos cian/azules sin quemar en blanco.
// ==============================================================================

uniform vec4 color_borde : source_color = vec4(0.20, 0.92, 1.0, 0.95);
uniform vec4 color_interior : source_color = vec4(0.12, 0.72, 1.0, 0.75);
uniform float radio_malla = 1.0;
uniform float radio_inicio_color : hint_range(0.0, 0.2) = 0.02;
uniform float exponente_degradado : hint_range(0.3, 2.5) = 0.75;
uniform float ancho_anillo_borde : hint_range(0.1, 0.7) = 0.45;
uniform float intensidad_borde : hint_range(1.0, 3.0) = 1.30;
uniform float opacidad : hint_range(0.0, 1.0) = 1.0;

varying vec2 pos_local;
varying float es_tapa_superior;

void vertex() {
	es_tapa_superior = NORMAL.y > 0.7 ? 1.0 : 0.0;
	pos_local = VERTEX.xz;
}

void fragment() {
	if (es_tapa_superior < 0.5) {
		discard;
	}

	float dist = length(pos_local) / max(0.001, radio_malla);
	if (dist > 1.0) {
		discard;
	}

	// 1. Degradado extenso que abarca el interior hacia el fantasma:
	// Justo en el centro (<= radio_inicio_color) es 100% transparente.
	// La curva sub-lineal (exponente ~0.75) extiende el color hacia adentro con suavidad.
	float t_degradado = clamp((dist - radio_inicio_color) / max(0.001, 1.0 - radio_inicio_color), 0.0, 1.0);
	float factor_cuerpo = pow(t_degradado, exponente_degradado);

	// 2. Anillo exterior amplio con transición difuminada hacia el interior
	float borde_externo = 1.0 - smoothstep(0.95, 1.0, dist);
	float borde_interno = smoothstep(1.0 - ancho_anillo_borde, 0.94, dist);
	float anillo_borde = borde_externo * borde_interno;

	// 3. Alpha compuesto: transición continua y fluida de adentro hacia afuera
	float alpha_cuerpo = color_interior.a * factor_cuerpo;
	float alpha_anillo = color_borde.a * anillo_borde;
	float alpha_final = clamp(alpha_cuerpo + alpha_anillo * (1.0 - alpha_cuerpo * 0.5), 0.0, 1.0) * opacidad * borde_externo;

	if (alpha_final < 0.005) {
		discard;
	}

	// 4. Color compuesto: azul etéreo luminoso que transiciona hacia cian brillante en el anillo
	float factor_mezcla_color = clamp(anillo_borde * 0.9 + factor_cuerpo * 0.55, 0.0, 1.0);
	vec3 color_final = mix(color_interior.rgb, color_borde.rgb * intensidad_borde, factor_mezcla_color);

	ALBEDO = color_final;
	ALPHA = alpha_final;
}
