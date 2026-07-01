extends Area3D

# Moneda para el Jugador Fantasma.
# Detecta únicamente al jugador Fantasma (Capa 3) y se destruye de forma sincronizada.
# Configura sus Visual Layers para ser visible únicamente al jugador Fantasma.

@export var value: int = 1
@export var velocidad_rotacion: float = 90.0 # Grados por segundo

func _process(delta: float) -> void:
	rotate_y(deg_to_rad(velocidad_rotacion * delta))

func _ready() -> void:
	# Moneda en Capa 4 (Coleccionables)
	collision_layer = 1 << 3
	
	# Detecta ÚNICAMENTE al jugador Fantasma (Capa 3)
	collision_mask = 1 << 2
	
	body_entered.connect(_on_body_entered)
	
	# Establece la capa visual del modelo a la Capa 3 (Plano Espiritual, valor de máscara 4)
	# para que el Vivo no la dibuje (su cámara tiene máscara que excluye la Capa 3).
	_configurar_capas_visuales(self, 4)

func _configurar_capas_visuales(nodo: Node, mascara_capas: int) -> void:
	if nodo is VisualInstance3D:
		nodo.layers = mascara_capas
	for hijo in nodo.get_children():
		_configurar_capas_visuales(hijo, mascara_capas)

func _on_body_entered(body: Node) -> void:
	# Solo la autoridad del multiplayer o local procesa la recolección
	if not is_multiplayer_authority():
		return
		
	if body is Fantasma:
		# Añadir puntuación de forma segura en el ScoreManager
		if is_instance_valid(ScoreManager):
			ScoreManager.add_score_fantasma(value)
		else:
			push_warning("[MonedaFantasma] ScoreManager no disponible.")
			
		# Sincronizar la eliminación en todos los peers
		rpc("_remover_para_todos")

@rpc("any_peer", "call_local", "reliable")
func _remover_para_todos() -> void:
	queue_free()
