extends Area3D

# Goal object: termina el nivel al ser tocado por el Jugador.
# Puedes colocar una escena de este tipo en el nivel y asignar la ruta del
# siguiente nivel en la exportación `next_scene_path`.

# Goal object: termina el nivel al ser tocado por ambos personajes simultáneamente.
# Exporta la ruta de la siguiente escena. Cambia este valor en el inspector o en tiempo de ejecución.
@export var next_scene_path: String = "res://scenes/levels/mundo_pruebas.tscn"

# Conjunto de cuerpos actualmente dentro del área.
var _cuerpos_dentro: Array = []

func _ready() -> void:
	# Goal pertenece a la capa 4 (Objetivo/Moneda) y detecta capas 2 y 3 (Jugadores)
	collision_layer = 1 << 3
	collision_mask = (1 << 1) | (1 << 2)  # layers 2 and 3
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if not (body is CharacterBase):
		return
	if body not in _cuerpos_dentro:
		_cuerpos_dentro.append(body)
	_verificar_activacion()

func _on_body_exited(body: Node) -> void:
	if body in _cuerpos_dentro:
		_cuerpos_dentro.erase(body)

@rpc("any_peer", "call_local", "reliable")
func rpc_change_scene(path: String) -> void:
	print("[Goal] Cambiando escena en todos los peers a: ", path)
	get_tree().change_scene_to_file(path)



func _verificar_activacion() -> void:
	if not is_multiplayer_authority():
		return
	var tiene_jugador = false
	var tiene_fantasma = false
	for c in _cuerpos_dentro:
		if c is Jugador:
			tiene_jugador = true
		elif c is Fantasma:
			tiene_fantasma = true
	if tiene_jugador and tiene_fantasma:
		print("[Goal] Ambos personajes dentro – Nivel completado, cambiando a: ", next_scene_path)
		rpc("rpc_change_scene", next_scene_path)
