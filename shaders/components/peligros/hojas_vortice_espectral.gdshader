shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

// ===================================================================
// HOJAS ESPECTRALES DEL VÓRTICE (PROYECTO LIMBO)
// - Extrae silueta y nervaduras de Hoja.png.
// - Proyecta los tonos espectrales definidos en el gradiente de partícula.
// - Modo Billboard cilíndrico/esférico para máxima visibilidad desde la cámara.
// ===================================================================

uniform sampler2D textura_hoja : source_color, filter_linear_mipmap;
uniform float resplandor : hint_range(0.0, 3.0) = 0.9;

void vertex() {
	// Cada partícula obtiene una orientación inicial estable a partir de su ID.
	// INSTANCE_CUSTOM.x añade el giro lento controlado por CPUParticles3D.
	// Nunca usamos su posición como semilla: cambia al orbitar y produciría
	// giros bruscos como una llanta.
	float semilla = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453);
	float angulo_hoja = semilla * 6.2831853 + INSTANCE_CUSTOM.x;
	float c = cos(angulo_hoja);
	float s = sin(angulo_hoja);
	mat2 giro_hoja = mat2(vec2(c, -s), vec2(s, c));
	VERTEX.xy = giro_hoja * VERTEX.xy;

	// Billboard para que las hojas miren hacia la cámara manteniendo la escala y rotación de partícula
	mat4 mat_world = mat4(
		normalize(INV_VIEW_MATRIX[0]) * length(MODEL_MATRIX[0].xyz),
		normalize(INV_VIEW_MATRIX[1]) * length(MODEL_MATRIX[1].xyz),
		normalize(INV_VIEW_MATRIX[2]) * length(MODEL_MATRIX[2].xyz),
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat_world;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 tex = texture(textura_hoja, UV);

	// Luminancia para conservar nervaduras y forma sin retener colores otoñales amarillos/marrones
	float luma = clamp(dot(tex.rgb, vec3(0.299, 0.587, 0.114)) * 1.35, 0.0, 1.0);

	// Color espectral provisto dinámicamente por la partícula (COLOR)
	vec3 color_espectral = COLOR.rgb * (0.55 + 0.45 * luma);

	ALBEDO = color_espectral;
	EMISSION = color_espectral * resplandor;
	ALPHA = tex.a * COLOR.a;
	ROUGHNESS = 0.3;
}
