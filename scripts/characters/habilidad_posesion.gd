@tool
extends Node3D
class_name HabilidadPosesion

## ==============================================================================
## HABILIDAD DE POSESIÓN ESPECTRAL DEL FANTASMA (PROYECTO LIMBO)
## Permite al Fantasma lanzarse en picada contra objetos del entorno y poseerlos,
## controlando su movimiento (plataformas taxi, cañones, faroles, engranajes)
## y adaptando dinámicamente la cámara para una experiencia espectacular y divertida.
## ==============================================================================

signal posesion_iniciada(objeto: Node3D)
signal posesion_terminada(objeto: Node3D)
signal objeto_cercano_cambiado(objeto: Node3D)

@export var radio_deteccion: float = 5.5
@export var velocidad_picada: float = 24.0
@export var duracion_maxima_picada: float = 0.28
@export var suavidad_transicion_camara: float = 8.0

var fantasma: CharacterBody3D = null
var objeto_poseido_actual: Node3D = null
var objeto_candidato_cercano: Node3D = null

var _en_transicion_picada: bool = false
var _tiempo_picada: float = 0.0
var _pos_inicio_picada: Vector3 = Vector3.ZERO
var _objeto_destino_picada: Node3D = null

# Estado de cámara original antes de poseer
var _distancia_camara_original: float = 3.5
var _altura_spring_arm_original: float = 1.35
var _pitch_camara_original: float = -0.14
var _v_offset_camara_original: float = 0.0

func _ready() -> void:
	_asegurar_fantasma()

func _asegurar_fantasma() -> CharacterBody3D:
	if not is_instance_valid(fantasma):
		fantasma = get_parent() as CharacterBody3D
	return fantasma

func esta_poseyendo() -> bool:
	return objeto_poseido_actual != null and not _en_transicion_picada

func puede_poseer_algo() -> bool:
	return objeto_candidato_cercano != null and not esta_poseyendo() and not _en_transicion_picada

func obtener_objeto_poseido() -> Node3D:
	return objeto_poseido_actual

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if not is_instance_valid(fantasma):
		fantasma = get_parent() as Fantasma
		if not is_instance_valid(fantasma):
			return

	if not fantasma.es_activo():
		return

	if _en_transicion_picada:
		_procesar_transicion_picada(delta)
		return

	if esta_poseyendo():
		_procesar_input_durante_posesion(delta)
		_adaptar_camara_a_objeto(delta)
	else:
		_actualizar_objeto_candidato_cercano()

func _actualizar_objeto_candidato_cercano() -> void:
	if not is_instance_valid(_asegurar_fantasma()):
		return

	# Si el fantasma no está activo (ej. controlando al Vivo), apagar todos los resaltes
	if fantasma.has_method("es_activo") and not fantasma.es_activo():
		if is_instance_valid(objeto_candidato_cercano):
			if objeto_candidato_cercano.has_method("establecer_resalte_candidato"):
				objeto_candidato_cercano.establecer_resalte_candidato(false)
			objeto_candidato_cercano = null
		var todos_objs = get_tree().get_nodes_in_group("objetos_poseibles")
		for nodo in todos_objs:
			if nodo.has_method("establecer_resalte_candidato") and nodo.get("es_candidato_posesion"):
				nodo.establecer_resalte_candidato(false)
		return

	var objetos = get_tree().get_nodes_in_group("objetos_poseibles")
	var mejor_objeto: Node3D = null
	var menor_distancia: float = radio_deteccion
	
	var pos_fantasma = fantasma.global_position
	
	for nodo in objetos:
		if not (nodo is ObjetoPoseibleBase or (nodo is IslaFlotante and (nodo.puede_ser_poseida or nodo.tipo_comportamiento == IslaFlotante.TipoComportamiento.POSEIBLE))):
			continue
		var obj = nodo
		var puede_ser = obj.get("puede_ser_poseido") if obj.get("puede_ser_poseido") != null else true
		var esta_pos = obj.get("esta_poseido") if obj.get("esta_poseido") != null else false
		if not puede_ser or esta_pos:
			if obj.get("es_candidato_posesion") and obj.has_method("establecer_resalte_candidato"):
				obj.establecer_resalte_candidato(false)
			continue
		
		var dist = pos_fantasma.distance_to(obj.global_position)
		var esta_cerca = (dist <= radio_deteccion)
		if obj.has_method("establecer_resalte_candidato"):
			obj.establecer_resalte_candidato(esta_cerca)
		if dist <= menor_distancia:
			menor_distancia = dist
			mejor_objeto = obj
	
	if mejor_objeto != objeto_candidato_cercano:
		objeto_candidato_cercano = mejor_objeto
		objeto_cercano_cambiado.emit(objeto_candidato_cercano)

func intentar_poseer() -> bool:
	if not puede_poseer_algo():
		return false
	
	iniciar_picada(objeto_candidato_cercano)
	return true

func iniciar_picada(objeto: Node3D) -> void:
	if not is_instance_valid(objeto):
		return
	
	# Desactivar resalte de candidatos durante la picada
	var objetos = get_tree().get_nodes_in_group("objetos_poseibles")
	for nodo in objetos:
		if nodo.has_method("establecer_resalte_candidato"):
			nodo.establecer_resalte_candidato(false)
	
	_en_transicion_picada = true
	_tiempo_picada = 0.0
	_pos_inicio_picada = fantasma.global_position
	_objeto_destino_picada = objeto
	
	# Guardar configuración actual de cámara para restauración
	var arm = fantasma.obtener_spring_arm() if (not Engine.is_editor_hint() and fantasma.has_method("obtener_spring_arm")) else null
	if arm:
		_distancia_camara_original = arm.spring_length
		_altura_spring_arm_original = arm.position.y
	var cam = fantasma.obtener_camara() if (not Engine.is_editor_hint() and fantasma.has_method("obtener_camara")) else null
	if cam:
		_v_offset_camara_original = cam.v_offset
	
	# Activar estela mística al lanzarse en picada
	var estela = fantasma.get("estela_fantasma") if is_instance_valid(fantasma) else null
	if is_instance_valid(estela):
		estela.emitting = true
		estela.amount = 25

func _procesar_transicion_picada(delta: float) -> void:
	if not is_instance_valid(_objeto_destino_picada):
		_cancelar_picada()
		return
	
	_tiempo_picada += delta
	var t = clampf(_tiempo_picada / duracion_maxima_picada, 0.0, 1.0)
	
	# Trayectoria parabólica veloz (Ease-in acelerado)
	var t_curva = t * t
	var pos_meta = _objeto_destino_picada.global_position
	var pos_intermedia = _pos_inicio_picada.lerp(pos_meta, t_curva)
	
	# Arco vertical de picada
	var arco_y = sin(t * PI) * 1.2
	pos_intermedia.y += arco_y
	
	fantasma.global_position = pos_intermedia
	
	if t >= 1.0 or fantasma.global_position.distance_squared_to(pos_meta) < 0.25:
		_finalizar_impacto_posesion(_objeto_destino_picada)

func _cancelar_picada() -> void:
	_en_transicion_picada = false
	_objeto_destino_picada = null

func _finalizar_impacto_posesion(objeto: Node3D) -> void:
	_en_transicion_picada = false
	_objeto_destino_picada = null
	
	objeto_poseido_actual = objeto
	
	_asegurar_fantasma()
	# Ocultar visual del fantasma y suspender colisiones normales
	var modelo = fantasma.get_node_or_null("fantasma") if is_instance_valid(fantasma) else null
	if is_instance_valid(modelo):
		modelo.visible = false
	var estela = fantasma.get("estela_fantasma") if is_instance_valid(fantasma) else null
	if is_instance_valid(estela):
		estela.emitting = false
	var luz1 = fantasma.get_node_or_null("OmniLight3D") as Light3D
	if is_instance_valid(luz1):
		luz1.visible = false
	var luz2 = fantasma.get_node_or_null("LuzAura") as Light3D
	if is_instance_valid(luz2):
		luz2.visible = false
	var aura = fantasma.get_node_or_null("Aura") as VisualInstance3D
	if is_instance_valid(aura):
		aura.visible = false
	var part = fantasma.get_node_or_null("ParticulasAuraMistica") as CPUParticles3D
	if is_instance_valid(part):
		part.emitting = false
	
	if is_instance_valid(fantasma):
		fantasma.collision_layer = 0
		fantasma.collision_mask = 0
	
	# Iniciar posesión en el objeto
	objeto.iniciar_posesion(fantasma)
	
	# Vibración / Feedback táctil
	if is_instance_valid(fantasma):
		var vib = fantasma.get_node_or_null("/root/VibrationManager")
		if is_instance_valid(vib) and vib.has_method("vibrar_ligero"):
			vib.vibrar_ligero()
	
	posesion_iniciada.emit(objeto)

func desposeer() -> void:
	if not esta_poseyendo():
		return
	
	var obj = objeto_poseido_actual
	objeto_poseido_actual = null
	
	# Terminar posesión en el objeto (él mismo expulsa al fantasma en el punto de eyección)
	obj.terminar_posesion()
	
	_asegurar_fantasma()
	# Restaurar visual y física del Fantasma
	var modelo = fantasma.get_node_or_null("fantasma") if is_instance_valid(fantasma) else null
	if is_instance_valid(modelo):
		modelo.visible = true
	var luz1 = fantasma.get_node_or_null("OmniLight3D") as Light3D
	if is_instance_valid(luz1):
		luz1.visible = true
	var luz2 = fantasma.get_node_or_null("LuzAura") as Light3D
	if is_instance_valid(luz2):
		luz2.visible = true
	var aura = fantasma.get_node_or_null("Aura") as VisualInstance3D
	if is_instance_valid(aura):
		aura.visible = true
	var part = fantasma.get_node_or_null("ParticulasAuraMistica") as CPUParticles3D
	if is_instance_valid(part):
		part.emitting = true
	
	if is_instance_valid(fantasma):
		fantasma.collision_layer = 1 << 2 # Capa 3 espiritual
		fantasma.collision_mask = (1 << 0) | (1 << 2) | (1 << 3)
	
	# Restaurar parámetros de cámara suavemente
	var arm = fantasma.obtener_spring_arm() if (is_instance_valid(fantasma) and not Engine.is_editor_hint() and fantasma.has_method("obtener_spring_arm")) else null
	if arm:
		var tween = create_tween()
		if tween:
			tween.tween_property(arm, "spring_length", _distancia_camara_original, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(arm, "position:y", _altura_spring_arm_original, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	var cam = fantasma.obtener_camara() if (is_instance_valid(fantasma) and not Engine.is_editor_hint() and fantasma.has_method("obtener_camara")) else null
	if cam:
		cam.v_offset = _v_offset_camara_original
	
	posesion_terminada.emit(obj)

func _procesar_input_durante_posesion(delta: float) -> void:
	if not is_instance_valid(objeto_poseido_actual):
		desposeer()
		return
	
	# Mantener al fantasma en la misma posición global que el objeto
	fantasma.global_position = objeto_poseido_actual.global_position
	fantasma.velocity = Vector3.ZERO
	
	# Salir de la posesión con el botón de aura / habilidad especial (el mismo botón usado para entrar)
	var salir_pulsado = Input.is_action_just_pressed("interactuar") or (InputMap.has_action("habilidad_especial") and Input.is_action_just_pressed("habilidad_especial"))
	if salir_pulsado:
		desposeer()
		return
	
	# Recopilar inputs de movimiento y botones
	var input_dir = Vector2.ZERO
	if InputMap.has_action("mover_izquierda") and InputMap.has_action("mover_derecha"):
		input_dir = Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras")
	else:
		input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# El botón de salto ahora produce los efectos / acción del objeto
	var accion_salto_mantenida = Input.is_action_pressed("saltar")
	var accion_salto_pulsada = Input.is_action_just_pressed("saltar")
	
	var acciones = {
		"saltar": accion_salto_mantenida,
		"saltar_just_pressed": accion_salto_pulsada,
		"efecto": accion_salto_mantenida,
		"efecto_just_pressed": accion_salto_pulsada,
		"turbo": accion_salto_mantenida,
		"disparar": accion_salto_pulsada
	}
	
	objeto_poseido_actual.procesar_input_posesion(delta, input_dir, acciones)

# ─────────────────────────────────────────────────────────────────────────────
# ADAPTACIÓN DINÁMICA DE CÁMARA (REQUERIMIENTO ESPECÍFICO DEL USUARIO)
# ─────────────────────────────────────────────────────────────────────────────

func _adaptar_camara_a_objeto(delta: float) -> void:
	if not is_instance_valid(objeto_poseido_actual) or not is_instance_valid(fantasma):
		return
	
	var arm = fantasma.obtener_spring_arm() if (not Engine.is_editor_hint() and fantasma.has_method("obtener_spring_arm")) else null
	if arm:
		var dist_obj = objeto_poseido_actual.obtener_distancia_camara_adaptada()
		var alt_obj = objeto_poseido_actual.obtener_altura_camara_adaptada()
		
		arm.spring_length = lerpf(arm.spring_length, dist_obj, suavidad_transicion_camara * delta)
		arm.position.y = lerpf(arm.position.y, alt_obj, suavidad_transicion_camara * delta)
	
	var pivote = fantasma.obtener_pivote_camara() if (not Engine.is_editor_hint() and fantasma.has_method("obtener_pivote_camara")) else null
	if pivote and pivote.top_level:
		var foco = objeto_poseido_actual.obtener_posicion_foco_camara()
		pivote.global_position = pivote.global_position.lerp(foco, suavidad_transicion_camara * 1.5 * delta)
	
	var cam = fantasma.obtener_camara() if (not Engine.is_editor_hint() and fantasma.has_method("obtener_camara")) else null
	if cam:
		var v_off_obj = objeto_poseido_actual.obtener_v_offset_camara_adaptado()
		cam.v_offset = lerpf(cam.v_offset, v_off_obj, suavidad_transicion_camara * delta)
