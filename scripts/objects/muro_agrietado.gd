extends StaticBody3D
class_name MuroAgrietado

# Muro Agrietado Destructible — Bloqueo físico que puede ser roto por el Embate del Vivo.
# Al recibir un impacto con la habilidad de golpe/embate, se fractura y desaparece
# expulsando partículas de escombros de roca. Sincronizado por RPC en red.

signal signal_destruido

@export_group("Resistencia del Muro")
@export var golpes_requeridos: int = 1
@export var auto_reaparicion: bool = false
@export var tiempo_reaparicion: float = 10.0

@onready var colision: CollisionShape3D = get_node_or_null("CollisionShape3D")
@onready var mesh_muro: MeshInstance3D = get_node_or_null("MeshInstance3D")
@onready var particulas_escombros: CPUParticles3D = get_node_or_null("ParticulasEscombros")
@onready var luz_grieta: OmniLight3D = get_node_or_null("LuzGrieta")

var _golpes_actuales: int = 0
var _esta_destruido: bool = false
var _timer_respawn: float = 0.0

func _ready() -> void:
	# Capa 1: Estructura Global (bloquea a todos mientras exista)
	collision_layer = 1
	collision_mask = 1 | (1 << 1) | (1 << 2)
	add_to_group("muros_agrietados")

func _process(delta: float) -> void:
	if auto_reaparicion and _esta_destruido:
		_timer_respawn -= delta
		if _timer_respawn <= 0.0:
			restaurar()

func recibir_impacto(personaje: Node) -> void:
	if _esta_destruido:
		return
		
	_golpes_actuales += 1
	if _golpes_actuales >= golpes_requeridos:
		if multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
			rpc("rpc_destruir_muro")
		else:
			_ejecutar_destruccion()

@rpc("any_peer", "call_local", "reliable")
func rpc_destruir_muro() -> void:
	_ejecutar_destruccion()

func _ejecutar_destruccion() -> void:
	if _esta_destruido:
		return
	_esta_destruido = true
	
	if is_instance_valid(colision):
		colision.set_deferred("disabled", true)
	if is_instance_valid(mesh_muro):
		mesh_muro.visible = false
	if is_instance_valid(luz_grieta):
		luz_grieta.visible = false
		
	if is_instance_valid(particulas_escombros):
		particulas_escombros.restart()
		particulas_escombros.emitting = true
		
	signal_destruido.emit()
	print("[MuroAgrietado] '%s' ¡DESTRUIDO por embate físico!" % name)
	
	if auto_reaparicion:
		_timer_respawn = tiempo_reaparicion

func restaurar() -> void:
	_esta_destruido = false
	_golpes_actuales = 0
	if is_instance_valid(colision):
		colision.set_deferred("disabled", false)
	if is_instance_valid(mesh_muro):
		mesh_muro.visible = true
	if is_instance_valid(luz_grieta):
		luz_grieta.visible = true
	print("[MuroAgrietado] '%s' Restaurado." % name)
