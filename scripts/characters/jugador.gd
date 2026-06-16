extends CharacterBase
class_name Jugador

@export var FUERZA_SALTO = 4.5
@export var MULTIPLICADOR_SEGUNDO_SALTO : float = 0.9
@export var MULTIPLICADOR_CAIDA : float = 1.9
@export var MULTIPLICADOR_CORTE_SALTO : float = 2.2
@export var TIEMPO_COYOTE : float = 0.12
@export var TIEMPO_BUFFER_SALTO : float = 0.12
@export var MAX_SALTOS : int = 2

var tiempo_desde_suelo : float = 0.0
var tiempo_desde_salto : float = 0.0
var saltos_realizados : int = 0

func _ready():
	super()
	if is_instance_valid(RedManager):
		RedManager.registrar_jugador(self)

func actualizar_visibilidad_local():
	super() # Llama a la cámara base
	"""Configura la cámara y resetea la UI para el jugador vivo"""
	var es_mio = is_multiplayer_authority()

	if es_mio and controles_tactiles:
		print("[Jugador] Restaurando interfaz original...")
		controles_tactiles.modulate = Color(1, 1, 1)
		# Quitamos el shader de todos los elementos de la interfaz
		_limpiar_shader_recursivo(controles_tactiles)

func _limpiar_shader_recursivo(nodo: Node):
	"""Elimina materiales de shader para recuperar texturas originales"""
	if nodo is CanvasItem:
		nodo.material = null
		
	for hijo in nodo.get_children():
		_limpiar_shader_recursivo(hijo)

func resetear_estados():
	saltos_realizados = 0
	tiempo_desde_suelo = 0.0

func _physics_process(delta):
	if not is_multiplayer_authority(): return

	procesar_camara_base(delta)

	# --- 2. GRAVEDAD ---
	var salto_mantenido = Input.is_action_pressed("saltar") or Input.is_action_pressed("ui_accept")
	if not is_on_floor():
		var gravedad_actual = gravity
		if velocity.y < 0.0: gravedad_actual *= MULTIPLICADOR_CAIDA
		elif velocity.y > 0.0 and not salto_mantenido: gravedad_actual *= MULTIPLICADOR_CORTE_SALTO
		velocity.y -= gravedad_actual * delta
		tiempo_desde_suelo += delta
	else:
		tiempo_desde_suelo = 0.0
		saltos_realizados = 0

	# --- 3. CONTROL DE SALTO (Botón táctil o teclado) ---
	if Input.is_action_just_pressed("saltar") or Input.is_action_just_pressed("ui_accept"): tiempo_desde_salto = 0.0
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

	var dir = obtener_direccion_movimiento()
	aplicar_friccion_y_movimiento(dir, delta)
