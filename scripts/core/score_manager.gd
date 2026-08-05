extends Node

# Autoload singleton to manage player scores, level timers, and level metrics.
var score: int = 0
var score_vivo: int = 0
var score_fantasma: int = 0

var total_monedas_vivo: int = 0
var total_monedas_fantasma: int = 0

var tiempo_transcurrido: float = 0.0
var tiempo_objetivo: float = 120.0
var cronometro_activo: bool = false

signal score_changed(new_score: int)
signal score_vivo_changed(new_score: int)
signal score_fantasma_changed(new_score: int)
signal tiempo_actualizado(tiempo: float)
signal nivel_iniciado()

enum TipoScore { GLOBAL, VIVO, FANTASMA }

func _process(delta: float) -> void:
	if cronometro_activo:
		tiempo_transcurrido += delta
		tiempo_actualizado.emit(tiempo_transcurrido)

func iniciar_nivel(tiempo_target: float, monedas_vivo: int, monedas_fantasma: int) -> void:
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		rpc("rpc_iniciar_nivel", tiempo_target, monedas_vivo, monedas_fantasma)
	else:
		rpc_iniciar_nivel(tiempo_target, monedas_vivo, monedas_fantasma)

@rpc("any_peer", "call_local", "reliable")
func rpc_iniciar_nivel(tiempo_target: float, monedas_vivo: int, monedas_fantasma: int) -> void:
	score = 0
	score_vivo = 0
	score_fantasma = 0
	total_monedas_vivo = monedas_vivo
	total_monedas_fantasma = monedas_fantasma
	tiempo_transcurrido = 0.0
	tiempo_objetivo = tiempo_target
	cronometro_activo = true
	
	score_vivo_changed.emit(score_vivo)
	score_fantasma_changed.emit(score_fantasma)
	score_changed.emit(score)
	tiempo_actualizado.emit(tiempo_transcurrido)
	nivel_iniciado.emit()
	print("[ScoreManager] Nivel iniciado. Tiempo Objetivo: %.1fs | Monedas Vivo: %d | Monedas Fantasma: %d" % [tiempo_target, monedas_vivo, monedas_fantasma])

func detener_cronometro() -> void:
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		rpc("rpc_detener_cronometro", tiempo_transcurrido)
	else:
		rpc_detener_cronometro(tiempo_transcurrido)

@rpc("any_peer", "call_local", "reliable")
func rpc_detener_cronometro(final_time: float) -> void:
	cronometro_activo = false
	tiempo_transcurrido = final_time
	tiempo_actualizado.emit(tiempo_transcurrido)
	print("[ScoreManager] Cronómetro detenido. Tiempo final: %.2fs" % tiempo_transcurrido)

# --- Métodos de puntuación unificados ---

## Método público: añade puntuación del tipo especificado
func add_score(value: int = 1, tipo: TipoScore = TipoScore.GLOBAL) -> void:
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		rpc("_rpc_add_score", value, tipo)
	else:
		_rpc_add_score(value, tipo)

## Métodos de conveniencia para compatibilidad hacia atrás
func add_score_vivo(value: int = 1) -> void:
	add_score(value, TipoScore.VIVO)

func add_score_fantasma(value: int = 1) -> void:
	add_score(value, TipoScore.FANTASMA)

@rpc("any_peer", "call_local", "reliable")
func _rpc_add_score(value: int, tipo: int) -> void:
	# Siempre actualizar el score global
	score += value
	score_changed.emit(score)
	
	match tipo:
		TipoScore.VIVO:
			score_vivo += value
			score_vivo_changed.emit(score_vivo)
			print("[ScoreManager] Score Vivo updated: ", score_vivo)
		TipoScore.FANTASMA:
			score_fantasma += value
			score_fantasma_changed.emit(score_fantasma)
			print("[ScoreManager] Score Fantasma updated: ", score_fantasma)
		_:
			print("[ScoreManager] Global Score updated: ", score)
