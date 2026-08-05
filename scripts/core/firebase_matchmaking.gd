extends Node
# Autoload: FirebaseMatchmaking
# Matchmaking vía Firebase Realtime Database REST API
# Solo se usa para ENCONTRAR al otro jugador (crear/listar/unir salas).
# La conexión de juego real sigue siendo ENet P2P.

signal salas_actualizadas(salas: Dictionary)
signal sala_creada_ok(nombre_sala: String)
signal sala_error(mensaje: String)
signal ip_publica_obtenida(ip: String)

# === CONFIGURACIÓN ===
# URL de la Realtime Database de Firebase (cambiar si es necesario)
const FIREBASE_DB_URL = "https://proyecto-limbo-match-default-rtdb.firebaseio.com"
const HEARTBEAT_INTERVAL = 10.0  # segundos entre actualizaciones de "estoy vivo"
const SALA_TIMEOUT = 30.0  # segundos sin heartbeat para considerar sala muerta
const REFRESH_INTERVAL = 5.0  # segundos entre refrescos de la lista de salas

# === ESTADO ===
var mi_sala_id: String = ""
var mi_ip_publica: String = ""
var salas_disponibles: Dictionary = {}  # {sala_id: {datos...}}
var esta_buscando: bool = false

# === NODOS HTTP ===
var http_ip: HTTPRequest
var http_crear: HTTPRequest
var http_listar: HTTPRequest
var http_eliminar: HTTPRequest
var http_heartbeat: HTTPRequest
var http_unirse: HTTPRequest

# === TIMERS ===
var timer_heartbeat: Timer
var timer_webrtc: Timer
var http_webrtc: HTTPRequest
var _sdp_procesados: Dictionary = {}
var _ice_procesados: Dictionary = {}
var timer_refresh: Timer

func _ready():
	# Crear nodos HTTPRequest
	http_ip = HTTPRequest.new()
	http_ip.name = "HttpIP"
	http_ip.request_completed.connect(_on_ip_response)
	add_child(http_ip)
	
	http_crear = HTTPRequest.new()
	http_crear.name = "HttpCrear"
	http_crear.request_completed.connect(_on_crear_response)
	add_child(http_crear)
	
	http_listar = HTTPRequest.new()
	http_listar.name = "HttpListar"
	http_listar.request_completed.connect(_on_listar_response)
	add_child(http_listar)
	
	http_eliminar = HTTPRequest.new()
	http_eliminar.name = "HttpEliminar"
	add_child(http_eliminar)
	
	http_heartbeat = HTTPRequest.new()
	http_heartbeat.name = "HttpHeartbeat"
	add_child(http_heartbeat)
	
	http_unirse = HTTPRequest.new()
	http_unirse.name = "HttpUnirse"
	http_unirse.request_completed.connect(_on_unirse_response)
	add_child(http_unirse)
	
	# Timer de heartbeat
	timer_heartbeat = Timer.new()
	timer_heartbeat.name = "TimerHeartbeat"
	timer_heartbeat.wait_time = HEARTBEAT_INTERVAL
	timer_heartbeat.timeout.connect(_on_heartbeat_timeout)
	add_child(timer_heartbeat)

	http_webrtc = HTTPRequest.new()
	http_webrtc.request_completed.connect(_on_webrtc_response)
	add_child(http_webrtc)
	
	timer_webrtc = Timer.new()
	timer_webrtc.wait_time = 0.4
	timer_webrtc.timeout.connect(_on_webrtc_poll)
	add_child(timer_webrtc)

	
	# Timer de refresco de salas
	timer_refresh = Timer.new()
	timer_refresh.name = "TimerRefresh"
	timer_refresh.wait_time = REFRESH_INTERVAL
	timer_refresh.timeout.connect(_on_refresh_timeout)
	add_child(timer_refresh)


# =====================
# === IP PÚBLICA ===
# =====================

func obtener_ip_publica():
	print("[FirebaseMatch] Obteniendo IP pública...")
	http_ip.request("https://api.ipify.org")

func _on_ip_response(result, response_code, _headers, body):
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		mi_ip_publica = body.get_string_from_utf8().strip_edges()
		print("[FirebaseMatch] IP Pública: ", mi_ip_publica)
		ip_publica_obtenida.emit(mi_ip_publica)
	else:
		print("[FirebaseMatch] Error obteniendo IP pública. Intentando alternativa...")
		# Fallback: usar IP local
		if is_instance_valid(RedManager):
			mi_ip_publica = RedManager.get_local_ip()
		else:
			mi_ip_publica = "0.0.0.0"
		ip_publica_obtenida.emit(mi_ip_publica)


# =====================
# === CREAR SALA ===
# =====================

func crear_sala(nombre_sala: String):
	if mi_ip_publica.is_empty():
		print("[FirebaseMatch] Esperando IP pública antes de crear sala...")
		await ip_publica_obtenida
	
	mi_sala_id = nombre_sala.to_lower().replace(" ", "_") + "_" + str(Time.get_unix_time_from_system()).replace(".", "")
	soy_host_sala = true
	
	var puerto = RedManager.PORT if is_instance_valid(RedManager) else 7000
	
	var sala_data = {
		"nombre": nombre_sala,
		"host_ip": mi_ip_publica,
		"host_local_ip": RedManager.get_local_ip() if is_instance_valid(RedManager) else "",
		"puerto": puerto,
		"estado": "esperando",  # "esperando" | "jugando"
		"jugadores": 1,
		"max_jugadores": 2,
		"timestamp": Time.get_unix_time_from_system(),
		"heartbeat": Time.get_unix_time_from_system()
	}
	
	var json_data = JSON.stringify(sala_data)
	var url = FIREBASE_DB_URL + "/salas/" + mi_sala_id + ".json"
	
	print("[FirebaseMatch] Creando sala: ", nombre_sala, " en ", url)
	var headers = ["Content-Type: application/json"]
	http_crear.request(url, headers, HTTPClient.METHOD_PUT, json_data)

func _on_crear_response(result, response_code, _headers, body):
	if result == HTTPRequest.RESULT_SUCCESS and (response_code == 200 or response_code == 201):
		print("[FirebaseMatch] Sala creada exitosamente: ", mi_sala_id)
		sala_creada_ok.emit(mi_sala_id)
		# Iniciar heartbeat
		timer_heartbeat.start()
		timer_webrtc.start()
	else:
		var error_msg = "Error creando sala (HTTP " + str(response_code) + ")"
		print("[FirebaseMatch] ", error_msg)
		if body.size() > 0:
			print("[FirebaseMatch] Response: ", body.get_string_from_utf8())
		sala_error.emit(error_msg)
		mi_sala_id = ""
		timer_webrtc.stop()
		_sdp_procesados.clear()
		_ice_procesados.clear()


# =====================
# === LISTAR SALAS ===
# =====================

func iniciar_busqueda():
	esta_buscando = true
	obtener_ip_publica()
	listar_salas()
	timer_refresh.start()

func detener_busqueda():
	esta_buscando = false
	timer_refresh.stop()
	if http_listar.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		http_listar.cancel_request()

func listar_salas():
	if http_listar.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		http_listar.cancel_request()
		
	var url = FIREBASE_DB_URL + "/salas.json?t=" + str(Time.get_ticks_msec())
	http_listar.request(url)

func _on_listar_response(result, response_code, _headers, body):
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var response_text = body.get_string_from_utf8()
		if response_text == "null" or response_text.is_empty():
			salas_disponibles.clear()
			salas_actualizadas.emit(salas_disponibles)
			return
		
		var json = JSON.new()
		var parse_result = json.parse(response_text)
		if parse_result != OK:
			print("[FirebaseMatch] Error parseando salas: ", json.get_error_message())
			return
		
		var data = json.data
		if not data is Dictionary:
			salas_disponibles.clear()
			salas_actualizadas.emit(salas_disponibles)
			return
		
		# Filtrar salas activas (con heartbeat reciente y estado "esperando")
		var ahora = Time.get_unix_time_from_system()
		var salas_validas: Dictionary = {}
		var salas_a_eliminar: Array = []
		
		for sala_id in data:
			var sala = data[sala_id]
			if not sala is Dictionary:
				continue
			
			var heartbeat = sala.get("heartbeat", 0.0)
			var estado = sala.get("estado", "")
			
			# Si el heartbeat es muy antiguo, marcar para eliminar
			if ahora - heartbeat > SALA_TIMEOUT:
				salas_a_eliminar.append(sala_id)
				continue
			
			# Solo mostrar salas abiertas
			if estado == "esperando" and sala.get("jugadores", 0) < sala.get("max_jugadores", 2):
				salas_validas[sala_id] = sala
		
		salas_disponibles = salas_validas
		salas_actualizadas.emit(salas_disponibles)
		
		# Limpiar salas muertas en segundo plano
		for sala_id in salas_a_eliminar:
			_eliminar_sala_remota(sala_id)
	else:
		print("[FirebaseMatch] Error listando salas (HTTP ", response_code, ")")


# =====================
# === UNIRSE A SALA ===
# =====================

func unirse_a_sala(sala_id: String):
	mi_sala_id = sala_id
	soy_host_sala = false
	if not salas_disponibles.has(sala_id):
		sala_error.emit("Sala no encontrada")
		return
	
	var sala = salas_disponibles[sala_id]
	var host_ip = sala.get("host_ip", "")
	var puerto = sala.get("puerto", 7000)
	
	if host_ip.is_empty():
		sala_error.emit("IP del host no disponible")
		return
		
	var target_ip = host_ip
	var host_local_ip = sala.get("host_local_ip", "")
	
	if mi_ip_publica != "" and host_ip == mi_ip_publica and host_local_ip != "":
		target_ip = host_local_ip
		print("[FirebaseMatch] El host está en la misma red local. Usando IP local: ", target_ip)
	
	print("[FirebaseMatch] Uniéndose a sala '", sala.get("nombre", sala_id), "' -> ", target_ip, ":", puerto)
	
	# Marcar la sala como llena en Firebase
	var url = FIREBASE_DB_URL + "/salas/" + sala_id + ".json"
	var update_data = JSON.stringify({
		"jugadores": 2,
		"estado": "jugando"
	})
	var headers = ["Content-Type: application/json"]
	http_unirse.request(url, headers, HTTPClient.METHOD_PATCH, update_data)
	
	# Conectar vía WebRTC
	if is_instance_valid(RedManager):
		RedManager.unirse_a_partida(sala_id)
	timer_webrtc.start()

func _on_unirse_response(result, response_code, _headers, _body):
	if result == HTTPRequest.RESULT_SUCCESS and (response_code == 200 or response_code == 201):
		print("[FirebaseMatch] Sala actualizada a 'jugando' en Firebase")
	else:
		print("[FirebaseMatch] Error actualizando sala en Firebase (HTTP ", response_code, ")")


# =====================
# === ELIMINAR SALA ===
# =====================

var soy_host_sala: bool = false

func eliminar_mi_sala():
	if mi_sala_id.is_empty():
		return
	if soy_host_sala:
		print("[FirebaseMatch] Eliminando mi sala: ", mi_sala_id)
		_eliminar_sala_remota(mi_sala_id)
	else:
		# Si soy cliente y me salgo, marco la sala como "esperando" y jugadores = 1
		print("[FirebaseMatch] Saliendo de la sala como cliente: ", mi_sala_id)
		var url = FIREBASE_DB_URL + "/salas/" + mi_sala_id + ".json"
		var update_data = JSON.stringify({"jugadores": 1, "estado": "esperando"})
		var headers = ["Content-Type: application/json"]
		var http_temp = HTTPRequest.new()
		add_child(http_temp)
		http_temp.request(url, headers, HTTPClient.METHOD_PATCH, update_data)
		http_temp.request_completed.connect(func(_r, _c, _h, _b): http_temp.queue_free())
		
	mi_sala_id = ""
	soy_host_sala = false
	timer_webrtc.stop()
	if http_webrtc.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		http_webrtc.cancel_request()
	_sdp_procesados.clear()
	_ice_procesados.clear()
	timer_heartbeat.stop()

func _eliminar_sala_remota(sala_id: String):
	var url = FIREBASE_DB_URL + "/salas/" + sala_id + ".json"
	# Usar un HTTPRequest temporal para no bloquear otros
	var http_temp = HTTPRequest.new()
	add_child(http_temp)
	http_temp.request(url, [], HTTPClient.METHOD_DELETE)
	http_temp.request_completed.connect(func(_r, _c, _h, _b): http_temp.queue_free())


# =====================
# === HEARTBEAT ===
# =====================

func _on_heartbeat_timeout():
	if mi_sala_id.is_empty():
		timer_heartbeat.stop()
		return
	
	var url = FIREBASE_DB_URL + "/salas/" + mi_sala_id + ".json"
	var update_data = JSON.stringify({
		"heartbeat": Time.get_unix_time_from_system()
	})
	var headers = ["Content-Type: application/json"]
	http_heartbeat.request(url, headers, HTTPClient.METHOD_PATCH, update_data)

func _on_refresh_timeout():
	if esta_buscando:
		listar_salas()


# =====================
# === LIMPIEZA ===
# =====================

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Limpiar sala al cerrar la app
		if not mi_sala_id.is_empty():
			eliminar_mi_sala()

func limpiar():
	eliminar_mi_sala()
	detener_busqueda()
	salas_disponibles.clear()
	mi_ip_publica = ""
	mi_sala_id = ""
	soy_host_sala = false
	if is_instance_valid(http_ip) and http_ip.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		http_ip.cancel_request()
	if is_instance_valid(http_crear) and http_crear.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		http_crear.cancel_request()
	if is_instance_valid(http_unirse) and http_unirse.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		http_unirse.cancel_request()
	if is_instance_valid(http_webrtc) and http_webrtc.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		http_webrtc.cancel_request()

# =====================
# === WEBRTC SIGNALING ===
# =====================

func enviar_sdp(target_id: int, type: String, sdp: String):
	if mi_sala_id.is_empty():
		print("[FirebaseMatch ERROR] No se puede enviar SDP: mi_sala_id está vacío")
		return
	var from_id = RedManager.get_mi_peer_id() if is_instance_valid(RedManager) else 1
	print("[FirebaseMatch Señalización] Enviando SDP ('", type, "') desde ID ", from_id, " hacia ID ", target_id)
	var url = FIREBASE_DB_URL + "/salas/" + mi_sala_id + "/webrtc/" + str(target_id) + "/from_" + str(from_id) + "/sdp.json"
	
	var data = {
		"type": type,
		"sdp": sdp
	}
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(res, code, _h, _b):
		if res == HTTPRequest.RESULT_SUCCESS and (code == 200 or code == 201):
			print("[FirebaseMatch Señalización] SDP publicado con éxito en Firebase")
		else:
			print("[FirebaseMatch ERROR] Falló al publicar SDP en Firebase (HTTP ", code, ")")
		http.queue_free()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_PATCH, JSON.stringify(data))

func enviar_ice(target_id: int, media: String, index: int, name: String):
	if mi_sala_id.is_empty(): return
	var from_id = RedManager.get_mi_peer_id() if is_instance_valid(RedManager) else 1
	var url = FIREBASE_DB_URL + "/salas/" + mi_sala_id + "/webrtc/" + str(target_id) + "/from_" + str(from_id) + "/ice.json"
	
	var data = {
		str(Time.get_ticks_usec()): {
			"media": media,
			"index": index,
			"name": name
		}
	}
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(res, code, _h, _b):
		http.queue_free()
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_PATCH, JSON.stringify(data))

func _on_webrtc_poll():
	if mi_sala_id.is_empty(): return
	if http_webrtc.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED: return
	var my_id = RedManager.get_mi_peer_id() if is_instance_valid(RedManager) else 1
	var url = FIREBASE_DB_URL + "/salas/" + mi_sala_id + "/webrtc/" + str(my_id) + ".json?t=" + str(Time.get_ticks_msec())
	http_webrtc.request(url)

func _on_webrtc_response(result, code, _headers, body):
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var response_text = body.get_string_from_utf8()
		if response_text == "null" or response_text.is_empty(): return
		var json = JSON.new()
		if json.parse(response_text) == OK and typeof(json.data) == TYPE_DICTIONARY:
			for from_key in json.data:
				var from_id_str = from_key.replace("from_", "")
				if from_id_str.is_valid_int():
					var from_id = from_id_str.to_int()
					var node = json.data[from_key]
					
					# 1. Procesar SDP Oferta / Respuesta
					if node.has("sdp"):
						var sdp_type = node["sdp"]["type"]
						var sdp_key = str(from_id) + "_" + sdp_type
						if not _sdp_procesados.has(sdp_key):
							_sdp_procesados[sdp_key] = true
							print("[FirebaseMatch Señalización] SDP '", sdp_type, "' recibido desde peer ID: ", from_id)
							if is_instance_valid(RedManager):
								RedManager.recibir_sdp(from_id, sdp_type, node["sdp"]["sdp"])
							
					# 2. Procesar Candidatos ICE
					if node.has("ice") and typeof(node["ice"]) == TYPE_DICTIONARY:
						for ice_key in node["ice"]:
							if not _ice_procesados.has(ice_key):
								_ice_procesados[ice_key] = true
								var ice_data = node["ice"][ice_key]
								if typeof(ice_data) == TYPE_DICTIONARY:
									print("[FirebaseMatch Señalización] ICE candidate recibido desde peer ID: ", from_id)
									if is_instance_valid(RedManager):
										RedManager.recibir_ice(from_id, str(ice_data.get("media","")), int(ice_data.get("index",0)), str(ice_data.get("name","")))
