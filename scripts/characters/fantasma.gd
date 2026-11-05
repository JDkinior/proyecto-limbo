extends CharacterBase
class_name Fantasma

signal aura_estado_actualizado(activo: bool, progreso_cooldown: float)

@onready var habilidad_aura: HabilidadAura = get_node_or_null("HabilidadAura")
@onready var habilidad_posesion: HabilidadPosesion = get_node_or_null("HabilidadPosesion")
@onready var modelo_fantasma: Node3D = get_node_or_null("fantasma")
@onready var anim_player: AnimationPlayer = get_node_or_null("fantasma/AnimationPlayer")
@onready var estela_fantasma: CPUParticles3D = get_node_or_null("EstelaFantasma")
@onready var particulas_impacto_fantasma: CPUParticles3D = get_node_or_null("ParticulasImpactoFantasma")
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
	MULTIPLICADOR_GRAVEDAD_APICE = 0.38
	UMBRAL_VELOCIDAD_APICE = 1.8
	VELOCIDAD_MAX_CAIDA = 9.5
	TIEMPO_COYOTE = 0.12
	TIEMPO_BUFFER_SALTO = 0.12
	MAX_SALTOS = 1

	# Habilidad de levitación espectral (Slow-Fall / Glide al mantener presionado el botón de salto)
	PUEDE_PLANEAR = true
	MULTIPLICADOR_CAIDA_PLANEO = 0.18
	VELOCIDAD_MAX_CAIDA_PLANEO = 1.85
	MULTIPLICADOR_VELOCIDAD_PLANEO = 1.20
	MULTIPLICADOR_ACELERACION_PLANEO = 1.35
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

	if not is_instance_valid(habilidad_posesion):
		habilidad_posesion = get_node_or_null("HabilidadPosesion") as HabilidadPosesion
		if not habilidad_posesion:
			habilidad_posesion = HabilidadPosesion.new()
			habilidad_posesion.name = "HabilidadPosesion"
			add_child(habilidad_posesion)

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
	_configurar_particulas_lowpoly_fantasma()
	
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
	# Ver todas las capas excepto la Capa 2 (aviso de silueta translúcida exclusivo para el Vivo)
	return 1048575 & ~(1 << 1)

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
	if is_instance_valid(habilidad_posesion) and habilidad_posesion.esta_poseyendo():
		# El fantasma está fusionado en el objeto poseído
		return

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
		_emitir_rafaga_particulas_impacto_fantasma(vel_y_previa < -4.5)
	_estaba_en_suelo_fantasma = en_suelo

func _process(delta: float):
	if is_instance_valid(habilidad_posesion) and habilidad_posesion.esta_poseyendo():
		_pos_anterior_remoto = global_position
		if es_activo():
			procesar_camara_base(delta)
		return

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

func obtener_distancia_camara_deseada() -> float:
	var cam_mgr = _get_camara_config_manager()
	if is_instance_valid(cam_mgr) and cam_mgr.has_method("esta_camara_estatica") and cam_mgr.esta_camara_estatica():
		return cam_mgr.obtener_distancia_camara()
	if is_instance_valid(habilidad_posesion) and habilidad_posesion.esta_poseyendo():
		var obj = habilidad_posesion.obtener_objeto_poseido()
		if is_instance_valid(obj):
			return obj.obtener_distancia_camara_adaptada()
	return super()

func obtener_altura_spring_arm_deseada() -> float:
	var cam_mgr = _get_camara_config_manager()
	if is_instance_valid(cam_mgr) and cam_mgr.has_method("esta_camara_estatica") and cam_mgr.esta_camara_estatica():
		return cam_mgr.obtener_altura_spring_arm()
	if is_instance_valid(habilidad_posesion) and habilidad_posesion.esta_poseyendo():
		var obj = habilidad_posesion.obtener_objeto_poseido()
		if is_instance_valid(obj):
			return obj.obtener_altura_camara_adaptada()
	return super()

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
	elif esta_derrapando:
		obj_pitch = -0.10
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
	if is_instance_valid(habilidad_posesion):
		if habilidad_posesion.esta_poseyendo():
			habilidad_posesion.desposeer()
			return
		elif habilidad_posesion.puede_poseer_algo():
			habilidad_posesion.intentar_poseer()
			return

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

	# 1. Impulso Instantáneo de Salto Espectral (Lanzamiento explosivo estirándose hacia arriba)
	if _tiempo_impulso_salto_fantasma > 0.0:
		_tiempo_impulso_salto_fantasma = maxf(_tiempo_impulso_salto_fantasma - delta, 0.0)
		var p = 1.0 - (_tiempo_impulso_salto_fantasma / _duracion_impulso_salto_fantasma)
		var factor_impulso = sin((1.0 - p) * (PI * 0.5))
		escala_y = lerpf(1.0, 1.28, factor_impulso)
		offset_y = 0.08 * factor_impulso

	# 2. Frenado / Derrape Espectral (Aplanamiento elástico en el plano de movimiento)
	elif esta_derrapando:
		escala_y = 0.88
		offset_y = -ALTURA_BASE_FANTASMA * (1.0 - escala_y) * 0.5

	# 3. Levitación / Planeo Espectral (Al mantener presionado salto en el aire: manto amplio y majestuoso)
	elif not en_suelo and (planeando or salto_mantenido):
		var respiracion_planeo = sin(_tiempo_flotacion * 2.8) * 0.02
		escala_y = 0.92 + respiracion_planeo
		offset_y = 0.03

	# 4. Flotación libre / Vuelo en el aire (sin mantener levitación)
	elif not en_suelo:
		var vel_y = velocity.y if (es_activo() or es_offline_o_solo) else 0.0
		if vel_y > 1.5:
			# Ascenso suave: alargamiento vertical
			var factor_subida = clampf(vel_y / FUERZA_SALTO, 0.0, 1.0)
			escala_y = 1.0 + (factor_subida * 0.14)
			offset_y = 0.03 * factor_subida
		elif absf(vel_y) <= 1.5:
			# Ápice: relajación flotante natural
			escala_y = 0.98 + sin(_tiempo_flotacion * 2.0) * 0.02
			offset_y = 0.01
		else:
			# Descenso suave en gravedad etérea: estirado hacia abajo
			var factor_caida = clampf(-vel_y / VELOCIDAD_MAX_CAIDA, 0.0, 1.0)
			escala_y = 1.0 + (factor_caida * 0.14)
			offset_y = 0.0

	# 5. Amortiguación de Aterrizaje Espectral (Pivote anclado a la base de la túnica/manto con rebote rápido de gelatina)
	elif _tiempo_aterrizaje_fantasma > 0.0:
		_tiempo_aterrizaje_fantasma = maxf(_tiempo_aterrizaje_fantasma - delta, 0.0)
		var t = 1.0 - (_tiempo_aterrizaje_fantasma / _duracion_aterrizaje_fantasma)
		var f = _fuerza_impacto_aterrizaje_fantasma

		if t < 0.25:
			# Amortiguación veloz tipo gelatina contra el piso con túnica anclada a la base
			var sub_t = t / 0.25
			var max_squash = 1.0 - (0.26 * f)
			escala_y = lerpf(1.0, max_squash, sin(sub_t * (PI * 0.5)))
			offset_y = -ALTURA_BASE_FANTASMA * (1.0 - escala_y)
		elif t < 0.62:
			# Rebote elástico overshoot inmediato
			var sub_t = (t - 0.25) / 0.37
			var max_squash = 1.0 - (0.26 * f)
			var overshoot = 1.0 + (0.14 * f)
			escala_y = lerpf(max_squash, overshoot, sin(sub_t * (PI * 0.5)))
			offset_y = -ALTURA_BASE_FANTASMA * (1.0 - escala_y)
		else:
			# Retorno elástico y fluido al reposo
			var sub_t = (t - 0.62) / 0.38
			var overshoot = 1.0 + (0.14 * f)
			escala_y = lerpf(overshoot, 1.0, sin(sub_t * (PI * 0.5)))
			offset_y = -ALTURA_BASE_FANTASMA * (1.0 - escala_y)
	else:
		# Reposo en el suelo / flotación neutral
		var respiracion_reposo = sin(_tiempo_flotacion * 2.0) * 0.015
		escala_y = 1.0 + respiracion_reposo
		offset_y = 0.0

	# Conservación elástica de volumen tipo gelatina espectral
	var delta_y = escala_y - 1.0
	var escala_xz = clampf(1.0 - (delta_y * 0.45), 0.82, 1.22)
	var escala_objetivo = Vector3(escala_xz, escala_y, escala_xz)

	_squash_stretch_fantasma = _squash_stretch_fantasma.lerp(escala_objetivo, 28.0 * delta)
	_offset_y_squash_fantasma = lerpf(_offset_y_squash_fantasma, offset_y, 28.0 * delta)

static var _malla_nube_lowpoly_fantasma_cache: ArrayMesh = null

static func _crear_malla_nube_lowpoly_fantasma(radio: float = 0.14) -> ArrayMesh:
	if _malla_nube_lowpoly_fantasma_cache != null:
		return _malla_nube_lowpoly_fantasma_cache

	# Construcción procedural de un icosaedro regular (20 caras triangulares) con sombreado flat-shaded
	var t: float = (1.0 + sqrt(5.0)) * 0.5
	var verts_raw: Array[Vector3] = [
		Vector3(-1,  t,  0), Vector3( 1,  t,  0), Vector3(-1, -t,  0), Vector3( 1, -t,  0),
		Vector3( 0, -1,  t), Vector3( 0,  1,  t), Vector3( 0, -1, -t), Vector3( 0,  1, -t),
		Vector3( t,  0, -1), Vector3( t,  0,  1), Vector3(-t,  0, -1), Vector3(-t,  0,  1)
	]
	var verts: Array[Vector3] = []
	for v in verts_raw:
		verts.append(v.normalized() * radio)

	var caras: Array[int] = [
		0, 11, 5,   0, 5, 1,    0, 1, 7,    0, 7, 10,   0, 10, 11,
		1, 5, 9,    5, 11, 4,   11, 10, 2,  10, 7, 6,   7, 1, 8,
		3, 9, 4,    3, 4, 2,    3, 2, 6,    3, 6, 8,    3, 8, 9,
		4, 9, 5,    2, 4, 11,   6, 2, 10,   8, 6, 7,    9, 8, 1
	]

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(0, caras.size(), 3):
		var v0: Vector3 = verts[caras[i]]
		var v1: Vector3 = verts[caras[i + 1]]
		var v2: Vector3 = verts[caras[i + 2]]
		var normal: Vector3 = (v2 - v0).cross(v1 - v0).normalized()
		if normal.dot((v0 + v1 + v2) / 3.0) < 0.0:
			normal = -normal
			var tmp = v1
			v1 = v2
			v2 = tmp
		st.set_normal(normal)
		st.add_vertex(v0)
		st.set_normal(normal)
		st.add_vertex(v1)
		st.set_normal(normal)
		st.add_vertex(v2)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.50, 0.88, 1.0, 1.0) # Azul celeste/cian espiritual sólido y luminoso
	mat.roughness = 0.88
	mat.metallic = 0.0
	mat.emission_enabled = true
	mat.emission = Color(0.18, 0.65, 0.95)
	mat.emission_energy_multiplier = 0.22
	# Usar TRANSPARENCY_ALPHA con alpha = 1.0 y DEPTH_DRAW_ALWAYS evita activar el X-Ray cian del personaje
	# manteniendo el poliedro 100% sólido y facetado.
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	st.set_material(mat)

	_malla_nube_lowpoly_fantasma_cache = st.commit()
	return _malla_nube_lowpoly_fantasma_cache

func _configurar_particulas_lowpoly_fantasma() -> void:
	var malla_lowpoly = _crear_malla_nube_lowpoly_fantasma(0.13)
	var curva_escala = Curve.new()
	curva_escala.add_point(Vector2(0.0, 0.40))
	curva_escala.add_point(Vector2(0.20, 1.15))
	curva_escala.add_point(Vector2(0.68, 0.85))
	curva_escala.add_point(Vector2(1.0, 0.0))

	if is_instance_valid(estela_fantasma):
		estela_fantasma.mesh = malla_lowpoly
		# A nivel de la base de la túnica/pies (-0.36) y ligeramente hacia atrás (z = 0.16)
		estela_fantasma.position = Vector3(0.0, -0.36, 0.16)
		estela_fantasma.amount = 10
		estela_fantasma.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		estela_fantasma.emission_box_extents = Vector3(0.15, 0.03, 0.08)
		estela_fantasma.direction = Vector3(0.0, 0.25, 0.85)
		estela_fantasma.spread = 28.0
		estela_fantasma.scale_amount_curve = curva_escala
		estela_fantasma.color_ramp = null
		estela_fantasma.color = Color(1.0, 1.0, 1.0, 1.0)
		estela_fantasma.gravity = Vector3(0.0, 0.35, 0.0)

	if not is_instance_valid(particulas_impacto_fantasma):
		particulas_impacto_fantasma = CPUParticles3D.new()
		particulas_impacto_fantasma.name = "ParticulasImpactoFantasma"
		add_child(particulas_impacto_fantasma)

	particulas_impacto_fantasma.emitting = false
	particulas_impacto_fantasma.one_shot = true
	particulas_impacto_fantasma.mesh = malla_lowpoly
	particulas_impacto_fantasma.position = Vector3(0.0, -0.38, 0.0)
	particulas_impacto_fantasma.amount = 16
	particulas_impacto_fantasma.lifetime = 0.42
	particulas_impacto_fantasma.explosiveness = 0.98
	particulas_impacto_fantasma.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	particulas_impacto_fantasma.emission_ring_axis = Vector3(0.0, 1.0, 0.0)
	particulas_impacto_fantasma.emission_ring_height = 0.04
	particulas_impacto_fantasma.emission_ring_radius = 0.28
	particulas_impacto_fantasma.emission_ring_inner_radius = 0.22
	# Expansión radial uniforme en círculo hacia afuera desde la base del fantasma
	particulas_impacto_fantasma.direction = Vector3(0.0, 1.0, 0.0)
	particulas_impacto_fantasma.spread = 15.0
	particulas_impacto_fantasma.flatness = 0.0
	particulas_impacto_fantasma.initial_velocity_min = 0.15
	particulas_impacto_fantasma.initial_velocity_max = 0.35
	particulas_impacto_fantasma.radial_accel_min = 11.0
	particulas_impacto_fantasma.radial_accel_max = 15.0
	particulas_impacto_fantasma.gravity = Vector3(0.0, 0.35, 0.0)
	particulas_impacto_fantasma.damping_min = 6.5
	particulas_impacto_fantasma.damping_max = 8.5
	particulas_impacto_fantasma.scale_amount_min = 0.80
	particulas_impacto_fantasma.scale_amount_max = 1.40
	particulas_impacto_fantasma.scale_amount_curve = curva_escala
	particulas_impacto_fantasma.color_ramp = null
	particulas_impacto_fantasma.color = Color(1.0, 1.0, 1.0, 1.0)

func _emitir_rafaga_particulas_impacto_fantasma(es_impacto_fuerte: bool = false) -> void:
	if not is_instance_valid(particulas_impacto_fantasma):
		return
	particulas_impacto_fantasma.position = Vector3(0.0, -0.36 if es_impacto_fuerte else -0.38, 0.0)
	particulas_impacto_fantasma.emission_ring_radius = 0.32 if es_impacto_fuerte else 0.26
	particulas_impacto_fantasma.emission_ring_inner_radius = 0.25 if es_impacto_fuerte else 0.20
	particulas_impacto_fantasma.radial_accel_min = 14.5 if es_impacto_fuerte else 10.0
	particulas_impacto_fantasma.radial_accel_max = 19.5 if es_impacto_fuerte else 14.0
	particulas_impacto_fantasma.scale_amount_min = 0.95 if es_impacto_fuerte else 0.75
	particulas_impacto_fantasma.scale_amount_max = 1.60 if es_impacto_fuerte else 1.25
	particulas_impacto_fantasma.restart()
	particulas_impacto_fantasma.emitting = true

func _iniciar_animacion_salto_fantasma() -> void:
	_tiempo_impulso_salto_fantasma = _duracion_impulso_salto_fantasma
	_tiempo_aterrizaje_fantasma = 0.0
	_pulso_luz_salto = 0.75
	_emitir_rafaga_particulas_impacto_fantasma(false)

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
	_emitir_rafaga_particulas_impacto_fantasma(vel_y < -4.5)

func _al_iniciar_derrape(velocidad: float, direccion_input: Vector3) -> void:
	super(velocidad, direccion_input)
	_emitir_rafaga_particulas_impacto_fantasma(false)
	if is_instance_valid(estela_fantasma):
		estela_fantasma.emitting = true
		estela_fantasma.scale_amount_max = 1.45

func _al_procesar_derrape(delta: float, velocidad: float) -> void:
	super(delta, velocidad)
	if is_instance_valid(estela_fantasma):
		estela_fantasma.position = Vector3(0.0, -0.36, 0.0)
		estela_fantasma.emitting = true
		estela_fantasma.scale_amount_min = 0.85
		estela_fantasma.scale_amount_max = 1.40
		estela_fantasma.direction = Vector3(0.0, 0.35, -0.65)

func _al_finalizar_derrape() -> void:
	super()
	if is_instance_valid(estela_fantasma):
		estela_fantasma.position = Vector3(0.0, -0.36, 0.16)
		estela_fantasma.scale_amount_min = 0.60
		estela_fantasma.scale_amount_max = 1.15
		estela_fantasma.direction = Vector3(0.0, 0.25, 0.85)

func _al_realizar_salto_derrape() -> void:
	super()
	_iniciar_animacion_salto_fantasma()
	_emitir_rafaga_particulas_impacto_fantasma(true)

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
	if is_instance_valid(particulas_impacto_fantasma):
		particulas_impacto_fantasma.emitting = false
		particulas_impacto_fantasma.restart()
