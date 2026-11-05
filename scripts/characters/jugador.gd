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

# ─────────────────────────────────────────────────────────────────────────────
# GROUND POUND & DIVE (ACROBACIAS TIPO ODYSSEY)
# ─────────────────────────────────────────────────────────────────────────────
var _en_ground_pound: bool = false
var _tiempo_pausa_ground_pound: float = 0.0
const DURACION_PAUSA_GROUND_POUND: float = 0.12
const VELOCIDAD_CAIDA_GROUND_POUND: float = -22.0
var _tiempo_ventana_salto_ground_pound: float = 0.0
const VENTANA_SALTO_GROUND_POUND: float = 0.35
var _tiempo_squash_ground_pound: float = 0.0
const DURACION_SQUASH_GROUND_POUND: float = 0.36

var _en_dive: bool = false
var _tiempo_dive: float = 0.0
const DURACION_DIVE: float = 0.32
const FUERZA_HORIZONTAL_DIVE: float = 8.5
const IMPULSO_VERTICAL_DIVE: float = 1.8
var _tiempo_recuperacion_dive: float = 0.0
const DURACION_RECUPERACION_DIVE: float = 0.18
var _dive_realizado_en_aire: bool = false
var _fuerza_despegue_especial: float = 0.0

var _estaba_en_suelo: bool = true
var _inclinacion_actual: float = 0.0
var _anim_actual: String = ""
var _pos_anterior_remoto: Vector3 = Vector3.ZERO
var _pos_y_inicial_vivo: float = 0.129
var _tiempo_paso_vivo: float = 0.0
var _balanceo_paso_actual: float = 0.0
var _rotacion_inicial_modelo_vivo: Vector3 = Vector3(0.0, PI, 0.0)

# ─────────────────────────────────────────────────────────────────────────────
# SQUASH & STRETCH Y ANTICIPACIÓN (EL VIVO - FÍSICO, ENÉRGICO Y ELÁSTICO)
# ─────────────────────────────────────────────────────────────────────────────
const ALTURA_PIVOTE_A_SUELO_VIVO: float = 0.67
var _escala_base_vivo: Vector3 = Vector3(0.5, 0.5, 0.5)
var _signo_escala_vivo: Vector3 = Vector3(-1.0, 1.0, -1.0)

# Estado de cañón espiritual
var en_canon: bool = false
var _factor_escala_canon: float = 1.0
var offset_vertical_canon: float = 0.11
var _offset_vertical_canon: float = 0.11
var _silueta_original_canon: bool = true

var _tiempo_anticipacion_salto_vivo: float = 0.0
var _duracion_anticipacion_vivo: float = 0.04
var _tiempo_despegue_salto_vivo: float = 0.0
var _duracion_despegue_vivo: float = 0.17
var _es_segundo_salto_vivo: bool = false

var _tiempo_aterrizaje_vivo: float = 0.0
var _duracion_aterrizaje_vivo: float = 0.22
var _fuerza_impacto_aterrizaje_vivo: float = 0.0

var _squash_stretch_vivo: Vector3 = Vector3.ONE
var _offset_y_squash_vivo: float = 0.0
var _vel_y_remoto_anterior_vivo: float = 0.0

var _eval_shape: SphereShape3D = null
var _eval_query: PhysicsShapeQueryParameters3D = null
var _impacto_shape: SphereShape3D = null
var _impacto_query: PhysicsShapeQueryParameters3D = null

@onready var modelo_vivo: Node3D = get_node_or_null("vivo")
@onready var anim_player: AnimationPlayer = get_node_or_null("vivo/AnimationPlayer")
@onready var particulas_polvo: CPUParticles3D = get_node_or_null("ParticulasPolvoCaminar")
@onready var particulas_aterrizaje: CPUParticles3D = get_node_or_null("ParticulasPolvoAterrizaje")
@onready var luz_vivo: OmniLight3D = get_node_or_null("OmniLight3D")

func _ready():
	# Configurar parámetros de movimiento ágil, reactivo y terrenal
	VELOCIDAD = 5.2
	ACELERACION_SUELO = 32.0
	DESACELERACION_SUELO = 36.0
	ACELERACION_AIRE = 17.0
	DESACELERACION_AIRE = 12.0
	VELOCIDAD_ROTACION_PERSONAJE = 15.5

	# Salto enérgico, doble salto y caída rápida con peso (altura fija y física ágil sin efecto lunar)
	FUERZA_SALTO = 9.8
	MULTIPLICADOR_SEGUNDO_SALTO = 0.95
	MULTIPLICADOR_GRAVEDAD_SUBIDA = 2.4
	MULTIPLICADOR_CAIDA = 3.4
	MULTIPLICADOR_CORTE_SALTO = 1.0 # Salto de altura fija: siempre salta lo mismo sin depender de mantener presionado el botón
	MULTIPLICADOR_GRAVEDAD_APICE = 1.0
	UMBRAL_VELOCIDAD_APICE = 1.6
	VELOCIDAD_MAX_CAIDA = 28.0
	TIEMPO_COYOTE = 0.12
	TIEMPO_BUFFER_SALTO = 0.12
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

	var red_mgr = _get_red_manager()
	if is_instance_valid(red_mgr):
		red_mgr.registrar_jugador(self)

	if es_activo() and controles_tactiles:
		if controles_tactiles.has_method("configurar_personaje_local"):
			controles_tactiles.configurar_personaje_local(self)
		elif controles_tactiles.has_method("configurar_estilo_personaje"):
			controles_tactiles.configurar_estilo_personaje(false)

	if is_instance_valid(modelo_vivo):
		_pos_y_inicial_vivo = modelo_vivo.position.y
		_rotacion_inicial_modelo_vivo = modelo_vivo.rotation
		_escala_base_vivo = modelo_vivo.scale.abs()
		_signo_escala_vivo = Vector3(
			signf(modelo_vivo.scale.x) if modelo_vivo.scale.x != 0.0 else -1.0,
			signf(modelo_vivo.scale.y) if modelo_vivo.scale.y != 0.0 else 1.0,
			signf(modelo_vivo.scale.z) if modelo_vivo.scale.z != 0.0 else -1.0
		)
	_pos_anterior_remoto = global_position

	_configurar_animaciones()
	_configurar_particulas_lowpoly()
	
	# Pre-inicializar entorno físico y cámara para pre-hornear radiancia del cielo al inicio
	_entorno_vivo_cache = obtener_entorno_personaje()
	var cam = obtener_camara()
	if cam:
		cam.environment = _entorno_vivo_cache
		cam.cull_mask = obtener_cull_mask_personaje()

	var arm = obtener_spring_arm()
	if arm:
		arm.collision_mask = (1 << 0) | (1 << 1)

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
	return puede_accionar or not is_on_floor()

func _actualizar_disponibilidad_interaccion() -> void:
	if not es_activo():
		return
	var previo = puede_accionar
	puede_accionar = _evaluar_objetos_interactuables_en_frente() or not is_on_floor()
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

	if _tiempo_recuperacion_dive > 0.0:
		_tiempo_recuperacion_dive = maxf(_tiempo_recuperacion_dive - delta, 0.0)

	# Resetear dive al tocar suelo
	if is_on_floor():
		_dive_realizado_en_aire = false

	# Ventana de rebote / salto acrobático potenciado tras Ground Pound
	if _tiempo_ventana_salto_ground_pound > 0.0:
		_tiempo_ventana_salto_ground_pound = maxf(_tiempo_ventana_salto_ground_pound - delta, 0.0)
		# Indicador visual dinámico: pulso de luz dorada enérgica que indica oportunidad de súper rebote
		if is_instance_valid(luz_vivo):
			var factor_pulso = sin(_tiempo_ventana_salto_ground_pound * 26.0) * 0.5 + 0.5
			luz_vivo.light_energy = lerpf(1.6, 3.2, factor_pulso)
			luz_vivo.omni_range = lerpf(4.5, 6.0, factor_pulso)

		if es_activo() and not entrada_bloqueada() and (Input.is_action_just_pressed("saltar") or Input.is_action_just_pressed("ui_accept")):
			velocity.y = FUERZA_SALTO * 1.35 # Súper rebote acrobático potenciado
			saltos_realizados = 1
			tiempo_desde_salto = TIEMPO_BUFFER_SALTO + 0.1
			_tiempo_ventana_salto_ground_pound = 0.0
			_tiempo_squash_ground_pound = 0.0
			_al_realizar_salto(1)
			_tiempo_despegue_salto_vivo = 0.22 # Despegue elástico estirado
			_fuerza_despegue_especial = 1.38 # Estiramiento vertical de gelatina suprema
			if is_instance_valid(luz_vivo):
				luz_vivo.light_energy = 3.6
			if is_instance_valid(particulas_aterrizaje):
				particulas_aterrizaje.restart()
				particulas_aterrizaje.emitting = true
			var vib_mgr = _get_vibration_manager()
			if es_activo() and is_instance_valid(vib_mgr):
				vib_mgr.vibrar_impacto_fuerte()
	else:
		if is_instance_valid(luz_vivo) and luz_vivo.light_energy > 1.65:
			luz_vivo.light_energy = lerpf(luz_vivo.light_energy, 1.6, 8.0 * delta)
			luz_vivo.omni_range = lerpf(luz_vivo.omni_range, 4.5, 8.0 * delta)

	if en_canon:
		velocity = Vector3.ZERO
		_actualizar_squash_stretch_vivo(delta)
		_procesar_inclinacion_visual(delta)
		return

	if not es_activo():
		var red_mgr = _get_red_manager()
		var es_offline_o_solo = is_instance_valid(red_mgr) and (red_mgr.es_un_jugador or multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
		if es_offline_o_solo:
			procesar_salto_base(delta)
			aplicar_friccion_y_movimiento(Vector3.ZERO, delta)
			_actualizar_particulas_polvo(vel_y_previa)
			_actualizar_squash_stretch_vivo(delta)
			_procesar_inclinacion_visual(delta)
			_actualizar_animaciones(delta)
		return

	if entrada_bloqueada():
		procesar_salto_base(delta)
		aplicar_friccion_y_movimiento(Vector3.ZERO, delta)
		_actualizar_particulas_polvo(vel_y_previa)
		_actualizar_squash_stretch_vivo(delta)
		_procesar_inclinacion_visual(delta)
		_actualizar_animaciones(delta)
		return

	# Estado de Ground Pound (Pisotón descendente bólido)
	if _en_ground_pound:
		if is_on_floor():
			_al_aterrizar_ground_pound(vel_y_previa)
		else:
			# Cancelación a Dive tipo Odyssey: si durante la pausa o caída el jugador acciona con dirección
			if not entrada_bloqueada() and (Input.is_action_just_pressed("interactuar") or (InputMap.has_action("habilidad_especial") and Input.is_action_just_pressed("habilidad_especial"))):
				var dir_input = obtener_direccion_movimiento()
				if dir_input != Vector3.ZERO and not _dive_realizado_en_aire:
					_en_ground_pound = false
					_tiempo_pausa_ground_pound = 0.0
					ejecutar_dive(dir_input.normalized())
					_actualizar_squash_stretch_vivo(delta)
					_procesar_inclinacion_visual(delta)
					_actualizar_animaciones(delta)
					return

			if _tiempo_pausa_ground_pound > 0.0:
				_tiempo_pausa_ground_pound -= delta
				velocity = Vector3.ZERO
			else:
				velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
				velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
				velocity.y = VELOCIDAD_CAIDA_GROUND_POUND
			move_and_slide()
			_actualizar_disponibilidad_interaccion()
			_actualizar_squash_stretch_vivo(delta)
			_procesar_inclinacion_visual(delta)
			_actualizar_animaciones(delta)
			return

	# Estado de Dive aéreo (Lanzamiento horizontal tipo Odyssey)
	if _en_dive:
		if is_on_floor():
			_en_dive = false
			_dive_realizado_en_aire = false
			_tiempo_dive = 0.0
			_tiempo_recuperacion_dive = DURACION_RECUPERACION_DIVE
			_al_aterrizar(vel_y_previa)
		else:
			_tiempo_dive -= delta
			if _tiempo_dive <= 0.0:
				_en_dive = false

	procesar_salto_base(delta)
	procesar_movimiento_base(delta)
	_actualizar_disponibilidad_interaccion()
	_procesar_input_habilidad()
	_actualizar_particulas_polvo(vel_y_previa)
	_actualizar_squash_stretch_vivo(delta)
	_procesar_inclinacion_visual(delta)
	_actualizar_animaciones(delta)

func _procesar_input_habilidad() -> void:
	if movimiento_bloqueado:
		return

	if Input.is_action_just_pressed("interactuar") or (InputMap.has_action("habilidad_especial") and Input.is_action_just_pressed("habilidad_especial")):
		# Aéreo: Si está en el aire, ejecuta Dive o Ground Pound según el stick
		if not is_on_floor():
			var dir_input = obtener_direccion_movimiento()
			if dir_input != Vector3.ZERO:
				if not _dive_realizado_en_aire:
					ejecutar_dive(dir_input.normalized())
			elif not _en_ground_pound:
				ejecutar_ground_pound()
			return

		# Terrestre: Si hay un mecanismo físico cercano (Palanca, Manivela), operarlo
		var mecanismo = _obtener_mecanismo_prioritario()
		if is_instance_valid(mecanismo):
			if mecanismo.has_method("intentar_interactuar"):
				if mecanismo.intentar_interactuar(self):
					var vib_mgr = _get_vibration_manager()
					if es_activo() and is_instance_valid(vib_mgr):
						vib_mgr.vibrar_mecanismo()
			return

		# Terrestre: Si no hay mecanismo pero hay un muro rompible o caja enfrente: Realizar Embate Rompedor
		if _cooldown_embate_actual <= 0.0 and puede_accionar:
			ejecutar_embate()

# ─────────────────────────────────────────────────────────────────────────────
# EMBATE FÍSICO (GOLPE / TACKLE / ROMPER MUROS)
# ─────────────────────────────────────────────────────────────────────────────

func ejecutar_embate() -> void:
	_cooldown_embate_actual = tiempo_cooldown_embate
	_esta_haciendo_embate = true
	_tiempo_embate = 0.22
	var vib_mgr = _get_vibration_manager()
	if es_activo() and is_instance_valid(vib_mgr):
		vib_mgr.vibrar_embate()

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
					var vib_mgr = _get_vibration_manager()
					if es_activo() and is_instance_valid(vib_mgr):
						vib_mgr.vibrar_impacto_fuerte()
				elif colisionador is RigidBody3D:
					colisionador.apply_central_impulse(direccion * 7.0)
					var vib_mgr = _get_vibration_manager()
					if es_activo() and is_instance_valid(vib_mgr):
						vib_mgr.vibrar_embate()

func ejecutar_ground_pound() -> void:
	if _en_ground_pound or is_on_floor():
		return
	_en_ground_pound = true
	_tiempo_pausa_ground_pound = DURACION_PAUSA_GROUND_POUND
	_en_dive = false
	_tiempo_dive = 0.0
	velocity = Vector3.ZERO
	var vib_mgr = _get_vibration_manager()
	if es_activo() and is_instance_valid(vib_mgr):
		vib_mgr.vibrar_salto(1)

func ejecutar_dive(dir_impulso: Vector3) -> void:
	if is_on_floor() or _dive_realizado_en_aire:
		return
	_dive_realizado_en_aire = true
	_en_dive = true
	_tiempo_dive = DURACION_DIVE
	_en_ground_pound = false
	_tiempo_pausa_ground_pound = 0.0

	var target_angle = atan2(-dir_impulso.x, -dir_impulso.z)
	rotation.y = target_angle

	velocity.x = dir_impulso.x * FUERZA_HORIZONTAL_DIVE
	velocity.z = dir_impulso.z * FUERZA_HORIZONTAL_DIVE
	velocity.y = IMPULSO_VERTICAL_DIVE

	_comprobar_impacto_frontal(dir_impulso)
	_emitir_efectos_embate()
	var vib_mgr = _get_vibration_manager()
	if es_activo() and is_instance_valid(vib_mgr):
		vib_mgr.vibrar_embate()

func _al_aterrizar_ground_pound(_vel_y: float) -> void:
	_en_ground_pound = false
	_tiempo_pausa_ground_pound = 0.0
	_tiempo_ventana_salto_ground_pound = VENTANA_SALTO_GROUND_POUND
	_tiempo_squash_ground_pound = DURACION_SQUASH_GROUND_POUND
	_tiempo_aterrizaje_vivo = 0.0 # Se prioriza el rebote rápido de gelatina del ground pound
	_estaba_en_suelo = true # Evitar que _actualizar_particulas_polvo dispare un segundo aterrizaje encima
	_comprobar_impacto_ground_pound()
	_emitir_rafaga_particulas_impacto(true)
	var vib_mgr = _get_vibration_manager()
	if es_activo() and is_instance_valid(vib_mgr):
		vib_mgr.vibrar_impacto_fuerte()

func _comprobar_impacto_ground_pound() -> void:
	var espacio_fisica = get_world_3d().direct_space_state
	if not espacio_fisica or not _impacto_query:
		return

	_impacto_query.transform = Transform3D(Basis(), global_position + Vector3.DOWN * 0.2)
	var resultados = espacio_fisica.intersect_shape(_impacto_query, 8)
	for res in resultados:
		var colisionador = res.get("collider")
		if is_instance_valid(colisionador):
			if colisionador.has_method("recibir_impacto"):
				colisionador.recibir_impacto(self)
			elif colisionador.has_method("activar"):
				colisionador.activar(self)
			elif colisionador is RigidBody3D:
				colisionador.apply_central_impulse(Vector3.DOWN * 6.0)

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

var _entorno_vivo_cache: Environment = null

func obtener_entorno_personaje() -> Environment:
	if _entorno_vivo_cache == null:
		_entorno_vivo_cache = _crear_entorno_vivo()
	return _entorno_vivo_cache

func obtener_cull_mask_personaje() -> int:
	return 1048575 & ~(1 << 2)

func actualizar_visibilidad_local(preservar_rotacion_camara: bool = false):
	super(preservar_rotacion_camara)
	var es_mio = es_activo()
	var camera = obtener_camara()
	if es_mio and camera:
		camera.cull_mask = obtener_cull_mask_personaje()
		camera.environment = obtener_entorno_personaje()
	var arm = obtener_spring_arm()
	if arm:
		arm.collision_mask = (1 << 0) | (1 << 1)

const CIELO_VIVO_MAT = preload("res://shaders/entorno/cielo/cielo_vivo_mat.tres")

func _crear_entorno_vivo() -> Environment:
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	
	var sky = Sky.new()
	sky.sky_material = CIELO_VIVO_MAT
	sky.radiance_size = Sky.RADIANCE_SIZE_128
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
	if en_canon:
		return
	if not es_activo():
		var red_mgr = _get_red_manager()
		var es_offline_o_solo = is_instance_valid(red_mgr) and (red_mgr.es_un_jugador or multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
		if not es_offline_o_solo:
			# Detección remota de salto y aterrizaje en multijugador para peers sincronizados
			var desp_y = global_position.y - _pos_anterior_remoto.y
			var vel_y_remoto = desp_y / maxf(delta, 0.001)
			if vel_y_remoto > 3.6 and _tiempo_anticipacion_salto_vivo <= 0.0 and _tiempo_despegue_salto_vivo <= 0.0:
				_iniciar_animacion_salto_vivo(1)
			elif vel_y_remoto < -1.8:
				_vel_y_remoto_anterior_vivo = vel_y_remoto
			elif absf(vel_y_remoto) < 0.6 and _vel_y_remoto_anterior_vivo < -1.8:
				_iniciar_animacion_aterrizaje_vivo(_vel_y_remoto_anterior_vivo)
				_vel_y_remoto_anterior_vivo = 0.0

			_actualizar_squash_stretch_vivo(delta)
			_actualizar_animaciones(delta)
			_procesar_inclinacion_visual(delta)

func _actualizar_animaciones(delta: float):
	if not is_instance_valid(anim_player):
		return
		
	var vel_horizontal: float = 0.0
	var en_suelo: bool = true
	var red_mgr = _get_red_manager()
	var es_offline_o_solo = is_instance_valid(red_mgr) and (red_mgr.es_un_jugador or multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	
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
		if esta_derrapando:
			# Durante el derrape, amortiguar la animación de caminar con fluidez (sin cortar bruscamente a Idle)
			anim_deseada = "caminar"
			blend_time = 0.22
			speed = clampf((vel_horizontal / VELOCIDAD) * 1.6, 0.35, 1.2)
		elif vel_horizontal > 0.35:
			anim_deseada = "caminar"
			blend_time = 0.16
			speed = clampf((vel_horizontal / VELOCIDAD) * 2.6, 0.75, 3.2)
		else:
			anim_deseada = "Idle"
			blend_time = 0.26
			speed = 1.25
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

	if en_canon:
		modelo_vivo.rotation = _rotacion_inicial_modelo_vivo
		var t_aplastamiento = clampf((1.0 - _factor_escala_canon) / maxf(1.0 - 0.82, 0.001), 0.0, 1.0)
		var offset_y = lerpf(0.0, offset_vertical_canon, t_aplastamiento)
		modelo_vivo.position.y = _pos_y_inicial_vivo - offset_y
		return

	var vel_horizontal: float = 0.0
	var en_suelo: bool = true
	var red_mgr = _get_red_manager()
	var es_offline_o_solo = is_instance_valid(red_mgr) and (red_mgr.es_un_jugador or multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer)

	if es_activo() or es_offline_o_solo:
		vel_horizontal = Vector2(velocity.x, velocity.z).length()
		en_suelo = is_on_floor()
	else:
		var dist = Vector2(global_position.x - _pos_anterior_remoto.x, global_position.z - _pos_anterior_remoto.z).length()
		vel_horizontal = dist / maxf(delta, 0.001)
		en_suelo = true

	var factor_vel = clampf(vel_horizontal / VELOCIDAD, 0.0, 1.0)

	# 1. Inclinación frontal (pitch) al correr, embestir, derrapar o realizar dive/ground pound
	var objetivo_inclinacion = 0.0
	if esta_derrapando:
		objetivo_inclinacion = -0.12 # Inclinación suave y controlada hacia atrás
	elif _en_dive:
		objetivo_inclinacion = 0.52 # Inclinación aerodinámica de clavado frontal en el aire
	elif _en_ground_pound:
		objetivo_inclinacion = 0.0 # Posición erguida de bólido vertical
	elif _esta_haciendo_embate:
		objetivo_inclinacion = 0.24 # Inclinación frontal al hacer tackle
	elif en_suelo and vel_horizontal > 0.5:
		objetivo_inclinacion = factor_vel * 0.07
	var vel_lerp_inclinacion = 16.0 if (_en_dive or _esta_haciendo_embate) else 11.0
	_inclinacion_actual = lerpf(_inclinacion_actual, objetivo_inclinacion, vel_lerp_inclinacion * delta)
	modelo_vivo.rotation.x = _rotacion_inicial_modelo_vivo.x + _inclinacion_actual
	modelo_vivo.rotation.y = _rotacion_inicial_modelo_vivo.y

	# 2. Amortiguación, caminata y desplazamiento vertical por Squash & Stretch
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
		
		# Sumar rebote de paso + compresión/extensión de squash & stretch
		var target_y = _pos_y_inicial_vivo + rebote_y + _offset_y_squash_vivo
		modelo_vivo.position.y = lerpf(modelo_vivo.position.y, target_y, 18.0 * delta)
		
		# Balanceo lateral mínimo y orgánico
		var balanceo_objetivo = sin((t_anim / dur) * TAU) * 0.008 * factor_vel
		_balanceo_paso_actual = lerpf(_balanceo_paso_actual, balanceo_objetivo, 14.0 * delta)
		modelo_vivo.rotation.z = _rotacion_inicial_modelo_vivo.z + _balanceo_paso_actual
	else:
		# Regreso suave a la postura y altura con offset de squash & stretch aplicado
		var target_y = _pos_y_inicial_vivo + _offset_y_squash_vivo
		modelo_vivo.position.y = lerpf(modelo_vivo.position.y, target_y, 18.0 * delta)
		_balanceo_paso_actual = lerpf(_balanceo_paso_actual, 0.0, 12.0 * delta)
		modelo_vivo.rotation.z = _rotacion_inicial_modelo_vivo.z + _balanceo_paso_actual

# ─────────────────────────────────────────────────────────────────────────────
# CONTROL PROCEDURAL DE SQUASH & STRETCH (EL VIVO - GELATINA ELÁSTICA Y REACTIVA)
# ─────────────────────────────────────────────────────────────────────────────

func _actualizar_squash_stretch_vivo(delta: float) -> void:
	if not is_instance_valid(modelo_vivo):
		return

	if en_canon:
		ajustar_factor_escala_canon(_factor_escala_canon)
		return

	var escala_y = 1.0
	var offset_y = 0.0
	var red_mgr = _get_red_manager()
	var es_offline_o_solo = is_instance_valid(red_mgr) and (red_mgr.es_un_jugador or multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	var en_suelo = is_on_floor() if (es_activo() or es_offline_o_solo) else true

	# 1. Fase de Impacto y Resorte de Salto Bomba (Ground Pound - Rebote rápido de gelatina sin pausa estática)
	if _tiempo_squash_ground_pound > 0.0:
		_tiempo_squash_ground_pound = maxf(_tiempo_squash_ground_pound - delta, 0.0)
		var p = 1.0 - (_tiempo_squash_ground_pound / DURACION_SQUASH_GROUND_POUND)
		if p < 0.22:
			# Sub-fase A: Impact Squash elástico y veloz contra el suelo (pies anclados a la base)
			var sub_p = p / 0.22
			escala_y = lerpf(1.0, 0.62, sin(sub_p * (PI * 0.5)))
			offset_y = -ALTURA_PIVOTE_A_SUELO_VIVO * (1.0 - escala_y)
		elif p < 0.55:
			# Sub-fase B: Rebote inmediato de gelatina hacia arriba (Overshoot Stretch)
			var sub_p = (p - 0.22) / 0.33
			escala_y = lerpf(0.62, 1.22, sin(sub_p * (PI * 0.5)))
			offset_y = -ALTURA_PIVOTE_A_SUELO_VIVO * (1.0 - escala_y)
		elif p < 0.80:
			# Sub-fase C: Segundo mini-rebote elástico de compresión
			var sub_p = (p - 0.55) / 0.25
			escala_y = lerpf(1.22, 0.91, sin(sub_p * (PI * 0.5)))
			offset_y = -ALTURA_PIVOTE_A_SUELO_VIVO * (1.0 - escala_y)
		else:
			# Sub-fase D: Asentamiento final al reposo
			var sub_p = (p - 0.80) / 0.20
			escala_y = lerpf(0.91, 1.0, sin(sub_p * (PI * 0.5)))
			offset_y = -ALTURA_PIVOTE_A_SUELO_VIVO * (1.0 - escala_y)

	# 2. Fase de Derrape / Frenado en el Suelo (Aplanamiento elástico en la dirección de inercia)
	elif esta_derrapando:
		escala_y = 0.88 # Aplanándose como gelatina elástica contra el suelo
		offset_y = -ALTURA_PIVOTE_A_SUELO_VIVO * (1.0 - escala_y)

	# 3. Fase de Anticipación de Salto (Agazapado elástico rápido reuniendo fuerza con base en los pies)
	elif _tiempo_anticipacion_salto_vivo > 0.0:
		_tiempo_anticipacion_salto_vivo = maxf(_tiempo_anticipacion_salto_vivo - delta, 0.0)
		var p = 1.0 - (_tiempo_anticipacion_salto_vivo / _duracion_anticipacion_vivo)
		var factor_curva = sin(p * PI)
		if _es_segundo_salto_vivo:
			# Doble salto aéreo: encogimiento atlético en el aire (tuck)
			escala_y = lerpf(1.0, 0.78, factor_curva)
			offset_y = 0.0
		else:
			# Salto desde el suelo: compresión contra el piso con plantas de los pies ancladas
			escala_y = lerpf(1.0, 0.72, factor_curva)
			offset_y = -ALTURA_PIVOTE_A_SUELO_VIVO * (1.0 - escala_y)

	# 4. Fase de Despegue Explosivo (Salto estirándose hacia arriba y estrechándose en los lados)
	elif _tiempo_despegue_salto_vivo > 0.0:
		_tiempo_despegue_salto_vivo = maxf(_tiempo_despegue_salto_vivo - delta, 0.0)
		var p = 1.0 - (_tiempo_despegue_salto_vivo / _duracion_despegue_vivo)
		var factor_estiramiento = sin(clampf(p * 1.4, 0.0, 1.0) * PI)
		var stretch_max = _fuerza_despegue_especial if _fuerza_despegue_especial > 1.0 else (1.36 if _es_segundo_salto_vivo else 1.32)
		escala_y = lerpf(1.0, stretch_max, factor_estiramiento)
		if not _es_segundo_salto_vivo:
			offset_y = -ALTURA_PIVOTE_A_SUELO_VIVO * (1.0 - escala_y) * (1.0 - p)

	# 5. Fase Aérea (Deformación aerodinámica según velocidad vertical, dive o ground pound)
	elif not en_suelo:
		if _en_ground_pound:
			if _tiempo_pausa_ground_pound > 0.0:
				escala_y = 0.76 # Encogido como resorte concentrado
			else:
				escala_y = 1.38 # ¡Alargarse verticalmente al caer como una gota de gelatina!
			offset_y = 0.0
		elif _en_dive:
			escala_y = 0.84 # Perfil de torpedo aerodinámico alargado hacia el frente
			offset_y = 0.0
		else:
			var vel_y = velocity.y if (es_activo() or es_offline_o_solo) else 0.0
			if vel_y > 1.5:
				# Ascenso: alargamiento sostenido proporcional a la velocidad
				var factor_subida = clampf(vel_y / FUERZA_SALTO, 0.0, 1.0)
				escala_y = 1.0 + (factor_subida * 0.18)
				offset_y = 0.0
			elif absf(vel_y) <= 1.5:
				# Ápice: normalización suave con relajación momentánea
				escala_y = 1.0
				offset_y = 0.0
			else:
				# Caída rápida: estiramiento descendente hacia el suelo anticipando el impacto
				var factor_caida = clampf(-vel_y / VELOCIDAD_MAX_CAIDA, 0.0, 1.0)
				escala_y = 1.0 + (factor_caida * 0.22)
				offset_y = 0.0

	# 6. Fase de Aterrizaje Normal (Impacto rápido, rebote de gelatina y asentamiento con pies en la base)
	elif _tiempo_aterrizaje_vivo > 0.0:
		_tiempo_aterrizaje_vivo = maxf(_tiempo_aterrizaje_vivo - delta, 0.0)
		var t = 1.0 - (_tiempo_aterrizaje_vivo / _duracion_aterrizaje_vivo)
		var f = _fuerza_impacto_aterrizaje_vivo

		if t < 0.25:
			# Sub-fase A: Impact Squash veloz con base anclada a los pies
			var sub_t = t / 0.25
			var max_squash = 1.0 - (0.30 * f) # Hasta 0.70 en caídas rápidas
			escala_y = lerpf(1.0, max_squash, sin(sub_t * (PI * 0.5)))
			offset_y = -ALTURA_PIVOTE_A_SUELO_VIVO * (1.0 - escala_y)
		elif t < 0.62:
			# Sub-fase B: Rebound Overshoot (Rebote de gelatina superando altura normal)
			var sub_t = (t - 0.25) / 0.37
			var max_squash = 1.0 - (0.30 * f)
			var overshoot = 1.0 + (0.16 * f) # Hasta 1.16
			escala_y = lerpf(max_squash, overshoot, sin(sub_t * (PI * 0.5)))
			offset_y = -ALTURA_PIVOTE_A_SUELO_VIVO * (1.0 - escala_y)
		else:
			# Sub-fase C: Asentamiento elástico fluido de regreso al reposo
			var sub_t = (t - 0.62) / 0.38
			var overshoot = 1.0 + (0.16 * f)
			escala_y = lerpf(overshoot, 1.0, sin(sub_t * (PI * 0.5)))
			offset_y = -ALTURA_PIVOTE_A_SUELO_VIVO * (1.0 - escala_y)
	else:
		escala_y = 1.0
		offset_y = 0.0
		_fuerza_despegue_especial = 0.0

	# Principio de conservación elástica tipo gelatina:
	# Al comprimirse verticalmente se ensancha lateralmente, y al estirarse verticalmente se estrecha en los lados
	var delta_y = escala_y - 1.0
	var escala_xz = clampf(1.0 - (delta_y * 0.50), 0.80, 1.25)
	var escala_objetivo = Vector3(escala_xz, escala_y, escala_xz)

	_squash_stretch_vivo = _squash_stretch_vivo.lerp(escala_objetivo, 32.0 * delta)
	_offset_y_squash_vivo = lerpf(_offset_y_squash_vivo, offset_y, 32.0 * delta)

	# Aplicar escala al modelo respetando la escala base y orientación
	modelo_vivo.scale = Vector3(
		_escala_base_vivo.x * _squash_stretch_vivo.x * _signo_escala_vivo.x,
		_escala_base_vivo.y * _squash_stretch_vivo.y * _signo_escala_vivo.y,
		_escala_base_vivo.z * _squash_stretch_vivo.z * _signo_escala_vivo.z
	)

func _iniciar_animacion_salto_vivo(numero_salto: int) -> void:
	_es_segundo_salto_vivo = (numero_salto > 1)
	_tiempo_anticipacion_salto_vivo = _duracion_anticipacion_vivo
	_tiempo_despegue_salto_vivo = _duracion_despegue_vivo
	_tiempo_aterrizaje_vivo = 0.0

func _iniciar_animacion_aterrizaje_vivo(vel_y: float) -> void:
	if _tiempo_squash_ground_pound > 0.0:
		return
	if _tiempo_aterrizaje_vivo > (_duracion_aterrizaje_vivo * 0.75):
		return
	var factor = clampf((abs(vel_y) - 1.8) / 12.0, 0.25, 1.0)
	_fuerza_impacto_aterrizaje_vivo = factor
	_tiempo_aterrizaje_vivo = _duracion_aterrizaje_vivo
	_tiempo_anticipacion_salto_vivo = 0.0
	_tiempo_despegue_salto_vivo = 0.0

func _al_realizar_salto(numero_salto: int):
	super(numero_salto)
	_iniciar_animacion_salto_vivo(numero_salto)
	_emitir_rafaga_particulas_impacto(false)

func _al_aterrizar(vel_y: float) -> void:
	super(vel_y)
	_iniciar_animacion_aterrizaje_vivo(vel_y)

static var _malla_nube_lowpoly_cache: ArrayMesh = null

static func _crear_malla_nube_lowpoly(radio: float = 0.16) -> ArrayMesh:
	if _malla_nube_lowpoly_cache != null:
		return _malla_nube_lowpoly_cache

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
		# En Godot, el orden horario/antihorario para normal exterior:
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
	mat.albedo_color = Color(0.97, 0.95, 0.91, 1.0) # Crema/blanco cálido sólido mate
	mat.roughness = 0.92
	mat.metallic = 0.0
	# Usar TRANSPARENCY_ALPHA con alpha = 1.0 y DEPTH_DRAW_ALWAYS hace que las partículas se dibujen
	# después de la silueta X-Ray del personaje (sin activar el stencil naranja a través de ellas),
	# pero manteniendo su volumen 100% sólido y opaco con escritura en el buffer de profundidad.
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	st.set_material(mat)

	_malla_nube_lowpoly_cache = st.commit()
	return _malla_nube_lowpoly_cache

func _configurar_particulas_lowpoly() -> void:
	var malla_lowpoly = _crear_malla_nube_lowpoly(0.14)
	var curva_escala = Curve.new()
	curva_escala.add_point(Vector2(0.0, 0.40))
	curva_escala.add_point(Vector2(0.20, 1.15))
	curva_escala.add_point(Vector2(0.68, 0.85))
	curva_escala.add_point(Vector2(1.0, 0.0))

	if is_instance_valid(particulas_polvo):
		particulas_polvo.mesh = malla_lowpoly
		# Nivel de los pies en la base de la cápsula (-0.42) y ligeramente detrás de los talones (z = 0.16)
		particulas_polvo.position = Vector3(0.0, -0.42, 0.16)
		particulas_polvo.amount = 10
		particulas_polvo.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		particulas_polvo.emission_box_extents = Vector3(0.16, 0.03, 0.08)
		particulas_polvo.direction = Vector3(0.0, 0.25, 0.85) # En espacio local del personaje, +Z es hacia atrás de los pies
		particulas_polvo.spread = 28.0
		particulas_polvo.scale_amount_curve = curva_escala
		particulas_polvo.color_ramp = null
		particulas_polvo.color = Color(1.0, 1.0, 1.0, 1.0)
		particulas_polvo.gravity = Vector3(0.0, 0.4, 0.0)

	if is_instance_valid(particulas_aterrizaje):
		particulas_aterrizaje.mesh = malla_lowpoly
		# Justo a ras de los pies (-0.42)
		particulas_aterrizaje.position = Vector3(0.0, -0.42, 0.0)
		particulas_aterrizaje.amount = 16
		particulas_aterrizaje.lifetime = 0.42
		particulas_aterrizaje.explosiveness = 0.98
		particulas_aterrizaje.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		particulas_aterrizaje.emission_ring_axis = Vector3(0.0, 1.0, 0.0)
		particulas_aterrizaje.emission_ring_height = 0.04
		particulas_aterrizaje.emission_ring_radius = 0.28
		particulas_aterrizaje.emission_ring_inner_radius = 0.22
		# Velocidad inicial 0 y aceleración radial positiva para que nazcan en círculo alrededor de los pies
		# y se expandan radialmente hacia afuera en 360° de forma uniforme
		particulas_aterrizaje.direction = Vector3(0.0, 1.0, 0.0)
		particulas_aterrizaje.spread = 15.0
		particulas_aterrizaje.flatness = 0.0
		particulas_aterrizaje.initial_velocity_min = 0.15
		particulas_aterrizaje.initial_velocity_max = 0.35
		particulas_aterrizaje.radial_accel_min = 12.0
		particulas_aterrizaje.radial_accel_max = 16.0
		particulas_aterrizaje.gravity = Vector3(0.0, 0.4, 0.0)
		particulas_aterrizaje.damping_min = 6.5
		particulas_aterrizaje.damping_max = 8.5
		particulas_aterrizaje.scale_amount_min = 0.85
		particulas_aterrizaje.scale_amount_max = 1.45
		particulas_aterrizaje.scale_amount_curve = curva_escala
		particulas_aterrizaje.color_ramp = null
		particulas_aterrizaje.color = Color(1.0, 1.0, 1.0, 1.0)

func _emitir_rafaga_particulas_impacto(es_impacto_fuerte: bool = false) -> void:
	if not is_instance_valid(particulas_aterrizaje):
		return
	particulas_aterrizaje.position = Vector3(0.0, -0.40 if es_impacto_fuerte else -0.42, 0.0)
	particulas_aterrizaje.emission_ring_radius = 0.34 if es_impacto_fuerte else 0.26
	particulas_aterrizaje.emission_ring_inner_radius = 0.26 if es_impacto_fuerte else 0.20
	particulas_aterrizaje.radial_accel_min = 16.0 if es_impacto_fuerte else 10.5
	particulas_aterrizaje.radial_accel_max = 22.0 if es_impacto_fuerte else 14.5
	particulas_aterrizaje.scale_amount_min = 1.05 if es_impacto_fuerte else 0.78
	particulas_aterrizaje.scale_amount_max = 1.75 if es_impacto_fuerte else 1.25
	particulas_aterrizaje.restart()
	particulas_aterrizaje.emitting = true

func _actualizar_particulas_polvo(vel_y_previa: float = 0.0):
	if esta_derrapando:
		return

	var en_suelo = is_on_floor()
	var vel_horizontal = Vector2(velocity.x, velocity.z).length()
	
	if en_suelo and not _estaba_en_suelo and vel_y_previa < -1.8:
		var es_fuerte = vel_y_previa < -11.0
		_emitir_impacto_aterrizaje(es_fuerte)
		_iniciar_animacion_aterrizaje_vivo(vel_y_previa)
		
	_estaba_en_suelo = en_suelo
	
	if is_instance_valid(particulas_polvo):
		var se_mueve = vel_horizontal > 0.35 and en_suelo
		particulas_polvo.emitting = se_mueve
		
		if se_mueve:
			particulas_polvo.position = Vector3(0.0, -0.42, 0.16)
			var factor = clampf((vel_horizontal - 0.35) / maxf(VELOCIDAD - 0.35, 0.1), 0.0, 1.0)
			particulas_polvo.scale_amount_min = lerpf(0.60, 0.90, factor)
			particulas_polvo.scale_amount_max = lerpf(0.85, 1.25, factor)
			particulas_polvo.initial_velocity_min = lerpf(0.5, 1.1, factor)
			particulas_polvo.initial_velocity_max = lerpf(0.9, 1.8, factor)
			particulas_polvo.lifetime = lerpf(0.26, 0.36, factor)
			particulas_polvo.direction = Vector3(0.0, 0.25, 0.85) # Siempre hacia atrás desde los talones en espacio local

func _emitir_impacto_aterrizaje(es_fuerte: bool = false):
	var vib_mgr = _get_vibration_manager()
	if es_activo() and is_instance_valid(vib_mgr):
		vib_mgr.vibrar_aterrizaje(1.5 if es_fuerte else 1.1)
	_emitir_rafaga_particulas_impacto(es_fuerte)

func _al_iniciar_derrape(velocidad: float, direccion_input: Vector3) -> void:
	super(velocidad, direccion_input)
	# Transición suave gestionada continuamente por _procesar_inclinacion_visual y _actualizar_squash_stretch_vivo
	_emitir_rafaga_particulas_impacto(false)
		
	var vib_mgr = _get_vibration_manager()
	if es_activo() and is_instance_valid(vib_mgr):
		if vib_mgr.has_method("vibrar_derrape"):
			vib_mgr.vibrar_derrape(0.9)
		elif vib_mgr.has_method("vibrar"):
			vib_mgr.vibrar(45, 0.40, 0.20, 0.08)

func _al_procesar_derrape(delta: float, velocidad: float) -> void:
	super(delta, velocidad)
	if is_instance_valid(particulas_polvo):
		particulas_polvo.position = Vector3(0.0, -0.40, 0.0) # En los pies durante el derrape
		particulas_polvo.emitting = true
		particulas_polvo.scale_amount_min = 0.85
		particulas_polvo.scale_amount_max = 1.40
		particulas_polvo.direction = Vector3(0.0, 0.35, -0.65)

func _al_finalizar_derrape() -> void:
	super()
	if is_instance_valid(particulas_polvo):
		particulas_polvo.position = Vector3(0.0, -0.42, 0.16)
		particulas_polvo.scale_amount_min = 0.60
		particulas_polvo.scale_amount_max = 1.10
	if is_instance_valid(particulas_aterrizaje):
		particulas_aterrizaje.position = Vector3(0.0, -0.42, 0.0)

func _al_realizar_salto_derrape() -> void:
	super()
	_iniciar_animacion_salto_vivo(1)
	_emitir_rafaga_particulas_impacto(true)
	var vib_mgr = _get_vibration_manager()
	if es_activo() and is_instance_valid(vib_mgr):
		vib_mgr.vibrar_embate()

func _al_resetear_estados() -> void:
	_esta_haciendo_embate = false
	_tiempo_embate = 0.0
	_en_ground_pound = false
	_tiempo_pausa_ground_pound = 0.0
	_tiempo_ventana_salto_ground_pound = 0.0
	_tiempo_squash_ground_pound = 0.0
	_en_dive = false
	_tiempo_dive = 0.0
	_tiempo_recuperacion_dive = 0.0
	_dive_realizado_en_aire = false
	_fuerza_despegue_especial = 0.0
	_inclinacion_actual = 0.0
	_balanceo_paso_actual = 0.0
	_tiempo_anticipacion_salto_vivo = 0.0
	_tiempo_despegue_salto_vivo = 0.0
	_tiempo_aterrizaje_vivo = 0.0
	_squash_stretch_vivo = Vector3.ONE
	_offset_y_squash_vivo = 0.0
	_vel_y_remoto_anterior_vivo = 0.0
	if is_instance_valid(luz_vivo):
		luz_vivo.light_energy = 1.6
		luz_vivo.omni_range = 4.5
	if is_instance_valid(modelo_vivo):
		modelo_vivo.rotation = _rotacion_inicial_modelo_vivo
		modelo_vivo.position.y = _pos_y_inicial_vivo
		modelo_vivo.scale = Vector3(
			_escala_base_vivo.x * _signo_escala_vivo.x,
			_escala_base_vivo.y * _signo_escala_vivo.y,
			_escala_base_vivo.z * _signo_escala_vivo.z
		)

# ─────────────────────────────────────────────────────────────────────────────
# GESTIÓN DE FORMA Y ESTADO EN CAÑÓN ESPIRITUAL
# ─────────────────────────────────────────────────────────────────────────────

func entrar_en_canon(factor_escala: float = 0.82) -> void:
	if not en_canon:
		_silueta_original_canon = silueta_activa
	en_canon = true
	_factor_escala_canon = factor_escala
	movimiento_bloqueado = true
	silueta_activa = false
	velocity = Vector3.ZERO
	if is_instance_valid(modelo_vivo):
		modelo_vivo.rotation = _rotacion_inicial_modelo_vivo
	ajustar_factor_escala_canon(factor_escala)

func salir_de_canon() -> void:
	en_canon = false
	_factor_escala_canon = 1.0
	offset_vertical_canon = 0.11
	_offset_vertical_canon = 0.11
	movimiento_bloqueado = false
	silueta_activa = true
	rotation.x = 0.0
	rotation.z = 0.0
	if is_instance_valid(modelo_vivo):
		modelo_vivo.rotation = _rotacion_inicial_modelo_vivo
		modelo_vivo.position.y = _pos_y_inicial_vivo
		modelo_vivo.scale = Vector3(
			_escala_base_vivo.x * _signo_escala_vivo.x,
			_escala_base_vivo.y * _signo_escala_vivo.y,
			_escala_base_vivo.z * _signo_escala_vivo.z
		)

func ajustar_factor_escala_canon(factor: float) -> void:
	_factor_escala_canon = factor
	if is_instance_valid(modelo_vivo):
		var t_aplastamiento = clampf((1.0 - factor) / maxf(1.0 - 0.82, 0.001), 0.0, 1.0)
		# Tucking lateral ligero para que las manos se mantengan cómodamente dentro del cilindro
		var squash_x = lerpf(1.0, 0.92, t_aplastamiento)
		# Ligera compresión vertical
		var squash_y = lerpf(1.0, 0.90, t_aplastamiento)
		var squash_z = lerpf(1.0, 0.98, t_aplastamiento)
		# Descenso vertical para que los pies queden completamente ocultos dentro del cañón
		var offset_y = lerpf(0.0, offset_vertical_canon, t_aplastamiento)
		modelo_vivo.position.y = _pos_y_inicial_vivo - offset_y
		modelo_vivo.scale = Vector3(
			_escala_base_vivo.x * factor * squash_x * _signo_escala_vivo.x,
			_escala_base_vivo.y * factor * squash_y * _signo_escala_vivo.y,
			_escala_base_vivo.z * factor * squash_z * _signo_escala_vivo.z
		)
