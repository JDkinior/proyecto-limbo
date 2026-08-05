extends ColeccionableBase

# Moneda para el Jugador Vivo.
# Detecta únicamente al jugador Vivo (Capa 2) y se destruye de forma sincronizada.

func _configurar_colision() -> void:
	# Detecta ÚNICAMENTE al jugador Vivo (Capa 2)
	collision_mask = 1 << 1

func _puede_ser_recogido_por(body: Node) -> bool:
	return body is Jugador

func _aplicar_puntuacion() -> void:
	if is_instance_valid(ScoreManager):
		ScoreManager.add_score_vivo(value)
	else:
		push_warning("[MonedaVivo] ScoreManager no disponible.")
