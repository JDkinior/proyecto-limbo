extends Node
class_name MenuMatchmakingCtrl

var menu: Control
var _firebase_sala_ids: Array = []

func init(p_menu: Control):
	menu = p_menu
	_inicializar_nuevos_paneles()
	_conectar_senales()

func _conectar_senales():
	menu.get_node("PanelJugar/VBoxContainer/BtnHost").pressed.connect(_on_btn_host_pressed)
	menu.get_node("PanelJugar/VBoxContainer/HBoxContainer/BtnConectar").pressed.connect(_on_btn_conectar_pressed)
	menu.get_node("PanelJugar/VBoxContainer/QuickJoinOption").item_selected.connect(_on_quick_join_option_item_selected)
	menu.get_node("PanelJugar/VBoxContainer/BtnVolver").pressed.connect(_on_btn_volver_jugar_pressed)
	
	if is_instance_valid(menu.get_tree().root.get_node_or_null("RedManager")):
		var RedManager = menu.get_tree().root.get_node("RedManager")
		RedManager.lan_server_found.connect(_on_lan_server_found)

func _inicializar_nuevos_paneles():
	var style_panel = menu.panel_principal.get_theme_stylebox("panel")
	var sample_btn = menu.get_node("PanelPrincipal/VBoxContainer/BtnJugar")
	var style_btn_normal = sample_btn.get_theme_stylebox("normal")
	var style_btn_hover = sample_btn.get_theme_stylebox("hover")
	var style_btn_pressed = sample_btn.get_theme_stylebox("pressed")
	var style_btn_disabled = sample_btn.get_theme_stylebox("disabled")
	var style_input = menu.get_node("PanelAmigos/VBoxContainer/HBoxAdd/AmigoNombreInput").get_theme_stylebox("normal")
	
	# 1. PANEL SELECCIÓN DE MODOS (LOCAL VS ONLINE)
	menu.panel_modos = Panel.new()
	menu.panel_modos.name = "PanelModos"
	menu.panel_modos.visible = false
	menu.panel_modos.add_theme_stylebox_override("panel", style_panel)
	menu.add_child(menu.panel_modos)
	
	menu.panel_modos.anchor_left = 0.5
	menu.panel_modos.anchor_right = 0.5
	menu.panel_modos.anchor_top = 0.5
	menu.panel_modos.anchor_bottom = 0.5
	menu.panel_modos.offset_left = -300
	menu.panel_modos.offset_top = -220
	menu.panel_modos.offset_right = 300
	menu.panel_modos.offset_bottom = 220
	menu.panel_modos.custom_minimum_size = Vector2(600, 440)
	menu.panel_modos.size = Vector2(600, 440)
	
	var vbox_modos = VBoxContainer.new()
	vbox_modos.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox_modos.offset_left = 30
	vbox_modos.offset_top = 24
	vbox_modos.offset_right = -30
	vbox_modos.offset_bottom = -24
	vbox_modos.add_theme_constant_override("separation", 18)
	vbox_modos.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.panel_modos.add_child(vbox_modos)
	
	var title_modos = Label.new()
	title_modos.text = "Seleccionar Conexión"
	title_modos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_modos.add_theme_font_size_override("font_size", 30)
	vbox_modos.add_child(title_modos)
	
	var subt_modos = Label.new()
	subt_modos.text = "¿Cómo quieres conectarte hoy?"
	subt_modos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subt_modos.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	subt_modos.add_theme_font_size_override("font_size", 16)
	vbox_modos.add_child(subt_modos)
	
	var sep_modos = HSeparator.new()
	vbox_modos.add_child(sep_modos)
	
	menu.btn_modo_online = Button.new()
	menu.btn_modo_online.text = "🌐 Modo Online (Internet)"
	menu.btn_modo_online.custom_minimum_size = Vector2(0, 58)
	menu.btn_modo_online.add_theme_stylebox_override("normal", style_btn_normal)
	menu.btn_modo_online.add_theme_stylebox_override("hover", style_btn_hover)
	menu.btn_modo_online.add_theme_stylebox_override("pressed", style_btn_pressed)
	menu.btn_modo_online.add_theme_stylebox_override("disabled", style_btn_disabled)
	menu.btn_modo_online.add_theme_font_size_override("font_size", 18)
	menu.btn_modo_online.pressed.connect(_on_btn_modo_online_pressed)
	vbox_modos.add_child(menu.btn_modo_online)
	
	menu.btn_modo_local = Button.new()
	menu.btn_modo_local.text = "📡 Modo Local (Red LAN)"
	menu.btn_modo_local.custom_minimum_size = Vector2(0, 58)
	menu.btn_modo_local.add_theme_stylebox_override("normal", style_btn_normal)
	menu.btn_modo_local.add_theme_stylebox_override("hover", style_btn_hover)
	menu.btn_modo_local.add_theme_stylebox_override("pressed", style_btn_pressed)
	menu.btn_modo_local.add_theme_stylebox_override("disabled", style_btn_disabled)
	menu.btn_modo_local.add_theme_font_size_override("font_size", 18)
	menu.btn_modo_local.pressed.connect(_on_btn_modo_local_pressed)
	vbox_modos.add_child(menu.btn_modo_local)
	
	menu.btn_volver_modos = Button.new()
	menu.btn_volver_modos.text = "← Volver al Menú"
	menu.btn_volver_modos.custom_minimum_size = Vector2(0, 50)
	menu.btn_volver_modos.add_theme_stylebox_override("normal", style_btn_normal)
	menu.btn_volver_modos.add_theme_stylebox_override("hover", style_btn_hover)
	menu.btn_volver_modos.add_theme_stylebox_override("pressed", style_btn_pressed)
	menu.btn_volver_modos.add_theme_stylebox_override("disabled", style_btn_disabled)
	menu.btn_volver_modos.add_theme_font_size_override("font_size", 16)
	menu.btn_volver_modos.pressed.connect(_on_btn_volver_modos_pressed)
	vbox_modos.add_child(menu.btn_volver_modos)
	
	# 2. PANEL SALAS (ROOM MATCHMAKING DEDICADO - MÓVIL)
	menu.panel_salas = Panel.new()
	menu.panel_salas.name = "PanelSalas"
	menu.panel_salas.visible = false
	menu.panel_salas.add_theme_stylebox_override("panel", style_panel)
	menu.add_child(menu.panel_salas)
	
	menu.panel_salas.anchor_left = 0.5
	menu.panel_salas.anchor_right = 0.5
	menu.panel_salas.anchor_top = 0.5
	menu.panel_salas.anchor_bottom = 0.5
	menu.panel_salas.offset_left = -340
	menu.panel_salas.offset_top = -260
	menu.panel_salas.offset_right = 340
	menu.panel_salas.offset_bottom = 260
	menu.panel_salas.custom_minimum_size = Vector2(680, 520)
	menu.panel_salas.size = Vector2(680, 520)
	
	var vbox_salas = VBoxContainer.new()
	vbox_salas.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox_salas.offset_left = 28
	vbox_salas.offset_top = 20
	vbox_salas.offset_right = -28
	vbox_salas.offset_bottom = -20
	vbox_salas.add_theme_constant_override("separation", 14)
	vbox_salas.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.panel_salas.add_child(vbox_salas)
	
	var title_salas = Label.new()
	title_salas.text = "Salas Online (Internet)"
	title_salas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_salas.add_theme_font_size_override("font_size", 30)
	vbox_salas.add_child(title_salas)
	
	var lbl_salas_desc = Label.new()
	lbl_salas_desc.text = "Selecciona una sala activa o crea una nueva:"
	lbl_salas_desc.add_theme_font_size_override("font_size", 16)
	lbl_salas_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox_salas.add_child(lbl_salas_desc)
	
	menu.lista_salas = ItemList.new()
	menu.lista_salas.custom_minimum_size = Vector2(0, 180)
	menu.lista_salas.add_theme_stylebox_override("panel", style_input)
	menu.lista_salas.add_theme_font_size_override("font_size", 16)
	menu.lista_salas.fixed_icon_size = Vector2i(24, 24)
	vbox_salas.add_child(menu.lista_salas)
	
	var hbox_create = HBoxContainer.new()
	hbox_create.add_theme_constant_override("separation", 10)
	vbox_salas.add_child(hbox_create)
	
	menu.sala_nombre_input = LineEdit.new()
	menu.sala_nombre_input.placeholder_text = "Nombre de la sala..."
	menu.sala_nombre_input.custom_minimum_size = Vector2(0, 52)
	menu.sala_nombre_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.sala_nombre_input.add_theme_stylebox_override("normal", style_input)
	menu.sala_nombre_input.add_theme_font_size_override("font_size", 16)
	hbox_create.add_child(menu.sala_nombre_input)
	
	menu.btn_crear_sala = Button.new()
	menu.btn_crear_sala.text = "➕ Crear"
	menu.btn_crear_sala.custom_minimum_size = Vector2(130, 52)
	menu.btn_crear_sala.add_theme_stylebox_override("normal", style_btn_normal)
	menu.btn_crear_sala.add_theme_stylebox_override("hover", style_btn_hover)
	menu.btn_crear_sala.add_theme_stylebox_override("pressed", style_btn_pressed)
	menu.btn_crear_sala.add_theme_stylebox_override("disabled", style_btn_disabled)
	menu.btn_crear_sala.add_theme_font_size_override("font_size", 16)
	menu.btn_crear_sala.pressed.connect(_on_btn_crear_sala_pressed)
	hbox_create.add_child(menu.btn_crear_sala)
	
	var hbox_actions = HBoxContainer.new()
	hbox_actions.add_theme_constant_override("separation", 12)
	vbox_salas.add_child(hbox_actions)
	
	menu.btn_unirse_sala = Button.new()
	menu.btn_unirse_sala.text = "Unirse a Sala"
	menu.btn_unirse_sala.custom_minimum_size = Vector2(0, 54)
	menu.btn_unirse_sala.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.btn_unirse_sala.add_theme_stylebox_override("normal", style_btn_normal)
	menu.btn_unirse_sala.add_theme_stylebox_override("hover", style_btn_hover)
	menu.btn_unirse_sala.add_theme_stylebox_override("pressed", style_btn_pressed)
	menu.btn_unirse_sala.add_theme_stylebox_override("disabled", style_btn_disabled)
	menu.btn_unirse_sala.add_theme_font_size_override("font_size", 17)
	menu.btn_unirse_sala.pressed.connect(_on_btn_unirse_sala_pressed)
	hbox_actions.add_child(menu.btn_unirse_sala)
	
	menu.btn_refrescar_salas = Button.new()
	menu.btn_refrescar_salas.text = "🔄 Refrescar"
	menu.btn_refrescar_salas.custom_minimum_size = Vector2(140, 54)
	menu.btn_refrescar_salas.add_theme_stylebox_override("normal", style_btn_normal)
	menu.btn_refrescar_salas.add_theme_stylebox_override("hover", style_btn_hover)
	menu.btn_refrescar_salas.add_theme_stylebox_override("pressed", style_btn_pressed)
	menu.btn_refrescar_salas.add_theme_stylebox_override("disabled", style_btn_disabled)
	menu.btn_refrescar_salas.add_theme_font_size_override("font_size", 16)
	menu.btn_refrescar_salas.pressed.connect(_on_btn_refrescar_salas_pressed)
	hbox_actions.add_child(menu.btn_refrescar_salas)

	var hbox_extra = HBoxContainer.new()
	hbox_extra.add_theme_constant_override("separation", 12)
	vbox_salas.add_child(hbox_extra)
	
	var btn_lan_alt = Button.new()
	btn_lan_alt.text = "📡 Conexión LAN"
	btn_lan_alt.custom_minimum_size = Vector2(0, 48)
	btn_lan_alt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_lan_alt.add_theme_stylebox_override("normal", style_btn_normal)
	btn_lan_alt.add_theme_stylebox_override("hover", style_btn_hover)
	btn_lan_alt.add_theme_font_size_override("font_size", 15)
	btn_lan_alt.pressed.connect(_on_btn_modo_local_pressed)
	hbox_extra.add_child(btn_lan_alt)
	
	menu.btn_volver_salas = Button.new()
	menu.btn_volver_salas.text = "← Volver al Menú"
	menu.btn_volver_salas.custom_minimum_size = Vector2(0, 48)
	menu.btn_volver_salas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.btn_volver_salas.add_theme_stylebox_override("normal", style_btn_normal)
	menu.btn_volver_salas.add_theme_stylebox_override("hover", style_btn_hover)
	menu.btn_volver_salas.add_theme_stylebox_override("pressed", style_btn_pressed)
	menu.btn_volver_salas.add_theme_stylebox_override("disabled", style_btn_disabled)
	menu.btn_volver_salas.add_theme_font_size_override("font_size", 15)
	menu.btn_volver_salas.pressed.connect(_on_btn_volver_salas_pressed)
	hbox_extra.add_child(menu.btn_volver_salas)
	
	# 3. LAN DISCOVERY EN PANEL JUGAR (LOCAL)
	var vbox_jugar = menu.get_node("PanelJugar/VBoxContainer")
	
	menu.label_servidores_lan = Label.new()
	menu.label_servidores_lan.text = "Partidas en Red Local (LAN):"
	menu.label_servidores_lan.add_theme_font_size_override("font_size", 14)
	
	var idx_volver = vbox_jugar.get_child_count() - 1
	vbox_jugar.add_child(menu.label_servidores_lan)
	vbox_jugar.move_child(menu.label_servidores_lan, idx_volver)
	
	menu.lista_servidores_lan = ItemList.new()
	menu.lista_servidores_lan.custom_minimum_size = Vector2(0, 100)
	var style_input_jugar = menu.get_node("PanelAmigos/VBoxContainer/HBoxAdd/AmigoNombreInput").get_theme_stylebox("normal")
	menu.lista_servidores_lan.add_theme_stylebox_override("panel", style_input_jugar)
	menu.lista_servidores_lan.item_selected.connect(_on_lan_server_selected)
	vbox_jugar.add_child(menu.lista_servidores_lan)
	vbox_jugar.move_child(menu.lista_servidores_lan, idx_volver + 1)

func _on_btn_modo_local_pressed():
	var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
	if is_instance_valid(RedManager):
		RedManager.iniciar_lan_listener()
	
	menu.mostrar_panel(menu.panel_jugar)
	if is_instance_valid(RedManager):
		menu.local_ip_label.text = "Tu IP local para WiFi: " + RedManager.get_local_ip()
	_actualizar_servidores_lan()

func _on_btn_modo_online_pressed():
	menu.mostrar_panel(menu.panel_salas)
	menu.btn_crear_sala.disabled = false
	menu.btn_crear_sala.text = "Crear"
	_actualizar_lista_salas_firebase()
	
	var FirebaseMatchmaking = menu.get_tree().root.get_node_or_null("FirebaseMatchmaking")
	if is_instance_valid(FirebaseMatchmaking):
		FirebaseMatchmaking.iniciar_busqueda()
		if not FirebaseMatchmaking.salas_actualizadas.is_connected(_on_firebase_salas_actualizadas):
			FirebaseMatchmaking.salas_actualizadas.connect(_on_firebase_salas_actualizadas)

func _on_btn_volver_modos_pressed():
	menu.mostrar_panel(menu.panel_principal)

func _on_btn_host_pressed():
	var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
	if is_instance_valid(RedManager):
		RedManager.crear_partida()

func _on_btn_conectar_pressed():
	var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
	if is_instance_valid(RedManager):
		var target_ip = menu.ip_input.text.strip_edges()
		if target_ip.is_empty():
			target_ip = "127.0.0.1"
		RedManager.unirse_a_partida(target_ip)
		menu.lobby_status_label.text = "Conectando a " + target_ip + "..."
		menu.mostrar_panel(menu.panel_lobby)

func _on_quick_join_option_item_selected(index):
	if index > 0:
		var nombre_amigo = menu.quick_join_option.get_item_text(index)
		var ip_amigo = menu.amigos_dict.get(nombre_amigo, "127.0.0.1")
		menu.ip_input.text = ip_amigo

func _on_btn_volver_jugar_pressed():
	var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
	if is_instance_valid(RedManager):
		RedManager.detener_lan_listener()
	menu.mostrar_panel(menu.panel_modos)

func _on_lan_server_found(_ip, _port, _name):
	_actualizar_servidores_lan()

func _actualizar_servidores_lan():
	var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
	if not is_instance_valid(menu.lista_servidores_lan) or not is_instance_valid(RedManager):
		return
	menu.lista_servidores_lan.clear()
	for ip in RedManager.lan_servers_discovered:
		var s = RedManager.lan_servers_discovered[ip]
		menu.lista_servidores_lan.add_item(s["name"] + " (" + ip + ")")
	
	if menu.lista_servidores_lan.item_count == 0:
		menu.lista_servidores_lan.add_item("Buscando partidas en red local...")

func _on_lan_server_selected(index):
	if menu.lista_servidores_lan.item_count > 0:
		var text = menu.lista_servidores_lan.get_item_text(index)
		if "(" in text:
			var ip = text.split(" (")[1].replace(")", "").strip_edges()
			menu.ip_input.text = ip

func _on_firebase_salas_actualizadas(salas: Dictionary):
	if menu.panel_salas.visible:
		_actualizar_lista_salas_firebase()

func _actualizar_lista_salas_firebase():
	var FirebaseMatchmaking = menu.get_tree().root.get_node_or_null("FirebaseMatchmaking")
	if not is_instance_valid(FirebaseMatchmaking) or not menu.panel_salas.visible: return
	menu.lista_salas.clear()
	_firebase_sala_ids.clear()
	
	for sala_id in FirebaseMatchmaking.salas_disponibles:
		var sala = FirebaseMatchmaking.salas_disponibles[sala_id]
		var nombre = sala.get("nombre", sala_id)
		var jugadores = sala.get("jugadores", 1)
		var max_j = sala.get("max_jugadores", 2)
		var status = "Abierta" if jugadores < max_j else "Llena"
		menu.lista_salas.add_item(nombre + " (" + str(jugadores) + "/" + str(max_j) + ") [" + status + "]")
		_firebase_sala_ids.append(sala_id)
	
	if menu.lista_salas.item_count == 0:
		menu.lista_salas.add_item("No hay salas activas. ¡Crea una!")

func _on_btn_crear_sala_pressed():
	var nombre = menu.sala_nombre_input.text.strip_edges()
	if nombre.is_empty():
		return
	
	var FirebaseMatchmaking = menu.get_tree().root.get_node_or_null("FirebaseMatchmaking")
	var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
	if not is_instance_valid(FirebaseMatchmaking) or not is_instance_valid(RedManager):
		return
	
	menu.btn_crear_sala.disabled = true
	menu.btn_crear_sala.text = "Creando..."
	
	FirebaseMatchmaking.obtener_ip_publica()
	await FirebaseMatchmaking.ip_publica_obtenida
	
	RedManager.crear_partida()
	
	FirebaseMatchmaking.crear_sala(nombre)
	
	var signals = [FirebaseMatchmaking.sala_creada_ok, FirebaseMatchmaking.sala_error]
	var result = await menu._esperar_cualquier_signal(signals)
	
	menu.btn_crear_sala.disabled = false
	menu.btn_crear_sala.text = "Crear"
	
	if result == 0:
		menu.sala_nombre_input.clear()
		menu.mostrar_panel(menu.panel_lobby)
		if menu.lobby_ctrl != null:
			menu.lobby_ctrl._actualizar_ui_lobby()
			menu.lobby_ctrl._actualizar_lobby_3d()
		menu.lobby_status_label.text = "Sala creada. Esperando al otro jugador...\nIP: " + FirebaseMatchmaking.mi_ip_publica
	else:
		menu.lobby_status_label.text = "Error al crear sala. Inténtalo de nuevo."

func _on_btn_unirse_sala_pressed():
	var items = menu.lista_salas.get_selected_items()
	if items.size() > 0:
		var index = items[0]
		if index >= 0 and index < _firebase_sala_ids.size():
			var sala_id = _firebase_sala_ids[index]
			var FirebaseMatchmaking = menu.get_tree().root.get_node_or_null("FirebaseMatchmaking")
			if is_instance_valid(FirebaseMatchmaking):
				FirebaseMatchmaking.detener_busqueda()
				FirebaseMatchmaking.unirse_a_sala(sala_id)
				menu.mostrar_panel(menu.panel_lobby)
				menu.lobby_status_label.text = "Conectando al host..."
				menu.btn_jugador.disabled = true
				menu.btn_fantasma.disabled = true
				menu.btn_listo.disabled = true
				menu.host_controls_container.visible = false
				menu.client_status_container.visible = false
				menu.autoconectando = true

func _on_btn_refrescar_salas_pressed():
	var FirebaseMatchmaking = menu.get_tree().root.get_node_or_null("FirebaseMatchmaking")
	if is_instance_valid(FirebaseMatchmaking):
		FirebaseMatchmaking.listar_salas()

func _on_btn_volver_salas_pressed():
	var FirebaseMatchmaking = menu.get_tree().root.get_node_or_null("FirebaseMatchmaking")
	if is_instance_valid(FirebaseMatchmaking):
		FirebaseMatchmaking.detener_busqueda()
		FirebaseMatchmaking.limpiar()
	var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
	if is_instance_valid(RedManager):
		RedManager.desconectar()
	
	menu.btn_crear_sala.disabled = false
	menu.btn_crear_sala.text = "Crear"
		
	menu.mostrar_panel(menu.panel_modos)
