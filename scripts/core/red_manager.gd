extends Node # Configurar como Autoload con nombre 'RedManager'

signal personajes_actualizados(peer_personajes: Dictionary)
signal ready_estados_actualizados(peer_listos: Dictionary)
signal modo_juego_actualizado(modo: String)
signal conexion_establecida()
signal conexion_perdida()

const PORT = 7000
const ADDRESS = "127.0.0.1"
const AMIGOS_FILE = "user://amigos.json"

const NIVELES = [
	"res://scenes/levels/Nivel 1 _ El Despertar Separado.tscn",
	"res://scenes/levels/nivel 2.tscn"
]

var jugador_vivo: CharacterBase
var fantasma: CharacterBase

# Estado del Lobby
var peer_personajes: Dictionary = {}  # {peer_id: "jugador" | "fantasma" | ""}
var peer_listos: Dictionary = {}      # {peer_id: listo}
var modo_juego: String = "historia"    # "historia" | "libre"
var nivel_actual_index: int = 0

# --- CAMPOS DE RECONEXIÓN DE SESIÓN ---
var ultima_conexion_ip: String = ""
var ultimo_personaje: String = ""
var ultimo_nivel_path: String = ""
var es_host_previo: bool = false
var puede_reconectarse: bool = false

# UPnP
var upnp_active: bool = false
var ip_publica: String = ""


# --- NUEVOS CAMPOS: Salas Online e Integración P2P ---
var mi_sala_actual: String = ""
var mi_peer_id: int = 1

func get_mi_peer_id() -> int:
	return mi_peer_id

var iniciar_directo_p2p: bool = false
var p2p_modo_inicial: String = "historia"
var p2p_nivel_inicial: int = 0
var p2p_personaje_elegido: String = ""

signal ping_actualizado(ms: int)

# --- Sistema de Ping ---
var last_ping_time: float = 0.0
var current_ping_ms: int = -1
var ping_timer: Timer = null

func _crear_interfaz_ping():
	# Ya no creamos interfaz visual aquí, solo el temporizador lógico
	ping_timer = Timer.new()
	ping_timer.wait_time = 1.0
	ping_timer.autostart = true
	ping_timer.timeout.connect(_on_ping_timer)
	add_child(ping_timer)

func _on_ping_timer():
	if not multiplayer.has_multiplayer_peer() or multiplayer.get_peers().is_empty():
		current_ping_ms = -1
		ping_actualizado.emit(-1)
		return
	var target_id = multiplayer.get_peers()[0]
	last_ping_time = Time.get_ticks_msec()
	rpc_id(target_id, "_rpc_ping_request")

@rpc("any_peer", "call_remote", "unreliable")
func _rpc_ping_request():
	var sender = multiplayer.get_remote_sender_id()
	rpc_id(sender, "_rpc_ping_response")

@rpc("any_peer", "call_remote", "unreliable")
func _rpc_ping_response():
	current_ping_ms = Time.get_ticks_msec() - last_ping_time
	ping_actualizado.emit(current_ping_ms)

# --- NUEVOS CAMPOS: Autodescubrimiento LAN (UDP) ---
signal status_webrtc_changed(msg: String)
signal lan_server_found(ip: String, port: int, name: String)
const LAN_DISCOVERY_PORT = 7001
var lan_servers_discovered: Dictionary = {} # { ip: { name: String, port: int, time: float } }

func _ready():
	_crear_interfaz_ping()
	
	# Inicializar LAN Discovery como nodo hijo
	var lan = LanDiscovery.new()
	lan.name = "LanDiscovery"
	add_child(lan)
	lan.servidor_encontrado.connect(func(ip, port, name): lan_server_found.emit(ip, port, name))
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	# Autoiniciar servidor solo si se ejecuta con el parámetro --server (y no en check-only)
	var cmd_args = OS.get_cmdline_args()
	if cmd_args.has("--server") and not cmd_args.has("--check-only"):
		print("[Servidor Dedicado] Detectado parámetro --server. Iniciando servidor en puerto ", PORT)
		await get_tree().process_frame
		crear_partida_online_server()

func _process(delta):
	if is_instance_valid(webrtc_peer):
		webrtc_peer.poll()
	
	# LAN discovery ahora es manejado por el nodo hijo LanDiscovery
	var lan_node = get_node_or_null("LanDiscovery") as LanDiscovery
	if lan_node:
		lan_servers_discovered = lan_node.servidores_descubiertos

func registrar_jugador(p: CharacterBase):
	if p.is_in_group("fantasmas") or p.name.to_lower().contains("fantasma"): 
		fantasma = p
	else:
		jugador_vivo = p
	
	_intentar_asignar_autoridades()

func _intentar_asignar_autoridades():
	if not jugador_vivo or not fantasma: return
	
	if not multiplayer.multiplayer_peer or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		# Modo local de prueba o sin red: el Host controla a ambos o al jugador vivo
		jugador_vivo.set_multiplayer_authority(1)
		fantasma.set_multiplayer_authority(1)
		var sync_v = jugador_vivo.get_node_or_null("MultiplayerSynchronizer")
		if sync_v: sync_v.set_multiplayer_authority(1)
		var sync_f = fantasma.get_node_or_null("MultiplayerSynchronizer")
		if sync_f: sync_f.set_multiplayer_authority(1)
		jugador_vivo.actualizar_visibilidad_local()
		fantasma.actualizar_visibilidad_local()
		_actualizar_interfaz_local()
		return
		
	# Buscar quién tiene cada personaje
	var id_jugador = 1
	var id_fantasma = 1
	
	for peer_id in peer_personajes:
		if peer_personajes[peer_id] == "jugador":
			id_jugador = peer_id
		elif peer_personajes[peer_id] == "fantasma":
			id_fantasma = peer_id
			
	jugador_vivo.set_multiplayer_authority(id_jugador)
	fantasma.set_multiplayer_authority(id_fantasma)

	var sync_vivo = jugador_vivo.get_node_or_null("MultiplayerSynchronizer")
	if sync_vivo:
		sync_vivo.set_multiplayer_authority(id_jugador)
		
	var sync_fant = fantasma.get_node_or_null("MultiplayerSynchronizer")
	if sync_fant:
		sync_fant.set_multiplayer_authority(id_fantasma)
	
	jugador_vivo.actualizar_visibilidad_local()
	fantasma.actualizar_visibilidad_local()
	_actualizar_interfaz_local()
	
	print("[RedManager] Autoridades asignadas - Jugador: ", id_jugador, " (", peer_personajes.get(id_jugador, ""), "), Fantasma: ", id_fantasma, " (", peer_personajes.get(id_fantasma, ""), ")")


func _actualizar_interfaz_local():
	var escena_actual = get_tree().current_scene
	if not escena_actual:
		return

	var controles = escena_actual.get_node_or_null("Controles_Tactiles")
	if not controles or not controles.has_method("configurar_personaje_local"):
		return

	if jugador_vivo and jugador_vivo.is_multiplayer_authority():
		controles.configurar_personaje_local(jugador_vivo)
	elif fantasma and fantasma.is_multiplayer_authority():
		controles.configurar_personaje_local(fantasma)

# --- Métodos de Creación y Conexión Local/P2P ---


const ICE_SERVERS = [
	{ "urls": ["stun:stun.l.google.com:19302"] },
	{ "urls": ["stun:stun.relay.metered.ca:80"] },
	{ 
		"urls": [
			"turn:global.relay.metered.ca:80",
			"turn:global.relay.metered.ca:80?transport=tcp",
			"turn:global.relay.metered.ca:443",
			"turns:global.relay.metered.ca:443?transport=tcp"
		],
		"username": "c1baebff3f04fcaeb912660a",
		"credential": "dH915CfDvUzOj/FS"
	}
]

var webrtc_peer: WebRTCMultiplayerPeer
var webrtc_connections: Dictionary = {}
var ice_candidates_queue: Dictionary = {} # { peer_id: Array }

func crear_partida():
	desconectar()
	mi_peer_id = 1
	webrtc_peer = WebRTCMultiplayerPeer.new()
	var error = webrtc_peer.create_server()
	if error != OK:
		print("[RedManager ERROR] Error al crear servidor WebRTC: ", error)
		return
		
	multiplayer.multiplayer_peer = webrtc_peer
	
	peer_personajes.clear()
	peer_listos.clear()
	modo_juego = "historia"
	nivel_actual_index = 0
	es_host_previo = true
	ultima_conexion_ip = "127.0.0.1"
	
	peer_personajes[1] = ""
	peer_listos[1] = false
	
	conexion_establecida.emit()
	status_webrtc_changed.emit("Servidor listo. Esperando al jugador...")
	print("[RedManager WebRTC] Servidor WebRTC listo (ID: 1). Esperando señalización de Firebase...")

	if iniciar_directo_p2p:
		await get_tree().process_frame
		rpc_seleccionar_personaje.rpc(p2p_personaje_elegido)

func unirse_a_partida(sala_id: String):
	desconectar()
	es_host_previo = false
	ultima_conexion_ip = sala_id
	webrtc_peer = WebRTCMultiplayerPeer.new()
	mi_peer_id = randi() % 89999 + 1000
	var error = webrtc_peer.create_client(mi_peer_id)
	if error != OK:
		print("[RedManager ERROR] Error al crear cliente WebRTC: ", error)
		status_webrtc_changed.emit("Error de WebRTC. ¿Falta el plugin nativo o bloqueado por Firewall?")
		return
		
	multiplayer.multiplayer_peer = webrtc_peer
	print("[RedManager WebRTC] Iniciando cliente WebRTC (Mi ID: ", mi_peer_id, ") para sala: ", sala_id)
	
	var pc = _crear_peer_connection(1)
	status_webrtc_changed.emit("Iniciando oferta de conexión P2P...")
	print("[RedManager WebRTC] Creando Oferta SDP para Host (ID: 1)...")
	pc.create_offer()

func _crear_peer_connection(id: int) -> WebRTCPeerConnection:
	if webrtc_connections.has(id):
		return webrtc_connections[id]
		
	print("[RedManager WebRTC] Inicializando WebRTCPeerConnection para peer ID: ", id)
	var pc = WebRTCPeerConnection.new()
	var err = pc.initialize({ "iceServers": ICE_SERVERS })
	if err != OK:
		print("[RedManager ERROR] Falló al inicializar PeerConnection: ", err)
		status_webrtc_changed.emit("Fallo en WebRTC (Comprueba tu conexión o Firewall)")
		
	pc.session_description_created.connect(_on_sdp_created.bind(id))
	pc.ice_candidate_created.connect(_on_ice_created.bind(id))
	webrtc_peer.add_peer(pc, id)
	webrtc_connections[id] = pc
	return pc

func _on_sdp_created(type: String, sdp: String, id: int):
	print("[RedManager WebRTC] SDP Generado ('", type, "') para peer ID: ", id)
	if webrtc_connections.has(id):
		webrtc_connections[id].set_local_description(type, sdp)
	FirebaseMatchmaking.enviar_sdp(id, type, sdp)

func _on_ice_created(media: String, index: int, name: String, id: int):
	print("[RedManager WebRTC] Candidato ICE local generado para peer ID: ", id, " -> ", name)
	FirebaseMatchmaking.enviar_ice(id, media, index, name)

func recibir_sdp(id: int, type: String, sdp: String):
	print("[RedManager WebRTC] Recibido SDP '", type, "' remoto proveniente de peer ID: ", id)
	if type == "offer":
		var pc = _crear_peer_connection(id)
		var err = pc.set_remote_description(type, sdp)
		print("[RedManager WebRTC] Remote description (Offer) establecida. Status: ", err)
		_peers_con_remote_sdp[id] = true
		status_webrtc_changed.emit("Generando respuesta al invitado...")
		print("[RedManager WebRTC] Generando Respuesta SDP automáticamente por Godot...")
		_flush_ice_queue(id)
	elif type == "answer":
		if webrtc_connections.has(id):
			var pc = webrtc_connections[id]
			var err = pc.set_remote_description(type, sdp)
			status_webrtc_changed.emit("Respuesta aceptada. Intercambiando redes...")
			print("[RedManager WebRTC] Remote description (Answer) establecida. Status: ", err)
			_peers_con_remote_sdp[id] = true
			_flush_ice_queue(id)

var _peers_con_remote_sdp: Dictionary = {}

func recibir_ice(id: int, media: String, index: int, name: String):
	print("[RedManager WebRTC] Recibido ICE remoto de peer ID ", id, ": ", name)
	if webrtc_connections.has(id) and _peers_con_remote_sdp.get(id, false):
		var pc = webrtc_connections[id]
		pc.add_ice_candidate(media, index, name)
	else:
		print("[RedManager WebRTC] Encolando ICE remoto (PeerConnection esperando remote SDP para ID: ", id, ")")
		if not ice_candidates_queue.has(id):
			ice_candidates_queue[id] = []
		ice_candidates_queue[id].append({"media": media, "index": index, "name": name})

func _flush_ice_queue(id: int):
	if ice_candidates_queue.has(id) and webrtc_connections.has(id):
		var list = ice_candidates_queue[id]
		print("[RedManager WebRTC] Vaciando cola de ", list.size(), " ICE candidates para peer ID: ", id)
		for cand in list:
			webrtc_connections[id].add_ice_candidate(cand["media"], cand["index"], cand["name"])
		ice_candidates_queue.erase(id)

func reconectar_a_partida():
	if ultima_conexion_ip.is_empty():
		print("[RedManager] No hay datos de sesión previa para reconectar.")
		return
	print("[RedManager] Reconectando a la sesión previa: ", ultima_conexion_ip, " | Personaje: ", ultimo_personaje)
	if es_host_previo:
		crear_partida()
	else:
		unirse_a_partida(ultima_conexion_ip)


func crear_partida_online_server():
	desconectar()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, 100) # Máximo 100 jugadores para salas
	if error != OK:
		print("[Servidor Dedicado] Error al crear el servidor online: ", error)
		return
	multiplayer.multiplayer_peer = peer
	print("[Servidor Dedicado] Servidor iniciado en puerto ", PORT, " para albergar salas online.")

func desconectar():
	print("[RedManager WebRTC] Desconectando red...")
	for id in webrtc_connections.keys():
		var pc = webrtc_connections[id]
		if is_instance_valid(pc) and pc.has_method("close"):
			pc.close()
	webrtc_connections.clear()
	ice_candidates_queue.clear()
	_peers_con_remote_sdp.clear()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	webrtc_peer = null
	peer_personajes.clear()
	peer_listos.clear()

func iniciar_juego():
	if not multiplayer.is_server(): return
	
	if modo_juego == "historia":
		nivel_actual_index = 0
		_cargar_nivel_todos(NIVELES[0])
	else:
		if nivel_actual_index >= 0 and nivel_actual_index < NIVELES.size():
			_cargar_nivel_todos(NIVELES[nivel_actual_index])
		else:
			_cargar_nivel_todos(NIVELES[0])

func cargar_nivel_libre(path: String):
	if not multiplayer.is_server(): return
	_cargar_nivel_todos(path)

func completar_nivel():
	if not multiplayer.is_server(): return
	
	if modo_juego == "historia":
		nivel_actual_index += 1
		if nivel_actual_index < NIVELES.size():
			_cargar_nivel_todos(NIVELES[nivel_actual_index])
		else:
			print("[RedManager] Fin de la historia. Volviendo al menú principal.")
			_cargar_nivel_todos("res://scenes/ui/menu_inicio.tscn")
	else:
		print("[RedManager] Nivel libre completado. Volviendo al menú principal.")
		_cargar_nivel_todos("res://scenes/ui/menu_inicio.tscn")

func reintentar_nivel_actual():
	if not multiplayer.is_server(): return
	if nivel_actual_index >= 0 and nivel_actual_index < NIVELES.size():
		_cargar_nivel_todos(NIVELES[nivel_actual_index])
	else:
		_cargar_nivel_todos(NIVELES[0])

func mostrar_pantalla_resultados():
	print("[RedManager] Mostrando pantalla de resultados a todos los peers.")
	rpc_mostrar_pantalla_resultados.rpc()
	rpc_mostrar_pantalla_resultados()

@rpc("any_peer", "call_local", "reliable")
func rpc_mostrar_pantalla_resultados():
	var escena_res = load("res://scenes/ui/pantalla_resultados.tscn")
	if escena_res and get_tree() and get_tree().current_scene:
		if not get_tree().current_scene.has_node("PantallaResultados"):
			var inst = escena_res.instantiate()
			get_tree().current_scene.add_child(inst)

# Función auxiliar que garantiza la carga del nivel en TODAS las instancias
# Envía el RPC a los peers remotos y ejecuta localmente de forma explícita
func _cargar_nivel_todos(path: String):
	if path.ends_with(".tscn") and not "menu_inicio" in path:
		ultimo_nivel_path = path
		puede_reconectarse = true
	print("[RedManager] Enviando carga de nivel a todos: ", path)
	rpc_cargar_nivel.rpc(path)  # Enviar a peers remotos
	rpc_cargar_nivel(path)      # Ejecutar localmente de forma explícita

@rpc("reliable")
func rpc_cargar_nivel(path: String):
	print("[RedManager] Cargando nivel: ", path)
	get_tree().change_scene_to_file(path)
	# Esperar 2 frames para inicialización limpia de nodos antes de reasignar autoridad
	await get_tree().process_frame
	await get_tree().process_frame
	_intentar_asignar_autoridades()

# --- Métodos de Lobby (RPCs para P2P / Local) ---

@rpc("any_peer", "call_local", "reliable")
func rpc_seleccionar_personaje(personaje: String):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
	
	if sender_id == multiplayer.get_unique_id():
		ultimo_personaje = personaje
		
	# Verificar si ya está elegido por otro peer
	for peer in peer_personajes:
		if peer != sender_id and peer_personajes[peer] == personaje and personaje != "":
			# Ocupado, ignorar
			return
			
	peer_personajes[sender_id] = personaje
	personajes_actualizados.emit(peer_personajes)
	
	# Si somos el servidor, sincronizar con todos
	if multiplayer.is_server():
		rpc("rpc_sincronizar_personajes", peer_personajes)

@rpc("any_peer", "call_local", "reliable")
func rpc_solicitar_reconexion(personaje_solicitado: String):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
		
	if not multiplayer.is_server():
		return
		
	print("[RedManager] Solicitud de reconexión aceptada para peer ", sender_id, " como: ", personaje_solicitado)
	
	# Limpiar asignaciones anteriores de este rol
	for p in peer_personajes.keys():
		if peer_personajes[p] == personaje_solicitado:
			peer_personajes.erase(p)
			
	peer_personajes[sender_id] = personaje_solicitado
	peer_listos[sender_id] = true
	
	# Sincronizar roles a todos los clientes (Host y Clientes)
	rpc("rpc_sincronizar_personajes", peer_personajes)
	_intentar_asignar_autoridades()
	
	var escena_actual = get_tree().current_scene
	if escena_actual and escena_actual.scene_file_path.ends_with(".tscn") and not "menu_inicio" in escena_actual.scene_file_path:
		print("[RedManager] Sincronizando nivel activo con reconectado: ", escena_actual.scene_file_path)
		rpc_cargar_nivel.rpc_id(sender_id, escena_actual.scene_file_path)

@rpc("any_peer", "call_local", "reliable")
func rpc_establecer_listo(listo: bool):

	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
	
	peer_listos[sender_id] = listo
	ready_estados_actualizados.emit(peer_listos)
	
	if multiplayer.is_server():
		rpc("rpc_sincronizar_listos", peer_listos)

@rpc("any_peer", "call_local", "reliable")
func rpc_establecer_modo(modo: String):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
		
	if sender_id == get_lider_peer_id():
		modo_juego = modo
		modo_juego_actualizado.emit(modo)
		if multiplayer.is_server():
			rpc("rpc_sincronizar_modo", modo)

@rpc("any_peer", "call_local", "reliable")
func rpc_solicitar_inicio(sync_modo: String, idx_nivel: int):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
		
	if sender_id == get_lider_peer_id() and multiplayer.is_server():
		print("[RedManager] Solicitud de inicio aceptada. Modo: ", sync_modo, " Nivel: ", idx_nivel)
		modo_juego = sync_modo
		nivel_actual_index = idx_nivel
		if modo_juego == "libre":
			if idx_nivel >= 0 and idx_nivel < NIVELES.size():
				_cargar_nivel_todos(NIVELES[idx_nivel])
			else:
				_cargar_nivel_todos(NIVELES[0])
		else:
			_cargar_nivel_todos(NIVELES[0])

# --- Sincronizaciones desde el Servidor ---

@rpc("reliable")
func rpc_sincronizar_estado_inicial(sync_personajes: Dictionary, sync_modo: String, sync_listos: Dictionary):
	peer_personajes = sync_personajes
	modo_juego = sync_modo
	peer_listos = sync_listos
	personajes_actualizados.emit(peer_personajes)
	modo_juego_actualizado.emit(modo_juego)
	ready_estados_actualizados.emit(peer_listos)

@rpc("reliable")
func rpc_sincronizar_personajes(sync_personajes: Dictionary):
	peer_personajes = sync_personajes
	personajes_actualizados.emit(peer_personajes)
	_intentar_asignar_autoridades()

@rpc("reliable")
func rpc_sincronizar_listos(sync_listos: Dictionary):
	peer_listos = sync_listos
	ready_estados_actualizados.emit(peer_listos)

@rpc("reliable")
func rpc_sincronizar_modo(sync_modo: String):
	modo_juego = sync_modo
	modo_juego_actualizado.emit(sync_modo)

# --- Manejadores de Red ---

func _on_peer_connected(id):
	status_webrtc_changed.emit("¡Conexión P2P/WebRTC Establecida!")
	print("[RedManager] Peer conectado: ", id)
	if multiplayer.is_server():
			
		# Registrar el nuevo peer en las variables de estado (Modo Local/P2P)
		peer_personajes[id] = ""
		peer_listos[id] = false
		rpc_sincronizar_estado_inicial.rpc_id(id, peer_personajes, modo_juego, peer_listos)
		rpc("rpc_sincronizar_personajes", peer_personajes)
		rpc("rpc_sincronizar_listos", peer_listos)
		
		# Si venimos de P2P automático y se conecta el otro jugador
		if iniciar_directo_p2p:
			print("[RedManager] P2P - Jugador conectado. Esperando sincronización...")
			await get_tree().create_timer(1.0).timeout
			if peer_personajes.size() >= 2:
				print("[RedManager] P2P - Ambos listos. Cargando nivel automáticamente: ", p2p_modo_inicial)
				modo_juego = p2p_modo_inicial
				nivel_actual_index = p2p_nivel_inicial
				iniciar_directo_p2p = false
				rpc_solicitar_inicio(modo_juego, nivel_actual_index)

func _on_peer_disconnected(id):
	print("[RedManager] Peer desconectado: ", id)
	
	# Lógica local/P2P
	if peer_personajes.has(id):
		peer_personajes.erase(id)
	if peer_listos.has(id):
		peer_listos.erase(id)
	personajes_actualizados.emit(peer_personajes)
	ready_estados_actualizados.emit(peer_listos)
	
	if multiplayer.is_server():
		rpc("rpc_sincronizar_personajes", peer_personajes)
		rpc("rpc_sincronizar_listos", peer_listos)

func _on_connected_to_server():
	var mi_id = multiplayer.get_unique_id()
	status_webrtc_changed.emit("¡Conectado al Host con éxito!")
	print("[RedManager] Conectado al servidor con ID: ", mi_id)
	conexion_establecida.emit()
	
	if puede_reconectarse and not ultimo_personaje.is_empty():
		print("[RedManager] Enviando solicitud de reconexión con personaje: ", ultimo_personaje)
		rpc_solicitar_reconexion.rpc(ultimo_personaje)
	elif iniciar_directo_p2p:
		print("[RedManager] P2P establecido en Cliente. Enviando selección: ", p2p_personaje_elegido)
		rpc_seleccionar_personaje.rpc(p2p_personaje_elegido)
		rpc_establecer_listo.rpc(true)


func _on_connection_failed():
	print("[RedManager] Error de conexión.")
	desconectar()
	conexion_perdida.emit()

func _on_server_disconnected():
	print("[RedManager] El servidor se cerró.")
	desconectar()
	conexion_perdida.emit()

# --- Funciones de Utilidad ---

func get_local_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169.254."):
			return ip
	return "127.0.0.1"

func get_lider_peer_id() -> int:
	# En arquitectura P2P pura (sin servidor dedicado separado), el host (1) siempre es el líder.
	return 1

# --- Sistema de Amigos Persistente (delegado a AmigosManager) ---

func cargar_amigos() -> Dictionary:
	return AmigosManager.cargar()

func guardar_amigos(amigos: Dictionary):
	AmigosManager.guardar(amigos)

func agregar_amigo(nombre: String, ip: String):
	AmigosManager.agregar(nombre, ip)

func eliminar_amigo(nombre: String):
	AmigosManager.eliminar(nombre)

# --- Métodos de Descubrimiento LAN ---

func iniciar_lan_broadcaster():
	var lan_node = get_node_or_null("LanDiscovery") as LanDiscovery
	if lan_node:
		lan_node.configurar_broadcast(get_local_ip(), PORT, "Partida de " + OS.get_environment("USERNAME"))
		lan_node.iniciar_broadcaster()

func detener_lan_broadcaster():
	var lan_node = get_node_or_null("LanDiscovery") as LanDiscovery
	if lan_node:
		lan_node.detener_broadcaster()

func iniciar_lan_listener():
	var lan_node = get_node_or_null("LanDiscovery") as LanDiscovery
	if lan_node:
		lan_node.iniciar_listener()

func detener_lan_listener():
	var lan_node = get_node_or_null("LanDiscovery") as LanDiscovery
	if lan_node:
		lan_node.detener_listener()
