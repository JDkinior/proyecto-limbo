shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

uniform vec4 color_halo : source_color = vec4(0.18, 0.82, 1.0, 0.25);
uniform float radio_malla = 1.16;
uniform float radio_hueco_metros : hint_range(0.2, 2.0) = 0.85;
uniform float radio_actual = 10.0;
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

	float distancia = length(pos_local) / max(0.001, radio_malla);
	if (distancia > 1.0) {
		discard;
	}

	float r_efectivo = radio_actual > 0.01 ? radio_actual : max(0.01, escala_mundo);
	float radio_inicio = clamp(radio_hueco_metros / r_efectivo, 0.0, 0.85);
	if (distancia <= radio_inicio) {
		discard;
	}

	float borde_externo = 1.0 - smoothstep(0.92, 1.0, distancia);
	float borde_interno = smoothstep(0.70, 0.92, distancia);
	float halo = borde_externo * borde_interno;

	float alpha = halo * opacidad * color_halo.a;
	if (alpha < 0.005) {
		discard;
	}

	ALBEDO = color_halo.rgb;
	ALPHA = alpha;
}