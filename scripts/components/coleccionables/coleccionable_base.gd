extends Area3D
class_name ColeccionableBase

# Clase base para todos los coleccionables (monedas, gemas, orbes, etc.).
# Maneja rotación continua, detección de colisión, estallido omnidireccional de partículas y eliminación sincronizada en red.

@export var value: int = 1
@export var velocidad_rotacion: float = 90.0 # Grados por segundo

var _ya_recogido: bool = false
@onready var _particulas_recoleccion: CPUParticles3D = get_node_or_null("ParticulasRecoleccion")

func _process(delta: float) -> void:
	if not _ya_recogido:
		rotate_y(deg_to_rad(velocidad_rotacion * delta))

func _ready() -> void:
	add_to_group("coleccionables")
	# Coleccionable en Capa 4
	collision_layer = 1 << 3
	_configurar_colision()
	body_entered.connect(_on_body_entered)
	_configurar_visual()

func _configurar_colision() -> void:
	# Sobrescribir en subclases para definir qué capa detecta
	pass

func _configurar_visual() -> void:
	# Sobrescribir en subclases para configurar capas visuales
	pass

func _on_body_entered(body: Node) -> void:
	if _ya_recogido:
		return
	if not _puede_ser_recogido_por(body):
		return
		
	# Predicción del lado del cliente (Client-Side Prediction / Optimistic UI):
	# Si el personaje que tocó la moneda es el que yo controlo (mi autoridad local),
	# ocultamos de inmediato la moneda y disparamos las partículas (0ms de lag).
	if (body.has_method("es_activo") and body.es_activo()) or (body.has_method("is_multiplayer_authority") and body.is_multiplayer_authority()):
		_ejecutar_efecto_recoleccion()
		
	# Solo el Host (o en offline / un jugador) valida oficialmente la puntuación y sincroniza
	if is_multiplayer_authority() or not multiplayer.has_multiplayer_peer() or (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		_aplicar_puntuacion()
		if multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
			rpc("_remover_para_todos")
		else:
			if not _ya_recogido:
				_ejecutar_efecto_recoleccion()

func _ejecutar_efecto_recoleccion() -> void:
	if _ya_recogido:
		return
	_ya_recogido = true
	set_process(false)

	if is_instance_valid(VibrationManager):
		VibrationManager.vibrar_coleccionable()
	
	# Desactivar colisiones de inmediato
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# Ocultar de inmediato el modelo visual y la luz (sin escalas lentas)
	for hijo in get_children():
		if hijo == _particulas_recoleccion or hijo is CollisionShape3D:
			continue
		if hijo is Node3D:
			hijo.hide()
	
	# Disparar estallido instantáneo de partículas en todas las direcciones
	var tiempo_espera: float = 0.5
	if is_instance_valid(_particulas_recoleccion):
		_particulas_recoleccion.restart()
		_particulas_recoleccion.emitting = true
		tiempo_espera = max(0.3, _particulas_recoleccion.lifetime + 0.05)
		
	get_tree().create_timer(tiempo_espera).timeout.connect(queue_free)

func _puede_ser_recogido_por(_body: Node) -> bool:
	# Sobrescribir en subclases para validar quién puede recoger
	return false

func _aplicar_puntuacion() -> void:
	# Sobrescribir en subclases para aplicar puntuación al ScoreManager
	pass

@rpc("any_peer", "call_local", "reliable")
func _remover_para_todos() -> void:
	_ejecutar_efecto_recoleccion()
