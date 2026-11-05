@tool
extends ObjetoPoseibleBase
class_name CanonEspiritual

## ==============================================================================
## CAÑÓN ESPIRITUAL ANCESTRAL (PROYECTO LIMBO)
## Mecanismo de piedra monumental que el Fantasma puede poseer.
## Permite rotar y calibrar la puntería balística 3D elevada hacia el cielo.
## El Jugador Vivo puede entrar dentro de la recámara presionando el botón de acción
## para salir disparado por los aires con un impulso parabólico potente.
## ==============================================================================

signal vivo_cargado_en_canon(jugador: CharacterBase)
signal vivo_expulsado_de_canon(jugador: CharacterBase)
signal disparo_ejecutado(fuerza: float, direccion: Vector3)

@export_group("Balística y Disparo")
@export var fuerza_disparo: float = 32.0
@export var elevacion_minima_grados: float = -5.0
@export var elevacion_maxima_grados: float = 80.0
@export var velocidad_giro_apuntado: float = 2.4
@export var tiempo_recoil: float = 0.35

@export_group("Referencias de Cañón")
@export var nodo_canon_giratorio: Node3D = null
@export var marcador_boca_canon: Marker3D = null
@export var area_recamara: Area3D = null
@export var luz_recamara: OmniLight3D = null
@export var particulas_disparo: CPUParticles3D = null
@export var nodo_mira: MiraCanonEspiritual = null

@export_group("Alojamiento y Salto del Vivo")
## Escala relativa que adopta el Vivo al ingresar en la recámara para adaptarse sin sobresalir.
@export var factor_escala_vivo_recamara: float = 0.82
## Descenso vertical del Vivo dentro del cañón para que sus pies queden ocultos en la base del modelo.
@export var descenso_vertical_vivo: float = 0.11
## Profundidad dentro del tubo medida desde la boca del cañón hacia atrás.
@export var profundidad_vivo_recamara: float = 0.45
## Duración de la animación del salto de entrada al cañón.
@export var duracion_salto_entrada: float = 0.48
## Altura del arco de salto parabólico hacia la boca del cañón.
@export var altura_arco_salto: float = 1.4

var _jugador_cargado: CharacterBody3D = null
var _jugador_cerca: CharacterBody3D = null
var _capa_colision_previa_vivo: int = 0
var _mascara_colision_previa_vivo: int = 0
var _silueta_previa_vivo: bool = true
var _tiempo_en_recamara: float = 0.0

var _en_transicion_salto_vivo: bool = false
var _en_transicion_salida_vivo: bool = false
var _tiempo_transicion_salto: float = 0.0
var _pos_inicio_salto_vivo: Vector3 = Vector3.ZERO
var _pos_destino_salida_vivo: Vector3 = Vector3.ZERO

var _angulo_yaw: float = 0.0
var _angulo_pitch: float = 45.0 # Elevación inicial apuntando hacia arriba!
var _recoil_offset_z: float = 0.0
var _cooldown_recarga: float = 0.0

func _ready() -> void:
	super()
	nombre_objeto = "Cañón Espiritual"
	distancia_camara_posesion = 6.2
	altura_spring_arm_posesion = 2.2
	pitch_defecto_posesion = -0.18
	
	add_to_group("mecanismos_interactivos")
	
	if area_recamara:
		if not area_recamara.body_entered.is_connected(_on_cuerpo_recamara_entro):
			area_recamara.body_entered.connect(_on_cuerpo_recamara_entro)
		if not area_recamara.body_exited.is_connected(_on_cuerpo_recamara_salio):
			area_recamara.body_exited.connect(_on_cuerpo_recamara_salio)
	
	if not is_instance_valid(nodo_cabeza):
		nodo_cabeza = get_node_or_null("PivoteCanon/CabezaFantasmaEmergente") as Node3D
	if not is_instance_valid(nodo_ojos):
		nodo_ojos = get_node_or_null("PivoteCanon/OjosPosesion") as OjosPosesion
	
	if is_instance_valid(nodo_ojos) and nodo_ojos.has_method("adaptar_a_superficie"):
		nodo_ojos.adaptar_a_superficie(
			Vector3(0.17, 0.0, 0.0),
			Vector3.ZERO,
			Vector3(-0.17, 0.0, 0.0),
			Vector3.ZERO,
			0.56
		)
	
	_angulo_yaw = rotation.y
	if is_instance_valid(nodo_canon_giratorio):
		_angulo_pitch = clampf(absf(rad_to_deg(nodo_canon_giratorio.rotation.x)), elevacion_minima_grados, elevacion_maxima_grados)
	
	if not is_instance_valid(nodo_mira):
		nodo_mira = get_node_or_null("PivoteCanon/MiraCanon") as MiraCanonEspiritual
	if is_instance_valid(nodo_mira):
		nodo_mira.configurar_origen(marcador_boca_canon if is_instance_valid(marcador_boca_canon) else nodo_canon_giratorio, self)
	
	_actualizar_orientacion_canon()
	_actualizar_estado_luz_recamara()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() and _jugador_cargado == null and not esta_poseido and _recoil_offset_z <= 0.0:
		return
	
	if _cooldown_recarga > 0.0:
		_cooldown_recarga = maxf(_cooldown_recarga - delta, 0.0)
		_actualizar_estado_luz_recamara()
	
	# Recuperación elástica del retroceso (recoil) tras disparar
	if _recoil_offset_z > 0.0:
		_recoil_offset_z = move_toward(_recoil_offset_z, 0.0, (1.0 / tiempo_recoil) * delta)
		if is_instance_valid(nodo_canon_giratorio):
			nodo_canon_giratorio.position.z = _recoil_offset_z
	
	# Mantener al jugador vivo alojado dentro de la recámara o procesar salto de entrada / salida
	if is_instance_valid(_jugador_cargado):
		if _en_transicion_salto_vivo:
			_procesar_transicion_salto_vivo(delta)
		elif _en_transicion_salida_vivo:
			_procesar_transicion_salida_vivo(delta)
		else:
			_tiempo_en_recamara += delta
			_posicionar_vivo_en_recamara()
			
			# El vivo no puede disparar el cañón ni operarlo por su cuenta.
			# Solo si el cañón NO está poseído y el jugador controla activamente al vivo,
			# puede pulsar saltar o interactuar voluntariamente para bajarse sin disparo.
			if not esta_poseido and _tiempo_en_recamara > 0.25:
				var es_vivo_activo = not _jugador_cargado.has_method("es_activo") or _jugador_cargado.es_activo()
				if es_vivo_activo and (Input.is_action_just_pressed("saltar") or Input.is_action_just_pressed("interactuar")):
					_expulsar_vivo_sin_disparar()

func procesar_input_posesion(delta: float, input_dir: Vector2, acciones: Dictionary) -> void:
	if not esta_poseido:
		return
	
	# Control de Yaw (giro horizontal) y Pitch (elevación vertical hacia arriba) del Fantasma
	_angulo_yaw -= input_dir.x * velocidad_giro_apuntado * delta
	# Stick adelante (input_dir.y < 0) eleva el cañón hacia arriba (+)
	_angulo_pitch = clampf(_angulo_pitch - (input_dir.y * velocidad_giro_apuntado * 25.0 * delta), elevacion_minima_grados, elevacion_maxima_grados)
	
	_actualizar_orientacion_canon()
	
	if is_instance_valid(nodo_ojos):
		var dir_apuntado = Vector3(input_dir.x, -input_dir.y, 0.0)
		nodo_ojos.actualizar_mirada(dir_apuntado, 0.5)
	
	# El Fantasma es quien decide y ejecuta el disparo
	if acciones.get("disparar", false) or acciones.get("saltar_just_pressed", false) or acciones.get("efecto_just_pressed", false) or acciones.get("interactuar_secundario", false):
		ejecutar_disparo()

func _al_iniciar_posesion() -> void:
	_actualizar_estado_luz_recamara()
	if is_instance_valid(nodo_cabeza):
		if nodo_cabeza.has_method("emerger"):
			nodo_cabeza.emerger()
		else:
			nodo_cabeza.visible = true
	if is_instance_valid(nodo_mira):
		nodo_mira.mostrar()

func _al_terminar_posesion() -> void:
	_actualizar_estado_luz_recamara()
	if is_instance_valid(nodo_cabeza):
		if nodo_cabeza.has_method("ocultar_suave"):
			nodo_cabeza.ocultar_suave()
		else:
			nodo_cabeza.visible = false
	if is_instance_valid(nodo_mira):
		nodo_mira.ocultar()

func _actualizar_orientacion_canon() -> void:
	# Rotación horizontal (Yaw) rota el objeto completo
	rotation.y = _angulo_yaw
	
	# Rotación vertical (Pitch) rota únicamente el cañón (tubo y boca)
	if is_instance_valid(nodo_canon_giratorio):
		nodo_canon_giratorio.rotation.y = 0.0
		nodo_canon_giratorio.rotation.x = deg_to_rad(_angulo_pitch)

## Interfaz estándar para que Jugador.gd active la interacción al pulsar el botón de acción
func intentar_interactuar(personaje: Node) -> bool:
	if not is_instance_valid(personaje):
		return false
	if _cooldown_recarga > 0.0 or _en_transicion_salto_vivo or _en_transicion_salida_vivo:
		return false
	
	# El personaje vivo puede entrar al cañón esté poseído o no
	if _jugador_cargado == null:
		cargar_jugador_en_canon(personaje as CharacterBody3D)
		return true
	elif _jugador_cargado == personaje and not esta_poseido and _tiempo_en_recamara > 0.35 and not _en_transicion_salto_vivo and not _en_transicion_salida_vivo:
		_expulsar_vivo_sin_disparar()
		return true
		
	return false

func cargar_jugador_en_canon(jugador: CharacterBody3D) -> void:
	if not is_instance_valid(jugador) or _jugador_cargado != null or _en_transicion_salto_vivo or _en_transicion_salida_vivo:
		return
	
	_jugador_cargado = jugador
	_tiempo_en_recamara = 0.0
	_capa_colision_previa_vivo = _jugador_cargado.collision_layer
	_mascara_colision_previa_vivo = _jugador_cargado.collision_mask
	_silueta_previa_vivo = _jugador_cargado.get("silueta_activa") if _jugador_cargado.get("silueta_activa") != null else true
	
	# Desactivar colisiones físicas y bloquear movimiento mientras se lanza e ingresa
	_jugador_cargado.collision_layer = 0
	_jugador_cargado.collision_mask = 0
	_jugador_cargado.velocity = Vector3.ZERO
	if "movimiento_bloqueado" in _jugador_cargado:
		_jugador_cargado.movimiento_bloqueado = true
	
	if not Engine.is_editor_hint() and _jugador_cargado.has_method("desregistrar_mecanismo_cercano"):
		_jugador_cargado.desregistrar_mecanismo_cercano(self)
	
	# Iniciar el estado de cañón manteniendo su tamaño completo (1.0) durante el salto
	if "offset_vertical_canon" in _jugador_cargado:
		_jugador_cargado.offset_vertical_canon = descenso_vertical_vivo
	if _jugador_cargado.has_method("entrar_en_canon"):
		_jugador_cargado.entrar_en_canon(1.0)
	elif "silueta_activa" in _jugador_cargado:
		_jugador_cargado.silueta_activa = false
	if _jugador_cargado.has_method("_iniciar_animacion_salto_vivo"):
		_jugador_cargado._iniciar_animacion_salto_vivo(1)
	
	# Iniciar animación de salto parabólico hacia el interior del cañón
	_en_transicion_salto_vivo = true
	_tiempo_transicion_salto = 0.0
	_pos_inicio_salto_vivo = _jugador_cargado.global_position
	
	_actualizar_estado_luz_recamara()

func _procesar_transicion_salto_vivo(delta: float) -> void:
	if not is_instance_valid(_jugador_cargado):
		_en_transicion_salto_vivo = false
		return
	
	_tiempo_transicion_salto += delta
	var t = clampf(_tiempo_transicion_salto / duracion_salto_entrada, 0.0, 1.0)
	
	var dir = obtener_direccion_disparo()
	var pos_boca = marcador_boca_canon.global_position if is_instance_valid(marcador_boca_canon) else global_position + Vector3(0.0, 1.8, -1.5)
	var pos_recamara = pos_boca - (dir * profundidad_vivo_recamara)
	
	# Punto de entrada justo frente a la boca del cañón
	var pos_frente_boca = pos_boca + (dir * 0.45)
	
	var pos_actual: Vector3
	# Fase 1 (t de 0.0 a 0.68): Salto ágil en el aire a tamaño normal (1.0) sin encogerse
	if t < 0.68:
		var sub_t = t / 0.68
		var u_curva = sin(sub_t * (PI * 0.5)) # Ease-out hacia el frente de la boca
		pos_actual = _pos_inicio_salto_vivo.lerp(pos_frente_boca, u_curva)
		var arco = sin(sub_t * PI) * altura_arco_salto
		pos_actual.y += arco
		
		# Orientar hacia la boca del cañón durante el vuelo
		var dir_hacia_boca = (pos_boca - _jugador_cargado.global_position).normalized()
		var dir_plana = Vector3(dir_hacia_boca.x, 0.0, dir_hacia_boca.z)
		if not dir_plana.is_zero_approx():
			_jugador_cargado.rotation.y = lerp_angle(_jugador_cargado.rotation.y, atan2(-dir_plana.x, -dir_plana.z), 18.0 * delta)
		
		# El vivo conserva su tamaño completo 1.0 durante todo el salto por el aire
		if _jugador_cargado.has_method("ajustar_factor_escala_canon"):
			_jugador_cargado.ajustar_factor_escala_canon(1.0)
	else:
		# Fase 2 (t de 0.68 a 1.0): Inmersión en la boca del cañón; encogimiento rápido de golpe
		var sub_t = (t - 0.68) / 0.32
		var v_curva = sub_t * sub_t # Inmersión veloz hacia adentro
		pos_actual = pos_frente_boca.lerp(pos_recamara, v_curva)
		
		# Encogimiento de golpe al cruzar el umbral de la boca del cañón
		var p_golpe = clampf(sub_t / 0.70, 0.0, 1.0)
		var curva_shrink = 1.0 - pow(1.0 - p_golpe, 3.0) # Cubic ease-out rápido y contundente
		var factor_actual = lerpf(1.0, factor_escala_vivo_recamara, curva_shrink)
		
		if _jugador_cargado.has_method("ajustar_factor_escala_canon"):
			_jugador_cargado.ajustar_factor_escala_canon(factor_actual)
		
		# Alinear orientación completa tridimensional con el eje del cañón
		if is_instance_valid(nodo_canon_giratorio):
			var b_objetivo = nodo_canon_giratorio.global_transform.basis.orthonormalized()
			_jugador_cargado.global_transform.basis = _jugador_cargado.global_transform.basis.slerp(b_objetivo, 25.0 * delta).orthonormalized()
	
	_jugador_cargado.global_position = pos_actual
	_jugador_cargado.velocity = Vector3.ZERO
	if "sync_position" in _jugador_cargado:
		_jugador_cargado.sync_position = pos_actual
	if "sync_rotation" in _jugador_cargado:
		_jugador_cargado.sync_rotation = _jugador_cargado.rotation
	
	if t >= 1.0:
		_finalizar_entrada_salto()

func _finalizar_entrada_salto() -> void:
	_en_transicion_salto_vivo = false
	_tiempo_en_recamara = 0.0
	if is_instance_valid(_jugador_cargado) and _jugador_cargado.has_method("ajustar_factor_escala_canon"):
		_jugador_cargado.ajustar_factor_escala_canon(factor_escala_vivo_recamara)
	_posicionar_vivo_en_recamara()
	_actualizar_estado_luz_recamara()
	
	vivo_cargado_en_canon.emit(_jugador_cargado)
	
	if is_instance_valid(nodo_ojos):
		nodo_ojos.activar_expresion_sorpresa()
	
	if is_instance_valid(nodo_cabeza) and nodo_cabeza.has_method("reproducir_parar"):
		nodo_cabeza.reproducir_parar()
		
	var tree_vivo = get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree_vivo and tree_vivo.root:
		var vib = tree_vivo.root.get_node_or_null("VibrationManager")
		if is_instance_valid(vib) and vib.has_method("vibrar_mecanismo"):
			vib.vibrar_mecanismo()

func _posicionar_vivo_en_recamara() -> void:
	if not is_instance_valid(_jugador_cargado):
		return
	var dir = obtener_direccion_disparo()
	var pos_boca = marcador_boca_canon.global_position if is_instance_valid(marcador_boca_canon) else global_position + Vector3(0.0, 1.8, -1.5)
	_jugador_cargado.global_position = pos_boca - (dir * profundidad_vivo_recamara)
	_jugador_cargado.velocity = Vector3.ZERO
	
	# Alinear orientación del vivo con la orientación tridimensional del cañón (pitch y yaw)
	if is_instance_valid(nodo_canon_giratorio):
		_jugador_cargado.global_transform.basis = nodo_canon_giratorio.global_transform.basis.orthonormalized()
	else:
		var dir_plana = Vector3(dir.x, 0.0, dir.z)
		if not dir_plana.is_zero_approx():
			_jugador_cargado.rotation.y = atan2(-dir_plana.x, -dir_plana.z)
	
	if "sync_position" in _jugador_cargado:
		_jugador_cargado.sync_position = _jugador_cargado.global_position
	if "sync_rotation" in _jugador_cargado:
		_jugador_cargado.sync_rotation = _jugador_cargado.rotation

func ejecutar_disparo() -> void:
	if _cooldown_recarga > 0.0 or _en_transicion_salida_vivo:
		return
	
	var dir_disparo = obtener_direccion_disparo()
	_recoil_offset_z = 0.45
	
	if is_instance_valid(particulas_disparo):
		particulas_disparo.restart()
		particulas_disparo.emitting = true
	
	if is_instance_valid(nodo_ojos):
		nodo_ojos.activar_expresion_sorpresa()
	
	if is_instance_valid(nodo_cabeza) and nodo_cabeza.has_method("reproducir_parar"):
		nodo_cabeza.reproducir_parar()
	
	if is_instance_valid(nodo_mira) and nodo_mira.has_method("pulsar_disparo"):
		nodo_mira.pulsar_disparo()
	
	disparo_ejecutado.emit(fuerza_disparo, dir_disparo)
	
	# Vibración háptica en el disparo
	var tree_disparo = get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree_disparo and tree_disparo.root:
		var vib = tree_disparo.root.get_node_or_null("VibrationManager")
		if is_instance_valid(vib) and vib.has_method("vibrar_embate"):
			vib.vibrar_embate()
	
	# Lanzar al Jugador Vivo si está presente en la recámara hacia la dirección elegida
	if is_instance_valid(_jugador_cargado):
		var vivo_lanzado = _jugador_cargado
		_restaurar_colisiones_vivo(vivo_lanzado)
		
		# Restaurar silueta de oclusión (Rayos X) y forma original del vivo
		if "silueta_activa" in vivo_lanzado:
			vivo_lanzado.silueta_activa = _silueta_previa_vivo
		if vivo_lanzado.has_method("salir_de_canon"):
			vivo_lanzado.salir_de_canon()
		
		var pos_salida = marcador_boca_canon.global_position + (dir_disparo * 0.55) if is_instance_valid(marcador_boca_canon) else global_position + (dir_disparo * 2.2)
		vivo_lanzado.add_collision_exception_with(self)
		add_collision_exception_with(vivo_lanzado)
		vivo_lanzado.global_position = pos_salida
		vivo_lanzado.velocity = dir_disparo * fuerza_disparo
		if "en_vuelo_balistico" in vivo_lanzado:
			vivo_lanzado.en_vuelo_balistico = true
		
		vivo_lanzado.rotation.x = 0.0
		vivo_lanzado.rotation.z = 0.0
		var dir_plana = Vector3(dir_disparo.x, 0.0, dir_disparo.z)
		if not dir_plana.is_zero_approx():
			vivo_lanzado.rotation.y = atan2(-dir_plana.x, -dir_plana.z)
		if not Engine.is_editor_hint() and vivo_lanzado.has_method("_al_realizar_salto"):
			vivo_lanzado._al_realizar_salto(1)
		
		_en_transicion_salto_vivo = false
		_jugador_cargado = null
		_tiempo_en_recamara = 0.0
		_cooldown_recarga = 1.2
		_actualizar_estado_luz_recamara()
		vivo_expulsado_de_canon.emit(vivo_lanzado)
	else:
		_cooldown_recarga = 0.5
		_actualizar_estado_luz_recamara()

func _expulsar_vivo_sin_disparar() -> void:
	if not is_instance_valid(_jugador_cargado) or _en_transicion_salida_vivo or _en_transicion_salto_vivo:
		return
	
	var vivo = _jugador_cargado
	_en_transicion_salida_vivo = true
	_tiempo_transicion_salto = 0.0
	
	# Calcular punto de aterrizaje en el suelo frente al cañón
	var dir = obtener_direccion_disparo()
	var dir_plana = Vector3(dir.x, 0.0, dir.z)
	if dir_plana.is_zero_approx():
		dir_plana = -global_transform.basis.z
		dir_plana.y = 0.0
	dir_plana = dir_plana.normalized()
	
	# Altura del centro del personaje respecto al suelo (centro de la cápsula al contacto con el piso)
	var altura_pivote_suelo = 0.56
	if is_instance_valid(vivo):
		var col_shape = vivo.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col_shape and col_shape.shape is CapsuleShape3D:
			altura_pivote_suelo = (col_shape.shape as CapsuleShape3D).height * 0.5 + 0.02
	
	var pos_suelo = global_position + (dir_plana * 2.3)
	var espacio = get_world_3d().direct_space_state if is_inside_tree() else null
	if espacio:
		var query = PhysicsRayQueryParameters3D.create(
			pos_suelo + Vector3.UP * 2.5,
			pos_suelo + Vector3.DOWN * 5.0,
			(1 << 0) | (1 << 1)
		)
		var exclusion: Array[RID] = [get_rid()]
		if is_instance_valid(vivo):
			exclusion.append(vivo.get_rid())
		query.exclude = exclusion
		
		var hit = espacio.intersect_ray(query)
		if hit:
			pos_suelo.x = hit.position.x
			pos_suelo.z = hit.position.z
			pos_suelo.y = hit.position.y + altura_pivote_suelo
		else:
			pos_suelo.y = (_pos_inicio_salto_vivo.y if _pos_inicio_salto_vivo != Vector3.ZERO else global_position.y + altura_pivote_suelo)
	else:
		pos_suelo.y = (_pos_inicio_salto_vivo.y if _pos_inicio_salto_vivo != Vector3.ZERO else global_position.y + altura_pivote_suelo)
	
	_pos_destino_salida_vivo = pos_suelo
	
	if not Engine.is_editor_hint() and vivo.has_method("_iniciar_animacion_salto_vivo"):
		vivo._iniciar_animacion_salto_vivo(1)
	
	_actualizar_estado_luz_recamara()

func _procesar_transicion_salida_vivo(delta: float) -> void:
	if not is_instance_valid(_jugador_cargado):
		_en_transicion_salida_vivo = false
		return
	
	_tiempo_transicion_salto += delta
	var t = clampf(_tiempo_transicion_salto / duracion_salto_entrada, 0.0, 1.0)
	
	var dir = obtener_direccion_disparo()
	var pos_boca = marcador_boca_canon.global_position if is_instance_valid(marcador_boca_canon) else global_position + Vector3(0.0, 1.8, -1.5)
	var pos_recamara = pos_boca - (dir * profundidad_vivo_recamara)
	var pos_frente_boca = pos_boca + (dir * 0.45)
	
	var pos_actual: Vector3
	# Fase 1 (t de 0.0 a 0.32): Salida fluida de la recámara por la boca del cañón y expansión a tamaño normal (1.0)
	if t < 0.32:
		var sub_t = t / 0.32
		var v_curva = sin(sub_t * (PI * 0.5)) # Salida fluida hacia el exterior de la boca
		pos_actual = pos_recamara.lerp(pos_frente_boca, v_curva)
		
		# Expansión rápida al asomarse completamente fuera de la boca del cañón
		var p_golpe = clampf(sub_t / 0.70, 0.0, 1.0)
		var curva_grow = 1.0 - pow(1.0 - p_golpe, 3.0)
		var factor_actual = lerpf(factor_escala_vivo_recamara, 1.0, curva_grow)
		
		if _jugador_cargado.has_method("ajustar_factor_escala_canon"):
			_jugador_cargado.ajustar_factor_escala_canon(factor_actual)
		
		# Alinear orientación con el cañón mientras sale de la boca y comenzar a erguirse
		if is_instance_valid(nodo_canon_giratorio):
			var b_canon = nodo_canon_giratorio.global_transform.basis.orthonormalized()
			var dir_plana = Vector3(dir.x, 0.0, dir.z)
			if not dir_plana.is_zero_approx():
				var b_erguido = Transform3D().looking_at(dir_plana.normalized(), Vector3.UP).basis.orthonormalized()
				_jugador_cargado.global_transform.basis = b_canon.slerp(b_erguido, sub_t * 0.5).orthonormalized()
	else:
		# Fase 2 (t de 0.32 a 1.0): Salto parabólico desde el frente de la boca hacia el suelo
		var sub_t = (t - 0.32) / 0.68
		var u_curva = sin(sub_t * (PI * 0.5))
		pos_actual = pos_frente_boca.lerp(_pos_destino_salida_vivo, u_curva)
		var arco = sin(sub_t * PI) * (altura_arco_salto * 0.65)
		pos_actual.y += arco
		
		# Conservar tamaño normal completo 1.0 durante todo el vuelo hacia el suelo
		if _jugador_cargado.has_method("ajustar_factor_escala_canon"):
			_jugador_cargado.ajustar_factor_escala_canon(1.0)
		
		# Enderezar completamente a la posición erguida
		var dir_plana = Vector3(dir.x, 0.0, dir.z)
		if not dir_plana.is_zero_approx():
			_jugador_cargado.rotation.x = lerp_angle(_jugador_cargado.rotation.x, 0.0, 18.0 * delta)
			_jugador_cargado.rotation.z = lerp_angle(_jugador_cargado.rotation.z, 0.0, 18.0 * delta)
			_jugador_cargado.rotation.y = lerp_angle(_jugador_cargado.rotation.y, atan2(-dir_plana.x, -dir_plana.z), 18.0 * delta)
	
	_jugador_cargado.global_position = pos_actual
	_jugador_cargado.velocity = Vector3.ZERO
	if "sync_position" in _jugador_cargado:
		_jugador_cargado.sync_position = pos_actual
	if "sync_rotation" in _jugador_cargado:
		_jugador_cargado.sync_rotation = _jugador_cargado.rotation
	
	if t >= 1.0:
		_finalizar_salida_salto()

func _finalizar_salida_salto() -> void:
	if not is_instance_valid(_jugador_cargado):
		_en_transicion_salida_vivo = false
		return
	
	var vivo = _jugador_cargado
	_restaurar_colisiones_vivo(vivo)
	
	# Restaurar silueta de oclusión (Rayos X) y estado normal del vivo
	if "silueta_activa" in vivo:
		vivo.silueta_activa = _silueta_previa_vivo
	if vivo.has_method("salir_de_canon"):
		vivo.salir_de_canon()
	
	vivo.rotation.x = 0.0
	vivo.rotation.z = 0.0
	vivo.global_position = _pos_destino_salida_vivo
	vivo.velocity = Vector3.ZERO
	
	# Reproducir animación de impacto / aterrizaje al tocar suelo
	if not Engine.is_editor_hint():
		if vivo.has_method("_iniciar_animacion_aterrizaje_vivo"):
			vivo._iniciar_animacion_aterrizaje_vivo(-3.5)
		if vivo.has_method("_emitir_impacto_aterrizaje"):
			vivo._emitir_impacto_aterrizaje()
	
	_en_transicion_salida_vivo = false
	_jugador_cargado = null
	_tiempo_en_recamara = 0.0
	_cooldown_recarga = 0.6
	_actualizar_estado_luz_recamara()
	vivo_expulsado_de_canon.emit(vivo)

func _restaurar_colisiones_vivo(vivo: CharacterBody3D) -> void:
	if is_instance_valid(vivo):
		vivo.collision_layer = _capa_colision_previa_vivo if _capa_colision_previa_vivo != 0 else (1 << 1)
		vivo.collision_mask = _mascara_colision_previa_vivo if _mascara_colision_previa_vivo != 0 else ((1 << 0) | (1 << 1))
		if "movimiento_bloqueado" in vivo:
			vivo.movimiento_bloqueado = false

func obtener_direccion_disparo() -> Vector3:
	if is_instance_valid(marcador_boca_canon):
		return -marcador_boca_canon.global_transform.basis.z.normalized()
	if is_instance_valid(nodo_canon_giratorio):
		return -nodo_canon_giratorio.global_transform.basis.z.normalized()
	return Vector3(0.0, sin(deg_to_rad(_angulo_pitch)), -cos(deg_to_rad(_angulo_pitch))).rotated(Vector3.UP, _angulo_yaw).normalized()

func _on_cuerpo_recamara_entro(body: Node3D) -> void:
	if body is CharacterBody3D and not body.is_in_group("fantasmas"):
		_jugador_cerca = body as CharacterBody3D
		if _jugador_cargado == null and not Engine.is_editor_hint() and body.has_method("registrar_mecanismo_cercano"):
			body.registrar_mecanismo_cercano(self)
		_actualizar_estado_luz_recamara()

func _on_cuerpo_recamara_salio(body: Node3D) -> void:
	if body == _jugador_cerca:
		if not Engine.is_editor_hint() and body.has_method("desregistrar_mecanismo_cercano") and _jugador_cargado != body:
			body.desregistrar_mecanismo_cercano(self)
		_jugador_cerca = null
		_actualizar_estado_luz_recamara()

func _actualizar_estado_luz_recamara() -> void:
	if not is_instance_valid(luz_recamara):
		return
	if is_instance_valid(_jugador_cargado) and not _en_transicion_salto_vivo:
		luz_recamara.visible = true
		luz_recamara.light_color = Color(0.2, 1.0, 0.45)
		luz_recamara.light_energy = 2.4
	elif is_instance_valid(_jugador_cerca) and _cooldown_recarga <= 0.0:
		luz_recamara.visible = true
		luz_recamara.light_color = Color(0.25, 0.9, 1.0)
		luz_recamara.light_energy = 1.8
	elif esta_poseido:
		luz_recamara.visible = true
		luz_recamara.light_color = Color(0.3, 0.8, 1.0)
		luz_recamara.light_energy = 1.0
	else:
		luz_recamara.visible = false
