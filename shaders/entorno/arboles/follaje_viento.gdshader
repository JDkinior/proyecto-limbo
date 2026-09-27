shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx, skip_vertex_transform;

// ====================================================================
// SHADER DE FOLLAJE CON VIENTO UNIFICADO (GODOT 4)
// Proyecto Limbo - Optimizado para PC / Mobile
//
// 1. Movimiento rígido unificado: la base y las tarjetas de hojas se
//    desplazan con el MISMO vector exacto. Cero cizallamiento entre
//    vértices de la copa para que la base NUNCA traspase los planos
//    ni los planos se abran mostrando sus bordes.
// 2. filter_linear (sin mipmaps): evita la degradación y el desenfoque
//    del canal alfa a la distancia, eliminando los bordes oscuros o
//    moteados al alejarse la cámara.
// 3. Anclaje pre-horneado en COLOR.r: Elimina el bucle de 16 iteraciones
//    de distancia por vértice, optimizando el rendimiento en GPU móvil.
// ====================================================================

group_uniforms Apariencia;
uniform sampler2D textura_albedo : source_color, filter_linear;
uniform vec4 color_albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float umbral_alfa : hint_range(0.0, 1.0) = 0.35;
uniform float rugosidad : hint_range(0.0, 1.0) = 0.90;
uniform float especular : hint_range(0.0, 1.0) = 0.50;

group_uniforms Viento;
// Vector de dirección horizontal del viento en espacio de mundo.
// Sincronizado con caida_hojas.tscn (0.35, 0.20) -> (0.868, 0.496)
uniform vec2 direccion_viento = vec2(0.868, 0.496);
uniform float velocidad_viento : hint_range(0.0, 10.0) = 1.8;
uniform float fuerza_sway : hint_range(0.0, 1.0) = 0.16;
uniform float turbulencia_lateral : hint_range(0.0, 1.0) = 0.25;
uniform float altura_base_copa = 2.0;

void vertex() {
	// 1. Origen del árbol en mundo (compartido por toda la instancia)
	vec3 origen_arbol = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// 2. Dirección normalizada del viento y vector perpendicular
	vec2 dir_viento = length(direccion_viento) > 0.001 ? normalize(direccion_viento) : vec2(0.868, 0.496);
	vec2 dir_perpendicular = vec2(-dir_viento.y, dir_viento.x);

	// 3. Atenuación vertical en la base del tronco
	float altura_relativa = max(0.0, pos_mundo.y - origen_arbol.y);
	float factor_copa = smoothstep(altura_base_copa - 0.4, altura_base_copa + 0.4, altura_relativa);

	// 4. Anclaje a las ramas pre-horneado en Vertex Colors (COLOR.r):
	// Los modelos de árboles tienen pre-calculado en vértices el factor de anclaje
	// (0.0 = unión estática con la madera, 1.0 = puntas con vaivén pleno), eliminando
	// el costoso bucle de 16 iteraciones de distancia por cada vértice en GPU móvil.
	float factor_anclaje = COLOR.r;
	float peso_viento = factor_copa * factor_anclaje;

	// 5. Oscilación de viento unificada
	float tiempo = TIME * velocidad_viento;
	float desfase = (origen_arbol.x * dir_viento.x + origen_arbol.z * dir_viento.y) * 0.25;

	float onda_principal = sin(tiempo + desfase);
	float onda_secundaria = sin(tiempo * 1.63 + desfase * 1.3) * 0.35;
	float rafaga = smoothstep(-0.2, 0.8, sin(tiempo * 0.5 + desfase * 0.2)) * 0.4;

	float empuje_viento = (onda_principal + onda_secundaria + rafaga) * fuerza_sway * peso_viento;
	float bamboleo_lateral = cos(tiempo * 0.85 + desfase * 0.7) * turbulencia_lateral * fuerza_sway * 0.35 * peso_viento;

	vec3 desplazamiento_mundo = vec3(
		dir_viento.x * empuje_viento + dir_perpendicular.x * bamboleo_lateral,
		-abs(empuje_viento) * 0.12,
		dir_viento.y * empuje_viento + dir_perpendicular.y * bamboleo_lateral
	);

	// 6. Aplicar desplazamiento al vértice transformando directamente a espacio de vista
	pos_mundo += desplazamiento_mundo;
	VERTEX = (VIEW_MATRIX * vec4(pos_mundo, 1.0)).xyz;
	NORMAL = (VIEW_MATRIX * vec4(MODEL_NORMAL_MATRIX * NORMAL, 0.0)).xyz;
}

void fragment() {
	vec4 tex = texture(textura_albedo, UV);
	vec4 albedo_final = tex * color_albedo;

	ALPHA = albedo_final.a;
	ALPHA_SCISSOR_THRESHOLD = umbral_alfa;

	ALBEDO = albedo_final.rgb;
	ROUGHNESS = rugosidad;
	SPECULAR = especular;
}
