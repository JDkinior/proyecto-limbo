extends Node

# Autoload singleton to manage the player's score.
var score: int = 0
var score_vivo: int = 0
var score_fantasma: int = 0

signal score_changed(new_score: int)
signal score_vivo_changed(new_score: int)
signal score_fantasma_changed(new_score: int)

func add_score(value: int = 1) -> void:
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		rpc("rpc_add_score", value)
	else:
		rpc_add_score(value)

func add_score_vivo(value: int = 1) -> void:
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		rpc("rpc_add_score_vivo", value)
	else:
		rpc_add_score_vivo(value)

func add_score_fantasma(value: int = 1) -> void:
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		rpc("rpc_add_score_fantasma", value)
	else:
		rpc_add_score_fantasma(value)

@rpc("any_peer", "call_local", "reliable")
func rpc_add_score(value: int) -> void:
	score += value
	emit_signal("score_changed", score)
	print("[ScoreManager] Global Score updated: ", score)

@rpc("any_peer", "call_local", "reliable")
func rpc_add_score_vivo(value: int) -> void:
	score_vivo += value
	emit_signal("score_vivo_changed", score_vivo)
	score += value
	emit_signal("score_changed", score)
	print("[ScoreManager] Score Vivo updated: ", score_vivo)

@rpc("any_peer", "call_local", "reliable")
func rpc_add_score_fantasma(value: int) -> void:
	score_fantasma += value
	emit_signal("score_fantasma_changed", score_fantasma)
	score += value
	emit_signal("score_changed", score)
	print("[ScoreManager] Score Fantasma updated: ", score_fantasma)
