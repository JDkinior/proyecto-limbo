extends Area3D
class_name ColeccionableBase

# Clase base para todos los coleccionables (monedas, etc.).
# Maneja rotación, detección de colisión y eliminación sincronizada por red.

@export var value: int = 1
@export var velocidad_rotacion: float = 90.0 # Grados por segundo

func _process(delta: float) -> void:
	rotate_y(deg_to_rad(velocidad_rotacion * delta))

func _ready() -> void:
	# Coleccionable en Capa 4
	collision_layer = 1 << 3
	# Subclases deben establecer collision_mask según el tipo de jugador que lo recoge
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
	if not _puede_ser_recogido_por(body):
		return
		
	# Predicción del lado del cliente (Client-Side Prediction / Optimistic UI):
	# Si el personaje que tocó la moneda es el que yo controlo (mi autoridad local),
	# ocultamos la moneda inmediatamente para que se sienta instantáneo (0 ping visual).
	if body.has_method("is_multiplayer_authority") and body.is_multiplayer_authority():
		hide()
		set_deferred("monitoring", false)
		
	# Solo el Host (Autoridad de la red) valida oficialmente que se recogió
	if is_multiplayer_authority():
		_aplicar_puntuacion()
		rpc("_remover_para_todos")

func _puede_ser_recogido_por(_body: Node) -> bool:
	# Sobrescribir en subclases para validar quién puede recoger
	return false

func _aplicar_puntuacion() -> void:
	# Sobrescribir en subclases para aplicar puntuación al ScoreManager correcto
	pass

@rpc("any_peer", "call_local", "reliable")
func _remover_para_todos() -> void:
	queue_free()
