extends CharacterBase
class_name Jugador

func _ready():
	# Configurar parámetros de movimiento ágil, reactivo y terrenal
	VELOCIDAD = 5.2
	ACELERACION_SUELO = 32.0
	DESACELERACION_SUELO = 36.0
	ACELERACION_AIRE = 17.0
	DESACELERACION_AIRE = 12.0
	VELOCIDAD_ROTACION_PERSONAJE = 15.5

	# Configurar física de salto enérgico, doble salto y caída rápida con peso
	FUERZA_SALTO = 7.8
	MULTIPLICADOR_SEGUNDO_SALTO = 0.90
	MULTIPLICADOR_CAIDA = 2.6
	MULTIPLICADOR_CORTE_SALTO = 2.5
	MULTIPLICADOR_GRAVEDAD_APICE = 1.0
	UMBRAL_VELOCIDAD_APICE = 1.6
	VELOCIDAD_MAX_CAIDA = 26.0
	TIEMPO_COYOTE = 0.16
	TIEMPO_BUFFER_SALTO = 0.14
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

	if es_activo() and controles_tactiles:
		if controles_tactiles.has_method("configurar_personaje_local"):
			controles_tactiles.configurar_personaje_local(self)
		elif controles_tactiles.has_method("configurar_estilo_personaje"):
			controles_tactiles.configurar_estilo_personaje(false)

	_configurar_animaciones()


func obtener_entorno_personaje() -> Environment:
	return _crear_entorno_vivo()

func obtener_cull_mask_personaje() -> int:
	return 1048575 & ~(1 << 2)

func actualizar_visibilidad_local(preservar_rotacion_camara: bool = false):
	super(preservar_rotacion_camara) # Llama a la cámara base
	var es_mio = es_activo()
	var camera = obtener_camara()
	if es_mio and camera:
		# Excluir capa visual 3 (Plano Espiritual) para ocultar las monedas del fantasma y elementos espirituales
		camera.cull_mask = obtener_cull_mask_personaje()
		camera.environment = obtener_entorno_personaje()

const CIELO_VIVO_MAT = preload("res://shaders/cielo_vivo_mat.tres")

func _crear_entorno_vivo() -> Environment:
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	
	var sky = Sky.new()
	sky.sky_material = CIELO_VIVO_MAT
	env.sky = sky
	
	# Iluminación ambiental DORADA cálida del arte conceptual
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.96, 0.82, 0.52) # Ámbar dorado cálido del arte conceptual
	env.ambient_light_energy = 1.15
	
	# Mapeo de tonos ACES (2 = ACES)
	env.tonemap_mode = 2
	env.tonemap_exposure = 1.04
	env.tonemap_white = 1.12
	
	# Glow cálido atmosférico
	env.glow_enabled = true
	env.glow_intensity = 0.65
	env.glow_strength = 0.85
	env.glow_bloom = 0.12
	
	# Niebla dorada atmosférica para difuminar el fondo
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.96, 0.80, 0.48) # Niebla dorada envolvente
	env.fog_light_energy = 1.05
	env.fog_sun_scatter = 0.20
	env.fog_density = 0.018 # Densidad incrementada para ocultar aristas y cortes del fondo
	env.fog_aerial_perspective = 0.45 # Funde gradualmente las estructuras lejanas con la niebla
	env.fog_sky_affect = 0.85 # Integración suave y continua con el horizonte
	env.fog_height = 0.0
	env.fog_height_density = 1.0
	
	# Ajustes de color para calidez pictórica
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.05
	env.adjustment_brightness = 1.02
	
	return env




var _estaba_en_suelo: bool = true
var _inclinacion_actual: float = 0.0
var _anim_actual: String = ""
var _pos_anterior_remoto: Vector3 = Vector3.ZERO

@onready var modelo_vivo: Node3D = get_node_or_null("vivo")
@onready var anim_player: AnimationPlayer = get_node_or_null("vivo/AnimationPlayer")
@onready var particulas_polvo: CPUParticles3D = get_node_or_null("ParticulasPolvoCaminar")
@onready var particulas_aterrizaje: CPUParticles3D = get_node_or_null("ParticulasPolvoAterrizaje")

func _configurar_animaciones():
	if not anim_player:
		anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not anim_player:
		return
	
	# Configurar bucle y duración exacta del ciclo de animación (38 frames a 30 FPS = ~1.266s)
	# para eliminar pausas vacías y lograr un bucle continuo y fluido.
	var duracion_ciclo = 38.0 / 30.0
	
	for nombre_anim in ["Idle", "Idle_002"]:
		if anim_player.has_animation(nombre_anim):
			var anim = anim_player.get_animation(nombre_anim)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
				anim.length = duracion_ciclo
				
	if anim_player.has_animation("caminar"):
		var anim_walk = anim_player.get_animation("caminar")
		if anim_walk:
			anim_walk.loop_mode = Animation.LOOP_LINEAR
			anim_walk.length = duracion_ciclo
	
	# Iniciar con Idle por defecto
	if anim_player.has_animation("Idle"):
		anim_player.play("Idle")
		_anim_actual = "Idle"

func _physics_process(delta):
	var vel_y_previa = velocity.y

	if not es_activo():
		var es_offline_o_solo = is_instance_valid(RedManager) and (RedManager.es_un_jugador or multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
		if es_offline_o_solo:
			procesar_salto_base(delta)
			aplicar_friccion_y_movimiento(Vector3.ZERO, delta)
			_actualizar_particulas_polvo(vel_y_previa)
			_procesar_inclinacion_visual(delta)
			_actualizar_animaciones(delta)
		return

	if entrada_bloqueada():
		procesar_salto_base(delta)
		aplicar_friccion_y_movimiento(Vector3.ZERO, delta)
		_actualizar_particulas_polvo(vel_y_previa)
		_procesar_inclinacion_visual(delta)
		_actualizar_animaciones(delta)
		return

	procesar_camara_base(delta)
	procesar_salto_base(delta)
	procesar_movimiento_base(delta)
	_actualizar_particulas_polvo(vel_y_previa)
	_procesar_inclinacion_visual(delta)
	_actualizar_animaciones(delta)

func _process(delta: float):
	super(delta)
	if not es_activo():
		var es_offline_o_solo = is_instance_valid(RedManager) and (RedManager.es_un_jugador or multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
		if not es_offline_o_solo:
			_actualizar_animaciones(delta)

func _actualizar_animaciones(delta: float):
	if not is_instance_valid(anim_player):
		return
		
	var vel_horizontal: float = 0.0
	var en_suelo: bool = true
	var es_offline_o_solo = is_instance_valid(RedManager) and (RedManager.es_un_jugador or multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	
	if es_activo() or es_offline_o_solo:
		vel_horizontal = Vector2(velocity.x, velocity.z).length()
		en_suelo = is_on_floor()
	else:
		# Para multijugador remoto: calcular velocidad a partir de la posición interpolada
		var dist = Vector2(global_position.x - _pos_anterior_remoto.x, global_position.z - _pos_anterior_remoto.z).length()
		vel_horizontal = dist / maxf(delta, 0.001)
		en_suelo = true
		_pos_anterior_remoto = global_position
		
	var anim_deseada = "Idle"
	var blend_time = 0.22
	var speed = 1.0
	
	if en_suelo:
		if vel_horizontal > 0.35:
			anim_deseada = "caminar"
			blend_time = 0.16
			# Acelerar la animación proporcionalmente a la velocidad del jugador para sincronizar los pasos
			speed = clampf((vel_horizontal / VELOCIDAD) * 2.6, 0.75, 3.2)
		else:
			anim_deseada = "Idle"
			blend_time = 0.25
			speed = 1.0
	else:
		# En el aire (saltando o cayendo)
		anim_deseada = "Idle"
		blend_time = 0.20
		speed = 0.85
			
	if not anim_player.has_animation(anim_deseada):
		return
		
	if _anim_actual != anim_deseada:
		_anim_actual = anim_deseada
		anim_player.play(anim_deseada, blend_time)
		
	anim_player.speed_scale = speed

func _procesar_inclinacion_visual(delta: float):
	if not is_instance_valid(modelo_vivo): return
	var vel_horizontal = Vector2(velocity.x, velocity.z).length()
	var objetivo_inclinacion = 0.0
	if is_on_floor() and vel_horizontal > 0.5:
		objetivo_inclinacion = clampf(vel_horizontal / VELOCIDAD, 0.0, 1.0) * 0.07
	_inclinacion_actual = lerpf(_inclinacion_actual, objetivo_inclinacion, 14.0 * delta)
	modelo_vivo.rotation.x = _inclinacion_actual

func _al_realizar_salto(numero_salto: int):
	if numero_salto == 2 and is_instance_valid(particulas_aterrizaje):
		# Feedback enérgico para el segundo salto
		particulas_aterrizaje.restart()
		particulas_aterrizaje.emitting = true

func _actualizar_particulas_polvo(vel_y_previa: float = 0.0):
	var en_suelo = is_on_floor()
	var vel_horizontal = Vector2(velocity.x, velocity.z).length()
	
	# Detectar impacto de aterrizaje tras saltar o caer con suficiente velocidad
	if en_suelo and not _estaba_en_suelo and vel_y_previa < -2.5:
		_emitir_impacto_aterrizaje()
		
	_estaba_en_suelo = en_suelo
	
	if is_instance_valid(particulas_polvo):
		var se_mueve = vel_horizontal > 0.35 and en_suelo
		particulas_polvo.emitting = se_mueve
		
		if se_mueve:
			# Factor de 0.0 (caminar suave) a 1.0 (correr a tope)
			var factor = clampf((vel_horizontal - 0.35) / maxf(VELOCIDAD - 0.35, 0.1), 0.0, 1.0)
			
			# Ajuste dinámico: bocanadas grandes y estilizadas, pero espaciadas y de baja densidad
			particulas_polvo.scale_amount_min = lerpf(0.75, 1.05, factor)
			particulas_polvo.scale_amount_max = lerpf(1.05, 1.45, factor)
			particulas_polvo.initial_velocity_min = lerpf(0.3, 0.7, factor)
			particulas_polvo.initial_velocity_max = lerpf(0.6, 1.2, factor)
			particulas_polvo.lifetime = lerpf(0.32, 0.42, factor)
			
			# Expulsión hacia atrás y ligeramente hacia arriba
			var dir_horiz = Vector3(velocity.x, 0.0, velocity.z).normalized()
			if dir_horiz.length_squared() > 0.01:
				var dir_expulsion = (-dir_horiz * 0.75 + Vector3.UP * 0.4).normalized()
				particulas_polvo.direction = dir_expulsion

func _emitir_impacto_aterrizaje():
	if is_instance_valid(particulas_aterrizaje):
		particulas_aterrizaje.restart()
		particulas_aterrizaje.emitting = true
