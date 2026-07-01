extends Area3D
class_name BotonPresion

# Botón de Presión Físico.
# Detecta cuerpos de la Capa 2 (Jugador Vivo y Cajas Empujables).
# Emite señales signal_activado y signal_desactivado.

signal signal_activado
signal signal_desactivado

var cuerpos_encima: int = 0

func _ready() -> void:
	# No pertenece a ninguna capa de colisión física (es intangible)
	collision_layer = 0
	
	# Detecta ÚNICAMENTE objetos en Capa 2 (Plano Físico)
	collision_mask = 1 << 1
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	print("[BotonPresion] Inicializado en Capa 0, detectando Capa 2.")

func _on_body_entered(body: Node) -> void:
	cuerpos_encima += 1
	if cuerpos_encima == 1:
		signal_activado.emit()
		print("[BotonPresion] Activado por: ", body.name)

func _on_body_exited(body: Node) -> void:
	cuerpos_encima = max(0, cuerpos_encima - 1)
	if cuerpos_encima == 0:
		signal_desactivado.emit()
		print("[BotonPresion] Desactivado")
