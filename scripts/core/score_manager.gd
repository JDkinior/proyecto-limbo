extends Node

# Autoload singleton to manage the player's score.
var score: int = 0

signal score_changed(new_score: int)

func add_score(value: int = 1) -> void:
    score += value
    emit_signal("score_changed", score)
    print("[ScoreManager] Score updated: ", score)
