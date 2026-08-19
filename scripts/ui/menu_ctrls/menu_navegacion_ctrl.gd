extends Node
class_name MenuNavegacionCtrl

var menu: Control

func init(p_menu: Control):
	menu = p_menu
	_conectar_senales()
	estilar_interfaz_general(menu)
	_inicializar_boton_reconectar()

func _conectar_senales():
	menu.get_node("PanelPrincipal/VBoxContainer/BtnJugar").pressed.connect(_on_btn_jugar_pressed)
	menu.get_node("PanelPrincipal/VBoxContainer/BtnAmigos").pressed.connect(_on_btn_amigos_menu_pressed)
	menu.get_node("PanelPrincipal/VBoxContainer/BtnOpciones").pressed.connect(_on_btn_opciones_pressed)
	menu.get_node("PanelPrincipal/VBoxContainer/BtnSalir").pressed.connect(_on_btn_salir_pressed)

func estilar_interfaz_general(nodo: Node):
	if nodo is Label:
		if not nodo.has_theme_color_override(&"font_color"):
			nodo.add_theme_color_override(&"font_color", Color(0.96, 0.97, 1.0, 1.0))
		nodo.add_theme_color_override(&"font_outline_color", Color(0.02, 0.02, 0.08, 0.9))
		nodo.add_theme_constant_override(&"outline_size", 6)
		nodo.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.4))
		nodo.add_theme_constant_override(&"shadow_offset_x", 1)
		nodo.add_theme_constant_override(&"shadow_offset_y", 2)
		
	elif nodo is Button:
		var es_boton_principal = (nodo.name == "BtnJugar" or nodo.name == "BtnJugador" or nodo.name == "BtnModoOnline")
		
		nodo.add_theme_color_override(&"font_color", Color(1.0, 0.98, 0.9, 1.0) if es_boton_principal else Color(0.9, 0.95, 1.0, 1.0))
		nodo.add_theme_color_override(&"font_pressed_color", Color(0.8, 0.95, 1.0, 1.0))
		nodo.add_theme_color_override(&"font_hover_color", Color(1.0, 0.9, 0.5, 1.0) if es_boton_principal else Color(0.3, 0.9, 1.0, 1.0))
		nodo.add_theme_color_override(&"font_outline_color", Color(0.02, 0.02, 0.08, 0.95))
		nodo.add_theme_constant_override(&"outline_size", 6)
		
		if nodo.custom_minimum_size.y < 52:
			nodo.custom_minimum_size.y = 54
			
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.08, 0.11, 0.20, 0.88)
		style_normal.set_corner_radius_all(20)
		style_normal.content_margin_left = 20
		style_normal.content_margin_right = 20
		style_normal.content_margin_top = 10
		style_normal.content_margin_bottom = 10
		
		if es_boton_principal:
			style_normal.border_width_left = 2
			style_normal.border_width_top = 2
			style_normal.border_width_right = 2
			style_normal.border_width_bottom = 2
			style_normal.border_color = Color(0.98, 0.78, 0.25, 1.0) # Dorado brillante
			style_normal.shadow_size = 0
		else:
			style_normal.border_width_left = 2
			style_normal.border_width_top = 2
			style_normal.border_width_right = 2
			style_normal.border_width_bottom = 2
			style_normal.border_color = Color(0.2, 0.55, 0.85, 0.85) # Azul místico
			style_normal.shadow_size = 0
		
		var style_hover = style_normal.duplicate()
		if es_boton_principal:
			style_hover.bg_color = Color(0.16, 0.18, 0.30, 0.95)
			style_hover.border_color = Color(1.0, 0.88, 0.4, 1.0)
			style_hover.shadow_size = 0
		else:
			style_hover.bg_color = Color(0.14, 0.18, 0.32, 0.95)
			style_hover.border_color = Color(0.3, 0.75, 1.0, 1.0)
			style_hover.shadow_size = 0
		
		var style_pressed = style_normal.duplicate()
		style_pressed.bg_color = Color(0.06, 0.08, 0.15, 0.98)
		style_pressed.shadow_size = 0
		
		var style_disabled = style_normal.duplicate()
		style_disabled.bg_color = Color(0.08, 0.09, 0.14, 0.5)
		style_disabled.border_color = Color(0.15, 0.18, 0.25, 0.3)
		style_disabled.shadow_size = 0
		
		nodo.add_theme_stylebox_override(&"normal", style_normal)
		nodo.add_theme_stylebox_override(&"hover", style_hover)
		nodo.add_theme_stylebox_override(&"pressed", style_pressed)
		nodo.add_theme_stylebox_override(&"focus", style_hover)
		nodo.add_theme_stylebox_override(&"disabled", style_disabled)

	elif nodo is LineEdit:
		if nodo.custom_minimum_size.y < 50:
			nodo.custom_minimum_size.y = 52
		var style_input = StyleBoxFlat.new()
		style_input.bg_color = Color(0.06, 0.08, 0.14, 0.95)
		style_input.border_width_left = 2
		style_input.border_width_top = 2
		style_input.border_width_right = 2
		style_input.border_width_bottom = 2
		style_input.border_color = Color(0.2, 0.4, 0.7, 0.8)
		style_input.set_corner_radius_all(14)
		style_input.content_margin_left = 14
		style_input.content_margin_right = 14
		nodo.add_theme_stylebox_override(&"normal", style_input)
		nodo.add_theme_stylebox_override(&"focus", style_input)
		nodo.add_theme_font_size_override(&"font_size", 16)

	elif nodo is Panel or nodo is PanelContainer:
		if nodo.name == "Background":
			var style_bg = StyleBoxFlat.new()
			style_bg.bg_color = Color(0.05, 0.05, 0.10, 1.0)
			nodo.add_theme_stylebox_override(&"panel", style_bg)
		elif nodo.name == "PanelPrincipal":
			var style_empty = StyleBoxEmpty.new()
			nodo.add_theme_stylebox_override(&"panel", style_empty)
		else:
			var style_panel = StyleBoxFlat.new()
			style_panel.bg_color = Color(0.07, 0.09, 0.17, 0.93)
			style_panel.border_width_left = 2
			style_panel.border_width_top = 2
			style_panel.border_width_right = 2
			style_panel.border_width_bottom = 2
			style_panel.border_color = Color(0.2, 0.4, 0.75, 0.6)
			style_panel.set_corner_radius_all(20)
			style_panel.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
			style_panel.shadow_size = 14
			style_panel.shadow_offset = Vector2(0, 4)
			nodo.add_theme_stylebox_override(&"panel", style_panel)

	for hijo in nodo.get_children():
		estilar_interfaz_general(hijo)

func mostrar_panel(panel_activo: Panel):
	menu.panel_principal.visible = (panel_activo == menu.panel_principal)
	if menu.has_node("HeaderContainer"):
		menu.get_node("HeaderContainer").visible = (panel_activo == menu.panel_principal)
	menu.panel_jugar.visible = (panel_activo == menu.panel_jugar)
	menu.panel_lobby.visible = (panel_activo == menu.panel_lobby)
	menu.panel_amigos.visible = (panel_activo == menu.panel_amigos)
	menu.panel_opciones.visible = (panel_activo == menu.panel_opciones)
	
	if is_instance_valid(menu.panel_modos):
		menu.panel_modos.visible = (panel_activo == menu.panel_modos)
	if is_instance_valid(menu.panel_salas):
		menu.panel_salas.visible = (panel_activo == menu.panel_salas)
	if is_instance_valid(menu.panel_un_jugador):
		menu.panel_un_jugador.visible = (panel_activo == menu.panel_un_jugador)
		
	if panel_activo == menu.panel_un_jugador:
		if is_instance_valid(menu.matchmaking_ctrl) and menu.matchmaking_ctrl.has_method("_actualizar_seleccion_visual_un_jugador"):
			menu.matchmaking_ctrl._actualizar_seleccion_visual_un_jugador()
	else:
		if menu.has_method("cambiar_color_ambiente"):
			menu.cambiar_color_ambiente(Color(0, 0, 0, 0), 0.35)

func _inicializar_boton_reconectar():
	var red_mgr = menu.get_node_or_null("/root/RedManager")
	if is_instance_valid(red_mgr) and red_mgr.puede_reconectarse:
		if not is_instance_valid(menu.btn_reconectar):
			menu.btn_reconectar = Button.new()
			menu.btn_reconectar.name = "BtnReconectar"
			var rol = " (Jugador Vivo)" if red_mgr.ultimo_personaje == "jugador" else (" (Fantasma)" if red_mgr.ultimo_personaje == "fantasma" else "")
			menu.btn_reconectar.text = "🔄 Reconectarse a Partida" + rol
			menu.btn_reconectar.custom_minimum_size = Vector2(0, 48)
			menu.btn_reconectar.add_theme_color_override("font_color", Color(0.3, 0.95, 0.5))
			menu.btn_reconectar.add_theme_font_size_override("font_size", 16)
			menu.btn_reconectar.pressed.connect(_on_btn_reconectar_pressed)
			var vbox = menu.panel_principal.get_node_or_null("VBoxContainer")
			if vbox:
				vbox.add_child(menu.btn_reconectar)
				vbox.move_child(menu.btn_reconectar, 3)
			estilar_interfaz_general(menu.btn_reconectar)

func _on_btn_reconectar_pressed():
	print("[MenuInicio] Botón Reconectarse presionado. Iniciando reconexión...")
	var red_mgr = menu.get_node_or_null("/root/RedManager")
	if is_instance_valid(red_mgr):
		red_mgr.reconectar_a_partida()

func _on_btn_jugar_pressed():
	if is_instance_valid(menu.panel_modos):
		mostrar_panel(menu.panel_modos)
	elif menu.matchmaking_ctrl != null:
		menu.matchmaking_ctrl._on_btn_modo_online_pressed()

func _on_btn_amigos_menu_pressed():
	mostrar_panel(menu.panel_amigos)
	if menu.amigos_opciones_ctrl != null:
		menu.amigos_opciones_ctrl._actualizar_lista_amigos()

func _on_btn_opciones_pressed():
	mostrar_panel(menu.panel_opciones)

func _on_btn_salir_pressed():
	menu.get_tree().quit()
