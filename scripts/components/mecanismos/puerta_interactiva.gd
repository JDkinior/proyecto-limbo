extends ElementoInteractivoBase
class_name PuertaInteractiva

# Puerta Interactiva.
# Al activarse, se desplaza suavemente en la dirección y distancia especificadas,
# y desactiva su colisión. Al desactivarse, regresa y reactiva su colisión.
# Incluye vibración háptica continua durante el movimiento y tope final.

@export_group("Configuración de Movimiento")
@export var distancia_desplazamiento: float = 4.5
@export var direccion_desplazamiento: Vector3 = Vector3.DOWN
@export var tiempo_transicion: float = 1.0

# Referencias Internas (se resuelven automáticamente)
var collision_shape: CollisionShape3D

var posicion_inicial: Vector3
var tween: Tween
var _primera_vez: bool = true

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

func _exit_tree() -> void:
	_detener_vibracion_puerta_actual(false)

func _calcular_factor_proximidad_jugador() -> float:
	var distancia_min = 999.0
	for pj in get_tree().get_nodes_in_group("jugadores"):
		if pj is Node3D:
			var es_activo = pj.has_method("es_activo") and pj.es_activo()
			var d = global_position.distance_to(pj.global_position)
			if es_activo:
				distancia_min = minf(distancia_min, d)
			elif distancia_min > 50.0:
				distancia_min = minf(distancia_min, d)
	
	if distancia_min > 24.0:
		return 0.0 # Fuera del alcance acústico y háptico
	# Menos de 5m: 1.0 (máxima intensidad); a 24m: ~0.15
	return clampf(1.0 - ((distancia_min - 5.0) / 19.0), 0.15, 1.0)

func _detener_vibracion_puerta_actual(con_impacto_final: bool = true, factor: float = 1.0) -> void:
	if is_instance_valid(VibrationManager):
		var id_puerta = "puerta_" + str(get_instance_id())
		VibrationManager.detener_vibracion_puerta(id_puerta, con_impacto_final, factor)

func actualizar_comportamiento(activo: bool) -> void:
	# En el arranque inicial, no reproducir animación ni vibración
	if _primera_vez:
		_primera_vez = false
		if not activo:
			global_position = posicion_inicial
			if is_instance_valid(collision_shape):
				collision_shape.disabled = false
		return

	# Detener animación y vibración previa si existían
	if tween:
		tween.kill()
		_detener_vibracion_puerta_actual(false)
		
	var factor_prox = _calcular_factor_proximidad_jugador()
	var id_puerta = "puerta_" + str(get_instance_id())
	
	# Iniciar vibración háptica continua mientras la puerta se mueve
	if factor_prox > 0.0 and is_instance_valid(VibrationManager):
		VibrationManager.iniciar_vibracion_puerta(id_puerta, tiempo_transicion, factor_prox)
		
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	if activo:
		var target_pos = posicion_inicial + (direccion_desplazamiento.normalized() * distancia_desplazamiento)
		tween.tween_property(self, "global_position", target_pos, tiempo_transicion)
		
		if is_instance_valid(collision_shape):
			collision_shape.disabled = true
	else:
		tween.tween_property(self, "global_position", posicion_inicial, tiempo_transicion)
		
		if is_instance_valid(collision_shape):
			collision_shape.disabled = false

	# Al completar el recorrido: detener rumble continuo y dar golpe/tope sólido de cierre o apertura
	tween.finished.connect(func():
		_detener_vibracion_puerta_actual(true, factor_prox)
	)
