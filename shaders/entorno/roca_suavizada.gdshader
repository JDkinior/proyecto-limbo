shader_type spatial;
// Compatible con Godot 4.7 · renderer Mobile (Forward Mobile / d3d12)
// Efecto: suavizado selectivo de normales de roca low-poly,
// equivalente al "Shade Auto Smooth" de Blender.
//
// FUNCIONAMIENTO:
// La malla procedimental llega con una normal flat por triángulo (facetado puro).
// Este shader interpola esa normal con la normal derivada de la posición en
// screen-space (dFdx / dFdy sobre VERTEX), simulando un suavizado de normales
// en tiempo real sin modificar la geometría ni la silueta.
// El color por vértice (vertex_color_use_as_albedo) se conserva íntegro.

render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

// ---------------------------------------------------------------------------
// PARÁMETROS AJUSTABLES DESDE EL INSPECTOR
// ---------------------------------------------------------------------------

/// Intensidad del suavizado de normales (0 = facetado puro, 1 = totalmente suavizado).
/// Valor recomendado inicial: 0.55
uniform float smooth_strength : hint_range(0.0, 1.0, 0.01) = 0.55;

/// Cuánto del aspecto facetado se conserva aunque smooth_strength sea alto.
/// 1.0 = preserva todo el facetado (sin efecto), 0.0 = suavizado máximo.
/// Valor recomendado inicial: 0.25
uniform float facet_preservation : hint_range(0.0, 1.0, 0.01) = 0.25;

/// Rugosidad del material rocoso.
/// Valor recomendado inicial: 0.90
uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.90;

/// Amplifica o reduce el contraste entre facetas adyacentes.
/// 1.0 = color original sin cambios, > 1.0 = contraste elevado.
/// Valor recomendado inicial: 1.05
uniform float facet_contrast : hint_range(0.8, 1.5, 0.01) = 1.05;

/// Oscurece las grietas y aristas cóncavas entre facetas (pseudo contact shadow).
/// 0.0 = sin efecto, 1.0 = aristas muy pronunciadas.
/// Valor recomendado inicial: 0.35
uniform float edge_shadow : hint_range(0.0, 1.0, 0.01) = 0.35;


// ---------------------------------------------------------------------------
// VERTEX SHADER
// ---------------------------------------------------------------------------
// Pasamos la normal flat (calculada por SurfaceTool, un valor uniforme por tri)
// y el color por vértice para usarlos en el fragment.
// VERTEX aquí es la posición en view-space (Godot 4 spatial).
varying vec3 v_normal_smooth_view; // Normal por sección suavizada interpolada en view-space
varying vec3 v_color;              // Color por vértice (paleta de la sección)
varying vec3 v_vertex_view;        // Posición en view-space para derivada geométrica

group_uniforms LevitacionSatelites;
uniform bool habilitar_levitacion_satelites = true;
uniform float amplitud_levitacion : hint_range(0.0, 0.5, 0.01) = 0.12;
uniform float velocidad_levitacion : hint_range(0.1, 4.0, 0.05) = 1.2;
uniform float balanceo_levitacion : hint_range(0.0, 0.2, 0.005) = 0.035;

void vertex() {
	if (habilitar_levitacion_satelites && COLOR.a < 0.5) {
		vec3 offset_local = vec3(UV2.x, UV.x, UV2.y);
		vec3 centro_roca = VERTEX - offset_local;

		float fase = COLOR.a * 67.0;
		float t = TIME * velocidad_levitacion;

		float dy = sin(t + fase) * amplitud_levitacion + sin(t * 0.48 + fase * 1.6) * (amplitud_levitacion * 0.22);
		float dx = sin(t * 0.62 + fase * 1.3) * (amplitud_levitacion * 0.32);
		float dz = cos(t * 0.71 + fase * 0.77) * (amplitud_levitacion * 0.32);
		vec3 desplazamiento = vec3(dx, dy, dz);

		float rx = sin(t * 0.82 + fase) * balanceo_levitacion;
		float rz = cos(t * 0.75 + fase * 1.4) * balanceo_levitacion;
		float ry = sin(t * 0.41 + fase * 0.5) * (balanceo_levitacion * 0.8);

		float cx = cos(rx), sx = sin(rx);
		vec3 r_pos = vec3(offset_local.x, offset_local.y * cx - offset_local.z * sx, offset_local.y * sx + offset_local.z * cx);
		vec3 r_norm = vec3(NORMAL.x, NORMAL.y * cx - NORMAL.z * sx, NORMAL.y * sx + NORMAL.z * cx);

		float cz = cos(rz), sz = sin(rz);
		r_pos = vec3(r_pos.x * cz - r_pos.y * sz, r_pos.x * sz + r_pos.y * cz, r_pos.z);
		r_norm = vec3(r_norm.x * cz - r_norm.y * sz, r_norm.x * sz + r_norm.y * cz, r_norm.z);

		float cy = cos(ry), sy = sin(ry);
		r_pos = vec3(r_pos.x * cy + r_pos.z * sy, r_pos.y, -r_pos.x * sy + r_pos.z * cy);
		r_norm = vec3(r_norm.x * cy + r_norm.z * sy, r_norm.y, -r_norm.x * sy + r_norm.z * cy);

		NORMAL = normalize(r_norm);
		VERTEX = centro_roca + r_pos + desplazamiento;
	}

	v_normal_smooth_view = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_color = COLOR.rgb;
	v_vertex_view = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


// ---------------------------------------------------------------------------
// FRAGMENT SHADER
// ---------------------------------------------------------------------------
void fragment() {
	// 1. Normal geométrica plana del triángulo vs normal suavizada por secciones (Auto Smooth)
	vec3 ddx_pos = dFdx(v_vertex_view);
	vec3 ddy_pos = dFdy(v_vertex_view);
	vec3 normal_geom_flat = normalize(cross(ddy_pos, ddx_pos));
	vec3 normal_sec_smooth = normalize(v_normal_smooth_view);

	if (dot(normal_geom_flat, normal_sec_smooth) < 0.0) {
		normal_geom_flat = -normal_geom_flat;
	}

	// 2. Mezcla selectiva: preserva las normales suavizadas por secciones de IslaFlotante
	float blend = clamp(smooth_strength + (1.0 - facet_preservation) * 0.45, 0.0, 1.0);
	vec3 normal_final = normalize(mix(normal_geom_flat, normal_sec_smooth, blend));
	NORMAL = normal_final;

	// 3. Color base con contraste sutil
	vec3 albedo = v_color * vec3(0.76, 0.7347, 0.6992);
	float lum = dot(albedo, vec3(0.299, 0.587, 0.114));
	albedo = clamp(lum + (albedo - vec3(lum)) * facet_contrast, 0.0, 1.0);

	// 4. Sombra suave de curvatura en los bordes de cada sección
	float similarity = clamp(dot(normal_geom_flat, normal_sec_smooth), 0.0, 1.0);
	float edge_factor = (1.0 - similarity);
	albedo *= 1.0 - edge_shadow * edge_factor * 0.35;

	// ------------------------------------------------------------------
	// 5. SALIDAS
	// ------------------------------------------------------------------
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	SPECULAR = 0.12;   // Especularidad mínima → roca mate natural
	METALLIC = 0.0;
}
