shader_type spatial;
// Se mantienen las dos caras para que la rotación no abra una costura visual.
// La cara posterior se descarta en fragmento, antes de sumar transparencia.
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

// ===================================================================
// SHADER DE TORBELLINO ESPIRITUAL (PROYECTO LIMBO)
// Fiel a la referencia estética (media_1791003723838.jpg):
// - Modo 'unshaded' para que el sol no lave ni queme los tonos azules.
// - Cono con silueta de trompeta estilizada y esbelta.
// - Cuerpo etéreo translúcido en azul zafiro y cyan profundo.
// - Cintas helicoidales de viento luminoso en cyan eléctrico y blanco.
// - Resplandor de contacto en la base y corona suave en la cima.
// - Transparente para ver el interior (fantasma, cristales, hojas).
// ===================================================================

group_uniforms Dimensiones_Embudo;
uniform float radio_base = 0.45;
uniform float radio_cima = 3.2;
uniform float altura_cono = 5.7;

group_uniforms Colores_Cuerpo;
// Paleta canónica del Fantasma en azules celestes intensificados:
uniform vec4 color_profundo : source_color = vec4(0.08, 0.50, 0.86, 0.32);
uniform vec4 color_medio : source_color = vec4(0.18, 0.68, 0.96, 0.26);
uniform vec4 color_cima : source_color = vec4(0.35, 0.82, 1.00, 0.22);

group_uniforms Bandas_Espirales;
uniform vec4 color_cinta_nucleo : source_color = vec4(0.40, 0.88, 1.0, 1.0); // Celeste luminoso
uniform vec4 color_cinta_halo : source_color = vec4(0.22, 0.78, 1.0, 1.0);   // Cyan celeste vibrante
uniform float cantidad_cintas : hint_range(1.0, 4.0) = 1.0;
uniform float torsion_espiral : hint_range(1.0, 28.0) = 21.0;
uniform float velocidad_giro : hint_range(0.0, 10.0) = 2.4;
uniform float ancho_cintas : hint_range(0.05, 0.5) = 0.20;
uniform float suavidad_cintas : hint_range(0.02, 0.4) = 0.16;
uniform float ancho_halo_cintas : hint_range(0.05, 0.5) = 0.30;
uniform float difuminado_halo : hint_range(0.02, 0.4) = 0.26;
uniform vec4 color_cinta_secundaria : source_color = vec4(0.26, 0.80, 1.0, 1.0);
uniform vec4 color_cinta_acento : source_color = vec4(0.44, 0.90, 1.0, 1.0);
uniform float ancho_cinta_secundaria : hint_range(0.03, 0.4) = 0.13;
uniform float ancho_cinta_acento : hint_range(0.02, 0.3) = 0.075;
uniform vec4 color_zona_clara : source_color = vec4(0.82, 1.0, 1.0, 1.0);
uniform float brillo_zonas_claras : hint_range(1.0, 3.0) = 1.5;
uniform float intensidad_zonas_claras : hint_range(0.0, 2.0) = 1.0;
uniform float peso_base_claro : hint_range(0.0, 1.0) = 0.15;

group_uniforms Borde_del_Cono;
uniform vec4 color_borde_filo : source_color = vec4(0.75, 0.94, 1.0, 1.0); // Azul blanco luminoso (#C0F0FF)
uniform vec4 color_borde_halo : source_color = vec4(0.24, 0.78, 1.0, 1.0); // Azul celeste vibrante
uniform float ancho_borde : hint_range(0.05, 0.8) = 0.42;
uniform float nitidez_filo : hint_range(0.05, 0.6) = 0.25;
uniform float intensidad_borde : hint_range(0.5, 3.0) = 1.45;
uniform float brillo_filo : hint_range(1.0, 2.5) = 1.15;
uniform float brillo_glow_borde : hint_range(0.0, 3.0) = 1.35;

group_uniforms Brillo_y_Resplandor;
uniform float fuerza_fresnel : hint_range(0.0, 3.0) = 1.1;
uniform float exponente_fresnel : hint_range(0.5, 4.0) = 2.6;
uniform float brillo_cintas : hint_range(1.0, 4.0) = 1.05;
uniform float brillo_base : hint_range(1.0, 4.0) = 1.35;
uniform float opacidad_general : hint_range(0.0, 1.0) = 0.75;
uniform float intensidad_glow_cintas : hint_range(0.0, 4.0) = 1.8;
uniform float intensidad_glow_cuerpo : hint_range(0.0, 2.0) = 0.45;
uniform float limite_brillo : hint_range(0.3, 2.0) = 0.8;
uniform float atenuacion_cara_posterior : hint_range(0.0, 1.0) = 0.35;
uniform float amplitud_irregularidad : hint_range(0.0, 0.4) = 0.14;
uniform float velocidad_irregularidad : hint_range(0.0, 5.0) = 1.25;

group_uniforms Forma_y_Difuminado;
uniform float curvatura_trompeta : hint_range(0.0, 1.0) = 0.55;
uniform float amplitud_ondulacion : hint_range(0.0, 0.4) = 0.16;
uniform float frecuencia_ondulacion : hint_range(2.0, 20.0) = 8.0;
uniform float velocidad_ondulacion : hint_range(0.0, 5.0) = 1.6;
uniform float difuminado_cima : hint_range(0.05, 0.5) = 0.28;
uniform float difuminado_silueta : hint_range(0.0, 1.0) = 0.60;
uniform float irregularidad_borde : hint_range(0.0, 0.5) = 0.16;

varying float v_height;
varying vec2 v_uv;

void vertex() {
	// Normalizar altura de 0.0 (base) a 1.0 (cima)
	v_height = clamp((VERTEX.y + (altura_cono * 0.5)) / altura_cono, 0.0, 1.0);
	v_uv = UV;

	// 1. Curvatura de trompeta estilizada (elimina la línea recta cónica rígida):
	float t_curva = mix(v_height, pow(v_height, 2.0), curvatura_trompeta);
	float r_teorico_recto = mix(radio_base, radio_cima, v_height);
	float r_curvado = mix(radio_base, radio_cima, t_curva);
	float factor_trompeta = r_curvado / max(0.001, r_teorico_recto);
	VERTEX.xz *= factor_trompeta;

	// 2. Ondulaciones de volumen helicoidales (capas/anillos de viento en relieve):
	float angulo = atan(VERTEX.z, VERTEX.x);
	float peso_efecto = smoothstep(0.06, 0.35, v_height);
	float fase_espiral = (v_height * frecuencia_ondulacion) - (TIME * velocidad_ondulacion * 2.0) + (angulo * 2.0);
	float onda_relieve = (sin(fase_espiral) * 0.7 + sin(fase_espiral * 2.2 + 1.2) * 0.3) * amplitud_ondulacion * peso_efecto;
	VERTEX.xz *= (1.0 + onda_relieve);

	// 3. Meceo orgánico global de la columna de viento:
	float peso_irregularidad = smoothstep(0.08, 0.95, v_height);
	float onda_a = sin(TIME * velocidad_irregularidad + v_height * 7.0);
	float onda_b = cos(TIME * (velocidad_irregularidad * 1.37) - v_height * 11.0);
	VERTEX.x += onda_a * amplitud_irregularidad * peso_irregularidad;
	VERTEX.z += onda_b * amplitud_irregularidad * 0.72 * peso_irregularidad;

	// 4. Ondulación suave de altura en la cima (la boca superior no es plana ni cortada en horizontal):
	float onda_cima_v = sin(angulo * 3.0 + TIME * velocidad_ondulacion) * 0.12 * smoothstep(0.7, 1.0, v_height);
	VERTEX.y += onda_cima_v;
}

void fragment() {
	// La parte posterior se atenúa para no saturar el volumen ni sobreexponer a blanco
	float intensidad_cara = FRONT_FACING ? 1.0 : atenuacion_cara_posterior;

	vec3 n = NORMAL;
	if (!FRONT_FACING) {
		n = -n;
	}

	// 1. Degradado espectral vertical: azul profundo en base -> azul vibrante -> celeste en cima
	vec3 col_cuerpo = mix(color_profundo.rgb, color_medio.rgb, smoothstep(0.05, 0.55, v_height));
	col_cuerpo = mix(col_cuerpo, color_cima.rgb, smoothstep(0.48, 0.95, v_height));

	// 2. Cintas espirales de viento ascendente
	float espiral_1 = sin((v_uv.x * 6.28318 * cantidad_cintas) + (v_height * torsion_espiral) - (TIME * velocidad_giro * 2.2));
	float umbral_1 = 1.0 - ancho_cintas;
	float nucleo_1 = smoothstep(umbral_1 - suavidad_cintas, umbral_1, espiral_1);
	float halo_1 = smoothstep((umbral_1 - ancho_halo_cintas) - difuminado_halo, umbral_1 - ancho_halo_cintas, espiral_1);

	// Corrientes adicionales periódicas en UV.x para cerrar sin costura
	float fase_secundaria = (v_uv.x * 6.28318 * cantidad_cintas * 2.0) + (v_height * torsion_espiral * 0.76) - (TIME * velocidad_giro * 1.45);
	float espiral_secundaria = sin(fase_secundaria + 1.8);
	float umbral_secundaria = 1.0 - ancho_cinta_secundaria;
	float nucleo_secundario = smoothstep(umbral_secundaria - 0.13, umbral_secundaria, espiral_secundaria);
	float halo_secundario = smoothstep((umbral_secundaria - 0.24) - 0.20, umbral_secundaria - 0.24, espiral_secundaria);

	float fase_acento = (v_uv.x * 6.28318 * cantidad_cintas * 3.0) + (v_height * torsion_espiral * 0.56) - (TIME * velocidad_giro * 0.82);
	float espiral_acento = sin(fase_acento - 0.65);
	float umbral_acento = 1.0 - ancho_cinta_acento;
	float nucleo_acento = smoothstep(umbral_acento - 0.09, umbral_acento, espiral_acento);
	float halo_acento = smoothstep((umbral_acento - 0.16) - 0.16, umbral_acento - 0.16, espiral_acento);

	vec3 col_nucleo = color_cinta_nucleo.rgb * brillo_cintas;
	vec3 col_halo = color_cinta_halo.rgb;

	// 3. Resplandor Fresnel y Borde del Cono (Filo Azul Blanco + Halo Celeste)
	float dot_nv = clamp(dot(n, VIEW), 0.0, 1.0);
	float borde_vista = 1.0 - dot_nv;

	// Peso por altura: cerca de la base el borde/zonas claras se reducen para no perder la forma
	float peso_altura = mix(peso_base_claro, 1.0, smoothstep(0.08, 0.7, v_height));

	// Irregularidad orgánica en el borde para que no sea una línea rígida de vector:
	float ruido_borde = sin((v_height * 14.0) - (TIME * velocidad_giro * 2.5) + (v_uv.x * 18.0)) * irregularidad_borde;
	float borde_organico = clamp(borde_vista + (ruido_borde * peso_altura), 0.0, 1.0);

	float fresnel = pow(borde_organico, exponente_fresnel) * fuerza_fresnel * intensidad_cara;

	// Borde del cono difuminado: Halo envolvente celeste y filo exterior suave
	float halo_borde = smoothstep(1.0 - ancho_borde, 1.0, borde_organico) * peso_altura;
	float filo_borde = smoothstep(1.0 - (ancho_borde * nitidez_filo), 1.0, borde_organico) * peso_altura;
	float borde_total = halo_borde * intensidad_borde * intensidad_cara;
	float filo_total = filo_borde * intensidad_borde * intensidad_cara;

	vec3 col_filo_borde = color_borde_filo.rgb * brillo_filo;

	float nucleo_visible = nucleo_1 * intensidad_cara;
	float halo_visible = halo_1 * intensidad_cara;
	float nucleo_secundario_visible = nucleo_secundario * intensidad_cara;
	float halo_secundario_visible = halo_secundario * intensidad_cara;
	float nucleo_acento_visible = nucleo_acento * intensidad_cara;
	float halo_acento_visible = halo_acento * intensidad_cara;

	// 4. Contacto brillante en el suelo y difuminado vaporoso de la cima
	float contacto_base = (1.0 - smoothstep(0.0, 0.15, v_height)) * (brillo_base - 1.0) * intensidad_cara;
	
	// Desvanecimiento suave en la base y disolución vaporosa en la cima:
	float fade_base = smoothstep(0.008, 0.09, v_height);
	float onda_fade_cima = sin((v_uv.x * 6.28318 * 3.0) + TIME * 1.5) * 0.05;
	float umbral_cima = clamp(1.0 - difuminado_cima + onda_fade_cima, 0.5, 0.95);
	float fade_cima = 1.0 - smoothstep(umbral_cima, 1.0, v_height);
	float fade_extremos = fade_base * fade_cima;

	// Suavizar la transición extrema del borde para difuminarlo con el aire exterior:
	float feather_silueta = 1.0 - (smoothstep(0.92, 1.0, borde_vista) * difuminado_silueta);

	float corona_cima = smoothstep(umbral_cima - 0.1, umbral_cima + 0.04, v_height) * (1.0 - smoothstep(0.96, 1.0, v_height));

	// 5. Mezcla de color en capas espirituales celestes con borde del cono azul blanco
	vec3 color_final = col_cuerpo;

	// Corriente principal: halo celeste y núcleo celeste brillante
	color_final = mix(color_final, col_halo, halo_visible * 0.45);
	color_final = mix(color_final, col_nucleo, nucleo_visible * 0.45);

	// Corriente secundaria: bandas intermedias celestes
	color_final = mix(color_final, color_cinta_secundaria.rgb, halo_secundario_visible * 0.30);
	color_final = mix(color_final, color_cinta_secundaria.rgb, nucleo_secundario_visible * 0.35);

	// Corriente de acento: filamentos celestes luminosos
	color_final = mix(color_final, color_cinta_acento.rgb, halo_acento_visible * 0.25);
	color_final = mix(color_final, color_cinta_acento.rgb, nucleo_acento_visible * 0.30);

	// Zonas claras tirando a blanco (brillo > 1 para que lleguen casi a blanco)
	vec3 col_zona_clara = color_zona_clara.rgb * brillo_zonas_claras;
	float k_clara = intensidad_zonas_claras * peso_altura;
	color_final = mix(color_final, col_zona_clara, halo_visible * 0.18 * k_clara);
	color_final = mix(color_final, col_zona_clara, nucleo_visible * 0.45 * k_clara);
	color_final = mix(color_final, col_zona_clara, nucleo_secundario_visible * 0.35 * k_clara);
	color_final = mix(color_final, col_zona_clara, nucleo_acento_visible * 0.85 * k_clara);

	// Borde del cono prominente: Halo celeste envolvente y filo suave azul blanco
	color_final = mix(color_final, color_borde_halo.rgb, clamp(borde_total * 0.75, 0.0, 1.0));
	color_final = mix(color_final, col_filo_borde, clamp(filo_total * 0.75, 0.0, 1.0));

	// Resplandor azul blanco en la base de contacto
	color_final = mix(color_final, col_filo_borde, clamp(contacto_base * 0.90, 0.0, 1.0));

	// Corona superior en el filo de la cima (azul blanco)
	color_final = mix(color_final, col_filo_borde, corona_cima * intensidad_cara * 0.75);

	// 6. Transparencia etérea con borde del cono difuminado y suave
	float alpha_cuerpo = mix(color_profundo.a, color_cima.a, v_height);
	float alpha_corrientes = (halo_visible * 0.10) + (nucleo_visible * 0.25) +
	                         (halo_secundario_visible * 0.07) + (nucleo_secundario_visible * 0.15) +
	                         (halo_acento_visible * 0.05) + (nucleo_acento_visible * 0.12);
	// El borde del cono aporta presencia visual pero con caída suave sin filo rígido
	float alpha_borde = (halo_borde * 0.25) + (filo_borde * 0.25) + (fresnel * 0.10);
	float alpha_total = ((alpha_cuerpo * intensidad_cara) + alpha_corrientes + alpha_borde + (contacto_base * 0.35) + (corona_cima * 0.25)) * fade_extremos * feather_silueta * opacidad_general;

	// Emisión: Glow suave concentrado en los bordes del cono en azul blanco/celeste
	vec3 emision_borde = (col_filo_borde * filo_total * 0.85) + (color_borde_halo.rgb * borde_total * 0.55);
	vec3 emision_cintas = (col_nucleo * nucleo_visible * 0.55) +
	                      (color_cinta_secundaria.rgb * nucleo_secundario_visible * 0.30) +
	                      (color_cinta_acento.rgb * nucleo_acento_visible * 0.25) +
	                      (col_halo * halo_visible * 0.18);
	vec3 emision_cuerpo = col_cuerpo * intensidad_glow_cuerpo * intensidad_cara;
	vec3 emision_total = (emision_cintas * intensidad_glow_cintas) +
	           emision_cuerpo * fade_extremos +
	           (emision_borde * brillo_glow_borde) +
	           (col_filo_borde * contacto_base * 0.35) +
	           (col_filo_borde * corona_cima * 0.30);

	// Limitador de brillo que conserva el tono: evita que el Glow del entorno y
	// el tonemap filmic del gameplay laven el cian hacia blanco.
	vec3 salida = color_final + emision_total;
	float pico = max(salida.r, max(salida.g, salida.b));
	float escala = min(1.0, limite_brillo / max(pico, 0.0001));
	ALBEDO = color_final * escala;
	EMISSION = emision_total * escala;
	ALPHA = clamp(alpha_total, 0.0, 0.85);
}
