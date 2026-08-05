extends Area3D

# Coin collectible for Jugador Vivo (Ruby Coin): increments score_vivo when touched by player.
@export var value: int = 1

func _ready():
	# Coin belongs to layer 4 (Objetivo/Moneda) and watches layer 2 (Jugador Vivo)
	collision_layer = 1 << 3
	collision_mask = 1 << 1  # layer 2 (Jugador Vivo)
	body_entered.connect(_on_body_entered)

@rpc("any_peer", "call_local", "reliable")
func _remover_para_todos() -> void:
	queue_free()

func _on_body_entered(body: Node) -> void:
	if not is_multiplayer_authority():
		return
		
	if body is Jugador or body is CharacterBase:
		if is_instance_valid(ScoreManager):
			ScoreManager.add_score_vivo(value)
		else:
			push_warning("ScoreManager not available.")
			
		rpc("_remover_para_todos")
