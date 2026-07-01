extends Area3D

# Moneda para el Jugador Vivo.
# Detecta únicamente al jugador Vivo (Capa 2) y se destruye de forma sincronizada.

@export var value: int = 1
@export var velocidad_rotacion: float = 90.0 # Grados por segundo

func _process(delta: float) -> void:
	rotate_y(deg_to_rad(velocidad_rotacion * delta))

func _ready() -> void:
	# Moneda en Capa 4 (Coleccionables)
	collision_layer = 1 << 3
	
	# Detecta ÚNICAMENTE al jugador Vivo (Capa 2)
	collision_mask = 1 << 1
	
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	# Solo la autoridad del multiplayer o local procesa la recolección
	if not is_multiplayer_authority():
		return
		
	if body is Jugador:
		# Añadir puntuación de forma segura en el ScoreManager
		if is_instance_valid(ScoreManager):
			ScoreManager.add_score_vivo(value)
		else:
			push_warning("[MonedaVivo] ScoreManager no disponible.")
			
		# Sincronizar la eliminación en todos los peers
		rpc("_remover_para_todos")

@rpc("any_peer", "call_local", "reliable")
func _remover_para_todos() -> void:
	queue_free()
