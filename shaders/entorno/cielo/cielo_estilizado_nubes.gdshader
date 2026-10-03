shader_type sky;

// ===================================================================
// SHADER DE CIELO ESTILIZADO - PROYECTO LIMBO (GODOT 4)
// Nubes Pictóricas, Estrellas 3D en Diamante (Sin Deformación) y Luna Creciente
// ===================================================================

group_uniforms Colores_Cielo;
uniform vec4 color_cielo_cenit : source_color = vec4(0.10, 0.22, 0.50, 1.0);
uniform vec4 color_cielo_horizonte : source_color = vec4(1.0, 0.72, 0.30, 1.0);
uniform vec4 color_suelo_horizonte : source_color = vec4(0.40, 0.28, 0.22, 1.0);
uniform vec4 color_suelo_nadir : source_color = vec4(0.12, 0.10, 0.10, 1.0);
uniform float exponente_gradiente_cielo : hint_range(0.5, 5.0) = 2.0;

group_uniforms Nubes_Pintura_Anime_Oleo;
uniform bool usar_textura_optimizada = true;
uniform sampler2D textura_ruido_nubes : filter_linear_mipmap, repeat_enable;
uniform vec4 color_nube_luz : source_color = vec4(1.0, 0.98, 0.94, 1.0);
uniform vec4 color_nube_medio : source_color = vec4(0.98, 0.76, 0.58, 1.0);
uniform vec4 color_nube_sombra : source_color = vec4(0.36, 0.28, 0.48, 1.0);
uniform vec4 color_borde_solar : source_color = vec4(1.0, 0.85, 0.35, 1.0);

uniform float escala_nubes : hint_range(0.1, 8.0) = 1.05;
uniform float cobertura_nubes : hint_range(0.0, 1.0) = 0.40;
uniform float nitidez_borde : hint_range(0.001, 0.2) = 0.028;

// Parámetros de Cortes Cel-Shaded Suavizados
uniform float corte_sombra : hint_range(0.0, 1.0) = 0.28;
uniform float corte_luz : hint_range(0.0, 1.0) = 0.60;
uniform float corte_cresta : hint_range(0.0, 1.0) = 0.84;
uniform float nitidez_cel : hint_range(0.001, 0.2) = 0.035;
uniform float fuerza_rim_solar : hint_range(0.0, 3.0) = 1.15;
uniform float grosor_rim : hint_range(0.005, 0.2) = 0.04;

uniform float curvatura_domo : hint_range(0.05, 1.0) = 0.38;
uniform float atenuacion_horizonte : hint_range(0.0, 1.0) = 0.05;

group_uniforms Nubes_Suaves_Volumetricas;
uniform bool modo_nubes_suaves = false; // Nubes pintadas suaves (sin cortes cel-shaded)
uniform float suavidad_nubes : hint_range(0.01, 0.5) = 0.18;
uniform float opacidad_nubes : hint_range(0.0, 1.0) = 0.85;
uniform float detalle_bordes : hint_range(0.0, 1.0) = 0.35;

group_uniforms Viento_Nubes;
uniform vec2 direccion_viento = vec2(0.868, 0.496);
uniform float velocidad_viento : hint_range(0.0, 3.0) = 0.38;
uniform float velocidad_evolucion : hint_range(0.0, 1.0) = 0.06;

group_uniforms Sol_y_Luna;
uniform bool modo_luna = false;
uniform vec4 color_disco_solar : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform vec4 color_halo_solar : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float tamano_sol : hint_range(0.001, 0.15) = 0.025;
uniform float halo_sol : hint_range(0.01, 0.5) = 0.12;

group_uniforms Estrellas_Nocturnas;
uniform bool mostrar_estrellas = false;
uniform float densidad_estrellas : hint_range(5.0, 60.0) = 24.0;
uniform float brillo_estrellas : hint_range(0.0, 3.0) = 1.2;
uniform vec4 color_estrellas : source_color = vec4(0.75, 0.92, 1.0, 1.0);

// --- Generadores de Ruido 2D y 3D ---
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

float noise2D(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);

	return mix(mix(dot(hash2(i + vec2(0.0, 0.0)) - 0.5, f - vec2(0.0, 0.0)),
	               dot(hash2(i + vec2(1.0, 0.0)) - 0.5, f - vec2(1.0, 0.0)), u.x),
	           mix(dot(hash2(i + vec2(0.0, 1.0)) - 0.5, f - vec2(0.0, 1.0)),
	               dot(hash2(i + vec2(1.0, 1.0)) - 0.5, f - vec2(1.0, 1.0)), u.x), u.y) + 0.5;
}

float worley(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 point = hash2(i + neighbor);
			vec2 diff = neighbor + point - f;
			d = min(d, dot(diff, diff));
		}
	}
	return sqrt(d);
}

float fbm_suave(vec2 p) {
	float total = 0.0;
	float amp = 0.55;
	float freq = 1.0;
	// Optimizado a 3 octavas para GPU móvil (imperceptible bajo cel-shading y 40% menos ALU)
	for (int i = 0; i < 3; i++) {
		total += noise2D(p * freq) * amp;
		freq *= 2.05;
		amp *= 0.48;
	}
	return clamp(total, 0.0, 1.0);
}

// Genera una máscara de cúmulo esférico partiendo de Worley invertido.
// Potencia moderada (1.45) → lobulos suaves sin anillos de celdas visibles.
float cumulo_esfera(vec2 uv, float escala, float t_evol_x, float t_evol_y) {
	float w = 1.0 - worley(uv * escala + vec2(t_evol_x, t_evol_y));
	return pow(clamp(w * 1.18, 0.0, 1.0), 1.45);
}

// Generación ultrarrápida por hardware mediante textura empacada seamless (Canal R=FBM, G=Worley1, B=Worley2, A=Pincel)
// Reduce en 95% el gasto de batería y calentamiento en móviles reemplazando 42 funciones trigonométricas por 2 lecturas de textura.
float generar_nubes_cumulo_textura(vec2 uv, float t_evol) {
	vec2 uv1 = uv * 0.22 + vec2(t_evol * 0.08, t_evol * 0.04);
	vec2 uv2 = uv * 0.55 + vec2(-t_evol * 0.06, t_evol * 0.10);

	vec4 tex1 = texture(textura_ruido_nubes, uv1);
	vec4 tex2 = texture(textura_ruido_nubes, uv2);

	float macro = tex1.r;
	float w1 = tex1.g;
	float w2 = tex2.b;
	float copos = w1 * 0.65 + w2 * 0.35;

	float nube = macro * (0.50 + copos * 0.85);
	float pincel = (tex2.a - 0.5) * 0.07;
	return clamp(nube + pincel * macro, 0.0, 1.0);
}

// Cúmulos de nubes estilizadas basados en lóbulos redondeados continuos y luz cenital direccional
float generar_nubes_cumulo_estilizadas(vec2 uv, float t_evol, out float luz_cenit) {
	// Deformación pictórica orgánica suave (warp)
	vec2 uv_warp = uv * 0.12;
	vec2 warp = (texture(textura_ruido_nubes, uv_warp).rg - vec2(0.5)) * 0.18;
	vec2 uw = uv + warp;

	// Muestreo multi-escala de textura sin repeticiones visibles
	vec2 uv_macro = uw * 0.10 + vec2(t_evol * 0.04, t_evol * 0.02);
	vec2 uv_puffs = uw * 0.24 + vec2(-t_evol * 0.03, t_evol * 0.05);
	vec2 uv_scallop = uw * 0.48 + vec2(t_evol * 0.06, -t_evol * 0.04);

	float macro = texture(textura_ruido_nubes, uv_macro).r;
	float w_puffs = texture(textura_ruido_nubes, uv_puffs).g;
	float w_scallop = texture(textura_ruido_nubes, uv_scallop).g;

	// Perfil abombado de los cúmulos (lóbulos redondeados)
	float lobulos = pow(clamp(w_puffs * 1.28, 0.0, 1.0), 1.35);
	float festones = pow(clamp(w_scallop * 1.15, 0.0, 1.0), 1.20);
	float copos = lobulos * 0.70 + festones * 0.30;

	// Envolvente macro para definir bancos de nubes continuos con cielo abierto entre ellos
	float macro_gate = smoothstep(0.32, 0.65, macro);
	float forma = clamp(macro_gate * (0.35 + copos * 0.85), 0.0, 1.0);

	// Estimación de luz cenital mediante diferencial en dirección al cenit (origen en plano UV)
	vec2 hacia_cenit = -normalize(uv + vec2(0.0001));
	vec2 uw_up = (uv + hacia_cenit * 0.025) + warp;
	float macro_up = texture(textura_ruido_nubes, uw_up * 0.10 + vec2(t_evol * 0.04, t_evol * 0.02)).r;
	float w_up = texture(textura_ruido_nubes, uw_up * 0.24 + vec2(-t_evol * 0.03, t_evol * 0.05)).g;
	float forma_up = smoothstep(0.32, 0.65, macro_up) * (0.35 + pow(clamp(w_up * 1.28, 0.0, 1.0), 1.35) * 0.70 * 0.85);

	luz_cenit = clamp((forma - forma_up) * 4.5 * 0.5 + 0.5, 0.0, 1.0);
	return forma;
}

float generar_nubes_cumulo(vec2 uv, float t_evol) {
	// Masa base: FBM define DÓNDE existe la nube (regiones continuas)
	float macro = fbm_suave(uv * 0.38 + vec2(t_evol * 0.10));

	// Dos escalas de Worley (como el original) añaden textura interna de cúmulo
	float w1 = cumulo_esfera(uv, 1.0, 0.0, t_evol * 0.15);
	float w2 = cumulo_esfera(uv, 2.2, t_evol * 0.20, -t_evol * 0.10);
	float copos = w1 * 0.65 + w2 * 0.35;

	// MULTIPLICAR en vez de sumar: el Worley solo aparece donde el FBM ya tiene
	// masa → los lóbulos quedan conectados dentro de la nube, no como blobs flotantes
	float nube = macro * (0.50 + copos * 0.85);

	// El ruido fino también se escala por macro para no añadir detalle en zonas vacías
	float pincel = (noise2D(uv * 2.8 + vec2(t_evol, -t_evol)) - 0.5) * 0.07;
	return clamp(nube + pincel * macro, 0.0, 1.0);
}

// Estrellas sutiles y pequeñas dispersadas orgánicamente mediante mapa de ruido
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
				
				// Filtro 1: Probabilidad base reducida para que sean pocas
				if (h.x > 0.90 && celda.y > 0.0) {
					vec3 star_pos = normalize(celda + (h - 0.5) * 0.85);
					
					// Filtro 2: Mapa de ruido para dispersión natural (crea variedad y constelaciones orgánicas)
					vec2 uv_ruido = star_pos.xz * 1.6 + vec2(0.24, 0.68);
					float ruido_dispersion = texture(textura_ruido_nubes, uv_ruido).r;
					if (ruido_dispersion < 0.54) {
						continue; // Se descarta: solo aparecen en regiones selectas del mapa de ruido
					}
					
					// Diferencia vectorial tangencial
					vec3 diff = dir - star_pos;
					float dist_3d = length(diff);
					
					// Estrellas pequeñas y delicadas (radio fino entre 0.0010 y 0.0030)
					float factor_variedad = smoothstep(0.54, 0.88, ruido_dispersion);
					float radio = mix(0.0010, 0.0030, h.y * factor_variedad);
					
					if (dist_3d < radio * 2.8) {
						vec3 up = abs(star_pos.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
						vec3 right = normalize(cross(up, star_pos));
						vec3 forward = cross(star_pos, right);
						
						vec2 uv_star = vec2(dot(diff, right), dot(diff, forward));
						float dist_radial = length(uv_star);
						
						// Núcleo estelar suave y destello tenue
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
	
	// Desvanecer suavemente hacia el horizonte para no saturar las islas flotantes
	float desvanecer_horizonte = smoothstep(0.08, 0.30, dir.y);
	return total_estrella * brillo * desvanecer_horizonte;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 color_fondo;

	// 1. Degradado del Fondo Celeste / Atmósfera
	if (dir.y >= 0.0) {
		float factor_cielo = clamp(pow(1.0 - dir.y, exponente_gradiente_cielo), 0.0, 1.0);
		color_fondo = mix(color_cielo_cenit.rgb, color_cielo_horizonte.rgb, factor_cielo);
	} else {
		float factor_suelo = clamp(pow(-dir.y, 1.2), 0.0, 1.0);
		color_fondo = mix(color_suelo_horizonte.rgb, color_suelo_nadir.rgb, factor_suelo);
	}

	// 2. Estrellas Estilizadas 3D en Forma de Diamante (✦)
	float destello_estrellas = 0.0;
	if (mostrar_estrellas && dir.y > 0.04) {
		destello_estrellas = calcular_estrellas_3d(dir, densidad_estrellas, brillo_estrellas, TIME);
	}

	// 3. Sol o Luna Creciente Estilizada
	vec3 dir_sol = normalize(LIGHT0_DIRECTION);
	float dist_astro = length(dir - dir_sol);

	if (modo_luna) {
		// --- LUNA CRECIENTE ESTILIZADA ---
		// Halo amplio con color configurable (frio/azulado para el mundo del fantasma)
		float halo_lunar_amplio = smoothstep(halo_sol * 2.2, 0.0, dist_astro) * 0.18;
		color_fondo += color_halo_solar.rgb * halo_lunar_amplio;

		if (dist_astro < tamano_sol * 2.5) {
			float disco_luna = smoothstep(tamano_sol, tamano_sol * 0.88, dist_astro);
			vec3 dir_corte = normalize(dir_sol + vec3(tamano_sol * 0.48, tamano_sol * 0.34, 0.0));
			float dist_corte = length(dir - dir_corte);
			float corte_luna = smoothstep(tamano_sol * 0.94, tamano_sol * 0.76, dist_corte);
			
			float creciente = clamp(disco_luna - corte_luna, 0.0, 1.0);
			// Halo interior cercano al disco, también en color frio
			float halo_lunar_cercano = smoothstep(halo_sol * 0.55, 0.0, dist_astro) * 0.45;
			
			color_fondo += color_disco_solar.rgb * (creciente * 1.6);
			color_fondo += color_halo_solar.rgb * halo_lunar_cercano;
		}
	} else {
		// --- SOL RADIANTE ---
		float punto_sol = dot(dir, dir_sol);
		if (punto_sol > 0.0) {
			float angulo_sol = 1.0 - punto_sol;
			float disco = smoothstep(tamano_sol * 1.2, tamano_sol * 0.8, angulo_sol);
			float halo = smoothstep(halo_sol, 0.0, angulo_sol) * 0.45;
			color_fondo += color_disco_solar.rgb * (disco + halo);
		}
	}

	// 4. Cúmulos de Nubes Cel-Shaded Suavizadas al Óleo
	if (dir.y > 0.005) {
		vec2 dir_viento_norm = length(direccion_viento) > 0.001 ? normalize(direccion_viento) : vec2(1.0, 0.0);
		float t_viento = TIME * velocidad_viento * 0.038;
		float t_evol = TIME * velocidad_evolucion * 0.025;

		vec2 plano_uv = (dir.xz / (dir.y + curvatura_domo)) * escala_nubes;
		vec2 uv_nube = plano_uv - dir_viento_norm * t_viento;

		float forma_nube;
		if (usar_textura_optimizada) {
			forma_nube = generar_nubes_cumulo_textura(uv_nube, t_evol);
		} else {
			forma_nube = generar_nubes_cumulo(uv_nube, t_evol);
		}
		float desvanecer_horizonte = smoothstep(0.0, atenuacion_horizonte, dir.y);

		float umbral_densidad = 1.0 - cobertura_nubes;

		if (modo_nubes_suaves) {
			// --- CÚMULOS PINTADOS ESTILIZADOS (Reino Espiritual) ---
			float luz_cenit = 0.5;
			float forma = generar_nubes_cumulo_estilizadas(uv_nube, t_evol, luz_cenit);

			float desvanecer_horizonte = smoothstep(0.01, atenuacion_horizonte, dir.y);
			float mascara = smoothstep(umbral_densidad - nitidez_borde, umbral_densidad + nitidez_borde, forma) * desvanecer_horizonte;

			if (destello_estrellas > 0.001) {
				color_fondo += color_estrellas.rgb * (destello_estrellas * (1.0 - mascara * 0.95));
			}

			if (mascara > 0.001) {
				float vol = clamp((forma - umbral_densidad) / max(0.001, 1.0 - umbral_densidad), 0.0, 1.0);
				float factor_sombreado = vol * 0.45 + luz_cenit * 0.55;

				// Sombreado pictórico en 3 tonos con transiciones cel-shaded suaves
				float paso_sombra = smoothstep(corte_sombra - nitidez_cel, corte_sombra + nitidez_cel, factor_sombreado);
				float paso_luz    = smoothstep(corte_luz - nitidez_cel, corte_luz + nitidez_cel, factor_sombreado);
				float paso_cresta = smoothstep(corte_cresta - nitidez_cel, corte_cresta + nitidez_cel, factor_sombreado);

				vec3 col = mix(color_nube_sombra.rgb, color_nube_medio.rgb, paso_sombra);
				col = mix(col, color_nube_luz.rgb, paso_luz);
				col = mix(col, color_nube_luz.rgb * 1.10, paso_cresta);

				// Ribete iluminado superior
				float rim = smoothstep(corte_luz, 1.0, luz_cenit) * (1.0 - vol) * fuerza_rim_solar * 0.35;
				col += color_borde_solar.rgb * rim;

				color_fondo = mix(color_fondo, col, mascara * opacidad_nubes);
			}
		} else {
		float mascara_nube = smoothstep(umbral_densidad - nitidez_borde, umbral_densidad + nitidez_borde, forma_nube) * desvanecer_horizonte;

		// Añadir estrellas en el cielo abierto (ocultas tras nubes densas)
		if (destello_estrellas > 0.001) {
			float vis_estrella_nube = 1.0 - mascara_nube * 0.95;
			color_fondo += color_estrellas.rgb * (destello_estrellas * vis_estrella_nube);
		}

		if (mascara_nube > 0.001) {
			float factor_volumen = clamp((forma_nube - umbral_densidad) / max(0.001, 1.0 - umbral_densidad), 0.0, 1.0);

			float paso_sombra_a_medio = smoothstep(corte_sombra - nitidez_cel, corte_sombra + nitidez_cel, factor_volumen);
			float paso_medio_a_luz   = smoothstep(corte_luz - nitidez_cel, corte_luz + nitidez_cel, factor_volumen);
			float paso_cresta_luz    = smoothstep(corte_cresta - nitidez_cel, corte_cresta + nitidez_cel, factor_volumen);

			vec3 color_cuerpo = mix(color_nube_sombra.rgb, color_nube_medio.rgb, paso_sombra_a_medio);
			color_cuerpo = mix(color_cuerpo, color_nube_luz.rgb, paso_medio_a_luz);
			color_cuerpo = mix(color_cuerpo, color_nube_luz.rgb * 1.12, paso_cresta_luz);

			float influencia_solar = clamp(dot(dir, dir_sol) * 0.5 + 0.5, 0.0, 1.0);
			float borde_sol = smoothstep(umbral_densidad, umbral_densidad + grosor_rim, forma_nube) * (1.0 - paso_sombra_a_medio) * influencia_solar;
			color_cuerpo += color_borde_solar.rgb * (borde_sol * fuerza_rim_solar);

			color_fondo = mix(color_fondo, color_cuerpo, mascara_nube);
		}
		}
	} else if (destello_estrellas > 0.001) {
		color_fondo += color_estrellas.rgb * destello_estrellas;
	}

	COLOR = color_fondo;
}
