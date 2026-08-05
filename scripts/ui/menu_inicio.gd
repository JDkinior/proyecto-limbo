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
var btn_reconectar: Button = null

# Controllers
var navegacion_ctrl: MenuNavegacionCtrl
var matchmaking_ctrl: MenuMatchmakingCtrl
var lobby_ctrl: MenuLobbyCtrl
var amigos_opciones_ctrl: MenuAmigosOpcionesCtrl

func _ready():
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
	
	mostrar_panel(panel_principal)

func _process(delta):
	if is_instance_valid(lobby_ctrl):
		lobby_ctrl.process(delta)

func mostrar_panel(panel_activo: Panel):
	if is_instance_valid(navegacion_ctrl):
		navegacion_ctrl.mostrar_panel(panel_activo)

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
