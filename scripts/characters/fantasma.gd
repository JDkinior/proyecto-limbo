extends CharacterBase
class_name Fantasma

signal aura_estado_actualizado(activo: bool, progreso: float)

@export_group("Configuración Visual")
@export var fantasma_camera_environment: Environment # Entorno para la cámara del fantasma
@export var RADIO_DETECCION : float = 10.0 # Radio máximo de detección para plataformas
@export var BUFFER_CONTACTO_PLATAFORMA : float = 0.25 # Tiempo de gracia (amortiguación) en segundos para evitar parpadeos al moverse

var _original_camera_environment: Environment
@onready var habilidad_aura = $HabilidadAura

# Diccionario para rastrear el tiempo de contacto restante para cada plataforma
var _contacto_plataformas : Dictionary = {} # {plataforma: float}

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
		var camera = pivote_camara.get_node("Camera3D")
		_original_camera_environment = camera.environment
		# Ghost only renders layers 2 (Plano_Fisico) and 3 (Plano_Espiritual).
		# Exclude layer 4 (Objetivo/Moneda) so coins are not visible.
		camera.cull_mask = (1 << 0) | (1 << 1) | (1 << 2)  # layers 1 (default), 2 and 3

	# Fantasma pertenece SOLO a capa 3 (Plano Espiritual)
	collision_layer = 1 << 2   # solo capa 3
	# Máscara: detecta capa 1 (entorno), capa 3 (plataformas espirituales), capa 4 (monedas/objetivo)
	# NO incluye capa 2 (Jugador) → no colisiona con el jugador
	collision_mask = (1 << 0) | (1 << 2) | (1 << 3)

	if is_instance_valid(RedManager):
		RedManager.registrar_jugador(self)

	# Agregar al grupo global para localización rápida por otros componentes
	add_to_group("fantasmas")

	if habilidad_aura:
		habilidad_aura.radio_maximo = RADIO_DETECCION
		habilidad_aura.estado_cambiado.connect(_on_aura_estado_cambiado)

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

func _physics_process(delta):
	# Solo procesar input y movimiento si somos la autoridad local
	if not is_multiplayer_authority(): return

	procesar_camara_base(delta)
	procesar_salto_base(delta)

	# --- 5. ACTIVACIÓN DE AURA (Delegada al componente) ---
	if Input.is_action_just_pressed("interactuar") and habilidad_aura:
		habilidad_aura.intentar_activar()

	procesar_movimiento_base(delta)
	_actualizar_estado_plataformas(delta)

func _actualizar_estado_plataformas(delta: float) -> void:
	"""Activa/desactiva plataformas del grupo 'plataformas_aura' en base a si el fantasma las toca y si el aura está activa y por encima del umbral de fin."""
	if not is_multiplayer_authority(): return

	# 1. Decrementar los contadores de contacto de todas las plataformas registradas
	for plat in _contacto_plataformas.keys():
		if _contacto_plataformas[plat] > 0.0:
			_contacto_plataformas[plat] = max(_contacto_plataformas[plat] - delta, 0.0)

	# 2. Detectar contacto y refrescar el temporizador para las plataformas del grupo tocadas
	var plataformas = get_tree().get_nodes_in_group("plataformas_aura")
	for plataforma in plataformas:
		if plataforma.has_method("esta_siendo_tocada_por_fantasma") and plataforma.esta_siendo_tocada_por_fantasma():
			_contacto_plataformas[plataforma] = BUFFER_CONTACTO_PLATAFORMA

	# 3. Verificar si la habilidad está activa
	var habilidad_valida = habilidad_aura and habilidad_aura.esta_activa()

	# 4. Sincronizar el estado de todas las plataformas del grupo
	for plataforma in plataformas:
		if not plataforma.has_method("actualizar_estado"):
			continue
			
		var tiempo_restante = _contacto_plataformas.get(plataforma, 0.0)
		var debe_ser_activa = habilidad_valida and (tiempo_restante > 0.0)
		
		# Sincronizar por RPC solo si el estado cambió
		if plataforma.esta_activa != debe_ser_activa:
			plataforma.rpc_sincronizar_estado.rpc(debe_ser_activa)
			print("[Fantasma] Estado plataforma actualizado: ", plataforma.name, 
				  " -> ", "ACTIVA (Tangible)" if debe_ser_activa else "INACTIVA (Intangible)",
				  " (Tiempo contacto restante: %f)" % tiempo_restante)

func reiniciar_posicion() -> void:
	"""Reinicia el fantasma a su posición inicial"""
	global_position = posicion_inicial
	velocity = Vector3.ZERO
	_contacto_plataformas.clear()
	
	# Desactivar todas las plataformas al reiniciar
	if is_multiplayer_authority():
		var plataformas = get_tree().get_nodes_in_group("plataformas_aura")
		for plataforma in plataformas:
			if plataforma.has_method("actualizar_estado") and plataforma.esta_activa:
				plataforma.rpc_sincronizar_estado.rpc(false)
