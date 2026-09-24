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
@onready var btn_ajustar_hud = $PanelOpciones/VBoxContainer/BtnAjustarHUD
@onready var btn_mapear_control = $PanelOpciones/VBoxContainer/BtnMapearControl
@onready var slider_tamano_hud = $PanelOpciones/VBoxContainer/SliderTamanoHUD
@onready var slider_tamano_joy = $PanelOpciones/VBoxContainer/SliderTamanoJoy

# --- NUEVOS NODOS: Creados por código para mantener compatibilidad con TSCN ---
var panel_modos: Panel
var panel_salas: Panel
var panel_un_jugador: Panel

# Elementos PanelModos
var btn_modo_local: Button
var btn_modo_online: Button
var btn_modo_solo: Button
var btn_volver_modos: Button

# Elementos PanelSalas
var lista_salas: ItemList
var sala_nombre_input: LineEdit
var btn_crear_sala: Button
var btn_unirse_sala: Button
var btn_refrescar_salas: Button
var btn_volver_salas: Button

# Elementos PanelUnJugador
var btn_iniciar_solo: Button
var btn_card_vivo_solo: Button
var btn_card_fantasma_solo: Button
var btn_volver_un_jugador: Button

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
var btn_reconectar: Button = null

# Overlay de Color Ambiental de Pantalla
var ambient_overlay: ColorRect = null
var _ambient_tween: Tween = null

# Controllers
var navegacion_ctrl: MenuNavegacionCtrl
var matchmaking_ctrl: MenuMatchmakingCtrl
var lobby_ctrl: MenuLobbyCtrl
var amigos_opciones_ctrl: MenuAmigosOpcionesCtrl

func _ready():
	_inicializar_overlay_ambiente()
	
	matchmaking_ctrl = MenuMatchmakingCtrl.new()
	add_child(matchmaking_ctrl)
	matchmaking_ctrl.init(self)
	
	navegacion_ctrl = MenuNavegacionCtrl.new()
	add_child(navegacion_ctrl)
	navegacion_ctrl.init(self)
	
	lobby_ctrl = MenuLobbyCtrl.new()
	add_child(lobby_ctrl)
	lobby_ctrl.init(self)
	
	amigos_opciones_ctrl = MenuAmigosOpcionesCtrl.new()
	add_child(amigos_opciones_ctrl)
	amigos_opciones_ctrl.init(self)
	
	_crear_ventana_logs()
	mostrar_panel(panel_principal)

func _process(delta):
	if is_instance_valid(lobby_ctrl):
		lobby_ctrl.process(delta)
	if is_instance_valid(matchmaking_ctrl):
		matchmaking_ctrl.process(delta)

func _inicializar_overlay_ambiente():
	ambient_overlay = ColorRect.new()
	ambient_overlay.name = "AmbientColorOverlay"
	ambient_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	ambient_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ambient_overlay.color = Color(0, 0, 0, 0)
	
	var bg_node = get_node_or_null("Background")
	if bg_node:
		var idx = bg_node.get_index()
		add_child(ambient_overlay)
		move_child(ambient_overlay, idx + 1)
	else:
		add_child(ambient_overlay)
		move_child(ambient_overlay, 0)

func cambiar_color_ambiente(color_destino: Color, duracion: float = 0.45):
	if not is_instance_valid(ambient_overlay):
		return
	if is_instance_valid(_ambient_tween) and _ambient_tween.is_running():
		_ambient_tween.kill()
	_ambient_tween = create_tween()
	_ambient_tween.tween_property(ambient_overlay, "color", color_destino, duracion).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func mostrar_panel(panel_activo: Panel):
	if is_instance_valid(navegacion_ctrl):
		navegacion_ctrl.mostrar_panel(panel_activo)

func _unhandled_input(event: InputEvent) -> void:
	# 1. Botón B o Escape: Volver hacia atrás jerárquicamente en los menús
	if event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B):
		if volver_panel_atras():
			get_viewport().set_input_as_handled()
			return
			
	# 2. Si se navega con mando / D-Pad y ningún control tiene foco, enfocar el principal
	if get_viewport().gui_get_focus_owner() == null:
		if (event is InputEventJoypadButton and event.is_pressed()) or (event is InputEventJoypadMotion and abs(event.axis_value) > 0.4):
			_enfocar_panel_activo()

func _enfocar_panel_activo() -> void:
	if not is_instance_valid(navegacion_ctrl):
		return
	var panel_activo = _obtener_panel_activo_actual()
	if panel_activo:
		navegacion_ctrl.enfocar_primer_control_en_panel(panel_activo)

func _obtener_panel_activo_actual() -> Panel:
	if is_instance_valid(panel_salas) and panel_salas.visible:
		return panel_salas
	if is_instance_valid(panel_un_jugador) and panel_un_jugador.visible:
		return panel_un_jugador
	if is_instance_valid(panel_jugar) and panel_jugar.visible:
		return panel_jugar
	if is_instance_valid(panel_lobby) and panel_lobby.visible:
		return panel_lobby
	if is_instance_valid(panel_modos) and panel_modos.visible:
		return panel_modos
	if is_instance_valid(panel_amigos) and panel_amigos.visible:
		return panel_amigos
	if is_instance_valid(panel_opciones) and panel_opciones.visible:
		return panel_opciones
	if is_instance_valid(panel_principal) and panel_principal.visible:
		return panel_principal
	return null

func volver_panel_atras() -> bool:
	# Modales
	var ajuste_ctrl = get_node_or_null("AjusteControl")
	if is_instance_valid(ajuste_ctrl):
		ajuste_ctrl.cerrar()
		return true
	var ajuste_hud = get_node_or_null("AjusteHUD")
	if is_instance_valid(ajuste_hud):
		ajuste_hud.queue_free()
		return true
		
	# Paneles según jerarquía de navegación
	if is_instance_valid(panel_salas) and panel_salas.visible:
		if is_instance_valid(matchmaking_ctrl):
			matchmaking_ctrl._on_btn_volver_salas_pressed()
		return true
	if is_instance_valid(panel_un_jugador) and panel_un_jugador.visible:
		if is_instance_valid(matchmaking_ctrl):
			matchmaking_ctrl._on_btn_volver_un_jugador_pressed()
		return true
	if is_instance_valid(panel_jugar) and panel_jugar.visible:
		if is_instance_valid(matchmaking_ctrl):
			matchmaking_ctrl._on_btn_volver_jugar_pressed()
		return true
	if is_instance_valid(panel_lobby) and panel_lobby.visible:
		if is_instance_valid(lobby_ctrl):
			lobby_ctrl._on_btn_volver_lobby_pressed()
		return true
	if is_instance_valid(panel_modos) and panel_modos.visible:
		if is_instance_valid(matchmaking_ctrl):
			matchmaking_ctrl._on_btn_volver_modos_pressed()
		return true
	if is_instance_valid(panel_amigos) and panel_amigos.visible:
		if is_instance_valid(amigos_opciones_ctrl):
			amigos_opciones_ctrl._on_btn_volver_amigos_pressed()
		return true
	if is_instance_valid(panel_opciones) and panel_opciones.visible:
		if is_instance_valid(amigos_opciones_ctrl):
			amigos_opciones_ctrl._on_btn_volver_opciones_pressed()
		return true
		
	return false

# Utilidad para esperar la primera de varias señales
func _esperar_cualquier_signal(signals: Array) -> int:
	var resultado = -1
	var completado = false
	
	for i in range(signals.size()):
		var sig = signals[i]
		var idx = i
		var callable = func(_a = null, _b = null):
			if not completado:
				resultado = idx
				completado = true
		sig.connect(callable, CONNECT_ONE_SHOT)
	
	while not completado:
		if not is_inside_tree():
			return -1
		await get_tree().process_frame
	
	return resultado

func _crear_ventana_logs() -> void:
	var debug_window = Window.new()
	debug_window.title = "EOS Logs (Diagnostic)"
	debug_window.size = Vector2(800, 600)
	debug_window.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	debug_window.close_requested.connect(func(): debug_window.hide())
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	debug_window.add_child(vbox)
	
	var text_edit = TextEdit.new()
	text_edit.name = "LogText"
	text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_edit.editable = false
	text_edit.add_theme_font_size_override("font_size", 12)
	vbox.add_child(text_edit)
	
	var btn_copy = Button.new()
	btn_copy.text = "Copiar Logs al Portapapeles"
	btn_copy.custom_minimum_size = Vector2(0, 50)
	btn_copy.pressed.connect(func():
		DisplayServer.clipboard_set(text_edit.text)
		var eos_m = get_tree().root.get_node_or_null("EosManager")
		if eos_m and eos_m.has_method("log_diagnostic"):
			eos_m.log_diagnostic("[INFO] Logs copiados al portapapeles.")
	)
	vbox.add_child(btn_copy)
	
	add_child(debug_window)
	debug_window.hide()
	
	var btn_show_logs = Button.new()
	btn_show_logs.text = "📜 Mostrar Logs"
	btn_show_logs.custom_minimum_size = Vector2(160, 40)
	btn_show_logs.position = Vector2(10, 10)
	btn_show_logs.pressed.connect(func(): debug_window.popup())
	add_child(btn_show_logs)
	
	var eos_m = get_tree().root.get_node_or_null("EosManager")
	if eos_m:
		var log_callable = func(msg):
			text_edit.text += msg + "\n"
			text_edit.scroll_vertical = INF
		
		eos_m.log_agregado.connect(log_callable)
		text_edit.tree_exited.connect(func():
			if eos_m.log_agregado.is_connected(log_callable):
				eos_m.log_agregado.disconnect(log_callable)
		)
		
		# Load existing
		if "log_buffer" in eos_m:
			for msg in eos_m.log_buffer:
				text_edit.text += msg + "\n"
			text_edit.scroll_vertical = INF
