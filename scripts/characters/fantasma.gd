extends CharacterBase
class_name Fantasma

signal aura_estado_actualizado(activo: bool, progreso_cooldown: float)

@onready var habilidad_aura: HabilidadAura = get_node_or_null("HabilidadAura")

func _ready():
	# Configurar parámetros propios del Fantasma (salto alto, levitación y 1 solo salto)
	FUERZA_SALTO = 8.0
	MULTIPLICADOR_SEGUNDO_SALTO = 1.0
	MULTIPLICADOR_CAIDA = 0.45
	MULTIPLICADOR_CORTE_SALTO = 1.1
	TIEMPO_COYOTE = 0.15
	TIEMPO_BUFFER_SALTO = 0.12
	MAX_SALTOS = 1

	super()
	add_to_group("fantasmas")
	add_to_group("jugadores")
	# Fantasma pertenece solo a la capa 3 (Plano Espiritual)

	collision_layer = 1 << 2   # solo capa 3
	# Máscara: detecta capa 1 (entorno), capa 3 (plataformas espirituales), capa 4 (monedas/triggers)
	collision_mask = (1 << 0) | (1 << 2) | (1 << 3)

	if is_instance_valid(RedManager):
		RedManager.registrar_jugador(self)

	if is_multiplayer_authority() and controles_tactiles and controles_tactiles.has_method("configurar_estilo_personaje"):
		controles_tactiles.configurar_estilo_personaje(true)

	if is_instance_valid(habilidad_aura):
		habilidad_aura.estado_cambiado.connect(_on_aura_estado_cambiado)

func _on_aura_estado_cambiado(activo: bool, progreso_cooldown: float):
	aura_estado_actualizado.emit(activo, progreso_cooldown)

func actualizar_visibilidad_local():
	super()
	var es_mio = is_multiplayer_authority()
	if es_mio and pivote_camara and pivote_camara.has_node("Camera3D"):
		var camera = pivote_camara.get_node("Camera3D")
		# Ver todas las capas (incluyendo plano espiritual)
		camera.cull_mask = 1048575
		camera.environment = _crear_entorno_fantasma()

func _crear_entorno_fantasma() -> Environment:
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	
	var sky_mat = ProceduralSkyMaterial.new()
	# Cielo nocturno místico estilizado: Violeta noche en lo alto, degradado a azul cobalto/índigo en horizonte
	sky_mat.sky_top_color = Color(0.10, 0.12, 0.38)       # Púrpura azul noche estilizado
	sky_mat.sky_horizon_color = Color(0.20, 0.25, 0.60)   # Azul cobalto/índigo místico
	sky_mat.ground_bottom_color = Color(0.06, 0.05, 0.18) # Abismo azul púrpura
	sky_mat.ground_horizon_color = Color(0.14, 0.12, 0.35)
	sky_mat.sky_curve = 0.08
	sky_mat.sun_angle_max = 20.0
	sky_mat.sun_curve = 0.1
	
	var sky = Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	
	# Iluminación ambiental cobalto/azul (ilumina paredes y suelo para evitar áreas en negro absoluto)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.24, 0.30, 0.65) # Azul cobalto vibrante (sin sombras negras)
	env.ambient_light_energy = 1.35
	
	# Mapeo de tonos ACES (2 = ACES)
	env.tonemap_mode = 2
	env.tonemap_exposure = 1.05
	env.tonemap_white = 1.1
	
	# Glow espectral brillante para magia/cristales/aura
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.14
	
	# Niebla mística PÚRPURA de distancia (como en el arte conceptual: entre más lejos, más púrpura se vuelve)
	env.fog_enabled = true
	env.fog_light_color = Color(0.28, 0.22, 0.55) # Tono púrpura violeta místico de distancia
	env.fog_density = 0.015                       # Tinta suavemente la profundidad de púrpura
	env.fog_sky_affect = 0.3
	env.fog_height = -4.0
	env.fog_height_density = 0.06
	
	# Ajustes de color estilizados (saturación para azul cobalto y púrpura vivos)
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.25
	env.adjustment_contrast = 1.05
	env.adjustment_brightness = 1.05
	
	return env




func _physics_process(delta):
	if not is_multiplayer_authority(): return

	procesar_camara_base(delta)
	procesar_salto_base(delta)
	procesar_movimiento_base(delta)
	_actualizar_estela()

	if Input.is_action_just_pressed("interactuar") or (InputMap.has_action("habilidad_especial") and Input.is_action_just_pressed("habilidad_especial")):
		activar_habilidad_especial()


func activar_habilidad_especial():
	if is_instance_valid(habilidad_aura):
		habilidad_aura.intentar_activar()

func _actualizar_estela():
	if has_node("EstelaFantasma"):
		var esta_moviendose = velocity.length() > 0.3
		$EstelaFantasma.emitting = esta_moviendose
