shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform int modo_filtro : hint_range(0, 7) = 0;
// 0: Normal
// 1: Otoño Cálido (Mario Odyssey / BotW Warm Golden)
// 2: Espiritual / Místico (Cyan & Celestial Blue)
// 3: Cine Blanco y Negro (Monochrome Noir)
// 4: Vintage Sepia (Nostalgic Brown)
// 5: Vívido / Pop (High Vibrance & Saturation)
// 6: Ensueño / Pastel (Dreamy Soft Glow)
// 7: Silueta / Alto Contraste (Dramatic Silhouette)

uniform float intensidad_filtro : hint_range(0.0, 1.0) = 1.0;
uniform float intensidad_vineta : hint_range(0.0, 1.0) = 0.0;
uniform float brillo : hint_range(-0.5, 0.5) = 0.0;
uniform float contraste : hint_range(0.5, 1.8) = 1.0;

void fragment() {
	vec4 src_color = texture(screen_texture, SCREEN_UV);
	vec3 c = src_color.rgb;

	// 1. Aplicación de brillo y contraste base
	c = (c - 0.5) * contraste + 0.5 + brillo;
	c = clamp(c, 0.0, 1.0);

	vec3 c_filtrado = c;

	if (modo_filtro == 1) {
		// Otoño Cálido: realza dorados, ocres y luz solar otoñal
		c_filtrado = vec3(
			c.r * 1.18 + 0.06,
			c.g * 1.04 + 0.03,
			c.b * 0.78 - 0.02
		);
	} else if (modo_filtro == 2) {
		// Espiritual / Místico: tonos celestiales, cyan luminoso y noche etérea
		c_filtrado = vec3(
			c.r * 0.72 - 0.02,
			c.g * 1.08 + 0.05,
			c.b * 1.28 + 0.10
		);
	} else if (modo_filtro == 3) {
		// Blanco y Negro: película clásica con contraste cinematográfico
		float lum = dot(c, vec3(0.299, 0.587, 0.114));
		float mono = clamp((lum - 0.5) * 1.30 + 0.5, 0.0, 1.0);
		c_filtrado = vec3(mono);
	} else if (modo_filtro == 4) {
		// Vintage Sepia: fotografía antigua nostálgica
		float lum = dot(c, vec3(0.299, 0.587, 0.114));
		c_filtrado = vec3(
			lum * 1.20 + 0.06,
			lum * 1.00 + 0.03,
			lum * 0.72
		);
	} else if (modo_filtro == 5) {
		// Vívido / Pop: saturación exuberante y colores intensos
		float lum = dot(c, vec3(0.299, 0.587, 0.114));
		c_filtrado = mix(vec3(lum), c, 1.65);
	} else if (modo_filtro == 6) {
		// Ensueño / Pastel: curvas suaves, sombras etéreas y tonos pastel
		vec3 pastel = pow(c, vec3(0.82)) * vec3(1.06, 0.98, 1.05);
		c_filtrado = pastel;
	} else if (modo_filtro == 7) {
		// Silueta / Alto Contraste: corte dramático estilo sombras chinescas
		float lum = dot(c, vec3(0.299, 0.587, 0.114));
		float sil = smoothstep(0.32, 0.68, lum);
		c_filtrado = vec3(sil);
	}

	c = mix(c, clamp(c_filtrado, 0.0, 1.0), intensidad_filtro);

	// 2. Viñeta fotográfica suave en las esquinas
	if (intensidad_vineta > 0.01) {
		vec2 uv_dist = SCREEN_UV - vec2(0.5);
		float radio = length(uv_dist);
		float v = smoothstep(0.38, 0.88, radio);
		c = mix(c, c * (1.0 - v * 0.88), intensidad_vineta);
	}

	COLOR = vec4(clamp(c, 0.0, 1.0), src_color.a);
}
