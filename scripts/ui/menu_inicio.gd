extends Control

# Nodos de Interfaz (Existentes)
@onready var panel_principal = $PanelPrincipal
@onready var panel_jugar = $PanelJugar
@onready var panel_lobby = $PanelLobby
@onready var panel_amigos = $PanelAmigos
@onready var panel_opciones = $PanelOpciones

# Inputs de Conexión
@onready var ip_input = $PanelJugar/VBoxContainer/HBoxContainer/IPInput
@onready var local_ip_label = $PanelJugar/VBoxContainer/LocalIPLabel
@onready var quick_join_option = $PanelJugar/VBoxContainer/QuickJoinOption

# Nodos de Lobby
@onready var btn_jugador = $PanelLobby/VBoxContainer/HBoxPersonajes/BtnJugador
@onready var btn_fantasma = $PanelLobby/VBoxContainer/HBoxPersonajes/BtnFantasma
@onready var lobby_status_label = $PanelLobby/VBoxContainer/LobbyStatusLabel
@onready var host_controls_container = $PanelLobby/VBoxContainer/HostControls
@onready var client_status_container = $PanelLobby/VBoxContainer/ClientStatus
@onready var client_status_label = $PanelLobby/VBoxContainer/ClientStatus/ClientStatusLabel
@onready var btn_iniciar = $PanelLobby/VBoxContainer/HostControls/BtnIniciar
@onready var btn_listo = $PanelLobby/VBoxContainer/BtnListo
@onready var selector_modo = $PanelLobby/VBoxContainer/HostControls/SelectorModo
@onready var selector_nivel = $PanelLobby/VBoxContainer/HostControls/SelectorNivel
@onready var modo_cliente_label = $PanelLobby/VBoxContainer/ClientStatus/ModoClienteLabel

# Nodos de Amigos
@onready var amigo_nombre_input = $PanelAmigos/VBoxContainer/HBoxAdd/AmigoNombreInput
@onready var amigo_ip_input = $PanelAmigos/VBoxContainer/HBoxAdd/AmigoIPInput
@onready var lista_amigos = $PanelAmigos/VBoxContainer/ListaAmigos

# Nodos de Opciones
@onready var volume_slider = $PanelOpciones/VBoxContainer/VolumeSlider
@onready var btn_fullscreen = $PanelOpciones/VBoxContainer/BtnFullscreen

# --- NUEVOS NODOS: Creados por código para mantener compatibilidad con TSCN ---
var panel_modos: Panel
var panel_salas: Panel

# Elementos PanelModos
var btn_modo_local: Button
var btn_modo_online: Button
var btn_volver_modos: Button

# Elementos PanelSalas
var lista_salas: ItemList
var sala_nombre_input: LineEdit
var btn_crear_sala: Button
var btn_unirse_sala: Button
var btn_refrescar_salas: Button
var btn_volver_salas: Button

# Elementos LAN Discovery en PanelJugar (Local)
var lista_servidores_lan: ItemList
var label_servidores_lan: Label

# Elementos Lobby 3D en PanelLobby
var subviewport_container: SubViewportContainer
var subviewport: SubViewport
var camera_3d: Camera3D
var light_3d: DirectionalLight3D
var model_jugador: MeshInstance3D
var model_fantasma: MeshInstance3D
var label_3d_jugador: Label3D
var label_3d_fantasma: Label3D

var amigos_dict: Dictionary = {}
var autoconectando: bool = false

func _ready():
	# 1. Inicializar nuevos paneles programáticos con estilos unificados
	_inicializar_nuevos_paneles()
	
	# 2. Inicializar Paneles Visibles
	_mostrar_panel(panel_principal)
	
	# Conectar Señales de la Interfaz por Código
	$PanelPrincipal/VBoxContainer/BtnJugar.pressed.connect(_on_btn_jugar_pressed)
	$PanelPrincipal/VBoxContainer/BtnAmigos.pressed.connect(_on_btn_amigos_menu_pressed)
	$PanelPrincipal/VBoxContainer/BtnOpciones.pressed.connect(_on_btn_opciones_pressed)
	$PanelPrincipal/VBoxContainer/BtnSalir.pressed.connect(_on_btn_salir_pressed)
	
	$PanelJugar/VBoxContainer/BtnHost.pressed.connect(_on_btn_host_pressed)
	$PanelJugar/VBoxContainer/HBoxContainer/BtnConectar.pressed.connect(_on_btn_conectar_pressed)
	$PanelJugar/VBoxContainer/QuickJoinOption.item_selected.connect(_on_quick_join_option_item_selected)
	$PanelJugar/VBoxContainer/BtnVolver.pressed.connect(_on_btn_volver_jugar_pressed)
	
	$PanelLobby/VBoxContainer/BtnDesconectar.pressed.connect(_on_btn_desconectar_pressed)
	$PanelLobby/VBoxContainer/HBoxPersonajes/BtnJugador.pressed.connect(_on_btn_jugador_pressed)
	$PanelLobby/VBoxContainer/HBoxPersonajes/BtnFantasma.pressed.connect(_on_btn_fantasma_pressed)
	$PanelLobby/VBoxContainer/BtnListo.toggled.connect(_on_btn_listo_toggled)
	$PanelLobby/VBoxContainer/HostControls/SelectorModo.item_selected.connect(_on_selector_modo_item_selected)
	$PanelLobby/VBoxContainer/HostControls/SelectorNivel.item_selected.connect(_on_selector_nivel_item_selected)
	$PanelLobby/VBoxContainer/HostControls/BtnIniciar.pressed.connect(_on_btn_iniciar_pressed)
	
	$PanelAmigos/VBoxContainer/HBoxAdd/BtnAgregar.pressed.connect(_on_btn_agregar_amigo_pressed)
	$PanelAmigos/VBoxContainer/BtnEliminar.pressed.connect(_on_btn_eliminar_amigo_pressed)
	$PanelAmigos/VBoxContainer/BtnVolver.pressed.connect(_on_btn_volver_amigos_pressed)
	
	$PanelOpciones/VBoxContainer/VolumeSlider.value_changed.connect(_on_volume_slider_value_changed)
	$PanelOpciones/VBoxContainer/BtnFullscreen.toggled.connect(_on_btn_fullscreen_toggled)
	$PanelOpciones/VBoxContainer/BtnVolver.pressed.connect(_on_btn_volver_opciones_pressed)
	
	# Configurar opciones del selector de nivel en Modo Libre
	_configurar_selector_niveles()
	
	# Cargar amigos
	_actualizar_lista_amigos()
	
	# Cargar opciones guardadas
	_cargar_opciones()
	
	# Conectar Señales de RedManager
	if is_instance_valid(RedManager):
		RedManager.conexion_establecida.connect(_on_conexion_establecida)
		RedManager.conexion_perdida.connect(_on_conexion_perdida)
		RedManager.personajes_actualizados.connect(_on_personajes_actualizados)
		RedManager.ready_estados_actualizados.connect(_on_ready_estados_actualizados)
		RedManager.modo_juego_actualizado.connect(_on_modo_juego_actualizado)
		
		# Nuevas señales del RedManager
		RedManager.lan_server_found.connect(_on_lan_server_found)
		RedManager.salas_actualizadas.connect(_on_salas_actualizadas)
		RedManager.sala_entrar.connect(_on_sala_entrar)
		RedManager.sala_salir.connect(_on_sala_salir)
		
		# Si ya estamos conectados (por ejemplo, al volver de un nivel), ir directo al lobby
		if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
			_on_conexion_establecida()
		# SE HA ELIMINADO EL AUTOCONECTAR AUTOMÁTICO AL INICIAR

func _process(delta):
	# Rotación lenta de los modelos 3D en la vista del lobby
	if is_instance_valid(model_jugador):
		model_jugador.rotate_y(delta * 0.4)
	if is_instance_valid(model_fantasma):
		model_fantasma.rotate_y(delta * 0.4)

func _inicializar_nuevos_paneles():
	# Obtener estilos existentes para mantener la consistencia visual
	var style_panel = panel_principal.get_theme_stylebox("panel")
	var sample_btn = $PanelPrincipal/VBoxContainer/BtnJugar
	var style_btn_normal = sample_btn.get_theme_stylebox("normal")
	var style_btn_hover = sample_btn.get_theme_stylebox("hover")
	var style_btn_pressed = sample_btn.get_theme_stylebox("pressed")
	var style_btn_disabled = sample_btn.get_theme_stylebox("disabled")
	var style_input = amigo_nombre_input.get_theme_stylebox("normal")
	
	# 1. PANEL SELECCIÓN DE MODOS (LOCAL VS ONLINE)
	panel_modos = Panel.new()
	panel_modos.name = "PanelModos"
	panel_modos.visible = false
	panel_modos.add_theme_stylebox_override("panel", style_panel)
	add_child(panel_modos)
	
	panel_modos.anchor_left = 0.5
	panel_modos.anchor_right = 0.5
	panel_modos.anchor_top = 0.5
	panel_modos.anchor_bottom = 0.5
	panel_modos.offset_left = -210
	panel_modos.offset_top = -170
	panel_modos.offset_right = 210
	panel_modos.offset_bottom = 170
	panel_modos.custom_minimum_size = Vector2(420, 340)
	panel_modos.size = Vector2(420, 340)
	
	var vbox_modos = VBoxContainer.new()
	vbox_modos.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox_modos.offset_left = 30
	vbox_modos.offset_top = 30
	vbox_modos.offset_right = -30
	vbox_modos.offset_bottom = -30
	vbox_modos.add_theme_constant_override("separation", 16)
	vbox_modos.alignment = BoxContainer.ALIGNMENT_CENTER
	panel_modos.add_child(vbox_modos)
	
	var title_modos = Label.new()
	title_modos.text = "Seleccionar Conexión"
	title_modos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_modos.add_theme_font_size_override("font_size", 28)
	vbox_modos.add_child(title_modos)
	
	var subt_modos = Label.new()
	subt_modos.text = "¿Cómo quieres conectarte hoy?"
	subt_modos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subt_modos.add_theme_color_override("font_color", Color(0.6, 0.55, 0.75))
	subt_modos.add_theme_font_size_override("font_size", 14)
	vbox_modos.add_child(subt_modos)
	
	var sep_modos = HSeparator.new()
	vbox_modos.add_child(sep_modos)
	
	btn_modo_local = Button.new()
	btn_modo_local.text = "Modo Local (LAN)"
	btn_modo_local.custom_minimum_size = Vector2(0, 46)
	btn_modo_local.add_theme_stylebox_override("normal", style_btn_normal)
	btn_modo_local.add_theme_stylebox_override("hover", style_btn_hover)
	btn_modo_local.add_theme_stylebox_override("pressed", style_btn_pressed)
	btn_modo_local.add_theme_stylebox_override("disabled", style_btn_disabled)
	btn_modo_local.add_theme_font_size_override("font_size", 16)
	btn_modo_local.pressed.connect(_on_btn_modo_local_pressed)
	vbox_modos.add_child(btn_modo_local)
	
	btn_modo_online = Button.new()
	btn_modo_online.text = "Modo Online (Internet)"
	btn_modo_online.custom_minimum_size = Vector2(0, 46)
	btn_modo_online.add_theme_stylebox_override("normal", style_btn_normal)
	btn_modo_online.add_theme_stylebox_override("hover", style_btn_hover)
	btn_modo_online.add_theme_stylebox_override("pressed", style_btn_pressed)
	btn_modo_online.add_theme_stylebox_override("disabled", style_btn_disabled)
	btn_modo_online.add_theme_font_size_override("font_size", 16)
	btn_modo_online.pressed.connect(_on_btn_modo_online_pressed)
	vbox_modos.add_child(btn_modo_online)
	
	btn_volver_modos = Button.new()
	btn_volver_modos.text = "Volver al Menú"
	btn_volver_modos.custom_minimum_size = Vector2(0, 40)
	btn_volver_modos.add_theme_stylebox_override("normal", style_btn_normal)
	btn_volver_modos.add_theme_stylebox_override("hover", style_btn_hover)
	btn_volver_modos.add_theme_stylebox_override("pressed", style_btn_pressed)
	btn_volver_modos.add_theme_stylebox_override("disabled", style_btn_disabled)
	btn_volver_modos.add_theme_font_size_override("font_size", 14)
	btn_volver_modos.pressed.connect(_on_btn_volver_modos_pressed)
	vbox_modos.add_child(btn_volver_modos)
	
	# 2. PANEL SALAS (ROOM MATCHMAKING DEDICADO)
	panel_salas = Panel.new()
	panel_salas.name = "PanelSalas"
	panel_salas.visible = false
	panel_salas.add_theme_stylebox_override("panel", style_panel)
	add_child(panel_salas)
	
	panel_salas.anchor_left = 0.5
	panel_salas.anchor_right = 0.5
	panel_salas.anchor_top = 0.5
	panel_salas.anchor_bottom = 0.5
	panel_salas.offset_left = -260
	panel_salas.offset_top = -230
	panel_salas.offset_right = 260
	panel_salas.offset_bottom = 230
	panel_salas.custom_minimum_size = Vector2(520, 460)
	panel_salas.size = Vector2(520, 460)
	
	var vbox_salas = VBoxContainer.new()
	vbox_salas.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox_salas.offset_left = 30
	vbox_salas.offset_top = 20
	vbox_salas.offset_right = -30
	vbox_salas.offset_bottom = -20
	vbox_salas.add_theme_constant_override("separation", 12)
	vbox_salas.alignment = BoxContainer.ALIGNMENT_CENTER
	panel_salas.add_child(vbox_salas)
	
	var title_salas = Label.new()
	title_salas.text = "Salas Online"
	title_salas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_salas.add_theme_font_size_override("font_size", 28)
	vbox_salas.add_child(title_salas)
	
	var lbl_salas_desc = Label.new()
	lbl_salas_desc.text = "Selecciona una sala o crea una nueva:"
	lbl_salas_desc.add_theme_font_size_override("font_size", 14)
	vbox_salas.add_child(lbl_salas_desc)
	
	lista_salas = ItemList.new()
	lista_salas.custom_minimum_size = Vector2(0, 160)
	lista_salas.add_theme_stylebox_override("panel", style_input)
	vbox_salas.add_child(lista_salas)
	
	var hbox_create = HBoxContainer.new()
	hbox_create.add_theme_constant_override("separation", 8)
	vbox_salas.add_child(hbox_create)
	
	sala_nombre_input = LineEdit.new()
	sala_nombre_input.placeholder_text = "Nombre de la sala..."
	sala_nombre_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sala_nombre_input.add_theme_stylebox_override("normal", style_input)
	hbox_create.add_child(sala_nombre_input)
	
	btn_crear_sala = Button.new()
	btn_crear_sala.text = "Crear"
	btn_crear_sala.custom_minimum_size = Vector2(100, 38)
	btn_crear_sala.add_theme_stylebox_override("normal", style_btn_normal)
	btn_crear_sala.add_theme_stylebox_override("hover", style_btn_hover)
	btn_crear_sala.add_theme_stylebox_override("pressed", style_btn_pressed)
	btn_crear_sala.add_theme_stylebox_override("disabled", style_btn_disabled)
	btn_crear_sala.pressed.connect(_on_btn_crear_sala_pressed)
	hbox_create.add_child(btn_crear_sala)
	
	var hbox_actions = HBoxContainer.new()
	hbox_actions.add_theme_constant_override("separation", 10)
	vbox_salas.add_child(hbox_actions)
	
	btn_unirse_sala = Button.new()
	btn_unirse_sala.text = "Unirse a Sala"
	btn_unirse_sala.custom_minimum_size = Vector2(0, 40)
	btn_unirse_sala.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_unirse_sala.add_theme_stylebox_override("normal", style_btn_normal)
	btn_unirse_sala.add_theme_stylebox_override("hover", style_btn_hover)
	btn_unirse_sala.add_theme_stylebox_override("pressed", style_btn_pressed)
	btn_unirse_sala.add_theme_stylebox_override("disabled", style_btn_disabled)
	btn_unirse_sala.pressed.connect(_on_btn_unirse_sala_pressed)
	hbox_actions.add_child(btn_unirse_sala)
	
	btn_refrescar_salas = Button.new()
	btn_refrescar_salas.text = "Refrescar"
	btn_refrescar_salas.custom_minimum_size = Vector2(120, 40)
	btn_refrescar_salas.add_theme_stylebox_override("normal", style_btn_normal)
	btn_refrescar_salas.add_theme_stylebox_override("hover", style_btn_hover)
	btn_refrescar_salas.add_theme_stylebox_override("pressed", style_btn_pressed)
	btn_refrescar_salas.add_theme_stylebox_override("disabled", style_btn_disabled)
	btn_refrescar_salas.pressed.connect(_on_btn_refrescar_salas_pressed)
	hbox_actions.add_child(btn_refrescar_salas)
	
	btn_volver_salas = Button.new()
	btn_volver_salas.text = "Salir de Online"
	btn_volver_salas.custom_minimum_size = Vector2(0, 40)
	btn_volver_salas.add_theme_stylebox_override("normal", style_btn_normal)
	btn_volver_salas.add_theme_stylebox_override("hover", style_btn_hover)
	btn_volver_salas.add_theme_stylebox_override("pressed", style_btn_pressed)
	btn_volver_salas.add_theme_stylebox_override("disabled", style_btn_disabled)
	btn_volver_salas.pressed.connect(_on_btn_volver_salas_pressed)
	vbox_salas.add_child(btn_volver_salas)
	
	# 3. LAN DISCOVERY EN PANEL JUGAR (LOCAL)
	var vbox_jugar = $PanelJugar/VBoxContainer
	
	label_servidores_lan = Label.new()
	label_servidores_lan.text = "Partidas en Red Local (LAN):"
	label_servidores_lan.add_theme_font_size_override("font_size", 14)
	
	var idx_volver = vbox_jugar.get_child_count() - 1
	vbox_jugar.add_child(label_servidores_lan)
	vbox_jugar.move_child(label_servidores_lan, idx_volver)
	
	lista_servidores_lan = ItemList.new()
	lista_servidores_lan.custom_minimum_size = Vector2(0, 100)
	lista_servidores_lan.add_theme_stylebox_override("panel", style_input)
	lista_servidores_lan.item_selected.connect(_on_lan_server_selected)
	vbox_jugar.add_child(lista_servidores_lan)
	vbox_jugar.move_child(lista_servidores_lan, idx_volver + 1)
	
	# 4. VIEWPORT 3D EN PANEL LOBBY
	var vbox_lobby = $PanelLobby/VBoxContainer
	var label_elige = $PanelLobby/VBoxContainer/LabelElige
	
	subviewport_container = SubViewportContainer.new()
	subviewport_container.custom_minimum_size = Vector2(0, 200)
	subviewport_container.stretch = true
	var idx_elige = label_elige.get_index()
	vbox_lobby.add_child(subviewport_container)
	vbox_lobby.move_child(subviewport_container, idx_elige + 1)
	
	subviewport = SubViewport.new()
	subviewport.transparent_bg = true
	subviewport.msaa_3d = Viewport.MSAA_4X
	subviewport_container.add_child(subviewport)
	
	var root_3d = Node3D.new()
	subviewport.add_child(root_3d)
	
	camera_3d = Camera3D.new()
	camera_3d.transform = Transform3D(Basis(), Vector3(0, 0.75, 2.3))
	camera_3d.current = true
	root_3d.add_child(camera_3d)
	
	light_3d = DirectionalLight3D.new()
	light_3d.transform = Transform3D(Basis().rotated(Vector3.UP, deg_to_rad(45)).rotated(Vector3.RIGHT, deg_to_rad(-30)), Vector3.ZERO)
	root_3d.add_child(light_3d)
	
	# Modelo Jugador Vivo
	model_jugador = MeshInstance3D.new()
	model_jugador.mesh = load("res://assets/Modelos/Provicional/untitled.obj")
	model_jugador.transform = Transform3D(Basis().scaled(Vector3(0.6, 0.6, 0.6)), Vector3(-0.55, 0.05, 0))
	root_3d.add_child(model_jugador)
	
	# Modelo Fantasma
	model_fantasma = MeshInstance3D.new()
	model_fantasma.mesh = load("res://assets/Modelos/Provicional/misty.obj")
	model_fantasma.transform = Transform3D(Basis().scaled(Vector3(0.6, 0.6, 0.6)), Vector3(0.55, 0.1, 0))
	root_3d.add_child(model_fantasma)
	
	# ETIQUETAS 3D SOBRE MODELOS
	label_3d_jugador = Label3D.new()
	label_3d_jugador.transform = Transform3D(Basis(), Vector3(-0.55, 1.1, 0))
	label_3d_jugador.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d_jugador.font_size = 32
	label_3d_jugador.outline_size = 8
	label_3d_jugador.text = ""
	root_3d.add_child(label_3d_jugador)
	
	label_3d_fantasma = Label3D.new()
	label_3d_fantasma.transform = Transform3D(Basis(), Vector3(0.55, 1.1, 0))
	label_3d_fantasma.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d_fantasma.font_size = 32
	label_3d_fantasma.outline_size = 8
	label_3d_fantasma.text = ""
	root_3d.add_child(label_3d_fantasma)

func _configurar_selector_niveles():
	selector_nivel.clear()
	if is_instance_valid(RedManager):
		for path in RedManager.NIVELES:
			var nombre_nivel = path.get_file().get_basename().capitalize()
			selector_nivel.add_item(nombre_nivel)

# --- Navegación entre Paneles ---

func _mostrar_panel(panel_activo: Panel):
	panel_principal.visible = (panel_activo == panel_principal)
	panel_jugar.visible = (panel_activo == panel_jugar)
	panel_lobby.visible = (panel_activo == panel_lobby)
	panel_amigos.visible = (panel_activo == panel_amigos)
	panel_opciones.visible = (panel_activo == panel_opciones)
	
	if is_instance_valid(panel_modos):
		panel_modos.visible = (panel_activo == panel_modos)
	if is_instance_valid(panel_salas):
		panel_salas.visible = (panel_activo == panel_salas)

# --- Panel Principal ---

func _on_btn_jugar_pressed():
	# En lugar de ir a panel_jugar directo, vamos a panel_modos
	_mostrar_panel(panel_modos)

func _on_btn_amigos_menu_pressed():
	_mostrar_panel(panel_amigos)
	_actualizar_lista_amigos()

func _on_btn_opciones_pressed():
	_mostrar_panel(panel_opciones)

func _on_btn_salir_pressed():
	get_tree().quit()

# --- Panel Selección de Modo (Local vs Online) ---

func _on_btn_modo_local_pressed():
	# Iniciar el receptor LAN de UDP
	if is_instance_valid(RedManager):
		RedManager.iniciar_lan_listener()
	
	_mostrar_panel(panel_jugar)
	if is_instance_valid(RedManager):
		local_ip_label.text = "Tu IP local para WiFi: " + RedManager.get_local_ip()
	_actualizar_servidores_lan()

func _on_btn_modo_online_pressed():
	# Conectarse al servidor dedicado en internet
	if is_instance_valid(RedManager):
		autoconectando = false
		_mostrar_panel(panel_lobby)
		lobby_status_label.text = "Conectando al servidor online principal..."
		btn_jugador.disabled = true
		btn_fantasma.disabled = true
		btn_listo.disabled = true
		
		# Conectar a la IP pública del matchmaking
		RedManager.unirse_a_partida("134.65.24.63")

func _on_btn_volver_modos_pressed():
	_mostrar_panel(panel_principal)

# --- Panel Jugar / Conexión Local ---

func _on_btn_host_pressed():
	if is_instance_valid(RedManager):
		RedManager.crear_partida()

func _on_btn_conectar_pressed():
	if is_instance_valid(RedManager):
		var target_ip = ip_input.text.strip_edges()
		if target_ip.is_empty():
			target_ip = "127.0.0.1"
		RedManager.unirse_a_partida(target_ip)
		lobby_status_label.text = "Conectando a " + target_ip + "..."
		_mostrar_panel(panel_lobby)

func _on_quick_join_option_item_selected(index):
	if index > 0:
		var nombre_amigo = quick_join_option.get_item_text(index)
		var ip_amigo = amigos_dict.get(nombre_amigo, "127.0.0.1")
		ip_input.text = ip_amigo

func _on_btn_volver_jugar_pressed():
	if is_instance_valid(RedManager):
		RedManager.detener_lan_listener()
	_mostrar_panel(panel_modos)

# --- Autodescubrimiento LAN ---

func _on_lan_server_found(_ip, _port, _name):
	_actualizar_servidores_lan()

func _actualizar_servidores_lan():
	if not is_instance_valid(lista_servidores_lan) or not is_instance_valid(RedManager):
		return
	lista_servidores_lan.clear()
	for ip in RedManager.lan_servers_discovered:
		var s = RedManager.lan_servers_discovered[ip]
		lista_servidores_lan.add_item(s["name"] + " (" + ip + ")")
	
	if lista_servidores_lan.item_count == 0:
		lista_servidores_lan.add_item("Buscando partidas en red local...")

func _on_lan_server_selected(index):
	if lista_servidores_lan.item_count > 0:
		var text = lista_servidores_lan.get_item_text(index)
		if "(" in text:
			var ip = text.split(" (")[1].replace(")", "").strip_edges()
			ip_input.text = ip

# --- Panel Salas Online ---

func _on_salas_actualizadas(_salas):
	if panel_salas.visible:
		_actualizar_lista_salas()
	elif panel_lobby.visible:
		_actualizar_ui_lobby()
		_actualizar_lobby_3d()

func _actualizar_lista_salas():
	if not is_instance_valid(RedManager) or not panel_salas.visible: return
	lista_salas.clear()
	for nombre in RedManager.salas:
		var sala = RedManager.salas[nombre]
		var count = 1 if sala["guest_id"] == 0 else 2
		var status = "Abierta" if count < 2 else "Llena"
		lista_salas.add_item(nombre + " (" + str(count) + "/2) [" + status + "]")
		
	if lista_salas.item_count == 0:
		lista_salas.add_item("No hay salas activas. ¡Crea una!")

func _on_btn_crear_sala_pressed():
	var nombre = sala_nombre_input.text.strip_edges()
	if nombre.is_empty():
		return
	if is_instance_valid(RedManager):
		RedManager.rpc_crear_sala.rpc(nombre)
		sala_nombre_input.clear()

func _on_btn_unirse_sala_pressed():
	var items = lista_salas.get_selected_items()
	if items.size() > 0:
		var text = lista_salas.get_item_text(items[0])
		if " (" in text:
			var nombre_sala = text.split(" (")[0]
			if is_instance_valid(RedManager):
				RedManager.rpc_unirse_a_sala.rpc(nombre_sala)

func _on_btn_refrescar_salas_pressed():
	if is_instance_valid(RedManager):
		# Enviar un ping o sincronización (el servidor envía automáticamente ante cualquier cambio)
		_actualizar_lista_salas()

func _on_btn_volver_salas_pressed():
	if is_instance_valid(RedManager):
		RedManager.desconectar()
	_mostrar_panel(panel_modos)

func _on_sala_entrar(nombre_sala):
	_mostrar_panel(panel_lobby)
	_actualizar_ui_lobby()
	_actualizar_lobby_3d()

func _on_sala_salir():
	if is_instance_valid(RedManager) and RedManager.es_servidor_online_dedicado:
		_mostrar_panel(panel_salas)
		_actualizar_lista_salas()
	else:
		_mostrar_panel(panel_jugar)

# --- Lobby / Selección de Personajes ---

func _on_conexion_establecida():
	autoconectando = false
	if is_instance_valid(RedManager):
		if RedManager.es_servidor_online_dedicado:
			# Si nos conectamos al matchmaking online, mostrar salas
			_mostrar_panel(panel_salas)
			_actualizar_lista_salas()
		else:
			# Si nos conectamos P2P o localmente, ir al lobby
			if RedManager.iniciar_directo_p2p:
				# Si es P2P automático directo, no mostramos el panel, se inicia directo
				pass
			else:
				_mostrar_panel(panel_lobby)
				_actualizar_ui_lobby()
				_actualizar_lobby_3d()

func _on_conexion_perdida():
	_resetear_seleccion_lobby()
	if autoconectando:
		autoconectando = false
		_mostrar_panel(panel_principal)
	else:
		if is_instance_valid(RedManager) and RedManager.es_servidor_online_dedicado:
			_mostrar_panel(panel_modos)
		else:
			_mostrar_panel(panel_jugar)
		lobby_status_label.text = "Desconectado o error de conexión."

func _on_btn_desconectar_pressed():
	if is_instance_valid(RedManager):
		if RedManager.es_servidor_online_dedicado:
			RedManager.rpc_salir_de_sala.rpc()
		else:
			RedManager.desconectar()
			_mostrar_panel(panel_jugar)

func _on_btn_jugador_pressed():
	if is_instance_valid(RedManager):
		if RedManager.es_servidor_online_dedicado:
			var mi_id = multiplayer.get_unique_id()
			var sala = RedManager.salas.get(RedManager.mi_sala_actual)
			if sala:
				var es_host = (sala["host_id"] == mi_id)
				var personaje = "jugador"
				if (es_host and sala["char_guest"] == personaje) or (not es_host and sala["char_host"] == personaje):
					return # Ya elegido
				
				var listo = btn_listo.button_pressed if not es_host else false
				var modo = sala["modo"]
				var nivel = sala["nivel_index"]
				RedManager.rpc_actualizar_seleccion_sala.rpc(personaje, listo, modo, nivel)
		else:
			RedManager.rpc_seleccionar_personaje.rpc("jugador")

func _on_btn_fantasma_pressed():
	if is_instance_valid(RedManager):
		if RedManager.es_servidor_online_dedicado:
			var mi_id = multiplayer.get_unique_id()
			var sala = RedManager.salas.get(RedManager.mi_sala_actual)
			if sala:
				var es_host = (sala["host_id"] == mi_id)
				var personaje = "fantasma"
				if (es_host and sala["char_guest"] == personaje) or (not es_host and sala["char_host"] == personaje):
					return # Ya elegido
				
				var listo = btn_listo.button_pressed if not es_host else false
				var modo = sala["modo"]
				var nivel = sala["nivel_index"]
				RedManager.rpc_actualizar_seleccion_sala.rpc(personaje, listo, modo, nivel)
		else:
			RedManager.rpc_seleccionar_personaje.rpc("fantasma")

func _on_btn_listo_toggled(button_pressed):
	if is_instance_valid(RedManager):
		if RedManager.es_servidor_online_dedicado:
			var mi_id = multiplayer.get_unique_id()
			var sala = RedManager.salas.get(RedManager.mi_sala_actual)
			if sala and sala["guest_id"] == mi_id:
				var personaje = sala["char_guest"]
				var modo = sala["modo"]
				var nivel = sala["nivel_index"]
				RedManager.rpc_actualizar_seleccion_sala.rpc(personaje, button_pressed, modo, nivel)
				btn_listo.text = "¡Listo!" if button_pressed else "Prepararse"
		else:
			RedManager.rpc_establecer_listo.rpc(button_pressed)
			btn_listo.text = "¡Listo!" if button_pressed else "Prepararse"

func _on_selector_modo_item_selected(index):
	if is_instance_valid(RedManager):
		var modo = "historia" if index == 0 else "libre"
		if RedManager.es_servidor_online_dedicado:
			var mi_id = multiplayer.get_unique_id()
			var sala = RedManager.salas.get(RedManager.mi_sala_actual)
			if sala and sala["host_id"] == mi_id:
				var personaje = sala["char_host"]
				var nivel = selector_nivel.selected
				RedManager.rpc_actualizar_seleccion_sala.rpc(personaje, false, modo, nivel)
		else:
			var mi_id = multiplayer.get_unique_id()
			if mi_id == RedManager.get_lider_peer_id():
				RedManager.rpc_establecer_modo.rpc(modo)

func _on_selector_nivel_item_selected(index):
	if is_instance_valid(RedManager):
		if RedManager.es_servidor_online_dedicado:
			var mi_id = multiplayer.get_unique_id()
			var sala = RedManager.salas.get(RedManager.mi_sala_actual)
			if sala and sala["host_id"] == mi_id:
				var personaje = sala["char_host"]
				var modo = sala["modo"]
				RedManager.rpc_actualizar_seleccion_sala.rpc(personaje, false, modo, index)

func _on_btn_iniciar_pressed():
	if is_instance_valid(RedManager):
		if RedManager.es_servidor_online_dedicado:
			lobby_status_label.text = "Iniciando partida online..."
			print("[MenuInicio] Solicitando inicio P2P online")
			RedManager.rpc_solicitar_inicio_p2p.rpc()
		else:
			var mi_id = multiplayer.get_unique_id()
			var lider_id = RedManager.get_lider_peer_id()
			print("[MenuInicio] Intentando iniciar. mi_id=", mi_id, " lider_id=", lider_id)
			if mi_id == lider_id:
				var modo = "historia" if selector_modo.selected == 0 else "libre"
				var idx_nivel = selector_nivel.selected
				lobby_status_label.text = "Cargando nivel... Modo: " + modo
				print("[MenuInicio] Enviando RPC inicio. modo=", modo, " nivel=", idx_nivel)
				RedManager.rpc_solicitar_inicio.rpc(modo, idx_nivel)
			else:
				lobby_status_label.text = "Error: No eres el líder."
				print("[MenuInicio] ERROR: No soy líder. mi_id=", mi_id, " lider=", lider_id)

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
	btn_jugador.disabled = false
	btn_jugador.text = "Elegir Jugador Vivo"
	btn_fantasma.disabled = false
	btn_fantasma.text = "Elegir Fantasma"
	btn_listo.button_pressed = false
	btn_listo.text = "Prepararse"

func _actualizar_ui_lobby():
	if not is_instance_valid(RedManager): return
	
	var mi_id = multiplayer.get_unique_id()
	var es_lider = false
	
	var jugador_elegido_por = 0
	var fantasma_elegido_por = 0
	var guest_listo = false
	var modo_nombre = "historia"
	var nivel_index = 0
	var total_jugadores = 0
	
	if RedManager.es_servidor_online_dedicado:
		var sala = RedManager.salas.get(RedManager.mi_sala_actual)
		if not sala: return
		
		es_lider = (sala["host_id"] == mi_id)
		total_jugadores = 1 if sala["guest_id"] == 0 else 2
		
		if sala["char_host"] == "jugador":
			jugador_elegido_por = sala["host_id"]
		elif sala["char_host"] == "fantasma":
			fantasma_elegido_por = sala["host_id"]
			
		if sala["char_guest"] == "jugador":
			jugador_elegido_por = sala["guest_id"]
		elif sala["char_guest"] == "fantasma":
			fantasma_elegido_por = sala["guest_id"]
			
		guest_listo = sala["ready_guest"]
		modo_nombre = sala["modo"]
		nivel_index = sala["nivel_index"]
	else:
		es_lider = (mi_id == RedManager.get_lider_peer_id())
		total_jugadores = RedManager.peer_personajes.size()
		
		for peer in RedManager.peer_personajes:
			var personaje = RedManager.peer_personajes[peer]
			if personaje == "jugador":
				jugador_elegido_por = peer
			elif personaje == "fantasma":
				fantasma_elegido_por = peer
				
		for peer in RedManager.peer_listos:
			if peer != RedManager.get_lider_peer_id() and RedManager.peer_listos[peer]:
				guest_listo = true
		modo_nombre = RedManager.modo_juego
		nivel_index = RedManager.nivel_actual_index
	
	# Mostrar controles de Host o Cliente
	host_controls_container.visible = es_lider
	client_status_container.visible = not es_lider
	btn_listo.visible = not es_lider
	
	# 1. Botones de Selección de Personajes
	# Jugador Vivo
	if jugador_elegido_por == mi_id:
		btn_jugador.disabled = false
		btn_jugador.text = "Jugador Vivo (Tú)"
	elif jugador_elegido_por != 0:
		btn_jugador.disabled = true
		btn_jugador.text = "Jugador Vivo (Compañero)"
	else:
		btn_jugador.disabled = false
		btn_jugador.text = "Elegir Jugador Vivo"
		
	# Fantasma
	if fantasma_elegido_por == mi_id:
		btn_fantasma.disabled = false
		btn_fantasma.text = "Fantasma (Tú)"
	elif fantasma_elegido_por != 0:
		btn_fantasma.disabled = true
		btn_fantasma.text = "Fantasma (Compañero)"
	else:
		btn_fantasma.disabled = false
		btn_fantasma.text = "Elegir Fantasma"
		
	# 2. Modos de Juego
	if es_lider:
		selector_modo.selected = 0 if modo_nombre == "historia" else 1
		selector_nivel.visible = (modo_nombre == "libre")
		if selector_nivel.visible:
			selector_nivel.selected = nivel_index
	else:
		var nivel_label = ""
		if modo_nombre == "libre" and nivel_index < RedManager.NIVELES.size():
			nivel_label = " - " + RedManager.NIVELES[nivel_index].get_file().get_basename().capitalize()
		modo_cliente_label.text = "Modo de juego: " + ("Historia (En orden)" if modo_nombre == "historia" else "Libre" + nivel_label)
		
	# 3. Validar Inicio
	if es_lider:
		var lider_eligio = false
		if RedManager.es_servidor_online_dedicado:
			var sala = RedManager.salas.get(RedManager.mi_sala_actual)
			lider_eligio = sala["char_host"] != "" if sala else false
		else:
			lider_eligio = RedManager.peer_personajes.get(mi_id, "") != ""
			
		var todos_personaje = (jugador_elegido_por != 0 and fantasma_elegido_por != 0)
		btn_iniciar.disabled = not (todos_personaje and guest_listo and lider_eligio)
		
		var host_status_text = ""
		if btn_iniciar.disabled:
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
		if not RedManager.es_servidor_online_dedicado:
			if multiplayer.is_server():
				ip_text = "\nIP Local: " + RedManager.get_local_ip()
				if RedManager.ip_publica != "":
					ip_text += " | IP Pública: " + RedManager.ip_publica
			else:
				ip_text = "\nConectado localmente."
		else:
			ip_text = "\nEn sala de servidor online dedicado."
			
		lobby_status_label.text = host_status_text + ip_text
	else:
		var cliente_eligio = false
		if RedManager.es_servidor_online_dedicado:
			var sala = RedManager.salas.get(RedManager.mi_sala_actual)
			cliente_eligio = sala["char_guest"] != "" if sala else false
		else:
			cliente_eligio = RedManager.peer_personajes.get(mi_id, "") != ""
			
		btn_listo.disabled = not cliente_eligio
		if not cliente_eligio:
			client_status_label.text = "Elige un personaje para poder prepararte."
		elif not guest_listo:
			client_status_label.text = "¡Personaje elegido! Presiona 'Prepararse'."
		else:
			client_status_label.text = "¡Estás listo! Esperando a que el host inicie..."

func _actualizar_lobby_3d():
	if not is_instance_valid(RedManager) or not is_instance_valid(model_jugador): return
	
	# Material translúcido para personajes no elegidos
	var mat_unselected = StandardMaterial3D.new()
	mat_unselected.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_unselected.albedo_color = Color(0.2, 0.2, 0.2, 0.4)
	
	var char_jugador_nombre = ""
	var char_fantasma_nombre = ""
	var jugador_elegido = false
	var fantasma_elegido = false
	
	var mi_id = multiplayer.get_unique_id()
	
	if RedManager.es_servidor_online_dedicado:
		var sala = RedManager.salas.get(RedManager.mi_sala_actual)
		if sala:
			if sala["char_host"] == "jugador":
				jugador_elegido = true
				char_jugador_nombre = "Tú (Líder)" if sala["host_id"] == mi_id else "Compañero"
			elif sala["char_host"] == "fantasma":
				fantasma_elegido = true
				char_fantasma_nombre = "Tú (Líder)" if sala["host_id"] == mi_id else "Compañero"
				
			if sala["char_guest"] == "jugador":
				jugador_elegido = true
				char_jugador_nombre = "Tú" if sala["guest_id"] == mi_id else "Compañero"
			elif sala["char_guest"] == "fantasma":
				fantasma_elegido = true
				char_fantasma_nombre = "Tú" if sala["guest_id"] == mi_id else "Compañero"
	else:
		# P2P / Local
		for peer in RedManager.peer_personajes:
			var personaje = RedManager.peer_personajes[peer]
			var display_name = "Tú" if peer == mi_id else "Compañero"
			
			if personaje == "jugador":
				jugador_elegido = true
				char_jugador_nombre = display_name
			elif personaje == "fantasma":
				fantasma_elegido = true
				char_fantasma_nombre = display_name
				
	# Aplicar visuales a Jugador Vivo
	if is_instance_valid(model_jugador) and is_instance_valid(label_3d_jugador):
		if jugador_elegido:
			model_jugador.material_override = null
			model_jugador.scale = Vector3(0.72, 0.72, 0.72)
			label_3d_jugador.text = char_jugador_nombre
			label_3d_jugador.modulate = Color(1.0, 0.6, 0.2) # Anaranjado
		else:
			model_jugador.material_override = mat_unselected
			model_jugador.scale = Vector3(0.6, 0.6, 0.6)
			label_3d_jugador.text = ""
			
	# Aplicar visuales a Fantasma
	if is_instance_valid(model_fantasma) and is_instance_valid(label_3d_fantasma):
		if fantasma_elegido:
			model_fantasma.material_override = null
			model_fantasma.scale = Vector3(0.72, 0.72, 0.72)
			label_3d_fantasma.text = char_fantasma_nombre
			label_3d_fantasma.modulate = Color(0.2, 0.6, 1.0) # Azul
		else:
			model_fantasma.material_override = mat_unselected
			model_fantasma.scale = Vector3(0.6, 0.6, 0.6)
			label_3d_fantasma.text = ""

# --- Panel Amigos ---

func _on_btn_agregar_amigo_pressed():
	var nombre = amigo_nombre_input.text.strip_edges()
	var ip = amigo_ip_input.text.strip_edges()
	if nombre.is_empty() or ip.is_empty():
		return
		
	if is_instance_valid(RedManager):
		RedManager.agregar_amigo(nombre, ip)
		amigo_nombre_input.clear()
		amigo_ip_input.clear()
		_actualizar_lista_amigos()

func _actualizar_lista_amigos():
	if not is_instance_valid(RedManager): return
	
	amigos_dict = RedManager.cargar_amigos()
	lista_amigos.clear()
	
	quick_join_option.clear()
	quick_join_option.add_item("Seleccionar Amigo Rápido...")
	
	for nombre in amigos_dict:
		var ip = amigos_dict[nombre]
		lista_amigos.add_item(nombre + " (" + ip + ")")
		quick_join_option.add_item(nombre)

func _on_btn_eliminar_amigo_pressed():
	var selected_idx = lista_amigos.get_selected_items()
	if selected_idx.size() > 0:
		var texto = lista_amigos.get_item_text(selected_idx[0])
		var nombre = texto.split(" (")[0]
		if is_instance_valid(RedManager):
			RedManager.eliminar_amigo(nombre)
			_actualizar_lista_amigos()

func _on_btn_volver_amigos_pressed():
	_mostrar_panel(panel_principal)

# --- Panel Opciones ---

func _on_volume_slider_value_changed(value):
	var bus_index = AudioServer.get_bus_index("Master")
	if bus_index != -1:
		var db = linear_to_db(value)
		AudioServer.set_bus_volume_db(bus_index, db)
		_guardar_opciones()

func _on_btn_fullscreen_toggled(button_pressed):
	if button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_guardar_opciones()

func _on_btn_volver_opciones_pressed():
	_mostrar_panel(panel_principal)

# --- Cargar/Guardar Configuración General ---

func _guardar_opciones():
	var config = ConfigFile.new()
	var bus_index = AudioServer.get_bus_index("Master")
	if bus_index != -1:
		config.set_value("audio", "master_volume", db_to_linear(AudioServer.get_bus_volume_db(bus_index)))
	config.set_value("video", "fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	config.save("user://opciones.cfg")

func _cargar_opciones():
	var config = ConfigFile.new()
	var err = config.load("user://opciones.cfg")
	if err == OK:
		var vol = config.get_value("audio", "master_volume", 0.8)
		volume_slider.value = vol
		var bus_index = AudioServer.get_bus_index("Master")
		if bus_index != -1:
			AudioServer.set_bus_volume_db(bus_index, linear_to_db(vol))
			
		var fs = config.get_value("video", "fullscreen", false)
		btn_fullscreen.button_pressed = fs
		if fs:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		volume_slider.value = 0.8
		btn_fullscreen.button_pressed = false
