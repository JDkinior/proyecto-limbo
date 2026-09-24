extends Area3D
class_name AnclaEstasis

# Ancla de Éxtasis / Congelamiento Espiritual — Habilidad de soporte para el Fantasma.
# Al expandir su Aura mística sobre este objeto, el mecanismo o plataforma asignado
# se congela en el tiempo durante 'duracion_estasis' segundos (pausando movimiento/caída/retornos).
# Emite señales y despliega efectos visuales de escarcha y luz cian.

signal signal_estasis_iniciado(duracion: float)
signal signal_estasis_finalizado

@export_group("Configuración de Éxtasis")
@export var nodo_objetivo: Node3D = null               # Nodo a congelar (si es null, usa el padre)
@export var duracion_estasis: float = 4.5              # Segundos que dura el congelamiento
@export var radio_deteccion: float = 2.0               # Radio de contacto con el aura
@export var congelar_animaciones_tweens: bool = true   # Pausa tweens y animaciones en el objetivo

@onready var particulas_escarcha: CPUParticles3D = get_node_or_null("ParticulasEscarcha")
@onready var luz_estasis: OmniLight3D = get_node_or_null("LuzEstasis")
@onready var cristal_visual: MeshInstance3D = get_node_or_null("CristalVisual")

var esta_congelado: bool = false
var tiempo_restante: float = 0.0
var _fantasma_cache: Node = null
var _posicion_congelada: Vector3 = Vector3.ZERO

const COLOR_ESTASIS := Color(0.2, 0.85, 1.0, 1.0)
const COLOR_REPOSO := Color(0.15, 0.4, 0.6, 0.4)

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	
	if not nodo_objetivo:
		nodo_objetivo = get_parent() as Node3D
		
	add_to_group("anclas_estasis")
	_actualizar_visual(false)

func _obtener_fantasma() -> Node:
	if not is_instance_valid(_fantasma_cache):
		var fantasmas = get_tree().get_nodes_in_group("fantasmas")
		_fantasma_cache = fantasmas[0] if fantasmas.size() > 0 else null
	return _fantasma_cache

func _process(delta: float) -> void:
	# 1. Comprobar si el aura del Fantasma toca el ancla para congelar
	_comprobar_contacto_aura()
	
	# 2. Gestionar temporizador de congelamiento
	if esta_congelado:
		tiempo_restante -= delta
		
		# Mantener posición estricta si está congelado
		if is_instance_valid(nodo_objetivo) and _posicion_congelada != Vector3.ZERO:
			nodo_objetivo.global_position = _posicion_congelada
			
		if tiempo_restante <= 0.0:
			_descongelar()

func _comprobar_contacto_aura() -> void:
	var f = _obtener_fantasma()
	if not is_instance_valid(f):
		return
		
	var aura = f.get_node_or_null("HabilidadAura") as HabilidadAura
	if not aura or not aura.esta_activa():
		return
		
	var dist_horizontal = Vector2(global_position.x - f.global_position.x, global_position.z - f.global_position.z).length()
	var dist_vertical = absf(global_position.y - f.global_position.y)
	var radio_aura = aura.obtener_radio()
	
	# Contacto 3D con el aura esférica del Fantasma
	if dist_horizontal <= (radio_aura + radio_deteccion) and dist_vertical <= (radio_aura * 0.75 + radio_deteccion):
		if not esta_congelado:
			aplicar_estasis(duracion_estasis)

func aplicar_estasis(duracion: float) -> void:
	if multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		rpc("rpc_aplicar_estasis", duracion)
	else:
		_ejecutar_estasis(duracion)

@rpc("any_peer", "call_local", "reliable")
func rpc_aplicar_estasis(duracion: float) -> void:
	_ejecutar_estasis(duracion)

func _ejecutar_estasis(duracion: float) -> void:
	esta_congelado = true
	tiempo_restante = duracion
	
	if is_instance_valid(nodo_objetivo):
		_posicion_congelada = nodo_objetivo.global_position
		
		# Si el nodo objetivo tiene soporte de estasis propio (como Manivela o Plataforma)
		if nodo_objetivo.has_method("congelar_estasis"):
			nodo_objetivo.congelar_estasis(duracion)
			
	_actualizar_visual(true)
	signal_estasis_iniciado.emit(duracion)
	print("[AnclaEstasis] '%s' ¡CONGELADO EN EL TIEMPO por Aura durante %.1fs!" % [name, duracion])

func _descongelar() -> void:
	esta_congelado = false
	_posicion_congelada = Vector3.ZERO
	
	if is_instance_valid(nodo_objetivo) and nodo_objetivo.has_method("descongelar_estasis"):
		nodo_objetivo.descongelar_estasis()
		
	_actualizar_visual(false)
	signal_estasis_finalizado.emit()
	print("[AnclaEstasis] '%s' Descongelado." % name)

func _actualizar_visual(activo: bool) -> void:
	if is_instance_valid(luz_estasis):
		luz_estasis.visible = activo
		luz_estasis.light_color = COLOR_ESTASIS
		luz_estasis.light_energy = 2.5 if activo else 0.0
		
	if is_instance_valid(particulas_escarcha):
		particulas_escarcha.emitting = activo
		
	if is_instance_valid(cristal_visual):
		var mat = cristal_visual.get_surface_override_material(0)
		if not mat:
			mat = StandardMaterial3D.new()
			cristal_visual.set_surface_override_material(0, mat)
		mat.albedo_color = COLOR_ESTASIS if activo else COLOR_REPOSO
		mat.emission_enabled = activo
		mat.emission = COLOR_ESTASIS
		mat.emission_energy_multiplier = 2.0 if activo else 0.0
