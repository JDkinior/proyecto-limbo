extends ColeccionableBase

# Moneda / Orbe para el Jugador Fantasma.
# Detecta únicamente al jugador Fantasma (Capa 3) y se destruye de forma sincronizada.
# Configura sus Visual Layers para ser visible únicamente al jugador Fantasma (Capa 3)
# y aplica el ShaderMaterial de energía espiritual.

@export var material_espiritual: Material = preload("res://shaders/material_orbe_espiritual.tres")

func _configurar_colision() -> void:
	add_to_group("monedas_fantasma")
	# Detecta ÚNICAMENTE al jugador Fantasma (Capa 3)
	collision_mask = 1 << 2

func _configurar_visual() -> void:
	# 1. Establece la capa visual del modelo a la Capa 3 (Plano Espiritual, valor de máscara 4)
	# para que el Vivo no la dibuje (su cámara tiene máscara que excluye la Capa 3).
	_configurar_capas_visuales(self, 4)
	# 2. Aplica el ShaderMaterial a todas las mallas del modelo
	_aplicar_material_mallas(self)

func _configurar_capas_visuales(nodo: Node, mascara_capas: int) -> void:
	if nodo is VisualInstance3D:
		nodo.layers = mascara_capas
	for hijo in nodo.get_children():
		_configurar_capas_visuales(hijo, mascara_capas)

func _aplicar_material_mallas(nodo: Node) -> void:
	if nodo is MeshInstance3D and material_espiritual != null:
		nodo.material_override = material_espiritual
	for hijo in nodo.get_children():
		_aplicar_material_mallas(hijo)

func _puede_ser_recogido_por(body: Node) -> bool:
	return body is Fantasma

func _aplicar_puntuacion() -> void:
	if is_instance_valid(ScoreManager):
		ScoreManager.add_score_fantasma(value)
	else:
		push_warning("[MonedaFantasma] ScoreManager no disponible.")
