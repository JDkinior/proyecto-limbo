extends Node
class_name LanDiscovery

# Autodescubrimiento de partidas en red local (LAN) via UDP broadcast.
# Extraído de RedManager para reducir responsabilidad.

signal servidor_encontrado(ip: String, port: int, name: String)

const DISCOVERY_PORT = 7001

var udp_broadcaster: PacketPeerUDP
var udp_listener: PacketPeerUDP
var broadcast_timer: float = 0.0
var servidores_descubiertos: Dictionary = {} # { ip: { name: String, port: int, time: float } }

var _broadcast_info: Dictionary = {} # Info to broadcast (ip, port, name)

func configurar_broadcast(ip_local: String, port: int, nombre: String) -> void:
	_broadcast_info = {
		"ip": ip_local,
		"port": port,
		"name": nombre
	}

func _process(delta: float) -> void:
	_procesar_broadcaster(delta)
	_procesar_listener()

func _procesar_broadcaster(delta: float) -> void:
	if not udp_broadcaster:
		return
	broadcast_timer += delta
	if broadcast_timer >= 1.5:
		broadcast_timer = 0.0
		var packet = JSON.stringify(_broadcast_info).to_utf8_buffer()
		udp_broadcaster.put_packet(packet)

func _procesar_listener() -> void:
	if not udp_listener:
		return
	while udp_listener.get_available_packet_count() > 0:
		var packet = udp_listener.get_packet()
		var ip = udp_listener.get_packet_ip()
		var data_str = packet.get_string_from_utf8()
		var data = JSON.parse_string(data_str)
		if data and typeof(data) == TYPE_DICTIONARY:
			var server_ip = ip
			var server_name = data.get("name", "Servidor Local")
			var server_port = data.get("port", 7000)
			
			# Evitar agregarse a uno mismo
			var mi_ip = _broadcast_info.get("ip", "")
			if server_ip != mi_ip:
				servidores_descubiertos[server_ip] = {
					"name": server_name,
					"port": server_port,
					"time": Time.get_ticks_msec()
				}
				servidor_encontrado.emit(server_ip, server_port, server_name)
	
	# Limpiar servidores obsoletos (más de 5 segundos sin paquetes)
	var ahora = Time.get_ticks_msec()
	var keys = servidores_descubiertos.keys()
	for k in keys:
		if ahora - servidores_descubiertos[k]["time"] > 5000:
			servidores_descubiertos.erase(k)

func iniciar_broadcaster() -> void:
	udp_broadcaster = PacketPeerUDP.new()
	udp_broadcaster.set_broadcast_enabled(true)
	udp_broadcaster.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	broadcast_timer = 0.0
	print("[LAN] Emisor de descubrimiento iniciado.")

func detener_broadcaster() -> void:
	if udp_broadcaster:
		udp_broadcaster.close()
		udp_broadcaster = null
		print("[LAN] Emisor de descubrimiento detenido.")

func iniciar_listener() -> void:
	detener_listener()
	servidores_descubiertos.clear()
	udp_listener = PacketPeerUDP.new()
	var err = udp_listener.bind(DISCOVERY_PORT)
	if err != OK:
		print("[LAN] Error al iniciar receptor de descubrimiento: ", err)
		udp_listener = null
	else:
		print("[LAN] Receptor de descubrimiento iniciado.")

func detener_listener() -> void:
	if udp_listener:
		udp_listener.close()
		udp_listener = null
		print("[LAN] Receptor de descubrimiento detenido.")
