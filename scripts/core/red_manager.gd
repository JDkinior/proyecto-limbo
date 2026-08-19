extends Node # Configurar como Autoload con nombre 'RedManager'

signal personajes_actualizados(peer_personajes: Dictionary)
signal ready_estados_actualizados(peer_listos: Dictionary)
signal modo_juego_actualizado(modo: String)
signal conexion_establecida()
signal conexion_perdida()
signal ping_actualizado(ms: int)
signal status_webrtc_changed(msg: String)
signal lan_server_found(ip: String, port: int, name: String)
signal personaje_solo_cambiado(nuevo_personaje: String)
signal transicion_camara_iniciada(origen: String, destino: String, duracion: float)
signal transicion_camara_completada(nuevo_personaje: String)
signal reino_cambiado(es_fantasma: bool)

const PORT = 7000
const EOS_P2P_SOCKET_ID = "limbop2pv1"
const ONLINE_CONNECTION_TIMEOUT_SECONDS := 60.0
const P2P_REQUEST_AUTHORIZATION_TIMEOUT_SECONDS := 12.0
const P2P_RELAY_COORDINATION_WAIT_SECONDS := 3.0
const DURACION_TRANSICION_CAMARA := 0.65
const NIVELES_HISTORIA_COUNT = 2
const NIVELES = [
	"res://scenes/levels/Nivel 1 _ El Despertar Separado.tscn",
	"res://scenes/levels/nivel 2.tscn",
	"res://scenes/levels/mundo_pruebas.tscn"
]

var jugador_vivo: CharacterBase
var fantasma: CharacterBase

# Estado del Lobby y Modo Un Jugador
var peer_personajes: Dictionary = {}  # {peer_id: "jugador" | "fantasma" | ""}
var peer_listos: Dictionary = {}      # {peer_id: listo}
var modo_juego: String = "historia"    # "historia" | "libre"
var nivel_actual_index: int = 0

var es_un_jugador: bool = false
var personaje_activo_solo: String = "jugador" # "jugador" | "fantasma"
var reino_espiritual_activo: bool = false
var transicion_en_progreso: bool = false
var _paso_mitad_transicion: bool = false
var _camara_transicion: Camera3D = null
var _tween_transicion: Tween = null

func es_reino_espiritual_activo() -> bool:
	if es_un_jugador:
		return reino_espiritual_activo
	var mi_id = get_mi_peer_id()
	if peer_personajes.has(mi_id):
		return peer_personajes[mi_id] == "fantasma"
	return false

var ultima_conexion_ip: String = ""
var ultimo_personaje: String = ""
var ultimo_nivel_path: String = ""
var es_host_previo: bool = false
var puede_reconectarse: bool = false
var es_lan_previo: bool = false
var _manejando_fallo_conexion := false

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

func _input(event: InputEvent) -> void:
	var es_offline = (multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	if es_un_jugador or es_offline:
		if event.is_action_pressed("cambiar_personaje") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_TAB or event.keycode == KEY_C or event.keycode == KEY_T)):
			if not transicion_en_progreso:
				alternar_personaje_un_jugador()
			get_viewport().set_input_as_handled()

func _process(delta):
	# Ya no necesitamos poll de webrtc_peer manualmente con EOS
	var lan_node = get_node_or_null("LanDiscovery") as LanDiscovery
	if lan_node:
		lan_servers_discovered = lan_node.servidores_descubiertos

func buscar_personajes_en_escena() -> void:
	var tree = get_tree()
	if not tree: return
	for node in tree.get_nodes_in_group("jugadores"):
		if node is CharacterBase:
			if node.is_in_group("fantasmas") or node.name.to_lower().contains("fantasma"):
				fantasma = node
			else:
				jugador_vivo = node
	for node in tree.get_nodes_in_group("vivos"):
		if node is CharacterBase:
			jugador_vivo = node
	for node in tree.get_nodes_in_group("fantasmas"):
		if node is CharacterBase:
			fantasma = node

func registrar_jugador(p: CharacterBase):
	if p.is_in_group("fantasmas") or p.name.to_lower().contains("fantasma"): 
		fantasma = p
	else:
		jugador_vivo = p
	
	_intentar_asignar_autoridades()

func _intentar_asignar_autoridades(preservar_rotacion: bool = false):
	if not is_instance_valid(jugador_vivo) or not is_instance_valid(fantasma):
		buscar_personajes_en_escena()
	if not is_instance_valid(jugador_vivo) or not is_instance_valid(fantasma):
		return
	
	var es_offline = (multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	if es_un_jugador or es_offline:
		es_un_jugador = true
		var es_jugador_activo = (personaje_activo_solo == "jugador")
		var auth_vivo = 1 if es_jugador_activo else 9999
		var auth_fant = 1 if not es_jugador_activo else 9999
		
		jugador_vivo.set_multiplayer_authority(auth_vivo)
		fantasma.set_multiplayer_authority(auth_fant)
		
		if not es_jugador_activo:
			jugador_vivo.sync_position = jugador_vivo.global_position
			jugador_vivo.sync_rotation = jugador_vivo.rotation
		else:
			fantasma.sync_position = fantasma.global_position
			fantasma.sync_rotation = fantasma.rotation
			
		var sync_vivo = jugador_vivo.get_node_or_null("MultiplayerSynchronizer")
		if sync_vivo: sync_vivo.set_multiplayer_authority(auth_vivo)
		var sync_fant = fantasma.get_node_or_null("MultiplayerSynchronizer")
		if sync_fant: sync_fant.set_multiplayer_authority(auth_fant)
		
		jugador_vivo.actualizar_visibilidad_local(preservar_rotacion)
		fantasma.actualizar_visibilidad_local(preservar_rotacion)
		_actualizar_interfaz_local()
		reino_espiritual_activo = not es_jugador_activo
		reino_cambiado.emit(reino_espiritual_activo)
		personaje_solo_cambiado.emit(personaje_activo_solo)
		print("[RedManager] Modo Un Jugador - Controlando: ", personaje_activo_solo)
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
	if not controles:
		var nodos_ui = get_tree().get_nodes_in_group("ui_tactil")
		if nodos_ui.size() > 0:
			controles = nodos_ui[0]

	if not controles or not controles.has_method("configurar_personaje_local"):
		return

	if es_un_jugador:
		if personaje_activo_solo == "fantasma" and is_instance_valid(fantasma):
			controles.configurar_personaje_local(fantasma)
		elif is_instance_valid(jugador_vivo):
			controles.configurar_personaje_local(jugador_vivo)
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


func _conectar_eventos_peer_eos(peer) -> void:
	# El plugin EOSG auto-acepta conexiones por defecto. Dejamos este
	# comportamiento activo para evitar condiciones de carrera con callbacks
	# manuales que producían ClosedRemotely en pruebas anteriores.
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

	var relay_str = "AllowRelays"
	var hp2p = get_tree().root.get_node_or_null("HP2P")
	if hp2p and hp2p.has_method("get_relay_control"):
		var rc = hp2p.get_relay_control()
		if typeof(rc) == TYPE_DICTIONARY and rc.get("relay_control") == 2:
			relay_str = "ForceRelays"
	
	if not es_lan:
		# El relay está en AllowRelays (por defecto) o ForceRelays si se alternó en la UI.
		eos_peer = ClassDB.instantiate("EOSGMultiplayerPeer")
		var eos_error = eos_peer.create_server(EOS_P2P_SOCKET_ID)
		if eos_error != OK:
			print("[RedManager ERROR] Error al crear servidor EOS P2P. Código de error de Godot: ", eos_error)
			status_webrtc_changed.emit("No se pudo abrir el servidor EOS P2P.")
			eos_peer = null
			return false
		_conectar_eventos_peer_eos(eos_peer)
		var eos_m = get_tree().root.get_node_or_null("EosManager")
		if eos_m and eos_m.has_method("log_diagnostic"):
			eos_m.log_diagnostic("[RedManager] Servidor EOS P2P creado (" + relay_str + "). Socket: " + EOS_P2P_SOCKET_ID)
		else:
			print("[RedManager] Servidor EOS P2P creado (" + relay_str + "). Socket: ", EOS_P2P_SOCKET_ID)
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
	_manejando_fallo_conexion = false

	var relay_str = "AllowRelays"
	var hp2p = get_tree().root.get_node_or_null("HP2P")
	if hp2p and hp2p.has_method("get_relay_control"):
		var rc = hp2p.get_relay_control()
		if typeof(rc) == TYPE_DICTIONARY and rc.get("relay_control") == 2:
			relay_str = "ForceRelays"
	
	if not es_lan:
		# El relay está en AllowRelays (por defecto) o ForceRelays si se alternó en la UI.
		eos_peer = ClassDB.instantiate("EOSGMultiplayerPeer")
		var eos_error = eos_peer.create_client(EOS_P2P_SOCKET_ID, ultima_conexion_ip)
		if eos_error != OK:
			print("[RedManager ERROR] Error al iniciar cliente EOS P2P. Código de error de Godot: ", eos_error)
			status_webrtc_changed.emit("No se pudo iniciar el cliente EOS P2P.")
			eos_peer = null
			return false
		_conectar_eventos_peer_eos(eos_peer)
		var eos_m = get_tree().root.get_node_or_null("EosManager")
		if eos_m and eos_m.has_method("log_diagnostic"):
			eos_m.log_diagnostic("[RedManager] Cliente EOS P2P iniciado (" + relay_str + "). Host PUID: " + _id_puid_corto(ultima_conexion_ip))
		else:
			print("[RedManager] Cliente EOS P2P iniciado (" + relay_str + "). Host PUID: ", _id_puid_corto(ultima_conexion_ip))
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
			status_webrtc_changed.emit("Estableciendo conexión P2P (EOS)... " + str(_tiempo_conexion) + "s")
		
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
	if _tween_transicion and _tween_transicion.is_running():
		_tween_transicion.kill()
		_tween_transicion = null
	if is_instance_valid(_camara_transicion):
		_camara_transicion.queue_free()
		_camara_transicion = null
	transicion_en_progreso = false

	es_un_jugador = false
	personaje_activo_solo = "jugador"
	_conectando = false
	_timer_conexion.stop()
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

func iniciar_un_jugador(nivel_idx: int = 0, personaje_inicial: String = "jugador") -> void:
	await desconectar(true)
	es_un_jugador = true
	personaje_activo_solo = personaje_inicial
	peer_personajes = {1: personaje_inicial}
	peer_listos = {1: true}
	mi_peer_id = 1
	modo_juego = "historia" if nivel_idx < NIVELES_HISTORIA_COUNT else "libre"
	nivel_actual_index = nivel_idx
	
	print("[RedManager] Iniciando Modo Un Jugador en nivel index: ", nivel_idx, " con personaje: ", personaje_inicial)
	if nivel_idx >= 0 and nivel_idx < NIVELES.size():
		_cargar_nivel_todos(NIVELES[nivel_idx])
	else:
		_cargar_nivel_todos(NIVELES[0])

func alternar_personaje_un_jugador() -> void:
	if not es_un_jugador or transicion_en_progreso:
		return

	if not is_instance_valid(jugador_vivo) or not is_instance_valid(fantasma):
		buscar_personajes_en_escena()

	if not is_instance_valid(jugador_vivo) or not is_instance_valid(fantasma):
		# Fallback si falta algún personaje
		if personaje_activo_solo == "jugador":
			personaje_activo_solo = "fantasma"
		else:
			personaje_activo_solo = "jugador"
		_intentar_asignar_autoridades()
		return

	_ejecutar_transicion_camara_un_jugador()

func _ejecutar_transicion_camara_un_jugador() -> void:
	var es_vivo_activo = (personaje_activo_solo == "jugador")
	var origen_char: CharacterBase = jugador_vivo if es_vivo_activo else fantasma
	var destino_char: CharacterBase = fantasma if es_vivo_activo else jugador_vivo
	var nuevo_personaje_str: String = "fantasma" if es_vivo_activo else "jugador"

	var cam_origen: Camera3D = origen_char.obtener_camara()
	var cam_destino: Camera3D = destino_char.obtener_camara()

	if not is_instance_valid(cam_origen) or not is_instance_valid(cam_destino):
		personaje_activo_solo = nuevo_personaje_str
		_intentar_asignar_autoridades()
		return

	# Alinear pivote del personaje destino detrás del personaje para mirar en la dirección hacia donde mira
	if is_instance_valid(destino_char.pivote_camara):
		destino_char.pivote_camara.top_level = true
		destino_char.pivote_camara.global_position = destino_char.global_position
		destino_char.objetivo_rotacion_y = destino_char.rotation.y
		destino_char.objetivo_rotacion_x = destino_char.PITCH_DEFECTO_CAMARA
		destino_char.pivote_camara.rotation.y = destino_char.objetivo_rotacion_y
		var arm_dest = destino_char.obtener_spring_arm()
		if is_instance_valid(arm_dest):
			arm_dest.rotation.x = destino_char.objetivo_rotacion_x
			arm_dest.add_excluded_object(destino_char.get_rid())

	var transform_inicio: Transform3D = cam_origen.global_transform
	var fov_inicio: float = cam_origen.fov

	# Crear cámara de vuelo de transición limpia
	if is_instance_valid(_camara_transicion):
		_camara_transicion.queue_free()

	_camara_transicion = Camera3D.new()
	_camara_transicion.name = "CamaraTransicionSuave"
	var escena = get_tree().current_scene
	if is_instance_valid(escena):
		escena.add_child(_camara_transicion)
	else:
		add_child(_camara_transicion)

	_camara_transicion.global_transform = transform_inicio
	_camara_transicion.fov = fov_inicio
	_camara_transicion.near = cam_origen.near
	_camara_transicion.far = cam_origen.far
	_camara_transicion.cull_mask = cam_origen.cull_mask
	_camara_transicion.environment = cam_origen.environment

	_camara_transicion.current = true
	cam_origen.current = false
	cam_destino.current = false

	transicion_en_progreso = true
	_paso_mitad_transicion = false
	reino_espiritual_activo = (personaje_activo_solo == "fantasma")
	transicion_camara_iniciada.emit(personaje_activo_solo, nuevo_personaje_str, DURACION_TRANSICION_CAMARA)

	if _tween_transicion and _tween_transicion.is_running():
		_tween_transicion.kill()

	_tween_transicion = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween_transicion.tween_method(
		func(progreso: float):
			_interpolar_transicion_camara(progreso, transform_inicio, fov_inicio, origen_char, destino_char),
		0.0,
		1.0,
		DURACION_TRANSICION_CAMARA
	)
	_tween_transicion.finished.connect(
		func():
			_completar_transicion_camara(nuevo_personaje_str, destino_char)
	)

func _interpolar_transicion_camara(progreso: float, trans_inicio: Transform3D, fov_inicio: float, _origen: CharacterBase, destino: CharacterBase) -> void:
	if not is_instance_valid(_camara_transicion) or not is_instance_valid(destino):
		return

	if is_instance_valid(destino.pivote_camara) and destino.pivote_camara.top_level:
		destino.pivote_camara.global_position = destino.global_position
		destino.pivote_camara.rotation.y = destino.objetivo_rotacion_y
		var arm = destino.obtener_spring_arm()
		if is_instance_valid(arm):
			arm.rotation.x = destino.objetivo_rotacion_x

	var cam_dest: Camera3D = destino.obtener_camara()
	if not is_instance_valid(cam_dest):
		return

	var trans_fin: Transform3D = cam_dest.global_transform
	var fov_fin: float = cam_dest.fov

	# Vuelo en arco suave tridimensional
	var p_start: Vector3 = trans_inicio.origin
	var p_end: Vector3 = trans_fin.origin
	var distancia: float = p_start.distance_to(p_end)
	var altura_arco: float = clampf(distancia * 0.12, 0.4, 3.2)
	var elevacion_arco: float = sin(progreso * PI) * altura_arco

	var pos_interpolada: Vector3 = p_start.lerp(p_end, progreso) + Vector3.UP * elevacion_arco

	# Interpolación de rotación mediante cuaterniones (Slerp) asegurando el camino más corto
	var q_start: Quaternion = trans_inicio.basis.get_rotation_quaternion().normalized()
	var q_end: Quaternion = trans_fin.basis.get_rotation_quaternion().normalized()
	if q_start.dot(q_end) < 0.0:
		q_end = -q_end
	var q_interpolada: Quaternion = q_start.slerp(q_end, progreso).normalized()

	_camara_transicion.global_transform = Transform3D(Basis(q_interpolada), pos_interpolada)

	# Pulso dinámico de FOV (+5.5° en el ápice)
	var fov_base: float = lerpf(fov_inicio, fov_fin, progreso)
	_camara_transicion.fov = fov_base + sin(progreso * PI) * 5.5

	# Cambio de dimensiones / plano a mitad de trayecto exacto
	if progreso >= 0.5 and not _paso_mitad_transicion:
		_paso_mitad_transicion = true
		var es_fant = destino.is_in_group("fantasmas") or destino.name.to_lower().contains("fantasma")
		reino_espiritual_activo = es_fant
		var mask_dest = destino.obtener_cull_mask_personaje() if destino.has_method("obtener_cull_mask_personaje") else 1048575
		var env_dest = destino.obtener_entorno_personaje() if destino.has_method("obtener_entorno_personaje") else null
		_camara_transicion.cull_mask = mask_dest
		if env_dest:
			_camara_transicion.environment = env_dest
		reino_cambiado.emit(es_fant)

func _completar_transicion_camara(nuevo_personaje: String, destino: CharacterBase) -> void:
	personaje_activo_solo = nuevo_personaje
	reino_espiritual_activo = (nuevo_personaje == "fantasma")
	transicion_en_progreso = false

	# Asignar autoridades de red / locales y actualizar HUD PRESERVANDO la rotación de cámara calculada
	_intentar_asignar_autoridades(true)

	if is_instance_valid(destino):
		var cam_dest: Camera3D = destino.obtener_camara()
		if is_instance_valid(cam_dest):
			cam_dest.current = true

	if is_instance_valid(_camara_transicion):
		_camara_transicion.current = false
		_camara_transicion.queue_free()
		_camara_transicion = null

	reino_cambiado.emit(reino_espiritual_activo)
	transicion_camara_completada.emit(nuevo_personaje)
	print("[RedManager] Transición de cámara completada sin saltos angulares. Controlando: ", nuevo_personaje)

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
	if not es_un_jugador and not multiplayer.is_server(): return
	if modo_juego == "historia":
		nivel_actual_index += 1
		if nivel_actual_index < NIVELES_HISTORIA_COUNT:
			_cargar_nivel_todos(NIVELES[nivel_actual_index])
		else:
			_cargar_nivel_todos("res://scenes/ui/menu_inicio.tscn")
	else:
		_cargar_nivel_todos("res://scenes/ui/menu_inicio.tscn")

func reintentar_nivel_actual():
	if not es_un_jugador and not multiplayer.is_server(): return
	if nivel_actual_index >= 0 and nivel_actual_index < NIVELES.size():
		_cargar_nivel_todos(NIVELES[nivel_actual_index])
	else:
		_cargar_nivel_todos(NIVELES[0])

func mostrar_pantalla_resultados():
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		rpc_mostrar_pantalla_resultados.rpc()
	else:
		rpc_mostrar_pantalla_resultados()

@rpc("any_peer", "call_local", "reliable")
func rpc_mostrar_pantalla_resultados():
	var escena_res = load("res://scenes/ui/pantalla_resultados.tscn")
	if not escena_res:
		return
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return
	var root_escena = tree.current_scene
	if root_escena.has_node("CanvasResultados") or root_escena.has_node("PantallaResultados"):
		return

	var canvas = CanvasLayer.new()
	canvas.name = "CanvasResultados"
	canvas.layer = 100
	var inst = escena_res.instantiate()
	canvas.add_child(inst)
	root_escena.add_child(canvas)
	print("[RedManager] Pantalla de resultados añadida en CanvasLayer (Capa 100).")

func _cargar_nivel_todos(path: String):
	if path.ends_with(".tscn") and not "menu_inicio" in path:
		ultimo_nivel_path = path
		puede_reconectarse = not es_un_jugador
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
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

	await desconectar(true)
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

func _on_eos_peer_connection_established(data: Dictionary) -> void:
	var network_type: int = int(data.get("network_type", 0))
	var route_name := "Epic Relay" if network_type == 2 else "ruta directa"
	
	var msg = "[RedManager] Transporte EOS establecido por " + route_name + ". Datos: " + str(data)
	var eos_m = get_tree().root.get_node_or_null("EosManager")
	if eos_m and eos_m.has_method("log_diagnostic"):
		eos_m.log_diagnostic(msg)
	else:
		print(msg)
		
	status_webrtc_changed.emit("Transporte EOS listo (" + route_name + ").")


func _on_eos_peer_connection_interrupted(data: Dictionary) -> void:
	print("[RedManager] Conexión EOS interrumpida: ", data)
	status_webrtc_changed.emit("La conexión EOS se interrumpió; esperando recuperación...")


func _on_eos_peer_connection_closed(data: Dictionary) -> void:
	print("[RedManager] Conexión EOS cerrada: ", data)


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
