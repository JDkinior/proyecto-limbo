extends Area3D

# Goal: Meta final de nivel. Transiciona de escena mediante RPC
# cuando detecta al jugador Vivo y al Fantasma de forma simultánea en su área.

@export var next_scene_path: String = "res://scenes/levels/mundo_pruebas.tscn"

# Registro indexado de cuerpos actualmente en la meta
var _cuerpos_dentro: Array[CharacterBase] = []

func _ready() -> void:
	# La meta pertenece a la Capa de Colisión 4 (Coleccionables/Metas)
	collision_layer = 1 << 3 # Capa 4
	
	# Detecta Capa 2 (Jugador Vivo) y Capa 3 (Jugador Fantasma)
	collision_mask = (1 << 1) | (1 << 2) # Capas 2 y 3
	
	# Conexión dinámica a señales de detección
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	print("[Goal] Inicializado en Capa 4. Detectando Capas 2 y 3.")

func _on_body_entered(body: Node) -> void:
	if not (body is CharacterBase):
		return
		
	if not body in _cuerpos_dentro:
		_cuerpos_dentro.append(body)
		print("[Goal] Personaje ingresó a la meta: ", body.name, " (Total: ", _cuerpos_dentro.size(), ")")
		
	# Solo el authority del multijugador evalúa la condición de transición
	if is_multiplayer_authority():
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
		print("[Goal] ¡Ambos jugadores están en la meta! Iniciando transición de nivel.")
		
		# Si RedManager está disponible y estamos en red, delegamos la carga
		if is_instance_valid(RedManager) and RedManager.has_method("completar_nivel") and RedManager.multiplayer.multiplayer_peer and not RedManager.multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
			if RedManager.multiplayer.is_server():
				RedManager.completar_nivel()
		else:
			# Fallback offline o P2P directo a todos los peers
			rpc("rpc_change_scene", next_scene_path)

@rpc("any_peer", "call_local", "reliable")
func rpc_change_scene(path: String) -> void:
	print("[Goal] RPC recibido. Cambiando de escena a: ", path)
	if get_tree():
		get_tree().change_scene_to_file(path)
