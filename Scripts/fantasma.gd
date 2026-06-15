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
@export var LIMITE_CAIDA_Y : float = -20.0
@export var RADIO_DETECCION : float = 10.0  # Radio para detectar plataformas cercanas

# Gravedad predeterminada del proyecto
var gravedad = ProjectSettings.get_setting("physics/3d/default_gravity")
var tiempo_desde_suelo : float = 0.0
var tiempo_desde_salto : float = 0.0
var objetivo_rotacion_y : float = 0.0
var objetivo_rotacion_x : float = 0.0
var saltos_realizados : int = 0
var posicion_inicial : Vector3

# Sistema de plataformas
var plataformas_activas : Dictionary = {}  # {nodo_path: bool}
var plataforma_seleccionada : Node3D = null
var plataformas_detectadas : Array = []
var plataformas_registradas : Array = []

@onready var pivote_camara = $Node3D
@onready var controles_tactiles = get_node_or_null("../Controles_Tactiles")

func _ready():
	objetivo_rotacion_y = rotation.y
	if pivote_camara:
		objetivo_rotacion_x = pivote_camara.rotation.x
	posicion_inicial = global_position
	# Inicializar sistema de plataformas
	_inicializar_plataformas()
	print("[Fantasma] Inicializado en posición: ", global_position)

func _inicializar_plataformas():
	"""Encuentra todas las plataformas interactuables en el mundo"""
	print("[Fantasma] Buscando plataformas en el mundo...")
	plataformas_registradas.clear()
	plataformas_activas.clear()
	
	# Buscar todos los nodos StaticBody3D que tengan nombre con "Caja_Fisica"
	_buscar_plataformas(get_tree().root)
	
	print("[Fantasma] Plataformas encontradas: ", plataformas_registradas.size())
	for plat in plataformas_registradas:
		print("  - ", plat.name, " en posición ", plat.global_position)

func _buscar_plataformas(nodo: Node) -> void:
	"""Búsqueda recursiva de plataformas en el árbol de escenas"""
	if nodo is StaticBody3D and "Caja_Fisica" in nodo.name:
		plataformas_registradas.append(nodo)
		plataformas_activas[nodo.get_path()] = false  # Inicialmente desactivadas
	
	for hijo in nodo.get_children():
		_buscar_plataformas(hijo)

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

	# --- 3. CONTROL DE SALTO ---
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
		input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		
	var direccion = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var velocidad_objetivo = direccion * VELOCIDAD
	var tasa_aceleracion = ACELERACION_SUELO if is_on_floor() else ACELERACION_AIRE
	
	if direccion != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, velocidad_objetivo.x, tasa_aceleracion * delta)
		velocity.z = move_toward(velocity.z, velocidad_objetivo.z, tasa_aceleracion * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, DESACELERACION_SUELO * delta)
		velocity.z = move_toward(velocity.z, 0, DESACELERACION_SUELO * delta)

	# --- 5. DETECCIÓN Y MANIPULACIÓN DE PLATAFORMAS ---
	_actualizar_plataformas_detectadas()
	_procesar_entrada_plataformas()

	# --- 6. MOVIMIENTO FINAL ---
	if global_position.y < LIMITE_CAIDA_Y:
		global_position = posicion_inicial

	move_and_slide()

func _actualizar_plataformas_detectadas() -> void:
	"""Detecta plataformas cercanas al fantasma usando distancia directa"""
	plataformas_detectadas.clear()
	
	# Búsqueda simple basada en distancia
	for plataforma in plataformas_registradas:
		var distancia = global_position.distance_to(plataforma.global_position)
		if distancia <= RADIO_DETECCION:
			plataformas_detectadas.append(plataforma)

func _procesar_entrada_plataformas() -> void:
	"""Procesa la entrada para seleccionar/deseleccionar plataformas"""
	# Detectar clic/tap o tecla ui_select
	if Input.is_action_just_pressed("ui_select") and plataformas_detectadas.size() > 0:
		# Seleccionar la plataforma más cercana
		var plataforma_cercana = _obtener_plataforma_mas_cercana()
		if plataforma_cercana:
			_alternar_plataforma(plataforma_cercana)

func _obtener_plataforma_mas_cercana() -> Node3D:
	"""Obtiene la plataforma detectada más cercana al fantasma"""
	var distancia_minima = INF
	var plataforma_cercana = null
	
	for plataforma in plataformas_detectadas:
		var distancia = global_position.distance_to(plataforma.global_position)
		if distancia < distancia_minima:
			distancia_minima = distancia
			plataforma_cercana = plataforma
	
	return plataforma_cercana

func _alternar_plataforma(plataforma: Node3D) -> void:
	"""Alterna el estado de una plataforma (activa/inactiva)"""
	var path = plataforma.get_path()
	var estado_actual = plataformas_activas.get(path, false)
	plataformas_activas[path] = not estado_actual
	
	# Cambiar la visibilidad y colisión de la plataforma
	_aplicar_estado_plataforma(plataforma, plataformas_activas[path])
	
	print("[Fantasma] Plataforma '%s' %s (distancia: %.2f m)" % [
		plataforma.name,
		"ACTIVADA" if plataformas_activas[path] else "DESACTIVADA",
		global_position.distance_to(plataforma.global_position)
	])

func _aplicar_estado_plataforma(plataforma: Node3D, activa: bool) -> void:
	"""Aplica el estado de visibilidad y colisión a una plataforma"""
	if activa:
		# Activa: visible y colisionable con el jugador vivo
		plataforma.collision_layer = 2
		plataforma.collision_mask = 2
		_cambiar_opacidad_plataforma(plataforma, 1.0)  # Visible
	else:
		# Inactiva: invisible y sin colisión
		plataforma.collision_layer = 0
		plataforma.collision_mask = 0
		_cambiar_opacidad_plataforma(plataforma, 0.5)  # Semi-transparente

func _cambiar_opacidad_plataforma(plataforma: Node3D, opacidad: float) -> void:
	"""Cambia la opacidad del MeshInstance3D de una plataforma"""
	# Buscar el MeshInstance3D dentro de la plataforma
	for hijo in plataforma.get_children():
		if hijo is MeshInstance3D:
			# Obtener el material del mesh
			var material = hijo.get_active_material(0)
			if material:
				material = material.duplicate()
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				material.alpha_scissor = 0.5
				var color = material.albedo_color
				color.a = opacidad
				material.albedo_color = color
				hijo.set_surface_override_material(0, material)
			break

func obtener_plataformas_activas() -> Dictionary:
	"""Retorna las plataformas activas (para sincronización con el jugador vivo)"""
	return plataformas_activas.duplicate()

func obtener_plataformas_detectadas() -> Array:
	"""Retorna las plataformas actualmente detectadas"""
	return plataformas_detectadas.duplicate()

func reiniciar_posicion() -> void:
	"""Reinicia el fantasma a su posición inicial"""
	global_position = posicion_inicial
	velocity = Vector3.ZERO
	
	# Desactivar todas las plataformas al reiniciar
	for plat_path in plataformas_activas.keys():
		plataformas_activas[plat_path] = false
		var plat = get_tree().root.get_node_or_null(plat_path)
		if plat:
			_aplicar_estado_plataforma(plat, false)
