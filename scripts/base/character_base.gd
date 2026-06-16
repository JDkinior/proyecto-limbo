extends CharacterBody3D
class_name CharacterBase

# Parámetros compartidos
@export var VELOCIDAD : float = 5.0
@export var ACELERACION_SUELO : float = 24.0
@export var DESACELERACION_SUELO : float = 30.0
@export var ACELERACION_AIRE : float = 10.0
@export var SENSIBILIDAD_CAMARA = 0.005
@export var SUAVIDAD_CAMARA : float = 18.0
@export var LIMITE_CAIDA_Y : float = -20.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var objetivo_rotacion_y : float = 0.0
var objetivo_rotacion_x : float = 0.0
var posicion_inicial : Vector3

@onready var pivote_camara = $Node3D
@onready var controles_tactiles = get_node_or_null("../Controles_Tactiles")

func _ready():
	objetivo_rotacion_y = rotation.y
	if pivote_camara:
		objetivo_rotacion_x = pivote_camara.rotation.x
	posicion_inicial = global_position
	actualizar_visibilidad_local()

func actualizar_visibilidad_local():
	# Lógica base de cámara, los hijos extenderán esto
	var es_mio = is_multiplayer_authority()
	if pivote_camara and pivote_camara.has_node("Camera3D"):
		pivote_camara.get_node("Camera3D").current = es_mio

func procesar_camara_base(delta: float):
	if not is_multiplayer_authority(): return

	if controles_tactiles and pivote_camara:
		var giro = controles_tactiles.consumir_arrastre()
		if giro != Vector2.ZERO:
			objetivo_rotacion_y -= giro.x * SENSIBILIDAD_CAMARA
			objetivo_rotacion_x = clamp(objetivo_rotacion_x - giro.y * SENSIBILIDAD_CAMARA, deg_to_rad(-40), deg_to_rad(20))

	var suavizado_camara = 1.0 - exp(-SUAVIDAD_CAMARA * delta)
	rotation.y = lerp_angle(rotation.y, objetivo_rotacion_y, suavizado_camara)
	if pivote_camara:
		pivote_camara.rotation.x = lerp_angle(pivote_camara.rotation.x, objetivo_rotacion_x, suavizado_camara)

func obtener_direccion_movimiento() -> Vector3:
	var joystick = get_node_or_null("../Controles_Tactiles/Joystick_Virtual")
	var input_dir = Vector2.ZERO
	
	if joystick and joystick.tocando:
		input_dir = joystick.vector_salida.limit_length(1.0)
	else:
		input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		
	return (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

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

func _comprobar_caida_vacio():
	if global_position.y < LIMITE_CAIDA_Y:
		global_position = posicion_inicial
		velocity = Vector3.ZERO
		if has_method("resetear_estados"): call("resetear_estados")
