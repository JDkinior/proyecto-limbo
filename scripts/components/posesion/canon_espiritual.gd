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
@export var elevacion_minima_grados: float = 15.0
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

var _jugador_cargado: CharacterBody3D = null
var _jugador_cerca: CharacterBody3D = null
var _capa_colision_previa_vivo: int = 0
var _mascara_colision_previa_vivo: int = 0
var _tiempo_en_recamara: float = 0.0

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
		nodo_mira.configurar_origen(marcador_boca_canon if is_instance_valid(marcador_boca_canon) else nodo_canon_giratorio)
	
	_actualizar_orientacion_canon()
	_actualizar_estado_luz_recamara()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if _cooldown_recarga > 0.0:
		_cooldown_recarga = maxf(_cooldown_recarga - delta, 0.0)
		_actualizar_estado_luz_recamara()
	
	# Recuperación elástica del retroceso (recoil) tras disparar
	if _recoil_offset_z > 0.001:
		_recoil_offset_z = move_toward(_recoil_offset_z, 0.0, (1.0 / tiempo_recoil) * delta)
		if is_instance_valid(nodo_canon_giratorio):
			nodo_canon_giratorio.position.z = _recoil_offset_z
	
	# Mantener al jugador vivo alojado dentro de la recámara
	if is_instance_valid(_jugador_cargado):
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
	if _cooldown_recarga > 0.0:
		return false
	
	# El personaje vivo puede entrar al cañón esté poseído o no
	if _jugador_cargado == null:
		cargar_jugador_en_canon(personaje as CharacterBody3D)
		return true
	elif _jugador_cargado == personaje and not esta_poseido and _tiempo_en_recamara > 0.35:
		_expulsar_vivo_sin_disparar()
		return true
		
	return false

func cargar_jugador_en_canon(jugador: CharacterBody3D) -> void:
	if not is_instance_valid(jugador) or _jugador_cargado != null:
		return
	
	_jugador_cargado = jugador
	_tiempo_en_recamara = 0.0
	_capa_colision_previa_vivo = _jugador_cargado.collision_layer
	_mascara_colision_previa_vivo = _jugador_cargado.collision_mask
	
	# Desactivar colisiones físicas y bloquear movimiento mientras permanece adentro
	_jugador_cargado.collision_layer = 0
	_jugador_cargado.collision_mask = 0
	_jugador_cargado.velocity = Vector3.ZERO
	if "movimiento_bloqueado" in _jugador_cargado:
		_jugador_cargado.movimiento_bloqueado = true
	
	if not Engine.is_editor_hint() and _jugador_cargado.has_method("desregistrar_mecanismo_cercano"):
		_jugador_cargado.desregistrar_mecanismo_cercano(self)
	
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
	_jugador_cargado.global_position = pos_boca - (dir * 1.1)
	_jugador_cargado.velocity = Vector3.ZERO
	
	# Orientar horizontalmente al vivo mirando hacia la boca del cañón
	var dir_plana = Vector3(dir.x, 0.0, dir.z)
	if not dir_plana.is_zero_approx():
		_jugador_cargado.rotation.y = atan2(-dir_plana.x, -dir_plana.z)

func ejecutar_disparo() -> void:
	if _cooldown_recarga > 0.0:
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
		
		var pos_salida = marcador_boca_canon.global_position + (dir_disparo * 0.4) if is_instance_valid(marcador_boca_canon) else global_position + (dir_disparo * 2.2)
		vivo_lanzado.global_position = pos_salida
		vivo_lanzado.velocity = dir_disparo * fuerza_disparo
		if not Engine.is_editor_hint() and vivo_lanzado.has_method("_al_realizar_salto"):
			vivo_lanzado._al_realizar_salto(1)
		
		_jugador_cargado = null
		_tiempo_en_recamara = 0.0
		_cooldown_recarga = 1.2
		_actualizar_estado_luz_recamara()
		vivo_expulsado_de_canon.emit(vivo_lanzado)
	else:
		_cooldown_recarga = 0.5
		_actualizar_estado_luz_recamara()

func _expulsar_vivo_sin_disparar() -> void:
	if is_instance_valid(_jugador_cargado):
		var vivo = _jugador_cargado
		_restaurar_colisiones_vivo(vivo)
		
		vivo.global_position = global_position + Vector3(0.0, 2.4, 0.0)
		vivo.velocity = Vector3.UP * 5.0
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
	if is_instance_valid(_jugador_cargado):
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
