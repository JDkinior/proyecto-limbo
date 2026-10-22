shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

// ==============================================================================
// SHADER DE OJOS EXPRESIVOS DE POSESIÓN - PROYECTO LIMBO
// Estilo Kirby Mouthful / Mario Odyssey para objetos poseídos por el Fantasma.
// ==============================================================================

uniform vec4 color_esclerotica : source_color = vec4(0.92, 0.98, 1.0, 1.0);
uniform vec4 color_iris : source_color = vec4(0.08, 0.35, 0.85, 1.0);
uniform vec4 color_pupila : source_color = vec4(0.02, 0.08, 0.22, 1.0);
uniform vec4 color_brillo_reflejo : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform vec2 offset_mirada = vec2(0.0, 0.0);
uniform float factor_parpadeo : hint_range(0.0, 1.0, 0.05) = 0.0; // 0 = abierto, 1 = completamente cerrado
uniform float escala_iris : hint_range(0.3, 0.9, 0.05) = 0.62;

void fragment() {
	// UV normalizado centrado (-1.0 a 1.0)
	vec2 uv_centrado = (UV - vec2(0.5)) * 2.0;

	// Simulación de párpado (parpadeo)
	float corte_parpado = 1.0 - factor_parpadeo;
	if (abs(uv_centrado.y) > corte_parpado) {
		discard;
	}

	// Forma elíptica del ojo (más alto que ancho, estilo cartoon)
	vec2 coord_ojo = uv_centrado;
	coord_ojo.x *= 1.15;
	float dist_borde_ojo = length(coord_ojo);

	if (dist_borde_ojo > 0.98) {
		discard;
	}

	// Color base de esclerótica
	vec3 color_res = color_esclerotica.rgb;

	// Posición del iris desplazada por la mirada (input del fantasma)
	vec2 centro_iris = offset_mirada * 0.35;
	vec2 coord_iris = (uv_centrado - centro_iris) / escala_iris;
	float dist_iris = length(coord_iris);

	if (dist_iris < 1.0) {
		// Degradado del iris hacia la pupila
		float t_iris = smoothstep(0.0, 1.0, dist_iris);
		color_res = mix(color_pupila.rgb, color_iris.rgb, t_iris);

		// Pupila oscura en el centro
		if (dist_iris < 0.55) {
			color_res = color_pupila.rgb;
		}

		// Brillo especular principal (arriba a la derecha)
		vec2 pos_brillo1 = coord_iris - vec2(0.28, 0.32);
		if (length(pos_brillo1) < 0.25) {
			color_res = color_brillo_reflejo.rgb;
		}

		// Brillo especular secundario pequeño (abajo a la izquierda)
		vec2 pos_brillo2 = coord_iris - vec2(-0.25, -0.28);
		if (length(pos_brillo2) < 0.12) {
			color_res = color_brillo_reflejo.rgb;
		}
	}

	// Borde sutil oscuro exterior del ojo
	if (dist_borde_ojo > 0.88) {
		float sombra_borde = smoothstep(0.88, 0.98, dist_borde_ojo);
		color_res = mix(color_res, color_pupila.rgb * 0.5, sombra_borde * 0.7);
	}

	ALBEDO = color_res;
	ALPHA = 1.0;
}
