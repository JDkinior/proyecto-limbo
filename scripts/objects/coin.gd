extends Area3D

# Coin collectible: increments score when touched by player.
@export var value: int = 1

func _ready():
	# Coin belongs to layer 4 (Objetivo/Moneda) and watches layers 2 and 3 (players)
	collision_layer = 1 << 3
	collision_mask = (1 << 1) | (1 << 2)  # layers 2 and 3
	body_entered.connect(_on_body_entered)

@rpc("any_peer", "call_local", "reliable")
func _remover_para_todos() -> void:
	queue_free()

func _on_body_entered(body: Node) -> void:
	if not is_multiplayer_authority():
		return
	# Check if body is a player character (assumes CharacterBase base class)
	if body is CharacterBase:
		if Engine.has_singleton("ScoreManager"):
			var score_manager = Engine.get_singleton("ScoreManager")
			score_manager.add_score(value)
		else:
			push_warning("ScoreManager singleton not found.")
		# Remove the coin for everyone
		rpc("_remover_para_todos")
		# Also free locally in case RPC latency
		queue_free()
