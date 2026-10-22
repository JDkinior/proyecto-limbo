shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

// ==============================================================================
// INDICADOR VISUAL DE OBJETO POSEÍBLE - PROYECTO LIMBO
// Proporciona un resalte azul espectral suave y pulsante cuando el Fantasma
// se aproxima a un objeto que puede ser poseído.
// ==============================================================================

group_uniforms EstiloIndicador;
uniform vec4 color_borde : source_color = vec4(0.25, 0.85, 1.0, 1.0);
uniform vec4 color_superficie : source_color = vec4(0.06, 0.45, 0.88, 0.30);
uniform float potencia_fresnel : hint_range(1.0, 6.0, 0.1) = 2.4;
uniform float energia_emision : hint_range(0.0, 3.0, 0.1) = 0.85;

group_uniforms ControlAnimacion;
uniform float intensidad : hint_range(0.0, 1.0, 0.02) = 0.0;
uniform float velocidad_pulso : hint_range(0.5, 6.0, 0.1) = 2.5;
uniform float amplitud_pulso : hint_range(0.0, 0.5, 0.02) = 0.18;

void fragment() {
	if (intensidad <= 0.001) {
		discard;
	}

	// 1. Efecto Fresnel para bordes definidos estilo espectral
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), potencia_fresnel);

	// 2. Respiración mística suave
	float pulso = 1.0 + (sin(TIME * velocidad_pulso) * amplitud_pulso);

	// 3. Mezcla armónica entre tinte azul de superficie y borde cian
	vec3 color_resalte = mix(color_superficie.rgb, color_borde.rgb, fresnel * 0.75);
	ALBEDO = color_resalte;

	// 4. Emisión suave en los bordes para iluminar sutilmente la silueta
	EMISSION = color_borde.rgb * fresnel * energia_emision * pulso * intensidad;

	// 5. Opacidad sutil translúcida: levemente azul en el cuerpo, más visible en silueta
	float alfa_cuerpo = color_superficie.a * 0.40;
	float alfa_borde = fresnel * 0.60;
	ALPHA = clamp((alfa_cuerpo + alfa_borde) * intensidad * pulso, 0.0, 0.85);
}
