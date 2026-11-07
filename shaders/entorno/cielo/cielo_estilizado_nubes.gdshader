shader_type sky;

// ===================================================================
// SHADER DE CIELO ESTILIZADO - PROYECTO LIMBO (GODOT 4)
// Cúmulos Volumétricos Pictóricos Isótropos (Estilo Mario Odyssey / Astrobot),
// Degradado 3-Tonos Fiel a la Referencia (Azulada Cenit, Media, Baja Horizonte),
// Sol Radiante Definido con Halo Cálido, Estrellas 3D y Luna Creciente
// ===================================================================

group_uniforms Colores_Cielo;
uniform bool usar_cielo_tres_tonos = true;
// Tonos exactos solicitados por referencia (Imagen 2):
// Cenit ("Parte Alta"):     rgb(237, 221, 162) -> Color(0.929, 0.867, 0.635)
// Media ("Parte Media"):    rgb(250, 230, 144) -> Color(0.980, 0.902, 0.565)
// Baja ("Parte Baja"):      rgb(254, 237, 157) -> Color(0.996, 0.929, 0.616)
uniform vec4 color_cielo_cenit : source_color = vec4(0.929, 0.867, 0.635, 1.0);
uniform vec4 color_cielo_medio : source_color = vec4(0.980, 0.902, 0.565, 1.0);
uniform vec4 color_cielo_horizonte : source_color = vec4(0.996, 0.929, 0.616, 1.0);
uniform float punto_cielo_medio : hint_range(0.1, 0.6) = 0.26;
uniform float altitud_cielo_cenit : hint_range(0.4, 1.0) = 0.65;

uniform vec4 color_suelo_horizonte : source_color = vec4(0.91, 0.72, 0.38, 1.0);
uniform vec4 color_suelo_nadir : source_color = vec4(0.76, 0.52, 0.22, 1.0);
uniform float exponente_gradiente_cielo : hint_range(0.5, 5.0) = 1.6;

group_uniforms Nubes_Pintura_Anime_Oleo;
uniform bool usar_textura_optimizada = true;
uniform sampler2D textura_ruido_nubes : filter_linear_mipmap, repeat_enable;
// Tonos de nubes cálidos según referencia Imagen 2:
// "Claro nube": Tono crema dorado cálido iluminado rgb(253, 252, 207)
// "Medio": Tono dorado cálido de nube rgb(248, 225, 155)
// "Fondo nube": Sombra cálida ámbar-naranja de atardecer rgb(240, 186, 112)
uniform vec4 color_nube_luz : source_color = vec4(0.992, 0.988, 0.812, 1.0);
uniform vec4 color_nube_medio : source_color = vec4(0.973, 0.882, 0.608, 1.0);
uniform vec4 color_nube_sombra : source_color = vec4(0.941, 0.729, 0.439, 1.0);
uniform vec4 color_borde_solar : source_color = vec4(0.988, 0.965, 0.620, 1.0);

// Parámetros de proyección isótropa sin distorsiones
uniform float repeticiones_horizontales : hint_range(1.0, 12.0) = 4.0;
uniform float escala_vertical : hint_range(0.1, 4.0) = 1.0;
uniform float escala_nubes : hint_range(0.1, 4.0) = 1.0;
uniform float cobertura_nubes : hint_range(0.0, 1.0) = 0.42;
uniform float nitidez_borde : hint_range(0.001, 0.2) = 0.035;

uniform float altitud_minima : hint_range(0.0, 0.3) = 0.04;
uniform float altitud_maxima : hint_range(0.5, 1.0) = 0.85;

// Parámetros de Cortes Cel-Shaded Suavizados
uniform float corte_sombra : hint_range(0.0, 1.0) = 0.28;
uniform float corte_luz : hint_range(0.0, 1.0) = 0.54;
uniform float corte_cresta : hint_range(0.0, 1.0) = 0.75;
uniform float nitidez_cel : hint_range(0.001, 0.2) = 0.05;
uniform float fuerza_rim_solar : hint_range(0.0, 3.0) = 0.40;

group_uniforms Nubes_Suaves_Volumetricas;
uniform bool modo_nubes_suaves = true;
uniform float opacidad_nubes : hint_range(0.0, 1.0) = 0.94;
uniform float detalle_bordes : hint_range(0.0, 1.0) = 0.15;

group_uniforms Viento_Nubes;
uniform vec2 direccion_viento = vec2(1.0, 0.0); // Desplazamiento puramente lateral por defecto
uniform float velocidad_viento : hint_range(0.0, 2.0) = 0.12;
uniform float velocidad_evolucion : hint_range(0.0, 1.0) = 0.02;

group_uniforms Sol_y_Luna;
uniform bool modo_luna = false;
uniform bool usar_direccion_personalizada = true;
// Posición solar aprobada en Imagen 1:
uniform vec3 direccion_sol_personalizada = vec3(0.50, 0.20, -0.84);
// Tonos exactos solicitados para el sol en Imagen 2:
// Centro: rgb(253, 252, 232) -> Color(0.992, 0.988, 0.910)
// Halo:   rgb(252, 246, 158) -> Color(0.988, 0.965, 0.620)
uniform vec4 color_disco_solar : source_color = vec4(0.992, 0.988, 0.910, 1.0);
uniform vec4 color_halo_solar : source_color = vec4(0.988, 0.965, 0.620, 1.0);
uniform float tamano_sol : hint_range(0.005, 0.2) = 0.052;
uniform float halo_sol : hint_range(0.01, 0.5) = 0.16;
uniform float halo_atmosferico : hint_range(0.01, 1.0) = 0.42;

group_uniforms Estrellas_Nocturnas;
uniform bool mostrar_estrellas = false;
uniform float densidad_estrellas : hint_range(5.0, 60.0) = 24.0;
uniform float brillo_estrellas : hint_range(0.0, 3.0) = 1.2;
uniform vec4 color_estrellas : source_color = vec4(0.75, 0.92, 1.0, 1.0);

// --- Funciones Matemáticas Auxiliares ---
vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453123);
}

vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)),
	         dot(p, vec3(269.5, 183.3, 246.1)),
	         dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453123);
}

// Cúmulos de nubes estilizadas basados en lóbulos redondeados continuos y luz solar direccional
float generar_nubes_cumulo_estilizadas(vec2 uv, vec3 dir_luz, float t_evol, out float luz_solar) {
	// Deformación pictórica orgánica suave (warp)
	vec2 uv_warp = uv * 0.50;
	vec2 warp = (texture(textura_ruido_nubes, uv_warp).rg - vec2(0.5)) * 0.05;
	vec2 uw = uv + warp;

	// Muestreo multi-escala isótropo
	vec2 uv_macro = uw * 0.60 + vec2(t_evol * 0.04, t_evol * 0.02);
	vec2 uv_puffs = uw * 1.50 + vec2(-t_evol * 0.03, t_evol * 0.05);
	vec2 uv_scallop = uw * 3.20 + vec2(t_evol * 0.06, -t_evol * 0.04);
	vec2 uv_wisps = uw * 6.00 + vec2(-t_evol * 0.05, t_evol * 0.03);

	float macro = texture(textura_ruido_nubes, uv_macro).r;
	float w_puffs = texture(textura_ruido_nubes, uv_puffs).g;
	float w_scallop = texture(textura_ruido_nubes, uv_scallop).b;
	float wisps = (texture(textura_ruido_nubes, uv_wisps).a - 0.5) * detalle_bordes;

	// Lóbulos redondeados (billows) y festones superiores (cauliflower scallops)
	float lobulos = pow(clamp(w_puffs * 1.30, 0.0, 1.0), 1.30);
	float festones = pow(clamp(w_scallop * 1.20, 0.0, 1.0), 1.25);
	float copos = lobulos * 0.70 + festones * 0.30;

	// Envolvente macro para definir bancos de nubes continuos con cielo abierto entre ellos
	float macro_gate = smoothstep(0.28, 0.64, macro);
	float forma = clamp(macro_gate * (0.35 + copos * 0.85) + wisps * macro_gate, 0.0, 1.0);

	// Estimación de luz direccional hacia el sol en el domo
	vec2 hacia_sol = -normalize(dir_luz.xz + vec2(0.0001)) * 0.025;
	vec2 uw_sol = (uv + hacia_sol) + warp;
	float macro_s = texture(textura_ruido_nubes, uw_sol * 0.60 + vec2(t_evol * 0.04, t_evol * 0.02)).r;
	float w_s = texture(textura_ruido_nubes, uw_sol * 1.50 + vec2(-t_evol * 0.03, t_evol * 0.05)).g;
	float forma_s = smoothstep(0.28, 0.64, macro_s) * (0.35 + pow(clamp(w_s * 1.30, 0.0, 1.0), 1.30) * 0.85);

	luz_solar = clamp((forma - forma_s) * 5.0 * 0.5 + 0.5, 0.0, 1.0);
	return forma;
}

// Estrellas sutiles 3D dispersadas para noche/fantasma
float calcular_estrellas_3d(vec3 dir, float densidad, float brillo, float t) {
	if (dir.y <= 0.08) return 0.0;
	vec3 p = dir * densidad;
	vec3 id = floor(p);
	float total_estrella = 0.0;
	
	for (int z = 0; z <= 1; z++) {
		for (int y = 0; y <= 1; y++) {
			for (int x = 0; x <= 1; x++) {
				vec3 celda = id + vec3(float(x), float(y), float(z));
				vec3 h = hash3(celda);
				
				if (h.x > 0.90 && celda.y > 0.0) {
					vec3 star_pos = normalize(celda + (h - 0.5) * 0.85);
					vec2 uv_ruido = star_pos.xz * 1.6 + vec2(0.24, 0.68);
					float ruido_dispersion = texture(textura_ruido_nubes, uv_ruido).r;
					if (ruido_dispersion < 0.54) continue;
					
					vec3 diff = dir - star_pos;
					float dist_3d = length(diff);
					float factor_variedad = smoothstep(0.54, 0.88, ruido_dispersion);
					float radio = mix(0.0010, 0.0030, h.y * factor_variedad);
					
					if (dist_3d < radio * 2.8) {
						vec3 up = abs(star_pos.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
						vec3 right = normalize(cross(up, star_pos));
						vec3 forward = cross(star_pos, right);
						
						vec2 uv_star = vec2(dot(diff, right), dot(diff, forward));
						float dist_radial = length(uv_star);
						float nucleo = smoothstep(radio, 0.0002, dist_radial);
						float destello_cruz = max(
							smoothstep(radio * 2.2, 0.0, abs(uv_star.x)) * smoothstep(radio * 0.35, 0.0, abs(uv_star.y)),
							smoothstep(radio * 2.2, 0.0, abs(uv_star.y)) * smoothstep(radio * 0.35, 0.0, abs(uv_star.x))
						) * 0.35;
						
						float twinkle = sin(t * (1.2 + h.z * 1.8) + h.x * 25.0) * 0.25 + 0.75;
						float forma = (nucleo + destello_cruz) * twinkle * (0.6 + factor_variedad * 0.4);
						total_estrella += forma;
					}
				}
			}
		}
	}
	float desvanecer_horizonte = smoothstep(0.08, 0.30, dir.y);
	return total_estrella * brillo * desvanecer_horizonte;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 color_fondo;

	// 1. Degradado del Cielo
	if (dir.y >= 0.0) {
		float h = clamp(dir.y, 0.0, 1.0);
		if (usar_cielo_tres_tonos) {
			// Fiel a la referencia Imagen 2 en el hemisferio superior (dir.y >= 0.0):
			// Baja (0.0):       rgb(254, 237, 157)
			// Media (punto):    rgb(250, 230, 144)
			// Alta (altitud):   rgb(237, 221, 162)
			if (h < punto_cielo_medio) {
				float f = smoothstep(0.0, punto_cielo_medio, h);
				color_fondo = mix(color_cielo_horizonte.rgb, color_cielo_medio.rgb, f);
			} else {
				float f = smoothstep(punto_cielo_medio, altitud_cielo_cenit, h);
				color_fondo = mix(color_cielo_medio.rgb, color_cielo_cenit.rgb, f);
			}
		} else {
			float factor_cielo = clamp(pow(1.0 - h, exponente_gradiente_cielo), 0.0, 1.0);
			color_fondo = mix(color_cielo_cenit.rgb, color_cielo_horizonte.rgb, factor_cielo);
		}
	} else {
		float factor_suelo = clamp(pow(max(0.0, -dir.y), 1.2), 0.0, 1.0);
		color_fondo = mix(color_cielo_horizonte.rgb, color_suelo_horizonte.rgb, clamp(-dir.y * 3.0, 0.0, 1.0));
		color_fondo = mix(color_fondo, color_suelo_nadir.rgb, factor_suelo);
	}

	// 2. Estrellas Estilizadas 3D (Nocturno / Fantasma)
	float destello_estrellas = 0.0;
	if (mostrar_estrellas && dir.y > 0.04) {
		destello_estrellas = calcular_estrellas_3d(dir, densidad_estrellas, brillo_estrellas, TIME);
	}

	// 3. Posición Solar / Lunar
	vec3 dir_sol = (LIGHT0_ENABLED && !usar_direccion_personalizada) ? normalize(LIGHT0_DIRECTION) : normalize(direccion_sol_personalizada);
	float dist_astro = length(dir - dir_sol);

	if (modo_luna) {
		// --- LUNA CRECIENTE ESTILIZADA ---
		float halo_lunar = smoothstep(halo_sol * 2.2, 0.0, dist_astro) * 0.18;
		color_fondo += color_halo_solar.rgb * halo_lunar;

		if (dist_astro < tamano_sol * 2.5) {
			float disco_luna = smoothstep(tamano_sol, tamano_sol * 0.88, dist_astro);
			vec3 dir_corte = normalize(dir_sol + vec3(tamano_sol * 0.48, tamano_sol * 0.34, 0.0));
			float dist_corte = length(dir - dir_corte);
			float corte_luna = smoothstep(tamano_sol * 0.94, tamano_sol * 0.76, dist_corte);
			
			float creciente = clamp(disco_luna - corte_luna, 0.0, 1.0);
			float halo_cercano = smoothstep(halo_sol * 0.55, 0.0, dist_astro) * 0.45;
			
			color_fondo += color_disco_solar.rgb * (creciente * 1.6);
			color_fondo += color_halo_solar.rgb * halo_cercano;
		}
	} else {
		// --- SOL RADIANTE DEFINIDO Y CÁLIDO (Estilo Mario Odyssey / Astrobot) ---
		if (dir.y > -0.05) {
			// Halo atmosférico dorado (mezcla suave para NO blanquear ni desaturar los tonos atardecer)
			float halo_amplio = pow(clamp(1.0 - dist_astro / max(0.001, halo_atmosferico), 0.0, 1.0), 1.8);
			color_fondo = mix(color_fondo, color_halo_solar.rgb, halo_amplio * 0.45);

			// Corona dorada cercana al sol
			float corona = pow(clamp(1.0 - dist_astro / max(0.001, halo_sol), 0.0, 1.0), 2.4);
			color_fondo = mix(color_fondo, color_halo_solar.rgb, corona * 0.75);

			// Disco solar nítido, circular y brillante (núcleo marfil cálido solicitado)
			float disco = 1.0 - smoothstep(tamano_sol * 0.94, tamano_sol, dist_astro);
			color_fondo = mix(color_fondo, color_disco_solar.rgb, disco);
		}
	}

	// 4. Cúmulos de Nubes Volumétricos Isótropos (Horizontales y Laterales)
	if (dir.y > 0.005) {
		// Proyección Esférica Equirectangular Isótropa Seamless (360 grados sin costuras ni distorsión)
		float azim = atan(dir.z, dir.x); // [-PI, PI]
		float elev = asin(clamp(dir.y, 0.0, 1.0)); // [0, PI/2]

		float u_base = (azim / (2.0 * PI) + 0.5) * repeticiones_horizontales;
		float v_base = (elev / (2.0 * PI)) * repeticiones_horizontales * escala_vertical + 0.08;

		vec2 dir_viento_norm = length(direccion_viento) > 0.001 ? normalize(direccion_viento) : vec2(1.0, 0.0);
		float t_viento = TIME * velocidad_viento * 0.02;
		float t_evol = TIME * velocidad_evolucion * 0.02;

		vec2 uv_nube = (vec2(u_base, v_base) - dir_viento_norm * t_viento) * escala_nubes;

		float umbral_densidad = 1.0 - cobertura_nubes;

		// Envolvente de altitud: nubes se desarrollan majestuosas en el cielo medio y superior
		float env_bottom = smoothstep(altitud_minima, altitud_minima + 0.10, dir.y);
		float env_top = smoothstep(altitud_maxima, altitud_maxima - 0.15, dir.y);
		float envolvente_altitud = env_bottom * env_top;

		float luz_sol = 0.5;
		float forma = generar_nubes_cumulo_estilizadas(uv_nube, dir_sol, t_evol, luz_sol);

		// Las nubes se componen por encima del disco y del halo solar.
		float mascara = smoothstep(umbral_densidad - nitidez_borde, umbral_densidad + nitidez_borde, forma) * envolvente_altitud;

		if (destello_estrellas > 0.001) {
			color_fondo += color_estrellas.rgb * (destello_estrellas * (1.0 - mascara * 0.95));
		}

		if (mascara > 0.001) {
			float vol = clamp((forma - umbral_densidad) / max(0.001, 1.0 - umbral_densidad), 0.0, 1.0);
			float rim_sol = clamp(1.0 - dist_astro / max(0.001, halo_atmosferico), 0.0, 1.0);
			float factor_sombreado = vol * 0.38 + luz_sol * 0.42 + rim_sol * 0.20;

			vec3 col;
			if (modo_nubes_suaves) {
				// Transiciones amplias para nubes pictóricas, sin bandas cel-shaded duras.
				float sombra_a_medio = smoothstep(corte_sombra - 0.18, corte_sombra + 0.25, factor_sombreado);
				float medio_a_luz = smoothstep(corte_luz - 0.16, corte_cresta + 0.15, factor_sombreado);
				col = mix(color_nube_sombra.rgb, color_nube_medio.rgb, sombra_a_medio);
				col = mix(col, color_nube_luz.rgb, medio_a_luz);
			} else {
				float paso_sombra = smoothstep(corte_sombra - nitidez_cel, corte_sombra + nitidez_cel, factor_sombreado);
				float paso_luz    = smoothstep(corte_luz - nitidez_cel, corte_luz + nitidez_cel, factor_sombreado);
				float paso_cresta = smoothstep(corte_cresta - nitidez_cel, corte_cresta + nitidez_cel, factor_sombreado);
				col = mix(color_nube_sombra.rgb, color_nube_medio.rgb, paso_sombra);
				col = mix(col, color_nube_luz.rgb, paso_luz);
				col = mix(col, color_nube_luz.rgb * 1.02, paso_cresta);
			}

			// Rim solar dorado suave en bordes cercanos al sol
			float rim = rim_sol * (1.0 - vol) * fuerza_rim_solar;
			col += color_borde_solar.rgb * rim;

			color_fondo = mix(color_fondo, col, mascara * opacidad_nubes);
		}

	} else if (destello_estrellas > 0.001) {
		color_fondo += color_estrellas.rgb * destello_estrellas;
	}

	COLOR = color_fondo;
}
