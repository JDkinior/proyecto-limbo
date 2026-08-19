extends Node

## Punto único de inicialización de Epic Online Services.
## RedManager debe esperar `esperar_login_async()` antes de crear un peer EOS.

signal eos_inicializado
signal login_completado(success: bool)
signal estado_eos_actualizado(message: String)

var log_buffer: Array[String] = []
signal log_agregado(msg: String)

@export_group("Epic Online Services Credentials")
@export var product_name: String = "Proyecto Limbo"
@export var product_version: String = "1.0.0"
@export var product_id: String = "3dc843c12f224b21b3a403f9c2d64e80"
@export var sandbox_id: String = "1dbd33f99f5e49589e6019dc9654ae1e"
@export var deployment_id: String = "b6c5f3c60f6c41a5a7288cea96896e68"
@export var client_id: String = "xyza7891yjndkPiE33RkZ4xoAACeRvAi"
@export var client_secret: String = "j+BpEFk5FtSEESPJ1eExulCY5r3B74G3hISKCIniwHY"
@export var encryption_key: String = ""

const P2P_PACKET_QUEUE_BYTES := 4 * 1024 * 1024

var is_initialized := false
var is_logged_in := false
var initialization_finished := false
var login_finished := false
var initialization_error := ""
var local_product_user_id := ""
var current_lobby = null
var cached_nat_type: int = 0 # Unknown=0, Open=1, Moderate=2, Strict=3

var _initialization_started := false
var _nat_query_in_progress := false


func _ready() -> void:
	call_deferred("_iniciar_eos")


func _iniciar_eos() -> void:
	if _initialization_started:
		return
	_initialization_started = true
	_emitir_estado("Inicializando Epic Online Services...")

	var hplatform = get_tree().root.get_node_or_null("HPlatform")
	if not hplatform:
		_finalizar_inicializacion(false, "El autoload HPlatform de EOSG no está disponible.")
		return

	if not _credenciales_completas():
		_finalizar_inicializacion(false, "Faltan credenciales de Epic Online Services.")
		return

	var creds := HCredentials.new()
	creds.product_name = product_name
	creds.product_version = product_version
	creds.product_id = product_id
	creds.sandbox_id = sandbox_id
	creds.deployment_id = deployment_id
	creds.client_id = client_id
	creds.client_secret = client_secret
	creds.encryption_key = encryption_key

	var success: bool = await hplatform.setup_eos_async(creds)
	if not success:
		_finalizar_inicializacion(false, "EOS no pudo inicializarse. Revisa las credenciales, el Client Policy y el log de EOS.")
		return

	is_initialized = true
	initialization_finished = true
	eos_inicializado.emit()
	_emitir_estado("EOS inicializado. Iniciando sesión de juego...")
	print("[EOS Manager] EOS inicializado correctamente.")

	var hlog = get_tree().root.get_node_or_null("HLog")
	if hlog:
		hlog.log_level = hlog.LogLevel.INFO
	if not hplatform.log_msg.is_connected(_on_eos_log_msg):
		hplatform.log_msg.connect(_on_eos_log_msg)
	hplatform.set_eos_log_level(EOS.Logging.LogCategory.AllCategories, EOS.Logging.LogLevel.VeryVerbose)

	# Deshabilitar RTC Room en Lobbies para evitar conflictos de WebRTC con P2P
	var hlobbies = get_tree().root.get_node_or_null("HLobbies")
	if hlobbies:
		hlobbies.local_rtc_options = null

	_login_device_id()


func _credenciales_completas() -> bool:
	return not product_id.is_empty() and not sandbox_id.is_empty() and not deployment_id.is_empty() and not client_id.is_empty() and not client_secret.is_empty()


func _finalizar_inicializacion(success: bool, message: String) -> void:
	initialization_finished = true
	is_initialized = success
	initialization_error = message
	_emitir_estado(message)
	if not success:
		print("[EOS Manager ERROR] ", message)
		_finalizar_login(false)


func _on_eos_log_msg(msg: EOS.Logging.LogMessage) -> void:
	var text = msg.message
	var highlight = false
	if "GetTurnCredentials" in text or "Applying updated RTC Configuration" in text or "STUN" in text or "TURN" in text or "ICE" in text or "NAT" in text or "Relay" in text or "Port" in text:
		highlight = true

	var final_msg = ""
	if highlight:
		final_msg = "[⭐ DIAGNOSTIC] " + text
	elif msg.level >= EOS.Logging.LogLevel.Warning:
		final_msg = "[EOS WARN/ERR] " + text
	elif "P2P" in text or "Relay" in text or "Socket" in text or "LogEpic" in text or "LibRTC" in text or "Stomp" in text:
		final_msg = "[EOS NATIVE] " + text
	else:
		final_msg = "[EOS NATIVE] " + text
	
	print(final_msg)
	log_buffer.append(final_msg)
	log_agregado.emit(final_msg)

func log_diagnostic(msg: String) -> void:
	print(msg)
	log_buffer.append(msg)
	log_agregado.emit(msg)


func _login_device_id() -> void:
	var hauth = get_tree().root.get_node_or_null("HAuth")
	if not hauth or not hauth.has_method("login_anonymous_async"):
		_finalizar_login(false, "El autoload HAuth de EOSG no está disponible.")
		return

	print("[EOS Manager] Iniciando sesión anónima mediante EOS Connect (Device ID)...")
	var player_name := "Jugador_%03d" % randi_range(100, 999)
	var login_success: bool = await hauth.login_anonymous_async(player_name)
	if not login_success:
		# Un único reintento evita dejar la pantalla en espera infinita ante una pérdida puntual de red.
		await get_tree().create_timer(1.0).timeout
		login_success = await hauth.login_anonymous_async(player_name)

	if not login_success or str(hauth.product_user_id).is_empty():
		_finalizar_login(false, "No fue posible iniciar sesión en EOS Connect. Consulta el log de EOS.")
		return

	local_product_user_id = str(hauth.product_user_id)
	_finalizar_login(true, "Sesión EOS lista.")
	var log_str = "[EOS Manager] Login completado. Product User ID: " + _id_corto(local_product_user_id)
	log_diagnostic(log_str)
	precalentar_red_p2p()
	_limpiar_lobbies_huerfanos_async()


func _finalizar_login(success: bool, message := "") -> void:
	if login_finished:
		return
	login_finished = true
	is_logged_in = success
	if not message.is_empty():
		_emitir_estado(message)
	login_completado.emit(success)


## Espera de forma acotada a que EOS Connect haya proporcionado un Product User ID.
func esperar_login_async(timeout_seconds := 20.0) -> bool:
	if is_logged_in and not local_product_user_id.is_empty():
		return true

	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if login_finished:
			return is_logged_in and not local_product_user_id.is_empty()
		await get_tree().process_frame

	_emitir_estado("EOS tardó demasiado en iniciar sesión. Comprueba la conexión a Internet.")
	return false


func esta_listo_para_p2p() -> bool:
	return is_initialized and is_logged_in and not local_product_user_id.is_empty()


func precalentar_red_p2p() -> void:
	var hp2p = get_tree().root.get_node_or_null("HP2P")
	if not hp2p:
		print("[EOS Manager] HP2P no está disponible; no se puede preparar P2P.")
		return

	if hp2p.has_method("set_packet_queue_size"):
		var queue_result = hp2p.set_packet_queue_size(P2P_PACKET_QUEUE_BYTES, P2P_PACKET_QUEUE_BYTES)
		if not EOS.is_success(queue_result):
			log_diagnostic("[EOS Manager] No se pudo configurar la cola P2P: " + EOS.result_str(queue_result))

	# Por defecto, usamos ForceRelays para garantizar conexión a través de CGNAT (Datos Móviles) y VPNs.
	set_relay_mode(2) # 1 = AllowRelays, 2 = ForceRelays
	actualizar_nat_async()

func set_relay_mode(mode: int) -> void:
	var hp2p = get_tree().root.get_node_or_null("HP2P")
	if hp2p and hp2p.has_method("set_relay_control"):
		var ctrl = EOS.P2P.RelayControl.AllowRelays
		if mode == 2:
			ctrl = EOS.P2P.RelayControl.ForceRelays
		
		var res = hp2p.set_relay_control(ctrl)
		var mode_str = "ForceRelays" if mode == 2 else "AllowRelays"
		if EOS.is_success(res):
			log_diagnostic("[EOS Manager] Relay P2P configurado a " + mode_str)
		else:
			log_diagnostic("[EOS Manager ERROR] Fallo al configurar Relay P2P a " + mode_str + ": " + EOS.result_str(res))


func actualizar_nat_async() -> void:
	if _nat_query_in_progress:
		return
	var hp2p = get_tree().root.get_node_or_null("HP2P")
	if not hp2p or not hp2p.has_method("get_nat_type_async"):
		return

	_nat_query_in_progress = true
	cached_nat_type = await hp2p.get_nat_type_async()
	_nat_query_in_progress = false
	log_diagnostic("[EOS Manager] NAT detectado: " + _nombre_nat(cached_nat_type))


func _nombre_nat(nat_type: int) -> String:
	match nat_type:
		1:
			return "Abierto"
		2:
			return "Moderado"
		3:
			return "Estricto"
		_:
			return "Desconocido"


func _id_corto(product_user_id: String) -> String:
	return product_user_id.left(8) + "…" if product_user_id.length() > 8 else product_user_id


func _emitir_estado(message: String) -> void:
	estado_eos_actualizado.emit(message)


func leave_current_lobby() -> void:
	if current_lobby == null or not is_instance_valid(current_lobby):
		current_lobby = null
		return

	var lobby_to_leave = current_lobby
	current_lobby = null
	if lobby_to_leave.is_owner():
		var destroy_result = await lobby_to_leave.destroy_async()
		if destroy_result != null and not destroy_result:
			print("[EOS Manager] No se pudo destruir el lobby actual.")
	else:
		var leave_result = await lobby_to_leave.leave_async()
		if leave_result != null and not leave_result:
			print("[EOS Manager] No se pudo salir del lobby actual.")


func _limpiar_lobbies_huerfanos_async() -> void:
	# Buscar lobbies que nos pertenezcan y destruirlos si no tienen un uso
	# activo. Esto limpia lobbies zombie que quedan cuando el juego se cierra
	# inesperadamente.
	var HLobbies_node = get_tree().root.get_node_or_null("HLobbies")
	if not is_instance_valid(HLobbies_node) or not HLobbies_node.has_method("search_by_product_user_id_async"):
		return
	
	var lobbies = await HLobbies_node.search_by_product_user_id_async(local_product_user_id)
	if lobbies == null or typeof(lobbies) != TYPE_ARRAY:
		return
	
	for lobby in lobbies:
		if not is_instance_valid(lobby):
			continue
		# Solo destruir lobbies que nos pertenecen y no son el lobby actual
		if lobby.is_owner(local_product_user_id):
			if current_lobby != null and is_instance_valid(current_lobby) and lobby.lobby_id == current_lobby.lobby_id:
				continue
			print("[EOS Manager] Destruyendo lobby huérfano: ", lobby.lobby_id.left(12), "…")
			await lobby.destroy_async()
		else:
			# Si somos miembros pero no dueños, salimos silenciosamente
			if current_lobby == null or not is_instance_valid(current_lobby) or lobby.lobby_id != current_lobby.lobby_id:
				print("[EOS Manager] Saliendo de lobby huérfano: ", lobby.lobby_id.left(12), "…")
				await lobby.leave_async()
