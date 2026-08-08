extends Node # Configurar como Autoload con nombre 'RedManager'

signal personajes_actualizados(peer_personajes: Dictionary)
signal ready_estados_actualizados(peer_listos: Dictionary)
signal modo_juego_actualizado(modo: String)
signal conexion_establecida()
signal conexion_perdida()
signal ping_actualizado(ms: int)
signal status_webrtc_changed(msg: String)
signal lan_server_found(ip: String, port: int, name: String)

const PORT = 7000
const EOS_P2P_SOCKET_ID = "limbop2pv1"
const ONLINE_CONNECTION_TIMEOUT_SECONDS := 60.0
const P2P_REQUEST_AUTHORIZATION_TIMEOUT_SECONDS := 12.0
# Este atributo es de miembro (no de la sala): permite que el cliente avise al
# host que el siguiente intento debe usar TURN/Relay. No se usa al iniciar una
# partida, por lo que la ruta directa LAN conserva su comportamiento actual.
const P2P_RELAY_REQUEST_MEMBER_ATTRIBUTE := "p2p_relay_request"
const P2P_RELAY_REQUEST_VALUE := "force"
const P2P_RELAY_COORDINATION_WAIT_SECONDS := 3.5
const NIVELES_HISTORIA_COUNT = 2
const NIVELES = [
	"res://scenes/levels/Nivel 1 _ El Despertar Separado.tscn",
	"res://scenes/levels/nivel 2.tscn",
	"res://scenes/levels/mundo_pruebas.tscn"
]

var jugador_vivo: CharacterBase
var fantasma: CharacterBase

# Estado del Lobby
var peer_personajes: Dictionary = {}  # {peer_id: "jugador" | "fantasma" | ""}
var peer_listos: Dictionary = {}      # {peer_id: listo}
var modo_juego: String = "historia"    # "historia" | "libre"
var nivel_actual_index: int = 0

var ultima_conexion_ip: String = ""
var ultimo_personaje: String = ""
var ultimo_nivel_path: String = ""
var es_host_previo: bool = false
var puede_reconectarse: bool = false
var es_lan_previo: bool = false
var intento_relay_forzado: bool = false
var _manejando_fallo_conexion := false
var _solicitudes_p2p_pendientes: Dictionary = {}

var _timer_conexion: Timer

var _conectando: bool = false
var _tiempo_conexion: int = 0

var mi_sala_actual: String = ""
var mi_peer_id: int = 1
var ip_publica: String = ""
var upnp_active: bool = false

func get_mi_peer_id() -> int:
	return mi_peer_id

var iniciar_directo_p2p: bool = false
var p2p_modo_inicial: String = "historia"
var p2p_nivel_inicial: int = 0
var p2p_personaje_elegido: String = ""

var last_ping_time: float = 0.0
var current_ping_ms: int = -1
var ping_timer: Timer = null
var lan_servers_discovered: Dictionary = {} 

var eos_peer # EOSGMultiplayerPeer o ENetMultiplayerPeer en fallback

func _crear_interfaz_ping():
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


func _ready():
	_crear_interfaz_ping()
	
	var lan = LanDiscovery.new()
	lan.name = "LanDiscovery"
	add_child(lan)
	lan.servidor_encontrado.connect(func(ip, port, name): lan_server_found.emit(ip, port, name))
	
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		
	_timer_conexion = Timer.new()
	_timer_conexion.one_shot = true
	_timer_conexion.wait_time = ONLINE_CONNECTION_TIMEOUT_SECONDS
	_timer_conexion.timeout.connect(_on_timeout_conexion)
	add_child(_timer_conexion)
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _process(delta):
	# Ya no necesitamos poll de webrtc_peer manualmente con EOS
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
	
	print("[RedManager] Autoridades asignadas - Jugador: ", id_jugador, ", Fantasma: ", id_fantasma)


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

# --- CREAR Y UNIRSE P2P (EOS) ---

func get_eos_p2p_socket_id() -> String:
	return EOS_P2P_SOCKET_ID


func _esperar_eos_para_online() -> bool:
	var eos_manager = get_tree().root.get_node_or_null("EosManager")
	if not eos_manager or not eos_manager.has_method("esperar_login_async"):
		status_webrtc_changed.emit("EOS no está disponible en esta compilación.")
		return false

	status_webrtc_changed.emit("Iniciando sesión en EOS...")
	if not (await eos_manager.esperar_login_async()):
		status_webrtc_changed.emit("EOS no pudo iniciar sesión. Revisa el log de conexión.")
		return false
	return true


func _aplicar_control_relay_inteligente(force_relay := false) -> void:
	var eos_manager = get_tree().root.get_node_or_null("EosManager")
	if not eos_manager or not eos_manager.has_method("configurar_relay_p2p"):
		return

	var nat_type: int = eos_manager.cached_nat_type
	# AllowRelays reúne candidatos directos Y de relay (TURN). ICE elige la
	# mejor ruta. ForceRelays se reserva para el reintento cuando ICE falla,
	# forzando que solo se usen servidores TURN de Epic.
	var must_force_relay := force_relay
	eos_manager.configurar_relay_p2p(must_force_relay)
	if must_force_relay:
		print("[RedManager] Usando Epic Relay (NAT: ", nat_type, ").")
	else:
		print("[RedManager] Intentando ruta directa con fallback de Epic Relay (NAT: ", nat_type, ").")


func _conectar_eventos_peer_eos(peer) -> void:
	# El plugin EOSG ignora set_auto_accept_connection_requests,
	# por lo que debemos aceptar las conexiones manualmente de forma inmediata.
	peer.set_auto_accept_connection_requests(false)
	peer.incoming_connection_request.connect(_on_eos_incoming_connection_request)
	peer.peer_connection_established.connect(_on_eos_peer_connection_established)
	peer.peer_connection_interrupted.connect(_on_eos_peer_connection_interrupted)
	peer.peer_connection_closed.connect(_on_eos_peer_connection_closed)


func crear_partida(es_lan: bool = false) -> bool:
	await desconectar(true)
	mi_peer_id = 1
	es_lan_previo = es_lan
	_manejando_fallo_conexion = false

	if not es_lan:
		if not await _esperar_eos_para_online():
			return false
		if not ClassDB.class_exists("EOSGMultiplayerPeer"):
			status_webrtc_changed.emit("El transporte EOS P2P no está incluido en esta compilación.")
			return false

		# Usamos AllowRelays por defecto para que las conexiones locales puedan
		# resolverse vía STUN sin depender de los servidores TURN de Epic.
		# ForceRelays se reserva exclusivamente para los reintentos.
		_aplicar_control_relay_inteligente(false)
		eos_peer = ClassDB.instantiate("EOSGMultiplayerPeer")
		var eos_error = eos_peer.create_server(EOS_P2P_SOCKET_ID)
		if eos_error != OK:
			print("[RedManager ERROR] Error al crear servidor EOS P2P: ", eos_error)
			status_webrtc_changed.emit("No se pudo abrir el servidor EOS P2P.")
			eos_peer = null
			return false
		_conectar_eventos_peer_eos(eos_peer)
		print("[RedManager] Servidor EOS P2P creado. Socket: ", EOS_P2P_SOCKET_ID)
	else:
		print("[RedManager] Creando servidor ENet para LAN.")
		eos_peer = ENetMultiplayerPeer.new()
		var lan_error = eos_peer.create_server(PORT, 2)
		if lan_error != OK:
			print("[RedManager ERROR] Error al crear servidor LAN: ", lan_error)
			status_webrtc_changed.emit("No se pudo abrir el servidor LAN.")
			eos_peer = null
			return false
		iniciar_lan_broadcaster()

	multiplayer.multiplayer_peer = eos_peer
	peer_personajes.clear()
	peer_listos.clear()
	modo_juego = "historia"
	nivel_actual_index = 0
	es_host_previo = true
	ultima_conexion_ip = "eos_host" if not es_lan else get_local_ip()
	peer_personajes[1] = ""
	peer_listos[1] = false
	conexion_establecida.emit()
	status_webrtc_changed.emit("Servidor listo. Esperando al jugador...")

	if iniciar_directo_p2p:
		await get_tree().process_frame
		rpc_seleccionar_personaje.rpc(p2p_personaje_elegido)
	return true


func unirse_a_partida(host_puid_or_ip: String, es_lan: bool = false, es_reintento: bool = false) -> bool:
	if host_puid_or_ip.strip_edges().is_empty():
		status_webrtc_changed.emit("No se recibió la dirección del host.")
		return false
	if not es_lan and not await _esperar_eos_para_online():
		return false
	if not es_lan and not ClassDB.class_exists("EOSGMultiplayerPeer"):
		status_webrtc_changed.emit("El transporte EOS P2P no está incluido en esta compilación.")
		return false

	# Conservamos el lobby durante un reintento: el host nos autoriza porque ya somos miembros.
	await desconectar(false)
	es_host_previo = false
	ultima_conexion_ip = host_puid_or_ip.strip_edges()
	mi_peer_id = randi_range(1000, 90999)
	es_lan_previo = es_lan
	intento_relay_forzado = es_reintento
	_manejando_fallo_conexion = false

	if not es_lan:
		# Primer intento: AllowRelays (directa + relay). Reintento: ForceRelays.
		_aplicar_control_relay_inteligente(es_reintento)
		eos_peer = ClassDB.instantiate("EOSGMultiplayerPeer")
		var eos_error = eos_peer.create_client(EOS_P2P_SOCKET_ID, ultima_conexion_ip)
		if eos_error != OK:
			print("[RedManager ERROR] Error al iniciar cliente EOS P2P: ", eos_error)
			status_webrtc_changed.emit("No se pudo iniciar el cliente EOS P2P.")
			eos_peer = null
			return false
		_conectar_eventos_peer_eos(eos_peer)
		print("[RedManager] Cliente EOS P2P iniciado. Host PUID: ", _id_puid_corto(ultima_conexion_ip))
	else:
		eos_peer = ENetMultiplayerPeer.new()
		var lan_error = eos_peer.create_client(ultima_conexion_ip, PORT)
		if lan_error != OK:
			print("[RedManager ERROR] Error al iniciar cliente LAN: ", lan_error)
			status_webrtc_changed.emit("No se pudo iniciar el cliente LAN.")
			eos_peer = null
			return false

	multiplayer.multiplayer_peer = eos_peer
	_conectando = true
	_tiempo_conexion = 0
	_timer_conexion.start()
	_actualizar_ui_conexion_loop()
	return true

func _actualizar_ui_conexion_loop():
	while _conectando and is_inside_tree():
		if es_lan_previo:
			status_webrtc_changed.emit("Estableciendo conexión (LAN)... " + str(_tiempo_conexion) + "s")
		else:
			var eos_manager = get_tree().root.get_node_or_null("EosManager")
			var nat_type: int = eos_manager.cached_nat_type if eos_manager else 0
			var info_tipo = "Epic Relay" if intento_relay_forzado or nat_type == 3 or nat_type == 0 else "P2P directo"
			status_webrtc_changed.emit("Estableciendo conexión (" + info_tipo + ")... " + str(_tiempo_conexion) + "s")
		
		await get_tree().create_timer(1.0).timeout
		_tiempo_conexion += 1

func reconectar_a_partida():
	if ultima_conexion_ip.is_empty():
		return
	if es_host_previo:
		crear_partida(es_lan_previo)
	else:
		unirse_a_partida(ultima_conexion_ip, es_lan_previo)

func desconectar(leave_lobby = true):
	print("[RedManager] Desconectando red...")
	_conectando = false
	_timer_conexion.stop()
	_solicitudes_p2p_pendientes.clear()
	detener_lan_broadcaster()
	detener_lan_listener()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	if leave_lobby:
		var EosManager = get_tree().root.get_node_or_null("EosManager")
		if is_instance_valid(EosManager) and EosManager.has_method("leave_current_lobby"):
			await EosManager.leave_current_lobby()
	
	eos_peer = null
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
		if nivel_actual_index < NIVELES_HISTORIA_COUNT:
			_cargar_nivel_todos(NIVELES[nivel_actual_index])
		else:
			_cargar_nivel_todos("res://scenes/ui/menu_inicio.tscn")
	else:
		_cargar_nivel_todos("res://scenes/ui/menu_inicio.tscn")

func reintentar_nivel_actual():
	if not multiplayer.is_server(): return
	if nivel_actual_index >= 0 and nivel_actual_index < NIVELES.size():
		_cargar_nivel_todos(NIVELES[nivel_actual_index])
	else:
		_cargar_nivel_todos(NIVELES[0])

func mostrar_pantalla_resultados():
	rpc_mostrar_pantalla_resultados.rpc()
	rpc_mostrar_pantalla_resultados()

@rpc("any_peer", "call_local", "reliable")
func rpc_mostrar_pantalla_resultados():
	var escena_res = load("res://scenes/ui/pantalla_resultados.tscn")
	if escena_res and get_tree() and get_tree().current_scene:
		if not get_tree().current_scene.has_node("PantallaResultados"):
			var inst = escena_res.instantiate()
			get_tree().current_scene.add_child(inst)

func _cargar_nivel_todos(path: String):
	if path.ends_with(".tscn") and not "menu_inicio" in path:
		ultimo_nivel_path = path
		puede_reconectarse = true
	rpc_cargar_nivel.rpc(path)
	rpc_cargar_nivel(path)

@rpc("reliable")
func rpc_cargar_nivel(path: String):
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	_intentar_asignar_autoridades()

@rpc("any_peer", "call_local", "reliable")
func rpc_seleccionar_personaje(personaje: String):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
	
	if sender_id == multiplayer.get_unique_id():
		ultimo_personaje = personaje
		
	for peer in peer_personajes:
		if peer != sender_id and peer_personajes[peer] == personaje and personaje != "":
			return
			
	peer_personajes[sender_id] = personaje
	personajes_actualizados.emit(peer_personajes)
	
	if multiplayer.is_server():
		rpc("rpc_sincronizar_personajes", peer_personajes)

@rpc("any_peer", "call_local", "reliable")
func rpc_solicitar_reconexion(personaje_solicitado: String):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
		
	if not multiplayer.is_server():
		return
		
	for p in peer_personajes.keys():
		if peer_personajes[p] == personaje_solicitado:
			peer_personajes.erase(p)
			
	peer_personajes[sender_id] = personaje_solicitado
	peer_listos[sender_id] = true
	
	rpc("rpc_sincronizar_personajes", peer_personajes)
	_intentar_asignar_autoridades()
	
	var escena_actual = get_tree().current_scene
	if escena_actual and escena_actual.scene_file_path.ends_with(".tscn") and not "menu_inicio" in escena_actual.scene_file_path:
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
func rpc_establecer_nivel(index: int):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
		
	if sender_id == get_lider_peer_id():
		nivel_actual_index = index
		if multiplayer.is_server():
			rpc("rpc_sincronizar_nivel", index)

@rpc("any_peer", "call_local", "reliable")
func rpc_solicitar_inicio(sync_modo: String, idx_nivel: int):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
		
	if sender_id == get_lider_peer_id() and multiplayer.is_server():
		modo_juego = sync_modo
		nivel_actual_index = idx_nivel
		if modo_juego == "libre":
			if idx_nivel >= 0 and idx_nivel < NIVELES.size():
				_cargar_nivel_todos(NIVELES[idx_nivel])
			else:
				_cargar_nivel_todos(NIVELES[0])
		else:
			_cargar_nivel_todos(NIVELES[0])

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

@rpc("reliable")
func rpc_sincronizar_nivel(index: int):
	nivel_actual_index = index

func _on_peer_connected(id):
	status_webrtc_changed.emit("¡Conexión establecida!")
	if multiplayer.is_server():
		peer_personajes[id] = ""
		peer_listos[id] = false
		rpc_sincronizar_estado_inicial.rpc_id(id, peer_personajes, modo_juego, peer_listos)
		rpc("rpc_sincronizar_personajes", peer_personajes)
		rpc("rpc_sincronizar_listos", peer_listos)
		
		if iniciar_directo_p2p:
			await get_tree().create_timer(1.0).timeout
			if peer_personajes.size() >= 2:
				modo_juego = p2p_modo_inicial
				nivel_actual_index = p2p_nivel_inicial
				iniciar_directo_p2p = false
				rpc_solicitar_inicio(modo_juego, nivel_actual_index)

func _on_peer_disconnected(id):
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
	print("[RedManager] Conectado al servidor con éxito.")
	_conectando = false
	_timer_conexion.stop()
	intento_relay_forzado = false
	mi_peer_id = multiplayer.get_unique_id()
	conexion_establecida.emit()
	status_webrtc_changed.emit("¡Conectado!")
	
	if puede_reconectarse and not ultimo_personaje.is_empty():
		rpc_solicitar_reconexion.rpc(ultimo_personaje)
	elif iniciar_directo_p2p:
		rpc_seleccionar_personaje.rpc(p2p_personaje_elegido)
		rpc_establecer_listo.rpc(true)

func _on_connection_failed():
	if _manejando_fallo_conexion:
		return
	_manejando_fallo_conexion = true
	print("[RedManager] Falló la conexión. Host PUID: ", _id_puid_corto(ultima_conexion_ip), " | es_host: ", es_host_previo, " | es_lan: ", es_lan_previo)
	_conectando = false
	_timer_conexion.stop()
	
	# Si el primer intento (AllowRelays) falla, reintentamos con ForceRelays.
	# El host recrea su servidor para que el peer EOS no quede en estado sucio.
	if not es_lan_previo and not es_host_previo and not intento_relay_forzado:
		status_webrtc_changed.emit("Conexión directa falló. Reintentando con Epic Relay...")
		print("[RedManager] AllowRelays falló. Reintentando con ForceRelays...")
		var host_puid = ultima_conexion_ip
		await _solicitar_relay_al_host_async()
		await desconectar(false)
		await get_tree().create_timer(P2P_RELAY_COORDINATION_WAIT_SECONDS).timeout
		_manejando_fallo_conexion = false
		await unirse_a_partida(host_puid, false, true)
		return
	
	await desconectar(true)
	intento_relay_forzado = false
	_manejando_fallo_conexion = false
	conexion_perdida.emit()
	status_webrtc_changed.emit("No se pudo establecer la conexión. Revisa el log de EOS.")

func _on_timeout_conexion():
	if not _conectando:
		return
	print("[RedManager] Timeout de conexión. LAN: ", es_lan_previo)
	_on_connection_failed()

func _on_server_disconnected():
	if _manejando_fallo_conexion:
		return
	desconectar(true)
	conexion_perdida.emit()


func _on_eos_incoming_connection_request(data: Dictionary) -> void:
	var remote_puid := str(data.get("remote_user_id", ""))
	print("[RedManager] Solicitud P2P entrante: ", _id_puid_corto(remote_puid))
	if remote_puid.is_empty():
		return
	
	if eos_peer != null and is_instance_valid(eos_peer):
		# Aceptar la conexión de inmediato. Validar si están en el lobby causaba
		# cuellos de botella y timeouts (ClosedRemotely). La seguridad ya está dada
		# porque el remote_puid debe conocer nuestro PUID (obtenido del lobby).
		eos_peer.accept_connection_request(remote_puid)
		print("[RedManager] Solicitud P2P aceptada automáticamente para: ", _id_puid_corto(remote_puid))
		_solicitudes_p2p_pendientes.erase(remote_puid)


func _es_miembro_del_lobby_eos(product_user_id: String) -> bool:
	var eos_manager = get_tree().root.get_node_or_null("EosManager")
	if not eos_manager or eos_manager.current_lobby == null or not is_instance_valid(eos_manager.current_lobby):
		return false
	return eos_manager.current_lobby.get_member_by_product_user_id(product_user_id) != null


func _miembro_solicita_relay_forzado(product_user_id: String) -> bool:
	var eos_manager = get_tree().root.get_node_or_null("EosManager")
	if not eos_manager or eos_manager.current_lobby == null or not is_instance_valid(eos_manager.current_lobby):
		return false
	var member = eos_manager.current_lobby.get_member_by_product_user_id(product_user_id)
	if member == null:
		return false
	var relay_attribute: Dictionary = member.get_attribute(P2P_RELAY_REQUEST_MEMBER_ATTRIBUTE)
	return str(relay_attribute.get("value", "")) == P2P_RELAY_REQUEST_VALUE


func _solicitar_relay_al_host_async() -> void:
	var eos_manager = get_tree().root.get_node_or_null("EosManager")
	if not eos_manager or eos_manager.current_lobby == null or not is_instance_valid(eos_manager.current_lobby):
		print("[RedManager] No se pudo coordinar relay: no hay lobby EOS activo.")
		return

	var lobby = eos_manager.current_lobby
	var added: bool = lobby.add_current_member_attribute(P2P_RELAY_REQUEST_MEMBER_ATTRIBUTE, P2P_RELAY_REQUEST_VALUE)
	if not added:
		print("[RedManager] No se pudo publicar la solicitud de Epic Relay en el lobby.")
		return

	var updated: bool = await lobby.update_async()
	if updated:
		print("[RedManager] Solicitud de Epic Relay publicada para el host.")
	else:
		print("[RedManager] Falló al publicar la solicitud de Epic Relay; se reintentará de todos modos.")


func _on_eos_peer_connection_established(data: Dictionary) -> void:
	var network_type: int = int(data.get("network_type", 0))
	var route_name := "Epic Relay" if network_type == 2 else "ruta directa"
	print("[RedManager] Transporte EOS establecido por ", route_name, ". Datos: ", data)
	status_webrtc_changed.emit("Transporte EOS listo (" + route_name + ").")


func _on_eos_peer_connection_interrupted(data: Dictionary) -> void:
	print("[RedManager] Conexión EOS interrumpida: ", data)
	status_webrtc_changed.emit("La conexión EOS se interrumpió; esperando recuperación...")


func _on_eos_peer_connection_closed(data: Dictionary) -> void:
	print("[RedManager] Conexión EOS cerrada: ", data)
	var remote_puid := str(data.get("remote_user_id", ""))
	_solicitudes_p2p_pendientes.erase(remote_puid)
	
	var close_reason := int(data.get("reason", 0))
	# Si cualquier fallo P2P ocurre en el host (excepto cierre voluntario reason 1),
	# recreamos completamente el servidor P2P para que el cliente pueda
	# reconectarse a un peer limpio. El peer EOS mantiene estado interno de
	# conexiones previas que impide aceptar reconexiones del mismo PUID.
	if not es_lan_previo and es_host_previo and close_reason != 1:
		print("[RedManager] Conexión P2P cerrada en host (reason ", close_reason, "); recreando servidor...")
		_recrear_servidor_eos_para_reintento.call_deferred()


func _recrear_servidor_eos_para_reintento() -> void:
	if not es_host_previo or es_lan_previo:
		return
	if not ClassDB.class_exists("EOSGMultiplayerPeer"):
		return
	
	# Cerrar el peer actual del host sin salir del lobby
	_solicitudes_p2p_pendientes.clear()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	eos_peer = null
	
	# Aplicar ForceRelays y recrear el servidor
	_aplicar_control_relay_inteligente(true)
	eos_peer = ClassDB.instantiate("EOSGMultiplayerPeer")
	var eos_error = eos_peer.create_server(EOS_P2P_SOCKET_ID)
	if eos_error != OK:
		print("[RedManager ERROR] No se pudo recrear el servidor EOS P2P: ", eos_error)
		eos_peer = null
		return
	_conectar_eventos_peer_eos(eos_peer)
	multiplayer.multiplayer_peer = eos_peer
	intento_relay_forzado = true
	print("[RedManager] Servidor EOS P2P recreado con ForceRelays. Listo para reintento del cliente.")


func _id_puid_corto(product_user_id: String) -> String:
	return product_user_id.left(8) + "…" if product_user_id.length() > 8 else product_user_id

func get_local_ip() -> String:
	var ips = IP.get_local_addresses()
	var valid_ip = ""
	for ip in ips:
		# Ignorar IPv6, localhost y APIPA
		if not ":" in ip and ip != "127.0.0.1" and not ip.begins_with("169.254."):
			valid_ip = ip
			# Preferir fuertemente IPs privadas estándar (LAN)
			if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
				return ip
	return valid_ip if valid_ip != "" else "127.0.0.1"

func get_lider_peer_id() -> int:
	return 1

func iniciar_lan_broadcaster():
	var lan = get_node_or_null("LanDiscovery")
	if lan:
		var nombre_sala = "Sala de " + (ultimo_personaje if ultimo_personaje != "" else "Host")
		lan.configurar_broadcast(get_local_ip(), PORT, nombre_sala)
		lan.iniciar_broadcaster()

func detener_lan_broadcaster():
	var lan = get_node_or_null("LanDiscovery")
	if lan:
		lan.detener_broadcaster()

func iniciar_lan_listener():
	var lan = get_node_or_null("LanDiscovery")
	if lan:
		lan.iniciar_listener()

func detener_lan_listener():
	var lan = get_node_or_null("LanDiscovery")
	if lan:
		lan.detener_listener()

# --- Sistema de Amigos Persistente (delegado a AmigosManager) ---

func cargar_amigos() -> Dictionary:
	return AmigosManager.cargar()

func guardar_amigos(amigos: Dictionary):
	AmigosManager.guardar(amigos)

func agregar_amigo(nombre: String, ip: String):
	AmigosManager.agregar(nombre, ip)

func eliminar_amigo(nombre: String):
	AmigosManager.eliminar(nombre)
