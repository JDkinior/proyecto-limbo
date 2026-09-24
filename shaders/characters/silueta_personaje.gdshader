// ══════════════════════════════════════════════════════════════════════════════
// SHADER DE SILUETA DE OCLUSIÓN (X-RAY)
// ══════════════════════════════════════════════════════════════════════════════
// Este shader se encarga de renderizar la silueta estilizada de un personaje
// cuando este se encuentra oculto detrás de obstáculos u objetos del escenario.
//
// Gracias al modo `depth_test_inverted`, el rasterizador solo dibuja los
// fragmentos cuya profundidad es mayor a la geometría previamente renderizada
// (es decir, cuando hay un muro u obstáculo en la línea de visión de la cámara).
// ══════════════════════════════════════════════════════════════════════════════

shader_type spatial;
render_mode depth_test_inverted, depth_draw_never, unshaded, cull_back;

group_uniforms ColorYBrillo;
## Color base de la silueta y nivel de transparencia (Alpha).
uniform vec4 color_silueta : source_color = vec4(1.0, 0.55, 0.12, 0.85);
## Multiplicador de luminosidad para hacer resaltar la silueta en entornos oscuros o con Glow.
uniform float intensidad_brillo : hint_range(0.5, 3.0, 0.05) = 1.15;

group_uniforms ContornoFresnel;
## Si está activo, ilumina más los bordes del personaje para resaltar su silueta tridimensional.
uniform bool usar_borde_fresnel = true;
## Controla la concentración del brillo en los bordes (valores más altos = borde más fino).
uniform float potencia_fresnel : hint_range(0.2, 6.0, 0.1) = 2.2;
## Intensidad añadida al efecto Fresnel en los bordes.
uniform float factor_fresnel : hint_range(0.0, 1.0, 0.05) = 0.45;

group_uniforms EfectoMistico;
## Activa una suave oscilación rítmica (pulsación) en la luminosidad de la silueta.
uniform bool pulso_activo = false;
## Frecuencia de la pulsación de la silueta.
uniform float velocidad_pulso : hint_range(0.2, 5.0, 0.1) = 2.0;

void fragment() {
	vec3 color_final = color_silueta.rgb * intensidad_brillo;
	float alpha_final = color_silueta.a;

	// Efecto de halo en el contorno (Fresnel)
	if (usar_borde_fresnel) {
		float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), potencia_fresnel);
		color_final = mix(color_final, vec3(1.0), fresnel * factor_fresnel);
		alpha_final = mix(alpha_final * 0.75, 1.0, fresnel * factor_fresnel);
	}

	// Pulsación sutil opcional
	if (pulso_activo) {
		float pulso = 0.5 + 0.5 * sin(TIME * velocidad_pulso);
		color_final *= (0.85 + 0.3 * pulso);
		alpha_final *= (0.9 + 0.1 * pulso);
	}

	ALBEDO = color_final;
	ALPHA = clamp(alpha_final, 0.0, 1.0);
}
