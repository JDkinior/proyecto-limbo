extends Node
class_name MenuMatchmakingCtrl

var menu: Control
var _firebase_sala_ids: Array = []
var _eos_lobbies: Array = []
var _eos_refresh_timer: Timer

# El bucket se fija en CreateLobbyOptions, antes de cualquier actualización de
# metadatos. Es la fuente de verdad de compatibilidad entre builds.
const EOS_LOBBY_BUCKET_ID := "limbop2pv1"
const LOBBY_OWNER_READY_TIMEOUT_SECONDS := 5.0

func init(p_menu: Control):
	menu = p_menu
	_eos_refresh_timer = Timer.new()
	_eos_refresh_timer.wait_time = 5.0
	_eos_refresh_timer.timeout.connect(_on_eos_refresh_timeout)
	menu.add_child(_eos_refresh_timer)
	
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
	
	# 1. PANEL SELECCIÓN DE MODOS (UN JUGADOR VS MULTIJUGADOR)
	menu.panel_modos = Panel.new()
	menu.panel_modos.name = "PanelModos"
	menu.panel_modos.visible = false
	menu.panel_modos.add_theme_stylebox_override("panel", style_panel)
	menu.add_child(menu.panel_modos)
	
	menu.panel_modos.anchor_left = 0.5
	menu.panel_modos.anchor_right = 0.5
	menu.panel_modos.anchor_top = 0.5
	menu.panel_modos.anchor_bottom = 0.5
	menu.panel_modos.offset_left = -380
	menu.panel_modos.offset_top = -260
	menu.panel_modos.offset_right = 380
	menu.panel_modos.offset_bottom = 260
	menu.panel_modos.custom_minimum_size = Vector2(760, 520)
	menu.panel_modos.size = Vector2(760, 520)
	
	var vbox_modos = VBoxContainer.new()
	vbox_modos.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox_modos.offset_left = 26
	vbox_modos.offset_top = 20
	vbox_modos.offset_right = -26
	vbox_modos.offset_bottom = -20
	vbox_modos.add_theme_constant_override("separation", 12)
	vbox_modos.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.panel_modos.add_child(vbox_modos)
	
	var title_modos = Label.new()
	title_modos.text = "✦ SELECCIONAR MODO DE JUEGO ✦"
	title_modos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_modos.add_theme_font_size_override("font_size", 26)
	vbox_modos.add_child(title_modos)
	
	var subt_modos = Label.new()
	subt_modos.text = "Elige la modalidad para adentrarte en el mundo de Limbo"
	subt_modos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subt_modos.add_theme_color_override("font_color", Color(0.75, 0.8, 0.95))
	subt_modos.add_theme_font_size_override("font_size", 14)
	vbox_modos.add_child(subt_modos)
	
	var sep_modos = HSeparator.new()
	vbox_modos.add_child(sep_modos)
	
	# Contenedor Horizontal con dos tarjetas (Un Jugador & Multijugador)
	var hbox_cards = HBoxContainer.new()
	hbox_cards.add_theme_constant_override("separation", 16)
	hbox_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox_modos.add_child(hbox_cards)
	
	# --- TARJETA 1: UN JUGADOR ---
	var card_solo = PanelContainer.new()
	card_solo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_solo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style_card_solo = StyleBoxFlat.new()
	style_card_solo.bg_color = Color(0.06, 0.09, 0.16, 0.92)
	style_card_solo.border_color = Color(0.25, 0.65, 0.85, 0.8)
	style_card_solo.border_width_left = 2
	style_card_solo.border_width_top = 2
	style_card_solo.border_width_right = 2
	style_card_solo.border_width_bottom = 2
	style_card_solo.set_corner_radius_all(16)
	style_card_solo.content_margin_left = 18
	style_card_solo.content_margin_right = 18
	style_card_solo.content_margin_top = 16
	style_card_solo.content_margin_bottom = 16
	card_solo.add_theme_stylebox_override("panel", style_card_solo)
	hbox_cards.add_child(card_solo)
	
	var vbox_card_solo = VBoxContainer.new()
	vbox_card_solo.add_theme_constant_override("separation", 10)
	vbox_card_solo.alignment = BoxContainer.ALIGNMENT_CENTER
	card_solo.add_child(vbox_card_solo)
	
	var lbl_solo_title = Label.new()
	lbl_solo_title.text = "🎮 UN JUGADOR"
	lbl_solo_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_solo_title.add_theme_font_size_override("font_size", 20)
	lbl_solo_title.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	vbox_card_solo.add_child(lbl_solo_title)
	
	var lbl_solo_tag = Label.new()
	lbl_solo_tag.text = "(Modo Solitario / Pruebas)"
	lbl_solo_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_solo_tag.add_theme_font_size_override("font_size", 12)
	lbl_solo_tag.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 0.85))
	vbox_card_solo.add_child(lbl_solo_tag)
	
	var lbl_solo_desc = Label.new()
	lbl_solo_desc.text = "Limbo está concebido como una experiencia cooperativa para dos personas. Este modo te permite explorar y superar los niveles controlando ambos planos en solitario, aunque la aventura alcanza su mayor esplendor jugando en pareja."
	lbl_solo_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_solo_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_solo_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl_solo_desc.add_theme_font_size_override("font_size", 13)
	lbl_solo_desc.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98))
	vbox_card_solo.add_child(lbl_solo_desc)
	
	menu.btn_modo_solo = Button.new()
	menu.btn_modo_solo.text = "Jugar en Solitario →"
	menu.btn_modo_solo.custom_minimum_size = Vector2(0, 48)
	menu.btn_modo_solo.add_theme_stylebox_override("normal", style_btn_normal)
	menu.btn_modo_solo.add_theme_stylebox_override("hover", style_btn_hover)
	menu.btn_modo_solo.add_theme_stylebox_override("pressed", style_btn_pressed)
	menu.btn_modo_solo.add_theme_font_size_override("font_size", 16)
	menu.btn_modo_solo.pressed.connect(_on_btn_modo_solo_pressed)
	vbox_card_solo.add_child(menu.btn_modo_solo)
	
	# --- TARJETA 2: MULTIJUGADOR ---
	var card_multi = PanelContainer.new()
	card_multi.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_multi.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style_card_multi = StyleBoxFlat.new()
	style_card_multi.bg_color = Color(0.08, 0.08, 0.16, 0.92)
	style_card_multi.border_color = Color(0.95, 0.75, 0.25, 0.8)
	style_card_multi.border_width_left = 2
	style_card_multi.border_width_top = 2
	style_card_multi.border_width_right = 2
	style_card_multi.border_width_bottom = 2
	style_card_multi.set_corner_radius_all(16)
	style_card_multi.content_margin_left = 18
	style_card_multi.content_margin_right = 18
	style_card_multi.content_margin_top = 16
	style_card_multi.content_margin_bottom = 16
	card_multi.add_theme_stylebox_override("panel", style_card_multi)
	hbox_cards.add_child(card_multi)
	
	var vbox_card_multi = VBoxContainer.new()
	vbox_card_multi.add_theme_constant_override("separation", 10)
	vbox_card_multi.alignment = BoxContainer.ALIGNMENT_CENTER
	card_multi.add_child(vbox_card_multi)
	
	var lbl_multi_title = Label.new()
	lbl_multi_title.text = "👥 MULTIJUGADOR"
	lbl_multi_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_multi_title.add_theme_font_size_override("font_size", 20)
	lbl_multi_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	vbox_card_multi.add_child(lbl_multi_title)
	
	var lbl_multi_tag = Label.new()
	lbl_multi_tag.text = "(Cooperativo 2 Jugadores)"
	lbl_multi_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_multi_tag.add_theme_font_size_override("font_size", 12)
	lbl_multi_tag.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6, 0.85))
	vbox_card_multi.add_child(lbl_multi_tag)
	
	var lbl_multi_desc = Label.new()
	lbl_multi_desc.text = "Disfruta la experiencia cooperativa definitiva sincronizando tus habilidades con otro jugador en tiempo real. Conéctate con tu compañero mediante Red Local (LAN) o a través de Internet (Online P2P con salas personalizadas)."
	lbl_multi_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_multi_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_multi_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl_multi_desc.add_theme_font_size_override("font_size", 13)
	lbl_multi_desc.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98))
	vbox_card_multi.add_child(lbl_multi_desc)
	
	menu.btn_modo_online = Button.new()
	menu.btn_modo_online.name = "BtnModoOnline"
	menu.btn_modo_online.text = "Conectar Multijugador →"
	menu.btn_modo_online.custom_minimum_size = Vector2(0, 48)
	menu.btn_modo_online.add_theme_stylebox_override("normal", style_btn_normal)
	menu.btn_modo_online.add_theme_stylebox_override("hover", style_btn_hover)
	menu.btn_modo_online.add_theme_stylebox_override("pressed", style_btn_pressed)
	menu.btn_modo_online.add_theme_font_size_override("font_size", 16)
	menu.btn_modo_online.pressed.connect(_on_btn_modo_online_pressed)
	vbox_card_multi.add_child(menu.btn_modo_online)
	
	# Botón Volver al Menú Principal
	menu.btn_volver_modos = Button.new()
	menu.btn_volver_modos.text = "← Volver al Menú Principal"
	menu.btn_volver_modos.custom_minimum_size = Vector2(0, 44)
	menu.btn_volver_modos.add_theme_stylebox_override("normal", style_btn_normal)
	menu.btn_volver_modos.add_theme_stylebox_override("hover", style_btn_hover)
	menu.btn_volver_modos.add_theme_stylebox_override("pressed", style_btn_pressed)
	menu.btn_volver_modos.add_theme_font_size_override("font_size", 15)
	menu.btn_volver_modos.pressed.connect(_on_btn_volver_modos_pressed)
	vbox_modos.add_child(menu.btn_volver_modos)
	
	# 1.5 PANEL UN JUGADOR (TEST / PRUEBAS)
	menu.panel_un_jugador = Panel.new()
	menu.panel_un_jugador.name = "PanelUnJugador"
	menu.panel_un_jugador.visible = false
	menu.panel_un_jugador.add_theme_stylebox_override("panel", style_panel)
	menu.add_child(menu.panel_un_jugador)
	
	menu.panel_un_jugador.anchor_left = 0.5
	menu.panel_un_jugador.anchor_right = 0.5
	menu.panel_un_jugador.anchor_top = 0.5
	menu.panel_un_jugador.anchor_bottom = 0.5
	menu.panel_un_jugador.offset_left = -320
	menu.panel_un_jugador.offset_top = -240
	menu.panel_un_jugador.offset_right = 320
	menu.panel_un_jugador.offset_bottom = 240
	menu.panel_un_jugador.custom_minimum_size = Vector2(640, 480)
	menu.panel_un_jugador.size = Vector2(640, 480)
	
	var vbox_solo = VBoxContainer.new()
	vbox_solo.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox_solo.offset_left = 28
	vbox_solo.offset_top = 20
	vbox_solo.offset_right = -28
	vbox_solo.offset_bottom = -20
	vbox_solo.add_theme_constant_override("separation", 14)
	vbox_solo.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.panel_un_jugador.add_child(vbox_solo)
	
	var title_solo = Label.new()
	title_solo.text = "🎮 Modo Un Jugador (Solitario)"
	title_solo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_solo.add_theme_font_size_override("font_size", 26)
	vbox_solo.add_child(title_solo)
	
	var subt_solo = Label.new()
	subt_solo.text = "Controla ambos personajes alternando con [Tab], [C] o el botón táctil."
	subt_solo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subt_solo.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	subt_solo.add_theme_font_size_override("font_size", 14)
	vbox_solo.add_child(subt_solo)
	
	var sep_solo = HSeparator.new()
	vbox_solo.add_child(sep_solo)
	
	var lbl_sel_nivel = Label.new()
	lbl_sel_nivel.text = "Seleccionar Nivel:"
	lbl_sel_nivel.add_theme_font_size_override("font_size", 16)
	vbox_solo.add_child(lbl_sel_nivel)
	
	var opt_nivel = OptionButton.new()
	opt_nivel.name = "SelectorNivelSolo"
	opt_nivel.add_item("🌟 Nivel 1: El Despertar Separado", 0)
	opt_nivel.add_item("🌟 Nivel 2", 1)
	opt_nivel.add_item("🧪 Mundo de Pruebas (Sandbox)", 2)
	opt_nivel.custom_minimum_size = Vector2(0, 50)
	opt_nivel.add_theme_stylebox_override("normal", style_input)
	opt_nivel.add_theme_font_size_override("font_size", 15)
	vbox_solo.add_child(opt_nivel)
	
	var lbl_sel_personaje = Label.new()
	lbl_sel_personaje.text = "Personaje Inicial:"
	lbl_sel_personaje.add_theme_font_size_override("font_size", 16)
	vbox_solo.add_child(lbl_sel_personaje)
	
	var opt_personaje = OptionButton.new()
	opt_personaje.name = "SelectorPersonajeSolo"
	opt_personaje.add_item("👤 Jugador Vivo (Plano Físico)", 0)
	opt_personaje.add_item("👻 Fantasma (Plano Espiritual)", 1)
	opt_personaje.custom_minimum_size = Vector2(0, 50)
	opt_personaje.add_theme_stylebox_override("normal", style_input)
	opt_personaje.add_theme_font_size_override("font_size", 15)
	vbox_solo.add_child(opt_personaje)
	
	var btn_jugar_solo = Button.new()
	btn_jugar_solo.text = "▶ Iniciar Nivel Seleccionado"
	btn_jugar_solo.custom_minimum_size = Vector2(0, 52)
	btn_jugar_solo.add_theme_stylebox_override("normal", style_btn_normal)
	btn_jugar_solo.add_theme_stylebox_override("hover", style_btn_hover)
	btn_jugar_solo.add_theme_stylebox_override("pressed", style_btn_pressed)
	btn_jugar_solo.add_theme_font_size_override("font_size", 18)
	btn_jugar_solo.pressed.connect(func():
		var red_mgr = menu.get_tree().root.get_node_or_null("RedManager")
		if is_instance_valid(red_mgr):
			var selected_idx = opt_nivel.get_selected_id()
			var p_inicial = "fantasma" if opt_personaje.get_selected_id() == 1 else "jugador"
			red_mgr.iniciar_un_jugador(selected_idx, p_inicial)
	)
	vbox_solo.add_child(btn_jugar_solo)
	
	var btn_volver_solo = Button.new()
	btn_volver_solo.text = "← Volver a Selección de Modos"
	btn_volver_solo.custom_minimum_size = Vector2(0, 48)
	btn_volver_solo.add_theme_stylebox_override("normal", style_btn_normal)
	btn_volver_solo.add_theme_stylebox_override("hover", style_btn_hover)
	btn_volver_solo.add_theme_stylebox_override("pressed", style_btn_pressed)
	btn_volver_solo.add_theme_font_size_override("font_size", 16)
	btn_volver_solo.pressed.connect(func():
		menu.mostrar_panel(menu.panel_modos)
	)
	vbox_solo.add_child(btn_volver_solo)
	
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
	
	var chk_relay = CheckButton.new()
	chk_relay.text = "Forzar Epic Relay"
	chk_relay.add_theme_font_size_override("font_size", 15)
	chk_relay.button_pressed = false
	chk_relay.toggled.connect(func(toggled_on):
		var EosManager = menu.get_tree().root.get_node_or_null("EosManager")
		if EosManager and EosManager.has_method("set_relay_mode"):
			EosManager.set_relay_mode(2 if toggled_on else 1)
	)
	hbox_extra.add_child(chk_relay)
	
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
	if not is_instance_valid(menu) or not menu.is_inside_tree(): return
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
	_eos_refresh_timer.start()
	_actualizar_lista_salas_eos()
	
	if not is_instance_valid(menu) or not menu.is_inside_tree(): return
	var EosManager = menu.get_tree().root.get_node_or_null("EosManager")
	if is_instance_valid(EosManager):
		# EosManager.buscar_lobbies()
		pass

func _on_btn_volver_modos_pressed():
	menu.mostrar_panel(menu.panel_principal)

func _on_btn_modo_solo_pressed():
	if is_instance_valid(menu.panel_un_jugador):
		menu.mostrar_panel(menu.panel_un_jugador)

func _on_btn_host_pressed():
	if not is_instance_valid(menu) or not menu.is_inside_tree(): return
	var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
	if is_instance_valid(RedManager):
		await RedManager.crear_partida(true)

func _on_btn_conectar_pressed():
	if not is_instance_valid(menu) or not menu.is_inside_tree(): return
	var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
	if is_instance_valid(RedManager):
		var target_ip = menu.ip_input.text.strip_edges()
		if target_ip.is_empty():
			target_ip = "127.0.0.1"
		if await RedManager.unirse_a_partida(target_ip, true):
			menu.lobby_status_label.text = "Conectando a " + target_ip + "..."
			menu.mostrar_panel(menu.panel_lobby)

func _on_quick_join_option_item_selected(index):
	if index > 0:
		var nombre_amigo = menu.quick_join_option.get_item_text(index)
		var ip_amigo = menu.amigos_dict.get(nombre_amigo, "127.0.0.1")
		menu.ip_input.text = ip_amigo

func _on_btn_volver_jugar_pressed():
	if not is_instance_valid(menu) or not menu.is_inside_tree(): return
	var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
	if is_instance_valid(RedManager):
		RedManager.detener_lan_listener()
	menu.mostrar_panel(menu.panel_modos)

func _on_lan_server_found(_ip, _port, _name):
	_actualizar_servidores_lan()

func _actualizar_servidores_lan():
	if not is_instance_valid(menu) or not menu.is_inside_tree(): return
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

func _on_eos_salas_actualizadas(salas: Array):
	if menu.panel_salas.visible:
		_actualizar_lista_salas_eos()

func _on_eos_refresh_timeout():
	if menu.panel_salas.visible:
		_actualizar_lista_salas_eos(true)

func _actualizar_lista_salas_eos(es_auto_refresh = false):
	if not menu.panel_salas.visible: return
	
	if not es_auto_refresh:
		menu.lista_salas.clear()
		menu.lista_salas.add_item("Buscando salas...")
	
	if not is_instance_valid(menu) or not menu.is_inside_tree(): return
	var EosManager = menu.get_tree().root.get_node_or_null("EosManager")
	var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
	if not is_instance_valid(EosManager) or not EosManager.has_method("esperar_login_async"):
		menu.lista_salas.clear()
		menu.lista_salas.add_item("EOS no está disponible en esta compilación.")
		return
	if not EosManager.is_logged_in:
		if not es_auto_refresh:
			menu.lista_salas.clear()
			menu.lista_salas.add_item("Iniciando sesión en EOS...")
		if not (await EosManager.esperar_login_async()):
			if not es_auto_refresh:
				menu.lista_salas.clear()
				menu.lista_salas.add_item("Error de inicio de sesión.")
			return
	
	var HLobbies_node = menu.get_tree().root.get_node_or_null("HLobbies")
	if is_instance_valid(HLobbies_node) and HLobbies_node.has_method("search_by_bucket_id_async") and is_instance_valid(RedManager):
		# join_async usa esta opción global; no requerimos el permiso de Presence para
		# lobbies públicos consultados por atributos.
		HLobbies_node.presence_enabled = false
		# El bucket identifica protocolo/build y está disponible desde la creación;
		# no dependemos de atributos que EOS recibe en una actualización posterior.
		var lobbies = await HLobbies_node.search_by_bucket_id_async(EOS_LOBBY_BUCKET_ID)
		if not menu.panel_salas.visible: return
		
		menu.lista_salas.clear()
		_firebase_sala_ids.clear()
		_eos_lobbies.clear()
		
		if lobbies != null and typeof(lobbies) == TYPE_ARRAY:
			print("[Matchmaking] EOS devolvió ", lobbies.size(), " lobby(s) del bucket ", EOS_LOBBY_BUCKET_ID, ".")
			for lobby in lobbies:
				if lobby.available_slots <= 0:
					continue
				# El bucket ya validó la versión. Los atributos son metadatos de UI y pueden
				# llegar unos instantes después de crear el lobby.
				var protocol = _valor_atributo_lobby(lobby, "protocol")
				if not protocol.is_empty() and protocol != RedManager.EOS_P2P_SOCKET_ID:
					print("[Matchmaking] Advertencia: protocolo de metadata inesperado: ", protocol)
				var room_name = _valor_atributo_lobby(lobby, "room_name")
				if room_name.is_empty():
					room_name = "Sala de Juego"
				menu.lista_salas.add_item("%s  ·  %d/2" % [room_name, lobby.max_members - lobby.available_slots])
				_firebase_sala_ids.append(str(lobby.owner_product_user_id))
				_eos_lobbies.append(lobby)
	
	if menu.lista_salas.item_count == 0:
		menu.lista_salas.add_item("No hay salas activas. ¡Crea una!")


func _valor_atributo_lobby(lobby, key: String) -> String:
	if lobby == null or not is_instance_valid(lobby):
		return ""
	var attribute = lobby.get_attribute(key)
	if typeof(attribute) == TYPE_DICTIONARY:
		return str(attribute.get("value", ""))
	return str(attribute)


func _esperar_lobby_con_propietario_async(lobby, local_product_user_id: String) -> bool:
	var deadline := Time.get_ticks_msec() + int(LOBBY_OWNER_READY_TIMEOUT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if str(lobby.owner_product_user_id) == local_product_user_id:
			return true
		await menu.get_tree().create_timer(0.1).timeout
	print("[Matchmaking ERROR] Lobby creado sin propietario disponible. Local: ", local_product_user_id.left(8), "… | owner: ", str(lobby.owner_product_user_id).left(8), "…")
	return false

func _on_btn_crear_sala_pressed():
	var nombre = menu.sala_nombre_input.text.strip_edges()
	if nombre.is_empty():
		return
	
	if not is_instance_valid(menu) or not menu.is_inside_tree(): return
	var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
	if not is_instance_valid(menu) or not menu.is_inside_tree(): return
	var EosManager = menu.get_tree().root.get_node_or_null("EosManager")
	if not is_instance_valid(RedManager):
		return
	
	menu.btn_crear_sala.disabled = true
	menu.btn_crear_sala.text = "Creando..."

	if not is_instance_valid(EosManager) or not (await EosManager.esperar_login_async()):
		menu.btn_crear_sala.disabled = false
		menu.btn_crear_sala.text = "Crear"
		menu.lista_salas.clear()
		menu.lista_salas.add_item("No se pudo iniciar sesión en EOS.")
		return

	if not (await RedManager.crear_partida(false)):
		menu.btn_crear_sala.disabled = false
		menu.btn_crear_sala.text = "Crear"
		return
	
	var HLobbies_node = menu.get_tree().root.get_node_or_null("HLobbies")
	var lobby = null
	if is_instance_valid(HLobbies_node) and HLobbies_node.has_method("create_lobby_async"):
		# Presence no es necesaria para buscar salas públicas y esta Client Policy no
		# la tiene habilitada; al desactivarla evitamos crear un lobby parcialmente anunciado.
		HLobbies_node.presence_enabled = false
		var create_opts = EOS.Lobby.CreateLobbyOptions.new()
		create_opts.max_lobby_members = 2
		create_opts.permission_level = EOS.Lobby.LobbyPermissionLevel.PublicAdvertised
		create_opts.presence_enabled = false
		create_opts.bucket_id = EOS_LOBBY_BUCKET_ID
		lobby = await HLobbies_node.create_lobby_async(create_opts)

	if lobby == null or not is_instance_valid(lobby):
		await RedManager.desconectar(false)
		menu.btn_crear_sala.disabled = false
		menu.btn_crear_sala.text = "Crear"
		menu.lista_salas.clear()
		menu.lista_salas.add_item("No se pudo crear la sala de EOS.")
		return

	EosManager.current_lobby = lobby
	# EOS puede entregar el callback de creación antes de que el owner esté copiado
	# en HLobby. Si se llama update_async() en ese instante, EOSG lo trata como
	# actualización de miembro y descarta los atributos de la sala.
	if not (await _esperar_lobby_con_propietario_async(lobby, EosManager.local_product_user_id)):
		await RedManager.desconectar(true)
		menu.btn_crear_sala.disabled = false
		menu.btn_crear_sala.text = "Crear"
		menu.lista_salas.clear()
		menu.lista_salas.add_item("EOS no confirmó el propietario de la sala. Intenta de nuevo.")
		return
	# El atributo de protocolo evita unir clientes con una versión incompatible. El
	# socket no se usa como secreto: la validación P2P real se hace por membresía.
	var protocol_added: bool = lobby.add_attribute("protocol", RedManager.get_eos_p2p_socket_id(), EOS.Lobby.LobbyAttributeVisibility.Public)
	var name_added: bool = lobby.add_attribute("room_name", nombre.left(40), EOS.Lobby.LobbyAttributeVisibility.Public)
	var build_added: bool = lobby.add_attribute("build", "1", EOS.Lobby.LobbyAttributeVisibility.Public)
	if not protocol_added or not name_added or not build_added:
		print("[Matchmaking ERROR] No se pudieron preparar los atributos del lobby.")
		await RedManager.desconectar(true)
		menu.btn_crear_sala.disabled = false
		menu.btn_crear_sala.text = "Crear"
		return
	if not (await lobby.update_async()):
		await RedManager.desconectar(true)
		menu.btn_crear_sala.disabled = false
		menu.btn_crear_sala.text = "Crear"
		menu.lista_salas.clear()
		menu.lista_salas.add_item("No se pudo publicar la sala de EOS.")
		return
	print("[Matchmaking] Sala publicada. owner=", EosManager.local_product_user_id.left(8), "… | protocol=", _valor_atributo_lobby(lobby, "protocol"))
	
	menu.btn_crear_sala.disabled = false
	menu.btn_crear_sala.text = "Crear"
	
	menu.sala_nombre_input.clear()
	menu.mostrar_panel(menu.panel_lobby)
	if menu.lobby_ctrl != null:
		menu.lobby_ctrl._actualizar_ui_lobby()
		menu.lobby_ctrl._actualizar_lobby_3d()
	menu.lobby_status_label.text = "Sala creada. Esperando al otro jugador..."

func _on_btn_unirse_sala_pressed():
	var items = menu.lista_salas.get_selected_items()
	if items.size() > 0:
		var index = items[0]
		if index >= 0 and index < _firebase_sala_ids.size():
			var host_puid = _firebase_sala_ids[index]
			if not is_instance_valid(menu) or not menu.is_inside_tree(): return
			var EosManager = menu.get_tree().root.get_node_or_null("EosManager")
			var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
			if is_instance_valid(RedManager):
				var HLobbies_node = menu.get_tree().root.get_node_or_null("HLobbies")
				if is_instance_valid(HLobbies_node) and _eos_lobbies.size() > index:
					menu.lobby_status_label.text = "Uniéndose al lobby de EOS..."
					var lobby = await HLobbies_node.join_async(_eos_lobbies[index])
					if lobby == null or not is_instance_valid(lobby):
						menu.lista_salas.clear()
						menu.lista_salas.add_item("No se pudo entrar a la sala; actualiza la lista.")
						return
					if is_instance_valid(EosManager):
						EosManager.current_lobby = lobby
				else:
					return

				# Da tiempo al host para recibir la actualización de miembros antes de
				# enviar la solicitud P2P, que el host valida contra el lobby.
				await menu.get_tree().create_timer(0.35).timeout
				if not (await RedManager.unirse_a_partida(host_puid, false)):
					await RedManager.desconectar(true)
					return
				menu.mostrar_panel(menu.panel_lobby)
				menu.lobby_status_label.text = "Conectando al host P2P..."
				menu.btn_jugador.disabled = true
				menu.btn_fantasma.disabled = true
				menu.btn_listo.disabled = true
				menu.host_controls_container.visible = false
				menu.client_status_container.visible = false
				menu.autoconectando = true

func _on_btn_refrescar_salas_pressed():
	menu.lista_salas.clear()
	menu.lista_salas.add_item("Buscando salas...")
	await _actualizar_lista_salas_eos()

func _on_btn_volver_salas_pressed():
	if not is_instance_valid(menu) or not menu.is_inside_tree(): return
	var EosManager = menu.get_tree().root.get_node_or_null("EosManager")
	_eos_refresh_timer.stop()
	if not is_instance_valid(menu) or not menu.is_inside_tree(): return
	var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
	if is_instance_valid(RedManager):
		RedManager.desconectar()
	
	menu.btn_crear_sala.disabled = false
	menu.btn_crear_sala.text = "Crear"
		
	menu.mostrar_panel(menu.panel_modos)
