extends CharacterBase
class_name Jugador

func _ready():
	# Configurar parámetros de salto dinámico y caída más rápida para el Jugador Vivo
	FUERZA_SALTO = 7.8
	MULTIPLICADOR_SEGUNDO_SALTO = 1.0
	MULTIPLICADOR_CAIDA = 2.8
	MULTIPLICADOR_CORTE_SALTO = 2.5
	TIEMPO_COYOTE = 0.15
	TIEMPO_BUFFER_SALTO = 0.15
	MAX_SALTOS = 2


	super()
	add_to_group("vivos")
	add_to_group("jugadores")
	# Jugador pertenece SOLO a capa 2 (Plano Físico)

	collision_layer = 1 << 1   # solo capa 2
	# Máscara: detecta capa 1 (entorno), capa 2 (plataformas físicas), capa 4 (monedas/objetivo)
	# NO incluye capa 3 (Fantasma) → no colisiona con el fantasma
	collision_mask = (1 << 0) | (1 << 1) | (1 << 3)
	if is_instance_valid(RedManager):
		RedManager.registrar_jugador(self)

	if is_multiplayer_authority() and controles_tactiles and controles_tactiles.has_method("configurar_estilo_personaje"):
		controles_tactiles.configurar_estilo_personaje(false)


func actualizar_visibilidad_local():
	super() # Llama a la cámara base
	var es_mio = is_multiplayer_authority()
	if es_mio and pivote_camara and pivote_camara.has_node("Camera3D"):
		var camera = pivote_camara.get_node("Camera3D")
		# Excluir capa visual 3 (Plano Espiritual) para ocultar las monedas del fantasma y elementos espirituales
		camera.cull_mask = 1048575 & ~(1 << 2)
		camera.environment = _crear_entorno_vivo()

func _crear_entorno_vivo() -> Environment:
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	
	var sky_mat = ProceduralSkyMaterial.new()
	# Cielo de atardecer/anochecer: azul crepuscular arriba, degradado a dorado cálido en el horizonte
	sky_mat.sky_top_color = Color(0.12, 0.18, 0.42)       # Azul crepúsculo sobrio en lo alto
	sky_mat.sky_horizon_color = Color(1.0, 0.78, 0.32)    # Ámbar dorado cálido en el horizonte
	sky_mat.ground_bottom_color = Color(0.14, 0.12, 0.10) # Suelo oscuro natural
	sky_mat.ground_horizon_color = Color(0.60, 0.45, 0.22) # Transición dorada suave de horizonte
	sky_mat.sky_curve = 0.08
	sky_mat.sun_angle_max = 25.0
	sky_mat.sun_curve = 0.12
	
	var sky = Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	
	# Iluminación ambiental DORADA cálida equilibrada (sin verdor ni rojizo)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.72, 0.45) # Ámbar dorado cálido natural
	env.ambient_light_energy = 1.0
	
	# Mapeo de tonos ACES (2 = ACES)
	env.tonemap_mode = 2
	env.tonemap_exposure = 1.02
	env.tonemap_white = 1.15
	
	# Glow cálido moderado
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 0.9
	env.glow_bloom = 0.08
	
	# Niebla de distancia con tinte ámbar dorado suave
	env.fog_enabled = true
	env.fog_light_color = Color(0.65, 0.50, 0.32) # Ámbar dorado distante
	env.fog_density = 0.005
	env.fog_sky_affect = 0.15
	env.fog_height = -3.0
	env.fog_height_density = 0.06
	
	# Ajustes de color naturales
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.10
	env.adjustment_contrast = 1.04
	env.adjustment_brightness = 1.0
	
	return env




func _physics_process(delta):
	if not is_multiplayer_authority(): return

	procesar_camara_base(delta)
	procesar_salto_base(delta)
	procesar_movimiento_base(delta)
	_actualizar_particulas_polvo()

func _actualizar_particulas_polvo():
	if has_node("ParticulasPolvoCaminar"):
		var esta_caminando = velocity.length() > 0.3 and is_on_floor()
		$ParticulasPolvoCaminar.emitting = esta_caminando
