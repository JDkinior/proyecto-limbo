extends CharacterBase
class_name Fantasma

signal aura_estado_actualizado(activo: bool, progreso: float)

@export_group("Movimiento Espectral")
@export var FUERZA_SALTO = 6.0
@export var MULTIPLICADOR_SEGUNDO_SALTO : float = 1.2
@export var MULTIPLICADOR_CAIDA : float = 1.2
@export var MULTIPLICADOR_CORTE_SALTO : float = 2.0
@export var TIEMPO_COYOTE : float = 0.15
@export var TIEMPO_BUFFER_SALTO : float = 0.12
@export var MAX_SALTOS : int = 2

@export_group("Configuración Visual")
@export var fantasma_camera_environment: Environment # Entorno para la cámara del fantasma
@export var RADIO_DETECCION : float = 10.0 # Radio máximo de detección para plataformas

var tiempo_desde_suelo : float = 0.0
var tiempo_desde_salto : float = 0.0
var saltos_realizados : int = 0

var plataformas_activas : Dictionary = {}  # {nodo_path: bool}
var plataformas_registradas : Array = []

var _original_camera_environment: Environment
@onready var habilidad_aura = $HabilidadAura

func _ready():
	super() # Inicializa cámara y posición desde CharacterBase
	if pivote_camara and pivote_camara.has_node("Camera3D"):
		_original_camera_environment = pivote_camara.get_node("Camera3D").environment

	_inicializar_plataformas()

	if is_instance_valid(RedManager):
		RedManager.registrar_jugador(self)

	if habilidad_aura:
		habilidad_aura.radio_maximo = RADIO_DETECCION
		habilidad_aura.estado_cambiado.connect(_on_aura_estado_cambiado)

func _on_aura_estado_cambiado(activo: bool, progreso: float):
	"""Manejador de señal del componente HabilidadAura"""
	aura_estado_actualizado.emit(activo, progreso)
	_actualizar_visual_boton_aura(activo, progreso)

func actualizar_visibilidad_local():
	super()
	"""Configura qué elementos son visibles solo para el jugador que controla este personaje"""
	var es_mio = is_multiplayer_authority()
	
	if has_node("Aura"):
		$Aura.visible = false
		
	var camera = null
	if pivote_camara and pivote_camara.has_node("Camera3D"):
		camera = pivote_camara.get_node("Camera3D")
		camera.current = es_mio

	if es_mio and camera:
		if fantasma_camera_environment:
			camera.environment = fantasma_camera_environment
		else:
			# Si no hay entorno asignado, creamos un efecto de "visión espiritual" azulada
			var base_env = _original_camera_environment
			if not base_env:
				# Intentamos obtener el del WorldEnvironment de la escena
				var we = get_tree().root.find_child("WorldEnvironment", true, false)
				if we: base_env = we.environment
			
			var env = base_env.duplicate() if base_env else Environment.new()
			env.adjustment_enabled = true
			
			# Creamos una gradiente para la corrección de color (LUT 1D)
			var grad = Gradient.new()
			grad.colors = PackedColorArray([Color(0, 0, 0.1), Color(0.4, 0.6, 1.0)])
			var tex = GradientTexture1D.new()
			tex.gradient = grad
			env.adjustment_color_correction = tex
			
			camera.environment = env
	elif camera:
		camera.environment = _original_camera_environment # Restablecer al entorno global

	if es_mio and controles_tactiles:
		print("[Fantasma] Aplicando interfaz azul...")
		# Creamos un Shader en tiempo de ejecución para "forzar" el color azul 
		# ignorando si la textura original es amarilla
		var shader = Shader.new()
		shader.code = "shader_type canvas_item; uniform vec4 color_solido : source_color; void fragment() { vec4 tex = texture(TEXTURE, UV); COLOR = vec4(color_solido.rgb, tex.a * color_solido.a); }"
		var mat = ShaderMaterial.new()
		mat.shader = shader
		# Azul Cian brillante (R=0.1, G=0.5, B=1.5 para efecto glow)
		mat.set_shader_parameter("color_solido", Color(0.101, 0.442, 1.5, 0.306))
		
		controles_tactiles.modulate = Color(1, 1, 1) # Reset del modulate global
		
		# Aplicamos el shader de forma recursiva a TODO lo que esté en la UI
		_aplicar_shader_recursivo(controles_tactiles, mat)
		
		# Duplicamos el material específicamente para el botón de interactuar
		# para que sus cambios de color por cooldown no afecten al resto de la UI
		var btn_interact = controles_tactiles.get_node_or_null("Area_Camara/Zona_Botones_Accion/Boton_Interactuar")
		if btn_interact and btn_interact.material:
			btn_interact.material = btn_interact.material.duplicate()

func _aplicar_shader_recursivo(nodo: Node, material_shader: ShaderMaterial):
	"""Aplica el material a todos los elementos visuales de la interfaz"""
	if nodo is CanvasItem:
		nodo.material = material_shader
	
	for hijo in nodo.get_children():
		_aplicar_shader_recursivo(hijo, material_shader)

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
		# Forzamos el estado inicial: sólido para fantasma, intangible para vivo
		_aplicar_estado_plataforma(nodo, false)
	
	for hijo in nodo.get_children():
		_buscar_plataformas(hijo)

func _physics_process(delta):
	# Solo procesar input y movimiento si somos la autoridad local
	if not is_multiplayer_authority(): return

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

	# --- 5. ACTIVACIÓN DE AURA (Delegada al componente) ---
	if Input.is_action_just_pressed("interactuar") and habilidad_aura:
		habilidad_aura.intentar_activar()

	# --- 6. MOVIMIENTO FINAL ---
	if global_position.y < LIMITE_CAIDA_Y:
		global_position = posicion_inicial

	move_and_slide()

func _actualizar_visual_boton_aura(activo: bool, progreso: float):
	"""Actualiza el color del botón en la UI según el estado del aura"""
	if not controles_tactiles: return
	var btn = controles_tactiles.get_node_or_null("Area_Camara/Zona_Botones_Accion/Boton_Interactuar")
	if btn and btn.material:
		if not activo and progreso < 1.0 and progreso > 0: # Recargando
			btn.material.set_shader_parameter("color_solido", Color(0.2, 0.2, 0.2, 0.3))
		else: # Listo o Activo
			btn.material.set_shader_parameter("color_solido", Color(0.101, 0.442, 1.5, 0.306))

func _actualizar_proximidad_plataformas(radio_aura: float) -> void:
	"""Activa plataformas si el aura está activa y están dentro de su radio actual"""
	for plataforma in plataformas_registradas:
		var path = plataforma.get_path()
		var esta_en_rango = false
		
		if habilidad_aura and habilidad_aura.esta_activa():
			var distancia = global_position.distance_to(plataforma.global_position)
			esta_en_rango = distancia <= radio_aura
		
		# Solo enviamos el RPC si el estado cambia para no saturar la red
		var estado_actual = plataformas_activas.get(path, false)
		
		if esta_en_rango != estado_actual:
			rpc_sincronizar_estado_plataforma.rpc(path, esta_en_rango)
			print("[Fantasma] Proximidad: ", plataforma.name, " -> ", "ACTIVA" if esta_en_rango else "INACTIVA")

@rpc("any_peer", "call_local", "reliable")
func rpc_sincronizar_estado_plataforma(camino_nodo: NodePath, activo: bool) -> void:
	var plataforma = get_node_or_null(camino_nodo)
	if plataforma:
		plataformas_activas[camino_nodo] = activo
		_aplicar_estado_plataforma(plataforma, activo)
		
		print("[Red] Plataforma '%s' sincronizada: %s" % [
			plataforma.name, 
			"ACTIVA" if activo else "INACTIVA"
		])

func _aplicar_estado_plataforma(plataforma: Node3D, activa: bool) -> void:
	"""Aplica el estado de visibilidad y colisión a una plataforma"""
	if activa:
		# Activa: sólido para vivo (2) y fantasma (8) -> valor 10
		plataforma.collision_layer = 10
		plataforma.collision_mask = 10
		_cambiar_opacidad_plataforma(plataforma, 1.0)  # Visible
	else:
		# Inactiva: solo sólido para el fantasma (8)
		plataforma.collision_layer = 8
		plataforma.collision_mask = 8
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
	var detectadas = []
	for plat in plataformas_registradas:
		if global_position.distance_to(plat.global_position) <= RADIO_DETECCION:
			detectadas.append(plat)
	return detectadas

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
