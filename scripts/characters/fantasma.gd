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
		_escala_base_fantasma = modelo_fantasma.scale.abs()
		_rotacion_inicial_modelo_fantasma = modelo_fantasma.rotation
	_rotacion_y_anterior = rotation.y
	_pos_anterior_remoto = global_position

	_configurar_animaciones()

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

const CIELO_FANTASMA_MAT = preload("res://shaders/entorno/cielo/cielo_fantasma_mat.tres")

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
	env.glow_strength = 1.02
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
			_actualizar_animaciones(delta)
		return

	if entrada_bloqueada():
		procesar_salto_base(delta)
		aplicar_friccion_y_movimiento(Vector3.ZERO, delta)
		_actualizar_animaciones(delta)
		return

	procesar_salto_base(delta)
	procesar_movimiento_base(delta)
	_actualizar_animaciones(delta)

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
		_actualizar_animaciones(delta)

	_procesar_flotacion_visual(delta, vel_horizontal)
	_actualizar_estela(vel_total)

func _procesar_flotacion_visual(delta: float, vel_horizontal: float):
	if not is_instance_valid(modelo_fantasma): return

	if not flotacion_procedural_activa:
		modelo_fantasma.position.y = lerpf(modelo_fantasma.position.y, _pos_y_inicial_fantasma, 10.0 * delta)
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

	# Onda sinusoidal pura y suave con amortiguación continua
	var amplitud_objetivo = 0.08 if en_vortice else (0.048 if planeando else (0.030 + factor_vel * 0.012))
	var y_objetivo = _pos_y_inicial_fantasma + sin(_tiempo_flotacion) * amplitud_objetivo
	modelo_fantasma.position.y = lerpf(modelo_fantasma.position.y, y_objetivo, 12.0 * delta)

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

	# 4. Squash & Stretch Espectral / Respiración elástica suavizada
	var factor_estiramiento = sin(_tiempo_flotacion) * (0.035 if en_vortice else (0.016 if planeando else 0.010))
	var sx_sign = signf(modelo_fantasma.scale.x) if modelo_fantasma.scale.x != 0.0 else -1.0
	var sy_sign = signf(modelo_fantasma.scale.y) if modelo_fantasma.scale.y != 0.0 else 1.0
	var sz_sign = signf(modelo_fantasma.scale.z) if modelo_fantasma.scale.z != 0.0 else -1.0
	var target_scale = Vector3(
		_escala_base_fantasma.x * (1.0 - factor_estiramiento * 0.5) * sx_sign,
		_escala_base_fantasma.y * (1.0 + factor_estiramiento) * sy_sign,
		_escala_base_fantasma.z * (1.0 - factor_estiramiento * 0.5) * sz_sign
	)
	modelo_fantasma.scale = modelo_fantasma.scale.lerp(target_scale, 10.0 * delta)

	# 5. Pulso sutil de luminosidad espectral al moverse o levitar
	if is_instance_valid(luz_fantasma):
		var energia_objetivo = 1.65 if en_vortice else (1.15 if planeando else (0.80 + factor_vel * 0.20))
		luz_fantasma.light_energy = lerpf(luz_fantasma.light_energy, energia_objetivo, 6.0 * delta)

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
	var es_offline_o_solo = is_instance_valid(RedManager) and (RedManager.es_un_jugador or multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer)

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
 
func _al_resetear_estados() -> void:
	_tilt_espectral_pitch = 0.0
	_tilt_espectral_roll = 0.0
	_rotacion_y_anterior = rotacion_inicial.y
	_vel_horizontal_anterior = 0.0
	if is_instance_valid(modelo_fantasma):
		modelo_fantasma.rotation = _rotacion_inicial_modelo_fantasma
