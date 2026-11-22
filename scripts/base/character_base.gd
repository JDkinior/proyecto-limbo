extends CharacterBody3D
class_name CharacterBase

# Parámetros compartidos
@export var VELOCIDAD : float = 5.0
@export var ACELERACION_SUELO : float = 24.0
@export var DESACELERACION_SUELO : float = 30.0
@export var ACELERACION_AIRE : float = 12.0
@export var DESACELERACION_AIRE : float = 12.0
@export var VELOCIDAD_ROTACION_PERSONAJE : float = 12.0
@export var LIMITE_CAIDA_Y : float = -8.0

@export_group("Camara Inteligente")
@export var SENSIBILIDAD_CAMARA : float = 0.005
@export var SUAVIDAD_CAMARA : float = 18.0
@export var VELOCIDAD_ROTACION_BUMPERS_Y : float = 2.4
@export var DISTANCIA_CAMARA : float = 5.2
@export var MARGEN_COLISION_CAMARA : float = 0.15
@export var PITCH_DEFECTO_CAMARA : float = -0.22            # ~-12.6 grados (encuadre Shorts vertical 9:16)
@export var LIMITE_PITCH_MIN : float = -0.75               # ~-43 grados
@export var LIMITE_PITCH_MAX : float = 0.25                # ~+14 grados
@export var ALTURA_SPRING_ARM : float = 0.65
@export var V_OFFSET_CAMARA : float = -0.15
@export var CAMARA_JEFE_ACTIVA : bool = true
@export var DISTANCIA_EXTRA_CAMARA_JEFE : float = 1.6
@export var ALTURA_EXTRA_CAMARA_JEFE : float = 0.30
@export var SUAVIDAD_AUTO_CAMARA_JEFE : float = 2.1
@export var PAUSA_MANUAL_CAMARA_JEFE : float = 2.0
@export var DESPLAZAMIENTO_PIVOTE_JEFE_MAX : float = 0.65
@export var ZONA_MUERTA_YAW_CAMARA_JEFE : float = 0.24

@export_group("Sombra de Aterrizaje")
@export var SOMBRA_ATERRIZAJE_ACTIVA: bool = true
@export var SOMBRA_DISTANCIA_MAX: float = 18.0
@export var SOMBRA_TAMANO_BASE: float = 1.05
@export var SOMBRA_ESCALA_MIN_ALTURA: float = 0.55
@export var SOMBRA_OPACIDAD_SUELO: float = 0.52
@export var SOMBRA_OPACIDAD_AIRE_MIN: float = 0.34
@export var SOMBRA_OFFSET_SUPERFICIE: float = 0.03

static var _malla_sombra_aterrizaje: PlaneMesh = null
static var _textura_sombra_aterrizaje: GradientTexture2D = null

var _raycast_sombra_aterrizaje: RayCast3D = null
var _mesh_sombra_aterrizaje: MeshInstance3D = null
var _material_sombra_aterrizaje: StandardMaterial3D = null

@export_group("Salto Compartido")
@export var FUERZA_SALTO : float = 7.5
@export var MULTIPLICADOR_SEGUNDO_SALTO : float = 0.9
@export var MULTIPLICADOR_GRAVEDAD_SUBIDA : float = 1.0
@export var MULTIPLICADOR_CAIDA : float = 2.0
@export var MULTIPLICADOR_CORTE_SALTO : float = 2.2
@export var MULTIPLICADOR_GRAVEDAD_APICE : float = 1.0
@export var UMBRAL_VELOCIDAD_APICE : float = 1.6
@export var VELOCIDAD_MAX_CAIDA : float = 26.0
@export var TIEMPO_COYOTE : float = 0.12
@export var TIEMPO_BUFFER_SALTO : float = 0.12
@export var MAX_SALTOS : int = 2

@export_group("Levitacion / Planeo")
@export var PUEDE_PLANEAR : bool = false
@export var MULTIPLICADOR_CAIDA_PLANEO : float = 0.18
@export var VELOCIDAD_MAX_CAIDA_PLANEO : float = 1.85
@export var MULTIPLICADOR_VELOCIDAD_PLANEO : float = 1.15
@export var MULTIPLICADOR_ACELERACION_PLANEO : float = 1.25
@export var SUAVIDAD_FRENADO_PLANEO : float = 18.0

@export_group("Silueta de Oclusion")
## Activa la silueta visible cuando el personaje queda oculto tras obstáculos (muros, rocas, árboles).
@export var silueta_activa: bool = true:
	set(valor):
		silueta_activa = valor
		actualizar_silueta_oclusion()

## Color y transparencia de la silueta al estar oculto tras obstáculos.
@export var color_silueta: Color = Color(1.0, 0.55, 0.12, 0.85):
	set(valor):
		color_silueta = valor
		actualizar_silueta_oclusion()

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var objetivo_rotacion_y : float = 0.0
var objetivo_rotacion_x : float = 0.0
var posicion_inicial : Vector3
var rotacion_inicial : Vector3
var punto_control : Vector3 = Vector3.ZERO
var rotacion_punto_control : Vector3 = Vector3.ZERO
var rotacion_inicial_camara_x : float = PITCH_DEFECTO_CAMARA
var tiempo_desde_suelo : float = 0.0
var tiempo_desde_salto : float = 0.0
var saltos_realizados : int = 0
var _vel_y_previa_base : float = 0.0

# Estado de derrape físico y turnaround tipo Odyssey
var esta_derrapando: bool = false
var tiempo_derrape_restante: float = 0.0
const DURACION_DERRAPE: float = 0.28
const DESACELERACION_DERRAPE: float = 14.0
var _dir_deslizamiento_derrape: Vector2 = Vector2.ZERO
var _angulo_derrape_rotacion: float = 0.0

# Variables para interpolación de red (anti-stuttering)
var sync_position: Vector3
var sync_rotation: Vector3

# ===================================================================
# GESTIÓN DE FUERZAS EXTERNAS Y VÓRTICES (TORBELLINOS)
# ===================================================================
var movimiento_bloqueado: bool = false
var en_vuelo_balistico: bool = false
var _fuerza_vortice_acumulada: Vector3 = Vector3.ZERO
var _arrastre_descendente_vortice: float = 0.0
var _vortice_esta_absorbido: bool = false
var _tiempo_absorcion_restante: float = 0.0
var _duracion_absorcion_total: float = 1.0
var _centro_absorcion: Vector3 = Vector3.ZERO
var _impulso_expulsion_pendiente: Vector3 = Vector3.ZERO
var _angulo_giro_absorcion: float = 0.0
var _radio_orbita_absorcion: float = 0.6
var _radio_inicial_absorcion: float = 0.6
var _velocidad_giro_absorcion: float = 12.0
var _y_entrada_vortice: float = 0.0
var _y_salida_vortice: float = 0.0
var _altura_vortice: float = 5.2
var _tiempo_impulso_caida: float = 0.0
var _vel_max_caida_impulso: float = 0.0
var _pos_camara_fija_vortice: Vector3 = Vector3.ZERO
var _rot_camara_fija_vortice: Vector3 = Vector3.ZERO
var _rot_x_arm_fija_vortice: float = 0.0
var _camara_fijada_en_vortice: bool = false

# Variables para fijar la cámara al caer tras desactivarse una plataforma o caer al vacío
var _pos_camara_fija_caida: Vector3 = Vector3.ZERO
var _rot_camara_fija_caida: Vector3 = Vector3.ZERO
var _rot_x_arm_fija_caida: float = 0.0
var _camara_fijada_en_caida: bool = false
var _retornando_de_camara_estatica: bool = false
var _ultimo_suelo_colisionado: Node = null
var _tiempo_desde_ultimo_suelo: float = 999.0

# Cámara inteligente centrada en el jefe dentro del coliseo (estilo Super Mario Odyssey)
var jefe_camara_override: Node3D = null
var _jefe_camara_activo: Node3D = null
var _factor_camara_jefe: float = 0.0
var _tiempo_pausa_camara_jefe: float = 0.0
var _offset_pivote_jefe_actual: Vector3 = Vector3.ZERO
var _distancia_extra_jefe_actual: float = 0.0
var _altura_extra_jefe_actual: float = 0.0
var _yaw_movimiento_anclado: float = 0.0
var _movimiento_anclado_activo: bool = false
var _ultimo_input_mov_2d: Vector2 = Vector2.ZERO

signal fantasma_absorbido_en_vortice(centro: Vector3, duracion: float)
signal fantasma_expulsado_de_vortice(impulso: Vector3)

var _nodo_vortice_origen: Node3D = null

func aplicar_fuerza_vortice(fuerza_horizontal: Vector3, arrastre_vertical: float = 0.0) -> void:
	_fuerza_vortice_acumulada += fuerza_horizontal
	_arrastre_descendente_vortice = maxf(_arrastre_descendente_vortice, arrastre_vertical)

func recibir_impulso_externo(impulso: Vector3) -> void:
	velocity += impulso

func ser_absorbido_en_vortice(centro: Vector3, duracion: float, impulso_salida: Vector3, nodo_vortice: Node3D = null, altura_tornado: float = 5.2) -> void:
	if _vortice_esta_absorbido:
		return
	_vortice_esta_absorbido = true
	_tiempo_absorcion_restante = duracion
	_duracion_absorcion_total = maxf(duracion, 0.1)
	_centro_absorcion = centro
	_nodo_vortice_origen = nodo_vortice
	_impulso_expulsion_pendiente = impulso_salida
	_velocidad_giro_absorcion = 12.0
	
	if is_instance_valid(nodo_vortice) and "altura_tornado" in nodo_vortice:
		var esc_y = nodo_vortice.global_basis.get_scale().y if is_instance_valid(nodo_vortice) else 1.0
		_altura_vortice = (nodo_vortice.get("altura_tornado") if nodo_vortice.get("altura_tornado") != null else 5.2) * esc_y
	else:
		_altura_vortice = altura_tornado
		
	var offset_visual_y = 0.0
	if is_instance_valid(nodo_vortice) and nodo_vortice.has_node("Visual"):
		offset_visual_y = nodo_vortice.get_node("Visual").position.y
	
	var y_centro_vortice = _centro_absorcion.y + offset_visual_y
	var y_tope_vortice = y_centro_vortice + (_altura_vortice * 0.5)
	var y_base_vortice = y_centro_vortice - (_altura_vortice * 0.5)
	
	# Salida justo por debajo de la base inferior del torbellino
	_y_salida_vortice = y_base_vortice - 0.35
	
	# Cota vertical de entrada: asegurar que comience dentro del cuerpo del embudo para un descenso visible
	_y_entrada_vortice = clampf(global_position.y, y_base_vortice + (_altura_vortice * 0.30), y_tope_vortice - 0.20)
	
	var offset = global_position - centro
	_angulo_giro_absorcion = atan2(offset.x, -offset.z)
	
	# Calcular radio del cono en el punto vertical de entrada
	var t_cono_entrada = clampf((_y_entrada_vortice - y_base_vortice) / maxf(_altura_vortice, 0.001), 0.0, 1.0)
	var r_cono_entrada = lerpf(0.45, 2.4, t_cono_entrada)
	
	# Acotar la distancia inicial para que entre directamente dentro del cono sin orbitar por fuera
	var dist_actual = Vector2(offset.x, offset.z).length()
	_radio_inicial_absorcion = minf(dist_actual, r_cono_entrada * 0.75)
	_radio_orbita_absorcion = _radio_inicial_absorcion
	velocity = Vector3.ZERO
	
	# Congelar la cámara en la posición exacta en la que quedó al ser absorbido (evita zoom brusco/cortado)
	if pivote_camara:
		_pos_camara_fija_vortice = pivote_camara.global_position
		_rot_camara_fija_vortice = pivote_camara.rotation
		var arm = obtener_spring_arm()
		_rot_x_arm_fija_vortice = arm.rotation.x if arm else pivote_camara.rotation.x
		_camara_fijada_en_vortice = true
	
	fantasma_absorbido_en_vortice.emit(centro, duracion)

func esta_absorbido_en_vortice() -> bool:
	return _vortice_esta_absorbido

func obtener_progreso_absorcion() -> float:
	if not _vortice_esta_absorbido: return 0.0
	return 1.0 - clampf(_tiempo_absorcion_restante / _duracion_absorcion_total, 0.0, 1.0)

func fijar_camara_en_caida() -> void:
	if pivote_camara == null:
		pivote_camara = get_node_or_null("Node3D")
	if not pivote_camara or _vortice_esta_absorbido or _camara_fijada_en_vortice or _camara_fijada_en_caida:
		return
	_pos_camara_fija_caida = pivote_camara.global_position
	_pos_camara_fija_caida.y = maxf(_pos_camara_fija_caida.y, LIMITE_CAIDA_Y + 4.0)
	_rot_camara_fija_caida = pivote_camara.rotation
	var arm = obtener_spring_arm()
	_rot_x_arm_fija_caida = arm.rotation.x if arm else pivote_camara.rotation.x
	_camara_fijada_en_caida = true

func esta_camara_fijada_en_caida() -> bool:
	return _camara_fijada_en_caida

func al_desactivarse_plataforma_soporte(plataforma: Node3D) -> void:
	if not es_activo():
		return
	var estaba_sobre_plataforma = false
	if _ultimo_suelo_colisionado == plataforma and _tiempo_desde_ultimo_suelo <= 0.4:
		estaba_sobre_plataforma = true
	else:
		# Comprobación espacial: verificar si el personaje se encuentra sobre la superficie de la plataforma
		var pos_local = plataforma.global_transform.affine_inverse() * global_position
		var ancho_plat = plataforma.get("ancho") if "ancho" in plataforma else 10.0
		var largo_plat = plataforma.get("largo") if "largo" in plataforma else 10.0
		var alt_sup = plataforma.get("altura_superficie") if "altura_superficie" in plataforma else 0.0
		var semieje_x = (ancho_plat * 0.5) + 1.5
		var semieje_z = (largo_plat * 0.5) + 1.5
		var y_rel = pos_local.y - alt_sup
		if absf(pos_local.x) <= semieje_x and absf(pos_local.z) <= semieje_z and y_rel >= -1.2 and y_rel <= 3.0:
			estaba_sobre_plataforma = true

	if estaba_sobre_plataforma:
		fijar_camara_en_caida()


var particulas_corazon: CPUParticles3D = null
var tiempo_cerca_otro: float = 0.0
var _otro_jugador_cache: Node3D = null
const DISTANCIA_PROXIMIDAD_CORAZON: float = 1.4 # Deben estar pegados lado a lado
const TIEMPO_REQUERIDO_PROXIMIDAD: float = 5.0 # 5 segundos continuos de estar cerca


@onready var pivote_camara = $Node3D
var controles_tactiles: Node = null

func obtener_pivote_camara() -> Node3D:
	if not pivote_camara:
		pivote_camara = get_node_or_null("Node3D")
	return pivote_camara

func obtener_camara() -> Camera3D:
	if not pivote_camara:
		pivote_camara = get_node_or_null("Node3D")
	if not pivote_camara:
		return null
	if pivote_camara is Camera3D:
		return pivote_camara as Camera3D
	var cam = pivote_camara.get_node_or_null("SpringArm3D/Camera3D")
	if cam is Camera3D:
		return cam
	cam = pivote_camara.get_node_or_null("Camera3D")
	if cam is Camera3D:
		return cam
	return pivote_camara.find_child("Camera3D", true, false) as Camera3D

func obtener_spring_arm() -> SpringArm3D:
	if not pivote_camara:
		pivote_camara = get_node_or_null("Node3D")
	if not pivote_camara:
		return null
	if pivote_camara is SpringArm3D:
		return pivote_camara as SpringArm3D
	var arm = pivote_camara.get_node_or_null("SpringArm3D")
	if arm is SpringArm3D:
		return arm
	return pivote_camara.find_child("SpringArm3D", true, false) as SpringArm3D

func _pos_mundo_nodo(nodo: Node3D) -> Vector3:
	if not is_instance_valid(nodo):
		return Vector3.ZERO
	return nodo.global_position if nodo.is_inside_tree() else nodo.position

func _calcular_pos_pivote_seguimiento() -> Vector3:
	var limite_y_camara := LIMITE_CAIDA_Y + 4.0
	var pos_objetivo: Vector3 = global_position
	if pos_objetivo.y < limite_y_camara:
		pos_objetivo.y = limite_y_camara
	return pos_objetivo + (_offset_pivote_jefe_actual * _factor_camara_jefe)

func _es_jefe_valido_para_camara(jefe: Node3D) -> bool:
	if not is_instance_valid(jefe):
		return false
	if jefe.has_method("esta_activo_para_camara"):
		return bool(jefe.esta_activo_para_camara())
	if "estado_actual" in jefe and "DERROTADO" in jefe:
		return int(jefe.get("estado_actual")) != int(jefe.get("DERROTADO"))
	return true

func obtener_jefe_camara_activo() -> Node3D:
	if not CAMARA_JEFE_ACTIVA:
		return null
	var candidatos: Array = []
	if is_instance_valid(jefe_camara_override):
		candidatos.append(jefe_camara_override)
	elif is_inside_tree() and get_tree():
		candidatos = get_tree().get_nodes_in_group("bosses_espectrales")

	var mi_pos: Vector3 = _pos_mundo_nodo(self)
	var mejor_jefe: Node3D = null
	var mejor_dist_sq: float = INF
	for item in candidatos:
		var jefe := item as Node3D
		if not _es_jefe_valido_para_camara(jefe):
			continue
		var jefe_pos: Vector3 = _pos_mundo_nodo(jefe)
		var radio_arena: float = float(jefe.obtener_radio_camara_arena()) if jefe.has_method("obtener_radio_camara_arena") else 16.0
		if jefe == _jefe_camara_activo:
			radio_arena += 1.5
		var dist_h_sq: float = Vector2(mi_pos.x - jefe_pos.x, mi_pos.z - jefe_pos.z).length_squared()
		if dist_h_sq <= radio_arena * radio_arena and absf(mi_pos.y - jefe_pos.y) <= 10.0:
			if dist_h_sq < mejor_dist_sq:
				mejor_dist_sq = dist_h_sq
				mejor_jefe = jefe
	return mejor_jefe

func esta_enfocando_jefe() -> bool:
	return is_instance_valid(_jefe_camara_activo) and _factor_camara_jefe > 0.05

func calcular_encuadre_camara_jefe(jefe: Node3D) -> Dictionary:
	var mi_pos: Vector3 = _pos_mundo_nodo(self)
	var jefe_pos: Vector3 = _pos_mundo_nodo(jefe)
	var foco: Vector3 = jefe.obtener_punto_foco_camara() if jefe.has_method("obtener_punto_foco_camara") else (jefe_pos + Vector3(0.0, 2.5, 0.0))
	var intensidad: float = float(jefe.obtener_intensidad_camara_arena()) if jefe.has_method("obtener_intensidad_camara_arena") else 1.0

	var delta_xz := Vector2(foco.x - mi_pos.x, foco.z - mi_pos.z)
	var dist_h: float = delta_xz.length()
	var yaw: float = atan2(-delta_xz.x, -delta_xz.y) if dist_h > 0.001 else objetivo_rotacion_y
	var peso_yaw: float = clampf((dist_h - 1.35) / 1.15, 0.0, 1.0)

	var y_cam_origen: float = mi_pos.y + ALTURA_SPRING_ARM + ALTURA_EXTRA_CAMARA_JEFE
	var dy: float = foco.y - y_cam_origen
	var pitch_base: float = atan2(dy, maxf(dist_h, 3.8)) - 0.26
	var pitch_min_auto: float = maxf(LIMITE_PITCH_MIN, -0.56)
	var pitch: float = clampf(pitch_base, pitch_min_auto, minf(LIMITE_PITCH_MAX, -0.18))

	var altura_rel: float = maxf(0.0, mi_pos.y - jefe_pos.y)
	var offset_pivote := Vector3.ZERO
	if dist_h > 0.25:
		var dir_h := Vector3(delta_xz.x / dist_h, 0.0, delta_xz.y / dist_h)
		var mag_pivote: float = minf(dist_h * 0.16, DESPLAZAMIENTO_PIVOTE_JEFE_MAX) * clampf(intensidad, 0.5, 1.15)
		offset_pivote = dir_h * mag_pivote

	# Límite radial de cuenco seguro (rayo-círculo) para mantener la cámara dentro de pilares/linternas/muros
	var r_seguro: float = float(jefe.obtener_radio_camara_seguro()) if jefe.has_method("obtener_radio_camara_seguro") else 11.2
	var yaw_eval: float = yaw
	if is_instance_valid(pivote_camara) and esta_enfocando_jefe():
		yaw_eval = pivote_camara.rotation.y
	var dir_atras := Vector2(sin(yaw_eval), cos(yaw_eval))

	var dist_base_cam: float = DISTANCIA_CAMARA
	var mgr := _get_camara_config_manager()
	if is_instance_valid(mgr) and mgr.has_method("obtener_distancia_camara"):
		var d_mgr: Variant = mgr.obtener_distancia_camara()
		if d_mgr != null:
			dist_base_cam = float(d_mgr)

	var dist_deseada: float = dist_base_cam + (DISTANCIA_EXTRA_CAMARA_JEFE + clampf(altura_rel * 0.14, 0.0, 0.75)) * clampf(intensidad, 0.55, 1.25)
	var cos_p: float = maxf(cos(pitch), 0.35)

	var p_jug := Vector2(mi_pos.x - foco.x, mi_pos.z - foco.z)
	var b_jug: float = p_jug.dot(dir_atras)
	var c_jug: float = p_jug.length_squared() - (r_seguro * r_seguro)
	var disc_jug: float = (b_jug * b_jug) - c_jug
	var t_horiz_jug: float = maxf(0.0, -b_jug + sqrt(disc_jug)) if disc_jug > 0.0 else 0.0
	var compresion: float = clampf(((dist_deseada - (t_horiz_jug / cos_p)) - 1.35) / 2.2, 0.0, 1.0)
	offset_pivote *= (1.0 - compresion * 0.90)

	var p_piv := Vector2((mi_pos.x + offset_pivote.x) - foco.x, (mi_pos.z + offset_pivote.z) - foco.z)
	var b: float = p_piv.dot(dir_atras)
	var c: float = p_piv.length_squared() - (r_seguro * r_seguro)
	var disc: float = (b * b) - c
	var t_horiz_max: float = maxf(0.0, -b + sqrt(disc)) if disc > 0.0 else 0.0

	var dist_max_segura: float = clampf(t_horiz_max / cos_p, 2.85, dist_deseada)
	var distancia_extra: float = dist_max_segura - dist_base_cam
	var altura_extra: float = ALTURA_EXTRA_CAMARA_JEFE * clampf(intensidad, 0.6, 1.15) * clampf(1.0 - altura_rel * 0.12, 0.40, 1.0) + compresion * 0.12
	pitch = clampf(pitch - compresion * 0.14, pitch_min_auto, -0.18)
	var radio_camara_estimado: float = (p_piv + dir_atras * (dist_max_segura * cos_p)).length()

	return {
		"yaw": yaw,
		"pitch": pitch,
		"peso_yaw": peso_yaw,
		"distancia_extra": distancia_extra,
		"altura_extra": altura_extra,
		"offset_pivote": offset_pivote,
		"intensidad": intensidad,
		"radio_camara_estimado": radio_camara_estimado
	}

func centrar_camara_inmediatamente():
	var jefe := obtener_jefe_camara_activo()
	if is_instance_valid(jefe):
		_jefe_camara_activo = jefe
		_tiempo_pausa_camara_jefe = 0.0
		var enc := calcular_encuadre_camara_jefe(jefe)
		if float(enc["peso_yaw"]) > 0.0:
			objetivo_rotacion_y = float(enc["yaw"])
		objetivo_rotacion_x = clampf(float(enc["pitch"]), LIMITE_PITCH_MIN, LIMITE_PITCH_MAX)
		return
	objetivo_rotacion_y = rotation.y
	objetivo_rotacion_x = PITCH_DEFECTO_CAMARA

func preparar_pose_camara_transicion(pitch_defecto: float) -> void:
	if not is_instance_valid(pivote_camara):
		return
	pivote_camara.top_level = true
	var jefe := obtener_jefe_camara_activo()
	if is_instance_valid(jefe):
		_jefe_camara_activo = null
		_factor_camara_jefe = 0.0
		var enc := calcular_encuadre_camara_jefe(jefe)
		_jefe_camara_activo = jefe
		_tiempo_pausa_camara_jefe = 0.0
		_factor_camara_jefe = 1.0
		_offset_pivote_jefe_actual = enc["offset_pivote"]
		_distancia_extra_jefe_actual = float(enc["distancia_extra"])
		_altura_extra_jefe_actual = float(enc["altura_extra"])
		objetivo_rotacion_y = float(enc["yaw"]) if float(enc["peso_yaw"]) > 0.0 else rotation.y
		objetivo_rotacion_x = clampf(float(enc["pitch"]), LIMITE_PITCH_MIN, LIMITE_PITCH_MAX)
	else:
		_jefe_camara_activo = null
		_factor_camara_jefe = 0.0
		_offset_pivote_jefe_actual = Vector3.ZERO
		_distancia_extra_jefe_actual = 0.0
		_altura_extra_jefe_actual = 0.0
		objetivo_rotacion_y = rotation.y
		objetivo_rotacion_x = pitch_defecto

	pivote_camara.global_position = _calcular_pos_pivote_seguimiento()
	pivote_camara.rotation = Vector3(0.0, objetivo_rotacion_y, 0.0)
	var arm = obtener_spring_arm()
	if arm:
		arm.rotation.x = objetivo_rotacion_x
		arm.position.y = obtener_altura_spring_arm_deseada()
		arm.spring_length = obtener_distancia_camara_deseada()
		arm.add_excluded_object(get_rid())
	else:
		pivote_camara.rotation.x = objetivo_rotacion_x
	var cam = obtener_camara()
	if cam:
		cam.v_offset = obtener_v_offset_deseado()
	pivote_camara.force_update_transform()

var camara_config_manager_override: Node = null

func _get_camara_config_manager() -> Node:
	if is_instance_valid(camara_config_manager_override):
		return camara_config_manager_override
	if not is_inside_tree():
		var loop = Engine.get_main_loop()
		if loop is SceneTree and (loop as SceneTree).root:
			return (loop as SceneTree).root.get_node_or_null("CamaraConfigManager")
		return null
	return get_node_or_null("/root/CamaraConfigManager")

func _get_red_manager() -> Node:
	if not is_inside_tree():
		var loop = Engine.get_main_loop()
		if loop is SceneTree and (loop as SceneTree).root:
			return (loop as SceneTree).root.get_node_or_null("RedManager")
		return null
	return get_node_or_null("/root/RedManager")

func _get_score_manager() -> Node:
	if not is_inside_tree():
		var loop = Engine.get_main_loop()
		if loop is SceneTree and (loop as SceneTree).root:
			return (loop as SceneTree).root.get_node_or_null("ScoreManager")
		return null
	return get_node_or_null("/root/ScoreManager")

func _get_vibration_manager() -> Node:
	if not is_inside_tree():
		var loop = Engine.get_main_loop()
		if loop is SceneTree and (loop as SceneTree).root:
			return (loop as SceneTree).root.get_node_or_null("VibrationManager")
		return null
	return get_node_or_null("/root/VibrationManager")

func _ready():
	objetivo_rotacion_y = rotation.y
	objetivo_rotacion_x = PITCH_DEFECTO_CAMARA

	var cam_mgr = _get_camara_config_manager()
	if is_instance_valid(cam_mgr) and cam_mgr.has_signal("camara_estatica_cambiada"):
		if not cam_mgr.camara_estatica_cambiada.is_connected(_on_camara_estatica_cambiada_base):
			cam_mgr.camara_estatica_cambiada.connect(_on_camara_estatica_cambiada_base)

	var spring_arm = obtener_spring_arm()
	if spring_arm:
		spring_arm.add_excluded_object(get_rid())
		if is_inside_tree() and get_tree():
			for e in get_tree().get_nodes_in_group("enemigos_espectrales"):
				if is_instance_valid(e) and e is CollisionObject3D:
					spring_arm.add_excluded_object(e.get_rid())
		spring_arm.spring_length = DISTANCIA_CAMARA
		spring_arm.position.y = ALTURA_SPRING_ARM
		spring_arm.margin = MARGEN_COLISION_CAMARA
		spring_arm.rotation.x = objetivo_rotacion_x
	elif pivote_camara:
		objetivo_rotacion_x = pivote_camara.rotation.x
	else:
		objetivo_rotacion_x = PITCH_DEFECTO_CAMARA

	var cam = obtener_camara()
	if cam:
		cam.v_offset = V_OFFSET_CAMARA

	posicion_inicial = global_position
	rotacion_inicial = rotation
	punto_control = posicion_inicial
	rotacion_punto_control = rotacion_inicial
	rotacion_inicial_camara_x = objetivo_rotacion_x
	sync_position = global_position
	sync_rotation = rotation
	actualizar_visibilidad_local()
	_crear_particulas_corazon_proximidad()
	actualizar_silueta_oclusion()
	_inicializar_sombra_aterrizaje()
	
	# Buscar controles táctiles en el grupo global "ui_tactil"
	if get_tree():
		var nodos_ui = get_tree().get_nodes_in_group("ui_tactil")
		if nodos_ui.size() > 0:
			controles_tactiles = nodos_ui[0]

func es_activo() -> bool:
	var red_mgr = _get_red_manager()
	if is_instance_valid(red_mgr) and (red_mgr.es_un_jugador or multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		var es_fantasma = is_in_group("fantasmas") or name.to_lower().contains("fantasma")
		if red_mgr.personaje_activo_solo == "fantasma":
			return es_fantasma
		else:
			return not es_fantasma
	return is_multiplayer_authority()

func _process(delta: float):
	if es_activo():
		sync_position = global_position
		sync_rotation = rotation
		procesar_camara_base(delta)
	elif multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		# Suavizado de red (Interpolación) solo en multijugador online
		if global_position.distance_squared_to(sync_position) > 16.0:
			global_position = sync_position
			rotation = sync_rotation
		else:
			global_position = global_position.lerp(sync_position, 15.0 * delta)
			rotation.y = lerp_angle(rotation.y, sync_rotation.y, 15.0 * delta)
			rotation.x = lerp_angle(rotation.x, sync_rotation.x, 15.0 * delta)
	actualizar_sombra_aterrizaje()

func _inicializar_sombra_aterrizaje() -> void:
	if is_instance_valid(_mesh_sombra_aterrizaje):
		return
	if _malla_sombra_aterrizaje == null:
		_malla_sombra_aterrizaje = PlaneMesh.new()
		_malla_sombra_aterrizaje.size = Vector2(1.0, 1.0)
	if _textura_sombra_aterrizaje == null:
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.48, 0.78, 1.0])
		grad.colors = PackedColorArray([
			Color(1.0, 1.0, 1.0, 1.0),
			Color(1.0, 1.0, 1.0, 0.85),
			Color(1.0, 1.0, 1.0, 0.25),
			Color(1.0, 1.0, 1.0, 0.0)
		])
		_textura_sombra_aterrizaje = GradientTexture2D.new()
		_textura_sombra_aterrizaje.width = 64
		_textura_sombra_aterrizaje.height = 64
		_textura_sombra_aterrizaje.fill = GradientTexture2D.FILL_RADIAL
		_textura_sombra_aterrizaje.fill_from = Vector2(0.5, 0.5)
		_textura_sombra_aterrizaje.fill_to = Vector2(1.0, 0.5)
		_textura_sombra_aterrizaje.gradient = grad

	_raycast_sombra_aterrizaje = RayCast3D.new()
	_raycast_sombra_aterrizaje.name = "RayCastSombraAterrizaje"
	_raycast_sombra_aterrizaje.position = Vector3(0.0, 0.1, 0.0)
	_raycast_sombra_aterrizaje.target_position = Vector3(0.0, -SOMBRA_DISTANCIA_MAX, 0.0)
	_raycast_sombra_aterrizaje.exclude_parent = true
	_raycast_sombra_aterrizaje.hit_from_inside = false
	_raycast_sombra_aterrizaje.hit_back_faces = false
	_raycast_sombra_aterrizaje.collision_mask = collision_mask
	_raycast_sombra_aterrizaje.enabled = true
	add_child(_raycast_sombra_aterrizaje)

	var es_fant: bool = is_in_group("fantasmas") or name.to_lower().contains("fantasma")
	_material_sombra_aterrizaje = StandardMaterial3D.new()
	_material_sombra_aterrizaje.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material_sombra_aterrizaje.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material_sombra_aterrizaje.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_material_sombra_aterrizaje.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material_sombra_aterrizaje.albedo_texture = _textura_sombra_aterrizaje
	_material_sombra_aterrizaje.albedo_color = Color(0.04, 0.07, 0.16, SOMBRA_OPACIDAD_SUELO) if es_fant else Color(0.08, 0.06, 0.05, SOMBRA_OPACIDAD_SUELO)

	_mesh_sombra_aterrizaje = MeshInstance3D.new()
	_mesh_sombra_aterrizaje.name = "SombraAterrizaje"
	_mesh_sombra_aterrizaje.mesh = _malla_sombra_aterrizaje
	_mesh_sombra_aterrizaje.material_override = _material_sombra_aterrizaje
	_mesh_sombra_aterrizaje.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_sombra_aterrizaje.top_level = true
	_mesh_sombra_aterrizaje.visible = false
	add_child(_mesh_sombra_aterrizaje)

func debe_mostrar_sombra_aterrizaje() -> bool:
	return SOMBRA_ATERRIZAJE_ACTIVA and is_visible_in_tree() and not _vortice_esta_absorbido

func calcular_parametros_sombra_aterrizaje(altura: float) -> Dictionary:
	var t: float = clampf(maxf(0.0, altura) / 10.0, 0.0, 1.0)
	return {
		"escala": SOMBRA_TAMANO_BASE * lerpf(1.0, SOMBRA_ESCALA_MIN_ALTURA, t),
		"opacidad": lerpf(SOMBRA_OPACIDAD_SUELO, SOMBRA_OPACIDAD_AIRE_MIN, t)
	}

func _calcular_basis_alineada_normal(normal: Vector3) -> Basis:
	var up: Vector3 = normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	var ref: Vector3 = Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT
	var right: Vector3 = ref.cross(up).normalized()
	var forward: Vector3 = right.cross(up).normalized()
	return Basis(right, up, forward)

func aplicar_sombra_aterrizaje_en_punto(punto: Vector3, normal: Vector3, altura: float) -> void:
	if not is_instance_valid(_mesh_sombra_aterrizaje):
		return
	var params := calcular_parametros_sombra_aterrizaje(altura)
	var escala: float = float(params["escala"])
	var up: Vector3 = normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	_mesh_sombra_aterrizaje.global_transform = Transform3D(
		_calcular_basis_alineada_normal(up).scaled(Vector3(escala, 1.0, escala)),
		punto + up * SOMBRA_OFFSET_SUPERFICIE
	)
	if is_instance_valid(_material_sombra_aterrizaje):
		_material_sombra_aterrizaje.albedo_color.a = float(params["opacidad"])
	_mesh_sombra_aterrizaje.visible = true

func actualizar_sombra_aterrizaje() -> void:
	if not is_instance_valid(_mesh_sombra_aterrizaje) or not is_instance_valid(_raycast_sombra_aterrizaje):
		return
	if not is_inside_tree() or not debe_mostrar_sombra_aterrizaje():
		_mesh_sombra_aterrizaje.visible = false
		return
	_raycast_sombra_aterrizaje.collision_mask = collision_mask
	_raycast_sombra_aterrizaje.target_position = Vector3(0.0, -SOMBRA_DISTANCIA_MAX, 0.0)
	_raycast_sombra_aterrizaje.force_raycast_update()
	if _raycast_sombra_aterrizaje.is_colliding():
		var punto: Vector3 = _raycast_sombra_aterrizaje.get_collision_point()
		var normal: Vector3 = _raycast_sombra_aterrizaje.get_collision_normal()
		var altura: float = maxf(0.0, (global_position.y - 0.54) - punto.y)
		aplicar_sombra_aterrizaje_en_punto(punto, normal, altura)
	else:
		_mesh_sombra_aterrizaje.visible = false


func _aplicar_pose_camara_estatica_base(cam_mgr: Node, resetear_interp: bool = false) -> void:
	if not pivote_camara or not is_instance_valid(cam_mgr):
		return
	pivote_camara.top_level = true
	pivote_camara.global_position = cam_mgr.obtener_posicion_camara_estatica()
	pivote_camara.rotation = Vector3(0.0, cam_mgr.obtener_rotacion_camara_estatica().y, 0.0)
	var arm = obtener_spring_arm()
	if arm:
		arm.position = Vector3.ZERO
		arm.spring_length = 0.0
		arm.rotation = Vector3(cam_mgr.obtener_rot_x_arm_estatica(), 0.0, 0.0)
		if resetear_interp:
			arm.force_update_transform()
	var cam = obtener_camara()
	if cam:
		cam.position = Vector3.ZERO
		if resetear_interp:
			cam.force_update_transform()
	if resetear_interp:
		pivote_camara.force_update_transform()
		pivote_camara.propagate_call("reset_physics_interpolation")

func esta_en_camara_libre() -> bool:
	var cam_mgr = _get_camara_config_manager()
	return is_instance_valid(cam_mgr) and cam_mgr.has_method("esta_camara_libre_activa") and cam_mgr.esta_camara_libre_activa()

func _on_camara_estatica_cambiada_base(activa: bool) -> void:
	if activa:
		_retornando_de_camara_estatica = false
		if es_activo():
			_aplicar_pose_camara_estatica_base(_get_camara_config_manager(), true)
	else:
		_retornando_de_camara_estatica = true
		var cam_mgr = _get_camara_config_manager()
		if is_instance_valid(cam_mgr):
			objetivo_rotacion_y = cam_mgr.obtener_rotacion_camara_estatica().y
			objetivo_rotacion_x = clampf(cam_mgr.obtener_rot_x_arm_estatica(), LIMITE_PITCH_MIN, LIMITE_PITCH_MAX)

func actualizar_visibilidad_local(preservar_rotacion_camara: bool = false):
	# Lógica base de cámara, los hijos extenderán esto
	var es_mio = es_activo()
	if pivote_camara:
		if es_mio:
			pivote_camara.top_level = true
			var cam_mgr = _get_camara_config_manager()
			var es_estatica = is_instance_valid(cam_mgr) and cam_mgr.has_method("esta_camara_estatica") and cam_mgr.esta_camara_estatica()
			if es_estatica:
				_aplicar_pose_camara_estatica_base(cam_mgr, true)
			else:
				pivote_camara.global_position = _calcular_pos_pivote_seguimiento()
				if not preservar_rotacion_camara:
					objetivo_rotacion_y = rotation.y
					pivote_camara.rotation.y = rotation.y
				else:
					pivote_camara.rotation.y = objetivo_rotacion_y
				var arm = obtener_spring_arm()
				if arm:
					arm.add_excluded_object(get_rid())
					if is_inside_tree() and get_tree():
						for e in get_tree().get_nodes_in_group("enemigos_espectrales"):
							if is_instance_valid(e) and e is CollisionObject3D:
								arm.add_excluded_object(e.get_rid())
					arm.rotation.x = objetivo_rotacion_x
					arm.position.y = obtener_altura_spring_arm_deseada()
					arm.spring_length = obtener_distancia_camara_deseada()
				else:
					pivote_camara.rotation.x = objetivo_rotacion_x
		else:
			pivote_camara.top_level = false
			
		var cam = obtener_camara()
		if cam:
			cam.current = es_mio
			cam.v_offset = obtener_v_offset_deseado()
			if es_mio:
				aplicar_vista_camara_activa()

func aplicar_vista_camara_activa() -> void:
	var cam := obtener_camara()
	if not is_instance_valid(cam):
		return
	var red_mgr := _get_red_manager()
	if is_instance_valid(red_mgr) and red_mgr.has_method("configurar_camara_segun_vista"):
		red_mgr.configurar_camara_segun_vista(cam, self)
	else:
		cam.environment = obtener_entorno_personaje()
		cam.cull_mask = obtener_cull_mask_personaje()

func obtener_entorno_personaje() -> Environment:
	return null

func obtener_cull_mask_personaje() -> int:
	return 1048575

func entrada_bloqueada() -> bool:
	if not is_inside_tree():
		return true
	var score_mgr = _get_score_manager()
	if is_instance_valid(score_mgr) and not score_mgr.cronometro_activo and score_mgr.tiempo_transcurrido > 0.0:
		return true
	var tree = get_tree()
	if tree and tree.current_scene:
		if tree.current_scene.has_node("CanvasResultados") or tree.current_scene.has_node("PantallaResultados"):
			return true
		if tree.current_scene is NivelBase and tree.current_scene.intro_en_curso:
			return true
	if is_instance_valid(controles_tactiles) and controles_tactiles.has_method("esta_bloqueado_para_juego"):
		if controles_tactiles.esta_bloqueado_para_juego():
			return true
	return false

func _obtener_dispositivo_mando_activo() -> int:
	if is_inside_tree() and get_tree() and get_tree().root and get_tree().root.has_node("GamepadManager"):
		return get_tree().root.get_node("GamepadManager").dispositivo_activo
	return 0

func _boton_mando_libre_para_camara(boton: JoyButton) -> bool:
	if is_inside_tree() and get_tree() and get_tree().root and get_tree().root.has_node("GamepadManager"):
		var gm = get_tree().root.get_node("GamepadManager")
		if gm.get("mapeos_actuales") is Dictionary:
			for data in gm.mapeos_actuales.values():
				if data is Dictionary and data.get("tipo") == "button" and int(data.get("indice", -1)) == int(boton):
					return false
	return true

func _calcular_delta_rotacion_bumpers_y(lb_presionado: bool, rb_presionado: bool, delta: float) -> float:
	var dir_y: float = 0.0
	if lb_presionado:
		dir_y += 1.0
	if rb_presionado:
		dir_y -= 1.0
	return dir_y * VELOCIDAD_ROTACION_BUMPERS_Y * delta

func _obtener_delta_rotacion_bumpers_y(dev_cam: int, delta: float) -> float:
	var lb_activo: bool = _boton_mando_libre_para_camara(JOY_BUTTON_LEFT_SHOULDER) and Input.is_joy_button_pressed(dev_cam, JOY_BUTTON_LEFT_SHOULDER)
	var rb_activo: bool = _boton_mando_libre_para_camara(JOY_BUTTON_RIGHT_SHOULDER) and Input.is_joy_button_pressed(dev_cam, JOY_BUTTON_RIGHT_SHOULDER)
	return _calcular_delta_rotacion_bumpers_y(lb_activo, rb_activo, delta)

func _calcular_curva_gatillo_camara(valor: float) -> float:
	if valor <= 0.05:
		return 0.0
	var normalizado := clampf((valor - 0.05) / 0.95, 0.0, 1.0)
	return normalizado * normalizado

func _procesar_control_camara_libre(delta: float, cam_mgr: Node) -> void:
	if not es_activo() or entrada_bloqueada():
		return

	if not controles_tactiles:
		var nodos_ui = get_tree().get_nodes_in_group("ui_tactil")
		if nodos_ui.size() > 0:
			controles_tactiles = nodos_ui[0]

	var dev_cam: int = _obtener_dispositivo_mando_activo()

	# 1. Rotación con Joystick Derecho + arrastre táctil
	var delta_yaw: float = 0.0
	var delta_pitch: float = 0.0
	var stick_cam_x = Input.get_joy_axis(dev_cam, JOY_AXIS_RIGHT_X)
	var stick_cam_y = Input.get_joy_axis(dev_cam, JOY_AXIS_RIGHT_Y)
	var stick_cam_vec = Vector2(stick_cam_x, stick_cam_y)
	var deadzone_cam := 0.15
	if stick_cam_vec.length() > deadzone_cam:
		var factor_rot = (stick_cam_vec.length() - deadzone_cam) / (1.0 - deadzone_cam)
		var dir_rot = stick_cam_vec.normalized() * factor_rot
		var vel_rot_mando := 2.4
		delta_yaw -= dir_rot.x * vel_rot_mando * delta
		delta_pitch -= dir_rot.y * vel_rot_mando * delta

	if controles_tactiles:
		var giro = controles_tactiles.consumir_arrastre()
		if giro != Vector2.ZERO:
			delta_yaw -= giro.x * SENSIBILIDAD_CAMARA
			delta_pitch -= giro.y * SENSIBILIDAD_CAMARA
		if controles_tactiles.has_method("consumir_centrado_camara"):
			controles_tactiles.consumir_centrado_camara()

	if delta_yaw != 0.0 or delta_pitch != 0.0:
		if cam_mgr.has_method("rotar_camara_estatica"):
			cam_mgr.rotar_camara_estatica(delta_yaw, delta_pitch)
		else:
			cam_mgr.rotar_camara_estatica_y(delta_yaw)
			cam_mgr.establecer_rot_x_arm_estatica(cam_mgr.obtener_rot_x_arm_estatica() + delta_pitch)

	# 2. Traslación libre con Joystick Izquierdo / WASD / Joystick táctil en la orientación de la cámara
	var input_mov := Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras", 0.05)
	var trigger_lt := Input.get_joy_axis(dev_cam, JOY_AXIS_TRIGGER_LEFT)
	var trigger_rt := Input.get_joy_axis(dev_cam, JOY_AXIS_TRIGGER_RIGHT)

	var vel_desp := 6.5
	if Input.is_key_pressed(KEY_SHIFT):
		vel_desp *= 2.2

	var rot_yaw: float = cam_mgr.obtener_rotacion_camara_estatica().y
	var rot_pitch: float = cam_mgr.obtener_rot_x_arm_estatica()
	var cam_basis := Basis.from_euler(Vector3(rot_pitch, rot_yaw, 0.0), EULER_ORDER_YXZ)
	var cam_right := cam_basis.x
	var cam_forward := -cam_basis.z

	var delta_pos := Vector3.ZERO
	if input_mov != Vector2.ZERO:
		delta_pos += (cam_right * input_mov.x + cam_forward * (-input_mov.y)) * (vel_desp * delta)

	# 3. Elevación vertical analógica progresiva según presión del gatillo (RT sube, LT baja; Space/E y Q/Ctrl en teclado)
	var elevacion_analog := _calcular_curva_gatillo_camara(trigger_rt) - _calcular_curva_gatillo_camara(trigger_lt)
	var elevacion_tecla := 0.0
	if Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_E):
		elevacion_tecla += 1.0
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_CTRL):
		elevacion_tecla -= 1.0
	if not is_zero_approx(elevacion_analog):
		var vel_vertical_max := 8.5
		if Input.is_key_pressed(KEY_SHIFT):
			vel_vertical_max *= 1.8
		delta_pos += Vector3.UP * (clampf(elevacion_analog, -1.0, 1.0) * vel_vertical_max * delta)
	elif elevacion_tecla != 0.0:
		delta_pos += Vector3.UP * (clampf(elevacion_tecla, -1.0, 1.0) * vel_desp * delta)

	if delta_pos != Vector3.ZERO:
		cam_mgr.mover_posicion_camara_estatica(delta_pos)

func procesar_camara_base(delta: float):
	if not es_activo() or entrada_bloqueada(): return
	var red_mgr = _get_red_manager()
	if is_instance_valid(red_mgr) and red_mgr.transicion_en_progreso: return

	if pivote_camara == null:
		pivote_camara = get_node_or_null("Node3D")

	if pivote_camara:
		var cam_mgr = _get_camara_config_manager()
		var es_estatica = is_instance_valid(cam_mgr) and cam_mgr.has_method("esta_camara_estatica") and cam_mgr.esta_camara_estatica()
		if es_estatica:
			if cam_mgr.has_method("esta_camara_libre_activa") and cam_mgr.esta_camara_libre_activa():
				_procesar_control_camara_libre(delta, cam_mgr)
			_aplicar_pose_camara_estatica_base(cam_mgr, false)
			return
		elif _retornando_de_camara_estatica:
			pivote_camara.global_position = pivote_camara.global_position.lerp(global_position, 8.0 * delta)
			if pivote_camara.global_position.distance_squared_to(global_position) < 0.12:
				_retornando_de_camara_estatica = false

		if _vortice_esta_absorbido:
			# Mantener la cámara exactamente en la posición en la que quedó al ser absorbido (sin zoom brusco ni saltos)
			pivote_camara.global_position = _pos_camara_fija_vortice
			pivote_camara.rotation = _rot_camara_fija_vortice
			var arm = obtener_spring_arm()
			if arm:
				arm.rotation.x = _rot_x_arm_fija_vortice
			return
		elif _camara_fijada_en_vortice:
			# Si el personaje fue expulsado y cae hacia el vacío con impulso vertical descendente o caída libre,
			# mantener la cámara fija en el punto de observación del vórtice viendo caer al personaje.
			# Esto evita sumergir la cámara en el abismo, colisionar bajo el suelo o mostrar un frame anómalo antes de reaparecer.
			var en_caida_al_vacio = _tiempo_impulso_caida > 0.0 or velocity.y < -4.5 or global_position.y < (LIMITE_CAIDA_Y + 2.0)
			if en_caida_al_vacio and not is_on_floor():
				pivote_camara.global_position = _pos_camara_fija_vortice
				pivote_camara.rotation = _rot_camara_fija_vortice
				var arm = obtener_spring_arm()
				if arm:
					arm.rotation.x = _rot_x_arm_fija_vortice
				return
			else:
				# Si aterrizó en plataforma o se estabilizó volando seguro, retornar suavemente hacia el personaje
				pivote_camara.global_position = pivote_camara.global_position.lerp(global_position, 8.0 * delta)
				if pivote_camara.global_position.distance_squared_to(global_position) < 0.12:
					_camara_fijada_en_vortice = false
		elif _camara_fijada_en_caida:
			# Mantener la cámara fija en la posición donde cayó el personaje tras desactivarse la plataforma
			# (comportamiento idéntico al vórtice/tornado, evitando sumergirse, atravesar la plataforma o zoom brusco)
			if not is_on_floor():
				pivote_camara.global_position = _pos_camara_fija_caida
				pivote_camara.rotation = _rot_camara_fija_caida
				var arm = obtener_spring_arm()
				if arm:
					arm.rotation.x = _rot_x_arm_fija_caida
				return
			else:
				# Si aterrizó en otra plataforma o suelo firme, retornar suavemente hacia el personaje
				pivote_camara.global_position = pivote_camara.global_position.lerp(global_position, 8.0 * delta)
				if pivote_camara.global_position.distance_squared_to(global_position) < 0.12:
					_camara_fijada_en_caida = false
		else:
			_jefe_camara_activo = obtener_jefe_camara_activo()
			var tiene_jefe: bool = is_instance_valid(_jefe_camara_activo)
			var k_factor: float = clampf(3.5 * delta, 0.0, 1.0)
			_factor_camara_jefe = lerpf(_factor_camara_jefe, 1.0 if tiene_jefe else 0.0, k_factor)
			_tiempo_pausa_camara_jefe = maxf(0.0, _tiempo_pausa_camara_jefe - delta)

			var enc_jefe := {}
			if tiene_jefe:
				enc_jefe = calcular_encuadre_camara_jefe(_jefe_camara_activo)
				_offset_pivote_jefe_actual = _offset_pivote_jefe_actual.lerp(enc_jefe["offset_pivote"], k_factor)
				_distancia_extra_jefe_actual = lerpf(_distancia_extra_jefe_actual, float(enc_jefe["distancia_extra"]), k_factor)
				_altura_extra_jefe_actual = lerpf(_altura_extra_jefe_actual, float(enc_jefe["altura_extra"]), k_factor)
			else:
				_offset_pivote_jefe_actual = _offset_pivote_jefe_actual.lerp(Vector3.ZERO, k_factor)
				_distancia_extra_jefe_actual = lerpf(_distancia_extra_jefe_actual, 0.0, k_factor)
				_altura_extra_jefe_actual = lerpf(_altura_extra_jefe_actual, 0.0, k_factor)

			# Al seguir normalmente al jugador, evitar que la cámara descienda a las profundidades del abismo si cae al vacío
			pivote_camara.global_position = _calcular_pos_pivote_seguimiento()

		# Buscar controles táctiles si aún no se han referenciado
		if not controles_tactiles:
			var nodos_ui = get_tree().get_nodes_in_group("ui_tactil")
			if nodos_ui.size() > 0:
				controles_tactiles = nodos_ui[0]

		# Comprobar gesto de doble toque táctil o tecla R en PC para centrado instantáneo
		var solicito_centrado = false
		if controles_tactiles and controles_tactiles.has_method("consumir_centrado_camara"):
			solicito_centrado = controles_tactiles.consumir_centrado_camara()
		
		if not solicito_centrado:
			if InputMap.has_action("centrar_camara") and Input.is_action_just_pressed("centrar_camara"):
				solicito_centrado = true
			elif Input.is_physical_key_pressed(KEY_R):
				solicito_centrado = true

		if solicito_centrado:
			centrar_camara_inmediatamente()

		var hubo_input_manual_camara: bool = false
		if controles_tactiles:
			var giro = controles_tactiles.consumir_arrastre()
			if giro != Vector2.ZERO:
				objetivo_rotacion_y -= giro.x * SENSIBILIDAD_CAMARA
				objetivo_rotacion_x = clamp(objetivo_rotacion_x - giro.y * SENSIBILIDAD_CAMARA, LIMITE_PITCH_MIN, LIMITE_PITCH_MAX)
				hubo_input_manual_camara = true

		# Control de rotación con stick derecho y bumpers (LB / RB) de control / gamepad
		var dev_cam: int = _obtener_dispositivo_mando_activo()
		var stick_cam_x = Input.get_joy_axis(dev_cam, JOY_AXIS_RIGHT_X)
		var stick_cam_y = Input.get_joy_axis(dev_cam, JOY_AXIS_RIGHT_Y)
		var stick_vec = Vector2(stick_cam_x, stick_cam_y)
		var deadzone_cam = 0.20
		if stick_vec.length() > deadzone_cam:
			var factor_cam = (stick_vec.length() - deadzone_cam) / (1.0 - deadzone_cam)
			var dir_cam = stick_vec.normalized() * factor_cam
			var vel_cam_yaw = 3.0 # Radianes por segundo
			var vel_cam_pitch = 1.45
			objetivo_rotacion_y = wrapf(objetivo_rotacion_y - dir_cam.x * vel_cam_yaw * delta, -PI, PI)
			if not (absf(dir_cam.y) < 0.35 and absf(dir_cam.x) > 0.55):
				objetivo_rotacion_x = clamp(objetivo_rotacion_x - dir_cam.y * vel_cam_pitch * delta, LIMITE_PITCH_MIN, LIMITE_PITCH_MAX)
			hubo_input_manual_camara = true

		var delta_bumpers_y: float = _obtener_delta_rotacion_bumpers_y(dev_cam, delta)
		if not is_zero_approx(delta_bumpers_y):
			objetivo_rotacion_y += delta_bumpers_y
			hubo_input_manual_camara = true

		if hubo_input_manual_camara and is_instance_valid(_jefe_camara_activo):
			_tiempo_pausa_camara_jefe = PAUSA_MANUAL_CAMARA_JEFE

		if is_instance_valid(_jefe_camara_activo) and _tiempo_pausa_camara_jefe <= 0.0 and not solicito_centrado:
			var enc_auto := calcular_encuadre_camara_jefe(_jefe_camara_activo)
			var intensidad_cam: float = float(enc_auto["intensidad"])
			var k_auto: float = 1.0 - exp(-SUAVIDAD_AUTO_CAMARA_JEFE * intensidad_cam * delta)
			var peso_yaw: float = float(enc_auto["peso_yaw"])
			var en_el_aire_jugando: bool = (not is_on_floor()) and (absf(velocity.y) > 0.25 or tiempo_desde_suelo > 0.12)
			if peso_yaw > 0.0:
				var yaw_obj: float = float(enc_auto["yaw"])
				var diff_yaw: float = angle_difference(objetivo_rotacion_y, yaw_obj)
				var vel_horiz: float = Vector2(velocity.x, velocity.z).length()
				if en_el_aire_jugando:
					if absf(diff_yaw) > ZONA_MUERTA_YAW_CAMARA_JEFE:
						var yaw_borde_aire: float = yaw_obj - signf(diff_yaw) * ZONA_MUERTA_YAW_CAMARA_JEFE
						objetivo_rotacion_y = lerp_angle(objetivo_rotacion_y, yaw_borde_aire, k_auto * peso_yaw * 0.55)
				elif intensidad_cam > 1.05 or vel_horiz < 0.3:
					objetivo_rotacion_y = lerp_angle(objetivo_rotacion_y, yaw_obj, k_auto * peso_yaw)
				elif absf(diff_yaw) > ZONA_MUERTA_YAW_CAMARA_JEFE:
					var yaw_borde: float = yaw_obj - signf(diff_yaw) * ZONA_MUERTA_YAW_CAMARA_JEFE
					objetivo_rotacion_y = lerp_angle(objetivo_rotacion_y, yaw_borde, k_auto * peso_yaw)
			objetivo_rotacion_x = clampf(lerpf(objetivo_rotacion_x, float(enc_auto["pitch"]), k_auto * 0.85), LIMITE_PITCH_MIN, LIMITE_PITCH_MAX)
		elif not is_instance_valid(_jefe_camara_activo) and _factor_camara_jefe > 0.02 and not hubo_input_manual_camara and not solicito_centrado:
			objetivo_rotacion_x = lerpf(objetivo_rotacion_x, PITCH_DEFECTO_CAMARA, clampf(4.0 * delta, 0.0, 1.0))

		var suavizado_camara = 1.0 - exp(-SUAVIDAD_CAMARA * delta)
		pivote_camara.rotation.y = lerp_angle(pivote_camara.rotation.y, objetivo_rotacion_y, suavizado_camara)
		
		var arm = obtener_spring_arm()
		if arm:
			pivote_camara.rotation.x = 0.0
			arm.rotation.x = lerp_angle(arm.rotation.x, objetivo_rotacion_x, suavizado_camara)
			var vel_trans_arm: float = 6.0 * delta if esta_enfocando_jefe() else 8.0 * delta
			var target_arm_y = obtener_altura_spring_arm_deseada()
			var target_arm_dist = obtener_distancia_camara_deseada()
			if absf(arm.position.y - target_arm_y) > 0.002:
				arm.position.y = lerp(arm.position.y, target_arm_y, vel_trans_arm)
			else:
				arm.position.y = target_arm_y
			if absf(arm.spring_length - target_arm_dist) > 0.002:
				arm.spring_length = lerp(arm.spring_length, target_arm_dist, vel_trans_arm)
			else:
				arm.spring_length = target_arm_dist
		else:
			pivote_camara.rotation.x = lerp_angle(pivote_camara.rotation.x, objetivo_rotacion_x, suavizado_camara)

		var cam = obtener_camara()
		if cam:
			var target_v_offset = obtener_v_offset_deseado()
			if absf(cam.v_offset - target_v_offset) > 0.002:
				cam.v_offset = lerp(cam.v_offset, target_v_offset, 8.0 * delta)
			else:
				cam.v_offset = target_v_offset

func _obtener_medida_camara_deseada(metodo_mgr: String, valor_defecto: float, extra_jefe: float) -> float:
	var valor_base: float = valor_defecto
	var mgr := _get_camara_config_manager()
	if is_instance_valid(mgr):
		var es_estatica: bool = mgr.has_method("esta_camara_estatica") and mgr.esta_camara_estatica()
		if mgr.has_method(metodo_mgr):
			var v: Variant = mgr.call(metodo_mgr)
			if v != null:
				valor_base = float(v)
		if es_estatica:
			return valor_base
	return valor_base + (extra_jefe * _factor_camara_jefe)

func obtener_distancia_camara_deseada() -> float:
	return _obtener_medida_camara_deseada("obtener_distancia_camara", DISTANCIA_CAMARA, _distancia_extra_jefe_actual)

func obtener_altura_spring_arm_deseada() -> float:
	return _obtener_medida_camara_deseada("obtener_altura_spring_arm", ALTURA_SPRING_ARM, _altura_extra_jefe_actual)

func obtener_v_offset_deseado() -> float:
	var mgr = _get_camara_config_manager()
	if is_instance_valid(mgr) and mgr.has_method("obtener_v_offset"):
		return mgr.obtener_v_offset()
	return V_OFFSET_CAMARA

func _unhandled_input(event: InputEvent) -> void:
	if not es_activo() or entrada_bloqueada():
		return
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if esta_en_camara_libre():
				var cam_mgr = _get_camara_config_manager()
				if is_instance_valid(cam_mgr) and cam_mgr.has_method("rotar_camara_estatica"):
					cam_mgr.rotar_camara_estatica(-event.relative.x * SENSIBILIDAD_CAMARA, -event.relative.y * SENSIBILIDAD_CAMARA)
			else:
				objetivo_rotacion_y -= event.relative.x * SENSIBILIDAD_CAMARA
				objetivo_rotacion_x = clamp(objetivo_rotacion_x - event.relative.y * SENSIBILIDAD_CAMARA, LIMITE_PITCH_MIN, LIMITE_PITCH_MAX)
				if event.relative != Vector2.ZERO and is_instance_valid(_jefe_camara_activo):
					_tiempo_pausa_camara_jefe = PAUSA_MANUAL_CAMARA_JEFE

func esta_planeando() -> bool:
	if movimiento_bloqueado or _vortice_esta_absorbido or esta_en_camara_libre():
		return false
	if not PUEDE_PLANEAR or is_on_floor():
		return false
	if not es_activo() or entrada_bloqueada():
		return false
	var red_mgr = _get_red_manager()
	if is_instance_valid(red_mgr) and red_mgr.transicion_en_progreso:
		return false
	var salto_mantenido = Input.is_action_pressed("saltar") or Input.is_action_pressed("ui_accept")
	return salto_mantenido and velocity.y <= 0.0

func procesar_salto_base(delta: float):
	if movimiento_bloqueado or _vortice_esta_absorbido:
		_arrastre_descendente_vortice = 0.0
		return

	var salto_mantenido = es_activo() and not entrada_bloqueada() and not esta_en_camara_libre() and (Input.is_action_pressed("saltar") or Input.is_action_pressed("ui_accept"))
	var planeando = esta_planeando()
	if not is_on_floor():
		var gravedad_actual = gravity
		# Suspensión en el ápice (Apex Hang / Float) al alcanzar la cima del salto
		if absf(velocity.y) < UMBRAL_VELOCIDAD_APICE and salto_mantenido and MULTIPLICADOR_GRAVEDAD_APICE < 1.0:
			gravedad_actual *= MULTIPLICADOR_GRAVEDAD_APICE
		elif planeando:
			gravedad_actual *= MULTIPLICADOR_CAIDA_PLANEO
		elif velocity.y < 0.0:
			gravedad_actual *= MULTIPLICADOR_CAIDA
		elif velocity.y > 0.0:
			gravedad_actual *= MULTIPLICADOR_GRAVEDAD_SUBIDA
			if not salto_mantenido and MULTIPLICADOR_CORTE_SALTO > 1.0:
				gravedad_actual *= MULTIPLICADOR_CORTE_SALTO

		velocity.y -= gravedad_actual * delta
		
		# Aplicar arrastre descendente del torbellino si está en su rango
		if _arrastre_descendente_vortice > 0.0:
			velocity.y -= _arrastre_descendente_vortice * delta
			var vel_max_arrastre = maxf(VELOCIDAD_MAX_CAIDA_PLANEO, _arrastre_descendente_vortice * 0.45)
			if planeando:
				velocity.y = maxf(velocity.y, -vel_max_arrastre)
			_arrastre_descendente_vortice = 0.0
		elif planeando:
			# Si el jugador decide abrir sus alas/planear, interrumpe el picado forzado para salvarse
			_tiempo_impulso_caida = 0.0
			_vel_max_caida_impulso = 0.0
			# Frenado suave amortiguado si se empieza a planear a alta velocidad de caída
			if velocity.y < -VELOCIDAD_MAX_CAIDA_PLANEO:
				velocity.y = move_toward(velocity.y, -VELOCIDAD_MAX_CAIDA_PLANEO, SUAVIDAD_FRENADO_PLANEO * delta)
			else:
				velocity.y = maxf(velocity.y, -VELOCIDAD_MAX_CAIDA_PLANEO)
		elif _tiempo_impulso_caida > 0.0:
			# Impulso de expulsión por debajo del torbellino: permite caer velozmente con gran impulso
			_tiempo_impulso_caida -= delta
			var vel_terminal_efectiva = maxf(VELOCIDAD_MAX_CAIDA, _vel_max_caida_impulso)
			velocity.y = maxf(velocity.y, -vel_terminal_efectiva)
			_vel_max_caida_impulso = move_toward(_vel_max_caida_impulso, VELOCIDAD_MAX_CAIDA, 8.0 * delta)
		elif VELOCIDAD_MAX_CAIDA > 0.0:
			velocity.y = maxf(velocity.y, -VELOCIDAD_MAX_CAIDA)
			
		tiempo_desde_suelo += delta
		# Si se cae de una plataforma y expira el tiempo coyote, se consume el salto del suelo
		if tiempo_desde_suelo > TIEMPO_COYOTE and saltos_realizados == 0:
			saltos_realizados = 1
	else:
		en_vuelo_balistico = false
		_tiempo_impulso_caida = 0.0
		_vel_max_caida_impulso = 0.0
		if tiempo_desde_suelo > 0.08 and _vel_y_previa_base < -1.6:
			_al_aterrizar_base(_vel_y_previa_base)
		tiempo_desde_suelo = 0.0
		saltos_realizados = 0

	_vel_y_previa_base = velocity.y

	var red_mgr = _get_red_manager()
	if not es_activo() or entrada_bloqueada() or esta_en_camara_libre() or (is_instance_valid(red_mgr) and red_mgr.transicion_en_progreso):
		return

	if Input.is_action_just_pressed("saltar") or Input.is_action_just_pressed("ui_accept"):
		tiempo_desde_salto = 0.0
	else:
		tiempo_desde_salto += delta

	if tiempo_desde_salto <= TIEMPO_BUFFER_SALTO:
		if esta_derrapando and (is_on_floor() or tiempo_desde_suelo <= TIEMPO_COYOTE):
			# Side Flip / Salto Invertido Acrobático tipo Odyssey
			esta_derrapando = false
			tiempo_derrape_restante = 0.0
			velocity.y = FUERZA_SALTO * 1.18
			var dir_mov = obtener_direccion_movimiento()
			if dir_mov != Vector3.ZERO:
				velocity.x = dir_mov.x * 6.5
				velocity.z = dir_mov.z * 6.5
			saltos_realizados = 1
			tiempo_desde_salto = TIEMPO_BUFFER_SALTO + 0.1
			_al_realizar_salto_derrape()
		elif (is_on_floor() or tiempo_desde_suelo <= TIEMPO_COYOTE) and saltos_realizados == 0:
			velocity.y = FUERZA_SALTO
			saltos_realizados = 1
			tiempo_desde_salto = TIEMPO_BUFFER_SALTO + 0.1 # Consumir buffer
			_al_realizar_salto(1)
		elif saltos_realizados < MAX_SALTOS and not (PUEDE_PLANEAR and not is_on_floor()):
			velocity.y = FUERZA_SALTO * MULTIPLICADOR_SEGUNDO_SALTO
			saltos_realizados += 1
			tiempo_desde_salto = TIEMPO_BUFFER_SALTO + 0.1 # Consumir buffer
			_al_realizar_salto(saltos_realizados)

func _al_aterrizar_base(vel_y: float) -> void:
	var vib_mgr = _get_vibration_manager()
	if es_activo() and is_instance_valid(vib_mgr):
		var factor = clampf(abs(vel_y) / 8.0, 0.4, 1.8)
		vib_mgr.vibrar_aterrizaje(factor)
	_al_aterrizar(vel_y)

func _al_aterrizar(_vel_y: float) -> void:
	# Hook virtual para subclases (Squash & Stretch y efectos de impacto/aterrizaje)
	pass

func _al_iniciar_derrape(_velocidad: float, _direccion_input: Vector3) -> void:
	# Hook virtual para inicio de derrape
	pass

func _al_procesar_derrape(_delta: float, _velocidad: float) -> void:
	# Hook virtual para avance continuo del derrape
	pass

func _al_finalizar_derrape() -> void:
	# Hook virtual para fin de derrape
	pass

func _al_realizar_salto_derrape() -> void:
	# Hook virtual para salto invertido (Side Flip) tras derrape
	_al_realizar_salto(1)

func _al_realizar_salto(numero_salto: int):
	# Feedback háptico y vibración de salto
	var vib_mgr = _get_vibration_manager()
	if es_activo() and is_instance_valid(vib_mgr):
		vib_mgr.vibrar_salto(numero_salto)

func calcular_direccion_movimiento_con_input(input_dir: Vector2) -> Vector3:
	if input_dir == Vector2.ZERO:
		_movimiento_anclado_activo = false
		_ultimo_input_mov_2d = Vector2.ZERO
		return Vector3.ZERO

	var cam_basis = Basis()
	if pivote_camara:
		if esta_enfocando_jefe():
			var input_norm: Vector2 = input_dir.normalized()
			var yaw_cam_actual: float = pivote_camara.global_rotation.y if pivote_camara.is_inside_tree() else pivote_camara.rotation.y
			var pausa_manual_activa: bool = _tiempo_pausa_camara_jefe > 0.0
			var cambio_input: bool = _ultimo_input_mov_2d.length_squared() > 0.01 and _ultimo_input_mov_2d.dot(input_norm) < 0.9945
			var deriva_camara_grande: bool = _movimiento_anclado_activo and absf(angle_difference(_yaw_movimiento_anclado, yaw_cam_actual)) > 0.42
			if not _movimiento_anclado_activo or cambio_input or pausa_manual_activa or deriva_camara_grande:
				_yaw_movimiento_anclado = yaw_cam_actual
				_ultimo_input_mov_2d = input_norm
			cam_basis = Basis(Vector3.UP, _yaw_movimiento_anclado)
			_movimiento_anclado_activo = true
		else:
			_movimiento_anclado_activo = false
			_ultimo_input_mov_2d = input_dir.normalized()
			cam_basis = pivote_camara.global_transform.basis if pivote_camara.is_inside_tree() else pivote_camara.transform.basis
	else:
		_movimiento_anclado_activo = false
		cam_basis = global_transform.basis if is_inside_tree() else transform.basis

	var forward = cam_basis.z
	var right = cam_basis.x

	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var move_dir = right * input_dir.x + forward * input_dir.y
	var input_len = input_dir.length()
	if move_dir.is_zero_approx():
		return Vector3.ZERO

	return move_dir.normalized() * clampf(input_len, 0.0, 1.0)

func obtener_direccion_movimiento() -> Vector3:
	if movimiento_bloqueado or entrada_bloqueada() or esta_en_camara_libre():
		_movimiento_anclado_activo = false
		_ultimo_input_mov_2d = Vector2.ZERO
		return Vector3.ZERO

	var input_dir = Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras", 0.05)
	return calcular_direccion_movimiento_con_input(input_dir)

func aplicar_friccion_y_movimiento(direccion: Vector3, delta: float):
	if _vortice_esta_absorbido:
		var offset_visual_y = 0.0
		if is_instance_valid(_nodo_vortice_origen):
			_centro_absorcion = _nodo_vortice_origen.global_position
			if _nodo_vortice_origen.has_node("Visual"):
				offset_visual_y = _nodo_vortice_origen.get_node("Visual").position.y
			var esc_y = _nodo_vortice_origen.global_basis.get_scale().y
			_altura_vortice = (_nodo_vortice_origen.get("altura_tornado") if _nodo_vortice_origen.get("altura_tornado") != null else 5.2) * esc_y
			_y_salida_vortice = (_centro_absorcion.y + offset_visual_y) - (_altura_vortice * 0.5) - 0.35
			
		_tiempo_absorcion_restante -= delta
		var progreso = 1.0 - clampf(_tiempo_absorcion_restante / _duracion_absorcion_total, 0.0, 1.0)
		
		# 1. Rotación: Entre más abajo del tornado va, más rápido gira
		# Inicia en 12.0 rad/s y se acelera progresivamente hasta 38.0 rad/s en el cono inferior
		var vel_giro_actual = lerpf(12.0, 38.0, progreso * progreso)
		_velocidad_giro_absorcion = vel_giro_actual
		_angulo_giro_absorcion += vel_giro_actual * delta
		
		# 2. Descenso vertical continuo desde la entrada hasta salir por debajo
		var target_y = lerpf(_y_entrada_vortice, _y_salida_vortice, progreso)
		
		# 3. Embudo interior: calcular el radio del cono en la altura actual
		var y_base_vortice = (_centro_absorcion.y + offset_visual_y) - (_altura_vortice * 0.5)
		var t_cono = clampf((target_y - y_base_vortice) / maxf(_altura_vortice, 0.001), 0.0, 1.0)
		var r_cono_actual = lerpf(0.45, 2.4, t_cono)
		
		# Radio objetivo dentro del ojo interior del torbellino (38% del radio del cono en esa cota)
		var r_interior_tornado = r_cono_actual * 0.38
		
		# Transición veloz y suave hacia el ojo interior del vórtice (en los primeros ~0.15s)
		var t_succion = clampf(progreso * 5.0, 0.0, 1.0)
		var factor_inward = 1.0 - pow(1.0 - t_succion, 3.0)
		_radio_orbita_absorcion = lerpf(_radio_inicial_absorcion, r_interior_tornado, factor_inward)
		
		var target_x = _centro_absorcion.x + sin(_angulo_giro_absorcion) * _radio_orbita_absorcion
		var target_z = _centro_absorcion.z - cos(_angulo_giro_absorcion) * _radio_orbita_absorcion
		
		var destino = Vector3(target_x, target_y, target_z)
		velocity = (destino - global_position) / maxf(delta, 0.001)
		move_and_slide()
		
		# Orientar visualmente al personaje hacia la dirección tangencial del giro
		var dir_vel = Vector2(velocity.x, velocity.z)
		if dir_vel.length_squared() > 0.01:
			var target_rot = atan2(-velocity.x, -velocity.z)
			rotation.y = lerp_angle(rotation.y, target_rot, 25.0 * delta)
		
		# Al expirar la duración o alcanzar la salida inferior, expulsar con impulso
		if _tiempo_absorcion_restante <= 0.0:
			_vortice_esta_absorbido = false
			_nodo_vortice_origen = null
			velocity = _impulso_expulsion_pendiente
			_fuerza_vortice_acumulada = Vector3.ZERO
			
			# Configurar impulso de caída rápida
			_tiempo_impulso_caida = 1.0
			_vel_max_caida_impulso = absf(_impulso_expulsion_pendiente.y)
			
			fantasma_expulsado_de_vortice.emit(_impulso_expulsion_pendiente)
		
		_comprobar_caida_vacio()
		
		# Mantener la cámara fija en la posición en la que quedó al ser absorbido
		if _vortice_esta_absorbido and es_activo() and pivote_camara and pivote_camara.top_level:
			pivote_camara.global_position = _pos_camara_fija_vortice
			pivote_camara.rotation = _rot_camara_fija_vortice
			var arm = obtener_spring_arm()
			if arm:
				arm.rotation.x = _rot_x_arm_fija_vortice
		return

	var planeando = esta_planeando()
	var vel_max = VELOCIDAD * (MULTIPLICADOR_VELOCIDAD_PLANEO if planeando else 1.0)
	var vel_horizontal = Vector2(velocity.x, velocity.z)

	# Conservación de inercia aérea (Momentum tipo Odyssey)
	if not is_on_floor() and vel_horizontal.length() > vel_max:
		var dir_h = Vector2(direccion.x, direccion.z)
		if dir_h != Vector2.ZERO and vel_horizontal.normalized().dot(dir_h.normalized()) > 0.2:
			vel_max = maxf(vel_max, vel_horizontal.length() - (3.5 * delta))

	var velocidad_objetivo = direccion * vel_max
	var tasa_aceleracion = ACELERACION_SUELO if is_on_floor() else (ACELERACION_AIRE * (MULTIPLICADOR_ACELERACION_PLANEO if planeando else 1.0))

	# Detección de inicio de Derrape Físico tipo Odyssey en el suelo (solo a alta velocidad y giro pronunciado)
	if is_on_floor() and not esta_derrapando and vel_horizontal.length() > 3.6 and direccion != Vector3.ZERO:
		var dir_obj_2d = Vector2(direccion.x, direccion.z).normalized()
		var dot_giro = vel_horizontal.normalized().dot(dir_obj_2d)
		if dot_giro < -0.55:
			esta_derrapando = true
			tiempo_derrape_restante = DURACION_DERRAPE
			_dir_deslizamiento_derrape = vel_horizontal.normalized()
			_angulo_derrape_rotacion = rotation.y
			_al_iniciar_derrape(vel_horizontal.length(), direccion)

	if esta_derrapando:
		tiempo_derrape_restante -= delta
		# Deslizamiento inercial suave con fricción de frenado fluida
		vel_horizontal = vel_horizontal.move_toward(Vector2.ZERO, DESACELERACION_DERRAPE * delta)
		_al_procesar_derrape(delta, vel_horizontal.length())
		if vel_horizontal.length() <= 0.4 or tiempo_derrape_restante <= 0.0 or not is_on_floor():
			esta_derrapando = false
			tiempo_derrape_restante = 0.0
			_al_finalizar_derrape()
	elif direccion != Vector3.ZERO:
		en_vuelo_balistico = false
		var obj_horizontal = Vector2(velocidad_objetivo.x, velocidad_objetivo.z)
		vel_horizontal = vel_horizontal.move_toward(obj_horizontal, tasa_aceleracion * delta)
	elif not (en_vuelo_balistico and not is_on_floor()):
		var tasa_frenado = DESACELERACION_SUELO if is_on_floor() else DESACELERACION_AIRE
		vel_horizontal = vel_horizontal.move_toward(Vector2.ZERO, tasa_frenado * delta)
	velocity.x = vel_horizontal.x
	velocity.z = vel_horizontal.y
	
	# Aplicar fuerza horizontal acumulada del vórtice (succión radial y rotacional)
	if _fuerza_vortice_acumulada != Vector3.ZERO:
		velocity.x += _fuerza_vortice_acumulada.x * delta
		velocity.z += _fuerza_vortice_acumulada.z * delta
		_fuerza_vortice_acumulada = Vector3.ZERO

	move_and_slide()
	
	# Empujar objetos RigidBody3D (cajas empujables)
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider is RigidBody3D:
			var direccion_empuje = -col.get_normal()
			direccion_empuje.y = 0.0 # Evitar levantar o hundir la caja
			direccion_empuje = direccion_empuje.normalized()
			var fuerza_empuje = 2.5 # Ajusta este valor si es necesario
			var impulso = direccion_empuje * fuerza_empuje * delta * 60.0
			
			if collider.has_method("rpc_aplicar_impulso"):
				# Llamar vía RPC para que se aplique en el servidor que simula la física de la caja
				collider.rpc("rpc_aplicar_impulso", impulso)
			elif not collider.freeze:
				# Fallback local para RigidBody3D no sincronizados
				collider.apply_central_impulse(impulso)

	# Registrar el último suelo colisionado para detección de plataformas
	if is_on_floor():
		_tiempo_desde_ultimo_suelo = 0.0
		for i in get_slide_collision_count():
			var col = get_slide_collision(i)
			if col.get_normal().y > 0.5:
				var collider = col.get_collider()
				if collider:
					_ultimo_suelo_colisionado = collider
					break
	else:
		_tiempo_desde_ultimo_suelo += delta
		
		# Detección reactiva: si el último suelo era una plataforma espiritual y se ha desactivado
		if not _camara_fijada_en_caida and not _camara_fijada_en_vortice and _tiempo_desde_ultimo_suelo <= 0.35 and velocity.y < 0.0:
			if is_instance_valid(_ultimo_suelo_colisionado):
				var es_espiritual = false
				if _ultimo_suelo_colisionado is IslaFlotante:
					es_espiritual = (_ultimo_suelo_colisionado.tipo_comportamiento == IslaFlotante.TipoComportamiento.ESPIRITUAL)
				elif _ultimo_suelo_colisionado.has_method("es_tangible_para_vivo"):
					es_espiritual = true
				
				if es_espiritual:
					var sigue_tangible = true
					if _ultimo_suelo_colisionado.has_method("es_tangible_para_vivo"):
						sigue_tangible = _ultimo_suelo_colisionado.es_tangible_para_vivo()
					if not sigue_tangible:
						fijar_camara_en_caida()

		# Detección de caída al vacío: congelar la cámara en el borde superior antes de descender al abismo
		if not is_on_floor() and not _camara_fijada_en_caida and not _camara_fijada_en_vortice and velocity.y < 0.0 and global_position.y < (LIMITE_CAIDA_Y + 4.0):
			fijar_camara_en_caida()

	if _comprobar_caida_vacio():
		return
	
	# Aseguramos que la cámara siga la posición del jugador después del movimiento físico sin hundirse en el abismo
	var cam_mgr = _get_camara_config_manager()
	var es_estatica = is_instance_valid(cam_mgr) and cam_mgr.has_method("esta_camara_estatica") and cam_mgr.esta_camara_estatica()
	if es_estatica and pivote_camara:
		pivote_camara.global_position = cam_mgr.obtener_posicion_camara_estatica()
	elif es_activo() and pivote_camara and pivote_camara.top_level and not _camara_fijada_en_vortice and not _camara_fijada_en_caida:
		pivote_camara.global_position = _calcular_pos_pivote_seguimiento()

func procesar_movimiento_base(delta: float):
	if movimiento_bloqueado:
		aplicar_friccion_y_movimiento(Vector3.ZERO, delta)
		return

	var red_mgr = _get_red_manager()
	if is_instance_valid(red_mgr) and red_mgr.transicion_en_progreso:
		aplicar_friccion_y_movimiento(Vector3.ZERO, delta)
		return

	if _vortice_esta_absorbido:
		aplicar_friccion_y_movimiento(Vector3.ZERO, delta)
		return

	var direccion = obtener_direccion_movimiento()
	
	if esta_derrapando:
		# Durante el derrape, el personaje desliza a lo largo de su inercia pero rota con fluidez hacia el nuevo input
		if direccion != Vector3.ZERO:
			var target_angle = atan2(-direccion.x, -direccion.z)
			rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)
		else:
			rotation.y = lerp_angle(rotation.y, _angulo_derrape_rotacion, 12.0 * delta)
	elif direccion != Vector3.ZERO:
		# Rotar suavemente al personaje hacia la dirección en la que se está moviendo
		var target_angle = atan2(-direccion.x, -direccion.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 1.0 - exp(-VELOCIDAD_ROTACION_PERSONAJE * delta))
		
	aplicar_friccion_y_movimiento(direccion, delta)
	_procesar_proximidad_corazon(delta)

func resetear_estados():
	en_vuelo_balistico = false
	esta_derrapando = false
	tiempo_derrape_restante = 0.0
	saltos_realizados = 0
	tiempo_desde_suelo = 0.0
	tiempo_desde_salto = 0.0
	_vortice_esta_absorbido = false
	_tiempo_absorcion_restante = 0.0
	_tiempo_impulso_caida = 0.0
	_vel_max_caida_impulso = 0.0
	_camara_fijada_en_vortice = false
	_camara_fijada_en_caida = false
	_ultimo_suelo_colisionado = null
	_tiempo_desde_ultimo_suelo = 999.0
	_fuerza_vortice_acumulada = Vector3.ZERO
	_arrastre_descendente_vortice = 0.0
	_nodo_vortice_origen = null
	if is_instance_valid(particulas_corazon):
		particulas_corazon.emitting = false
		particulas_corazon.restart()
	_al_resetear_estados()

func _al_resetear_estados():
	# Hook virtual para subclases
	pass

func establecer_punto_control(nueva_pos: Vector3, nueva_rot: Vector3 = Vector3.ZERO) -> void:
	punto_control = nueva_pos
	if nueva_rot != Vector3.ZERO:
		rotacion_punto_control = nueva_rot

func reaparecer() -> void:
	var vib_mgr = _get_vibration_manager()
	if es_activo() and is_instance_valid(vib_mgr):
		vib_mgr.vibrar_dano()

	var destino = punto_control if punto_control != Vector3.ZERO else posicion_inicial
	var rot_dest = rotacion_punto_control if punto_control != Vector3.ZERO else rotacion_inicial
	global_position = destino
	velocity = Vector3.ZERO
	rotation = rot_dest
	sync_position = destino
	sync_rotation = rot_dest
	_vel_y_previa_base = 0.0

	resetear_estados()

	objetivo_rotacion_y = rot_dest.y
	objetivo_rotacion_x = rotacion_inicial_camara_x

	if pivote_camara == null:
		pivote_camara = get_node_or_null("Node3D")
	if pivote_camara:
		var arm = obtener_spring_arm()
		var cam_mgr = _get_camara_config_manager()
		var es_estatica = is_instance_valid(cam_mgr) and cam_mgr.has_method("esta_camara_estatica") and cam_mgr.esta_camara_estatica()
		if es_estatica:
			_aplicar_pose_camara_estatica_base(cam_mgr, true)
		else:
			pivote_camara.global_position = destino
			pivote_camara.rotation = Vector3(0.0, rot_dest.y, 0.0)
			if arm:
				pivote_camara.rotation.x = 0.0
				arm.rotation = Vector3(rotacion_inicial_camara_x, 0.0, 0.0)
				arm.force_update_transform()
			pivote_camara.force_update_transform()

			var cam = obtener_camara()
			if cam:
				# Posicionar inmediatamente la cámara en una distancia despejada válida para evitar cualquier frame con spring comprimido residual
				var dist_final = DISTANCIA_CAMARA
				if arm:
					dist_final = arm.spring_length
					if is_inside_tree() and arm.get_world_3d():
						var espacio = arm.get_world_3d().direct_space_state
						if espacio:
							var origen = arm.global_position
							var dir_cam = arm.global_transform.basis.z * arm.spring_length
							var query = PhysicsRayQueryParameters3D.create(origen, origen + dir_cam, arm.collision_mask, [get_rid()])
							var hit = espacio.intersect_ray(query)
							if hit and not hit.is_empty():
								dist_final = maxf(origen.distance_to(hit.position) - arm.margin, 0.2)
				cam.position = Vector3(0.0, 0.0, dist_final)
				cam.force_update_transform()
				cam.reset_physics_interpolation()
			if arm:
				arm.reset_physics_interpolation()
			pivote_camara.reset_physics_interpolation()

	# Restablecer interpolación física en toda la jerarquía para eliminar estiramientos o saltos visuales en 1 frame
	reset_physics_interpolation()
	propagate_call("reset_physics_interpolation")
	if pivote_camara and pivote_camara.top_level:
		pivote_camara.propagate_call("reset_physics_interpolation")

func _comprobar_caida_vacio() -> bool:
	if global_position.y < LIMITE_CAIDA_Y:
		reaparecer()
		return true
	return false

static var _textura_corazon_cache: ImageTexture = null

func _obtener_textura_corazon() -> ImageTexture:
	if _textura_corazon_cache == null:
		_textura_corazon_cache = _generar_textura_corazon()
	return _textura_corazon_cache

func _crear_particulas_corazon_proximidad():
	particulas_corazon = CPUParticles3D.new()
	particulas_corazon.name = "ParticulasCorazonProximidad"
	particulas_corazon.amount = 5 # Reducido a 5 corazones para una flotación lenta y romántica
	particulas_corazon.lifetime = 2.4
	particulas_corazon.one_shot = false
	particulas_corazon.emitting = false
	particulas_corazon.explosiveness = 0.0
	particulas_corazon.randomness = 0.4
	particulas_corazon.lifetime_randomness = 0.3
	particulas_corazon.top_level = true
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.32, 0.32)
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED # Desactiva depth-buffer write para transparencia limpia sin artefactos
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.albedo_texture = _obtener_textura_corazon()
	mesh.material = mat
	
	particulas_corazon.mesh = mesh
	particulas_corazon.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particulas_corazon.emission_sphere_radius = 0.35
	particulas_corazon.direction = Vector3(0, 1, 0)
	particulas_corazon.spread = 15.0
	particulas_corazon.gravity = Vector3(0, 0.5, 0) # Elevación lenta y suave
	particulas_corazon.initial_velocity_min = 0.2
	particulas_corazon.initial_velocity_max = 0.45
	particulas_corazon.scale_amount_min = 0.6
	particulas_corazon.scale_amount_max = 1.1
	particulas_corazon.color = Color(1.0, 0.35, 0.65, 0.9)
	
	add_child(particulas_corazon)

func _generar_textura_corazon() -> ImageTexture:
	var size = 128
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center_x = size / 2.0
	var center_y = size * 0.36
	var r = size * 0.22
	var circle1 = Vector2(center_x - r * 0.90, center_y)
	var circle2 = Vector2(center_x + r * 0.90, center_y)
	var tip_bottom = Vector2(center_x, size * 0.88) # Alargado suavemente hacia abajo
	
	for y in range(size):
		for x in range(size):
			var p = Vector2(float(x), float(y))
			
			# Distancia a los lóbulos superiores (círculos)
			var d1 = p.distance_to(circle1) - r
			var d2 = p.distance_to(circle2) - r
			var dist = min(d1, d2)
			
			# Cuerpo inferior cónico en V continuo y sin sobresalir lateralmente
			if p.y >= center_y:
				var dy = p.y - tip_bottom.y
				if dy < 0:
					var slope_left = (circle1.x - r - tip_bottom.x) / (center_y - tip_bottom.y)
					var slope_right = (circle2.x + r - tip_bottom.x) / (center_y - tip_bottom.y)
					var bound_left = tip_bottom.x + slope_left * dy
					var bound_right = tip_bottom.x + slope_right * dy
					
					var dist_left = bound_left - p.x
					var dist_right = p.x - bound_right
					var dist_v = max(dist_left, dist_right)
					dist = min(dist, dist_v)
					
			if dist <= 0.0:
				img.set_pixel(x, y, Color(1.0, 0.2, 0.55, 1.0))
			elif dist < 2.0:
				var alpha = clamp(1.0 - (dist / 2.0), 0.0, 1.0)
				img.set_pixel(x, y, Color(1.0, 0.2, 0.55, alpha))
				
	return ImageTexture.create_from_image(img)





func _procesar_proximidad_corazon(delta: float):
	if not es_activo(): return

	var otro: Node3D = _buscar_otro_jugador()
	if is_instance_valid(otro):
		var dist = global_position.distance_to(otro.global_position)
		if dist <= DISTANCIA_PROXIMIDAD_CORAZON:
			tiempo_cerca_otro += delta
			if tiempo_cerca_otro >= TIEMPO_REQUERIDO_PROXIMIDAD:
				if is_instance_valid(particulas_corazon):
					particulas_corazon.emitting = true
					var pos_mitad = (global_position + otro.global_position) * 0.5
					pos_mitad.y += 0.8
					particulas_corazon.global_position = pos_mitad
			else:
				# Durante la cuenta regresiva de 5 segundos, mantener las partículas apagadas
				if is_instance_valid(particulas_corazon):
					particulas_corazon.emitting = false
		else:
			# Si se alejan más de 1.4 metros, reiniciar el contador a 0 y apagar la emisión
			tiempo_cerca_otro = 0.0
			if is_instance_valid(particulas_corazon):
				particulas_corazon.emitting = false
	else:
		tiempo_cerca_otro = 0.0
		if is_instance_valid(particulas_corazon):
			particulas_corazon.emitting = false


func _buscar_otro_jugador() -> Node3D:
	if is_instance_valid(_otro_jugador_cache) and _otro_jugador_cache != self:
		return _otro_jugador_cache

	var red_mgr = _get_red_manager()
	if is_instance_valid(red_mgr):
		var es_fantasma = is_in_group("fantasmas") or name.to_lower().contains("fantasma")
		var candidato = red_mgr.jugador_vivo if es_fantasma else red_mgr.fantasma
		if is_instance_valid(candidato) and candidato != self:
			_otro_jugador_cache = candidato
			return _otro_jugador_cache

	var todos = get_tree().get_nodes_in_group("jugadores")
	for p in todos:
		if p != self and is_instance_valid(p):
			_otro_jugador_cache = p
			return p

	var es_fant = is_in_group("fantasmas") or name.to_lower().contains("fantasma")
	if es_fant:
		var vivos = get_tree().get_nodes_in_group("vivos")
		if vivos.size() > 0 and vivos[0] != self:
			_otro_jugador_cache = vivos[0]
			return vivos[0]
	else:
		var fantasmas = get_tree().get_nodes_in_group("fantasmas")
		if fantasmas.size() > 0 and fantasmas[0] != self:
			_otro_jugador_cache = fantasmas[0]
			return fantasmas[0]

	return null

# ===================================================================
# SILUETA DE OCLUSIÓN (X-RAY A TRAVÉS DE OBSTÁCULOS)
# ===================================================================
func actualizar_silueta_oclusion() -> void:
	if not is_inside_tree():
		return
	
	var nodo_modelo = find_child("vivo", true, false)
	if not nodo_modelo:
		nodo_modelo = find_child("fantasma", true, false)
	if not nodo_modelo:
		return

	_aplicar_silueta_recursiva(nodo_modelo)

func _aplicar_silueta_recursiva(nodo: Node) -> void:
	if nodo is MeshInstance3D and nodo.mesh:
		# Excluir mallas accesorias de habilidades visuales como auras o halos
		if nodo.name == "Aura" or nodo.name == "HaloSuave":
			return
			
		# Evitar que Occlusion Culling descarte la malla en CPU cuando está tras un muro
		# permitiendo que el shader/stencil X-Ray se renderice en GPU sin parpadeos.
		nodo.ignore_occlusion_culling = silueta_activa
		nodo.extra_cull_margin = 0.5 if silueta_activa else 0.0

		for s in range(nodo.mesh.get_surface_count()):
			var mat = nodo.get_surface_override_material(s)
			if not mat:
				mat = nodo.mesh.surface_get_material(s)
				
			if mat is StandardMaterial3D:
				var mat_clon = mat.duplicate() as StandardMaterial3D
				if silueta_activa:
					mat_clon.stencil_mode = BaseMaterial3D.STENCIL_MODE_XRAY
					mat_clon.stencil_color = color_silueta
					if mat_clon.next_pass is StandardMaterial3D:
						var np = mat_clon.next_pass as StandardMaterial3D
						np.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						np.albedo_color = color_silueta
				else:
					mat_clon.stencil_mode = BaseMaterial3D.STENCIL_MODE_DISABLED
					mat_clon.next_pass = null
				nodo.set_surface_override_material(s, mat_clon)
			elif mat is ShaderMaterial:
				var mat_clon_sh := mat.duplicate() as ShaderMaterial
				if silueta_activa:
					var np := StandardMaterial3D.new()
					np.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					np.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					np.no_depth_test = true
					np.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
					np.cull_mode = BaseMaterial3D.CULL_DISABLED
					np.albedo_color = color_silueta
					np.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM
					np.stencil_flags = BaseMaterial3D.STENCIL_FLAG_READ
					np.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_NOT_EQUAL
					np.stencil_reference = 1
					# Se dibuja DESPUÉS de las partículas para respetar su stencil
					np.render_priority = 20
					mat_clon_sh.next_pass = np
				else:
					mat_clon_sh.next_pass = null
				nodo.set_surface_override_material(s, mat_clon_sh)

	for hijo in nodo.get_children():
		_aplicar_silueta_recursiva(hijo)
