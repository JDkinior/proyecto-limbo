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

func _ready() -> void:
	_pos_y_inicial = position.y
	_pos_inicial_mov = position
	
	# Asegurar configuración anti-culling para evitar que las rocas y hojas desaparezcan repentinamente
	for p in [particulas_atraccion, particulas_atraccion_2, particulas_atraccion_3, particulas_hojas, particulas_hojas_2]:
		if is_instance_valid(p):
			p.local_coords = true
			p.ignore_occlusion_culling = true
			p.extra_cull_margin = 4.0
			p.visibility_aabb = AABB(Vector3(-4.0, -4.0, -4.0), Vector3(8.0, 8.0, 8.0))

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
	_animar_visuales(delta)

func _animar_visuales(delta: float) -> void:
	if is_instance_valid(modelo_visual):
		modelo_visual.rotate_y(-deg_to_rad(velocidad_rotacion_visual * delta))
		# Flotación suave vertical del torbellino
		var offset_y = sin(_tiempo_acumulado * frecuencia_oscilacion) * oscilacion_altura
		modelo_visual.position.y = offset_y

	var vel_giro_base = -deg_to_rad(velocidad_rotacion_visual * delta)
	if is_instance_valid(particulas_vortice):
		particulas_vortice.rotate_y(vel_giro_base * 0.95)
	if is_instance_valid(particulas_atraccion):
		particulas_atraccion.rotate_y(vel_giro_base * 0.75)
	if is_instance_valid(particulas_atraccion_2):
		particulas_atraccion_2.rotate_y(vel_giro_base * 0.65)
	if is_instance_valid(particulas_atraccion_3):
		particulas_atraccion_3.rotate_y(vel_giro_base * 0.85)
	if is_instance_valid(particulas_hojas):
		particulas_hojas.rotate_y(vel_giro_base * 1.15)
	if is_instance_valid(particulas_hojas_2):
		particulas_hojas_2.rotate_y(vel_giro_base * 0.92)

	if is_instance_valid(luz_nucleo):
		if not luz_nucleo.has_meta("energia_base"):
			luz_nucleo.set_meta("energia_base", luz_nucleo.light_energy)
		var energia_base: float = luz_nucleo.get_meta("energia_base")
		var pulso = 0.85 + 0.25 * sin(_tiempo_acumulado * 3.5)
		luz_nucleo.light_energy = energia_base * pulso

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

		var factor_distancia = 1.0 - clampf(dist_horizontal / radio_influencia, 0.0, 1.0)
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

func _get_vibration_manager() -> Node:
	if Engine.is_editor_hint():
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
