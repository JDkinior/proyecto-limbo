extends CharacterBody3D

@export var VELOCIDAD : float = 5.0
@export var ACELERACION_SUELO : float = 24.0
@export var DESACELERACION_SUELO : float = 30.0
@export var ACELERACION_AIRE : float = 10.0
@export var FUERZA_SALTO = 4.5
@export var MULTIPLICADOR_SEGUNDO_SALTO : float = 0.9
@export var MULTIPLICADOR_CAIDA : float = 1.9
@export var MULTIPLICADOR_CORTE_SALTO : float = 2.2
@export var SENSIBILIDAD_CAMARA = 0.005
@export var SUAVIDAD_CAMARA : float = 18.0
@export var TIEMPO_COYOTE : float = 0.12
@export var TIEMPO_BUFFER_SALTO : float = 0.12
@export var MAX_SALTOS : int = 2

# Gravedad predeterminada del proyecto
var gravedad = ProjectSettings.get_setting("physics/3d/default_gravity")
var tiempo_desde_suelo : float = 0.0
var tiempo_desde_salto : float = 0.0
var objetivo_rotacion_y : float = 0.0
var objetivo_rotacion_x : float = 0.0
var saltos_realizados : int = 0

@onready var pivote_camara = $Node3D
@onready var controles_tactiles = get_node_or_null("../Controles_Tactiles")

func _ready():
	objetivo_rotacion_y = rotation.y
	if pivote_camara:
		objetivo_rotacion_x = pivote_camara.rotation.x

func _physics_process(delta):
	# --- 1. CONTROL DE CÁMARA TÁCTIL ---

	if controles_tactiles and pivote_camara:
		var giro = controles_tactiles.consumir_arrastre()
		if giro != Vector2.ZERO:
			objetivo_rotacion_y -= giro.x * SENSIBILIDAD_CAMARA
			objetivo_rotacion_x = clamp(objetivo_rotacion_x - giro.y * SENSIBILIDAD_CAMARA, deg_to_rad(-40), deg_to_rad(20))

	var suavizado_camara = 1.0 - exp(-SUAVIDAD_CAMARA * delta)
	rotation.y = lerp_angle(rotation.y, objetivo_rotacion_y, suavizado_camara)
	if pivote_camara:
		pivote_camara.rotation.x = lerp_angle(pivote_camara.rotation.x, objetivo_rotacion_x, suavizado_camara)

	# --- 2. GRAVEDAD ---
	var salto_mantenido = Input.is_action_pressed("saltar") or Input.is_action_pressed("ui_accept")
	if not is_on_floor():
		var gravedad_actual = gravedad
		if velocity.y < 0.0:
			gravedad_actual *= MULTIPLICADOR_CAIDA
		elif velocity.y > 0.0 and not salto_mantenido:
			gravedad_actual *= MULTIPLICADOR_CORTE_SALTO
		velocity.y -= gravedad_actual * delta
		tiempo_desde_suelo += delta
	else:
		tiempo_desde_suelo = 0.0
		saltos_realizados = 0

	# --- 3. CONTROL DE SALTO (Botón táctil o teclado) ---
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

	# --- 4. MOVIMIENTO EN BASE A LA DIRECCIÓN DE LA CÁMARA ---
	var joystick = get_node_or_null("../Controles_Tactiles/Joystick_Virtual")
	var input_dir = Vector2.ZERO
	
	if joystick and joystick.tocando:
		input_dir = joystick.vector_salida.limit_length(1.0)
	else:
		# Soporte para seguir probando en PC con las flechas del teclado
		input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		
	# CALCULAMOS LA DIRECCIÓN RELATIVA A LA ROTACIÓN ACTUAL DEL JUGADOR/CÁMARA
	# Usamos transform.basis para alinear el movimiento horizontal (X, Z) con la vista
	var direccion = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var velocidad_objetivo = direccion * VELOCIDAD
	var tasa_aceleracion = ACELERACION_SUELO if is_on_floor() else ACELERACION_AIRE
	
	if direccion != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, velocidad_objetivo.x, tasa_aceleracion * delta)
		velocity.z = move_toward(velocity.z, velocidad_objetivo.z, tasa_aceleracion * delta)
	else:
		# Frenado suave si se suelta el control
		var tasa_frenado = DESACELERACION_SUELO if is_on_floor() else ACELERACION_AIRE
		velocity.x = move_toward(velocity.x, 0.0, tasa_frenado * delta)
		velocity.z = move_toward(velocity.z, 0.0, tasa_frenado * delta)

	move_and_slide()
