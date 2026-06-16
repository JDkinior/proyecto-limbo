extends CharacterBase
class_name Fantasma

signal aura_estado_actualizado(activo: bool, progreso: float)

const CAPA_FISICA := 1 << 1 # Layer 2: Plano_Fisico
const CAPA_ESPIRITUAL := 1 << 2 # Layer 3: Plano_Espiritual
const CAPAS_PLATAFORMA_ACTIVA := CAPA_FISICA | CAPA_ESPIRITUAL

@export_group("Configuración Visual")
@export var fantasma_camera_environment: Environment # Entorno para la cámara del fantasma
@export var RADIO_DETECCION : float = 10.0 # Radio máximo de detección para plataformas

var plataformas_activas : Dictionary = {}  # {nodo_path: bool}
var plataformas_registradas : Array = []

var _original_camera_environment: Environment
@onready var habilidad_aura = $HabilidadAura

func _ready():
	FUERZA_SALTO = 8.0
	MULTIPLICADOR_SEGUNDO_SALTO = 1.0
	MULTIPLICADOR_CAIDA = 0.45
	MULTIPLICADOR_CORTE_SALTO = 1.1
	TIEMPO_COYOTE = 0.15
	TIEMPO_BUFFER_SALTO = 0.12
	MAX_SALTOS = 1
	super() # Inicializa cámara y posición desde CharacterBase
	if pivote_camara and pivote_camara.has_node("Camera3D"):
		_original_camera_environment = pivote_camara.get_node("Camera3D").environment

	_inicializar_plataformas()

	if is_instance_valid(RedManager):
		RedManager.registrar_jugador(self)

	if habilidad_aura:
		habilidad_aura.radio_maximo = RADIO_DETECCION
		habilidad_aura.estado_cambiado.connect(_on_aura_estado_cambiado)
		habilidad_aura.radio_actualizado.connect(_actualizar_proximidad_plataformas)

func _on_aura_estado_cambiado(activo: bool, progreso: float):
	"""Manejador de señal del componente HabilidadAura"""
	aura_estado_actualizado.emit(activo, progreso)

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

func _inicializar_plataformas():
	"""Encuentra todas las plataformas interactuables en el mundo"""
	print("[Fantasma] Buscando plataformas en el mundo...")
	plataformas_registradas.clear()
	plataformas_activas.clear()
	
	# Buscar plataformas marcadas por colisión espiritual, no por nombre.
	_buscar_plataformas(get_tree().root)
	
	print("[Fantasma] Plataformas encontradas: ", plataformas_registradas.size())
	for plat in plataformas_registradas:
		print("  - ", plat.name, " en posición ", plat.global_position)

func _buscar_plataformas(nodo: Node) -> void:
	"""Búsqueda recursiva de plataformas en el árbol de escenas"""
	if nodo is StaticBody3D and _es_plataforma_aura(nodo):
		plataformas_registradas.append(nodo)
		plataformas_activas[nodo.get_path()] = false  # Inicialmente desactivadas
		# Forzamos el estado inicial: sólido para fantasma, intangible para vivo
		_aplicar_estado_plataforma(nodo, false)
	
	for hijo in nodo.get_children():
		_buscar_plataformas(hijo)

func _es_plataforma_aura(plataforma: StaticBody3D) -> bool:
	return (plataforma.collision_layer & CAPA_ESPIRITUAL) != 0 or (plataforma.collision_mask & CAPA_ESPIRITUAL) != 0

func _physics_process(delta):
	# Solo procesar input y movimiento si somos la autoridad local
	if not is_multiplayer_authority(): return

	procesar_camara_base(delta)
	procesar_salto_base(delta)

	# --- 5. ACTIVACIÓN DE AURA (Delegada al componente) ---
	if Input.is_action_just_pressed("interactuar") and habilidad_aura:
		habilidad_aura.intentar_activar()

	procesar_movimiento_base(delta)

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
		# Activa: sólido para vivo y fantasma.
		plataforma.collision_layer = CAPAS_PLATAFORMA_ACTIVA
		plataforma.collision_mask = CAPAS_PLATAFORMA_ACTIVA
		_cambiar_opacidad_plataforma(plataforma, 1.0)  # Visible
	else:
		# Inactiva: solo sólido para el fantasma.
		plataforma.collision_layer = CAPA_ESPIRITUAL
		plataforma.collision_mask = CAPA_ESPIRITUAL
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
