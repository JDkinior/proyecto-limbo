shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Shader para las islas flotantes en el Reino Fantasma (Proyecto Limbo)
// Aplica una paleta estilizada azul oscuro grisáceo preservando las facetas low-poly de la malla.

uniform vec4 color_base : source_color = vec4(0.035, 0.075, 0.14, 1.0);
uniform vec4 color_resalte : source_color = vec4(0.075, 0.14, 0.23, 1.0);
uniform float rugosidad : hint_range(0.0, 1.0) = 0.94;
uniform float fuerza_variacion : hint_range(0.0, 2.0) = 1.0;
uniform vec4 color_emision : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float energia_emision : hint_range(0.0, 5.0) = 0.0;

void fragment() {
	// Luminosidad del color por vértice para conservar la textura facetada procedural
	float lum = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	
	// Si la geometría cuenta con colores por vértice low-poly (rango típico 0.15 a 0.58)
	float t = 0.5;
	if (lum < 0.95 && lum > 0.01) {
		t = clamp((lum - 0.18) / 0.34, 0.0, 1.0);
		t = clamp(mix(0.5, t, fuerza_variacion), 0.0, 1.0);
	}
	
	ALBEDO = mix(color_base.rgb, color_resalte.rgb, t);
	ROUGHNESS = rugosidad;
	
	if (energia_emision > 0.0) {
		EMISSION = color_emision.rgb * energia_emision;
	}
}
