extends Area3D

# Goal: Meta final de nivel. Muestra la pantalla de resultados cuando ambos jugadores están presentes.

@export var next_scene_path: String = "res://scenes/levels/nivel 2.tscn"
@export var radio_deteccion_proximidad: float = 2.5

var _cuerpos_dentro: Array[Node] = []
var _meta_activada: bool = false

func _ready() -> void:
	collision_layer = 1 << 3 # Capa 4
	collision_mask = (1 << 1) | (1 << 2) # Capas 2 y 3
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	print("[Goal] Inicializado en Capa 4. Detectando Capas 2 y 3.")

func _physics_process(_delta: float) -> void:
	if _meta_activada:
		return
	_verificar_activacion()

func _on_body_entered(body: Node) -> void:
	if not _es_personaje_valido(body):
		return
		
	if not body in _cuerpos_dentro:
		_cuerpos_dentro.append(body)
		print("[Goal] Personaje ingresó a la meta: ", body.name, " (Total registrados: ", _cuerpos_dentro.size(), ")")
		
	_verificar_activacion()

func _on_body_exited(body: Node) -> void:
	if body in _cuerpos_dentro:
		_cuerpos_dentro.erase(body)
		print("[Goal] Personaje salió de la meta: ", body.name, " (Total registrados: ", _cuerpos_dentro.size(), ")")

func _es_personaje_valido(cuerpo: Node) -> bool:
	if not is_instance_valid(cuerpo):
		return false
	return _es_vivo(cuerpo) or _es_fantasma(cuerpo)

func _es_vivo(cuerpo: Node) -> bool:
	if not is_instance_valid(cuerpo):
		return false
	if cuerpo is Jugador:
		return true
	if cuerpo.is_in_group("vivos"):
		return true
	var n = cuerpo.name.to_lower()
	return ("jugador" in n or "vivo" in n) and not "fantasma" in n

func _es_fantasma(cuerpo: Node) -> bool:
	if not is_instance_valid(cuerpo):
		return false
	if cuerpo is Fantasma:
		return true
	if cuerpo.is_in_group("fantasmas"):
		return true
	var n = cuerpo.name.to_lower()
	return "fantasma" in n

func _verificar_activacion() -> void:
	if _meta_activada:
		return

	var tiene_vivo: bool = false
	var tiene_fantasma: bool = false

	# 1. Comprobar lista interna de cuerpos registrados por señales
	for cuerpo in _cuerpos_dentro:
		if _es_vivo(cuerpo):
			tiene_vivo = true
		elif _es_fantasma(cuerpo):
			tiene_fantasma = true

	# 2. Comprobar cuerpos superpuestos directamente por Area3D (fallback dinámico)
	if not (tiene_vivo and tiene_fantasma):
		var solapados = get_overlapping_bodies()
		for cuerpo in solapados:
			if _es_vivo(cuerpo):
				tiene_vivo = true
			elif _es_fantasma(cuerpo):
				tiene_fantasma = true

	# 3. Comprobar proximidad de personajes registrados en RedManager (fallback absoluto para modo un jugador)
	if not (tiene_vivo and tiene_fantasma) and is_instance_valid(RedManager):
		var p_vivo = RedManager.jugador_vivo
		var p_fant = RedManager.fantasma
		
		if is_instance_valid(p_vivo):
			var dist_vivo_xz = Vector2(p_vivo.global_position.x - global_position.x, p_vivo.global_position.z - global_position.z).length()
			var dist_vivo_y = absf(p_vivo.global_position.y - global_position.y)
			if dist_vivo_xz <= radio_deteccion_proximidad and dist_vivo_y <= 3.0:
				tiene_vivo = true
				
		if is_instance_valid(p_fant):
			var dist_fant_xz = Vector2(p_fant.global_position.x - global_position.x, p_fant.global_position.z - global_position.z).length()
			var dist_fant_y = absf(p_fant.global_position.y - global_position.y)
			if dist_fant_xz <= radio_deteccion_proximidad and dist_fant_y <= 3.0:
				tiene_fantasma = true

	# Si ambos están en la zona verde, activar la meta
	if tiene_vivo and tiene_fantasma:
		# En multijugador online solo la autoridad/servidor activa; en un jugador siempre se activa
		var es_offline = (multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
		if not es_offline and not is_multiplayer_authority() and not multiplayer.is_server():
			return

		_meta_activada = true
		print("[Goal] ¡Ambos personajes están dentro de la meta! Mostrando pantalla de resultados...")

		if is_instance_valid(ScoreManager):
			ScoreManager.detener_cronometro()

		if is_instance_valid(RedManager) and RedManager.has_method("mostrar_pantalla_resultados"):
			RedManager.mostrar_pantalla_resultados()
		else:
			rpc_mostrar_resultados()

@rpc("any_peer", "call_local", "reliable")
func rpc_mostrar_resultados() -> void:
	print("[Goal] Mostrando pantalla de resultados.")
	if is_instance_valid(RedManager) and RedManager.has_method("mostrar_pantalla_resultados"):
		RedManager.mostrar_pantalla_resultados()
	else:
		var escena_res = load("res://scenes/ui/pantalla_resultados.tscn")
		if escena_res and get_tree() and get_tree().current_scene:
			var root_escena = get_tree().current_scene
			if not root_escena.has_node("CanvasResultados") and not root_escena.has_node("PantallaResultados"):
				var canvas = CanvasLayer.new()
				canvas.name = "CanvasResultados"
				canvas.layer = 100
				var instancia = escena_res.instantiate()
				canvas.add_child(instancia)
				root_escena.add_child(canvas)
