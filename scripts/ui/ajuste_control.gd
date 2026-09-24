extends Control
class_name AjusteControl

## AjusteControl
## Pantalla modal interactiva para mapear los botones del control/gamepad,
## visualizar el estado del control conectado y restablecer valores predeterminados.

signal cerrado()

var accion_en_espera: String = ""
var modal_escucha: Control = null
var label_estado_control: Label = null
var contenedor_acciones: VBoxContainer = null
var botones_mapeo: Dictionary = {}
var _manager_cache: Node = null

func _obtener_manager() -> Node:
	if is_instance_valid(_manager_cache):
		return _manager_cache
	if is_inside_tree() and get_tree() and get_tree().root:
		_manager_cache = get_tree().root.get_node_or_null("GamepadManager")
	if not is_instance_valid(_manager_cache):
		var GM = load("res://scripts/core/gamepad_manager.gd")
		if GM and GM.has_method("get_instancia"):
			_manager_cache = GM.get_instancia()
	return _manager_cache

func _ready() -> void:
	# Configurar pantalla completa y absorber eventos
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	_construir_interfaz()
	_actualizar_estado_control()
	_poblar_lista_acciones()
	_enfocar_primer_boton()
	
	var mgr = _obtener_manager()
	if is_instance_valid(mgr):
		if not mgr.control_conectado_cambiado.is_connected(_on_control_conectado_cambiado):
			mgr.control_conectado_cambiado.connect(_on_control_conectado_cambiado)
		if not mgr.mapeo_actualizado.is_connected(_on_mapeo_actualizado):
			mgr.mapeo_actualizado.connect(_on_mapeo_actualizado)

func _construir_interfaz() -> void:
	# 1. Fondo oscuro semitransparente
	var fondo = ColorRect.new()
	fondo.name = "FondoModal"
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.02, 0.04, 0.08, 0.94)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fondo)
	
	# 2. Contenedor Centrador Absoluto (Centra perfectamente en cualquier resolución)
	var center_wrap = CenterContainer.new()
	center_wrap.name = "CenterWrapper"
	center_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_wrap)
	
	# 3. Panel Central
	var panel = PanelContainer.new()
	panel.name = "PanelCentral"
	panel.custom_minimum_size = Vector2(580, 520)
	
	var style_panel = StyleBoxFlat.new()
	style_panel.bg_color = Color(0.08, 0.11, 0.16, 0.96)
	style_panel.border_color = Color(0.35, 0.70, 0.95, 0.90)
	style_panel.border_width_left = 2
	style_panel.border_width_top = 2
	style_panel.border_width_right = 2
	style_panel.border_width_bottom = 2
	style_panel.set_corner_radius_all(16)
	style_panel.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	style_panel.shadow_size = 20
	style_panel.content_margin_left = 24
	style_panel.content_margin_right = 24
	style_panel.content_margin_top = 20
	style_panel.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style_panel)
	center_wrap.add_child(panel)
	
	var vbox_principal = VBoxContainer.new()
	vbox_principal.add_theme_constant_override("separation", 12)
	panel.add_child(vbox_principal)
	
	# --- Título ---
	var lbl_titulo = Label.new()
	lbl_titulo.text = "🎮 Configuración de Mando / Control"
	lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_titulo.add_theme_font_size_override("font_size", 22)
	lbl_titulo.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88, 1.0))
	lbl_titulo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl_titulo.add_theme_constant_override("shadow_offset_y", 2)
	vbox_principal.add_child(lbl_titulo)
	
	# --- Estado de Conexión ---
	label_estado_control = Label.new()
	label_estado_control.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_estado_control.add_theme_font_size_override("font_size", 14)
	vbox_principal.add_child(label_estado_control)
	
	# --- Tarjeta de Controles Fijos (Movimiento y Cámara) ---
	var panel_info = PanelContainer.new()
	var style_info = StyleBoxFlat.new()
	style_info.bg_color = Color(0.12, 0.16, 0.24, 0.85)
	style_info.border_color = Color(0.25, 0.45, 0.65, 0.70)
	style_info.border_width_left = 1
	style_info.border_width_top = 1
	style_info.border_width_right = 1
	style_info.border_width_bottom = 1
	style_info.set_corner_radius_all(10)
	style_info.content_margin_left = 12
	style_info.content_margin_right = 12
	style_info.content_margin_top = 8
	style_info.content_margin_bottom = 8
	panel_info.add_theme_stylebox_override("panel", style_info)
	
	var hbox_info = HBoxContainer.new()
	hbox_info.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_info.add_theme_constant_override("separation", 24)
	
	var lbl_mov = Label.new()
	lbl_mov.text = "🕹️ Movimiento: Stick Izq. / D-Pad"
	lbl_mov.add_theme_font_size_override("font_size", 13)
	lbl_mov.add_theme_color_override("font_color", Color(0.75, 0.90, 1.0))
	hbox_info.add_child(lbl_mov)
	
	var lbl_cam = Label.new()
	lbl_cam.text = "👁️ Cámara: Stick Derecho"
	lbl_cam.add_theme_font_size_override("font_size", 13)
	lbl_cam.add_theme_color_override("font_color", Color(0.75, 0.90, 1.0))
	hbox_info.add_child(lbl_cam)
	
	panel_info.add_child(hbox_info)
	vbox_principal.add_child(panel_info)
	
	var sep1 = HSeparator.new()
	vbox_principal.add_child(sep1)
	
	# --- Lista Desplazable de Acciones ---
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 240)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	contenedor_acciones = VBoxContainer.new()
	contenedor_acciones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenedor_acciones.add_theme_constant_override("separation", 8)
	scroll.add_child(contenedor_acciones)
	vbox_principal.add_child(scroll)
	
	var sep2 = HSeparator.new()
	vbox_principal.add_child(sep2)
	
	# --- Botonera Inferior (Restablecer / Cerrar) ---
	var hbox_botones = HBoxContainer.new()
	hbox_botones.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_botones.add_theme_constant_override("separation", 16)
	
	var btn_defaults = Button.new()
	btn_defaults.text = "🔄 Predeterminados"
	btn_defaults.custom_minimum_size = Vector2(170, 38)
	_estilar_boton(btn_defaults, Color(0.18, 0.22, 0.30, 0.95), Color(0.8, 0.6, 0.2, 0.9))
	btn_defaults.pressed.connect(_on_btn_restablecer_pressed)
	hbox_botones.add_child(btn_defaults)
	
	var btn_cerrar = Button.new()
	btn_cerrar.text = "Atrás / Listo"
	btn_cerrar.custom_minimum_size = Vector2(160, 38)
	_estilar_boton(btn_cerrar, Color(0.14, 0.26, 0.42, 0.95), Color(0.4, 0.85, 1.0, 0.9))
	btn_cerrar.pressed.connect(cerrar)
	hbox_botones.add_child(btn_cerrar)
	
	vbox_principal.add_child(hbox_botones)
	
	# --- Modal de Escucha para Reasignar ---
	_crear_modal_escucha()

func _crear_modal_escucha() -> void:
	modal_escucha = Control.new()
	modal_escucha.name = "ModalEscucha"
	modal_escucha.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_escucha.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_escucha.visible = false
	
	var oscurecer = ColorRect.new()
	oscurecer.set_anchors_preset(Control.PRESET_FULL_RECT)
	oscurecer.color = Color(0.0, 0.0, 0.0, 0.75)
	modal_escucha.add_child(oscurecer)
	
	var center_escucha = CenterContainer.new()
	center_escucha.name = "CenterWrapperEscucha"
	center_escucha.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_escucha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_escucha.add_child(center_escucha)
	
	var panel_msg = PanelContainer.new()
	panel_msg.name = "PanelMensaje"
	panel_msg.custom_minimum_size = Vector2(440, 200)
	
	var style_m = StyleBoxFlat.new()
	style_m.bg_color = Color(0.10, 0.14, 0.22, 0.98)
	style_m.border_color = Color(1.0, 0.8, 0.3, 0.95)
	style_m.border_width_left = 3
	style_m.border_width_top = 3
	style_m.border_width_right = 3
	style_m.border_width_bottom = 3
	style_m.set_corner_radius_all(14)
	style_m.shadow_color = Color(0, 0, 0, 0.8)
	style_m.shadow_size = 24
	style_m.content_margin_left = 20
	style_m.content_margin_right = 20
	style_m.content_margin_top = 20
	style_m.content_margin_bottom = 20
	panel_msg.add_theme_stylebox_override("panel", style_m)
	center_escucha.add_child(panel_msg)
	
	var vbox_m = VBoxContainer.new()
	vbox_m.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_m.add_theme_constant_override("separation", 12)
	panel_msg.add_child(vbox_m)
	
	var lbl_tit = Label.new()
	lbl_tit.name = "LabelTituloEscucha"
	lbl_tit.text = "🎯 Asignando Botón"
	lbl_tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_tit.add_theme_font_size_override("font_size", 18)
	lbl_tit.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox_m.add_child(lbl_tit)
	
	var lbl_desc = Label.new()
	lbl_desc.name = "LabelDescEscucha"
	lbl_desc.text = "Presiona cualquier botón o gatillo en tu mando..."
	lbl_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_desc.add_theme_font_size_override("font_size", 14)
	lbl_desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	vbox_m.add_child(lbl_desc)
	
	var btn_cancelar = Button.new()
	btn_cancelar.text = "Cancelar (Escape)"
	btn_cancelar.custom_minimum_size = Vector2(160, 34)
	btn_cancelar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_estilar_boton(btn_cancelar, Color(0.25, 0.12, 0.12, 0.95), Color(0.9, 0.4, 0.4, 0.9))
	btn_cancelar.pressed.connect(_cancelar_escucha)
	vbox_m.add_child(btn_cancelar)
	
	add_child(modal_escucha)

func _actualizar_estado_control() -> void:
	if not is_instance_valid(label_estado_control):
		return
	var mgr = _obtener_manager()
	if not is_instance_valid(mgr):
		label_estado_control.text = "⚪ Estado del control: No disponible"
		label_estado_control.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		return
		
	if mgr.hay_control_conectado():
		var nom = mgr.obtener_nombre_control()
		label_estado_control.text = "🟢 Control Conectado: " + nom
		label_estado_control.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45))
	else:
		label_estado_control.text = "⚪ Ningún control conectado (Conéctalo por Bluetooth o USB)"
		label_estado_control.add_theme_color_override("font_color", Color(0.85, 0.70, 0.35))

func _poblar_lista_acciones() -> void:
	if not is_instance_valid(contenedor_acciones):
		return
	var mgr = _obtener_manager()
	if not is_instance_valid(mgr):
		return
		
	# Limpiar elementos anteriores
	for child in contenedor_acciones.get_children():
		child.queue_free()
	botones_mapeo.clear()
	
	var lista_acciones = mgr.ACCIONES_CONFIGURABLES
	for item in lista_acciones:
		var id_act: String = item["id"]
		var row = PanelContainer.new()
		
		var row_style = StyleBoxFlat.new()
		row_style.bg_color = Color(0.10, 0.14, 0.20, 0.75)
		row_style.border_color = Color(0.20, 0.30, 0.45, 0.5)
		row_style.border_width_left = 1
		row_style.border_width_top = 1
		row_style.border_width_right = 1
		row_style.border_width_bottom = 1
		row_style.set_corner_radius_all(8)
		row_style.content_margin_left = 14
		row_style.content_margin_right = 14
		row_style.content_margin_top = 8
		row_style.content_margin_bottom = 8
		row.add_theme_stylebox_override("panel", row_style)
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		row.add_child(hbox)
		
		# VBox texto (nombre y descripción)
		var vbox_txt = VBoxContainer.new()
		vbox_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox_txt.add_theme_constant_override("separation", 2)
		
		var lbl_nom = Label.new()
		lbl_nom.text = item["nombre"]
		lbl_nom.add_theme_font_size_override("font_size", 15)
		lbl_nom.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
		vbox_txt.add_child(lbl_nom)
		
		var lbl_desc = Label.new()
		lbl_desc.text = item["descripcion"]
		lbl_desc.add_theme_font_size_override("font_size", 11)
		lbl_desc.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
		vbox_txt.add_child(lbl_desc)
		
		hbox.add_child(vbox_txt)
		
		# Botón con el mapeo actual
		var btn_map = Button.new()
		btn_map.custom_minimum_size = Vector2(170, 36)
		btn_map.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_actualizar_texto_boton_mapeo(btn_map, id_act)
		_estilar_boton(btn_map, Color(0.14, 0.20, 0.32, 0.9), Color(0.35, 0.70, 0.95, 0.8))
		
		btn_map.pressed.connect(func():
			_iniciar_escucha(id_act)
		)
		
		botones_mapeo[id_act] = btn_map
		hbox.add_child(btn_map)
		
		contenedor_acciones.add_child(row)

func _actualizar_texto_boton_mapeo(btn: Button, id_act: String) -> void:
	var mgr = _obtener_manager()
	if not is_instance_valid(mgr):
		btn.text = "Sin Asignar"
		return
		
	var cfg = mgr.mapeos_actuales.get(id_act, {})
	var tipo = cfg.get("tipo", "button")
	var idx = cfg.get("indice", 0)
	var nombre_btn = mgr.obtener_texto_boton(tipo, idx)
	btn.text = "[ " + nombre_btn + " ]"

func _iniciar_escucha(id_act: String) -> void:
	var mgr = _obtener_manager()
	if not is_instance_valid(mgr):
		return
	accion_en_espera = id_act
	var item_info: Dictionary = {}
	for it in mgr.ACCIONES_CONFIGURABLES:
		if it["id"] == id_act:
			item_info = it
			break
			
	var nom = item_info.get("nombre", id_act)
	var lbl_tit = modal_escucha.get_node_or_null("PanelCentral/VBoxContainer/LabelTituloEscucha")
	if not is_instance_valid(lbl_tit):
		lbl_tit = modal_escucha.find_child("LabelTituloEscucha", true, false)
	if is_instance_valid(lbl_tit):
		lbl_tit.text = "🎯 Asignando: " + nom
		
	modal_escucha.visible = true

func _enfocar_primer_boton() -> void:
	if botones_mapeo.has("saltar") and is_instance_valid(botones_mapeo["saltar"]):
		botones_mapeo["saltar"].grab_focus()
	elif not botones_mapeo.is_empty():
		var primer_btn = botones_mapeo.values()[0]
		if is_instance_valid(primer_btn):
			primer_btn.grab_focus()

func _cancelar_escucha() -> void:
	var id_act_previa = accion_en_espera
	accion_en_espera = ""
	if is_instance_valid(modal_escucha):
		modal_escucha.visible = false
	if botones_mapeo.has(id_act_previa) and is_instance_valid(botones_mapeo[id_act_previa]):
		botones_mapeo[id_act_previa].grab_focus()

func _input(event: InputEvent) -> void:
	if not modal_escucha or not modal_escucha.visible:
		# Si se presiona ESC, ui_cancel o botón B para cerrar la ventana completa
		if event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B) or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
			cerrar()
			get_viewport().set_input_as_handled()
			return
			
		# Si no hay foco activo y se interactúa con mando/D-Pad, enfocar primer botón
		if get_viewport().gui_get_focus_owner() == null:
			if (event is InputEventJoypadButton and event.is_pressed()) or (event is InputEventJoypadMotion and abs(event.axis_value) > 0.4):
				_enfocar_primer_boton()
		return
		
	# Estamos en modo escucha de botón para 'accion_en_espera'
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancelar_escucha()
		get_viewport().set_input_as_handled()
		return

	# Si se presiona Select/Back en el control -> Cancelar la asignación
	if event is InputEventJoypadButton and event.is_pressed() and event.button_index == JOY_BUTTON_BACK:
		_cancelar_escucha()
		get_viewport().set_input_as_handled()
		return
		
	var mgr = _obtener_manager()
	if not is_instance_valid(mgr):
		_cancelar_escucha()
		return
		
	if event is InputEventJoypadButton and event.is_pressed():
		var btn_idx = event.button_index
		mgr.asignar_mapeo(accion_en_espera, "button", btn_idx)
		_finalizar_escucha()
		get_viewport().set_input_as_handled()
		return
		
	if event is InputEventJoypadMotion and abs(event.axis_value) > 0.6:
		var axis = event.axis
		# Solo permitir gatillos como botones analógicos para acciones
		if axis == JOY_AXIS_TRIGGER_LEFT or axis == JOY_AXIS_TRIGGER_RIGHT:
			mgr.asignar_mapeo(accion_en_espera, "axis", axis)
			_finalizar_escucha()
			get_viewport().set_input_as_handled()
			return

func _finalizar_escucha() -> void:
	var id_act_previa = accion_en_espera
	accion_en_espera = ""
	if is_instance_valid(modal_escucha):
		modal_escucha.visible = false
	_actualizar_todos_los_botones()
	if botones_mapeo.has(id_act_previa) and is_instance_valid(botones_mapeo[id_act_previa]):
		botones_mapeo[id_act_previa].grab_focus()

func _actualizar_todos_los_botones() -> void:
	for id_act in botones_mapeo.keys():
		var btn = botones_mapeo[id_act]
		if is_instance_valid(btn):
			_actualizar_texto_boton_mapeo(btn, id_act)

func _on_control_conectado_cambiado(_conectado: bool, _device_id: int) -> void:
	_actualizar_estado_control()

func _on_mapeo_actualizado() -> void:
	_actualizar_todos_los_botones()

func _on_btn_restablecer_pressed() -> void:
	var mgr = _obtener_manager()
	if is_instance_valid(mgr):
		mgr.restablecer_predeterminados()
		_actualizar_todos_los_botones()

func cerrar() -> void:
	cerrado.emit()
	queue_free()

func _estilar_boton(btn: Button, col_bg: Color, col_border: Color) -> void:
	var style_n = StyleBoxFlat.new()
	style_n.bg_color = col_bg
	style_n.border_color = col_border
	style_n.border_width_left = 1
	style_n.border_width_top = 1
	style_n.border_width_right = 1
	style_n.border_width_bottom = 1
	style_n.set_corner_radius_all(8)
	
	var style_h = style_n.duplicate()
	style_h.bg_color = col_bg.lightened(0.12)
	style_h.border_color = col_border.lightened(0.2)
	
	var style_p = style_n.duplicate()
	style_p.bg_color = col_bg.darkened(0.15)
	
	btn.add_theme_stylebox_override("normal", style_n)
	btn.add_theme_stylebox_override("hover", style_h)
	btn.add_theme_stylebox_override("pressed", style_p)
	btn.add_theme_stylebox_override("focus", style_h)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	btn.add_theme_font_size_override("font_size", 13)
