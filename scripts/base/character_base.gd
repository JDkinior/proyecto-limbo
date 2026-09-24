extends CharacterBody3D
class_name CharacterBase

# Parámetros compartidos
@export var VELOCIDAD : float = 5.0
@export var ACELERACION_SUELO : float = 24.0
@export var DESACELERACION_SUELO : float = 30.0
@export var ACELERACION_AIRE : float = 12.0
@export var DESACELERACION_AIRE : float = 12.0
@export var VELOCIDAD_ROTACION_PERSONAJE : float = 12.0
@export var LIMITE_CAIDA_Y : float = -2.0

@export_group("Camara Inteligente")
@export var SENSIBILIDAD_CAMARA : float = 0.005
@export var SUAVIDAD_CAMARA : float = 18.0
@export var DISTANCIA_CAMARA : float = 3.5
@export var MARGEN_COLISION_CAMARA : float = 0.15
@export var PITCH_DEFECTO_CAMARA : float = -0.14            # ~-8.0 grados (mirando ligeramente hacia abajo)
@export var LIMITE_PITCH_MIN : float = -0.70               # ~-40 grados
@export var LIMITE_PITCH_MAX : float = 0.35                # ~+20 grados

@export_group("Salto Compartido")
@export var FUERZA_SALTO : float = 7.5
@export var MULTIPLICADOR_SEGUNDO_SALTO : float = 0.9
@export var MULTIPLICADOR_CAIDA : float = 2.0
@export var MULTIPLICADOR_CORTE_SALTO : float = 2.2
@export var MULTIPLICADOR_GRAVEDAD_APICE : float = 1.0
@export var UMBRAL_VELOCIDAD_APICE : float = 1.6
@export var VELOCIDAD_MAX_CAIDA : float = 26.0
@export var TIEMPO_COYOTE : float = 0.15
@export var TIEMPO_BUFFER_SALTO : float = 0.14
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

# Variables para interpolación de red (anti-stuttering)
var sync_position: Vector3
var sync_rotation: Vector3

# ===================================================================
# GESTIÓN DE FUERZAS EXTERNAS Y VÓRTICES (TORBELLINOS)
# ===================================================================
var _fuerza_vortice_acumulada: Vector3 = Vector3.ZERO
var _arrastre_descendente_vortice: float = 0.0
var _vortice_esta_absorbido: bool = false
var _tiempo_absorcion_restante: float = 0.0
var _duracion_absorcion_total: float = 1.0
var _centro_absorcion: Vector3 = Vector3.ZERO
var _impulso_expulsion_pendiente: Vector3 = Vector3.ZERO
var _angulo_giro_absorcion: float = 0.0
var _radio_orbita_absorcion: float = 0.6
var _velocidad_giro_absorcion: float = 14.0

signal fantasma_absorbido_en_vortice(centro: Vector3, duracion: float)
signal fantasma_expulsado_de_vortice(impulso: Vector3)

var _nodo_vortice_origen: Node3D = null

func aplicar_fuerza_vortice(fuerza_horizontal: Vector3, arrastre_vertical: float = 0.0) -> void:
	_fuerza_vortice_acumulada += fuerza_horizontal
	_arrastre_descendente_vortice = maxf(_arrastre_descendente_vortice, arrastre_vertical)

func recibir_impulso_externo(impulso: Vector3) -> void:
	velocity += impulso

func ser_absorbido_en_vortice(centro: Vector3, duracion: float, impulso_salida: Vector3, nodo_vortice: Node3D = null) -> void:
	if _vortice_esta_absorbido:
		return
	_vortice_esta_absorbido = true
	_tiempo_absorcion_restante = duracion
	_duracion_absorcion_total = maxf(duracion, 0.1)
	_centro_absorcion = centro
	_nodo_vortice_origen = nodo_vortice
	_impulso_expulsion_pendiente = impulso_salida
	_velocidad_giro_absorcion = 14.0
	
	var offset = global_position - centro
	_angulo_giro_absorcion = atan2(offset.x, -offset.z)
	_radio_orbita_absorcion = clampf(Vector2(offset.x, offset.z).length(), 0.25, 1.2)
	velocity = Vector3.ZERO
	fantasma_absorbido_en_vortice.emit(centro, duracion)

func esta_absorbido_en_vortice() -> bool:
	return _vortice_esta_absorbido

func obtener_progreso_absorcion() -> float:
	if not _vortice_esta_absorbido: return 0.0
	return 1.0 - clampf(_tiempo_absorcion_restante / _duracion_absorcion_total, 0.0, 1.0)


var particulas_corazon: CPUParticles3D = null
var tiempo_cerca_otro: float = 0.0
var _otro_jugador_cache: Node3D = null
const DISTANCIA_PROXIMIDAD_CORAZON: float = 1.4 # Deben estar pegados lado a lado
const TIEMPO_REQUERIDO_PROXIMIDAD: float = 5.0 # 5 segundos continuos de estar cerca


@onready var pivote_camara = $Node3D
var controles_tactiles: Node = null

func obtener_camara() -> Camera3D:
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
		return null
	if pivote_camara is SpringArm3D:
		return pivote_camara as SpringArm3D
	var arm = pivote_camara.get_node_or_null("SpringArm3D")
	if arm is SpringArm3D:
		return arm
	return pivote_camara.find_child("SpringArm3D", true, false) as SpringArm3D

func centrar_camara_inmediatamente():
	objetivo_rotacion_y = rotation.y
	objetivo_rotacion_x = PITCH_DEFECTO_CAMARA

func _ready():
	objetivo_rotacion_y = rotation.y
	var spring_arm = obtener_spring_arm()
	if spring_arm:
		spring_arm.add_excluded_object(get_rid())
		spring_arm.spring_length = DISTANCIA_CAMARA
		spring_arm.margin = MARGEN_COLISION_CAMARA
		objetivo_rotacion_x = spring_arm.rotation.x
	elif pivote_camara:
		objetivo_rotacion_x = pivote_camara.rotation.x
	else:
		objetivo_rotacion_x = PITCH_DEFECTO_CAMARA

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
	
	# Buscar controles táctiles en el grupo global "ui_tactil"
	var nodos_ui = get_tree().get_nodes_in_group("ui_tactil")
	if nodos_ui.size() > 0:
		controles_tactiles = nodos_ui[0]

func es_activo() -> bool:
	if is_instance_valid(RedManager) and (RedManager.es_un_jugador or multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		var es_fantasma = is_in_group("fantasmas") or name.to_lower().contains("fantasma")
		if RedManager.personaje_activo_solo == "fantasma":
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


func actualizar_visibilidad_local(preservar_rotacion_camara: bool = false):
	# Lógica base de cámara, los hijos extenderán esto
	var es_mio = es_activo()
	if pivote_camara:
		if es_mio:
			pivote_camara.top_level = true
			pivote_camara.global_position = global_position
			if not preservar_rotacion_camara:
				objetivo_rotacion_y = rotation.y
				pivote_camara.rotation.y = rotation.y
			else:
				pivote_camara.rotation.y = objetivo_rotacion_y
			var arm = obtener_spring_arm()
			if arm:
				arm.add_excluded_object(get_rid())
				arm.rotation.x = objetivo_rotacion_x
			else:
				pivote_camara.rotation.x = objetivo_rotacion_x
		else:
			pivote_camara.top_level = false
			
		var cam = obtener_camara()
		if cam:
			cam.current = es_mio

func obtener_entorno_personaje() -> Environment:
	return null

func obtener_cull_mask_personaje() -> int:
	return 1048575

func entrada_bloqueada() -> bool:
	if not is_inside_tree():
		return true
	if is_instance_valid(ScoreManager) and not ScoreManager.cronometro_activo and ScoreManager.tiempo_transcurrido > 0.0:
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

func procesar_camara_base(delta: float):
	if not es_activo() or entrada_bloqueada(): return
	if is_instance_valid(RedManager) and RedManager.transicion_en_progreso: return

	if pivote_camara:
		pivote_camara.global_position = global_position

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

		if controles_tactiles:
			var giro = controles_tactiles.consumir_arrastre()
			if giro != Vector2.ZERO:
				objetivo_rotacion_y -= giro.x * SENSIBILIDAD_CAMARA
				objetivo_rotacion_x = clamp(objetivo_rotacion_x - giro.y * SENSIBILIDAD_CAMARA, LIMITE_PITCH_MIN, LIMITE_PITCH_MAX)

		# Control de rotación con stick derecho de control / gamepad
		var dev_cam = 0
		if is_inside_tree() and get_tree() and get_tree().root and get_tree().root.has_node("GamepadManager"):
			dev_cam = get_tree().root.get_node("GamepadManager").dispositivo_activo
		var stick_cam_x = Input.get_joy_axis(dev_cam, JOY_AXIS_RIGHT_X)
		var stick_cam_y = Input.get_joy_axis(dev_cam, JOY_AXIS_RIGHT_Y)
		var stick_vec = Vector2(stick_cam_x, stick_cam_y)
		var deadzone_cam = 0.15
		if stick_vec.length() > deadzone_cam:
			var factor_cam = (stick_vec.length() - deadzone_cam) / (1.0 - deadzone_cam)
			var dir_cam = stick_vec.normalized() * factor_cam
			var vel_cam_mando = 3.2 # Radianes por segundo
			objetivo_rotacion_y -= dir_cam.x * vel_cam_mando * delta
			objetivo_rotacion_x = clamp(objetivo_rotacion_x - dir_cam.y * vel_cam_mando * delta, LIMITE_PITCH_MIN, LIMITE_PITCH_MAX)

		var suavizado_camara = 1.0 - exp(-SUAVIDAD_CAMARA * delta)
		pivote_camara.rotation.y = lerp_angle(pivote_camara.rotation.y, objetivo_rotacion_y, suavizado_camara)
		
		var arm = obtener_spring_arm()
		if arm:
			pivote_camara.rotation.x = 0.0
			arm.rotation.x = lerp_angle(arm.rotation.x, objetivo_rotacion_x, suavizado_camara)
		else:
			pivote_camara.rotation.x = lerp_angle(pivote_camara.rotation.x, objetivo_rotacion_x, suavizado_camara)

func esta_planeando() -> bool:
	if _vortice_esta_absorbido:
		return false
	if not PUEDE_PLANEAR or is_on_floor():
		return false
	if not es_activo() or entrada_bloqueada():
		return false
	if is_instance_valid(RedManager) and RedManager.transicion_en_progreso:
		return false
	var salto_mantenido = Input.is_action_pressed("saltar") or Input.is_action_pressed("ui_accept")
	return salto_mantenido and velocity.y <= 0.0

func procesar_salto_base(delta: float):
	if _vortice_esta_absorbido:
		_arrastre_descendente_vortice = 0.0
		return

	var salto_mantenido = es_activo() and not entrada_bloqueada() and (Input.is_action_pressed("saltar") or Input.is_action_pressed("ui_accept"))
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
		elif velocity.y > 0.0 and not salto_mantenido:
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
			# Frenado suave amortiguado si se empieza a planear a alta velocidad de caída
			if velocity.y < -VELOCIDAD_MAX_CAIDA_PLANEO:
				velocity.y = move_toward(velocity.y, -VELOCIDAD_MAX_CAIDA_PLANEO, SUAVIDAD_FRENADO_PLANEO * delta)
			else:
				velocity.y = maxf(velocity.y, -VELOCIDAD_MAX_CAIDA_PLANEO)
		elif VELOCIDAD_MAX_CAIDA > 0.0:
			velocity.y = maxf(velocity.y, -VELOCIDAD_MAX_CAIDA)
			
		tiempo_desde_suelo += delta
		# Si se cae de una plataforma y expira el tiempo coyote, se consume el salto del suelo
		if tiempo_desde_suelo > TIEMPO_COYOTE and saltos_realizados == 0:
			saltos_realizados = 1
	else:
		if tiempo_desde_suelo > 0.12 and _vel_y_previa_base < -2.8:
			_al_aterrizar_base(_vel_y_previa_base)
		tiempo_desde_suelo = 0.0
		saltos_realizados = 0

	_vel_y_previa_base = velocity.y

	if not es_activo() or entrada_bloqueada() or (is_instance_valid(RedManager) and RedManager.transicion_en_progreso):
		return

	if Input.is_action_just_pressed("saltar") or Input.is_action_just_pressed("ui_accept"):
		tiempo_desde_salto = 0.0
	else:
		tiempo_desde_salto += delta

	if tiempo_desde_salto <= TIEMPO_BUFFER_SALTO:
		if (is_on_floor() or tiempo_desde_suelo <= TIEMPO_COYOTE) and saltos_realizados == 0:
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
	if es_activo() and is_instance_valid(VibrationManager):
		var factor = clampf(abs(vel_y) / 8.0, 0.4, 1.8)
		VibrationManager.vibrar_aterrizaje(factor)

func _al_realizar_salto(numero_salto: int):
	# Feedback háptico y vibración de salto
	if es_activo() and is_instance_valid(VibrationManager):
		VibrationManager.vibrar_salto(numero_salto)

func obtener_direccion_movimiento() -> Vector3:
	if entrada_bloqueada():
		return Vector3.ZERO
		
	var input_dir = Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras", 0.05)
		
	if input_dir == Vector2.ZERO:
		return Vector3.ZERO

	var cam_basis = Basis()
	if pivote_camara:
		cam_basis = pivote_camara.global_transform.basis
	else:
		cam_basis = global_transform.basis
		
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

func aplicar_friccion_y_movimiento(direccion: Vector3, delta: float):
	if _vortice_esta_absorbido:
		if is_instance_valid(_nodo_vortice_origen):
			_centro_absorcion = _nodo_vortice_origen.global_position
		_tiempo_absorcion_restante -= delta
		_angulo_giro_absorcion += _velocidad_giro_absorcion * delta
		_radio_orbita_absorcion = move_toward(_radio_orbita_absorcion, 0.20, 1.4 * delta)
		
		var target_x = _centro_absorcion.x + sin(_angulo_giro_absorcion) * _radio_orbita_absorcion
		var target_z = _centro_absorcion.z - cos(_angulo_giro_absorcion) * _radio_orbita_absorcion
		var target_y = move_toward(global_position.y, _centro_absorcion.y - 0.4, 3.0 * delta)
		
		var destino = Vector3(target_x, target_y, target_z)
		velocity = (destino - global_position) / maxf(delta, 0.001)
		move_and_slide()
		
		var dir_vel = Vector2(velocity.x, velocity.z)
		if dir_vel.length_squared() > 0.01:
			var target_rot = atan2(-velocity.x, -velocity.z)
			rotation.y = lerp_angle(rotation.y, target_rot, 20.0 * delta)
		
		if _tiempo_absorcion_restante <= 0.0:
			_vortice_esta_absorbido = false
			_nodo_vortice_origen = null
			velocity = _impulso_expulsion_pendiente
			_fuerza_vortice_acumulada = Vector3.ZERO
			fantasma_expulsado_de_vortice.emit(_impulso_expulsion_pendiente)
		
		_comprobar_caida_vacio()
		if es_activo() and pivote_camara and pivote_camara.top_level:
			pivote_camara.global_position = global_position
		return

	var planeando = esta_planeando()
	var vel_max = VELOCIDAD * (MULTIPLICADOR_VELOCIDAD_PLANEO if planeando else 1.0)
	var velocidad_objetivo = direccion * vel_max
	var tasa_aceleracion = ACELERACION_SUELO if is_on_floor() else (ACELERACION_AIRE * (MULTIPLICADOR_ACELERACION_PLANEO if planeando else 1.0))
	
	if direccion != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, velocidad_objetivo.x, tasa_aceleracion * delta)
		velocity.z = move_toward(velocity.z, velocidad_objetivo.z, tasa_aceleracion * delta)
	else:
		var tasa_frenado = DESACELERACION_SUELO if is_on_floor() else DESACELERACION_AIRE
		velocity.x = move_toward(velocity.x, 0.0, tasa_frenado * delta)
		velocity.z = move_toward(velocity.z, 0.0, tasa_frenado * delta)
	
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

	_comprobar_caida_vacio()
	
	# Aseguramos que la cámara siga exactamente la posición del jugador después del movimiento físico
	if es_activo() and pivote_camara and pivote_camara.top_level:
		pivote_camara.global_position = global_position

func procesar_movimiento_base(delta: float):
	if is_instance_valid(RedManager) and RedManager.transicion_en_progreso:
		aplicar_friccion_y_movimiento(Vector3.ZERO, delta)
		return

	if _vortice_esta_absorbido:
		aplicar_friccion_y_movimiento(Vector3.ZERO, delta)
		return

	var direccion = obtener_direccion_movimiento()
	
	if direccion != Vector3.ZERO:
		# Rotar suavemente al personaje hacia la dirección en la que se está moviendo
		var target_angle = atan2(-direccion.x, -direccion.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 1.0 - exp(-VELOCIDAD_ROTACION_PERSONAJE * delta))
		
	aplicar_friccion_y_movimiento(direccion, delta)
	_procesar_proximidad_corazon(delta)

func resetear_estados():
	saltos_realizados = 0
	tiempo_desde_suelo = 0.0
	tiempo_desde_salto = 0.0
	_vortice_esta_absorbido = false
	_tiempo_absorcion_restante = 0.0
	_fuerza_vortice_acumulada = Vector3.ZERO
	_arrastre_descendente_vortice = 0.0
	_nodo_vortice_origen = null
	_al_resetear_estados()

func _al_resetear_estados():
	# Hook virtual para subclases
	pass

func establecer_punto_control(nueva_pos: Vector3, nueva_rot: Vector3 = Vector3.ZERO) -> void:
	punto_control = nueva_pos
	if nueva_rot != Vector3.ZERO:
		rotacion_punto_control = nueva_rot

func reaparecer() -> void:
	if es_activo() and is_instance_valid(VibrationManager):
		VibrationManager.vibrar_dano()

	var destino = punto_control if punto_control != Vector3.ZERO else posicion_inicial
	var rot_dest = rotacion_punto_control if punto_control != Vector3.ZERO else rotacion_inicial
	global_position = destino
	velocity = Vector3.ZERO
	rotation = rot_dest
	sync_position = destino
	sync_rotation = rot_dest

	resetear_estados()

	objetivo_rotacion_y = rot_dest.y
	objetivo_rotacion_x = rotacion_inicial_camara_x

	if pivote_camara:
		pivote_camara.global_position = destino
		pivote_camara.rotation.y = rot_dest.y
		var arm = obtener_spring_arm()
		if arm:
			pivote_camara.rotation.x = 0.0
			arm.rotation.x = rotacion_inicial_camara_x
		else:
			pivote_camara.rotation.x = rotacion_inicial_camara_x

func _comprobar_caida_vacio():
	if global_position.y < LIMITE_CAIDA_Y:
		reaparecer()

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
	mat.albedo_texture = _generar_textura_corazon()
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

	if is_instance_valid(RedManager):
		var es_fantasma = is_in_group("fantasmas") or name.to_lower().contains("fantasma")
		var candidato = RedManager.jugador_vivo if es_fantasma else RedManager.fantasma
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

	for hijo in nodo.get_children():
		_aplicar_silueta_recursiva(hijo)
