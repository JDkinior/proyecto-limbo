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
	"res://scenes/levels/mundo_pruebas.tscn",
	"res://scenes/levels/nivel 2.tscn"
]

var jugador_vivo: Jugador
var fantasma: Fantasma

# Estado del Lobby
var peer_personajes: Dictionary = {}  # {peer_id: "jugador" | "fantasma" | ""}
var peer_listos: Dictionary = {}      # {peer_id: listo}
var modo_juego: String = "historia"    # "historia" | "libre"
var nivel_actual_index: int = 0

# UPnP
var upnp_active: bool = false
var ip_publica: String = ""

# --- NUEVOS CAMPOS: Salas Online e Integración P2P ---
var es_servidor_online_dedicado: bool = false
var salas: Dictionary = {} # { nombre_sala: { "host_id": int, "guest_id": int, "modo": String, "nivel_index": int, "char_host": String, "char_guest": String, "ready_guest": bool } }
var mi_sala_actual: String = ""

var iniciar_directo_p2p: bool = false
var p2p_modo_inicial: String = "historia"
var p2p_nivel_inicial: int = 0
var p2p_personaje_elegido: String = ""

# --- NUEVOS CAMPOS: Autodescubrimiento LAN (UDP) ---
signal lan_server_found(ip: String, port: int, name: String)
const LAN_DISCOVERY_PORT = 7001
var udp_broadcaster: PacketPeerUDP
var udp_listener: PacketPeerUDP
var lan_broadcast_timer: float = 0.0
var lan_servers_discovered: Dictionary = {} # { ip: { name: String, port: int, time: float } }

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	# Autoiniciar servidor si se ejecuta en modo headless
	if DisplayServer.get_name() == "headless" or OS.get_cmdline_args().has("--server"):
		print("[Servidor Dedicado] Detectado modo headless. Iniciando servidor en puerto ", PORT)
		await get_tree().process_frame
		crear_partida_online_server()

func _process(delta):
	# Procesar LAN Broadcaster (Envia paquetes si somos Host local)
	if udp_broadcaster:
		lan_broadcast_timer += delta
		if lan_broadcast_timer >= 1.5:
			lan_broadcast_timer = 0.0
			var info = {
				"ip": get_local_ip(),
				"port": PORT,
				"name": "Partida de " + OS.get_environment("USERNAME")
			}
			var packet = JSON.stringify(info).to_utf8_buffer()
			udp_broadcaster.put_packet(packet)
			
	# Procesar LAN Listener (Escucha paquetes si buscamos en LAN)
	if udp_listener:
		while udp_listener.get_available_packet_count() > 0:
			var packet = udp_listener.get_packet()
			var ip = udp_listener.get_packet_ip()
			var port = udp_listener.get_packet_port()
			var data_str = packet.get_string_from_utf8()
			var data = JSON.parse_string(data_str)
			if data and typeof(data) == TYPE_DICTIONARY:
				var server_ip = ip
				var server_name = data.get("name", "Servidor Local")
				var server_port = port
				
				# Evitar agregarse a uno mismo
				if server_ip != get_local_ip():
					lan_servers_discovered[server_ip] = {
						"name": server_name,
						"port": server_port,
						"time": Time.get_ticks_msec()
					}
					lan_server_found.emit(server_ip, server_port, server_name)
		
		# Limpiar servidores locales obsoletos (más de 5 segundos sin recibir paquetes)
		var ahora = Time.get_ticks_msec()
		var keys = lan_servers_discovered.keys()
		for k in keys:
			if ahora - lan_servers_discovered[k]["time"] > 5000:
				lan_servers_discovered.erase(k)

func registrar_jugador(p: CharacterBase):
	if p is Fantasma: 
		fantasma = p
	elif p is Jugador:
		jugador_vivo = p
	
	_intentar_asignar_autoridades()

func _intentar_assignar_autoridades():
	_intentar_asignar_autoridades() # Alias por si acaso

func _intentar_asignar_autoridades():
	if not jugador_vivo or not fantasma: return
	
	if not multiplayer.multiplayer_peer or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		# Modo local de prueba o sin red: el Host controla a ambos o al jugador vivo
		jugador_vivo.set_multiplayer_authority(1)
		fantasma.set_multiplayer_authority(1)
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

func crear_partida():
	desconectar()
	upnp_setup()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, 2) # Máximo 2 jugadores
	if error != OK:
		print("Error al crear servidor: ", error)
		if upnp_active:
			upnp_cleanup()
		return
		
	multiplayer.multiplayer_peer = peer
	
	peer_personajes.clear()
	peer_listos.clear()
	modo_juego = "historia"
	nivel_actual_index = 0
	
	# El Host se añade a sí mismo al lobby
	peer_personajes[1] = ""
	peer_listos[1] = false
	
	# Iniciar broadcaster de LAN si no es el servidor online dedicado
	if not es_servidor_online_dedicado:
		iniciar_lan_broadcaster()
	
	conexion_establecida.emit()
	if ip_publica != "":
		print("[RedManager] Servidor local iniciado. IP Local: ", get_local_ip(), " | IP Pública: ", ip_publica)
	else:
		print("[RedManager] Servidor local iniciado. IP Local: ", get_local_ip())

	# Si venimos de la transición P2P online, autoseleccionar personaje
	if iniciar_directo_p2p:
		print("[RedManager] Transición P2P (Host) - Autoseleccionando personaje: ", p2p_personaje_elegido)
		await get_tree().process_frame
		rpc_seleccionar_personaje.rpc(p2p_personaje_elegido)

func unirse_a_partida(ip: String):
	desconectar()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, PORT)
	if error != OK:
		print("Error al conectar: ", error)
		return
		
	multiplayer.multiplayer_peer = peer
	print("[RedManager] Intentando conectar a ", ip, "...")

func crear_partida_online_server():
	desconectar()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, 100) # Máximo 100 jugadores para salas
	if error != OK:
		print("[Servidor Dedicado] Error al crear el servidor online: ", error)
		return
	multiplayer.multiplayer_peer = peer
	es_servidor_online_dedicado = true
	salas.clear()
	print("[Servidor Dedicado] Servidor iniciado en puerto ", PORT, " para albergar salas online.")

func desconectar():
	detener_lan_broadcaster()
	detener_lan_listener()
	if upnp_active:
		upnp_cleanup()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer = null
	peer_personajes.clear()
	peer_listos.clear()
	jugador_vivo = null
	fantasma = null
	mi_sala_actual = ""

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

# Función auxiliar que garantiza la carga del nivel en TODAS las instancias
# Envía el RPC a los peers remotos y ejecuta localmente de forma explícita
func _cargar_nivel_todos(path: String):
	print("[RedManager] Enviando carga de nivel a todos: ", path)
	rpc_cargar_nivel.rpc(path)  # Enviar a peers remotos
	rpc_cargar_nivel(path)      # Ejecutar localmente de forma explícita

@rpc("reliable")
func rpc_cargar_nivel(path: String):
	print("[RedManager] Cargando nivel: ", path)
	get_tree().change_scene_to_file(path)

# --- Métodos de Lobby (RPCs para P2P / Local) ---

@rpc("any_peer", "call_local", "reliable")
func rpc_seleccionar_personaje(personaje: String):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
	
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

@rpc("reliable")
func rpc_sincronizar_listos(sync_listos: Dictionary):
	peer_listos = sync_listos
	ready_estados_actualizados.emit(peer_listos)

@rpc("reliable")
func rpc_sincronizar_modo(sync_modo: String):
	modo_juego = sync_modo
	modo_juego_actualizado.emit(sync_modo)

# --- SISTEMA DE SALAS ONLINE (Solo usado conectado al servidor dedicado) ---

signal salas_actualizadas(salas: Dictionary)
signal sala_entrar(nombre_sala: String)
signal sala_salir()

@rpc("any_peer", "call_local", "reliable")
func rpc_crear_sala(nombre_sala: String):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
		
	if not multiplayer.is_server():
		return
		
	nombre_sala = nombre_sala.strip_edges()
	if nombre_sala.is_empty() or salas.has(nombre_sala):
		return
		
	salas[nombre_sala] = {
		"host_id": sender_id,
		"guest_id": 0,
		"modo": "historia",
		"nivel_index": 0,
		"char_host": "",
		"char_guest": "",
		"ready_guest": false
	}
	
	print("[Servidor Dedicado] Sala creada: ", nombre_sala, " por peer ", sender_id)
	rpc("rpc_sincronizar_salas", salas)
	rpc_unirse_a_sala.rpc_id(sender_id, nombre_sala)

@rpc("any_peer", "call_local", "reliable")
func rpc_unirse_a_sala(nombre_sala: String):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
		
	if not multiplayer.is_server():
		mi_sala_actual = nombre_sala
		sala_entrar.emit(nombre_sala)
		return
		
	if not salas.has(nombre_sala):
		return
		
	var sala = salas[nombre_sala]
	if sala["host_id"] == sender_id:
		return
	if sala["guest_id"] != 0 and sala["guest_id"] != sender_id:
		return
		
	sala["guest_id"] = sender_id
	print("[Servidor Dedicado] Peer ", sender_id, " se unió a la sala: ", nombre_sala)
	rpc("rpc_sincronizar_salas", salas)
	rpc_unirse_a_sala.rpc_id(sender_id, nombre_sala)

@rpc("any_peer", "call_local", "reliable")
func rpc_salir_de_sala():
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
		
	if not multiplayer.is_server():
		mi_sala_actual = ""
		sala_salir.emit()
		return
		
	for nombre in salas.keys():
		var sala = salas[nombre]
		if sala["host_id"] == sender_id:
			salas.erase(nombre)
			print("[Servidor Dedicado] Sala eliminada por salida del host: ", nombre)
			if sala["guest_id"] != 0:
				rpc_salir_de_sala.rpc_id(sala["guest_id"])
			break
		elif sala["guest_id"] == sender_id:
			sala["guest_id"] = 0
			sala["char_guest"] = ""
			sala["ready_guest"] = false
			print("[Servidor Dedicado] Guest salió de la sala: ", nombre)
			break
			
	rpc("rpc_sincronizar_salas", salas)
	rpc_salir_de_sala.rpc_id(sender_id)

@rpc("reliable")
func rpc_sincronizar_salas(salas_sinc: Dictionary):
	salas = salas_sinc
	salas_actualizadas.emit(salas)

@rpc("any_peer", "call_local", "reliable")
func rpc_actualizar_seleccion_sala(personaje: String, listo: bool, modo: String, idx_nivel: int):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
		
	if not multiplayer.is_server():
		return
		
	for nombre in salas:
		var sala = salas[nombre]
		if sala["host_id"] == sender_id:
			sala["char_host"] = personaje
			sala["modo"] = modo
			sala["nivel_index"] = idx_nivel
			rpc("rpc_sincronizar_salas", salas)
			break
		elif sala["guest_id"] == sender_id:
			sala["char_guest"] = personaje
			sala["ready_guest"] = listo
			rpc("rpc_sincronizar_salas", salas)
			break

@rpc("any_peer", "call_local", "reliable")
func rpc_solicitar_inicio_p2p():
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
		
	if not multiplayer.is_server():
		return
		
	for nombre in salas.keys():
		var sala = salas[nombre]
		if sala["host_id"] == sender_id:
			if sala["guest_id"] != 0 and sala["ready_guest"] and sala["char_host"] != "" and sala["char_guest"] != "":
				var host_ip = ""
				var peer_api = multiplayer.multiplayer_peer as ENetMultiplayerPeer
				if peer_api:
					var p = peer_api.get_peer(sender_id)
					if p:
						host_ip = p.get_remote_address()
						
				if host_ip.is_empty() or host_ip == "127.0.0.1":
					host_ip = "127.0.0.1"
					
				print("[Servidor Dedicado] Iniciando transición P2P. Host IP: ", host_ip)
				
				# Enviar orden de transición a ambos
				rpc_iniciar_p2p_cliente.rpc_id(sala["guest_id"], host_ip, sala["char_guest"], sala["modo"], sala["nivel_index"])
				rpc_iniciar_p2p_cliente.rpc_id(sala["host_id"], "", sala["char_host"], sala["modo"], sala["nivel_index"])
				
				# Remover sala
				salas.erase(nombre)
				rpc("rpc_sincronizar_salas", salas)
				break

@rpc("reliable")
func rpc_iniciar_p2p_cliente(ip_host: String, personaje: String, modo: String, idx_nivel: int):
	print("[RedManager] Iniciando transición P2P. Host IP: '", ip_host, "', personaje: ", personaje)
	iniciar_directo_p2p = true
	p2p_personaje_elegido = personaje
	p2p_modo_inicial = modo
	p2p_nivel_inicial = idx_nivel
	
	desconectar()
	
	await get_tree().create_timer(0.6 if ip_host != "" else 0.1).timeout
	
	if ip_host == "":
		crear_partida()
	else:
		var target_ip = ip_host
		if target_ip == "127.0.0.1" or target_ip.is_empty():
			target_ip = ADDRESS
		unirse_a_partida(target_ip)

# --- Manejadores de Red ---

func _on_peer_connected(id):
	print("[RedManager] Peer conectado: ", id)
	if multiplayer.is_server():
		if es_servidor_online_dedicado:
			rpc_sincronizar_salas.rpc_id(id, salas)
			return
			
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
	if es_servidor_online_dedicado:
		var changed = false
		for nombre in salas.keys():
			var sala = salas[nombre]
			if sala["host_id"] == id:
				salas.erase(nombre)
				changed = true
				print("[Servidor Dedicado] Sala eliminada por desconexión del host: ", nombre)
				if sala["guest_id"] != 0:
					rpc_salir_de_sala.rpc_id(sala["guest_id"])
			elif sala["guest_id"] == id:
				sala["guest_id"] = 0
				sala["char_guest"] = ""
				sala["ready_guest"] = false
				changed = true
				print("[Servidor Dedicado] Slot liberado en sala ", nombre, " por desconexión del guest")
		if changed:
			rpc("rpc_sincronizar_salas", salas)
		return
		
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
	print("[RedManager] Conectado al servidor con ID: ", mi_id)
	conexion_establecida.emit()
	
	if iniciar_directo_p2p:
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
	if not multiplayer.multiplayer_peer or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return 1
	
	var servidor_es_dedicado = false
	if peer_personajes.has(1):
		if peer_personajes[1] == "":
			servidor_es_dedicado = true
	else:
		servidor_es_dedicado = true
	
	if not servidor_es_dedicado:
		return 1
	
	var peers_jugadores: Array = []
	for peer_id in peer_personajes:
		if peer_id != 1:
			peers_jugadores.append(peer_id)
	
	if peers_jugadores.is_empty():
		return 1
	peers_jugadores.sort()
	return peers_jugadores[0]

# --- Sistema de Amigos Persistente ---

func cargar_amigos() -> Dictionary:
	if not FileAccess.file_exists(AMIGOS_FILE):
		return {}
	var file = FileAccess.open(AMIGOS_FILE, FileAccess.READ)
	if not file:
		return {}
	var text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var error = json.parse(text)
	if error == OK:
		if typeof(json.data) == TYPE_DICTIONARY:
			return json.data
	return {}

func guardar_amigos(amigos: Dictionary):
	var file = FileAccess.open(AMIGOS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(amigos, "\t"))
		file.close()

func agregar_amigo(nombre: String, ip: String):
	var amigos = cargar_amigos()
	amigos[nombre] = ip
	guardar_amigos(amigos)

func eliminar_amigo(nombre: String):
	var amigos = cargar_amigos()
	if amigos.has(nombre):
		amigos.erase(nombre)
		guardar_amigos(amigos)

# --- Configuración UPNP ---

func upnp_setup():
	ip_publica = ""
	upnp_active = false
	
	var upnp = UPNP.new()
	var discover_result = upnp.discover(2000, 2, "LNDP")
	
	if discover_result == UPNP.UPNP_RESULT_SUCCESS:
		if upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
			var map_result = upnp.add_port_mapping(PORT, PORT, "ProyectoLimboUDP", "UDP")
			if map_result == UPNP.UPNP_RESULT_SUCCESS:
				ip_publica = upnp.query_external_address()
				upnp_active = true
				print("[UPNP] Redirección automática de puerto UDP ", PORT, " establecida con éxito.")
				return
			else:
				print("[UPNP] Error al mapear puerto: ", map_result)
		else:
			print("[UPNP] No se encontró una puerta de enlace (Gateway) válida.")
	else:
		print("[UPNP] Descubrimiento de dispositivos UPNP falló con código: ", discover_result)

func upnp_cleanup():
	if not upnp_active: return
	
	var upnp = UPNP.new()
	var discover_result = upnp.discover(1000, 2, "LNDP")
	if discover_result == UPNP.UPNP_RESULT_SUCCESS:
		if upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
			var result = upnp.delete_port_mapping(PORT, "UDP")
			if result == UPNP.UPNP_RESULT_SUCCESS:
				print("[UPNP] Redirección de puerto UDP eliminada del router.")
			else:
				print("[UPNP] Error al eliminar redirección de puerto: ", result)
	upnp_active = false
	ip_publica = ""

# --- Métodos de Descubrimiento LAN ---

func iniciar_lan_broadcaster():
	detener_lan_broadcaster()
	udp_broadcaster = PacketPeerUDP.new()
	udp_broadcaster.set_broadcast_enabled(true)
	udp_broadcaster.set_dest_address("255.255.255.255", LAN_DISCOVERY_PORT)
	lan_broadcast_timer = 0.0
	print("[LAN] Emisor de descubrimiento iniciado.")

func detener_lan_broadcaster():
	if udp_broadcaster:
		udp_broadcaster.close()
		udp_broadcaster = null
		print("[LAN] Emisor de descubrimiento detenido.")

func iniciar_lan_listener():
	detener_lan_listener()
	lan_servers_discovered.clear()
	udp_listener = PacketPeerUDP.new()
	var err = udp_listener.bind(LAN_DISCOVERY_PORT)
	if err != OK:
		print("[LAN] Error al iniciar receptor de descubrimiento: ", err)
		udp_listener = null
	else:
		print("[LAN] Receptor de descubrimiento iniciado.")

func detener_lan_listener():
	if udp_listener:
		udp_listener.close()
		udp_listener = null
		print("[LAN] Receptor de descubrimiento iniciado.")
