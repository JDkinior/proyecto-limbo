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
@export var fuerza_succion_horizontal: float = 8.5
@export var fuerza_giro_tangencial: float = 9.0
@export var fuerza_arrastre_vertical: float = 9.5
@export var afecta_solo_fantasmas: bool = true

@export_group("Absorción y Núcleo")
@export var radio_nucleo: float = 1.3
@export var duracion_absorcion: float = 1.0
@export var fuerza_expulsion_horizontal: float = 6.5
@export var fuerza_expulsion_vertical: float = -8.0
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

@onready var area_influencia: Area3D = get_node_or_null("AreaInfluencia")
@onready var area_absorcion: Area3D = get_node_or_null("AreaAbsorcion")
@onready var modelo_visual: Node3D = get_node_or_null("Visual")
@onready var luz_nucleo: OmniLight3D = get_node_or_null("LuzTorbellino")
@onready var particulas_vortice: CPUParticles3D = get_node_or_null("ParticulasVortice")

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

	if is_instance_valid(luz_nucleo):
		var pulso = 0.8 + 0.25 * sin(_tiempo_acumulado * 4.0)
		luz_nucleo.light_energy = 1.6 * pulso

func _procesar_succion_continua(_delta: float) -> void:
	for i in range(_cuerpos_en_influencia.size() - 1, -1, -1):
		var cuerpo = _cuerpos_en_influencia[i]
		if not is_instance_valid(cuerpo) or not cuerpo.is_inside_tree():
			_cuerpos_en_influencia.remove_at(i)
			continue

		# Si el personaje ya fue completamente absorbido, el núcleo maneja su órbita
		if cuerpo.has_method("esta_absorbido_en_vortice") and cuerpo.esta_absorbido_en_vortice():
			continue

		var pos_cuerpo = cuerpo.global_position
		var delta_pos = global_position - pos_cuerpo
		var dist_horizontal = Vector2(delta_pos.x, delta_pos.z).length()

		if dist_horizontal <= 0.01:
			continue

		var factor_distancia = 1.0 - clampf(dist_horizontal / radio_influencia, 0.0, 1.0)
		# Suavizar curva de atracción (más intensa cerca del centro)
		var factor_curva = factor_distancia * factor_distancia

		# 1. Fuerza radial centrípeta (atrae al centro)
		var dir_radial = Vector3(delta_pos.x, 0.0, delta_pos.z).normalized()
		var fuerza_radial = dir_radial * (fuerza_succion_horizontal * factor_curva)

		# 2. Fuerza tangencial circular (arremolina al personaje hacia la derecha / sentido horario)
		var dir_tangencial = Vector3(dir_radial.z, 0.0, -dir_radial.x)
		var fuerza_tangencial = dir_tangencial * (fuerza_giro_tangencial * factor_curva)

		# 3. Arrastre hacia abajo (cancela o acelera la levitación suave)
		var arrastre_y = fuerza_arrastre_vertical * (0.4 + factor_curva * 0.6)

		if cuerpo.has_method("aplicar_fuerza_vortice"):
			cuerpo.aplicar_fuerza_vortice(fuerza_radial + fuerza_tangencial, arrastre_y)
			fantasma_atraido.emit(cuerpo)

func _on_influencia_body_entered(body: Node3D) -> void:
	if not _es_candidato_valido(body):
		return
	if body is CharacterBody3D and not _cuerpos_en_influencia.has(body):
		_cuerpos_en_influencia.append(body)

func _on_influencia_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		_cuerpos_en_influencia.erase(body)

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

		# Calcular impulso de expulsión hacia abajo y en dirección hacia donde iba o alejándose
		var dir_horizontal = body.global_position - global_position
		dir_horizontal.y = 0.0
		if dir_horizontal.is_zero_approx():
			dir_horizontal = -global_transform.basis.z
		else:
			dir_horizontal = dir_horizontal.normalized()
		var impulso_salida = (dir_horizontal * fuerza_expulsion_horizontal) + (Vector3.DOWN * absf(fuerza_expulsion_vertical))

		if body.has_signal("fantasma_expulsado_de_vortice"):
			var on_expulsado: Callable
			on_expulsado = func(_imp):
				fantasma_expulsado.emit(body)
				if is_instance_valid(body) and body.is_connected("fantasma_expulsado_de_vortice", on_expulsado):
					body.disconnect("fantasma_expulsado_de_vortice", on_expulsado)
			body.connect("fantasma_expulsado_de_vortice", on_expulsado)

		body.ser_absorbido_en_vortice(global_position, duracion_absorcion, impulso_salida, self)
		fantasma_absorbido.emit(body)
		_disparar_efecto_absorcion()

func _disparar_efecto_absorcion() -> void:
	if is_instance_valid(luz_nucleo):
		var tween = create_tween()
		tween.tween_property(luz_nucleo, "light_energy", 4.0, 0.15)
		tween.tween_property(luz_nucleo, "light_energy", 1.6, 0.4)

	if is_instance_valid(modelo_visual):
		var tween_malla = create_tween()
		tween_malla.tween_property(modelo_visual, "scale", Vector3(1.25, 1.4, 1.25), 0.15)
		tween_malla.tween_property(modelo_visual, "scale", Vector3.ONE, 0.35)

func _es_candidato_valido(nodo: Node) -> bool:
	if not (nodo is CharacterBody3D):
		return false
	if afecta_solo_fantasmas:
		return nodo.is_in_group("fantasmas") or nodo.name.to_lower().contains("fantasma")
	return nodo.is_in_group("jugadores")
