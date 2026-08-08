extends Control

@onready var joystick = $Joystick_Virtual
@onready var icono_moneda = $HUD_Puntuacion/Contenedor_Puntuacion/Icono_Moneda
@onready var texto_puntuacion = $HUD_Puntuacion/Contenedor_Puntuacion/Texto_Puntuacion

var arrastre_camara : Vector2 = Vector2.ZERO
var _personaje_conectado: Node
var joystick_dedo : int = -1

func _ready():
	add_to_group("ui_tactil")
	_inicializar_joystick()
	if has_node("HUD_Puntuacion"):
		$HUD_Puntuacion.visible = true
		$HUD_Puntuacion.modulate.a = 0.0
	_aplicar_estilo_textos_y_botones(self)
	_crear_indicador_ping()

var label_ping: Label = null

func _crear_indicador_ping():
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 100) # Debajo del hud de monedas
	
	label_ping = Label.new()
	label_ping.text = "Ping: -- ms"
	label_ping.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	label_ping.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label_ping.add_theme_font_size_override("font_size", 14)
	margin.add_child(label_ping)
	add_child(margin)
	
	if is_instance_valid(RedManager):
		if not RedManager.ping_actualizado.is_connected(_on_ping_actualizado):
			RedManager.ping_actualizado.connect(_on_ping_actualizado)
		# Inicializar con el valor actual si existe
		_on_ping_actualizado(RedManager.current_ping_ms)

func _on_ping_actualizado(ms: int):
	if not is_instance_valid(label_ping): return
	if ms < 0:
		label_ping.text = "Ping: -- ms"
		label_ping.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		label_ping.text = "Ping: " + str(ms) + " ms"
		if ms < 80:
			label_ping.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
		elif ms < 150:
			label_ping.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		else:
			label_ping.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))


func _inicializar_joystick():
	if not joystick: return
	
	joystick.joystick_mode = 1 # JOYSTICK_DYNAMIC
	joystick.joystick_size = 200.0
	joystick.tip_size = 70.0
	joystick.deadzone_ratio = 0.0
	joystick.clampzone_ratio = 1.0
	joystick.initial_offset_ratio = Vector2(0.3, 0.5)
	joystick.visibility_mode = 0 # VISIBILITY_ALWAYS
	
	joystick.action_left = &"mover_izquierda"
	joystick.action_right = &"mover_derecha"
	joystick.action_up = &"mover_adelante"
	joystick.action_down = &"mover_atras"
	
	_actualizar_estilo_joystick()
	joystick.gui_input.connect(_on_joystick_gui_input)

var color_personaje_ui: Color = Color(1.0, 0.8, 0.2) # Default golden

func obtener_color_ui() -> Color:
	return color_personaje_ui

func configurar_estilo_personaje(es_fantasma: bool):
	if es_fantasma:
		color_personaje_ui = Color(0.25, 0.78, 1.0) # Neon Cyan / Blue
	else:
		color_personaje_ui = Color(1.0, 0.82, 0.25) # Warm Golden Yellow
	_actualizar_estilo_joystick()

func _actualizar_estilo_joystick():
	if not joystick: return
	
	var c = color_personaje_ui
	var style_base = StyleBoxFlat.new()
	style_base.bg_color = Color(c.r, c.g, c.b, 0.16)
	style_base.border_color = Color(c.r, c.g, c.b, 0.6)
	style_base.border_width_left = 3
	style_base.border_width_top = 3
	style_base.border_width_right = 3
	style_base.border_width_bottom = 3
	style_base.set_corner_radius_all(100)
	
	var style_tip = StyleBoxFlat.new()
	style_tip.bg_color = Color(c.r, c.g, c.b, 0.35)
	style_tip.border_color = Color(c.r, c.g, c.b, 0.8)
	style_tip.border_width_left = 2
	style_tip.border_width_top = 2
	style_tip.border_width_right = 2
	style_tip.border_width_bottom = 2
	style_tip.set_corner_radius_all(35)
	
	joystick.add_theme_stylebox_override(&"normal_joystick", style_base)
	joystick.add_theme_stylebox_override(&"pressed_joystick", style_base)
	joystick.add_theme_stylebox_override(&"normal_tip", style_tip)
	joystick.add_theme_stylebox_override(&"pressed_tip", style_tip)

func _on_joystick_gui_input(event: InputEvent):
	if event is InputEventScreenTouch:
		if event.is_pressed():
			joystick_dedo = event.index
		else:
			joystick_dedo = -1
	elif event is InputEventScreenDrag:
		joystick_dedo = event.index

func _input(event):
	if event is InputEventScreenDrag:
		if joystick_dedo != -1 and event.index == joystick_dedo:
			return

		var mitad_pantalla = get_viewport_rect().size.x / 2
		if event.position.x > mitad_pantalla:
			arrastre_camara += event.relative

func consumir_arrastre() -> Vector2:
	var temp = arrastre_camara
	arrastre_camara = Vector2.ZERO
	return temp

func configurar_personaje_local(personaje: Node):
	var callback = Callable(self, "actualizar_boton_aura")
	if is_instance_valid(_personaje_conectado) and _personaje_conectado.has_signal("aura_estado_actualizado"):
		if _personaje_conectado.aura_estado_actualizado.is_connected(callback):
			_personaje_conectado.aura_estado_actualizado.disconnect(callback)

	# Desconectar señales de score anteriores para evitar duplicados
	var callback_vivo = Callable(self, "_on_score_vivo_changed")
	var callback_fantasma = Callable(self, "_on_score_fantasma_changed")
	if is_instance_valid(ScoreManager):
		if ScoreManager.score_vivo_changed.is_connected(callback_vivo):
			ScoreManager.score_vivo_changed.disconnect(callback_vivo)
		if ScoreManager.score_fantasma_changed.is_connected(callback_fantasma):
			ScoreManager.score_fantasma_changed.disconnect(callback_fantasma)

	_personaje_conectado = personaje

	# Garantizar que las referencias del HUD estén resueltas si se llama antes del _ready() de esta escena
	if not is_instance_valid(icono_moneda):
		icono_moneda = get_node_or_null("HUD_Puntuacion/Contenedor_Puntuacion/Icono_Moneda")
	if not is_instance_valid(texto_puntuacion):
		texto_puntuacion = get_node_or_null("HUD_Puntuacion/Contenedor_Puntuacion/Texto_Puntuacion")

	if is_instance_valid(icono_moneda) and is_instance_valid(texto_puntuacion):
		var hud_puntuacion = get_node_or_null("HUD_Puntuacion")
		if hud_puntuacion:
			hud_puntuacion.visible = true
			hud_puntuacion.modulate.a = 0.0
			
		var es_fantasma = personaje.is_in_group("fantasmas") or personaje.name.to_lower().contains("fantasma") or personaje.has_node("HabilidadAura")
		if es_fantasma:
			aplicar_estilo_fantasma()

			# Cargar textura de esmeralda y modular a verde espectral
			var tex_emerald = load("res://assets/Modelos/Provicional/RuinsGLB/Accessories/AncientCoinEmerald_AncientCoinEmerald_1_Color.png")
			icono_moneda.texture = tex_emerald
			icono_moneda.self_modulate = Color(0.4, 1.0, 0.4) # Tinte verde
			
			# Conectar señal de puntuación del fantasma
			if is_instance_valid(ScoreManager):
				ScoreManager.score_fantasma_changed.connect(callback_fantasma)
				_on_score_fantasma_changed(ScoreManager.score_fantasma)
				
			if not personaje.aura_estado_actualizado.is_connected(callback):
				personaje.aura_estado_actualizado.connect(callback)
		else:
			aplicar_estilo_jugador()
			# Cargar textura de rubí y modular a rojo vida
			var tex_ruby = load("res://assets/Modelos/Provicional/RuinsGLB/Accessories/AncientCoinRuby_AncientGoldCoinRuby_1_Color.png")
			icono_moneda.texture = tex_ruby
			icono_moneda.self_modulate = Color(1.0, 0.4, 0.4) # Tinte rojo
			
			# Conectar señal de puntuación del jugador vivo
			if is_instance_valid(ScoreManager):
				ScoreManager.score_vivo_changed.connect(callback_vivo)
				_on_score_vivo_changed(ScoreManager.score_vivo)

var _hud_tween: Tween

func mostrar_hud_monedas_temporal(duracion_visible: float = 3.0, duracion_fade: float = 0.8) -> void:
	var hud_puntuacion = get_node_or_null("HUD_Puntuacion")
	if not is_instance_valid(hud_puntuacion):
		return
		
	hud_puntuacion.visible = true
	hud_puntuacion.pivot_offset = Vector2(0, hud_puntuacion.size.y / 2.0)
	
	if _hud_tween and _hud_tween.is_running():
		_hud_tween.kill()
		
	_hud_tween = create_tween()
	hud_puntuacion.modulate.a = 1.0
	hud_puntuacion.scale = Vector2(1.12, 1.12)
	_hud_tween.tween_property(hud_puntuacion, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hud_tween.tween_interval(duracion_visible)
	_hud_tween.tween_property(hud_puntuacion, "modulate:a", 0.0, duracion_fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_score_vivo_changed(new_score: int) -> void:
	if is_instance_valid(texto_puntuacion):
		texto_puntuacion.text = "Esencias de Vida: %d" % new_score
		mostrar_hud_monedas_temporal()

func _on_score_fantasma_changed(new_score: int) -> void:
	if is_instance_valid(texto_puntuacion):
		texto_puntuacion.text = "Fragmentos Espectrales: %d" % new_score
		mostrar_hud_monedas_temporal()

func aplicar_estilo_jugador():
	configurar_estilo_personaje(false)
	var shader = Shader.new()
	shader.code = "shader_type canvas_item; uniform vec4 color_solido : source_color; void fragment() { vec4 tex = texture(TEXTURE, UV); COLOR = vec4(color_solido.rgb, tex.a * color_solido.a); }"
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("color_solido", Color(1.0, 0.82, 0.25, 0.35)) # Dorado cálido igual al joystick

	modulate = Color(1, 1, 1)
	_aplicar_shader_recursivo(self, mat)


func aplicar_estilo_fantasma():
	configurar_estilo_personaje(true)
	var shader = Shader.new()
	shader.code = "shader_type canvas_item; uniform vec4 color_solido : source_color; void fragment() { vec4 tex = texture(TEXTURE, UV); COLOR = vec4(color_solido.rgb, tex.a * color_solido.a); }"
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("color_solido", Color(0.101, 0.442, 1.5, 0.306))

	modulate = Color(1, 1, 1)
	_aplicar_shader_recursivo(self, mat)

	var btn_interact = get_node_or_null("Area_Camara/Zona_Botones_Accion/Boton_Interactuar")
	if btn_interact and btn_interact.material:
		btn_interact.material = btn_interact.material.duplicate()


func actualizar_boton_aura(activo: bool, progreso: float):
	var btn = get_node_or_null("Area_Camara/Zona_Botones_Accion/Boton_Interactuar")
	if btn and btn.material:
		if not activo and progreso < 1.0 and progreso > 0.0:
			btn.material.set_shader_parameter("color_solido", Color(0.2, 0.2, 0.2, 0.3))
		else:
			btn.material.set_shader_parameter("color_solido", Color(0.101, 0.442, 1.5, 0.306))

func _aplicar_shader_recursivo(nodo: Node, material_shader: ShaderMaterial):
	# Evitar teñir la raíz completa, el área de cámara, el botón de pausa y los paneles del menú
	if nodo == self or nodo.name == "Area_Camara" or nodo.name == "Panel_Pausa" or nodo.name == "Panel_Opciones" or nodo.name == "HUD_Menu" or nodo.name == "Boton_Pausa":
		_limpiar_shader_recursivo(nodo)
		for hijo in nodo.get_children():
			_aplicar_shader_recursivo(hijo, material_shader)
		return

	# Aplicar el shader SOLO a los botones de acción táctiles (TouchScreenButton)
	if nodo is TouchScreenButton:
		nodo.material = material_shader

	for hijo in nodo.get_children():
		_aplicar_shader_recursivo(hijo, material_shader)


func _limpiar_shader_recursivo(nodo: Node):
	if nodo is CanvasItem:
		nodo.material = null

	for hijo in nodo.get_children():
		_limpiar_shader_recursivo(hijo)

func _aplicar_estilo_textos_y_botones(nodo: Node):
	var es_fantasma = false
	if is_instance_valid(_personaje_conectado):
		es_fantasma = _personaje_conectado.is_in_group("fantasmas") or _personaje_conectado.name.to_lower().contains("fantasma") or _personaje_conectado.has_node("HabilidadAura")
	
	var color_borde = Color(0.98, 0.78, 0.25, 0.88) if not es_fantasma else Color(0.35, 0.65, 0.95, 0.8)
	var color_borde_hover = Color(1.0, 0.88, 0.4, 0.95) if not es_fantasma else Color(0.55, 0.85, 1.0, 0.95)
	
	_estilar_nodo_recursivo(nodo, color_borde, color_borde_hover)

func _estilar_nodo_recursivo(nodo: Node, color_borde: Color, color_borde_hover: Color):
	if nodo is Label:
		nodo.add_theme_color_override(&"font_color", Color(1.0, 1.0, 1.0, 1.0))
		nodo.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
		nodo.add_theme_constant_override(&"outline_size", 8)
		nodo.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
		nodo.add_theme_constant_override(&"shadow_offset_x", 2)
		nodo.add_theme_constant_override(&"shadow_offset_y", 2)
		
	elif nodo is Button:
		nodo.material = null
		nodo.add_theme_color_override(&"font_color", Color(1.0, 1.0, 1.0, 1.0))
		nodo.add_theme_color_override(&"font_pressed_color", Color(0.9, 0.9, 0.9, 1.0))
		nodo.add_theme_color_override(&"font_hover_color", Color(1.0, 0.95, 0.6, 1.0))
		nodo.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
		nodo.add_theme_constant_override(&"outline_size", 6)
		
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.10, 0.12, 0.20, 0.90)
		style_normal.border_color = color_borde
		style_normal.border_width_left = 2
		style_normal.border_width_top = 2
		style_normal.border_width_right = 2
		style_normal.border_width_bottom = 2
		style_normal.set_corner_radius_all(10)
		
		var style_hover = style_normal.duplicate()
		style_hover.bg_color = Color(0.16, 0.20, 0.32, 0.95)
		style_hover.border_color = color_borde_hover
		
		var style_pressed = style_normal.duplicate()
		style_pressed.bg_color = Color(0.06, 0.08, 0.14, 0.95)
		style_pressed.border_color = color_borde
		
		nodo.add_theme_stylebox_override(&"normal", style_normal)
		nodo.add_theme_stylebox_override(&"hover", style_hover)
		nodo.add_theme_stylebox_override(&"pressed", style_pressed)
		nodo.add_theme_stylebox_override(&"focus", style_hover)

	elif nodo is Panel and (nodo.name == "Panel_Pausa" or nodo.name == "Panel_Opciones"):
		nodo.material = null
		var style_panel = StyleBoxFlat.new()
		style_panel.bg_color = Color(0.08, 0.10, 0.16, 0.92)
		style_panel.border_color = color_borde
		style_panel.border_width_left = 0
		style_panel.border_width_top = 0
		style_panel.border_width_right = 0
		style_panel.border_width_bottom = 0
		style_panel.set_corner_radius_all(16)
		# Sombra sutil y tenue
		style_panel.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
		style_panel.shadow_size = 16
		style_panel.shadow_offset = Vector2(0, 4)
		nodo.add_theme_stylebox_override(&"panel", style_panel)


	for hijo in nodo.get_children():
		_estilar_nodo_recursivo(hijo, color_borde, color_borde_hover)



# --- Gestores de HUD: Menú de Pausa, Ajustes y Salida Segura ---

func _on_boton_pausa_pressed() -> void:
	var panel_p = get_node_or_null("Panel_Pausa")
	if panel_p:
		panel_p.visible = !panel_p.visible
		# Ocultar panel de opciones por seguridad al alternar pausa
		var panel_o = get_node_or_null("Panel_Opciones")
		if panel_o:
			panel_o.visible = false
		print("[ControlesTactiles] Menú de Pausa alternado a: ", panel_p.visible)

func _on_boton_continuar_pressed() -> void:
	var panel_p = get_node_or_null("Panel_Pausa")
	if panel_p:
		panel_p.visible = false

func _on_boton_opciones_pressed() -> void:
	var panel_p = get_node_or_null("Panel_Pausa")
	var panel_o = get_node_or_null("Panel_Opciones")
	if panel_o:
		panel_o.visible = true
	if panel_p:
		panel_p.visible = false
	print("[ControlesTactiles] Entrando a Ajustes (Ocultando Pausa)")

func _on_boton_cerrar_opciones_pressed() -> void:
	var panel_p = get_node_or_null("Panel_Pausa")
	var panel_o = get_node_or_null("Panel_Opciones")
	if panel_o:
		panel_o.visible = false
	if panel_p:
		panel_p.visible = true
	print("[ControlesTactiles] Volviendo a Menú de Pausa (Ocultando Ajustes)")

func _on_boton_salir_pressed() -> void:
	print("[ControlesTactiles] Iniciando desconexión segura del entorno P2P...")
	

	
	# 1. Liberar datos, detener broadcasters de LAN, cerrar puertos UPNP y limpiar referencias
	if is_instance_valid(RedManager):
		if RedManager.has_method("desconectar"):
			RedManager.desconectar()
			
	# 2. Desasociar explícitamente el peer de red de Godot por seguridad
	if multiplayer:
		multiplayer.multiplayer_peer = null
		
	# 3. Volver de forma limpia al menú de inicio y liberar recursos huérfanos
	get_tree().change_scene_to_file("res://scenes/ui/menu_inicio.tscn")
