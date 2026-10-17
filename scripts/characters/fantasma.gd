extends CharacterBase
class_name Fantasma

signal aura_estado_actualizado(activo: bool, progreso_cooldown: float)

@onready var habilidad_aura: HabilidadAura = get_node_or_null("HabilidadAura")
@onready var modelo_fantasma: Node3D = get_node_or_null("fantasma")
@onready var anim_player: AnimationPlayer = get_node_or_null("fantasma/AnimationPlayer")
@onready var estela_fantasma: CPUParticles3D = get_node_or_null("EstelaFantasma")
@onready var luz_fantasma: OmniLight3D = get_node_or_null("OmniLight3D")

var _pos_y_inicial_fantasma: float = 0.36
var _escala_base_fantasma: Vector3 = Vector3(0.5, 0.5, 0.5)
var _tiempo_flotacion: float = 0.0
var _vel_osc_actual: float = 2.2
var _tilt_espectral_pitch: float = 0.0
var _tilt_espectral_roll: float = 0.0
var _rotacion_y_anterior: float = 0.0
var _vel_horizontal_anterior: float = 0.0
var _rotacion_inicial_modelo_fantasma: Vector3 = Vector3(0.0, PI, 0.0)
var _pos_anterior_remoto: Vector3 = Vector3.ZERO

# ─────────────────────────────────────────────────────────────────────────────
# SQUASH & STRETCH Y RESPUESTA DINÁMICA (EL FANTASMA - ETÉREO Y FLUIDO)
# ─────────────────────────────────────────────────────────────────────────────
const ALTURA_BASE_FANTASMA: float = 0.686 # Distancia desde el pivote del modelo hasta la base de la túnica/manto
var _signo_escala_fantasma: Vector3 = Vector3(-1.0, 1.0, -1.0)

var _tiempo_impulso_salto_fantasma: float = 0.0
var _duracion_impulso_salto_fantasma: float = 0.16

var _tiempo_aterrizaje_fantasma: float = 0.0
var _duracion_aterrizaje_fantasma: float = 0.22
var _fuerza_impacto_aterrizaje_fantasma: float = 0.0

var _squash_stretch_fantasma: Vector3 = Vector3.ONE
var _offset_y_squash_fantasma: float = 0.0
var _pulso_luz_salto: float = 0.0
var _estaba_en_suelo_fantasma: bool = true
var _vel_y_remoto_anterior_fantasma: float = 0.0

## Control de reproducción de animaciones del fantasma (Idle y flotar/movimiento).
@export var animaciones_activas: bool = true
@export var flotacion_procedural_activa: bool = true
var _anim_actual: String = ""
var _nombre_anim_idle: String = ""
var _nombre_anim_mover: String = ""

func _ready():
	# Configurar parámetros propios del Fantasma: movimiento etéreo, fluido y suavemente deslizante
	VELOCIDAD = 4.8
	ACELERACION_SUELO = 17.0
	DESACELERACION_SUELO = 21.0
	ACELERACION_AIRE = 21.0
	DESACELERACION_AIRE = 15.0
	VELOCIDAD_ROTACION_PERSONAJE = 11.0

	# Salto único elevado con suspensión en el ápice (Apex Float) y caída suave
	FUERZA_SALTO = 9.8
	MULTIPLICADOR_SEGUNDO_SALTO = 1.0
	MULTIPLICADOR_CAIDA = 0.65
	MULTIPLICADOR_CORTE_SALTO = 1.8
	MULTIPLICADOR_GRAVEDAD_APICE = 0.40
	UMBRAL_VELOCIDAD_APICE = 1.6
	VELOCIDAD_MAX_CAIDA = 9.5
	TIEMPO_COYOTE = 0.18
	TIEMPO_BUFFER_SALTO = 0.14
	MAX_SALTOS = 1

	# Habilidad de levitación espectral (Slow-Fall / Glide al mantener presionado el botón de salto)
	PUEDE_PLANEAR = true
	MULTIPLICADOR_CAIDA_PLANEO = 0.18
	VELOCIDAD_MAX_CAIDA_PLANEO = 1.85
	MULTIPLICADOR_VELOCIDAD_PLANEO = 1.15
	MULTIPLICADOR_ACELERACION_PLANEO = 1.30
	SUAVIDAD_FRENADO_PLANEO = 18.0

	# Silueta etérea cian/azul místico para el personaje espiritual (Fantasma)
	color_silueta = Color(0.2, 0.8, 1.0, 0.85)

	super()
	_rotacion_y_anterior = rotacion_inicial.y
	add_to_group("fantasmas")
	add_to_group("jugadores")
	# Fantasma pertenece solo a la capa 3 (Plano Espiritual)

	collision_layer = 1 << 2   # solo capa 3
	# Máscara: detecta capa 1 (entorno), capa 3 (plataformas espirituales), capa 4 (monedas/triggers)
	collision_mask = (1 << 0) | (1 << 2) | (1 << 3)

	var red_mgr = _get_red_manager()
	if is_instance_valid(red_mgr):
		red_mgr.registrar_jugador(self)

	if es_activo() and controles_tactiles:
		if controles_tactiles.has_method("configurar_personaje_local"):
			controles_tactiles.configurar_personaje_local(self)
		elif controles_tactiles.has_method("configurar_estilo_personaje"):
			controles_tactiles.configurar_estilo_personaje(true)

	if is_instance_valid(habilidad_aura):
		habilidad_aura.estado_cambiado.connect(_on_aura_estado_cambiado)

	if is_instance_valid(modelo_fantasma):
		_pos_y_inicial_fantasma = modelo_fantasma.position.y
		_escala_base_fantasma = modelo_fantasma.scale.abs()
		_rotacion_inicial_modelo_fantasma = modelo_fantasma.rotation
		_signo_escala_fantasma = Vector3(
			signf(modelo_fantasma.scale.x) if modelo_fantasma.scale.x != 0.0 else -1.0,
			signf(modelo_fantasma.scale.y) if modelo_fantasma.scale.y != 0.0 else 1.0,
			signf(modelo_fantasma.scale.z) if modelo_fantasma.scale.z != 0.0 else -1.0
		)
	_rotacion_y_anterior = rotation.y
	_pos_anterior_remoto = global_position

	_configurar_animaciones()
	
	# Pre-inicializar entorno espiritual y cámara para pre-hornear radiancia del cielo al inicio
	_entorno_fantasma_cache = obtener_entorno_personaje()
	var cam = obtener_camara()
	if cam:
		cam.environment = _entorno_fantasma_cache
		cam.cull_mask = obtener_cull_mask_personaje()

	var arm = obtener_spring_arm()
	if arm:
		arm.collision_mask = (1 << 0) | (1 << 2)

func _on_aura_estado_cambiado(activo: bool, progreso_cooldown: float):
	aura_estado_actualizado.emit(activo, progreso_cooldown)

var _entorno_fantasma_cache: Environment = null

func obtener_entorno_personaje() -> Environment:
	if _entorno_fantasma_cache == null:
		_entorno_fantasma_cache = _crear_entorno_fantasma()
	return _entorno_fantasma_cache

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
	var arm = obtener_spring_arm()
	if arm:
		arm.collision_mask = (1 << 0) | (1 << 2)

const CIELO_FANTASMA_MAT = preload("res://shaders/entorno/cielo/cielo_fantasma_mat.tres")

func _crear_entorno_fantasma() -> Environment:
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	
	var sky = Sky.new()
	sky.sky_material = CIELO_FANTASMA_MAT
	sky.radiance_size = Sky.RADIANCE_SIZE_128
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
	env.glow_strength = 1.02
	env.glow_bloom = 0.16
	env.glow_hdr_threshold = 0.95
	env.glow_hdr_scale = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	
	# Niebla mística etérea sincronizada con #1669BA que se funde suavemente con el horizonte
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.0863, 0.4118, 0.7294) # Sincronizado a #1669BA
	env.fog_light_energy = 1.02
	env.fog_sun_scatter = 0.12
	env.fog_density = 0.010 # Densidad atmosférica suave sin empastar las estructuras cercanas
	env.fog_aerial_perspective = 0.45
	env.fog_sky_affect = 0.35
	env.fog_height = 0.0
	env.fog_height_density = 1.0
	
	# Ajustes de color para tonos limpios, suaves y celestialmente armoniosos
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	env.adjustment_contrast = 1.03
	env.adjustment_brightness = 1.02
	
	return env

func _physics_process(delta):
	var vel_y_previa = velocity.y

	if not es_activo():
		var red_mgr = _get_red_manager()
		var es_offline_o_solo = is_instance_valid(red_mgr) and (red_mgr.es_un_jugador or multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
		if es_offline_o_solo:
			procesar_salto_base(delta)
			aplicar_friccion_y_movimiento(Vector3.ZERO, delta)
			_comprobar_aterrizaje_fisico(vel_y_previa)
			_actualizar_animaciones(delta)
		return

	if entrada_bloqueada():
		procesar_salto_base(delta)
		aplicar_friccion_y_movimiento(Vector3.ZERO, delta)
		_comprobar_aterrizaje_fisico(vel_y_previa)
		_actualizar_animaciones(delta)
		return

	procesar_salto_base(delta)
	procesar_movimiento_base(delta)
	_comprobar_aterrizaje_fisico(vel_y_previa)
	_actualizar_animaciones(delta)

	if Input.is_action_just_pressed("interactuar") or (InputMap.has_action("habilidad_especial") and Input.is_action_just_pressed("habilidad_especial")):
		activar_habilidad_especial()

func _comprobar_aterrizaje_fisico(vel_y_previa: float) -> void:
	var en_suelo = is_on_floor()
	if en_suelo and not _estaba_en_suelo_fantasma and vel_y_previa < -1.0:
		_iniciar_animacion_aterrizaje_fantasma(vel_y_previa)
	_estaba_en_suelo_fantasma = en_suelo

func _process(delta: float):
	super(delta)

	var vel_total: float = 0.0
	var vel_horizontal: float = 0.0
	var red_mgr = _get_red_manager()
	var es_offline_o_solo = is_instance_valid(red_mgr) and (red_mgr.es_un_jugador or multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	if es_activo() or es_offline_o_solo:
		vel_total = velocity.length()
		vel_horizontal = Vector2(velocity.x, velocity.z).length()
	else:
		var desp = global_position - _pos_anterior_remoto
		vel_total = desp.length() / maxf(delta, 0.001)
		vel_horizontal = Vector2(desp.x, desp.z).length() / maxf(delta, 0.001)

		# Detección remota de salto y aterrizaje en multijugador para el fantasma
		var desp_y = desp.y
		var vel_y_remoto = desp_y / maxf(delta, 0.001)
		if vel_y_remoto > 3.0 and _tiempo_impulso_salto_fantasma <= 0.0:
			_iniciar_animacion_salto_fantasma()
		elif vel_y_remoto < -1.0:
			_vel_y_remoto_anterior_fantasma = vel_y_remoto
		elif absf(vel_y_remoto) < 0.4 and _vel_y_remoto_anterior_fantasma < -1.0:
			_iniciar_animacion_aterrizaje_fantasma(_vel_y_remoto_anterior_fantasma)
			_vel_y_remoto_anterior_fantasma = 0.0

		_pos_anterior_remoto = global_position
		_actualizar_animaciones(delta)

	_actualizar_squash_stretch_fantasma(delta)
	_procesar_flotacion_visual(delta, vel_horizontal)
	_actualizar_estela(vel_total)

func _procesar_flotacion_visual(delta: float, vel_horizontal: float):
	if not is_instance_valid(modelo_fantasma): return

	if not flotacion_procedural_activa:
		modelo_fantasma.position.y = lerpf(modelo_fantasma.position.y, _pos_y_inicial_fantasma + _offset_y_squash_fantasma, 10.0 * delta)
		modelo_fantasma.rotation.x = lerpf(modelo_fantasma.rotation.x, _rotacion_inicial_modelo_fantasma.x, 10.0 * delta)
		modelo_fantasma.rotation.z = lerpf(modelo_fantasma.rotation.z, _rotacion_inicial_modelo_fantasma.z, 10.0 * delta)
		modelo_fantasma.rotation.y = _rotacion_inicial_modelo_fantasma.y
		return

	var planeando = esta_planeando()
	var en_vortice = esta_absorbido_en_vortice()
	var factor_vel = clampf(vel_horizontal / VELOCIDAD, 0.0, 1.0)

	# 1. Transición continua de frecuencia y ondulación suave pura (sin cortes en los ápices)
	var vel_osc_objetivo = 6.0 if en_vortice else (3.6 if planeando else (2.0 + factor_vel * 0.8))
	_vel_osc_actual = lerpf(_vel_osc_actual, vel_osc_objetivo, 4.0 * delta)
	_tiempo_flotacion += delta * _vel_osc_actual

	# Onda sinusoidal pura y suave con amortiguación continua + offset de deformación vertical
	var amplitud_objetivo = 0.08 if en_vortice else (0.048 if planeando else (0.030 + factor_vel * 0.012))
	var y_objetivo = _pos_y_inicial_fantasma + (sin(_tiempo_flotacion) * amplitud_objetivo) + _offset_y_squash_fantasma
	modelo_fantasma.position.y = lerpf(modelo_fantasma.position.y, y_objetivo, 14.0 * delta)

	# 2. Inclinación en Curvas / Banking (Roll en Z al girar)
	var diff_ang = wrapf(rotation.y - _rotacion_y_anterior, -PI, PI)
	var vel_giro = diff_ang / maxf(delta, 0.001)
	_rotacion_y_anterior = rotation.y
	var objetivo_roll = 0.0
	if en_vortice:
		objetivo_roll = sin(_tiempo_flotacion * 2.0) * 0.35
	else:
		objetivo_roll = clampf(-vel_giro * 0.045, -0.15, 0.15) * (0.35 + factor_vel * 0.65)
	_tilt_espectral_roll = lerpf(_tilt_espectral_roll, objetivo_roll, 8.0 * delta)
	modelo_fantasma.rotation.z = _rotacion_inicial_modelo_fantasma.z + _tilt_espectral_roll

	# 3. Inercia de Aceleración y Frenado / Drag en X (Pitch)
	var acel_horizontal = (vel_horizontal - _vel_horizontal_anterior) / maxf(delta, 0.001)
	_vel_horizontal_anterior = vel_horizontal
	var inercia_freno = clampf(acel_horizontal * 0.008, -0.06, 0.06)
	var obj_pitch = 0.0
	if en_vortice:
		obj_pitch = 0.28
	elif planeando:
		obj_pitch = 0.12
	elif vel_horizontal > 0.2:
		obj_pitch = (factor_vel * 0.10) + inercia_freno
	else:
		obj_pitch = inercia_freno * 0.5
	_tilt_espectral_pitch = lerpf(_tilt_espectral_pitch, obj_pitch, 8.0 * delta)
	modelo_fantasma.rotation.x = _rotacion_inicial_modelo_fantasma.x + _tilt_espectral_pitch
	modelo_fantasma.rotation.y = _rotacion_inicial_modelo_fantasma.y

	# 4. Squash & Stretch Espectral / Respiración elástica
	var target_scale = Vector3(
		_escala_base_fantasma.x * _squash_stretch_fantasma.x * _signo_escala_fantasma.x,
		_escala_base_fantasma.y * _squash_stretch_fantasma.y * _signo_escala_fantasma.y,
		_escala_base_fantasma.z * _squash_stretch_fantasma.z * _signo_escala_fantasma.z
	)
	modelo_fantasma.scale = modelo_fantasma.scale.lerp(target_scale, 16.0 * delta)

	# 5. Pulso de luminosidad espectral al moverse, saltar o levitar
	if is_instance_valid(luz_fantasma):
		var energia_objetivo = 1.65 if en_vortice else (1.15 if planeando else (0.80 + factor_vel * 0.20))
		luz_fantasma.light_energy = lerpf(luz_fantasma.light_energy, energia_objetivo + _pulso_luz_salto, 6.0 * delta)
		_pulso_luz_salto = move_toward(_pulso_luz_salto, 0.0, 2.5 * delta)

func activar_habilidad_especial():
	if is_instance_valid(habilidad_aura):
		habilidad_aura.intentar_activar()

func _actualizar_estela(vel_total: float):
	if is_instance_valid(estela_fantasma):
		var planeando = esta_planeando()
		var en_vortice = esta_absorbido_en_vortice()
		var tiene_input = false
		if es_activo():
			tiene_input = not entrada_bloqueada() and (obtener_direccion_movimiento() != Vector3.ZERO)

		var esta_moviendose = false
		if en_vortice or planeando:
			esta_moviendose = true
		elif es_activo():
			esta_moviendose = (tiene_input and vel_total > 0.25) or (vel_total > 0.85)
		else:
			esta_moviendose = vel_total > 0.55

		estela_fantasma.emitting = esta_moviendose
		
		if esta_moviendose:
			var factor = clampf((vel_total - 0.25) / maxf(VELOCIDAD - 0.25, 0.1), 0.0, 1.0)
			if en_vortice:
				factor = 1.0
			elif planeando:
				factor = maxf(factor, 0.85) # Emisión espectral potenciada durante levitación
			estela_fantasma.scale_amount_min = lerpf(0.5, 0.95 if en_vortice else 0.85, factor)
			estela_fantasma.scale_amount_max = lerpf(0.75, 1.60 if en_vortice else 1.30, factor)
			estela_fantasma.initial_velocity_min = lerpf(0.2, 0.85 if en_vortice else 0.55, factor)
			estela_fantasma.initial_velocity_max = lerpf(0.4, 1.45 if en_vortice else 1.05, factor)

# ─────────────────────────────────────────────────────────────────────────────
# GESTIÓN DE ANIMACIONES (Idle y flotar_001)
# ─────────────────────────────────────────────────────────────────────────────

func _configurar_animaciones():
	if not anim_player:
		anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not anim_player:
		return

	_nombre_anim_idle = _resolver_nombre_animacion(["Idle", "Idle_001", "Idle.001"])
	_nombre_anim_mover = _resolver_nombre_animacion(["flotar_001", "Flotar_001", "Flotar.001", "flotar.001", "caminar_001", "caminar.001"])

	var duracion_ciclo = 38.0 / 30.0 # Ajusta el ciclo a la duración real de los keyframes (1.25s) para un bucle continuo sin pausa
	for nombre_anim in [_nombre_anim_idle, _nombre_anim_mover]:
		if not nombre_anim.is_empty() and anim_player.has_animation(nombre_anim):
			var anim = anim_player.get_animation(nombre_anim)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
				anim.length = duracion_ciclo

	if not animaciones_activas:
		anim_player.stop()
		return

	if not _nombre_anim_idle.is_empty() and anim_player.has_animation(_nombre_anim_idle):
		anim_player.play(_nombre_anim_idle)
		_anim_actual = _nombre_anim_idle

func _resolver_nombre_animacion(candidatos: Array[String]) -> String:
	if not anim_player:
		return ""
	for c in candidatos:
		if anim_player.has_animation(c):
			return c
	var lista = anim_player.get_animation_list()
	for c in candidatos:
		var c_norm = c.to_lower().replace(".", "_").replace(" ", "_")
		for anim_nom in lista:
			var anim_norm = anim_nom.to_lower().replace(".", "_").replace(" ", "_")
			if anim_norm == c_norm:
				return anim_nom
	return ""

func _actualizar_animaciones(delta: float):
	if not is_instance_valid(anim_player):
		return

	if not animaciones_activas:
		if anim_player.is_playing():
			anim_player.stop()
			_anim_actual = ""
		return

	var vel_horizontal: float = 0.0
	var red_mgr = _get_red_manager()
	var es_offline_o_solo = is_instance_valid(red_mgr) and (red_mgr.es_un_jugador or multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer)

	if es_activo() or es_offline_o_solo:
		vel_horizontal = Vector2(velocity.x, velocity.z).length()
	else:
		var dist = Vector2(global_position.x - _pos_anterior_remoto.x, global_position.z - _pos_anterior_remoto.z).length()
		vel_horizontal = dist / maxf(delta, 0.001)

	var planeando = esta_planeando()
	var tiene_input: bool = false
	if es_activo():
		tiene_input = not entrada_bloqueada() and (obtener_direccion_movimiento() != Vector3.ZERO)

	# Determinar si el fantasma está en movimiento:
	# - Si está planeando/levitando, mantiene animación de vuelo/flotación.
	# - Si es el jugador activo con input, basta vel_horizontal > 0.20 para moverse.
	# - Al soltar el stick/teclas, si venía a gran velocidad permite una breve y suave inercia (> 0.85)
	#   antes de transicionar, apagándose con fluidez sin cortes abruptos ni retrasos pesados.
	# - Si es remoto o inactivo, umbral reactivo de 0.55.
	var en_movimiento: bool = false
	if planeando:
		en_movimiento = true
	elif es_activo():
		en_movimiento = (tiene_input and vel_horizontal > 0.20) or (vel_horizontal > 0.85)
	else:
		en_movimiento = vel_horizontal > 0.55

	var anim_deseada = _nombre_anim_idle
	var blend_time = 0.20
	var speed = 0.75

	if en_movimiento:
		anim_deseada = _nombre_anim_mover if not _nombre_anim_mover.is_empty() else _nombre_anim_idle
		blend_time = 0.18
		if planeando:
			speed = 0.85
		else:
			speed = clampf((vel_horizontal / VELOCIDAD) * 0.90, 0.65, 1.10)
	else:
		anim_deseada = _nombre_anim_idle
		blend_time = 0.20
		speed = 0.75

	if anim_deseada.is_empty() or not anim_player.has_animation(anim_deseada):
		return

	if _anim_actual != anim_deseada:
		_anim_actual = anim_deseada
		anim_player.play(anim_deseada, blend_time)

	anim_player.speed_scale = speed

# ─────────────────────────────────────────────────────────────────────────────
# CONTROL PROCEDURAL DE SQUASH & STRETCH ESPECTRAL (FANTASMA)
# ─────────────────────────────────────────────────────────────────────────────

func _actualizar_squash_stretch_fantasma(delta: float) -> void:
	if not is_instance_valid(modelo_fantasma):
		return

	var escala_y = 1.0
	var offset_y = 0.0
	var red_mgr = _get_red_manager()
	var es_offline_o_solo = is_instance_valid(red_mgr) and (red_mgr.es_un_jugador or multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	var en_suelo = is_on_floor() if (es_activo() or es_offline_o_solo) else true
	var planeando = esta_planeando()
	var salto_mantenido = es_activo() and not entrada_bloqueada() and (Input.is_action_pressed("saltar") or Input.is_action_pressed("ui_accept"))
	var en_vortice = esta_absorbido_en_vortice()

	if en_vortice:
		_squash_stretch_fantasma = Vector3.ONE
		_offset_y_squash_fantasma = 0.0
		return

	# 1. Impulso Instantáneo de Salto Espectral (Lanzamiento explosivo sin retraso ni agazapado)
	if _tiempo_impulso_salto_fantasma > 0.0:
		_tiempo_impulso_salto_fantasma = maxf(_tiempo_impulso_salto_fantasma - delta, 0.0)
		var p = 1.0 - (_tiempo_impulso_salto_fantasma / _duracion_impulso_salto_fantasma)
		# Deformación estilizada: impulso elástico inicial con rápido retorno
		var factor_impulso = sin((1.0 - p) * (PI * 0.5))
		escala_y = lerpf(1.0, 1.18, factor_impulso)
		offset_y = 0.06 * factor_impulso

	# 2. Levitación / Planeo Espectral (Al mantener presionado salto en el aire: manto amplio y majestuoso)
	elif not en_suelo and (planeando or salto_mantenido):
		# Manto espectral amplio que flota en corrientes de aire, nunca estrecho ni comprimido
		var respiracion_planeo = sin(_tiempo_flotacion * 2.8) * 0.02
		escala_y = 0.96 + respiracion_planeo
		offset_y = 0.03

	# 3. Flotación libre / Vuelo en el aire (sin mantener levitación)
	elif not en_suelo:
		var vel_y = velocity.y if (es_activo() or es_offline_o_solo) else 0.0
		if vel_y > 1.5:
			# Ascenso suave: alargamiento muy sutil sin adelgazar la silueta
			var factor_subida = clampf(vel_y / FUERZA_SALTO, 0.0, 1.0)
			escala_y = 1.0 + (factor_subida * 0.08)
			offset_y = 0.02 * factor_subida
		elif absf(vel_y) <= 1.5:
			# Ápice: relajación flotante natural
			escala_y = 0.98 + sin(_tiempo_flotacion * 2.0) * 0.02
			offset_y = 0.01
		else:
			# Descenso suave en gravedad etérea
			var factor_caida = clampf(-vel_y / VELOCIDAD_MAX_CAIDA, 0.0, 1.0)
			escala_y = 1.0 + (factor_caida * 0.06)
			offset_y = 0.0

	# 4. Amortiguación de Aterrizaje Espectral (Pivote anclado a la base de la túnica/manto)
	elif _tiempo_aterrizaje_fantasma > 0.0:
		_tiempo_aterrizaje_fantasma = maxf(_tiempo_aterrizaje_fantasma - delta, 0.0)
		var t = 1.0 - (_tiempo_aterrizaje_fantasma / _duracion_aterrizaje_fantasma)
		var f = _fuerza_impacto_aterrizaje_fantasma

		if t < 0.40:
			# Amortiguación suave y etérea contra el piso (máximo 12% para evitar efecto aplastado/panqueque)
			var sub_t = t / 0.40
			var max_squash = 1.0 - (0.12 * f)
			escala_y = lerpf(1.0, max_squash, sin(sub_t * (PI * 0.5)))
			# Compensación de pivote hacia la base para que la túnica no flote en el aire al deformarse
			offset_y = -ALTURA_BASE_FANTASMA * (1.0 - escala_y)
		else:
			# Retorno elástico y fluido al reposo
			var sub_t = (t - 0.40) / 0.60
			var max_squash = 1.0 - (0.12 * f)
			escala_y = lerpf(max_squash, 1.0, sin(sub_t * (PI * 0.5)))
			offset_y = -ALTURA_BASE_FANTASMA * (1.0 - escala_y)
	else:
		# Reposo en el suelo / flotación neutral
		var respiracion_reposo = sin(_tiempo_flotacion * 2.0) * 0.015
		escala_y = 1.0 + respiracion_reposo
		offset_y = 0.0

	# Conservación elástica de volumen: relación proporcional suave sin exageración
	var escala_xz = 1.0 / sqrt(maxf(escala_y, 0.2))
	var escala_objetivo = Vector3(escala_xz, escala_y, escala_xz)

	_squash_stretch_fantasma = _squash_stretch_fantasma.lerp(escala_objetivo, 18.0 * delta)
	_offset_y_squash_fantasma = lerpf(_offset_y_squash_fantasma, offset_y, 16.0 * delta)

func _iniciar_animacion_salto_fantasma() -> void:
	_tiempo_impulso_salto_fantasma = _duracion_impulso_salto_fantasma
	_tiempo_aterrizaje_fantasma = 0.0
	_pulso_luz_salto = 0.75
	if is_instance_valid(estela_fantasma):
		estela_fantasma.restart()
		estela_fantasma.emitting = true

func _iniciar_animacion_aterrizaje_fantasma(vel_y: float) -> void:
	if _tiempo_aterrizaje_fantasma > (_duracion_aterrizaje_fantasma * 0.75):
		return
	var factor = clampf((abs(vel_y) - 1.0) / 7.0, 0.25, 1.0)
	_fuerza_impacto_aterrizaje_fantasma = factor
	_tiempo_aterrizaje_fantasma = _duracion_aterrizaje_fantasma
	_tiempo_impulso_salto_fantasma = 0.0
	_pulso_luz_salto = 0.3 * factor

func _al_realizar_salto(numero_salto: int):
	super(numero_salto)
	_iniciar_animacion_salto_fantasma()

func _al_aterrizar(vel_y: float) -> void:
	super(vel_y)
	_iniciar_animacion_aterrizaje_fantasma(vel_y)

func _al_resetear_estados() -> void:
	_tilt_espectral_pitch = 0.0
	_tilt_espectral_roll = 0.0
	_rotacion_y_anterior = rotation.y
	_vel_horizontal_anterior = 0.0
	_pos_anterior_remoto = global_position
	_tiempo_flotacion = 0.0
	_vel_osc_actual = 2.0
	_tiempo_impulso_salto_fantasma = 0.0
	_tiempo_aterrizaje_fantasma = 0.0
	_squash_stretch_fantasma = Vector3.ONE
	_offset_y_squash_fantasma = 0.0
	_pulso_luz_salto = 0.0
	_vel_y_remoto_anterior_fantasma = 0.0
	if is_instance_valid(modelo_fantasma):
		modelo_fantasma.rotation = _rotacion_inicial_modelo_fantasma
		modelo_fantasma.position.y = _pos_y_inicial_fantasma
		modelo_fantasma.scale = _escala_base_fantasma
		modelo_fantasma.reset_physics_interpolation()
	if is_instance_valid(estela_fantasma):
		estela_fantasma.emitting = false
		estela_fantasma.restart()
