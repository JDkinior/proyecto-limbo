shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

// Shader para las islas flotantes en el Reino Vivo (Proyecto Limbo)
// Conserva el color de roca facetado procedural por vértice y proyecta falso pasto dorado
// en pendientes suaves/mesetas para interpretar vegetación en la distancia sin costo de rendimiento.

group_uniforms ColoresRoca;
uniform vec4 tinte_roca : source_color = vec4(0.76, 0.75, 0.78, 1.0);
uniform float rugosidad_roca : hint_range(0.0, 1.0) = 0.90;

group_uniforms LevitacionSatelites;
uniform bool habilitar_levitacion_satelites = true;
uniform float amplitud_levitacion : hint_range(0.0, 0.5, 0.01) = 0.12;
uniform float velocidad_levitacion : hint_range(0.1, 4.0, 0.05) = 1.2;
uniform float balanceo_levitacion : hint_range(0.0, 0.2, 0.005) = 0.035;

group_uniforms FalsoPastoDistancia;
uniform bool habilitar_pasto_distancia = true;
// Paleta cercana (bajo las briznas 3D: coincide con raíces y tierra profunda)
uniform vec4 color_pasto_cerca_base : source_color = vec4(0.28, 0.18, 0.03, 1.0);
uniform vec4 color_pasto_cerca_punta : source_color = vec4(0.38, 0.25, 0.05, 1.0);
// Paleta lejana (donde no hay pasto 3D: coincide con el follaje dorado brillante de las puntas)
uniform vec4 color_pasto_lejos_base : source_color = vec4(0.46, 0.32, 0.06, 1.0);
uniform vec4 color_pasto_lejos_punta : source_color = vec4(0.66, 0.49, 0.07, 1.0);
// Rango de transición por distancia a la cámara
uniform float distancia_transicion_inicio : hint_range(0.0, 100.0) = 20.0;
uniform float distancia_transicion_fin : hint_range(10.0, 150.0) = 48.0;

uniform float saturacion_pasto : hint_range(0.0, 1.0) = 0.85;
uniform float rugosidad_pasto : hint_range(0.0, 1.0) = 0.96;
uniform float umbral_pendiente_pasto : hint_range(0.0, 1.0) = 0.45;
uniform float suavizado_pendiente_pasto : hint_range(0.01, 0.5) = 0.15;

void vertex() {
	if (habilitar_levitacion_satelites && COLOR.a < 0.5) {
		// Vector relativo del vértice al centro de la roca satélite
		// UV.x codifica (VERTEX.y - centro.y)
		// UV2.x codifica (VERTEX.x - centro.x)
		// UV2.y codifica (VERTEX.z - centro.z)
		vec3 offset_local = vec3(UV2.x, UV.x, UV2.y);
		vec3 centro_roca = VERTEX - offset_local;

		// Fase determinista por roca derivada de COLOR.a
		float fase = COLOR.a * 67.0;
		float t = TIME * velocidad_levitacion;

		// 1. Levitación vertical suave y armónica (flotación en suspensión aérea)
		float dy = sin(t + fase) * amplitud_levitacion + sin(t * 0.48 + fase * 1.6) * (amplitud_levitacion * 0.22);

		// 2. Deriva horizontal sutil producida por corrientes de aire
		float dx = sin(t * 0.62 + fase * 1.3) * (amplitud_levitacion * 0.32);
		float dz = cos(t * 0.71 + fase * 0.77) * (amplitud_levitacion * 0.32);
		vec3 desplazamiento = vec3(dx, dy, dz);

		// 3. Balanceo angular tridimensional sutil (inclinación orgánica sin distorsionar la roca)
		float rx = sin(t * 0.82 + fase) * balanceo_levitacion;
		float rz = cos(t * 0.75 + fase * 1.4) * balanceo_levitacion;
		float ry = sin(t * 0.41 + fase * 0.5) * (balanceo_levitacion * 0.8);

		// Aplicar rotación rígida sobre el offset local y sobre la normal:
		// Pitch (X)
		float cx = cos(rx), sx = sin(rx);
		vec3 r_pos = vec3(offset_local.x, offset_local.y * cx - offset_local.z * sx, offset_local.y * sx + offset_local.z * cx);
		vec3 r_norm = vec3(NORMAL.x, NORMAL.y * cx - NORMAL.z * sx, NORMAL.y * sx + NORMAL.z * cx);

		// Roll (Z)
		float cz = cos(rz), sz = sin(rz);
		r_pos = vec3(r_pos.x * cz - r_pos.y * sz, r_pos.x * sz + r_pos.y * cz, r_pos.z);
		r_norm = vec3(r_norm.x * cz - r_norm.y * sz, r_norm.x * sz + r_norm.y * cz, r_norm.z);

		// Yaw (Y)
		float cy = cos(ry), sy = sin(ry);
		r_pos = vec3(r_pos.x * cy + r_pos.z * sy, r_pos.y, -r_pos.x * sy + r_pos.z * cy);
		r_norm = vec3(r_norm.x * cy + r_norm.z * sy, r_norm.y, -r_norm.x * sy + r_norm.z * cy);

		float r_len_sq = dot(r_norm, r_norm);
		NORMAL = r_len_sq > 0.0001 ? r_norm * inversesqrt(r_len_sq) : vec3(0.0, 1.0, 0.0);
		VERTEX = centro_roca + r_pos + desplazamiento;
	}
}

void fragment() {
	// Color base de roca a partir del color por vértice procedural (conserva variación low-poly pura)
	vec3 col_roca = COLOR.rgb * tinte_roca.rgb;
	
	// Luminosidad del color por vértice para modular la gradación del pasto con facetas
	float lum = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	float t = clamp((lum - 0.18) / 0.34, 0.0, 1.0);
	
	vec3 col_final = col_roca;
	float rough_final = rugosidad_roca;
	float factor_pasto = 0.0;

	if (habilitar_pasto_distancia) {
		// Normal en espacio de mundo para detectar planos horizontales y terrazas superiores
		// Protegida contra longitud cero para evitar NaN (pixeles negros en la GPU)
		float n_len_sq = dot(NORMAL, NORMAL);
		vec3 safe_norm = n_len_sq > 0.0001 ? NORMAL * inversesqrt(n_len_sq) : vec3(0.0, 1.0, 0.0);
		vec3 wn_unnorm = (INV_VIEW_MATRIX * vec4(safe_norm, 0.0)).xyz;
		float wn_len_sq = dot(wn_unnorm, wn_unnorm);
		vec3 world_normal = wn_len_sq > 0.0001 ? wn_unnorm * inversesqrt(wn_len_sq) : vec3(0.0, 1.0, 0.0);
		factor_pasto = smoothstep(
			umbral_pendiente_pasto - suavizado_pendiente_pasto,
			umbral_pendiente_pasto + suavizado_pendiente_pasto,
			world_normal.y
		);
		
		// Excluir rocas satélite (marcadas con COLOR.a = 0.0)
		factor_pasto *= step(0.5, COLOR.a);
		
		// Modulación facetada cerca y lejos
		vec3 col_cerca = mix(color_pasto_cerca_base.rgb, color_pasto_cerca_punta.rgb, t);
		vec3 col_lejos = mix(color_pasto_lejos_base.rgb, color_pasto_lejos_punta.rgb, t);
		
		// Transición suave según la distancia euclidiana a la cámara
		float dist_cam = length(VERTEX);
		float factor_dist = smoothstep(distancia_transicion_inicio, distancia_transicion_fin, dist_cam);
		vec3 col_pasto = mix(col_cerca, col_lejos, factor_dist);
		
		// Desaturación coincidente con pasto_estilizado.gdshader para evitar sobreexposición bajo sol cálido
		float luma_pasto = dot(col_pasto, vec3(0.299, 0.587, 0.114));
		col_pasto = mix(vec3(luma_pasto), col_pasto, saturacion_pasto);
		
		col_final = mix(col_roca, col_pasto, factor_pasto);
		rough_final = mix(rugosidad_roca, rugosidad_pasto, factor_pasto);
	}
	
	ALBEDO = col_final;
	ROUGHNESS = rough_final;
	SPECULAR = mix(0.10, 0.0, factor_pasto);
}
