extends "res://scripts/objects/elemento_interactivo_base.gd"
class_name PuertaInteractiva

# Puerta Interactiva.
# Al activarse, se desplaza suavemente en la dirección y distancia especificadas,
# y desactiva su colisión. Al desactivarse, regresa y reactiva su colisión.

@export_group("Configuración de Movimiento")
@export var distancia_desplazamiento: float = 3.0
@export var direccion_desplazamiento: Vector3 = Vector3.DOWN
@export var tiempo_transicion: float = 1.0

# Referencias Internas (se resuelven automáticamente)
var collision_shape: CollisionShape3D

var posicion_inicial: Vector3
var tween: Tween

func _ready() -> void:
	posicion_inicial = global_position
	
	# Fallback si el diseñador no asignó el CollisionShape3D en el inspector
	if not is_instance_valid(collision_shape):
		collision_shape = get_node_or_null("CollisionShape3D")
		if not is_instance_valid(collision_shape):
			# Buscar recursivamente
			for hijo in get_children():
				if hijo is CollisionShape3D:
					collision_shape = hijo
					break
					
	if not is_instance_valid(collision_shape):
		push_error("[%s] ERROR: No se encontró un nodo CollisionShape3D en esta puerta." % name)
		
	# Importante: llamar a super() para conectar el disparador_objetivo
	super()

func actualizar_comportamiento(activo: bool) -> void:
	# Detener animación en progreso si existe
	if tween:
		tween.kill()
		
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	if activo:
		var target_pos = posicion_inicial + (direccion_desplazamiento.normalized() * distancia_desplazamiento)
		# Desplazar suavemente
		tween.tween_property(self, "global_position", target_pos, tiempo_transicion)
		
		# Desactivar colisión inmediatamente (o al finalizar el movimiento, pero inmediatamente es más común para puertas)
		if is_instance_valid(collision_shape):
			collision_shape.disabled = true
	else:
		# Regresar a posición original
		tween.tween_property(self, "global_position", posicion_inicial, tiempo_transicion)
		
		# Reactivar colisión inmediatamente para evitar que el jugador se quede atrapado dentro
		if is_instance_valid(collision_shape):
			collision_shape.disabled = false
