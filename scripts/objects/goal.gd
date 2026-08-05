extends Area3D

# Goal: Meta final de nivel. Muestra la pantalla de resultados cuando ambos jugadores están presentes.

@export var next_scene_path: String = "res://scenes/levels/nivel 2.tscn"

var _cuerpos_dentro: Array[CharacterBase] = []
var _meta_activada: bool = false

func _ready() -> void:
	collision_layer = 1 << 3 # Capa 4
	collision_mask = (1 << 1) | (1 << 2) # Capas 2 y 3
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	print("[Goal] Inicializado en Capa 4. Detectando Capas 2 y 3.")

func _on_body_entered(body: Node) -> void:
	if not (body is CharacterBase):
		return
		
	if not body in _cuerpos_dentro:
		_cuerpos_dentro.append(body)
		print("[Goal] Personaje ingresó a la meta: ", body.name, " (Total: ", _cuerpos_dentro.size(), ")")
		
	if is_multiplayer_authority() and not _meta_activada:
		_verificar_activacion()

func _on_body_exited(body: Node) -> void:
	if body is CharacterBase and body in _cuerpos_dentro:
		_cuerpos_dentro.erase(body)
		print("[Goal] Personaje salió de la meta: ", body.name, " (Total: ", _cuerpos_dentro.size(), ")")

func _verificar_activacion() -> void:
	var tiene_vivo : bool = false
	var tiene_fantasma : bool = false
	
	for cuerpo in _cuerpos_dentro:
		if cuerpo is Jugador:
			tiene_vivo = true
		elif cuerpo is Fantasma:
			tiene_fantasma = true
			
	if tiene_vivo and tiene_fantasma:
		_meta_activada = true
		print("[Goal] ¡Ambos jugadores están en la meta! Mostrando pantalla de resultados.")
		
		if is_instance_valid(ScoreManager):
			ScoreManager.detener_cronometro()
			
		if is_instance_valid(RedManager) and RedManager.has_method("mostrar_pantalla_resultados"):
			RedManager.mostrar_pantalla_resultados()
		else:
			rpc("rpc_mostrar_resultados")

@rpc("any_peer", "call_local", "reliable")
func rpc_mostrar_resultados() -> void:
	print("[Goal] Mostrando pantalla de resultados localmente.")
	var escena_res = load("res://scenes/ui/pantalla_resultados.tscn")
	if escena_res:
		var instancia = escena_res.instantiate()
		get_tree().current_scene.add_child(instancia)
