shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_toon, specular_toon;

// ===================================================================
// SHADER DE PLATAFORMA ESPIRITUAL (GODOT 4)
// Gradiente Vertical, Volumen 3D Definido (Cara Inferior Visible) y Fresnel
// ===================================================================

group_uniforms Colores;
uniform vec4 color_superior : source_color = vec4(0.35, 0.72, 1.0, 0.75);
uniform vec4 color_inferior : source_color = vec4(0.18, 0.42, 0.82, 0.38);
uniform vec4 color_borde_fresnel : source_color = vec4(0.50, 0.88, 1.0, 1.0);

group_uniforms Desvanecimiento;
uniform float altura_caja = 0.4;
uniform float curva_desvanecimiento : hint_range(0.2, 4.0) = 1.0;
uniform float fuerza_fresnel : hint_range(0.0, 5.0) = 1.8;
uniform float fuerza_emision : hint_range(0.0, 3.0) = 0.65;
uniform float velocidad_onda : hint_range(0.0, 5.0) = 1.2;
uniform float opacidad_global : hint_range(0.0, 1.0) = 1.0;

varying float pos_y_local;
varying vec3 normal_local;

void vertex() {
	pos_y_local = VERTEX.y;
	normal_local = NORMAL;
}

void fragment() {
	// Factor vertical de 0.0 (abajo) a 1.0 (arriba)
	float factor_vertical = clamp((pos_y_local + altura_caja * 0.5) / max(0.001, altura_caja), 0.0, 1.0);
	float t_gradiente = pow(factor_vertical, curva_desvanecimiento);

	// Detección de caras superior e inferior para conservar el volumen 3D
	float cara_arriba = clamp(normal_local.y, 0.0, 1.0);
	float cara_abajo = clamp(-normal_local.y, 0.0, 1.0);

	// Resplandor Fresnel en los bordes
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5) * fuerza_fresnel;

	// Onda mística sutil
	float onda = sin(TIME * velocidad_onda + (pos_y_local * 4.0 + UV.x * 5.0)) * 0.5 + 0.5;

	// Mezcla armoniosa de color y alpha de arriba a abajo sin hacer desaparecer la base
	vec3 color_albedo = mix(color_inferior.rgb, color_superior.rgb, t_gradiente);
	float alpha_base = mix(color_inferior.a, color_superior.a, t_gradiente);

	// Garantizar que la cara inferior sea siempre visible y definida
	float alpha_final = clamp(alpha_base + fresnel * 0.30 + cara_arriba * 0.20 + cara_abajo * 0.15, 0.0, 1.0) * opacidad_global;

	ALBEDO = color_albedo;
	EMISSION = (color_borde_fresnel.rgb * (fresnel * 0.65 + onda * 0.15) + color_superior.rgb * cara_arriba * 0.2 + color_inferior.rgb * cara_abajo * 0.15) * fuerza_emision * opacidad_global;
	ALPHA = alpha_final;
	ROUGHNESS = 0.15;
	METALLIC = 0.25;
}
