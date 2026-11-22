@tool
extends Node3D
class_name Torbellino

# ===================================================================
# TORBELLINO ESPIRITUAL (PROYECTO LIMBO)
# Obstáculo aéreo que succiona y absorbe al Fantasma durante su descenso,
# obligándolo a calcular el tiempo de levitación y caída libre.
# ===================================================================

signal fantasma_atraido(fantasma: Node3D)
signal fantasma_absorbido(fantasma: Node3D)
signal fantasma_expulsado(fantasma: Node3D)

@export_group("Física de Succión")
@export var radio_influencia: float = 4.2
@export var fuerza_succion_horizontal: float = 14.0 ## Fuerza atractora radial hacia el centro
@export var fuerza_giro_tangencial: float = 11.0 ## Fuerza de giro circular envolvente
@export var fuerza_arrastre_vertical: float = 10.0 ## Arrastre hacia abajo para contrarrestar planeo
@export var afecta_solo_fantasmas: bool = true

@export_group("Absorción y Núcleo")
@export var radio_nucleo: float = 1.15
@export var duracion_absorcion: float = 1.1 ## Duración de descenso y giro dentro del cono
@export var fuerza_expulsion_horizontal: float = 5.0
@export var fuerza_expulsion_vertical: float = -18.0 ## Impulso descendente potente para caer con velocidad
@export var altura_tornado: float = 5.2 ## Altura total del embudo del torbellino
@export var es_letal_al_contacto: bool = false

@export_group("Patrulla / Movimiento")
@export var se_mueve: bool = false ## Activa el movimiento de ida y vuelta en bucle
@export var desplazamiento: Vector3 = Vector3(0, 0, 4.0) ## Desplazamiento relativo desde el origen (hacia dónde se mueve)
@export var velocidad_movimiento: float = 2.5 ## Velocidad de desplazamiento en m/s
@export var tiempo_espera_extremos: float = 0.5 ## Tiempo de pausa (segundos) en cada extremo antes de retornar
@export var movimiento_suave: bool = true ## Aceleración y frenado suave en los extremos

@export_group("Mecanismo / Puerta")
## Disparador principal (ej. BotonPresion o InterruptorAura) que mueve el torbellino para dejar pasar.
@export var disparador_objetivo: Node3D = null
## Lista adicional de disparadores si requiere múltiples interruptores.
@export var disparadores_objetivo: Array[Node3D] = []
## Condición lógica cuando hay múltiples disparadores (O = cualquiera, Y = todos).
@export var condicion_combinacion: ElementoInteractivoBase.CondicionCombinacion = ElementoInteractivoBase.CondicionCombinacion.CONDICION_O
## Distancia que se desplaza el torbellino al activarse el disparador.
@export var distancia_desplazamiento: float = 10.0
## Dirección en la que se desplaza el torbellino al activarse el disparador.
@export var direccion_desplazamiento: Vector3 = Vector3.RIGHT
## Tiempo en segundos que tarda la transición de apertura/cierre.
@export var tiempo_transicion: float = 1.0

@export_group("Visuales")
@export var velocidad_rotacion_visual: float = 240.0
@export var oscilacion_altura: float = 0.25
@export var frecuencia_oscilacion: float = 1.6
@export var mostrar_hojas: bool = true:
	set(valor):
		mostrar_hojas = valor
		if is_instance_valid(particulas_hojas):
			particulas_hojas.visible = valor
			particulas_hojas.emitting = valor
		if is_instance_valid(particulas_hojas_2):
			particulas_hojas_2.visible = valor
			particulas_hojas_2.emitting = valor

@onready var area_influencia: Area3D = get_node_or_null("AreaInfluencia")
@onready var area_absorcion: Area3D = get_node_or_null("AreaAbsorcion")
@onready var modelo_visual: Node3D = get_node_or_null("Visual")
@onready var embudo_vortice: MeshInstance3D = get_node_or_null("Visual/EmbudoVortice")
@onready var luz_nucleo: OmniLight3D = get_node_or_null("LuzTorbellino")
@onready var particulas_vortice: CPUParticles3D = get_node_or_null("ParticulasVortice")
@onready var particulas_atraccion: CPUParticles3D = get_node_or_null("ParticulasZonaAtraccion")
@onready var particulas_atraccion_2: CPUParticles3D = get_node_or_null("ParticulasZonaAtraccion2")
@onready var particulas_atraccion_3: CPUParticles3D = get_node_or_null("ParticulasZonaAtraccion3")
@onready var particulas_hojas: CPUParticles3D = get_node_or_null("ParticulasHojas")
@onready var particulas_hojas_2: CPUParticles3D = get_node_or_null("ParticulasHojas2")

var _cuerpos_en_influencia: Array[CharacterBody3D] = []
var _tiempo_acumulado: float = 0.0
var _pos_y_inicial: float = 0.0
var _pos_inicial_mov: Vector3 = Vector3.ZERO
var _progreso_patrulla: float = 0.0
var _direccion_patrulla: float = 1.0
var _timer_espera: float = 0.0

var _disparadores_resueltos: Array[Node3D] = []
var _estados_disparadores: Dictionary = {}
var _tiene_disparadores: bool = false
var _mecanismo_activo: bool = false
var _tween_mecanismo: Tween = null

# --- Variables de Adaptación a Escala ---
var _datos_base_guardados: bool = false
var _escala_previa: Vector3 = Vector3.ONE
var _particulas_todas: Array[CPUParticles3D] = []
var _datos_base_particulas: Dictionary = {}
var _angulos_particulas: Dictionary = {}
var _base_visual_pos_y: float = 0.2
var _base_luz_range: float = 4.5

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		if is_inside_tree():
			if typeof(_datos_base_guardados) != TYPE_BOOL or not _datos_base_guardados:
				_guardar_datos_base()
			if typeof(_escala_previa) != TYPE_VECTOR3:
				_escala_previa = scale
				_actualizar_adaptacion_escala()
			elif not scale.is_equal_approx(_escala_previa):
				_actualizar_adaptacion_escala()
				_escala_previa = scale

func _ready() -> void:
	_pos_y_inicial = position.y
	_pos_inicial_mov = position
	set_notify_transform(true)
	
	_guardar_datos_base()
	_actualizar_adaptacion_escala(true)
	_escala_previa = scale

	# Asegurar configuración anti-culling para evitar que las rocas y hojas desaparezcan repentinamente
	for p in [particulas_vortice, particulas_atraccion, particulas_atraccion_2, particulas_atraccion_3, particulas_hojas, particulas_hojas_2]:
		if is_instance_valid(p):
			p.local_coords = true
			p.ignore_occlusion_culling = true

	# El embudo es transparente y rota: no debe desaparecer por un AABB de
	# oclusión opaco ni por una estimación de culling demasiado ajustada.
	if is_instance_valid(embudo_vortice):
		embudo_vortice.ignore_occlusion_culling = true
		embudo_vortice.extra_cull_margin = 4.0

	if not mostrar_hojas:
		if is_instance_valid(particulas_hojas):
			particulas_hojas.visible = false
			particulas_hojas.emitting = false
		if is_instance_valid(particulas_hojas_2):
			particulas_hojas_2.visible = false
			particulas_hojas_2.emitting = false

	if Engine.is_editor_hint():
		return
	_configurar_areas()
	_inicializar_disparadores()

func _guardar_datos_base() -> void:
	if _datos_base_guardados:
		return
	_datos_base_guardados = true

	_particulas_todas = [
		particulas_vortice,
		particulas_atraccion,
		particulas_atraccion_2,
		particulas_atraccion_3,
		particulas_hojas,
		particulas_hojas_2
	]

	for p in _particulas_todas:
		if is_instance_valid(p):
			_angulos_particulas[p] = p.rotation.y
			_datos_base_particulas[p] = {
				"amount": p.amount,
				"emission_ring_height": p.emission_ring_height,
				"emission_ring_radius": p.emission_ring_radius,
				"emission_ring_inner_radius": p.emission_ring_inner_radius,
				"gravity": p.gravity,
				"initial_velocity_min": p.initial_velocity_min,
				"initial_velocity_max": p.initial_velocity_max,
				"tangential_accel_min": p.tangential_accel_min,
				"tangential_accel_max": p.tangential_accel_max,
				"lifetime": p.lifetime,
			}

	if is_instance_valid(luz_nucleo):
		_base_luz_range = luz_nucleo.omni_range
	if is_instance_valid(modelo_visual):
		_base_visual_pos_y = modelo_visual.position.y

func _actualizar_adaptacion_escala(_forzar: bool = false) -> void:
	if not _datos_base_guardados:
		_guardar_datos_base()

	var sx = maxf(0.01, absf(scale.x))
	var sy = maxf(0.01, absf(scale.y))
	var sz = maxf(0.01, absf(scale.z))
	var s_horiz = (sx + sz) * 0.5

	# 1. Adaptar Visual y Embudo para mantener simetría circular perfecta en X y Z
	if is_instance_valid(modelo_visual):
		modelo_visual.scale = Vector3(s_horiz / sx, 1.0, s_horiz / sz)

	if is_instance_valid(embudo_vortice):
		embudo_vortice.set_instance_shader_parameter("escala_y", sy)
		embudo_vortice.set_instance_shader_parameter("escala_xz", s_horiz)
		embudo_vortice.extra_cull_margin = 4.0 * maxf(s_horiz, sy)

	# 2. Factor de creación de partículas proporcional a la superficie del vórtice
	var factor_creacion = maxf(0.35, s_horiz * clampf(sy, 0.5, 4.0))
	var factor_v = clampf(sqrt(sy), 0.5, 3.0)

	# 3. Adaptar cada sistema de partículas
	var p_scale = Vector3(1.0 / sx, 1.0 / sy, 1.0 / sz)
	for p in _particulas_todas:
		if not is_instance_valid(p) or not _datos_base_particulas.has(p):
			continue
		var base_data: Dictionary = _datos_base_particulas[p]

		# Neutralizar escala para que las mallas/hojas/rocas mantengan su tamaño y aspecto original
		p.scale = p_scale

		# Expandir la forma de emisión hacia donde se está escalando
		p.emission_ring_height = base_data["emission_ring_height"] * sy
		p.emission_ring_radius = base_data["emission_ring_radius"] * s_horiz
		p.emission_ring_inner_radius = base_data["emission_ring_inner_radius"] * s_horiz

		# Generar más partículas ("crearse más hacia donde está escalándose")
		var nuevo_amount = clampi(roundi(float(base_data["amount"]) * factor_creacion), 1, 100)
		if p.amount != nuevo_amount:
			p.amount = nuevo_amount

		# Dinámica: velocidad y tiempo de vida para que alcancen la cima y giren adecuadamente
		p.lifetime = float(base_data["lifetime"]) * factor_v
		var grav: Vector3 = base_data["gravity"]
		p.gravity = Vector3(grav.x, grav.y * factor_v, grav.z)
		p.initial_velocity_min = float(base_data["initial_velocity_min"]) * factor_v
		p.initial_velocity_max = float(base_data["initial_velocity_max"]) * factor_v
		p.tangential_accel_min = float(base_data["tangential_accel_min"]) * clampf(s_horiz, 0.5, 4.0)
		p.tangential_accel_max = float(base_data["tangential_accel_max"]) * clampf(s_horiz, 0.5, 4.0)

		# AABB de visibilidad ampliada
		var ext_r = p.emission_ring_radius + 4.0
		var ext_h = p.emission_ring_height + 4.0
		p.visibility_aabb = AABB(Vector3(-ext_r, -2.0, -ext_r), Vector3(ext_r * 2.0, ext_h + 4.0, ext_r * 2.0))
		p.extra_cull_margin = 4.0 * maxf(s_horiz, sy)

	# 4. Adaptar áreas físicas de colisión
	if is_instance_valid(area_influencia):
		area_influencia.scale = p_scale
		var col = area_influencia.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if is_instance_valid(col) and col.shape is CylinderShape3D:
			if not col.shape.has_meta("es_copia_escala"):
				col.shape = col.shape.duplicate()
				col.shape.set_meta("es_copia_escala", true)
			col.shape.radius = radio_influencia * s_horiz
			col.shape.height = maxf(altura_tornado * sy * 1.5, 8.0 * sy)

	if is_instance_valid(area_absorcion):
		area_absorcion.scale = p_scale
		var col = area_absorcion.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if is_instance_valid(col) and col.shape is CylinderShape3D:
			if not col.shape.has_meta("es_copia_escala"):
				col.shape = col.shape.duplicate()
				col.shape.set_meta("es_copia_escala", true)
			col.shape.radius = radio_nucleo * s_horiz
			col.shape.height = maxf(altura_tornado * sy * 0.9, 4.8 * sy)

	# 5. Adaptar luz omnidireccional
	if is_instance_valid(luz_nucleo):
		luz_nucleo.scale = p_scale
		luz_nucleo.omni_range = _base_luz_range * maxf(s_horiz, sy * 0.7)

func _configurar_areas() -> void:
	# Máscara de detección: Capa 3 (Fantasma = bit 2), Capa 2 (Vivo = bit 1)
	var mascara = (1 << 2)
	if not afecta_solo_fantasmas:
		mascara |= (1 << 1)

	if is_instance_valid(area_influencia):
		area_influencia.collision_layer = 0
		area_influencia.collision_mask = mascara
		if not area_influencia.body_entered.is_connected(_on_influencia_body_entered):
			area_influencia.body_entered.connect(_on_influencia_body_entered)
		if not area_influencia.body_exited.is_connected(_on_influencia_body_exited):
			area_influencia.body_exited.connect(_on_influencia_body_exited)

	if is_instance_valid(area_absorcion):
		area_absorcion.collision_layer = 0
		area_absorcion.collision_mask = mascara
		if not area_absorcion.body_entered.is_connected(_on_absorcion_body_entered):
			area_absorcion.body_entered.connect(_on_absorcion_body_entered)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_procesar_movimiento_patrulla(delta)
	_procesar_succion_continua(delta)

func _procesar_movimiento_patrulla(delta: float) -> void:
	if _tiene_disparadores:
		return
	if not se_mueve or desplazamiento == Vector3.ZERO:
		return

	if _timer_espera > 0.0:
		_timer_espera -= delta
		return

	var dist_total = desplazamiento.length()
	if dist_total <= 0.001:
		return

	var paso = (velocidad_movimiento / dist_total) * delta
	_progreso_patrulla += paso * _direccion_patrulla

	if _progreso_patrulla >= 1.0:
		_progreso_patrulla = 1.0
		_direccion_patrulla = -1.0
		_timer_espera = tiempo_espera_extremos
	elif _progreso_patrulla <= 0.0:
		_progreso_patrulla = 0.0
		_direccion_patrulla = 1.0
		_timer_espera = tiempo_espera_extremos

	var factor_t = _progreso_patrulla
	if movimiento_suave:
		factor_t = (1.0 - cos(_progreso_patrulla * PI)) * 0.5

	position = _pos_inicial_mov + (desplazamiento * factor_t)

func _process(delta: float) -> void:
	_tiempo_acumulado += delta
	if typeof(_escala_previa) != TYPE_VECTOR3:
		_escala_previa = scale
		_actualizar_adaptacion_escala()
	elif not scale.is_equal_approx(_escala_previa):
		_actualizar_adaptacion_escala()
		_escala_previa = scale
	_animar_visuales(delta)

func _animar_visuales(delta: float) -> void:
	var sx = maxf(0.01, absf(scale.x))
	var sy = maxf(0.01, absf(scale.y))
	var sz = maxf(0.01, absf(scale.z))

	if is_instance_valid(modelo_visual):
		modelo_visual.rotate_y(-deg_to_rad(velocidad_rotacion_visual * delta))
		# Flotación suave vertical del torbellino
		var offset_y = sin(_tiempo_acumulado * frecuencia_oscilacion) * oscilacion_altura
		modelo_visual.position.y = _base_visual_pos_y + offset_y

	var vel_giro_base = -deg_to_rad(velocidad_rotacion_visual * delta)
	var p_scale = Vector3(1.0 / sx, 1.0 / sy, 1.0 / sz)
	_rotar_sistema_particulas(particulas_vortice, vel_giro_base * 0.95, p_scale)
	_rotar_sistema_particulas(particulas_atraccion, vel_giro_base * 0.75, p_scale)
	_rotar_sistema_particulas(particulas_atraccion_2, vel_giro_base * 0.65, p_scale)
	_rotar_sistema_particulas(particulas_atraccion_3, vel_giro_base * 0.85, p_scale)
	_rotar_sistema_particulas(particulas_hojas, vel_giro_base * 1.15, p_scale)
	_rotar_sistema_particulas(particulas_hojas_2, vel_giro_base * 0.92, p_scale)

	if is_instance_valid(luz_nucleo):
		if not luz_nucleo.has_meta("energia_base"):
			luz_nucleo.set_meta("energia_base", luz_nucleo.light_energy)
		var energia_base: float = luz_nucleo.get_meta("energia_base")
		var pulso = 0.85 + 0.25 * sin(_tiempo_acumulado * 3.5)
		luz_nucleo.light_energy = energia_base * pulso

func _rotar_sistema_particulas(p: CPUParticles3D, delta_rad: float, p_scale: Vector3) -> void:
	if not is_instance_valid(p):
		return
	var angulo = _angulos_particulas.get(p, p.rotation.y) + delta_rad
	_angulos_particulas[p] = angulo
	p.transform.basis = Basis(Vector3.UP, angulo).scaled(p_scale)

func _procesar_succion_continua(_delta: float) -> void:
	for i in range(_cuerpos_en_influencia.size() - 1, -1, -1):
		var cuerpo = _cuerpos_en_influencia[i]
		if not is_instance_valid(cuerpo) or not cuerpo.is_inside_tree():
			_cuerpos_en_influencia.remove_at(i)
			continue

		# Si el personaje ya fue completamente absorbido, el cono interior maneja su órbita
		if cuerpo.has_method("esta_absorbido_en_vortice") and cuerpo.esta_absorbido_en_vortice():
			continue

		var pos_cuerpo = cuerpo.global_position
		var delta_pos = global_position - pos_cuerpo
		var dist_horizontal = Vector2(delta_pos.x, delta_pos.z).length()

		if dist_horizontal <= 0.01:
			continue

		var s_horiz = (absf(scale.x) + absf(scale.z)) * 0.5
		var radio_efectivo = radio_influencia * s_horiz
		var factor_distancia = 1.0 - clampf(dist_horizontal / radio_efectivo, 0.0, 1.0)
		# Suavizar curva de atracción garantizando una fuerza base efectiva en todo el radio de influencia
		var factor_succion = lerpf(0.35, 1.0, factor_distancia)

		# 1. Fuerza radial centrípeta (atrae directamente hacia el centro)
		var dir_radial = Vector3(delta_pos.x, 0.0, delta_pos.z).normalized()
		var fuerza_radial = dir_radial * (fuerza_succion_horizontal * factor_succion)

		# 2. Fuerza tangencial circular (arremolina al personaje en sentido horario)
		var dir_tangencial = Vector3(dir_radial.z, 0.0, -dir_radial.x)
		var fuerza_tangencial = dir_tangencial * (fuerza_giro_tangencial * factor_succion)

		# 3. Arrastre hacia abajo (cancela o acelera la levitación suave)
		var arrastre_y = fuerza_arrastre_vertical * (0.5 + factor_succion * 0.5)

		if cuerpo.has_method("aplicar_fuerza_vortice"):
			cuerpo.aplicar_fuerza_vortice(fuerza_radial + fuerza_tangencial, arrastre_y)
			fantasma_atraido.emit(cuerpo)
			
			# Vibración de viento y succión proporcional a la cercanía del jugador activo
			var es_activo = cuerpo.has_method("es_activo") and cuerpo.es_activo()
			if es_activo:
				var vib = _get_vibration_manager()
				if is_instance_valid(vib):
					vib.actualizar_succion_torbellino(factor_distancia)

func _on_influencia_body_entered(body: Node3D) -> void:
	if not _es_candidato_valido(body):
		return
	if body is CharacterBody3D and not _cuerpos_en_influencia.has(body):
		_cuerpos_en_influencia.append(body)

func _on_influencia_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		_cuerpos_en_influencia.erase(body)
		if body.has_method("es_activo") and body.es_activo():
			var vib = _get_vibration_manager()
			if is_instance_valid(vib):
				vib.detener_succion_torbellino()

func _exit_tree() -> void:
	var vib = _get_vibration_manager()
	if is_instance_valid(vib):
		vib.detener_succion_torbellino()
		if vib.has_method("detener_vibracion_puerta"):
			vib.detener_vibracion_puerta("torbellino_" + str(get_instance_id()), false)

func _get_vibration_manager() -> Node:
	if Engine.is_editor_hint() or not is_inside_tree():
		return null
	return get_node_or_null("/root/VibrationManager")

func _on_absorcion_body_entered(body: Node3D) -> void:
	if not _es_candidato_valido(body):
		return

	if es_letal_al_contacto:
		if body.has_method("reaparecer"):
			body.reaparecer()
			return
		elif "posicion_inicial" in body:
			body.global_position = body.posicion_inicial
			body.velocity = Vector3.ZERO
			return

	if body.has_method("ser_absorbido_en_vortice"):
		if body.has_method("esta_absorbido_en_vortice") and body.esta_absorbido_en_vortice():
			return

		# Calcular impulso de expulsión hacia abajo con fuerza y hacia los lados al salir
		var dir_horizontal = body.global_position - global_position
		dir_horizontal.y = 0.0
		if dir_horizontal.is_zero_approx():
			dir_horizontal = -global_transform.basis.z
		else:
			dir_horizontal = dir_horizontal.normalized()
		var impulso_salida = (dir_horizontal * fuerza_expulsion_horizontal) + (Vector3.DOWN * absf(fuerza_expulsion_vertical))

		if body.has_signal("fantasma_expulsado_de_vortice"):
			body.connect("fantasma_expulsado_de_vortice", func(_imp): fantasma_expulsado.emit(body), CONNECT_ONE_SHOT)


		var altura_real = altura_tornado * global_basis.get_scale().y
		body.ser_absorbido_en_vortice(global_position, duracion_absorcion, impulso_salida, self, altura_real)
		fantasma_absorbido.emit(body)
		_disparar_efecto_absorcion()

func _disparar_efecto_absorcion() -> void:
	var vib = _get_vibration_manager()
	if is_instance_valid(vib) and vib.has_method("vibrar_dano"):
		vib.vibrar_dano()
	if is_instance_valid(luz_nucleo):
		var tween = create_tween()
		tween.tween_property(luz_nucleo, "light_energy", 4.0, 0.15)
		tween.tween_property(luz_nucleo, "light_energy", 1.6, 0.4)


func _es_candidato_valido(nodo: Node) -> bool:
	if not (nodo is CharacterBody3D):
		return false
	if afecta_solo_fantasmas:
		return nodo.is_in_group("fantasmas") or nodo.name.to_lower().contains("fantasma")
	return nodo.is_in_group("jugadores")


func _resolver_nodo(valor: Variant) -> Node3D:
	if valor == null:
		return null
	if valor is Node3D:
		return valor
	if valor is NodePath and not valor.is_empty():
		return get_node_or_null(valor) as Node3D
	return null


func _inicializar_disparadores() -> void:
	_disparadores_resueltos.clear()
	_estados_disparadores.clear()

	var disp_unico: Node3D = _resolver_nodo(disparador_objetivo)
	if disp_unico != null:
		_disparadores_resueltos.append(disp_unico)

	for d in disparadores_objetivo:
		var nodo_d: Node3D = _resolver_nodo(d)
		if nodo_d != null and not _disparadores_resueltos.has(nodo_d):
			_disparadores_resueltos.append(nodo_d)

	for disp in _disparadores_resueltos:
		_estados_disparadores[disp] = false
		var cb_activado := Callable(self, "_on_disparador_estado_cambiado").bind(disp, true)
		var cb_desactivado := Callable(self, "_on_disparador_estado_cambiado").bind(disp, false)
		if disp.has_signal("signal_activado") and not disp.is_connected("signal_activado", cb_activado):
			disp.connect("signal_activado", cb_activado)
		if disp.has_signal("signal_desactivado") and not disp.is_connected("signal_desactivado", cb_desactivado):
			disp.connect("signal_desactivado", cb_desactivado)

	_tiene_disparadores = not _disparadores_resueltos.is_empty()


func _on_disparador_estado_cambiado(disparador: Node3D, nuevo_estado: bool) -> void:
	_estados_disparadores[disparador] = nuevo_estado
	_evaluar_estado_mecanismo()


func _evaluar_estado_mecanismo() -> void:
	if _estados_disparadores.is_empty():
		return

	var resultado: bool = false
	if condicion_combinacion == ElementoInteractivoBase.CondicionCombinacion.CONDICION_O:
		for estado in _estados_disparadores.values():
			if estado == true:
				resultado = true
				break
	elif condicion_combinacion == ElementoInteractivoBase.CondicionCombinacion.CONDICION_Y:
		resultado = true
		for estado in _estados_disparadores.values():
			if estado == false:
				resultado = false
				break

	if resultado != _mecanismo_activo:
		_mecanismo_activo = resultado
		if is_inside_tree() and multiplayer and multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) and multiplayer.get_peers().size() > 0:
			rpc_sincronizar_estado.rpc(_mecanismo_activo)
		else:
			rpc_sincronizar_estado(_mecanismo_activo)


@rpc("any_peer", "call_local", "reliable")
func rpc_sincronizar_estado(activo: bool) -> void:
	_mecanismo_activo = activo
	actualizar_comportamiento(activo)


func _calcular_factor_proximidad_jugador() -> float:
	if not is_inside_tree():
		return 0.0
	var distancia_min: float = 999.0
	for pj in get_tree().get_nodes_in_group("jugadores"):
		if pj is Node3D:
			var es_activo: bool = pj.has_method("es_activo") and pj.es_activo()
			var d: float = global_position.distance_to(pj.global_position)
			if es_activo:
				distancia_min = minf(distancia_min, d)
			elif distancia_min > 50.0:
				distancia_min = minf(distancia_min, d)
	if distancia_min > 24.0:
		return 0.0
	return clampf(1.0 - ((distancia_min - 5.0) / 19.0), 0.15, 1.0)


func actualizar_comportamiento(activo: bool) -> void:
	if _tween_mecanismo and _tween_mecanismo.is_valid():
		_tween_mecanismo.kill()

	var posicion_objetivo: Vector3 = _pos_inicial_mov
	if activo:
		var dir_norm: Vector3 = direccion_desplazamiento.normalized() if not direccion_desplazamiento.is_zero_approx() else Vector3.RIGHT
		posicion_objetivo = _pos_inicial_mov + (dir_norm * distancia_desplazamiento)

	var vib: Node = _get_vibration_manager()
	var id_mecanismo: String = "torbellino_" + str(get_instance_id())
	var factor_prox: float = _calcular_factor_proximidad_jugador()
	if factor_prox > 0.0 and is_instance_valid(vib) and vib.has_method("iniciar_vibracion_puerta"):
		vib.iniciar_vibracion_puerta(id_mecanismo, tiempo_transicion, factor_prox)

	if not is_inside_tree():
		position = posicion_objetivo
		return

	_tween_mecanismo = create_tween()
	_tween_mecanismo.set_ease(Tween.EASE_OUT)
	_tween_mecanismo.set_trans(Tween.TRANS_QUAD)
	_tween_mecanismo.tween_property(self, "position", posicion_objetivo, tiempo_transicion)
	_tween_mecanismo.finished.connect(func():
		var vib_fin: Node = _get_vibration_manager()
		if is_instance_valid(vib_fin) and vib_fin.has_method("detener_vibracion_puerta"):
			vib_fin.detener_vibracion_puerta(id_mecanismo, true, factor_prox)
	)
