extends Node3D
class_name HabilidadAura

signal estado_cambiado(activo: bool, progreso_cooldown: float)
signal radio_actualizado(radio: float)

@export var radio_maximo : float = 10.0
@export var velocidad_encogimiento : float = 2.5
@export var tiempo_recarga : float = 4.0

var activa : bool = false
var radio_actual : float = 0.0
var cooldown_actual : float = 0.0

@onready var mesh_visual: MeshInstance3D = get_parent().get_node_or_null("Aura")
@onready var particulas_aura: CPUParticles3D = get_parent().get_node_or_null("Aura/ParticulasAuraMistica")

func _ready():
	if mesh_visual:
		mesh_visual.visible = false
		mesh_visual.scale = Vector3.ZERO
		_configurar_capas_visuales(mesh_visual, 4)
	if is_instance_valid(particulas_aura):
		particulas_aura.emitting = false

func _configurar_capas_visuales(nodo: Node, mascara_capas: int) -> void:
	if nodo is VisualInstance3D:
		nodo.layers = mascara_capas
	for hijo in nodo.get_children():
		_configurar_capas_visuales(hijo, mascara_capas)

func _process(delta: float):
	var es_offline = (multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	var es_local = es_offline or (is_instance_valid(RedManager) and RedManager.es_un_jugador)
	
	# En multijugador online, solo la autoridad del personaje calcula la lógica de física/aura
	if not es_local and not is_multiplayer_authority():
		return

	if cooldown_actual > 0.0:
		cooldown_actual = maxf(cooldown_actual - delta, 0.0)
		var progreso = 1.0 - (cooldown_actual / tiempo_recarga)
		estado_cambiado.emit(false, progreso)
		if cooldown_actual == 0.0:
			estado_cambiado.emit(false, 1.0) # 1.0 = Habilidad totalmente lista

	if activa:
		radio_actual -= velocidad_encogimiento * delta
		_actualizar_visual()
		radio_actualizado.emit(radio_actual)

		if radio_actual <= 0.0:
			desactivar()

func intentar_activar():
	if activa or cooldown_actual > 0.0:
		return

	if multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) and not (is_instance_valid(RedManager) and RedManager.es_un_jugador):
		rpc("rpc_activar_aura")
	else:
		rpc_activar_aura()

@rpc("call_local", "reliable")
func rpc_activar_aura():
	activa = true
	radio_actual = radio_maximo
	if is_instance_valid(mesh_visual):
		mesh_visual.visible = true
		mesh_visual.scale = Vector3(radio_maximo, 1.0, radio_maximo)
	if is_instance_valid(particulas_aura):
		particulas_aura.emitting = true
		particulas_aura.restart()
	estado_cambiado.emit(true, 0.0)
	radio_actualizado.emit(radio_actual)

func desactivar():
	if multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) and not (is_instance_valid(RedManager) and RedManager.es_un_jugador):
		rpc("rpc_desactivar_aura")
	else:
		rpc_desactivar_aura()

@rpc("call_local", "reliable")
func rpc_desactivar_aura():
	activa = false
	radio_actual = 0.0
	cooldown_actual = tiempo_recarga
	if is_instance_valid(mesh_visual):
		mesh_visual.visible = false
		mesh_visual.scale = Vector3.ZERO
	if is_instance_valid(particulas_aura):
		particulas_aura.emitting = false
	estado_cambiado.emit(false, 0.0)
	radio_actualizado.emit(0.0)

func _actualizar_visual():
	if is_instance_valid(mesh_visual):
		mesh_visual.scale = Vector3(radio_actual, 1.0, radio_actual)

func esta_activa() -> bool:
	return activa

func obtener_radio() -> float:
	return radio_actual
