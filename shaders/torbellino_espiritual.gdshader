shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

// ===================================================================
// SHADER DE TORBELLINO ESPIRITUAL (PROYECTO LIMBO)
// Vórtice etéreo en espiral, bandas de viento giratorias y resplandor.
// Doble cara visible (interior/exterior) y colores celestiales brillantes.
// ===================================================================

group_uniforms Colores;
uniform vec4 color_base : source_color = vec4(0.08, 0.38, 0.88, 0.55);
uniform vec4 color_nucleo : source_color = vec4(0.65, 0.92, 1.0, 0.85);
uniform vec4 color_borde : source_color = vec4(0.35, 0.85, 1.0, 1.0);

group_uniforms Dinamica_Viento;
uniform float velocidad_giro : hint_range(0.0, 12.0) = 4.5;
uniform float escala_espiral : hint_range(1.0, 12.0) = 4.0;
uniform float velocidad_ondulacion : hint_range(0.0, 8.0) = 2.4;
uniform float amplitud_ondulacion : hint_range(0.0, 0.5) = 0.12;

group_uniforms Brillo_y_Fresnel;
uniform float fuerza_fresnel : hint_range(0.0, 6.0) = 2.4;
uniform float exponente_fresnel : hint_range(0.5, 5.0) = 2.0;
uniform float energia_emision : hint_range(0.0, 5.0) = 2.2;
uniform float transparencia_base : hint_range(0.0, 1.0) = 0.65;

varying vec3 v_pos_local;
varying vec2 v_uv;

void vertex() {
	v_pos_local = VERTEX;
	v_uv = UV;

	// Ondulación y curvatura orgánica del torbellino según la altura
	float factor_altura = clamp((VERTEX.y + 2.0) * 0.25, 0.0, 2.0);
	float osc_x = sin(TIME * velocidad_ondulacion + VERTEX.y * 1.8) * amplitud_ondulacion * factor_altura;
	float osc_z = cos(TIME * (velocidad_ondulacion * 0.85) + VERTEX.y * 1.6) * amplitud_ondulacion * factor_altura;
	VERTEX.x += osc_x;
	VERTEX.z += osc_z;
}

void fragment() {
	// 1. Orientación normal de doble cara para verse tanto desde afuera como desde adentro
	vec3 n = NORMAL;
	if (!FRONT_FACING) {
		n = -n;
	}

	// 2. Bandas de viento en espiral cruzadas que rotan a alta velocidad
	float espiral_1 = sin((v_uv.x * escala_espiral + v_uv.y * 2.5 - TIME * velocidad_giro) * 6.28318) * 0.5 + 0.5;
	float espiral_2 = cos((v_uv.x * (escala_espiral * 1.5) - v_uv.y * 3.2 - TIME * (velocidad_giro * 1.35)) * 6.28318) * 0.5 + 0.5;
	float bandas = clamp(mix(espiral_1, espiral_2, 0.45) * 1.25, 0.0, 1.0);

	// 3. Difuminado suave en la base y en la corona superior para evitar cortes secos
	float fade_altura = smoothstep(0.0, 0.12, v_uv.y) * smoothstep(1.0, 0.88, v_uv.y);

	// 4. Resplandor Fresnel en los bordes para silueta etérea tanto interior como exterior
	float dot_nv = clamp(dot(n, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - dot_nv, exponente_fresnel) * fuerza_fresnel;

	// 5. Mezcla cromática espiritual y emisión vibrante acorde a la imagen 2
	vec3 color_albedo = mix(color_base.rgb, color_nucleo.rgb, bandas * 0.7);
	vec3 emision_total = (
		color_borde.rgb * fresnel * 0.8 +
		color_nucleo.rgb * bandas * 0.9 +
		color_base.rgb * 0.3
	) * energia_emision;

	ALBEDO = color_albedo;
	EMISSION = emision_total;

	// 6. Semitransparencia suave que permite apreciar al Fantasma dentro del vórtice
	float alpha_bandas = smoothstep(0.12, 0.88, bandas) * color_base.a * transparencia_base;
	ALPHA = clamp((alpha_bandas + fresnel * 0.35) * fade_altura, 0.0, 0.75);
	ROUGHNESS = 0.15;
	SPECULAR = 0.2;
}
