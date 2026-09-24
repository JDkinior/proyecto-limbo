extends CharacterBase
class_name Jugador

# ─────────────────────────────────────────────────────────────────────────────
# JUGADOR VIVO — Habilidad Física: Accionar Mecanismos y Embate Rompedor
# ─────────────────────────────────────────────────────────────────────────────
# 1. Interactuar con mecanismos cercanos (Palancas, Manivelas continuas).
# 2. Si no hay mecanismos al alcance: Embate Físico hacia adelante que rompe
#    muros agrietados y da un impulso ágil de movimiento.

signal embate_realizado
signal estado_interaccion_actualizado(puede_interactuar: bool)

@export_group("Habilidad de Embate")
@export var fuerza_embate: float = 7.5
@export var tiempo_cooldown_embate: float = 0.45

var _mecanismos_cercanos: Array[Node] = []
var _cooldown_embate_actual: float = 0.0
var _esta_haciendo_embate: bool = false
var _tiempo_embate: float = 0.0
var puede_accionar: bool = false

var _estaba_en_suelo: bool = true
var _inclinacion_actual: float = 0.0
var _anim_actual: String = ""
var _pos_anterior_remoto: Vector3 = Vector3.ZERO
var _pos_y_inicial_vivo: float = 0.129
var _tiempo_paso_vivo: float = 0.0
var _balanceo_paso_actual: float = 0.0
var _rotacion_inicial_modelo_vivo: Vector3 = Vector3(0.0, PI, 0.0)

var _eval_shape: SphereShape3D = null
var _eval_query: PhysicsShapeQueryParameters3D = null
var _impacto_shape: SphereShape3D = null
var _impacto_query: PhysicsShapeQueryParameters3D = null

@onready var modelo_vivo: Node3D = get_node_or_null("vivo")
@onready var anim_player: AnimationPlayer = get_node_or_null("vivo/AnimationPlayer")
@onready var particulas_polvo: CPUParticles3D = get_node_or_null("ParticulasPolvoCaminar")
@onready var particulas_aterrizaje: CPUParticles3D = get_node_or_null("ParticulasPolvoAterrizaje")

func _ready():
	# Configurar parámetros de movimiento ágil, reactivo y terrenal
	VELOCIDAD = 5.2
	ACELERACION_SUELO = 32.0
	DESACELERACION_SUELO = 36.0
	ACELERACION_AIRE = 17.0
	DESACELERACION_AIRE = 12.0
	VELOCIDAD_ROTACION_PERSONAJE = 15.5

	# Salto enérgico, doble salto y caída rápida con peso
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
	PUEDE_PLANEAR = false

	# Cachear formas y parámetros de consulta física para evitar GC stutter
	_eval_shape = SphereShape3D.new()
	_eval_shape.radius = 0.85
	_eval_query = PhysicsShapeQueryParameters3D.new()
	_eval_query.shape = _eval_shape
	_eval_query.collision_mask = 1 | 2
	_eval_query.exclude = [get_rid()]

	_impacto_shape = SphereShape3D.new()
	_impacto_shape.radius = 0.7
	_impacto_query = PhysicsShapeQueryParameters3D.new()
	_impacto_query.shape = _impacto_shape
	_impacto_query.collision_mask = 1 | 2
	_impacto_query.exclude = [get_rid()]

	# Silueta cálida ámbar/naranja para el personaje terrenal (Vivo)
	color_silueta = Color(1.0, 0.55, 0.12, 0.85)

	super()
	add_to_group("vivos")
	add_to_group("jugadores")

	# Jugador pertenece a Capa 2 (Plano Físico)
	collision_layer = 1 << 1
	# Máscara: Capa 1 (Entorno), Capa 2 (Plataformas físicas), Capa 4 (Monedas/Objetivos)
	collision_mask = (1 << 0) | (1 << 1) | (1 << 3)

	if is_instance_valid(RedManager):
		RedManager.registrar_jugador(self)

	if es_activo() and controles_tactiles:
		if controles_tactiles.has_method("configurar_personaje_local"):
			controles_tactiles.configurar_personaje_local(self)
		elif controles_tactiles.has_method("configurar_estilo_personaje"):
			controles_tactiles.configurar_estilo_personaje(false)

	if is_instance_valid(modelo_vivo):
		_pos_y_inicial_vivo = modelo_vivo.position.y
		_rotacion_inicial_modelo_vivo = modelo_vivo.rotation
	_pos_anterior_remoto = global_position

	_configurar_animaciones()

# ─────────────────────────────────────────────────────────────────────────────
# GESTIÓN DE MECANISMOS CERCANOS
# ─────────────────────────────────────────────────────────────────────────────

func registrar_mecanismo_cercano(mecanismo: Node) -> void:
	if not mecanismo in _mecanismos_cercanos:
		_mecanismos_cercanos.append(mecanismo)

func desregistrar_mecanismo_cercano(mecanismo: Node) -> void:
	_mecanismos_cercanos.erase(mecanismo)

func _obtener_mecanismo_prioritario() -> Node:
	# Limpiar instancias destruidas
	_mecanismos_cercanos = _mecanismos_cercanos.filter(func(m): return is_instance_valid(m))
	if _mecanismos_cercanos.is_empty():
		return null
		
	var mejor_mecanismo: Node = null
	var menor_dist: float = 99999.0
	for m in _mecanismos_cercanos:
		var dist = global_position.distance_squared_to(m.global_position)
		if dist < menor_dist:
			menor_dist = dist
			mejor_mecanismo = m
	return mejor_mecanismo

# ─────────────────────────────────────────────────────────────────────────────
# CICLO DE FÍSICA Y HABILIDADES
# ─────────────────────────────────────────────────────────────────────────────

func puede_interactuar() -> bool:
	return puede_accionar

func _actualizar_disponibilidad_interaccion() -> void:
	if not es_activo():
		return
	var previo = puede_accionar
	puede_accionar = _evaluar_objetos_interactuables_en_frente()
	if puede_accionar != previo:
		estado_interaccion_actualizado.emit(puede_accionar)
		if is_instance_valid(controles_tactiles) and controles_tactiles.has_method("actualizar_boton_vivo"):
			controles_tactiles.actualizar_boton_vivo(puede_accionar)

func _evaluar_objetos_interactuables_en_frente() -> bool:
	# 1. ¿Hay un mecanismo físico en el área de interacción? (Palanca, Manivela)
	var mecanismo = _obtener_mecanismo_prioritario()
	if is_instance_valid(mecanismo):
		return true

	# 2. ¿Hay un muro agrietado, caja empujable o mecanismo en frente?
	var espacio_fisica = get_world_3d().direct_space_state
	if not espacio_fisica:
		return false

	var dir_frente = -global_transform.basis.z
	dir_frente.y = 0.0
	if dir_frente.is_zero_approx():
		dir_frente = Vector3.FORWARD
	else:
		dir_frente = dir_frente.normalized()

	# Si el jugador está moviéndose con el stick, revisar hacia donde apunta el stick
	var dir_input = obtener_direccion_movimiento()
	if dir_input != Vector3.ZERO:
		dir_frente = dir_input.normalized()

	if _eval_query:
		_eval_query.transform = Transform3D(Basis(), global_position + Vector3.UP * 0.6 + (dir_frente * 1.35))
		var resultados = espacio_fisica.intersect_shape(_eval_query, 6)
		for res in resultados:
			var col = res.get("collider")
			if is_instance_valid(col):
				if col.has_method("recibir_impacto") or col.is_in_group("muros_agrietados"):
					return true
				elif col is RigidBody3D or col.is_in_group("cajas_empujables"):
					return true
				elif col.is_in_group("mecanismos_interactivos"):
					return true

	return false

func _physics_process(delta: float):
	var vel_y_previa = velocity.y

	if _cooldown_embate_actual > 0.0:
		_cooldown_embate_actual = maxf(_cooldown_embate_actual - delta, 0.0)

	if _esta_haciendo_embate:
		_tiempo_embate -= delta
		if _tiempo_embate <= 0.0:
			_esta_haciendo_embate = false

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

	procesar_salto_base(delta)
	procesar_movimiento_base(delta)
	_actualizar_disponibilidad_interaccion()
	_procesar_input_habilidad()
	_actualizar_particulas_polvo(vel_y_previa)
	_procesar_inclinacion_visual(delta)
	_actualizar_animaciones(delta)

func _procesar_input_habilidad() -> void:
	if Input.is_action_just_pressed("interactuar") or (InputMap.has_action("habilidad_especial") and Input.is_action_just_pressed("habilidad_especial")):
		# Solo se activa si hay un objeto interactuable o rompible en frente
		if not puede_accionar:
			return

		# 1. Si hay un mecanismo físico cercano (Palanca, Manivela), operarlo y NUNCA hacer dash
		var mecanismo = _obtener_mecanismo_prioritario()
		if is_instance_valid(mecanismo):
			if mecanismo.has_method("intentar_interactuar"):
				if mecanismo.intentar_interactuar(self):
					if es_activo() and is_instance_valid(VibrationManager):
						VibrationManager.vibrar_mecanismo()
			return

		# 2. Si NO hay mecanismos pero hay un muro rompible o caja enfrente: Realizar Embate Rompedor
		if _cooldown_embate_actual <= 0.0:
			ejecutar_embate()

# ─────────────────────────────────────────────────────────────────────────────
# EMBATE FÍSICO (GOLPE / TACKLE / ROMPER MUROS)
# ─────────────────────────────────────────────────────────────────────────────

func ejecutar_embate() -> void:
	_cooldown_embate_actual = tiempo_cooldown_embate
	_esta_haciendo_embate = true
	_tiempo_embate = 0.22
	if es_activo() and is_instance_valid(VibrationManager):
		VibrationManager.vibrar_embate()

	# 1. Obtener la dirección deseada (Input del joystick/teclado relativo a la cámara)
	var dir_input = obtener_direccion_movimiento()
	var dir_impulso = Vector3.ZERO

	if dir_input != Vector3.ZERO:
		# Se impulsa hacia donde apunta el joystick en 360 grados
		dir_impulso = dir_input.normalized()
		# Orientar inmediatamente al personaje hacia la dirección del embate
		var target_angle = atan2(-dir_impulso.x, -dir_impulso.z)
		rotation.y = target_angle
	else:
		# Si está quieto (sin input), impulsarse exactamente hacia donde está mirando el modelo del personaje
		dir_impulso = -global_transform.basis.z
		dir_impulso.y = 0.0
		if dir_impulso.is_zero_approx():
			dir_impulso = Vector3.FORWARD
		else:
			dir_impulso = dir_impulso.normalized()

	# 2. Impulso físico en los ejes X y Z según la orientación real 360°
	velocity.x = dir_impulso.x * fuerza_embate
	velocity.z = dir_impulso.z * fuerza_embate
	if is_on_floor():
		velocity.y = 1.8 # Pequeño saltito de impulso atlético

	_comprobar_impacto_frontal(dir_impulso)
	_emitir_efectos_embate()
	
	if multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		rpc("rpc_reproducir_embate")

	embate_realizado.emit()
	print("[Jugador] ¡Embate físico en 360° ejecutado!")

func _comprobar_impacto_frontal(direccion: Vector3) -> void:
	var espacio_fisica = get_world_3d().direct_space_state
	if not espacio_fisica:
		return

	if _impacto_query:
		_impacto_query.transform = Transform3D(Basis(), global_position + Vector3.UP * 0.6 + (direccion * 1.3))
		var resultados = espacio_fisica.intersect_shape(_impacto_query, 8)
		for res in resultados:
			var colisionador = res.get("collider")
			if is_instance_valid(colisionador):
				if colisionador.has_method("recibir_impacto"):
					colisionador.recibir_impacto(self)
					if es_activo() and is_instance_valid(VibrationManager):
						VibrationManager.vibrar_impacto_fuerte()
				elif colisionador is RigidBody3D:
					colisionador.apply_central_impulse(direccion * 7.0)
					if es_activo() and is_instance_valid(VibrationManager):
						VibrationManager.vibrar_embate()

@rpc("any_peer", "call_remote", "unreliable")
func rpc_reproducir_embate() -> void:
	_emitir_efectos_embate()

func _emitir_efectos_embate() -> void:
	if is_instance_valid(particulas_aterrizaje):
		particulas_aterrizaje.restart()
		particulas_aterrizaje.emitting = true

# ─────────────────────────────────────────────────────────────────────────────
# ENTORNO VISUAL Y CULL MASK
# ─────────────────────────────────────────────────────────────────────────────

func obtener_entorno_personaje() -> Environment:
	return _crear_entorno_vivo()

func obtener_cull_mask_personaje() -> int:
	return 1048575 & ~(1 << 2)

func actualizar_visibilidad_local(preservar_rotacion_camara: bool = false):
	super(preservar_rotacion_camara)
	var es_mio = es_activo()
	var camera = obtener_camara()
	if es_mio and camera:
		camera.cull_mask = obtener_cull_mask_personaje()
		camera.environment = obtener_entorno_personaje()

const CIELO_VIVO_MAT = preload("res://shaders/entorno/cielo/cielo_vivo_mat.tres")

func _crear_entorno_vivo() -> Environment:
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	
	var sky = Sky.new()
	sky.sky_material = CIELO_VIVO_MAT
	env.sky = sky
	
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.96, 0.82, 0.52)
	env.ambient_light_energy = 1.15
	
	env.tonemap_mode = 2
	env.tonemap_exposure = 1.04
	env.tonemap_white = 1.12
	
	env.glow_enabled = true
	env.glow_intensity = 0.65
	env.glow_strength = 1.02
	env.glow_bloom = 0.12
	
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.96, 0.80, 0.48)
	env.fog_light_energy = 1.05
	env.fog_sun_scatter = 0.20
	env.fog_density = 0.018
	env.fog_aerial_perspective = 0.45
	env.fog_sky_affect = 0.85
	env.fog_height = 0.0
	env.fog_height_density = 1.0
	
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.05
	env.adjustment_brightness = 1.02
	
	return env

# ─────────────────────────────────────────────────────────────────────────────
# ANIMACIONES E INCLINACIÓN
# ─────────────────────────────────────────────────────────────────────────────

func _configurar_animaciones():
	if not anim_player:
		anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not anim_player:
		return
	
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
	
	if anim_player.has_animation("Idle"):
		anim_player.play("Idle")
		_anim_actual = "Idle"

func _process(delta: float):
	super(delta)
	if not es_activo():
		var es_offline_o_solo = is_instance_valid(RedManager) and (RedManager.es_un_jugador or multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
		if not es_offline_o_solo:
			_actualizar_animaciones(delta)
			_procesar_inclinacion_visual(delta)

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
			speed = clampf((vel_horizontal / VELOCIDAD) * 2.6, 0.75, 3.2)
		else:
			anim_deseada = "Idle"
			blend_time = 0.25
			speed = 1.30
	else:
		anim_deseada = "Idle"
		blend_time = 0.20
		speed = 1.10
			
	if not anim_player.has_animation(anim_deseada):
		return
		
	if _anim_actual != anim_deseada:
		_anim_actual = anim_deseada
		anim_player.play(anim_deseada, blend_time)
		
	anim_player.speed_scale = speed

func _procesar_inclinacion_visual(delta: float):
	if not is_instance_valid(modelo_vivo): return

	var vel_horizontal: float = 0.0
	var en_suelo: bool = true
	var es_offline_o_solo = is_instance_valid(RedManager) and (RedManager.es_un_jugador or multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer)

	if es_activo() or es_offline_o_solo:
		vel_horizontal = Vector2(velocity.x, velocity.z).length()
		en_suelo = is_on_floor()
	else:
		var dist = Vector2(global_position.x - _pos_anterior_remoto.x, global_position.z - _pos_anterior_remoto.z).length()
		vel_horizontal = dist / maxf(delta, 0.001)
		en_suelo = true

	var factor_vel = clampf(vel_horizontal / VELOCIDAD, 0.0, 1.0)

	# 1. Inclinación frontal (pitch) al correr o embestir
	var objetivo_inclinacion = 0.0
	if _esta_haciendo_embate:
		objetivo_inclinacion = 0.25 # Inclinación frontal agresiva al hacer tackle
	elif en_suelo and vel_horizontal > 0.5:
		objetivo_inclinacion = factor_vel * 0.07
	_inclinacion_actual = lerpf(_inclinacion_actual, objetivo_inclinacion, 14.0 * delta)
	modelo_vivo.rotation.x = _rotacion_inicial_modelo_vivo.x + _inclinacion_actual
	modelo_vivo.rotation.y = _rotacion_inicial_modelo_vivo.y

	# 2. Amortiguación y rebote sutil sincronizado con la caminata (muy suave y sin mareos)
	if en_suelo and vel_horizontal > 0.35:
		var dur = 38.0 / 30.0 # Duración del ciclo completo de 2 pasos (~1.25s)
		var t_anim = 0.0
		if is_instance_valid(anim_player) and anim_player.current_animation == "caminar":
			t_anim = anim_player.current_animation_position
		else:
			_tiempo_paso_vivo += delta * (anim_player.speed_scale if is_instance_valid(anim_player) else 2.0)
			t_anim = fmod(_tiempo_paso_vivo, dur)

		# Curva suave y continua (sin impactos abruptos en los extremos)
		var fase_paso = fmod((t_anim / dur) * 2.0, 1.0)
		var curva_suave = (1.0 - cos(fase_paso * TAU)) * 0.5
		var rebote_y = curva_suave * 0.018 * factor_vel
		
		# Interpolación fluida para evitar cualquier sacudida
		var target_y = _pos_y_inicial_vivo + rebote_y
		modelo_vivo.position.y = lerpf(modelo_vivo.position.y, target_y, 16.0 * delta)
		
		# Balanceo lateral mínimo y orgánico (reducido al mínimo para confort visual)
		var balanceo_objetivo = sin((t_anim / dur) * TAU) * 0.008 * factor_vel
		_balanceo_paso_actual = lerpf(_balanceo_paso_actual, balanceo_objetivo, 14.0 * delta)
		modelo_vivo.rotation.z = _rotacion_inicial_modelo_vivo.z + _balanceo_paso_actual
	else:
		# Regreso suave a la postura y altura de reposo
		modelo_vivo.position.y = lerpf(modelo_vivo.position.y, _pos_y_inicial_vivo, 12.0 * delta)
		_balanceo_paso_actual = lerpf(_balanceo_paso_actual, 0.0, 12.0 * delta)
		modelo_vivo.rotation.z = _rotacion_inicial_modelo_vivo.z + _balanceo_paso_actual

func _al_realizar_salto(numero_salto: int):
	super(numero_salto)
	if numero_salto == 2 and is_instance_valid(particulas_aterrizaje):
		particulas_aterrizaje.restart()
		particulas_aterrizaje.emitting = true

func _actualizar_particulas_polvo(vel_y_previa: float = 0.0):
	var en_suelo = is_on_floor()
	var vel_horizontal = Vector2(velocity.x, velocity.z).length()
	
	if en_suelo and not _estaba_en_suelo and vel_y_previa < -2.5:
		_emitir_impacto_aterrizaje()
		
	_estaba_en_suelo = en_suelo
	
	if is_instance_valid(particulas_polvo):
		var se_mueve = vel_horizontal > 0.35 and en_suelo
		particulas_polvo.emitting = se_mueve
		
		if se_mueve:
			var factor = clampf((vel_horizontal - 0.35) / maxf(VELOCIDAD - 0.35, 0.1), 0.0, 1.0)
			particulas_polvo.scale_amount_min = lerpf(0.75, 1.05, factor)
			particulas_polvo.scale_amount_max = lerpf(1.05, 1.45, factor)
			particulas_polvo.initial_velocity_min = lerpf(0.3, 0.7, factor)
			particulas_polvo.initial_velocity_max = lerpf(0.6, 1.2, factor)
			particulas_polvo.lifetime = lerpf(0.32, 0.42, factor)
			
			var dir_horiz = Vector3(velocity.x, 0.0, velocity.z).normalized()
			if dir_horiz.length_squared() > 0.01:
				var dir_expulsion = (-dir_horiz * 0.75 + Vector3.UP * 0.4).normalized()
				particulas_polvo.direction = dir_expulsion

func _emitir_impacto_aterrizaje():
	if es_activo() and is_instance_valid(VibrationManager):
		VibrationManager.vibrar_aterrizaje(1.2)
	if is_instance_valid(particulas_aterrizaje):
		particulas_aterrizaje.restart()
		particulas_aterrizaje.emitting = true

func _al_resetear_estados() -> void:
	_esta_haciendo_embate = false
	_tiempo_embate = 0.0
	_inclinacion_actual = 0.0
	_balanceo_paso_actual = 0.0
	if is_instance_valid(modelo_vivo):
		modelo_vivo.rotation = _rotacion_inicial_modelo_vivo

