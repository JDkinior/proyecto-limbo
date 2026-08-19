extends Control
class_name AjusteHud

signal guardado(nueva_config: Dictionary)
signal cerrado()

# Nodos y variables de estado
var config_actual: Dictionary = {}
var elemento_seleccionado: String = "botones_accion"
var modo_movimiento_individual: bool = false

# Variables de arrastre
var arrastrando: bool = false
var id_toque_arrastre: int = -1
var elemento_en_arrastre: String = ""

# Elementos visuales interactivos
var nodo_joystick: Control
var nodo_grupo_botones: Control
var nodo_btn_saltar: Control
var nodo_btn_interactuar: Control
var nodo_btn_cambiar: Control
var nodo_btn_pausa: Control

# Controles de interfaz superior
var label_seleccionado: Label
var slider_tamano: HSlider
var label_tamano_valor: Label
var btn_modo_movimiento: Button
var toast_guardado: Label
var tween_toast: Tween

func _ready():
	# Bloquear propagación de eventos al juego
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	config_actual = HudConfigManager.cargar_config()
	
	_construir_interfaz()
	_actualizar_posiciones_y_escalas()
	_seleccionar_elemento("botones_accion")

func _unhandled_input(_event: InputEvent) -> void:
	# Consumir cualquier input que llegue para no mover al personaje
	accept_event()

func _construir_interfaz():
	# 1. Fondo oscuro con cuadrícula de edición
	var bg = ColorRect.new()
	bg.name = "FondoEditor"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.06, 0.10, 0.94)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	
	# 2. Contenedor de Elementos HUD Interactivos (renderizado antes de la barra superior para que la barra quede al frente)
	_crear_elementos_hud_interactivos()
	
	# 3. BARRA SUPERIOR UNIFICADA (Todas las herramientas arriba para dejar libre la zona inferior)
	var panel_sup = PanelContainer.new()
	panel_sup.name = "PanelHerramientasSuperior"
	panel_sup.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel_sup.offset_top = 8
	panel_sup.offset_left = 16
	panel_sup.offset_right = -16
	panel_sup.offset_bottom = 84
	panel_sup.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var style_panel_sup = StyleBoxFlat.new()
	style_panel_sup.bg_color = Color(0.07, 0.10, 0.16, 0.96)
	style_panel_sup.border_color = Color(0.3, 0.65, 0.95, 0.7)
	style_panel_sup.border_width_left = 1
	style_panel_sup.border_width_top = 1
	style_panel_sup.border_width_right = 1
	style_panel_sup.border_width_bottom = 2
	style_panel_sup.set_corner_radius_all(12)
	style_panel_sup.shadow_color = Color(0, 0, 0, 0.4)
	style_panel_sup.shadow_size = 8
	panel_sup.add_theme_stylebox_override("panel", style_panel_sup)
	
	var vbox_sup = VBoxContainer.new()
	vbox_sup.add_theme_constant_override("separation", 6)
	vbox_sup.offset_left = 12
	vbox_sup.offset_right = -12
	vbox_sup.offset_top = 6
	vbox_sup.offset_bottom = -6
	
	# --- Fila 1: Título, Elemento Seleccionado y Botones de Acción ---
	var hbox_fila1 = HBoxContainer.new()
	hbox_fila1.add_theme_constant_override("separation", 10)
	hbox_fila1.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var lbl_titulo = Label.new()
	lbl_titulo.text = "📐 PERSONALIZAR HUD"
	lbl_titulo.add_theme_font_size_override("font_size", 14)
	lbl_titulo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	hbox_fila1.add_child(lbl_titulo)
	
	var v_sep1 = VSeparator.new()
	hbox_fila1.add_child(v_sep1)
	
	label_seleccionado = Label.new()
	label_seleccionado.text = "Seleccionado: Botones de Acción"
	label_seleccionado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_seleccionado.add_theme_font_size_override("font_size", 13)
	label_seleccionado.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	hbox_fila1.add_child(label_seleccionado)
	
	# Botón Alternar Modo Grupo/Individual
	btn_modo_movimiento = Button.new()
	btn_modo_movimiento.text = "Mover: Grupo"
	btn_modo_movimiento.custom_minimum_size = Vector2(125, 32)
	btn_modo_movimiento.add_theme_font_size_override("font_size", 12)
	btn_modo_movimiento.pressed.connect(_on_toggle_modo_movimiento)
	_estilar_boton(btn_modo_movimiento, Color(0.2, 0.4, 0.6))
	hbox_fila1.add_child(btn_modo_movimiento)
	
	# Botón Restablecer
	var btn_restablecer = Button.new()
	btn_restablecer.text = "↺ Restablecer"
	btn_restablecer.custom_minimum_size = Vector2(105, 32)
	btn_restablecer.add_theme_font_size_override("font_size", 12)
	btn_restablecer.pressed.connect(_on_restablecer_pressed)
	_estilar_boton(btn_restablecer, Color(0.5, 0.28, 0.28))
	hbox_fila1.add_child(btn_restablecer)
	
	# Botón Cancelar
	var btn_cancelar = Button.new()
	btn_cancelar.text = "✕ Cancelar"
	btn_cancelar.custom_minimum_size = Vector2(90, 32)
	btn_cancelar.add_theme_font_size_override("font_size", 12)
	btn_cancelar.pressed.connect(_on_cancelar_pressed)
	_estilar_boton(btn_cancelar, Color(0.3, 0.3, 0.35))
	hbox_fila1.add_child(btn_cancelar)
	
	# Botón Guardar
	var btn_guardar = Button.new()
	btn_guardar.text = "💾 Guardar"
	btn_guardar.custom_minimum_size = Vector2(105, 32)
	btn_guardar.add_theme_font_size_override("font_size", 12)
	btn_guardar.pressed.connect(_on_guardar_pressed)
	_estilar_boton(btn_guardar, Color(0.18, 0.55, 0.28))
	hbox_fila1.add_child(btn_guardar)
	
	vbox_sup.add_child(hbox_fila1)
	
	# --- Fila 2: Deslizador de Tamaño y Ajuste Fino ---
	var hbox_fila2 = HBoxContainer.new()
	hbox_fila2.add_theme_constant_override("separation", 8)
	hbox_fila2.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var lbl_tam = Label.new()
	lbl_tam.text = "Tamaño del Elemento:"
	lbl_tam.add_theme_font_size_override("font_size", 12)
	lbl_tam.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	hbox_fila2.add_child(lbl_tam)
	
	var btn_tam_minus = Button.new()
	btn_tam_minus.text = " - "
	btn_tam_minus.custom_minimum_size = Vector2(28, 24)
	btn_tam_minus.pressed.connect(func(): if slider_tamano: slider_tamano.value -= 0.05)
	_estilar_boton(btn_tam_minus, Color(0.2, 0.25, 0.35))
	hbox_fila2.add_child(btn_tam_minus)
	
	slider_tamano = HSlider.new()
	slider_tamano.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_tamano.min_value = 0.5
	slider_tamano.max_value = 2.2
	slider_tamano.step = 0.05
	slider_tamano.value = 1.0
	slider_tamano.value_changed.connect(_on_slider_tamano_changed)
	hbox_fila2.add_child(slider_tamano)
	
	var btn_tam_plus = Button.new()
	btn_tam_plus.text = " + "
	btn_tam_plus.custom_minimum_size = Vector2(28, 24)
	btn_tam_plus.pressed.connect(func(): if slider_tamano: slider_tamano.value += 0.05)
	_estilar_boton(btn_tam_plus, Color(0.2, 0.25, 0.35))
	hbox_fila2.add_child(btn_tam_plus)
	
	label_tamano_valor = Label.new()
	label_tamano_valor.text = "100%"
	label_tamano_valor.custom_minimum_size = Vector2(45, 0)
	label_tamano_valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label_tamano_valor.add_theme_font_size_override("font_size", 12)
	label_tamano_valor.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	hbox_fila2.add_child(label_tamano_valor)
	
	vbox_sup.add_child(hbox_fila2)
	panel_sup.add_child(vbox_sup)
	add_child(panel_sup)
	
	# 4. Toast de Confirmación
	toast_guardado = Label.new()
	toast_guardado.text = "✅ ¡Configuración del HUD Guardada con Éxito!"
	toast_guardado.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_guardado.offset_top = 95
	toast_guardado.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_guardado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_guardado.add_theme_font_size_override("font_size", 15)
	toast_guardado.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	toast_guardado.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	toast_guardado.add_theme_constant_override("outline_size", 6)
	toast_guardado.modulate.a = 0.0
	add_child(toast_guardado)

func _crear_elementos_hud_interactivos():
	# 1. Joystick
	nodo_joystick = Control.new()
	nodo_joystick.name = "Preview_Joystick"
	nodo_joystick.custom_minimum_size = Vector2(180, 180)
	nodo_joystick.size = Vector2(180, 180)
	nodo_joystick.pivot_offset = Vector2(90, 90)
	nodo_joystick.gui_input.connect(func(ev): _manejar_input_elemento("joystick", ev, nodo_joystick))
	_crear_dibujo_joystick(nodo_joystick)
	add_child(nodo_joystick)
	
	# 2. Grupo de Botones de Acción
	nodo_grupo_botones = Control.new()
	nodo_grupo_botones.name = "Preview_Zona_Botones"
	nodo_grupo_botones.custom_minimum_size = Vector2(160, 160)
	nodo_grupo_botones.size = Vector2(160, 160)
	nodo_grupo_botones.pivot_offset = Vector2(80, 80)
	nodo_grupo_botones.gui_input.connect(func(ev): 
		if not modo_movimiento_individual:
			_manejar_input_elemento("botones_accion", ev, nodo_grupo_botones)
	)
	_crear_marco_seleccion(nodo_grupo_botones)
	add_child(nodo_grupo_botones)
	
	# Botón Saltar (sin etiquetas exteriores que se corten)
	nodo_btn_saltar = Control.new()
	nodo_btn_saltar.name = "Preview_Btn_Saltar"
	nodo_btn_saltar.custom_minimum_size = Vector2(76, 76)
	nodo_btn_saltar.size = Vector2(76, 76)
	nodo_btn_saltar.pivot_offset = Vector2(38, 38)
	nodo_btn_saltar.gui_input.connect(func(ev): _manejar_input_boton_accion("btn_saltar", ev, nodo_btn_saltar))
	_crear_dibujo_boton_accion(nodo_btn_saltar, Color(1.0, 0.82, 0.25), "▲")
	nodo_grupo_botones.add_child(nodo_btn_saltar)
	
	# Botón Interactuar
	nodo_btn_interactuar = Control.new()
	nodo_btn_interactuar.name = "Preview_Btn_Interactuar"
	nodo_btn_interactuar.custom_minimum_size = Vector2(76, 76)
	nodo_btn_interactuar.size = Vector2(76, 76)
	nodo_btn_interactuar.pivot_offset = Vector2(38, 38)
	nodo_btn_interactuar.gui_input.connect(func(ev): _manejar_input_boton_accion("btn_interactuar", ev, nodo_btn_interactuar))
	_crear_dibujo_boton_accion(nodo_btn_interactuar, Color(0.35, 0.85, 1.0), "◆")
	nodo_grupo_botones.add_child(nodo_btn_interactuar)
	
	# Botón Cambiar Personaje
	nodo_btn_cambiar = Control.new()
	nodo_btn_cambiar.name = "Preview_Btn_Cambiar"
	nodo_btn_cambiar.custom_minimum_size = Vector2(76, 76)
	nodo_btn_cambiar.size = Vector2(76, 76)
	nodo_btn_cambiar.pivot_offset = Vector2(38, 38)
	nodo_btn_cambiar.gui_input.connect(func(ev): _manejar_input_boton_accion("btn_cambiar", ev, nodo_btn_cambiar))
	_crear_dibujo_boton_accion(nodo_btn_cambiar, Color(0.85, 0.6, 1.0), "⇄")
	nodo_grupo_botones.add_child(nodo_btn_cambiar)
	
	# 3. Botón de Pausa
	nodo_btn_pausa = Control.new()
	nodo_btn_pausa.name = "Preview_Btn_Pausa"
	nodo_btn_pausa.custom_minimum_size = Vector2(130, 42)
	nodo_btn_pausa.size = Vector2(130, 42)
	nodo_btn_pausa.pivot_offset = Vector2(65, 21)
	nodo_btn_pausa.gui_input.connect(func(ev): _manejar_input_elemento("btn_pausa", ev, nodo_btn_pausa))
	_crear_dibujo_boton_pausa(nodo_btn_pausa)
	add_child(nodo_btn_pausa)

# --- Renderizado de Botones ---

func _crear_dibujo_joystick(parent: Control):
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.6, 0.9, 0.22)
	sb.border_color = Color(0.4, 0.85, 1.0, 0.85)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(90)
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)
	
	# Perilla Central
	var knob = Panel.new()
	knob.size = Vector2(64, 64)
	knob.position = Vector2(58, 58)
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb_k = StyleBoxFlat.new()
	sb_k.bg_color = Color(0.3, 0.75, 1.0, 0.55)
	sb_k.border_color = Color(0.7, 0.95, 1.0, 0.95)
	sb_k.border_width_left = 2
	sb_k.border_width_top = 2
	sb_k.border_width_right = 2
	sb_k.border_width_bottom = 2
	sb_k.set_corner_radius_all(32)
	knob.add_theme_stylebox_override("panel", sb_k)
	parent.add_child(knob)

func _crear_marco_seleccion(parent: Control):
	var panel_marco = Panel.new()
	panel_marco.name = "MarcoSeleccion"
	panel_marco.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.04)
	sb.border_color = Color(0.4, 0.85, 1.0, 0.45)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(14)
	panel_marco.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel_marco)

func _crear_dibujo_boton_accion(parent: Control, color_borde: Color, icono: String):
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(color_borde.r, color_borde.g, color_borde.b, 0.25)
	sb.border_color = color_borde
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(38)
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)
	
	var lbl_ico = Label.new()
	lbl_ico.text = icono
	lbl_ico.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl_ico.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_ico.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_ico.add_theme_font_size_override("font_size", 26)
	lbl_ico.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	parent.add_child(lbl_ico)

func _crear_dibujo_boton_pausa(parent: Control):
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.16, 0.24, 0.85)
	sb.border_color = Color(0.4, 0.8, 1.0, 0.75)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)
	
	var label = Label.new()
	label.text = "⏸ Pausa"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color.WHITE)
	parent.add_child(label)

func _estilar_boton(btn: Button, color_base: Color):
	var sb_n = StyleBoxFlat.new()
	sb_n.bg_color = color_base
	sb_n.border_color = color_base.lightened(0.3)
	sb_n.border_width_left = 1
	sb_n.border_width_top = 1
	sb_n.border_width_right = 1
	sb_n.border_width_bottom = 1
	sb_n.set_corner_radius_all(6)
	
	var sb_h = sb_n.duplicate()
	sb_h.bg_color = color_base.lightened(0.2)
	
	var sb_p = sb_n.duplicate()
	sb_p.bg_color = color_base.darkened(0.2)
	
	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_p)
	btn.add_theme_color_override("font_color", Color.WHITE)

# --- Sincronización de Posiciones y Escalas ---

func _actualizar_posiciones_y_escalas():
	var screen_size = get_viewport_rect().size
	if screen_size.x <= 0 or screen_size.y <= 0:
		screen_size = Vector2(1080, 720)
		
	# 1. Joystick
	var j_scale: float = config_actual.get("joystick_scale", 1.0)
	nodo_joystick.scale = Vector2(j_scale, j_scale)
	var j_center = Vector2(
		config_actual.get("joystick_pos_ratio_x", 0.15) * screen_size.x,
		config_actual.get("joystick_pos_ratio_y", 0.75) * screen_size.y
	)
	nodo_joystick.global_position = j_center - (nodo_joystick.size * 0.5 * j_scale)
	
	# 2. Grupo de Botones de Acción
	var bg_scale: float = config_actual.get("botones_accion_scale", 1.39)
	nodo_grupo_botones.scale = Vector2(bg_scale, bg_scale)
	var bg_center = Vector2(
		config_actual.get("botones_accion_pos_ratio_x", 0.84) * screen_size.x,
		config_actual.get("botones_accion_pos_ratio_y", 0.75) * screen_size.y
	)
	nodo_grupo_botones.global_position = bg_center - (nodo_grupo_botones.size * 0.5 * bg_scale)
	
	# Posiciones internas de los botones dentro del grupo
	var center_box = nodo_grupo_botones.size * 0.5
	
	# Salto
	var s_saltar: float = config_actual.get("btn_saltar_scale", 1.0)
	nodo_btn_saltar.scale = Vector2(s_saltar, s_saltar)
	nodo_btn_saltar.position = center_box + Vector2(
		config_actual.get("btn_saltar_offset_x", 40.0),
		config_actual.get("btn_saltar_offset_y", 51.0)
	) - (nodo_btn_saltar.size * 0.5)
	
	# Interactuar
	var s_int: float = config_actual.get("btn_interactuar_scale", 1.0)
	nodo_btn_interactuar.scale = Vector2(s_int, s_int)
	nodo_btn_interactuar.position = center_box + Vector2(
		config_actual.get("btn_interactuar_offset_x", 40.0),
		config_actual.get("btn_interactuar_offset_y", -51.0)
	) - (nodo_btn_interactuar.size * 0.5)
	
	# Cambiar
	var s_cam: float = config_actual.get("btn_cambiar_scale", 1.0)
	nodo_btn_cambiar.scale = Vector2(s_cam, s_cam)
	nodo_btn_cambiar.position = center_box + Vector2(
		config_actual.get("btn_cambiar_offset_x", -45.0),
		config_actual.get("btn_cambiar_offset_y", 0.0)
	) - (nodo_btn_cambiar.size * 0.5)
	
	# 3. Botón de Pausa
	var p_scale: float = config_actual.get("btn_pausa_scale", 1.0)
	nodo_btn_pausa.scale = Vector2(p_scale, p_scale)
	var p_pos = Vector2(
		config_actual.get("btn_pausa_pos_ratio_x", 0.92) * screen_size.x - (nodo_btn_pausa.size.x * 0.5 * p_scale),
		config_actual.get("btn_pausa_pos_ratio_y", 0.06) * screen_size.y
	)
	nodo_btn_pausa.global_position = p_pos

# --- Selección y Control de Escala ---

func _seleccionar_elemento(id: String):
	elemento_seleccionado = id
	var nombre_mostrado = ""
	var valor_escala: float = 1.0
	
	match id:
		"joystick":
			nombre_mostrado = "🕹️ Joystick Virtual"
			valor_escala = config_actual.get("joystick_scale", 1.0)
		"botones_accion":
			nombre_mostrado = "⚡ Grupo de Botones de Acción"
			valor_escala = config_actual.get("botones_accion_scale", 1.39)
		"btn_saltar":
			nombre_mostrado = "▲ Botón Saltar"
			valor_escala = config_actual.get("btn_saltar_scale", 1.0)
		"btn_interactuar":
			nombre_mostrado = "◆ Botón Interactuar / Aura"
			valor_escala = config_actual.get("btn_interactuar_scale", 1.0)
		"btn_cambiar":
			nombre_mostrado = "⇄ Botón Cambiar Personaje"
			valor_escala = config_actual.get("btn_cambiar_scale", 1.0)
		"btn_pausa":
			nombre_mostrado = "⏸ Botón de Pausa"
			valor_escala = config_actual.get("btn_pausa_scale", 1.0)
			
	if is_instance_valid(label_seleccionado):
		label_seleccionado.text = "Seleccionado: " + nombre_mostrado
	if is_instance_valid(slider_tamano):
		slider_tamano.set_value_no_signal(valor_escala)
	if is_instance_valid(label_tamano_valor):
		label_tamano_valor.text = str(int(round(valor_escala * 100))) + "%"

func _on_slider_tamano_changed(nuevo_tamano: float):
	if is_instance_valid(label_tamano_valor):
		label_tamano_valor.text = str(int(round(nuevo_tamano * 100))) + "%"
		
	match elemento_seleccionado:
		"joystick":
			config_actual["joystick_scale"] = nuevo_tamano
		"botones_accion":
			config_actual["botones_accion_scale"] = nuevo_tamano
		"btn_saltar":
			config_actual["btn_saltar_scale"] = nuevo_tamano
		"btn_interactuar":
			config_actual["btn_interactuar_scale"] = nuevo_tamano
		"btn_cambiar":
			config_actual["btn_cambiar_scale"] = nuevo_tamano
		"btn_pausa":
			config_actual["btn_pausa_scale"] = nuevo_tamano
			
	_actualizar_posiciones_y_escalas()

func _on_toggle_modo_movimiento():
	modo_movimiento_individual = !modo_movimiento_individual
	if modo_movimiento_individual:
		btn_modo_movimiento.text = "Mover: Individual"
		_estilar_boton(btn_modo_movimiento, Color(0.6, 0.4, 0.15))
		if elemento_seleccionado == "botones_accion":
			_seleccionar_elemento("btn_saltar")
	else:
		btn_modo_movimiento.text = "Mover: Grupo"
		_estilar_boton(btn_modo_movimiento, Color(0.2, 0.4, 0.6))
		if elemento_seleccionado in ["btn_saltar", "btn_interactuar", "btn_cambiar"]:
			_seleccionar_elemento("botones_accion")

# --- Manejo de Arrastre Centrado y Sin Saltos ---

func _manejar_input_boton_accion(id_btn: String, event: InputEvent, nodo: Control):
	accept_event()
	if modo_movimiento_individual:
		_manejar_input_elemento(id_btn, event, nodo)
	else:
		# Modo grupo: arrastrar el grupo completo centrado
		_manejar_input_elemento("botones_accion", event, nodo_grupo_botones)

func _manejar_input_elemento(id_elem: String, event: InputEvent, nodo: Control):
	accept_event()
	
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		var pressed = event.is_pressed()
		var pos_global = event.global_position if "global_position" in event else get_viewport().get_mouse_position()
		
		if pressed:
			_seleccionar_elemento(id_elem)
			arrastrando = true
			elemento_en_arrastre = id_elem
			id_toque_arrastre = event.index if event is InputEventScreenTouch else -1
			# Centrar y mover inmediatamente al toque inicial
			_procesar_arrastre(id_elem, nodo, pos_global)
		else:
			if arrastrando and (id_toque_arrastre == -1 or (event is InputEventScreenTouch and event.index == id_toque_arrastre)):
				arrastrando = false
				elemento_en_arrastre = ""
				
	elif (event is InputEventScreenDrag and (id_toque_arrastre == -1 or event.index == id_toque_arrastre)) or (event is InputEventMouseMotion and arrastrando and id_toque_arrastre == -1):
		var pos_global = event.global_position if "global_position" in event else get_viewport().get_mouse_position()
		_procesar_arrastre(id_elem, nodo, pos_global)

func _procesar_arrastre(id_elem: String, nodo: Control, touch_global_pos: Vector2):
	var screen_size = get_viewport_rect().size
	if screen_size.x <= 0 or screen_size.y <= 0:
		screen_size = Vector2(1080, 720)
		
	if id_elem in ["btn_saltar", "btn_interactuar", "btn_cambiar"]:
		# Mover botón individual con su centro exactamente bajo el dedo/cursor respecto al centro del grupo
		var cluster_center_global = nodo_grupo_botones.global_position + (nodo_grupo_botones.size * 0.5 * nodo_grupo_botones.scale)
		var relative_diff = (touch_global_pos - cluster_center_global) / nodo_grupo_botones.scale
		var offset = relative_diff.clamp(Vector2(-140, -140), Vector2(140, 140))
		
		match id_elem:
			"btn_saltar":
				config_actual["btn_saltar_offset_x"] = offset.x
				config_actual["btn_saltar_offset_y"] = offset.y
			"btn_interactuar":
				config_actual["btn_interactuar_offset_x"] = offset.x
				config_actual["btn_interactuar_offset_y"] = offset.y
			"btn_cambiar":
				config_actual["btn_cambiar_offset_x"] = offset.x
				config_actual["btn_cambiar_offset_y"] = offset.y
		_actualizar_posiciones_y_escalas()
	else:
		# Mover elementos globales (Joystick, Grupo de Botones o Pausa) tomados exactamente de su centro
		var nodo_tam_escalado = nodo.size * nodo.scale
		var half_size = nodo_tam_escalado * 0.5
		
		# Limitar para no salir de la pantalla ni tapar la barra superior (top limit = 90px)
		var top_limit = 90.0 if id_elem != "btn_pausa" else 5.0
		var new_pos = touch_global_pos - half_size
		new_pos.x = clampf(new_pos.x, 8.0, screen_size.x - nodo_tam_escalado.x - 8.0)
		new_pos.y = clampf(new_pos.y, top_limit, screen_size.y - nodo_tam_escalado.y - 8.0)
		
		var center = new_pos + half_size
		var ratio_x = clampf(center.x / screen_size.x, 0.02, 0.98)
		var ratio_y = clampf(center.y / screen_size.y, 0.02, 0.98)
		
		match id_elem:
			"joystick":
				config_actual["joystick_pos_ratio_x"] = ratio_x
				config_actual["joystick_pos_ratio_y"] = ratio_y
			"botones_accion":
				config_actual["botones_accion_pos_ratio_x"] = ratio_x
				config_actual["botones_accion_pos_ratio_y"] = ratio_y
			"btn_pausa":
				config_actual["btn_pausa_pos_ratio_x"] = ratio_x
				config_actual["btn_pausa_pos_ratio_y"] = ratio_y
				
		_actualizar_posiciones_y_escalas()

# --- Botones de Control ---

func _on_restablecer_pressed():
	config_actual = HudConfigManager.obtener_defaults()
	_actualizar_posiciones_y_escalas()
	_seleccionar_elemento(elemento_seleccionado)
	_mostrar_toast("↺ Controles restablecidos a valores por defecto")

func _on_cancelar_pressed():
	cerrado.emit()
	queue_free()

func _on_guardar_pressed():
	HudConfigManager.guardar_config(config_actual)
	_mostrar_toast("✅ ¡Configuración guardada exitosamente!")
	guardado.emit(config_actual)
	
	var timer = get_tree().create_timer(0.35)
	timer.timeout.connect(func():
		cerrado.emit()
		queue_free()
	)

func _mostrar_toast(mensaje: String):
	if not is_instance_valid(toast_guardado):
		return
	if tween_toast and tween_toast.is_running():
		tween_toast.kill()
		
	toast_guardado.text = mensaje
	toast_guardado.modulate.a = 1.0
	tween_toast = create_tween()
	tween_toast.tween_interval(1.2)
	tween_toast.tween_property(toast_guardado, "modulate:a", 0.0, 0.35)
