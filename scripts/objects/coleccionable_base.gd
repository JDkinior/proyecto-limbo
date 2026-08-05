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
	# Solo la autoridad del multiplayer procesa la recolección
	if not is_multiplayer_authority():
		return
	
	if _puede_ser_recogido_por(body):
		_aplicar_puntuacion()
		# Sincronizar la eliminación en todos los peers
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
