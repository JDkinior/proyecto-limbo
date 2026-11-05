shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;

// ===================================================================
// SHADER DE SILUETA TRANSPARENTE ESPECTRAL (PROYECTO LIMBO)
// Estado invisible/translúcido del fantasma para el Jugador Vivo:
// - Borde blanco marcado, grueso y con baja transparencia (fresnel).
// - Centro cristalino limpio y transparente que refracta el fondo.
// - Solo se visualiza la superficie frontal gracias al depth prepass.
// ===================================================================

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float fuerza_distorsion : hint_range(0.0, 0.1) = 0.018;
uniform float velocidad_ondulacion : hint_range(0.1, 8.0) = 2.5;
uniform float frecuencia_ondas : hint_range(1.0, 40.0) = 14.0;

// Parámetros de borde y visibilidad
uniform float grosor_borde : hint_range(0.2, 3.0) = 1.15;
uniform float opacidad_borde : hint_range(0.0, 1.0) = 0.88;
uniform float opacidad_centro : hint_range(0.0, 0.5) = 0.06;
uniform float factor_visibilidad : hint_range(0.0, 1.0) = 1.0;
uniform vec4 color_borde : source_color = vec4(1.0, 1.0, 1.0, 0.95);

void vertex() {
	// Ondulación etérea en la parte inferior (colas), idéntica al prepass
	float factor_altura = clamp(-VERTEX.y - 0.35, 0.0, 1.5);
	float onda_x = sin(TIME * 3.5 + VERTEX.y * 3.0) * 0.04 * factor_altura;
	float onda_z = cos(TIME * 2.8 + VERTEX.y * 2.5) * 0.04 * factor_altura;
	VERTEX.x += onda_x;
	VERTEX.z += onda_z;
}

void fragment() {
	// Fresnel con caída ancha para lograr un borde grueso y bien definido
	float dot_nv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = 1.0 - dot_nv;
	
	// Curva de borde: componente amplia (grosor) + componente en el extremo (filo)
	float rim_ancho = pow(fresnel, grosor_borde);
	float rim_filo = pow(fresnel, 3.8);
	float silueta = clamp(rim_ancho * 0.82 + rim_filo * 0.38, 0.0, 1.0);

	// Refracción del fondo siguiendo la curvatura normal del fantasma
	vec2 ref_normal = NORMAL.xy * fuerza_distorsion * (1.0 - dot_nv * 0.5);
	vec2 onda = vec2(
		sin(TIME * velocidad_ondulacion + SCREEN_UV.y * frecuencia_ondas),
		cos(TIME * velocidad_ondulacion * 0.9 + SCREEN_UV.x * frecuencia_ondas)
	) * (fuerza_distorsion * 0.35);

	vec3 color_fondo = texture(screen_texture, SCREEN_UV + ref_normal + onda).rgb;

	// Borde blanco destacado (menos transparente y más notorio, como en Imagen 2)
	vec3 color_final = mix(color_fondo, color_borde.rgb, silueta * color_borde.a);

	ALBEDO = color_final;
	float alpha_base = mix(opacidad_centro, opacidad_borde, silueta);
	ALPHA = clamp(alpha_base * factor_visibilidad, 0.0, 0.95);
}
