extends Node
class_name MenuLobbyCtrl

var menu: Control

func _init():
	pass

func init(p_menu: Control):
	menu = p_menu
	_conectar_senales()
	_inicializar_lobby_3d()
	_configurar_selector_niveles()

func _conectar_senales():
	menu.get_node("PanelLobby/VBoxContainer/BtnDesconectar").pressed.connect(_on_btn_desconectar_pressed)
	menu.get_node("PanelLobby/VBoxContainer/HBoxPersonajes/BtnJugador").pressed.connect(_on_btn_jugador_pressed)
	menu.get_node("PanelLobby/VBoxContainer/HBoxPersonajes/BtnFantasma").pressed.connect(_on_btn_fantasma_pressed)
	menu.get_node("PanelLobby/VBoxContainer/BtnListo").toggled.connect(_on_btn_listo_toggled)
	menu.get_node("PanelLobby/VBoxContainer/HostControls/SelectorModo").item_selected.connect(_on_selector_modo_item_selected)
	menu.get_node("PanelLobby/VBoxContainer/HostControls/SelectorNivel").item_selected.connect(_on_selector_nivel_item_selected)
	menu.get_node("PanelLobby/VBoxContainer/HostControls/BtnIniciar").pressed.connect(_on_btn_iniciar_pressed)
	
	var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
	if is_instance_valid(RedManager):
		RedManager.conexion_establecida.connect(_on_conexion_establecida)
		RedManager.conexion_perdida.connect(_on_conexion_perdida)
		RedManager.personajes_actualizados.connect(_on_personajes_actualizados)
		RedManager.ready_estados_actualizados.connect(_on_ready_estados_actualizados)
		RedManager.modo_juego_actualizado.connect(_on_modo_juego_actualizado)
		
		# Si ya estamos conectados, ir directo al lobby
		if menu.multiplayer.multiplayer_peer and not (menu.multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
			_on_conexion_establecida()

func process(delta):
	if is_instance_valid(menu.model_jugador):
		menu.model_jugador.rotate_y(delta * 0.4)
	if is_instance_valid(menu.model_fantasma):
		menu.model_fantasma.rotate_y(delta * 0.4)

func _inicializar_lobby_3d():
	var vbox_lobby = menu.get_node("PanelLobby/VBoxContainer")
	var label_elige = menu.get_node("PanelLobby/VBoxContainer/LabelElige")
	
	menu.subviewport_container = SubViewportContainer.new()
	menu.subviewport_container.custom_minimum_size = Vector2(0, 200)
	menu.subviewport_container.stretch = true
	var idx_elige = label_elige.get_index()
	vbox_lobby.add_child(menu.subviewport_container)
	vbox_lobby.move_child(menu.subviewport_container, idx_elige + 1)
	
	menu.subviewport = SubViewport.new()
	menu.subviewport.transparent_bg = true
	menu.subviewport.msaa_3d = Viewport.MSAA_4X
	menu.subviewport_container.add_child(menu.subviewport)
	
	var root_3d = Node3D.new()
	menu.subviewport.add_child(root_3d)
	
	menu.camera_3d = Camera3D.new()
	menu.camera_3d.transform = Transform3D(Basis(), Vector3(0, 0.75, 2.3))
	menu.camera_3d.current = true
	root_3d.add_child(menu.camera_3d)
	
	menu.light_3d = DirectionalLight3D.new()
	menu.light_3d.transform = Transform3D(Basis().rotated(Vector3.UP, deg_to_rad(45)).rotated(Vector3.RIGHT, deg_to_rad(-30)), Vector3.ZERO)
	root_3d.add_child(menu.light_3d)
	
	menu.model_jugador = MeshInstance3D.new()
	menu.model_jugador.mesh = load("res://assets/Modelos/Provicional/untitled.obj")
	menu.model_jugador.transform = Transform3D(Basis().scaled(Vector3(0.6, 0.6, 0.6)), Vector3(-0.55, 0.05, 0))
	root_3d.add_child(menu.model_jugador)
	
	menu.model_fantasma = MeshInstance3D.new()
	menu.model_fantasma.mesh = load("res://assets/Modelos/Provicional/misty.obj")
	menu.model_fantasma.transform = Transform3D(Basis().scaled(Vector3(0.6, 0.6, 0.6)), Vector3(0.55, 0.1, 0))
	root_3d.add_child(menu.model_fantasma)
	
	menu.label_3d_jugador = Label3D.new()
	menu.label_3d_jugador.transform = Transform3D(Basis(), Vector3(-0.55, 1.1, 0))
	menu.label_3d_jugador.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	menu.label_3d_jugador.font_size = 32
	menu.label_3d_jugador.outline_size = 8
	menu.label_3d_jugador.text = ""
	root_3d.add_child(menu.label_3d_jugador)
	
	menu.label_3d_fantasma = Label3D.new()
	menu.label_3d_fantasma.transform = Transform3D(Basis(), Vector3(0.55, 1.1, 0))
	menu.label_3d_fantasma.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	menu.label_3d_fantasma.font_size = 32
	menu.label_3d_fantasma.outline_size = 8
	menu.label_3d_fantasma.text = ""
	root_3d.add_child(menu.label_3d_fantasma)

func _configurar_selector_niveles():
	menu.selector_nivel.clear()
	var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
	if is_instance_valid(RedManager):
		for path in RedManager.NIVELES:
			var nombre_nivel = path.get_file().get_basename().capitalize()
			menu.selector_nivel.add_item(nombre_nivel)

func _on_conexion_establecida():
	menu.autoconectando = false
	var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
	if is_instance_valid(RedManager):
		if RedManager.iniciar_directo_p2p:
			pass
		else:
			menu.mostrar_panel(menu.panel_lobby)
			_actualizar_ui_lobby()
			_actualizar_lobby_3d()

func _on_conexion_perdida():
	_resetear_seleccion_lobby()
	var FirebaseMatchmaking = menu.get_tree().root.get_node_or_null("FirebaseMatchmaking")
	
	if menu.autoconectando:
		menu.autoconectando = false
		menu.mostrar_panel(menu.panel_principal)
	else:
		var era_online = false
		if is_instance_valid(FirebaseMatchmaking) and not FirebaseMatchmaking.mi_sala_id.is_empty():
			era_online = true
			FirebaseMatchmaking.eliminar_mi_sala()
			FirebaseMatchmaking.limpiar()
			
		if era_online:
			menu.mostrar_panel(menu.panel_salas)
			menu.btn_crear_sala.disabled = false
			menu.btn_crear_sala.text = "Crear"
			FirebaseMatchmaking.iniciar_busqueda()
		else:
			menu.mostrar_panel(menu.panel_jugar)
		menu.lobby_status_label.text = "Desconectado o error de conexión."

func _on_btn_desconectar_pressed():
	var era_online = false
	var FirebaseMatchmaking = menu.get_tree().root.get_node_or_null("FirebaseMatchmaking")
	if is_instance_valid(FirebaseMatchmaking) and not FirebaseMatchmaking.mi_sala_id.is_empty():
		era_online = true
		FirebaseMatchmaking.eliminar_mi_sala()
		FirebaseMatchmaking.limpiar()
		
	var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
	if is_instance_valid(RedManager):
		RedManager.desconectar()
		
	if era_online:
		menu.mostrar_panel(menu.panel_salas)
		menu.btn_crear_sala.disabled = false
		menu.btn_crear_sala.text = "Crear"
		if is_instance_valid(FirebaseMatchmaking):
			FirebaseMatchmaking.iniciar_busqueda()
	else:
		menu.mostrar_panel(menu.panel_jugar)

func _on_btn_jugador_pressed():
	var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
	if is_instance_valid(RedManager):
		RedManager.rpc_seleccionar_personaje.rpc("jugador")

func _on_btn_fantasma_pressed():
	var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
	if is_instance_valid(RedManager):
		RedManager.rpc_seleccionar_personaje.rpc("fantasma")

func _on_btn_listo_toggled(button_pressed):
	var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
	if is_instance_valid(RedManager):
		RedManager.rpc_establecer_listo.rpc(button_pressed)
		menu.btn_listo.text = "¡Listo!" if button_pressed else "Prepararse"

func _on_selector_modo_item_selected(index):
	var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
	if is_instance_valid(RedManager):
		var modo = "historia" if index == 0 else "libre"
		var mi_id = menu.multiplayer.get_unique_id()
		if mi_id == RedManager.get_lider_peer_id():
			RedManager.rpc_establecer_modo.rpc(modo)

func _on_selector_nivel_item_selected(index):
	var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
	if is_instance_valid(RedManager):
		var mi_id = menu.multiplayer.get_unique_id()
		if mi_id == RedManager.get_lider_peer_id():
			RedManager.rpc_establecer_nivel.rpc(index)

func _on_btn_iniciar_pressed():
	var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
	if is_instance_valid(RedManager):
		var mi_id = menu.multiplayer.get_unique_id()
		var lider_id = RedManager.get_lider_peer_id()
		if mi_id == lider_id:
			var modo = "historia" if menu.selector_modo.selected == 0 else "libre"
			var idx_nivel = menu.selector_nivel.selected
			menu.lobby_status_label.text = "Cargando nivel... Modo: " + modo
			RedManager.rpc_solicitar_inicio.rpc(modo, idx_nivel)
		else:
			menu.lobby_status_label.text = "Error: No eres el líder."

func _on_personajes_actualizados(_peer_personajes):
	_actualizar_ui_lobby()
	_actualizar_lobby_3d()

func _on_ready_estados_actualizados(_peer_listos):
	_actualizar_ui_lobby()
	_actualizar_lobby_3d()

func _on_modo_juego_actualizado(_modo):
	_actualizar_ui_lobby()
	_actualizar_lobby_3d()

func _resetear_seleccion_lobby():
	menu.btn_jugador.disabled = false
	menu.btn_jugador.text = "Elegir Jugador Vivo"
	menu.btn_fantasma.disabled = false
	menu.btn_fantasma.text = "Elegir Fantasma"
	menu.btn_listo.button_pressed = false
	menu.btn_listo.text = "Prepararse"

func _actualizar_ui_lobby():
	var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
	if not is_instance_valid(RedManager): return
	
	var mi_id = menu.multiplayer.get_unique_id()
	var es_lider = (mi_id == RedManager.get_lider_peer_id())
	var jugador_elegido_por = 0
	var fantasma_elegido_por = 0
	var guest_listo = false
	var total_jugadores = RedManager.peer_personajes.size()
	
	for peer in RedManager.peer_personajes:
		var personaje = RedManager.peer_personajes[peer]
		if personaje == "jugador":
			jugador_elegido_por = peer
		elif personaje == "fantasma":
			fantasma_elegido_por = peer
			
	for peer in RedManager.peer_listos:
		if peer != RedManager.get_lider_peer_id() and RedManager.peer_listos[peer]:
			guest_listo = true
			
	var modo_nombre = RedManager.modo_juego
	var nivel_index = RedManager.nivel_actual_index
	
	menu.host_controls_container.visible = es_lider
	menu.client_status_container.visible = not es_lider
	menu.btn_listo.visible = not es_lider
	
	if jugador_elegido_por == mi_id:
		menu.btn_jugador.disabled = false
		menu.btn_jugador.text = "Jugador Vivo (Tú)"
	elif jugador_elegido_por != 0:
		menu.btn_jugador.disabled = true
		menu.btn_jugador.text = "Jugador Vivo (Compañero)"
	else:
		menu.btn_jugador.disabled = false
		menu.btn_jugador.text = "Elegir Jugador Vivo"
		
	if fantasma_elegido_por == mi_id:
		menu.btn_fantasma.disabled = false
		menu.btn_fantasma.text = "Fantasma (Tú)"
	elif fantasma_elegido_por != 0:
		menu.btn_fantasma.disabled = true
		menu.btn_fantasma.text = "Fantasma (Compañero)"
	else:
		menu.btn_fantasma.disabled = false
		menu.btn_fantasma.text = "Elegir Fantasma"
		
	if es_lider:
		menu.selector_modo.selected = 0 if modo_nombre == "historia" else 1
		menu.selector_nivel.visible = (modo_nombre == "libre")
		if menu.selector_nivel.visible:
			menu.selector_nivel.selected = nivel_index
	else:
		var nivel_label = ""
		if modo_nombre == "libre" and nivel_index < RedManager.NIVELES.size():
			nivel_label = " - " + RedManager.NIVELES[nivel_index].get_file().get_basename().capitalize()
		menu.modo_cliente_label.text = "Modo de juego: " + ("Historia (En orden)" if modo_nombre == "historia" else "Libre" + nivel_label)
		
	if es_lider:
		var lider_eligio = RedManager.peer_personajes.get(mi_id, "") != ""
		var todos_personaje = (jugador_elegido_por != 0 and fantasma_elegido_por != 0)
		menu.btn_iniciar.disabled = not (todos_personaje and guest_listo and lider_eligio)
		
		var host_status_text = ""
		if menu.btn_iniciar.disabled:
			if total_jugadores < 2:
				host_status_text = "Esperando que se conecte tu compañero..."
			elif not lider_eligio:
				host_status_text = "Debes elegir tu personaje."
			elif not todos_personaje:
				host_status_text = "Esperando selección de personaje del compañero..."
			elif not guest_listo:
				host_status_text = "Esperando que el compañero esté listo..."
		else:
			host_status_text = "¡Todo listo! Inicia la partida."
			
		var ip_text = ""
		if menu.multiplayer.is_server():
			ip_text = "\nIP Local: " + RedManager.get_local_ip()
			if RedManager.ip_publica != "":
				ip_text += " | IP Pública: " + RedManager.ip_publica
		else:
			ip_text = "\nConectado localmente."
			
		menu.lobby_status_label.text = host_status_text + ip_text
	else:
		var cliente_eligio = RedManager.peer_personajes.get(mi_id, "") != ""
		menu.btn_listo.disabled = not cliente_eligio
		if not cliente_eligio:
			menu.client_status_label.text = "Elige un personaje para poder prepararte."
		elif not guest_listo:
			menu.client_status_label.text = "¡Personaje elegido! Presiona 'Prepararse'."
		else:
			menu.client_status_label.text = "¡Estás listo! Esperando a que el host inicie..."

func _actualizar_lobby_3d():
	var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
	if not is_instance_valid(RedManager) or not is_instance_valid(menu.model_jugador): return
	
	var mat_unselected = StandardMaterial3D.new()
	mat_unselected.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_unselected.albedo_color = Color(0.2, 0.2, 0.2, 0.4)
	
	var char_jugador_nombre = ""
	var char_fantasma_nombre = ""
	var jugador_elegido = false
	var fantasma_elegido = false
	
	var mi_id = menu.multiplayer.get_unique_id()
	
	for peer in RedManager.peer_personajes:
		var personaje = RedManager.peer_personajes[peer]
		var display_name = "Tú" if peer == mi_id else "Compañero"
		
		if personaje == "jugador":
			jugador_elegido = true
			char_jugador_nombre = display_name
		elif personaje == "fantasma":
			fantasma_elegido = true
			char_fantasma_nombre = display_name
				
	if is_instance_valid(menu.model_jugador) and is_instance_valid(menu.label_3d_jugador):
		if jugador_elegido:
			menu.model_jugador.material_override = null
			menu.model_jugador.scale = Vector3(0.72, 0.72, 0.72)
			menu.label_3d_jugador.text = char_jugador_nombre
			menu.label_3d_jugador.modulate = Color(1.0, 0.6, 0.2)
		else:
			menu.model_jugador.material_override = mat_unselected
			menu.model_jugador.scale = Vector3(0.6, 0.6, 0.6)
			menu.label_3d_jugador.text = ""
			
	if is_instance_valid(menu.model_fantasma) and is_instance_valid(menu.label_3d_fantasma):
		if fantasma_elegido:
			menu.model_fantasma.material_override = null
			menu.model_fantasma.scale = Vector3(0.72, 0.72, 0.72)
			menu.label_3d_fantasma.text = char_fantasma_nombre
			menu.label_3d_fantasma.modulate = Color(0.2, 0.6, 1.0)
		else:
			menu.model_fantasma.material_override = mat_unselected
			menu.model_fantasma.scale = Vector3(0.6, 0.6, 0.6)
			menu.label_3d_fantasma.text = ""
