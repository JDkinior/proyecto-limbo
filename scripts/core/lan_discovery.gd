extends Node
class_name LanDiscovery

# Autodescubrimiento de partidas en red local (LAN) via UDP broadcast.
# Extraído de RedManager para reducir responsabilidad.

signal servidor_encontrado(ip: String, port: int, name: String)

const DISCOVERY_PORTS = [7001, 7002, 7003, 7004, 7005]

var udp_broadcaster: PacketPeerUDP
var udp_listener: PacketPeerUDP
var puerto_escucha_actual = 0
var broadcast_timer: float = 0.0
var servidores_descubiertos: Dictionary = {} # { ip: { name: String, port: int, time: float } }

var mi_instance_id: int = randi()
var _broadcast_info: Dictionary = {} # Info to broadcast (ip, port, name, id)

func configurar_broadcast(ip_local: String, port: int, nombre: String) -> void:
	_broadcast_info = {
		"ip": ip_local,
		"port": port,
		"name": nombre,
		"id": mi_instance_id
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
		
		# Calcular subnet broadcast (ej. 192.168.1.255) para saltar bloqueos de routers/Android
		var mi_ip = _broadcast_info.get("ip", "")
		var subnet_bcast = "255.255.255.255"
		if mi_ip.count(".") == 3:
			var parts = mi_ip.split(".")
			subnet_bcast = parts[0] + "." + parts[1] + "." + parts[2] + ".255"
			
		for port in DISCOVERY_PORTS:
			udp_broadcaster.set_dest_address("255.255.255.255", port)
			udp_broadcaster.put_packet(packet)
			
			if subnet_bcast != "255.255.255.255":
				udp_broadcaster.set_dest_address(subnet_bcast, port)
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
			var sender_id = data.get("id", 0)
			
			# Evitar agregarse a uno mismo (misma instancia de Godot)
			if sender_id != mi_instance_id:
				# Si estamos en la misma PC, usamos localhost para que ENet funcione mejor localmente
				var connect_ip = server_ip
				if server_ip == _broadcast_info.get("ip", ""):
					connect_ip = "127.0.0.1"
					
				servidores_descubiertos[connect_ip] = {
					"name": server_name,
					"port": server_port,
					"time": Time.get_ticks_msec()
				}
				servidor_encontrado.emit(connect_ip, server_port, server_name)
	
	# Limpiar servidores obsoletos (más de 5 segundos sin paquetes)
	var ahora = Time.get_ticks_msec()
	var keys = servidores_descubiertos.keys()
	for k in keys:
		if ahora - servidores_descubiertos[k]["time"] > 5000:
			servidores_descubiertos.erase(k)

func iniciar_broadcaster() -> void:
	udp_broadcaster = PacketPeerUDP.new()
	udp_broadcaster.set_broadcast_enabled(true)
	# set_dest_address se hace justo antes de put_packet ahora
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
	
	var success = false
	for port in DISCOVERY_PORTS:
		var err = udp_listener.bind(port)
		if err == OK:
			puerto_escucha_actual = port
			success = true
			print("[LAN] Receptor de descubrimiento iniciado en puerto: ", port)
			break
			
	if not success:
		print("[LAN] Error: No se pudo enlazar a ningún puerto de descubrimiento.")
		udp_listener = null

func detener_listener() -> void:
	if udp_listener:
		udp_listener.close()
		udp_listener = null
		print("[LAN] Receptor de descubrimiento detenido.")
