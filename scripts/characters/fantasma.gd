extends CharacterBase
class_name Fantasma

signal aura_estado_actualizado(activo: bool, progreso_cooldown: float)

@onready var habilidad_aura: HabilidadAura = get_node_or_null("HabilidadAura")
@onready var modelo_fantasma: Node3D = get_node_or_null("fantasma")
@onready var estela_fantasma: CPUParticles3D = get_node_or_null("EstelaFantasma")

var _pos_y_inicial_fantasma: float = 0.089
var _tiempo_flotacion: float = 0.0
var _tilt_espectral: float = 0.0
var _pos_anterior_remoto: Vector3 = Vector3.ZERO

func _ready():
	# Configurar parámetros propios del Fantasma: movimiento etéreo, fluido y deslizante
	VELOCIDAD = 4.8
	ACELERACION_SUELO = 17.0
	DESACELERACION_SUELO = 13.0
	ACELERACION_AIRE = 21.0
	DESACELERACION_AIRE = 10.0
	VELOCIDAD_ROTACION_PERSONAJE = 11.0

	# Salto único elevado con suspensión en el ápice (Apex Float) y caída suave
	FUERZA_SALTO = 8.2
	MULTIPLICADOR_SEGUNDO_SALTO = 1.0
	MULTIPLICADOR_CAIDA = 0.65
	MULTIPLICADOR_CORTE_SALTO = 1.8
	MULTIPLICADOR_GRAVEDAD_APICE = 0.40
	UMBRAL_VELOCIDAD_APICE = 1.6
	VELOCIDAD_MAX_CAIDA = 9.5
	TIEMPO_COYOTE = 0.18
	TIEMPO_BUFFER_SALTO = 0.14
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

	if es_activo() and controles_tactiles:
		if controles_tactiles.has_method("configurar_personaje_local"):
			controles_tactiles.configurar_personaje_local(self)
		elif controles_tactiles.has_method("configurar_estilo_personaje"):
			controles_tactiles.configurar_estilo_personaje(true)

	if is_instance_valid(habilidad_aura):
		habilidad_aura.estado_cambiado.connect(_on_aura_estado_cambiado)

	if is_instance_valid(modelo_fantasma):
		_pos_y_inicial_fantasma = modelo_fantasma.position.y
	_pos_anterior_remoto = global_position

func _on_aura_estado_cambiado(activo: bool, progreso_cooldown: float):
	aura_estado_actualizado.emit(activo, progreso_cooldown)

func obtener_entorno_personaje() -> Environment:
	return _crear_entorno_fantasma()

func obtener_cull_mask_personaje() -> int:
	return 1048575

func actualizar_visibilidad_local(preservar_rotacion_camara: bool = false):
	super(preservar_rotacion_camara)
	var es_mio = es_activo()
	var camera = obtener_camara()
	if es_mio and camera:
		# Ver todas las capas (incluyendo plano espiritual)
		camera.cull_mask = obtener_cull_mask_personaje()
		camera.environment = obtener_entorno_personaje()

const CIELO_FANTASMA_MAT = preload("res://shaders/cielo_fantasma_mat.tres")

func _crear_entorno_fantasma() -> Environment:
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	
	var sky = Sky.new()
	sky.sky_material = CIELO_FANTASMA_MAT
	env.sky = sky
	
	# Iluminación ambiental MÍSTICA Y ETÉREA (turquesa/cian suave sobre piedra)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.24, 0.42, 0.58) # Azul cian/pizarra místico luminoso
	env.ambient_light_energy = 1.18
	
	# Mapeo de tonos Filmic / ACES optimizado para colores fríos y highlights definidos
	env.tonemap_mode = 3 # Filmic
	env.tonemap_exposure = 1.06
	env.tonemap_white = 1.20
	
	# Glow espectral envolvente para cristales, runas y elementos brillantes
	env.glow_enabled = true
	env.glow_intensity = 0.80
	env.glow_strength = 0.88
	env.glow_bloom = 0.16
	env.glow_hdr_threshold = 0.95
	env.glow_hdr_scale = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	
	# Niebla mística etérea turquesa/cian que se funde suavemente con el horizonte
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.16, 0.40, 0.58) # Niebla mística cian/turquesa
	env.fog_light_energy = 1.08
	env.fog_sun_scatter = 0.15
	env.fog_density = 0.012 # Densidad atmosférica suave sin empastar las estructuras cercanas
	env.fog_aerial_perspective = 0.45
	env.fog_sky_affect = 0.70
	env.fog_height = 0.0
	env.fog_height_density = 1.0
	
	# Ajustes de color para tonos limpios, suaves y celestialmente armoniosos
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	env.adjustment_contrast = 1.03
	env.adjustment_brightness = 1.02
	
	return env

func _physics_process(delta):
	if not es_activo():
		var es_offline_o_solo = is_instance_valid(RedManager) and (RedManager.es_un_jugador or multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
		if es_offline_o_solo:
			procesar_salto_base(delta)
			aplicar_friccion_y_movimiento(Vector3.ZERO, delta)
		return

	if entrada_bloqueada():
		procesar_salto_base(delta)
		aplicar_friccion_y_movimiento(Vector3.ZERO, delta)
		return

	procesar_camara_base(delta)
	procesar_salto_base(delta)
	procesar_movimiento_base(delta)

	if Input.is_action_just_pressed("interactuar") or (InputMap.has_action("habilidad_especial") and Input.is_action_just_pressed("habilidad_especial")):
		activar_habilidad_especial()

func _process(delta: float):
	super(delta)

	var vel_total: float = 0.0
	var vel_horizontal: float = 0.0
	var es_offline_o_solo = is_instance_valid(RedManager) and (RedManager.es_un_jugador or multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	if es_activo() or es_offline_o_solo:
		vel_total = velocity.length()
		vel_horizontal = Vector2(velocity.x, velocity.z).length()
	else:
		var desp = global_position - _pos_anterior_remoto
		vel_total = desp.length() / maxf(delta, 0.001)
		vel_horizontal = Vector2(desp.x, desp.z).length() / maxf(delta, 0.001)
		_pos_anterior_remoto = global_position

	_procesar_flotacion_visual(delta, vel_horizontal)
	_actualizar_estela(vel_total)

func _procesar_flotacion_visual(delta: float, vel_horizontal: float):
	if not is_instance_valid(modelo_fantasma): return
	
	# Oscilación suave continua de levitación espectral (sine wave)
	_tiempo_flotacion += delta * 2.8
	modelo_fantasma.position.y = _pos_y_inicial_fantasma + sin(_tiempo_flotacion) * 0.035
	
	# Inclinación grácil en movimiento
	var obj_tilt = 0.0
	if vel_horizontal > 0.3:
		obj_tilt = clampf(vel_horizontal / VELOCIDAD, 0.0, 1.0) * 0.06
	_tilt_espectral = lerpf(_tilt_espectral, obj_tilt, 7.0 * delta)
	modelo_fantasma.rotation.x = _tilt_espectral

func activar_habilidad_especial():
	if is_instance_valid(habilidad_aura):
		habilidad_aura.intentar_activar()

func _actualizar_estela(vel_total: float):
	if is_instance_valid(estela_fantasma):
		var esta_moviendose = vel_total > 0.35
		estela_fantasma.emitting = esta_moviendose
		
		if esta_moviendose:
			var factor = clampf((vel_total - 0.35) / maxf(VELOCIDAD - 0.35, 0.1), 0.0, 1.0)
			estela_fantasma.scale_amount_min = lerpf(0.5, 0.75, factor)
			estela_fantasma.scale_amount_max = lerpf(0.75, 1.15, factor)
			estela_fantasma.initial_velocity_min = lerpf(0.2, 0.45, factor)
			estela_fantasma.initial_velocity_max = lerpf(0.4, 0.85, factor)
