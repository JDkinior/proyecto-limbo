shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back;

// ===================================================================
// PREPASS DE PROFUNDIDAD PARA SILUETA ESPECTRAL (PROYECTO LIMBO)
// Escribe la profundidad de la superficie frontal más cercana
// para que las caras traseras e interiores no se vean a través del cuerpo.
// ===================================================================

void vertex() {
	// Ondulación etérea idéntica a la silueta para sincronía perfecta de vértices
	float factor_altura = clamp(-VERTEX.y - 0.35, 0.0, 1.5);
	float onda_x = sin(TIME * 3.5 + VERTEX.y * 3.0) * 0.04 * factor_altura;
	float onda_z = cos(TIME * 2.8 + VERTEX.y * 2.5) * 0.04 * factor_altura;
	VERTEX.x += onda_x;
	VERTEX.z += onda_z;
}

void fragment() {
	// Invisible para el color, pero escribe profundidad en el Z-buffer
	ALBEDO = vec3(0.0);
	ALPHA = 0.001;
}
