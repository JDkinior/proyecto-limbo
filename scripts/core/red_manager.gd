extends Node # Configurar como Autoload con nombre 'RedManager'

const PORT = 7000
const ADDRESS = "127.0.0.1" # Cambiar por IP pública para jugar por internet

var jugador_vivo: Jugador # Usamos el class_name específico
var fantasma: Fantasma   # Usamos el class_name específico

func registrar_jugador(p: CharacterBase):
	if p is Fantasma: 
		fantasma = p
	elif p is Jugador:
		jugador_vivo = p
	
	_intentar_asignar_autoridades()

func _intentar_asignar_autoridades():
	if not multiplayer.multiplayer_peer: return
	
	if multiplayer.is_server() and jugador_vivo:
		jugador_vivo.set_multiplayer_authority(1)
		# El fantasma recibirá autoridad cuando el peer se conecte

func _personajes_listos() -> bool:
	if not jugador_vivo:
		push_warning("[Red] No se encontro el Jugador. Revisa que la escena tenga un nodo con script Jugador.")
		return false
	if not fantasma:
		push_warning("[Red] No se encontro el Fantasma. Revisa que la escena tenga un nodo con script Fantasma.")
		return false
	return true

func _ready():
	# Configuración inicial: Por defecto nadie tiene autoridad hasta conectar
	# Esto evita que ambos se muevan antes de empezar la partida
	_crear_botones_red()

func _crear_botones_red():
	# Creamos una interfaz sencilla por código para testeo rápido
	var capa = CanvasLayer.new()
	capa.name = "MenuRed"
	add_child(capa)
	
	var contenedor = VBoxContainer.new()
	contenedor.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 20)
	capa.add_child(contenedor)
	
	var btn_host = Button.new()
	btn_host.text = "Iniciar como HOST (Jugador Vivo)"
	btn_host.custom_minimum_size = Vector2(250, 40)
	btn_host.pressed.connect(func():
		crear_partida()
		capa.queue_free()
	)
	contenedor.add_child(btn_host)
	
	var btn_join = Button.new()
	btn_join.text = "Unirse como CLIENTE (Fantasma)"
	btn_join.custom_minimum_size = Vector2(250, 40)
	btn_join.pressed.connect(func():
		unirse_a_partida()
		capa.queue_free()
	)
	contenedor.add_child(btn_join)

func _input(event):
	# Mantenemos soporte de teclas F1/F2 pero con lógica corregida
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			crear_partida()
			if has_node("MenuRed"): get_node("MenuRed").queue_free()
		elif event.keycode == KEY_F2:
			unirse_a_partida()
			if has_node("MenuRed"): get_node("MenuRed").queue_free()

func crear_partida():
	if not _personajes_listos(): return

	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, 2) # Máximo 2 jugadores
	if error != OK:
		print("Error al crear servidor: ", error)
		return
		
	multiplayer.multiplayer_peer = peer
	# Conectar la señal para saber cuando el cliente entra
	multiplayer.peer_connected.connect(_on_peer_connected)
	
	# El HOST (ID 1) siempre será el Jugador Vivo
	jugador_vivo.set_multiplayer_authority(1)
	jugador_vivo.actualizar_visibilidad_local()
	fantasma.actualizar_visibilidad_local()
	# El Fantasma quedará a la espera de que el cliente se conecte
	
	print("[Red] Servidor iniciado. Eres el JUGADOR VIVO.")
	print("[Red] Esperando al Fantasma...")

func unirse_a_partida():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ADDRESS, PORT)
	if error != OK:
		print("Error al conectar: ", error)
		return
		
	multiplayer.multiplayer_peer = peer
	
	multiplayer.connected_to_server.connect(_al_conectarse_al_servidor)
	print("[Red] Intentando conectar al servidor...")

func _al_conectarse_al_servidor():
	if not _personajes_listos(): return

	var id = multiplayer.get_unique_id()
	# El CLIENTE toma la autoridad del Fantasma
	fantasma.set_multiplayer_authority(id)
	jugador_vivo.actualizar_visibilidad_local()
	fantasma.actualizar_visibilidad_local()
	
	# El Jugador Vivo siempre es del Host (ID 1)
	jugador_vivo.set_multiplayer_authority(1)
	
	print("[Red] Conectado con éxito. Eres el FANTASMA (ID: ", id, ")")

func _on_peer_connected(id):
	# Si somos el host y alguien se conecta, le damos la autoridad del fantasma
	if multiplayer.is_server() and _personajes_listos():
		fantasma.set_multiplayer_authority(id)
		jugador_vivo.actualizar_visibilidad_local()
		fantasma.actualizar_visibilidad_local()
