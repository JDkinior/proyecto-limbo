extends Area3D
class_name PalancaInteractiva

# Palanca Interactiva Física — Mecanismo para el Jugador Vivo.
# Al acercarse y presionar el botón de interactuar, la palanca se acciona.
# Soporta modo conmutador (On/Off) y modo temporizado (retorna sola tras X segundos).
# Emite 'signal_activado' y 'signal_desactivado' para conectarse a puertas, plataformas, etc.

signal signal_activado
signal signal_desactivado
signal signal_estado_cambiado(activo: bool)

@export_group("Configuración de Palanca")
@export var esta_activa: bool = false
@export var es_temporizada: bool = false
@export var tiempo_retorno: float = 4.0
@export var angulo_inactivo: float = -35.0 # Grados
@export var angulo_activo: float = 35.0    # Grados

@onready var nodo_mango: Node3D = get_node_or_null("Mango")
@onready var luz_indicador: OmniLight3D = get_node_or_null("LuzIndicador")

var _jugador_cerca: Node = null
var _tween_mango: Tween = null
var _timer_retorno: float = 0.0

const COLOR_ACTIVO := Color(0.2, 0.95, 0.4, 1.0)
const COLOR_INACTIVO := Color(0.85, 0.3, 0.1, 1.0)

func _ready() -> void:
	# Detección del Jugador Vivo (Capa 2)
	collision_layer = 0
	collision_mask = 1 << 1
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	add_to_group("mecanismos_interactivos")
	
	_actualizar_visual(esta_activa, false)

func _process(delta: float) -> void:
	if es_temporizada and esta_activa:
		_timer_retorno -= delta
		if _timer_retorno <= 0.0:
			_set_estado(false)

func _on_body_entered(body: Node) -> void:
	if body is Jugador:
		_jugador_cerca = body
		if body.has_method("registrar_mecanismo_cercano"):
			body.registrar_mecanismo_cercano(self)

func _on_body_exited(body: Node) -> void:
	if body == _jugador_cerca:
		if _jugador_cerca.has_method("desregistrar_mecanismo_cercano"):
			_jugador_cerca.desregistrar_mecanismo_cercano(self)
		_jugador_cerca = null

func intentar_interactuar(personaje: Node) -> bool:
	if not is_instance_valid(personaje):
		return false
		
	var nuevo_estado = not esta_activa
	if multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		rpc("rpc_sincronizar_palanca", nuevo_estado)
	else:
		_set_estado(nuevo_estado)
	return true

@rpc("any_peer", "call_local", "reliable")
func rpc_sincronizar_palanca(nuevo_estado: bool) -> void:
	_set_estado(nuevo_estado)

func _set_estado(activo: bool) -> void:
	if esta_activa == activo:
		return
	esta_activa = activo
	if is_instance_valid(VibrationManager):
		VibrationManager.vibrar_mecanismo()
	if es_temporizada and esta_activa:
		_timer_retorno = tiempo_retorno
		
	_actualizar_visual(esta_activa, true)
	
	signal_estado_cambiado.emit(esta_activa)
	if esta_activa:
		signal_activado.emit()
		print("[PalancaInteractiva] '%s' ACTIVADA" % name)
	else:
		signal_desactivado.emit()
		print("[PalancaInteractiva] '%s' DESACTIVADA" % name)

func _actualizar_visual(activo: bool, con_animacion: bool) -> void:
	var angulo_target = angulo_activo if activo else angulo_inactivo
	var rad_target = deg_to_rad(angulo_target)
	
	if is_instance_valid(nodo_mango):
		if con_animacion:
			if _tween_mango and _tween_mango.is_valid():
				_tween_mango.kill()
			_tween_mango = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_tween_mango.tween_property(nodo_mango, "rotation:x", rad_target, 0.25)
		else:
			nodo_mango.rotation.x = rad_target
			
	if is_instance_valid(luz_indicador):
		luz_indicador.light_color = COLOR_ACTIVO if activo else COLOR_INACTIVO
		luz_indicador.light_energy = 2.0 if activo else 0.8
