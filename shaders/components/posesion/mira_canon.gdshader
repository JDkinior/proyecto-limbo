shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

// ==============================================================================
// SHADER DE MIRA ESPIRITUAL - PROYECTO LIMBO
// Retícula procedural luminosa de estilo etéreo / espiritual.
// Muestra anillo exterior, marcas de cruz, anillo interior y punto central.
// ==============================================================================

uniform vec4 color_mira : source_color = vec4(0.25, 0.9, 1.0, 0.92);
uniform float grosor_anillo : hint_range(0.01, 0.1) = 0.035;
uniform float radio_anillo : hint_range(0.1, 0.5) = 0.38;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float dist = length(uv);
	
	// Anillo exterior principal
	float anillo = smoothstep(grosor_anillo, grosor_anillo * 0.1, abs(dist - radio_anillo));
	
	// Punto central
	float punto_centro = smoothstep(0.07, 0.02, dist);
	
	// Marcas de la cruz (mira telescópica)
	float ancho_cruz = 0.025;
	float largo_cruz_min = 0.16;
	float largo_cruz_max = 0.48;
	float cruz_h = (abs(uv.y) < ancho_cruz && abs(uv.x) > largo_cruz_min && abs(uv.x) < largo_cruz_max) ? 1.0 : 0.0;
	float cruz_v = (abs(uv.x) < ancho_cruz && abs(uv.y) > largo_cruz_min && abs(uv.y) < largo_cruz_max) ? 1.0 : 0.0;
	float cruz = max(cruz_h, cruz_v);
	
	// Anillo interior sutil
	float anillo_interno = smoothstep(0.02, 0.005, abs(dist - 0.14)) * 0.6;
	
	// Brillo radial suave en el centro
	float aura_centro = smoothstep(radio_anillo * 1.1, 0.0, dist) * 0.15;
	
	float alpha = max(max(anillo, punto_centro), max(cruz, anillo_interno)) + aura_centro;
	
	// Pulso de respiración etérea
	float pulso = 0.88 + 0.12 * sin(TIME * 4.5);
	
	ALBEDO = color_mira.rgb;
	ALPHA = clamp(alpha * color_mira.a * pulso, 0.0, 1.0);
}
