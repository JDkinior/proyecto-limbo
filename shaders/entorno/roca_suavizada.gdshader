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

render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

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

void vertex() {
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
