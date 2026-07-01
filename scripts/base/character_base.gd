extends CharacterBody3D
class_name CharacterBase

# Parámetros compartidos
@export var VELOCIDAD : float = 5.0
@export var ACELERACION_SUELO : float = 24.0
@export var DESACELERACION_SUELO : float = 30.0
@export var ACELERACION_AIRE : float = 10.0
@export var SENSIBILIDAD_CAMARA = 0.005
@export var SUAVIDAD_CAMARA : float = 18.0
@export var VELOCIDAD_ROTACION_PERSONAJE : float = 12.0
@export var LIMITE_CAIDA_Y : float = -20.0
@export_group("Salto Compartido")
@export var FUERZA_SALTO = 4.5
@export var MULTIPLICADOR_SEGUNDO_SALTO : float = 0.9
@export var MULTIPLICADOR_CAIDA : float = 1.9
@export var MULTIPLICADOR_CORTE_SALTO : float = 2.2
@export var TIEMPO_COYOTE : float = 0.12
@export var TIEMPO_BUFFER_SALTO : float = 0.12
@export var MAX_SALTOS : int = 2

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var objetivo_rotacion_y : float = 0.0
var objetivo_rotacion_x : float = 0.0
var posicion_inicial : Vector3
var tiempo_desde_suelo : float = 0.0
var tiempo_desde_salto : float = 0.0
var saltos_realizados : int = 0

@onready var pivote_camara = $Node3D
var controles_tactiles: Node = null

func _ready():
	objetivo_rotacion_y = rotation.y
	if pivote_camara:
		objetivo_rotacion_x = pivote_camara.rotation.x
	posicion_inicial = global_position
	actualizar_visibilidad_local()
	
	# Buscar controles táctiles en el grupo global "ui_tactil"
	var nodos_ui = get_tree().get_nodes_in_group("ui_tactil")
	if nodos_ui.size() > 0:
		controles_tactiles = nodos_ui[0]

func actualizar_visibilidad_local():
	# Lógica base de cámara, los hijos extenderán esto
	var es_mio = is_multiplayer_authority()
	if pivote_camara:
		if es_mio:
			pivote_camara.top_level = true
			pivote_camara.global_position = global_position
			objetivo_rotacion_y = rotation.y
			pivote_camara.rotation.y = rotation.y
		else:
			pivote_camara.top_level = false
			
		if pivote_camara.has_node("Camera3D"):
			pivote_camara.get_node("Camera3D").current = es_mio

func procesar_camara_base(delta: float):
	if not is_multiplayer_authority(): return

	if pivote_camara:
		pivote_camara.global_position = global_position

		# Buscar controles táctiles si aún no se han referenciado
		if not controles_tactiles:
			var nodos_ui = get_tree().get_nodes_in_group("ui_tactil")
			if nodos_ui.size() > 0:
				controles_tactiles = nodos_ui[0]

		if controles_tactiles:
			var giro = controles_tactiles.consumir_arrastre()
			if giro != Vector2.ZERO:
				objetivo_rotacion_y -= giro.x * SENSIBILIDAD_CAMARA
				objetivo_rotacion_x = clamp(objetivo_rotacion_x - giro.y * SENSIBILIDAD_CAMARA, deg_to_rad(-40), deg_to_rad(20))

		var suavizado_camara = 1.0 - exp(-SUAVIDAD_CAMARA * delta)
		pivote_camara.rotation.y = lerp_angle(pivote_camara.rotation.y, objetivo_rotacion_y, suavizado_camara)
		pivote_camara.rotation.x = lerp_angle(pivote_camara.rotation.x, objetivo_rotacion_x, suavizado_camara)

func procesar_salto_base(delta: float):
	var salto_mantenido = Input.is_action_pressed("saltar") or Input.is_action_pressed("ui_accept")
	if not is_on_floor():
		var gravedad_actual = gravity
		if velocity.y < 0.0:
			gravedad_actual *= MULTIPLICADOR_CAIDA
		elif velocity.y > 0.0 and not salto_mantenido:
			gravedad_actual *= MULTIPLICADOR_CORTE_SALTO
		velocity.y -= gravedad_actual * delta
		tiempo_desde_suelo += delta
	else:
		tiempo_desde_suelo = 0.0
		saltos_realizados = 0

	if Input.is_action_just_pressed("saltar") or Input.is_action_just_pressed("ui_accept"):
		tiempo_desde_salto = 0.0
	else:
		tiempo_desde_salto += delta

	if tiempo_desde_salto <= TIEMPO_BUFFER_SALTO:
		if (is_on_floor() or tiempo_desde_suelo <= TIEMPO_COYOTE) and saltos_realizados == 0:
			velocity.y = FUERZA_SALTO
			saltos_realizados = 1
			tiempo_desde_salto = TIEMPO_BUFFER_SALTO
		elif saltos_realizados < MAX_SALTOS:
			velocity.y = FUERZA_SALTO * MULTIPLICADOR_SEGUNDO_SALTO
			saltos_realizados += 1
			tiempo_desde_salto = TIEMPO_BUFFER_SALTO

func obtener_direccion_movimiento() -> Vector3:
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
	var velocidad_objetivo = direccion * VELOCIDAD
	var tasa_aceleracion = ACELERACION_SUELO if is_on_floor() else ACELERACION_AIRE
	
	if direccion != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, velocidad_objetivo.x, tasa_aceleracion * delta)
		velocity.z = move_toward(velocity.z, velocidad_objetivo.z, tasa_aceleracion * delta)
	else:
		var tasa_frenado = DESACELERACION_SUELO if is_on_floor() else ACELERACION_AIRE
		velocity.x = move_toward(velocity.x, 0.0, tasa_frenado * delta)
		velocity.z = move_toward(velocity.z, 0.0, tasa_frenado * delta)
	
	move_and_slide()
	_comprobar_caida_vacio()
	
	# Aseguramos que la cámara siga exactamente la posición del jugador después del movimiento físico
	if is_multiplayer_authority() and pivote_camara and pivote_camara.top_level:
		pivote_camara.global_position = global_position

func procesar_movimiento_base(delta: float):
	var direccion = obtener_direccion_movimiento()
	
	if direccion != Vector3.ZERO:
		# Rotar suavemente al personaje hacia la dirección en la que se está moviendo
		var target_angle = atan2(-direccion.x, -direccion.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 1.0 - exp(-VELOCIDAD_ROTACION_PERSONAJE * delta))
		
	aplicar_friccion_y_movimiento(direccion, delta)

func resetear_estados():
	saltos_realizados = 0
	tiempo_desde_suelo = 0.0
	tiempo_desde_salto = 0.0

func _comprobar_caida_vacio():
	if global_position.y < LIMITE_CAIDA_Y:
		global_position = posicion_inicial
		velocity = Vector3.ZERO
		resetear_estados()
