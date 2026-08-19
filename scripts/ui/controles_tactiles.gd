extends Control

@onready var joystick = $Joystick_Virtual
@onready var icono_moneda = $HUD_Puntuacion/Contenedor_Puntuacion/Icono_Moneda
@onready var texto_puntuacion = $HUD_Puntuacion/Contenedor_Puntuacion/Texto_Puntuacion

var arrastre_camara : Vector2 = Vector2.ZERO
var _personaje_conectado: Node
var joystick_dedo : int = -1

func _ready():
	add_to_group("ui_tactil")
	var es_fantasma_inicial = false
	if is_instance_valid(RedManager) and RedManager.es_un_jugador:
		es_fantasma_inicial = (RedManager.personaje_activo_solo == "fantasma")
	if es_fantasma_inicial:
		color_personaje_ui = Color(0.30, 0.82, 1.0)
	else:
		color_personaje_ui = Color(1.0, 0.82, 0.25)
		
	_inicializar_joystick()
	if has_node("HUD_Puntuacion"):
		$HUD_Puntuacion.visible = true
		$HUD_Puntuacion.modulate.a = 0.0
	_aplicar_estilo_textos_y_botones(self)
	_crear_indicador_ping()
	_crear_hud_un_jugador()
	HudConfigManager.aplicar_a_hud(self)
	_inicializar_controles_opciones_hud()

var label_ping: Label = null
@onready var boton_cambiar_personaje: TouchScreenButton = get_node_or_null("Area_Camara/Zona_Botones_Accion/Boton_Cambiar_Personaje")
var label_aviso_cambio: Label = null
var overlay_transicion: ColorRect = null
var _aviso_tween: Tween = null
var _overlay_tween: Tween = null

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

func _crear_hud_un_jugador() -> void:
	var es_offline = (multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	var es_solo = is_instance_valid(RedManager) and (RedManager.es_un_jugador or es_offline)
	
	if not is_instance_valid(boton_cambiar_personaje):
		boton_cambiar_personaje = get_node_or_null("Area_Camara/Zona_Botones_Accion/Boton_Cambiar_Personaje")
		
	if is_instance_valid(boton_cambiar_personaje):
		boton_cambiar_personaje.visible = es_solo
		if not boton_cambiar_personaje.pressed.is_connected(_on_btn_cambiar_personaje_pressed):
			boton_cambiar_personaje.pressed.connect(_on_btn_cambiar_personaje_pressed)

	if not es_solo:
		return
		
	if not has_node("LabelAvisoCambio"):
		label_aviso_cambio = Label.new()
		label_aviso_cambio.name = "LabelAvisoCambio"
		label_aviso_cambio.set_anchors_preset(Control.PRESET_CENTER_TOP)
		label_aviso_cambio.offset_top = 80
		label_aviso_cambio.grow_horizontal = Control.GROW_DIRECTION_BOTH
		label_aviso_cambio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label_aviso_cambio.add_theme_font_size_override("font_size", 18)
		label_aviso_cambio.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		label_aviso_cambio.add_theme_constant_override("outline_size", 8)
		label_aviso_cambio.modulate.a = 0.0
		label_aviso_cambio.z_index = 10
		add_child(label_aviso_cambio)

	if not has_node("OverlayTransicion"):
		overlay_transicion = ColorRect.new()
		overlay_transicion.name = "OverlayTransicion"
		overlay_transicion.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay_transicion.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay_transicion.color = Color(1, 1, 1, 0)
		overlay_transicion.modulate.a = 0.0
		overlay_transicion.z_index = 20
		add_child(overlay_transicion)
	
	if not RedManager.personaje_solo_cambiado.is_connected(_on_personaje_solo_cambiado):
		RedManager.personaje_solo_cambiado.connect(_on_personaje_solo_cambiado)
	if not RedManager.transicion_camara_iniciada.is_connected(_on_transicion_camara_iniciada):
		RedManager.transicion_camara_iniciada.connect(_on_transicion_camara_iniciada)
		
	_actualizar_boton_cambio(RedManager.personaje_activo_solo)

func _on_btn_cambiar_personaje_pressed() -> void:
	if is_instance_valid(RedManager) and RedManager.has_method("alternar_personaje_un_jugador"):
		if not RedManager.transicion_en_progreso:
			RedManager.alternar_personaje_un_jugador()

func _on_transicion_camara_iniciada(_origen: String, destino: String, duracion: float) -> void:
	_reproducir_destello_transicion(destino, duracion)

func _reproducir_destello_transicion(destino: String, duracion: float) -> void:
	if not is_instance_valid(overlay_transicion):
		return
	if _overlay_tween and _overlay_tween.is_running():
		_overlay_tween.kill()

	var color_flash: Color = Color(0.25, 0.82, 1.0, 0.28) if destino == "fantasma" else Color(1.0, 0.86, 0.35, 0.24)
	overlay_transicion.color = color_flash
	overlay_transicion.modulate.a = 0.0

	var mitad_duracion: float = duracion * 0.45
	var resto_duracion: float = duracion - mitad_duracion

	_overlay_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_overlay_tween.tween_property(overlay_transicion, "modulate:a", 1.0, mitad_duracion)
	_overlay_tween.tween_property(overlay_transicion, "modulate:a", 0.0, resto_duracion)

func _on_personaje_solo_cambiado(nuevo_personaje: String) -> void:
	if nuevo_personaje == "fantasma":
		aplicar_estilo_fantasma()
	else:
		aplicar_estilo_jugador()
	_actualizar_boton_cambio(nuevo_personaje)
	mostrar_aviso_cambio_personaje(nuevo_personaje)

func _actualizar_boton_cambio(_personaje_activo: String) -> void:
	if not is_instance_valid(boton_cambiar_personaje):
		boton_cambiar_personaje = get_node_or_null("Area_Camara/Zona_Botones_Accion/Boton_Cambiar_Personaje")
	if is_instance_valid(boton_cambiar_personaje):
		boton_cambiar_personaje.queue_redraw()

func mostrar_aviso_cambio_personaje(personaje_activo: String) -> void:
	if not is_instance_valid(label_aviso_cambio):
		return
	if _aviso_tween and _aviso_tween.is_running():
		_aviso_tween.kill()
		
	if personaje_activo == "jugador":
		label_aviso_cambio.text = "👤 Controlando: Jugador Vivo (Plano Físico)"
		label_aviso_cambio.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	else:
		label_aviso_cambio.text = "👻 Controlando: Fantasma (Plano Espiritual)"
		label_aviso_cambio.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
		
	_aviso_tween = create_tween()
	label_aviso_cambio.modulate.a = 1.0
	_aviso_tween.tween_interval(1.8)
	_aviso_tween.tween_property(label_aviso_cambio, "modulate:a", 0.0, 0.6)


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
		color_personaje_ui = Color(0.30, 0.82, 1.0) # Turquesa / Cian escarchado
	else:
		color_personaje_ui = Color(1.0, 0.82, 0.25) # Warm Golden Yellow
	_actualizar_estilo_joystick()

func _actualizar_estilo_joystick():
	if not joystick: return
	
	var c = color_personaje_ui
	var es_fantasma = (c.b > 0.6 and c.r < 0.6)
	
	var style_base = StyleBoxFlat.new()
	if es_fantasma:
		style_base.bg_color = Color(0.15, 0.45, 0.65, 0.22) # Cristal escarchado cian
		style_base.border_color = Color(0.40, 0.85, 1.0, 0.75)
		style_base.border_width_left = 3
		style_base.border_width_top = 3
		style_base.border_width_right = 3
		style_base.border_width_bottom = 3
		style_base.set_corner_radius_all(100)
		style_base.shadow_color = Color(0.1, 0.5, 0.8, 0.2)
		style_base.shadow_size = 8
	else:
		style_base.bg_color = Color(c.r, c.g, c.b, 0.16)
		style_base.border_color = Color(c.r, c.g, c.b, 0.6)
		style_base.border_width_left = 3
		style_base.border_width_top = 3
		style_base.border_width_right = 3
		style_base.border_width_bottom = 3
		style_base.set_corner_radius_all(100)
	
	var style_tip = StyleBoxFlat.new()
	if es_fantasma:
		style_tip.bg_color = Color(0.22, 0.65, 0.90, 0.45)
		style_tip.border_color = Color(0.65, 0.95, 1.0, 0.90)
		style_tip.border_width_left = 2
		style_tip.border_width_top = 2
		style_tip.border_width_right = 2
		style_tip.border_width_bottom = 2
		style_tip.set_corner_radius_all(35)
		style_tip.shadow_color = Color(0.2, 0.8, 1.0, 0.3)
		style_tip.shadow_size = 6
	else:
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
var _ultimo_tiempo_toque_camara : float = -10.0
var _ultima_pos_toque_camara : Vector2 = Vector2.ZERO
var _arrastre_acumulado_toque : float = 0.0
var _solicitud_centrado_camara : bool = false
const TIEMPO_DOBLE_TOQUE : float = 0.35
const DISTANCIA_MAX_DOBLE_TOQUE : float = 45.0

func _on_joystick_gui_input(event: InputEvent):
	if event is InputEventScreenTouch:
		if event.is_pressed():
			joystick_dedo = event.index
		else:
			joystick_dedo = -1
	elif event is InputEventScreenDrag:
		joystick_dedo = event.index

func esta_bloqueado_para_juego() -> bool:
	if not is_visible_in_tree():
		return true
	var panel_p = get_node_or_null("Panel_Pausa")
	if is_instance_valid(panel_p) and panel_p.visible:
		return true
	var panel_o = get_node_or_null("Panel_Opciones")
	if is_instance_valid(panel_o) and panel_o.visible:
		return true
	if has_node("AjusteHUD"):
		return true
	return false

func _input(event):
	if esta_bloqueado_para_juego():
		arrastre_camara = Vector2.ZERO
		return

	var mitad_pantalla = get_viewport_rect().size.x / 2

	if event is InputEventScreenTouch:
		if joystick_dedo != -1 and event.index == joystick_dedo:
			return

		if event.position.x > mitad_pantalla:
			if event.is_pressed():
				_arrastre_acumulado_toque = 0.0
				var tiempo_actual = Time.get_ticks_msec() / 1000.0
				var delta_tiempo = tiempo_actual - _ultimo_tiempo_toque_camara
				var dist = event.position.distance_to(_ultima_pos_toque_camara)

				if delta_tiempo <= TIEMPO_DOBLE_TOQUE and dist <= DISTANCIA_MAX_DOBLE_TOQUE:
					# Doble toque rápido detectado en el área de la cámara: centrar cámara detrás
					_solicitud_centrado_camara = true
					_ultimo_tiempo_toque_camara = -10.0
				else:
					_ultimo_tiempo_toque_camara = tiempo_actual
					_ultima_pos_toque_camara = event.position
			else:
				# Si soltó tras haber arrastrado ampliamente, no era un toque limpio
				if _arrastre_acumulado_toque > 25.0:
					_ultimo_tiempo_toque_camara = -10.0

	elif event is InputEventScreenDrag:
		if joystick_dedo != -1 and event.index == joystick_dedo:
			return

		if event.position.x > mitad_pantalla:
			arrastre_camara += event.relative
			_arrastre_acumulado_toque += event.relative.length()

func consumir_arrastre() -> Vector2:
	var temp = arrastre_camara
	arrastre_camara = Vector2.ZERO
	return temp

func consumir_centrado_camara() -> bool:
	var temp = _solicitud_centrado_camara
	_solicitud_centrado_camara = false
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

	var es_fantasma = false
	if is_instance_valid(personaje):
		es_fantasma = personaje.is_in_group("fantasmas") or personaje.name.to_lower().contains("fantasma") or personaje.has_node("HabilidadAura")

	if is_instance_valid(icono_moneda) and is_instance_valid(texto_puntuacion):
		var hud_puntuacion = get_node_or_null("HUD_Puntuacion")
		if hud_puntuacion:
			hud_puntuacion.visible = true
			hud_puntuacion.modulate.a = 0.0
			
		if es_fantasma:
			aplicar_estilo_fantasma()

			# Cargar textura de esmeralda y modular a verde/cyan espectral
			var tex_emerald = load("res://assets/Modelos/Provicional/RuinsGLB/Accessories/AncientCoinEmerald_AncientCoinEmerald_1_Color.png")
			icono_moneda.texture = tex_emerald
			icono_moneda.self_modulate = Color(0.4, 1.0, 0.8) # Tinte espectral
			
			# Conectar señal de puntuación del fantasma
			if is_instance_valid(ScoreManager):
				ScoreManager.score_fantasma_changed.connect(callback_fantasma)
				_on_score_fantasma_changed(ScoreManager.score_fantasma)
				
			if not personaje.aura_estado_actualizado.is_connected(callback):
				personaje.aura_estado_actualizado.connect(callback)
				
			# Inicializar estado del botón de aura con el progreso actual
			if is_instance_valid(personaje.habilidad_aura):
				var aura = personaje.habilidad_aura
				var progreso = 1.0 if aura.cooldown_actual <= 0.0 else (1.0 - (aura.cooldown_actual / aura.tiempo_recarga))
				actualizar_boton_aura(aura.activa, progreso)
			else:
				actualizar_boton_aura(false, 1.0)
		else:
			aplicar_estilo_jugador()
			# Cargar textura de rubí y modular a rojo vida
			var tex_ruby = load("res://assets/Modelos/Provicional/RuinsGLB/Accessories/AncientCoinRuby_AncientGoldCoinRuby_1_Color.png")
			icono_moneda.texture = tex_ruby
			icono_moneda.self_modulate = Color(1.0, 0.4, 0.4) # Tinte rojo
			
			if is_instance_valid(ScoreManager):
				ScoreManager.score_vivo_changed.connect(callback_vivo)
				_on_score_vivo_changed(ScoreManager.score_vivo)
	else:
		if es_fantasma:
			aplicar_estilo_fantasma()
		else:
			aplicar_estilo_jugador()

	if is_instance_valid(RedManager) and RedManager.es_un_jugador:
		if not is_instance_valid(boton_cambiar_personaje):
			_crear_hud_un_jugador()
		var rol_str = "fantasma" if es_fantasma else "jugador"
		_actualizar_boton_cambio(rol_str)

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
	_aplicar_estilo_textos_y_botones(self)
	
	var btn_interact = get_node_or_null("Area_Camara/Zona_Botones_Accion/Boton_Interactuar")
	if btn_interact and btn_interact.has_method("actualizar_estado_habilidad"):
		btn_interact.actualizar_estado_habilidad(false, 1.0)

func aplicar_estilo_fantasma():
	configurar_estilo_personaje(true)
	_aplicar_estilo_textos_y_botones(self)

func actualizar_boton_aura(activo: bool, progreso: float):
	var btn = get_node_or_null("Area_Camara/Zona_Botones_Accion/Boton_Interactuar")
	if btn and btn.has_method("actualizar_estado_habilidad"):
		btn.actualizar_estado_habilidad(activo, progreso)

func _aplicar_estilo_textos_y_botones(nodo: Node):
	var es_fantasma = false
	if is_instance_valid(_personaje_conectado):
		es_fantasma = _personaje_conectado.is_in_group("fantasmas") or _personaje_conectado.name.to_lower().contains("fantasma") or _personaje_conectado.has_node("HabilidadAura")
	elif is_instance_valid(RedManager) and RedManager.es_un_jugador:
		es_fantasma = (RedManager.personaje_activo_solo == "fantasma")
	
	var color_borde = Color(0.30, 0.82, 1.0, 0.88) if es_fantasma else Color(0.98, 0.78, 0.25, 0.88)
	var color_borde_hover = Color(0.50, 0.92, 1.0, 0.95) if es_fantasma else Color(1.0, 0.88, 0.4, 0.95)
	
	_estilar_nodo_recursivo(nodo, color_borde, color_borde_hover, es_fantasma)

func _estilar_nodo_recursivo(nodo: Node, color_borde: Color, color_borde_hover: Color, es_fantasma: bool = false):
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
		nodo.add_theme_color_override(&"font_hover_color", color_borde_hover)
		nodo.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
		nodo.add_theme_constant_override(&"outline_size", 6)
		
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.08, 0.16, 0.26, 0.88) if es_fantasma else Color(0.10, 0.12, 0.20, 0.90)
		style_normal.border_color = color_borde
		style_normal.border_width_left = 2
		style_normal.border_width_top = 2
		style_normal.border_width_right = 2
		style_normal.border_width_bottom = 2
		style_normal.set_corner_radius_all(12)
		if es_fantasma:
			style_normal.shadow_color = Color(0.1, 0.6, 0.9, 0.25)
			style_normal.shadow_size = 6
		
		var style_hover = style_normal.duplicate()
		style_hover.bg_color = Color(0.14, 0.26, 0.42, 0.92) if es_fantasma else Color(0.16, 0.20, 0.32, 0.95)
		style_hover.border_color = color_borde_hover
		
		var style_pressed = style_normal.duplicate()
		style_pressed.bg_color = Color(0.06, 0.12, 0.20, 0.95)
		style_pressed.border_color = color_borde
		
		nodo.add_theme_stylebox_override(&"normal", style_normal)
		nodo.add_theme_stylebox_override(&"hover", style_hover)
		nodo.add_theme_stylebox_override(&"pressed", style_pressed)
		nodo.add_theme_stylebox_override(&"focus", style_hover)

	elif nodo is Panel and (nodo.name == "Panel_Pausa" or nodo.name == "Panel_Opciones"):
		nodo.material = null
		var style_panel = StyleBoxFlat.new()
		style_panel.bg_color = Color(0.07, 0.14, 0.22, 0.94) if es_fantasma else Color(0.08, 0.10, 0.16, 0.92)
		style_panel.border_color = color_borde
		style_panel.border_width_left = 2
		style_panel.border_width_top = 2
		style_panel.border_width_right = 2
		style_panel.border_width_bottom = 2
		style_panel.set_corner_radius_all(16)
		style_panel.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
		style_panel.shadow_size = 16
		style_panel.shadow_offset = Vector2(0, 4)
		nodo.add_theme_stylebox_override(&"panel", style_panel)

	for hijo in nodo.get_children():
		_estilar_nodo_recursivo(hijo, color_borde, color_borde_hover, es_fantasma)



# --- Gestores de HUD: Menú de Pausa, Ajustes y Salida Segura ---

func _actualizar_visibilidad_elementos_juego() -> void:
	var bloq = esta_bloqueado_para_juego()
	var en_editor = has_node("AjusteHUD")
	
	if is_instance_valid(joystick):
		joystick.visible = !bloq
	var zona = get_node_or_null("Area_Camara/Zona_Botones_Accion")
	if is_instance_valid(zona):
		zona.visible = !en_editor
	var hud_puntuacion = get_node_or_null("HUD_Puntuacion")
	if is_instance_valid(hud_puntuacion):
		hud_puntuacion.visible = !en_editor
	var hud_menu = get_node_or_null("HUD_Menu")
	if is_instance_valid(hud_menu):
		hud_menu.visible = !en_editor

func _on_boton_pausa_pressed() -> void:
	var panel_p = get_node_or_null("Panel_Pausa")
	if panel_p:
		panel_p.visible = !panel_p.visible
		var panel_o = get_node_or_null("Panel_Opciones")
		if panel_o:
			panel_o.visible = false
	_actualizar_visibilidad_elementos_juego()
	print("[ControlesTactiles] Menú de Pausa alternado a: ", panel_p.visible if panel_p else false)

func _on_boton_continuar_pressed() -> void:
	var panel_p = get_node_or_null("Panel_Pausa")
	if panel_p:
		panel_p.visible = false
	_actualizar_visibilidad_elementos_juego()

func _on_boton_opciones_pressed() -> void:
	var panel_p = get_node_or_null("Panel_Pausa")
	var panel_o = get_node_or_null("Panel_Opciones")
	if panel_o:
		panel_o.visible = true
		_inicializar_controles_opciones_hud()
	if panel_p:
		panel_p.visible = false
	_actualizar_visibilidad_elementos_juego()
	print("[ControlesTactiles] Entrando a Ajustes (Ocultando Pausa)")

func _on_boton_cerrar_opciones_pressed() -> void:
	var panel_p = get_node_or_null("Panel_Pausa")
	var panel_o = get_node_or_null("Panel_Opciones")
	if panel_o:
		panel_o.visible = false
	if panel_p:
		panel_p.visible = true
	_actualizar_visibilidad_elementos_juego()
	print("[ControlesTactiles] Volviendo a Menú de Pausa (Ocultando Ajustes)")

func _inicializar_controles_opciones_hud() -> void:
	var slider_btn = get_node_or_null("Panel_Opciones/VBoxContainer/Slider_Escala_Botones")
	var slider_joy = get_node_or_null("Panel_Opciones/VBoxContainer/Slider_Escala_Joy")
	var cfg = HudConfigManager.cargar_config()
	
	if is_instance_valid(slider_btn):
		slider_btn.set_value_no_signal(cfg.get("botones_accion_scale", 1.39))
		if not slider_btn.value_changed.is_connected(_on_slider_escala_botones_changed):
			slider_btn.value_changed.connect(_on_slider_escala_botones_changed)
			
	if is_instance_valid(slider_joy):
		slider_joy.set_value_no_signal(cfg.get("joystick_scale", 1.0))
		if not slider_joy.value_changed.is_connected(_on_slider_escala_joy_changed):
			slider_joy.value_changed.connect(_on_slider_escala_joy_changed)

func _on_slider_escala_botones_changed(val: float) -> void:
	var cfg = HudConfigManager.cargar_config()
	cfg["botones_accion_scale"] = val
	HudConfigManager.guardar_config(cfg)
	HudConfigManager.aplicar_a_hud(self, cfg)

func _on_slider_escala_joy_changed(val: float) -> void:
	var cfg = HudConfigManager.cargar_config()
	cfg["joystick_scale"] = val
	HudConfigManager.guardar_config(cfg)
	HudConfigManager.aplicar_a_hud(self, cfg)

func _on_boton_personalizar_hud_pressed() -> void:
	var panel_o = get_node_or_null("Panel_Opciones")
	if panel_o:
		panel_o.visible = false
		
	var escena_editor = load("res://scenes/ui/ajuste_hud.tscn")
	if escena_editor:
		var editor = escena_editor.instantiate()
		add_child(editor)
		_actualizar_visibilidad_elementos_juego()
		editor.guardado.connect(func(nueva_cfg):
			HudConfigManager.aplicar_a_hud(self, nueva_cfg)
		)
		editor.cerrado.connect(func():
			if panel_o:
				panel_o.visible = true
			_inicializar_controles_opciones_hud()
			HudConfigManager.aplicar_a_hud(self)
			_actualizar_visibilidad_elementos_juego()
		)

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
