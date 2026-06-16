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

@onready var mesh_visual = get_parent().get_node_or_null("Aura")

func _process(delta):
	if not is_multiplayer_authority(): return

	if cooldown_actual > 0:
		cooldown_actual = max(cooldown_actual - delta, 0.0)
		estado_cambiado.emit(false, 1.0 - (cooldown_actual / tiempo_recarga))

	if activa:
		radio_actual -= velocidad_encogimiento * delta
		_actualizar_visual()
		radio_actualizado.emit(radio_actual)

		if radio_actual <= 0:
			desactivar()

func intentar_activar():
	if activa or cooldown_actual > 0: return

	activa = true
	radio_actual = radio_maximo
	if mesh_visual:
		mesh_visual.visible = true
	estado_cambiado.emit(true, 0.0)
	radio_actualizado.emit(radio_actual)

func desactivar():
	activa = false
	radio_actual = 0.0
	cooldown_actual = tiempo_recarga
	if mesh_visual:
		mesh_visual.visible = false
	estado_cambiado.emit(false, 0.0)
	radio_actualizado.emit(radio_actual)

func _actualizar_visual():
	if mesh_visual:
		mesh_visual.scale = Vector3(radio_actual, 1.0, radio_actual)

func esta_activa() -> bool:
	return activa

func obtener_radio() -> float:
	return radio_actual
