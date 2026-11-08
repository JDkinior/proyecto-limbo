shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

// Shader para las islas flotantes en el Reino Fantasma (Proyecto Limbo)
// Aplica una paleta estilizada azul oscuro grisáceo preservando las facetas low-poly de la malla
// y proyecta falso pasto en pendientes suaves/mesetas para interpretar vegetación en la distancia.

group_uniforms ColoresRoca;
uniform vec4 color_base : source_color = vec4(0.035, 0.075, 0.14, 1.0);
uniform vec4 color_resalte : source_color = vec4(0.075, 0.14, 0.23, 1.0);
uniform float rugosidad : hint_range(0.0, 1.0) = 0.94;
uniform float fuerza_variacion : hint_range(0.0, 2.0) = 1.0;
uniform vec4 color_emision : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float energia_emision : hint_range(0.0, 5.0) = 0.0;

group_uniforms LevitacionSatelites;
uniform bool habilitar_levitacion_satelites = true;
uniform float amplitud_levitacion : hint_range(0.0, 0.5, 0.01) = 0.12;
uniform float velocidad_levitacion : hint_range(0.1, 4.0, 0.05) = 1.2;
uniform float balanceo_levitacion : hint_range(0.0, 0.2, 0.005) = 0.035;

group_uniforms FalsoPastoDistancia;
uniform bool habilitar_pasto_distancia = true;
// Paleta cercana (coincide con el brillo etéreo cian de las puntas)
uniform vec4 color_pasto_cerca_base : source_color = vec4(0.025, 0.22, 0.46, 1.0);
uniform vec4 color_pasto_cerca_punta : source_color = vec4(0.045, 0.35, 0.65, 1.0);
// Paleta lejana (donde no hay pasto 3D: coincide con el brillo etéreo cian de las puntas)
uniform vec4 color_pasto_lejos_base : source_color = vec4(0.025, 0.22, 0.46, 1.0);
uniform vec4 color_pasto_lejos_punta : source_color = vec4(0.045, 0.35, 0.65, 1.0);
// Rango de transición por distancia a la cámara
uniform float distancia_transicion_inicio : hint_range(0.0, 100.0) = 20.0;
uniform float distancia_transicion_fin : hint_range(10.0, 150.0) = 48.0;

uniform float saturacion_pasto : hint_range(0.0, 1.0) = 0.90;
uniform float rugosidad_pasto : hint_range(0.0, 1.0) = 0.96;
uniform float umbral_pendiente_pasto : hint_range(0.0, 1.0) = 0.45;
uniform float suavizado_pendiente_pasto : hint_range(0.01, 0.5) = 0.15;
uniform bool habilitar_borde_pasto_colgante = false;
uniform float longitud_borde_pasto : hint_range(0.05, 1.5, 0.01) = 0.28;
uniform float irregularidad_borde_pasto : hint_range(0.1, 1.5, 0.05) = 0.78;
uniform float escala_mechones_borde : hint_range(0.5, 8.0, 0.1) = 3.2;
uniform float nitidez_borde_pasto : hint_range(0.005, 0.25, 0.005) = 0.025;

group_uniforms TexturaTerreno;
uniform sampler2D textura_ruido_terreno : hint_default_white, repeat_enable;
uniform sampler2D textura_normal_terreno : hint_normal, repeat_enable;
uniform float escala_ruido_terreno : hint_range(0.01, 2.0) = 0.22;
uniform float fuerza_variacion_pasto : hint_range(0.0, 1.0) = 0.45;
uniform bool usar_normal_ruido = true;
uniform float fuerza_normal_terreno : hint_range(0.0, 1.0) = 0.15;

group_uniforms CaminosYPintura;
uniform bool habilitar_caminos = true;
// Tierra Clara Espectral
uniform vec4 color_tierra_clara_base : source_color = vec4(0.04, 0.12, 0.24, 1.0);
uniform vec4 color_tierra_clara_resalte : source_color = vec4(0.08, 0.18, 0.32, 1.0);
// Tierra Oscura Espectral
uniform vec4 color_tierra_oscura_base : source_color = vec4(0.02, 0.05, 0.12, 1.0);
uniform vec4 color_tierra_oscura_resalte : source_color = vec4(0.04, 0.10, 0.20, 1.0);
// Roca Base Espectral
uniform vec4 color_roca_base_pintada : source_color = vec4(0.08, 0.16, 0.28, 1.0);
uniform vec4 color_roca_resalte_pintada : source_color = vec4(0.14, 0.25, 0.40, 1.0);
// Pasto Espectral adicional
uniform vec4 color_pasto_resalte : source_color = vec4(0.05, 0.40, 0.70, 1.0);
uniform float rugosidad_tierra : hint_range(0.0, 1.0) = 0.94;
uniform float contraste_borde_camino : hint_range(0.1, 5.0) = 1.6;
uniform float nitidez_borde_camino : hint_range(0.01, 0.5) = 0.06;
uniform float relieve_profundidad_camino : hint_range(0.0, 2.0) = 0.60;

varying flat float v_es_superficie;
varying float v_profundidad_borde;
varying float v_y_local;
varying vec3 v_pos_local;
varying vec3 v_pos_mundo;
varying vec4 v_mascara_camino;

void vertex() {
	v_pos_local = VERTEX;
	v_pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_y_local = VERTEX.y;
	v_es_superficie = (COLOR.a > 0.85) ? 1.0 : 0.0;
	v_profundidad_borde = (COLOR.a > 0.5 && COLOR.a <= 0.85) ? UV.x : 99.0;
	if (v_es_superficie > 0.5) {
		// x = Tierra Clara, y = Tierra Oscura, z = Roca Base, w = Pasto
		v_mascara_camino = vec4(UV2.x, UV2.y, UV.x, UV.y);
	} else {
		v_mascara_camino = vec4(0.0);
	}
	if (habilitar_levitacion_satelites && COLOR.a < 0.5) {
		// Vector relativo del vértice al centro de la roca satélite
		// UV.x codifica (VERTEX.y - centro.y)
		// UV2.x codifica (VERTEX.x - centro.x)
		// UV2.y codifica (VERTEX.z - centro.z)
		vec3 offset_local = vec3(UV2.x, UV.x, UV2.y);
		vec3 centro_roca = VERTEX - offset_local;

		// Fase determinista por roca derivada de COLOR.a
		float fase = COLOR.a * 67.0;
		float t = TIME * velocidad_levitacion;

		// 1. Levitación vertical suave y armónica (flotación en suspensión aérea)
		float dy = sin(t + fase) * amplitud_levitacion + sin(t * 0.48 + fase * 1.6) * (amplitud_levitacion * 0.22);

		// 2. Deriva horizontal sutil producida por corrientes de aire
		float dx = sin(t * 0.62 + fase * 1.3) * (amplitud_levitacion * 0.32);
		float dz = cos(t * 0.71 + fase * 0.77) * (amplitud_levitacion * 0.32);
		vec3 desplazamiento = vec3(dx, dy, dz);

		// 3. Balanceo angular tridimensional sutil (inclinación orgánica sin distorsionar la roca)
		float rx = sin(t * 0.82 + fase) * balanceo_levitacion;
		float rz = cos(t * 0.75 + fase * 1.4) * balanceo_levitacion;
		float ry = sin(t * 0.41 + fase * 0.5) * (balanceo_levitacion * 0.8);

		// Aplicar rotación rígida sobre el offset local y sobre la normal:
		// Pitch (X)
		float cx = cos(rx), sx = sin(rx);
		vec3 r_pos = vec3(offset_local.x, offset_local.y * cx - offset_local.z * sx, offset_local.y * sx + offset_local.z * cx);
		vec3 r_norm = vec3(NORMAL.x, NORMAL.y * cx - NORMAL.z * sx, NORMAL.y * sx + NORMAL.z * cx);

		// Roll (Z)
		float cz = cos(rz), sz = sin(rz);
		r_pos = vec3(r_pos.x * cz - r_pos.y * sz, r_pos.x * sz + r_pos.y * cz, r_pos.z);
		r_norm = vec3(r_norm.x * cz - r_norm.y * sz, r_norm.x * sz + r_norm.y * cz, r_norm.z);

		// Yaw (Y)
		float cy = cos(ry), sy = sin(ry);
		r_pos = vec3(r_pos.x * cy + r_pos.z * sy, r_pos.y, -r_pos.x * sy + r_pos.z * cy);
		r_norm = vec3(r_norm.x * cy + r_norm.z * sy, r_norm.y, -r_norm.x * sy + r_norm.z * cy);

		float r_len_sq = dot(r_norm, r_norm);
		NORMAL = r_len_sq > 0.0001 ? r_norm * inversesqrt(r_len_sq) : vec3(0.0, 1.0, 0.0);
		VERTEX = centro_roca + r_pos + desplazamiento;
	}
}

void fragment() {
	// Luminosidad del color por vértice para conservar la textura facetada procedural
	float lum = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	
	// Si la geometría cuenta con colores por vértice low-poly (rango típico 0.15 a 0.58)
	float t = 0.5;
	if (lum < 0.95 && lum > 0.01) {
		t = clamp((lum - 0.18) / 0.34, 0.0, 1.0);
		t = clamp(mix(0.5, t, fuerza_variacion), 0.0, 1.0);
	}
	
	vec3 col_roca = mix(color_base.rgb, color_resalte.rgb, t);
	vec3 col_final = col_roca;
	float rough_final = rugosidad;
	float factor_pasto = 0.0;

	if (habilitar_pasto_distancia) {
		// Normal en espacio de mundo para detectar planos horizontales y terrazas superiores
		// Protegida contra longitud cero para evitar NaN (pixeles negros en la GPU)
		float n_len_sq = dot(NORMAL, NORMAL);
		vec3 safe_norm = n_len_sq > 0.0001 ? NORMAL * inversesqrt(n_len_sq) : vec3(0.0, 1.0, 0.0);
		vec3 wn_unnorm = (INV_VIEW_MATRIX * vec4(safe_norm, 0.0)).xyz;
		float wn_len_sq = dot(wn_unnorm, wn_unnorm);
		vec3 world_normal = wn_len_sq > 0.0001 ? wn_unnorm * inversesqrt(wn_len_sq) : vec3(0.0, 1.0, 0.0);
		// Aislamiento estricto de la base superior:
		// La base superior tiene COLOR.a = 1.0 y v_es_superficie = 1.0.
		// El acantilado tiene COLOR.a <= 0.55 y los satélites COLOR.a < 0.50.
		float factor_superficie = 0.0;
		float factor_borde_colgante = 0.0;
		float t_altura_borde = 0.0;
		if (v_es_superficie > 0.5 && COLOR.a > 0.85) {
			factor_superficie = smoothstep(
				umbral_pendiente_pasto - suavizado_pendiente_pasto,
				umbral_pendiente_pasto + suavizado_pendiente_pasto,
				world_normal.y
			);
		} else if (habilitar_borde_pasto_colgante && COLOR.a > 0.5 && COLOR.a <= 0.85) {
			float prof_borde = (v_profundidad_borde >= 0.99 && v_profundidad_borde < 50.0) ? (v_profundidad_borde - 1.0) : max(-v_y_local, 0.0);
			if (prof_borde < longitud_borde_pasto * (1.0 + irregularidad_borde_pasto) + 0.20) {
				float ang_perim = atan(v_pos_local.z, v_pos_local.x);
				float r_medio_isla = max(length(v_pos_local.xz), 3.0);
				float arco_perim = ang_perim * r_medio_isla * (escala_ruido_terreno * escala_mechones_borde * 0.55);
				vec2 uv_borde = vec2(arco_perim, cos(ang_perim * 2.0) * 0.35 + sin(ang_perim * 3.0) * 0.25);
				float r_macro = texture(textura_ruido_terreno, uv_borde * 0.55).r;
				float r_med = texture(textura_ruido_terreno, uv_borde * 1.45 + vec2(0.31, 0.57)).r;
				float r_fino = texture(textura_ruido_terreno, uv_borde * 3.10 + vec2(0.73, 0.19)).r;
				float onda_mechon = clamp(r_macro * 0.38 + r_med * 0.38 + r_fino * 0.24, 0.0, 1.0);
				float gotas = abs(sin(arco_perim * 14.0 + r_macro * 6.2831)) * 0.65 + abs(sin(arco_perim * 27.0 + r_med * 6.2831)) * 0.35;
				float perfil_mechon = mix(onda_mechon, gotas, 0.52);
				float alcance_borde = longitud_borde_pasto * mix(1.0 - irregularidad_borde_pasto * 0.72, 1.0 + irregularidad_borde_pasto * 0.60, perfil_mechon);
				factor_borde_colgante = 1.0 - smoothstep(alcance_borde - nitidez_borde_pasto, alcance_borde + nitidez_borde_pasto, prof_borde);
				t_altura_borde = clamp(prof_borde / max(alcance_borde, 0.01), 0.0, 1.0);
				factor_superficie = factor_borde_colgante;
			}
		}
		factor_pasto = factor_superficie;
		
		// Modulación facetada cerca y lejos (en el borde colgante predomina el color claro con ligeras variaciones del oscuro)
		float t_pasto = (factor_borde_colgante > 0.001) ? mix(0.78, 1.0, t) : t;
		vec3 col_cerca = mix(color_pasto_cerca_base.rgb, color_pasto_cerca_punta.rgb, t_pasto);
		vec3 col_lejos = mix(color_pasto_lejos_base.rgb, color_pasto_lejos_punta.rgb, t_pasto);
		
		// Transición suave según la distancia euclidiana a la cámara
		float dist_cam = length(VERTEX);
		float factor_dist = smoothstep(distancia_transicion_inicio, distancia_transicion_fin, dist_cam);
		vec3 col_pasto = mix(col_cerca, col_lejos, factor_dist);
		
		// Desaturación coincidente con pasto_estilizado.gdshader (saturacion = 0.90)
		float luma_pasto = dot(col_pasto, vec3(0.299, 0.587, 0.114));
		col_pasto = mix(vec3(luma_pasto), col_pasto, saturacion_pasto);

		// --- Texturizado estilizado y Height Blend orgánico tipo óleo (Kiuun Method) ---
		vec2 uv_ruido = v_pos_mundo.xz * escala_ruido_terreno;
		// Pincelada pictórica suave (domain warping en espacio de textura)
		float ruido_guia = texture(textura_ruido_terreno, uv_ruido * 0.65).r;
		vec2 uv_oleo = uv_ruido + vec2(ruido_guia - 0.5, 0.5 - ruido_guia) * 0.18;
		float ruido_oleo = texture(textura_ruido_terreno, uv_oleo).r;

		// 1. Suelo del pasto espectral: variación suave y aterciopelada
		// 1. Suelo del pasto espectral: variación suave y aterciopelada
		float factor_ruido_pasto = smoothstep(0.28, 0.72, ruido_oleo);
		vec3 col_pasto_tonal = mix(col_pasto, color_pasto_resalte.rgb, factor_ruido_pasto * 0.40);
		vec3 col_pasto_oleo = mix(col_pasto_tonal * 0.94, col_pasto_tonal * 1.05, factor_ruido_pasto);
		vec3 col_pasto_textura = mix(col_pasto, col_pasto_oleo, fuerza_variacion_pasto * 0.65);
		float rough_pasto_textura = mix(rugosidad_pasto, rugosidad_pasto * 0.96, factor_ruido_pasto);

		// 2. Tierra Clara Espectral
		float factor_tc_oleo = smoothstep(0.30, 0.70, ruido_oleo);
		vec3 col_tc_textura = mix(color_tierra_clara_base.rgb, color_tierra_clara_resalte.rgb, factor_tc_oleo * 0.40);
		float rough_tc_textura = mix(rugosidad_tierra, rugosidad_tierra * 0.94, factor_tc_oleo);

		// 3. Tierra Oscura Espectral
		float factor_to_oleo = smoothstep(0.32, 0.68, ruido_oleo);
		vec3 col_to_textura = mix(color_tierra_oscura_base.rgb, color_tierra_oscura_resalte.rgb, factor_to_oleo * 0.35);
		float rough_to_textura = mix(rugosidad_tierra, rugosidad_tierra * 0.96, factor_to_oleo);

		// 4. Roca Base Espectral
		vec3 col_roca_pintada_textura = mix(color_roca_base_pintada.rgb, color_roca_resalte_pintada.rgb, factor_to_oleo * 0.35);

		// 5. Mezcla orgánica por Height Blend (Bordes notorios e irregulares - Método Kiuun)
		// Estado base predeterminado de la superficie:
		// Si habilitar_pasto_distancia está activo: todo el suelo se inicializa con pasto espectral.
		// Si está desactivado: todo el suelo se inicializa con roca base de forma idéntica a como el pasto cubre el suelo.
		vec3 col_superficie = habilitar_pasto_distancia ? col_pasto_textura : col_roca_pintada_textura;
		float rough_superficie = habilitar_pasto_distancia ? rough_pasto_textura : rugosidad;

		float factor_tc = 0.0;
		float factor_to = 0.0;
		float factor_roca_p = 0.0;
		float factor_pasto_p = 0.0;

		if (habilitar_caminos) {
			float mask_tc = clamp(v_mascara_camino.x, 0.0, 1.0);
			float mask_to = clamp(v_mascara_camino.y, 0.0, 1.0);
			float mask_roca = clamp(v_mascara_camino.z, 0.0, 1.0);
			float mask_pasto = clamp(v_mascara_camino.w, 0.0, 1.0);

			// A. Tierra Clara (v_mascara_camino.x) con Height Blend
			if (mask_tc > 0.0001) {
				float blend_overlay_tc = (mask_tc < 0.5) ? 
					(2.0 * mask_tc * ruido_oleo) : 
					(1.0 - 2.0 * (1.0 - mask_tc) * (1.0 - ruido_oleo));

				float factor_c_tc = clamp(contraste_borde_camino, 0.0, 1.0);
				float mask_comb_tc = mix(mask_tc, blend_overlay_tc, factor_c_tc);

				if (contraste_borde_camino > 1.0) {
					float deformacion_extra_tc = (ruido_oleo - 0.5) * (contraste_borde_camino - 1.0) * 0.45;
					float zona_borde_tc = 1.0 - abs(mask_comb_tc * 2.0 - 1.0);
					mask_comb_tc = clamp(mask_comb_tc + deformacion_extra_tc * zona_borde_tc, 0.0, 1.0);
				}

				float nitidez_tc = clamp(nitidez_borde_camino, 0.01, 0.25);
				factor_tc = smoothstep(0.5 - nitidez_tc, 0.5 + nitidez_tc, mask_comb_tc);

				col_superficie = mix(col_superficie, col_tc_textura, factor_tc);
				rough_superficie = mix(rough_superficie, rough_tc_textura, factor_tc);
			}

			// B. Tierra Oscura (v_mascara_camino.y) con Height Blend
			if (mask_to > 0.0001) {
				float blend_overlay_to = (mask_to < 0.5) ? 
					(2.0 * mask_to * ruido_oleo) : 
					(1.0 - 2.0 * (1.0 - mask_to) * (1.0 - ruido_oleo));

				float factor_c_to = clamp(contraste_borde_camino, 0.0, 1.0);
				float mask_comb_to = mix(mask_to, blend_overlay_to, factor_c_to);

				if (contraste_borde_camino > 1.0) {
					float deformacion_extra_to = (ruido_oleo - 0.5) * (contraste_borde_camino - 1.0) * 0.45;
					float zona_borde_to = 1.0 - abs(mask_comb_to * 2.0 - 1.0);
					mask_comb_to = clamp(mask_comb_to + deformacion_extra_to * zona_borde_to, 0.0, 1.0);
				}

				float nitidez_to = clamp(nitidez_borde_camino, 0.01, 0.25);
				factor_to = smoothstep(0.5 - nitidez_to, 0.5 + nitidez_to, mask_comb_to);

				col_superficie = mix(col_superficie, col_to_textura, factor_to);
				rough_superficie = mix(rough_superficie, rough_to_textura, factor_to);
			}

			// C. Roca Base Espectral (v_mascara_camino.z) con Height Blend
			if (mask_roca > 0.0001) {
				float blend_overlay_r = (mask_roca < 0.5) ? 
					(2.0 * mask_roca * ruido_oleo) : 
					(1.0 - 2.0 * (1.0 - mask_roca) * (1.0 - ruido_oleo));

				float factor_c_r = clamp(contraste_borde_camino, 0.0, 1.0);
				float mask_comb_r = mix(mask_roca, blend_overlay_r, factor_c_r);

				if (contraste_borde_camino > 1.0) {
					float deformacion_extra_r = (ruido_oleo - 0.5) * (contraste_borde_camino - 1.0) * 0.45;
					float zona_borde_r = 1.0 - abs(mask_comb_r * 2.0 - 1.0);
					mask_comb_r = clamp(mask_comb_r + deformacion_extra_r * zona_borde_r, 0.0, 1.0);
				}

				float nitidez_r = clamp(nitidez_borde_camino, 0.01, 0.25);
				factor_roca_p = smoothstep(0.5 - nitidez_r, 0.5 + nitidez_r, mask_comb_r);

				col_superficie = mix(col_superficie, col_roca_pintada_textura, factor_roca_p);
				rough_superficie = mix(rough_superficie, rugosidad, factor_roca_p);
			}

			// D. Pasto Espectral (v_mascara_camino.w) con Height Blend
			if (mask_pasto > 0.0001) {
				float blend_overlay_p = (mask_pasto < 0.5) ? 
					(2.0 * mask_pasto * ruido_oleo) : 
					(1.0 - 2.0 * (1.0 - mask_pasto) * (1.0 - ruido_oleo));

				float factor_c_p = clamp(contraste_borde_camino, 0.0, 1.0);
				float mask_comb_p = mix(mask_pasto, blend_overlay_p, factor_c_p);

				if (contraste_borde_camino > 1.0) {
					float deformacion_extra_p = (ruido_oleo - 0.5) * (contraste_borde_camino - 1.0) * 0.45;
					float zona_borde_p = 1.0 - abs(mask_comb_p * 2.0 - 1.0);
					mask_comb_p = clamp(mask_comb_p + deformacion_extra_p * zona_borde_p, 0.0, 1.0);
				}

				float nitidez_p = clamp(nitidez_borde_camino, 0.01, 0.25);
				factor_pasto_p = smoothstep(0.5 - nitidez_p, 0.5 + nitidez_p, mask_comb_p);

				col_superficie = mix(col_superficie, col_pasto_textura, factor_pasto_p);
				rough_superficie = mix(rough_superficie, rough_pasto_textura, factor_pasto_p);
			}
		}

		if (usar_normal_ruido) {
			vec3 norm_map = texture(textura_normal_terreno, uv_oleo).rgb * 2.0 - 1.0;
			
			// Gradiente de relieve físico 3D para la forma de la textura y orillas de caminos
			float perfil_h = (factor_tc * -0.35 + factor_to * -0.40 + factor_roca_p * -0.25 + factor_pasto_p * 0.35);
			vec2 grad_borde = vec2(dFdx(perfil_h), dFdy(perfil_h)) * (relieve_profundidad_camino * 3.5);
			
			vec3 norm_mundo = vec3(
				(norm_map.x * fuerza_normal_terreno * 0.25) - grad_borde.x * 0.45,
				1.0,
				(norm_map.y * fuerza_normal_terreno * 0.25) - grad_borde.y * 0.45
			);
			vec3 norm_vista = (VIEW_MATRIX * vec4(normalize(norm_mundo), 0.0)).xyz;
			NORMAL = normalize(mix(NORMAL, norm_vista, 0.25 * factor_pasto));
		}

		if (factor_borde_colgante > 0.001) {
			vec3 norm_up_vista = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
			NORMAL = normalize(mix(NORMAL, norm_up_vista, 0.95 * factor_borde_colgante));
		}

		col_final = mix(col_roca, col_superficie, factor_pasto);
		rough_final = mix(rugosidad, rough_superficie, factor_pasto);
	}
	
	ALBEDO = col_final;
	ROUGHNESS = rough_final;
	SPECULAR = mix(0.10, 0.0, factor_pasto);
	
	if (energia_emision > 0.0) {
		EMISSION = color_emision.rgb * energia_emision;
	}
}

