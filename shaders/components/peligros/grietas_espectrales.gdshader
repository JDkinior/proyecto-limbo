shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_disabled;

// ==============================================================================
// SHADER DE GRIETAS ESPECTRALES - PARALLAX OCCLUSION MAPPING (POM) 3D
// ==============================================================================
// - 4 grietas separadas y distribuidas orgánicamente.
// - Ray marching de 8 pasos con refinamiento lineal (POM): detecta oclusión
//   real de las paredes rocosas de la fosa según el ángulo de la cámara.
// - Desde ángulos bajos (de lado), las paredes de roca ocluyen físicamente
//   el fondo de magma, evitando que se vea plano o pegado a la superficie.
// - Labio rocoso exterior en sombra para dar bisel y volumen de fractura.
// - Render priority negativo (-1) para no superponerse sobre auras y habilidades.
// ==============================================================================

uniform vec4 color_nucleo_rojo : source_color = vec4(1.35, 0.055, 0.075, 1.0);
uniform vec4 color_fondo_rojo : source_color = vec4(0.85, 0.030, 0.040, 1.0);
uniform vec4 color_pared_oscura : source_color = vec4(0.16, 0.008, 0.012, 1.0);
uniform vec4 color_borde_sombra : source_color = vec4(0.004, 0.001, 0.001, 1.0);

uniform float profundidad_metros : hint_range(0.1, 1.5) = 0.52;
uniform float radio_zona : hint_range(1.0, 15.0) = 5.0;
uniform float max_desplazamiento : hint_range(0.02, 1.5) = 0.9;
uniform float fuerza_emision : hint_range(1.0, 12.0) = 4.2;
uniform float grosor_grietas : hint_range(0.5, 2.5) = 1.0;
uniform float velocidad_pulso : hint_range(0.0, 6.0) = 2.2;

varying vec3 v_pos_local;
varying vec3 v_ray_dir_local;

// Hash 2D pseudoaleatorio y determinista
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Ruido suave 2D
float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i + vec2(0.0, 0.0)), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

// FBM multicapa para deformación orgánica de roca quebrada
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * noise2d(p);
		p = p * 2.15 + vec2(1.3, 3.7);
		a *= 0.5;
	}
	return v;
}

// Distancia mínima desde un punto p a un segmento rectilíneo AB
float dist_seg(vec2 p, vec2 a, vec2 b, out float h) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float b_len_sq = max(dot(ba, ba), 0.0001);
	h = clamp(dot(pa, ba) / b_len_sq, 0.0, 1.0);
	vec2 diff = pa - ba * h;
	return length(diff);
}

// 4 grietas independientes repartidas por el territorio (12 segmentos)
const int NUM_SEGS = 12;
const vec4 SEGS[12] = vec4[12](
	// Grieta 1 (NNE):
	vec4( 0.05,  0.25,  0.15,  0.55),
	vec4( 0.15,  0.55,  0.28,  0.78),
	vec4( 0.15,  0.55, -0.08,  0.70),

	// Grieta 2 (ESE):
	vec4( 0.22, -0.05,  0.52, -0.15),
	vec4( 0.52, -0.15,  0.78, -0.25),
	vec4( 0.45, -0.12,  0.68,  0.08),

	// Grieta 3 (SO):
	vec4(-0.12, -0.20, -0.32, -0.48),
	vec4(-0.32, -0.48, -0.46, -0.76),
	vec4(-0.32, -0.48, -0.62, -0.44),

	// Grieta 4 (ONO):
	vec4(-0.20,  0.10, -0.48,  0.22),
	vec4(-0.48,  0.22, -0.75,  0.30),
	vec4(-0.42,  0.19, -0.58,  0.48)
);

const float ANCHOS[12] = float[12](
	0.075, 0.055, 0.045,
	0.075, 0.055, 0.045,
	0.072, 0.054, 0.045,
	0.072, 0.055, 0.045
);

const int TIPOS_CONICIDAD[12] = int[12](
	0, 1, 1,
	0, 1, 1,
	0, 1, 1,
	0, 1, 1
);

// Evalúa la apertura de las grietas en una coordenada 2D p_coord
float eval_grietas(vec2 p_coord, float detalle) {
	vec2 warp = vec2(
		fbm(p_coord * 4.2 + vec2(1.1, 4.2)),
		fbm(p_coord * 4.2 + vec2(6.7, 2.3))
	) - 0.5;
	vec2 warp_det = vec2(0.0);
	if (detalle > 0.02) {
		warp_det = vec2(
			fbm(p_coord * 13.0 + vec2(3.3, 7.9)),
			fbm(p_coord * 13.0 + vec2(8.1, 1.5))
		) - 0.5;
	}

	vec2 p = p_coord + warp * 0.22 + warp_det * (0.05 * detalle);

	float min_d = 999.0;
	for (int i = 0; i < NUM_SEGS; i++) {
		float h;
		float d = dist_seg(p, SEGS[i].xy, SEGS[i].zw, h);
		float taper = 1.0;
		if (TIPOS_CONICIDAD[i] == 0) {
			taper = clamp(h / 0.32, 0.25, 1.0);
		} else {
			taper = clamp((1.0 - h) / 0.42, 0.25, 1.0);
		}
		float d_norm = d / (ANCHOS[i] * grosor_grietas * taper);
		if (d_norm < min_d) {
			min_d = d_norm;
		}
	}
	return min_d;
}

void vertex() {
	v_pos_local = VERTEX;
	// Posición de la cámara en el espacio local del objeto
	vec3 cam_pos_local = (inverse(MODEL_MATRIX) * INV_VIEW_MATRIX[3]).xyz;
	v_ray_dir_local = VERTEX - cam_pos_local;
}

void fragment() {
	vec2 uv_c = (UV - vec2(0.5)) * 2.0;
	float dist_centro = length(uv_c);
	if (dist_centro > 1.0) {
		discard;
	}

	// 1. Apertura en la superficie del terreno (Y = 0)
	float d_surf = eval_grietas(uv_c, 1.0);
	if (d_surf >= 1.0) {
		discard;
	}

	// 2. Rayo de vista en espacio local (sin limitar el angulo: la profundidad es geometricamente real)
	vec2 ray_xz = vec2(v_ray_dir_local.x, v_ray_dir_local.z);
	float ray_y = max(abs(v_ray_dir_local.y), 0.01);

	// 3. Desplazamiento total del rayo desde la superficie (t=0) hasta el fondo (t=1)
	vec2 delta_uv = (ray_xz / ray_y) * (profundidad_metros / radio_zona);
	float len_delta = length(delta_uv);
	if (len_delta > max_desplazamiento) {
		delta_uv *= max_desplazamiento / len_delta;
	}

	// 4. Ray marching con pasos adaptativos al angulo + biseccion (sin escalones visibles)
	const int MAX_STEPS = 40;
	int n_steps = clamp(int(ceil(len_delta / 0.010)), 8, MAX_STEPS);
	float step_size = 1.0 / float(n_steps);
	// Jitter por pixel (ruido de gradiente entrelazado): rompe las capas por paso de muestreo
	float jit = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	float t_hit = 1.0;
	bool hit_wall = false;
	float t_prev = 0.0;

	for (int i = 1; i <= MAX_STEPS + 1; i++) {
		if (i > n_steps + 1) {
			break;
		}
		float t = min((float(i) - 1.0 + jit) * step_size, 1.0);
		float dt = eval_grietas(uv_c + delta_uv * t, (1.0 - t) * (1.0 - t));
		if (dt >= 1.0 - 0.22 * t) {
			float lo = t_prev;
			float hi = t;
			for (int k = 0; k < 7; k++) {
				float mid = 0.5 * (lo + hi);
				if (eval_grietas(uv_c + delta_uv * mid, (1.0 - mid) * (1.0 - mid)) >= 1.0 - 0.22 * mid) {
					hi = mid;
				} else {
					lo = mid;
				}
			}
			t_hit = 0.5 * (lo + hi);
			hit_wall = true;
			break;
		}
		t_prev = t;
		if (t >= 1.0) {
			break;
		}
	}

	// 5. Coordenadas y distancia en el punto de impacto
	vec2 p_hit = uv_c + delta_uv * t_hit;
	float d_hit = eval_grietas(p_hit, (1.0 - t_hit) * (1.0 - t_hit));

	// 6. Sombreado de la pared rocosa según profundidad t_hit
	vec3 col_pared = mix(color_borde_sombra.rgb, color_pared_oscura.rgb, clamp(t_hit * 1.5, 0.0, 1.0));
	col_pared = mix(col_pared, color_fondo_rojo.rgb * 0.75, pow(t_hit, 3.2));

	// 7. Núcleo de magma ardiente en el fondo (solo si el rayo llegó al fondo sin chocar pared alta)
	// Magma vivo: el borde del brillo ondula y las vetas fluyen con el tiempo
	vec2 flujo = p_hit * 9.0 + vec2(TIME * 0.32, -TIME * 0.24);
	float n1 = fbm(flujo);
	float n2 = fbm(flujo * 1.9 - vec2(TIME * 0.45, TIME * 0.2) + n1 * 2.0);
	float ondula = (n1 - 0.5) * 0.30 + (n2 - 0.5) * 0.18;
	float factor_magma = clamp((1.0 - (d_hit + ondula) / 0.42) * 1.7, 0.0, 1.0);
	float vena = smoothstep(0.35, 0.75, n2);
	vec3 col_fondo = mix(color_fondo_rojo.rgb * (0.7 + 0.5 * n1), color_nucleo_rojo.rgb * (0.85 + 0.3 * vena), factor_magma);

	vec3 col_interior = hit_wall ? col_pared : col_fondo;

	// 8. Bisel/labio oscuro en el borde de la superficie para separar el terreno del abismo
	float labio_oscuro = clamp((d_surf - 0.65) / 0.35, 0.0, 1.0);
	col_interior *= (1.0 - pow(labio_oscuro, 2.5) * 0.78);

	// 9. Pulso de energía espectral
	float pulso = 0.88 + 0.12 * sin(TIME * velocidad_pulso - dist_centro * 3.0);

	// 10. Emisión concentrada en el magma del fondo y resplandor bajo de la pared
	vec3 emision = vec3(0.0);
	if (!hit_wall) {
		emision = col_fondo * (factor_magma * fuerza_emision * pulso);
	} else {
		emision = color_fondo_rojo.rgb * (pow(t_hit, 3.5) * fuerza_emision * 0.45 * pulso);
	}

	// 11. Suavizado en la boca de la grieta
	float masc_borde = 1.0 - smoothstep(0.85, 0.98, dist_centro);
	float alfa = smoothstep(1.0, 0.92, d_surf) * masc_borde;
	if (alfa < 0.01) {
		discard;
	}

	ALBEDO = col_interior;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	// Brillo propio: las paredes tambien emiten un poco, sin depender de la luz de la escena
	EMISSION = emision + col_interior * 0.35;
	ALPHA = alfa;
}
