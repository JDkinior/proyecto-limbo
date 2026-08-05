extends ColeccionableBase

# Moneda para el Jugador Fantasma.
# Detecta únicamente al jugador Fantasma (Capa 3) y se destruye de forma sincronizada.
# Configura sus Visual Layers para ser visible únicamente al jugador Fantasma.

func _configurar_colision() -> void:
	# Detecta ÚNICAMENTE al jugador Fantasma (Capa 3)
	collision_mask = 1 << 2

func _configurar_visual() -> void:
	# Establece la capa visual del modelo a la Capa 3 (Plano Espiritual, valor de máscara 4)
	# para que el Vivo no la dibuje (su cámara tiene máscara que excluye la Capa 3).
	_configurar_capas_visuales(self, 4)

func _configurar_capas_visuales(nodo: Node, mascara_capas: int) -> void:
	if nodo is VisualInstance3D:
		nodo.layers = mascara_capas
	for hijo in nodo.get_children():
		_configurar_capas_visuales(hijo, mascara_capas)

func _puede_ser_recogido_por(body: Node) -> bool:
	return body is Fantasma

func _aplicar_puntuacion() -> void:
	if is_instance_valid(ScoreManager):
		ScoreManager.add_score_fantasma(value)
	else:
		push_warning("[MonedaFantasma] ScoreManager no disponible.")
