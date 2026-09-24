extends Control

@onready var joystick = $Joystick_Virtual
@onready var icono_moneda = $HUD_Puntuacion/Contenedor_Puntuacion/Icono_Moneda
@onready var texto_puntuacion = $HUD_Puntuacion/Contenedor_Puntuacion/Texto_Puntuacion

var arrastre_camara : Vector2 = Vector2.ZERO
var _personaje_conectado: Node
var joystick_dedo : int = -1
var camara_dedo : int = -1
var dedos_en_botones : Dictionary = {}
var _ultimo_delta_arrastre : Vector2 = Vector2.ZERO
var intro_nivel_en_progreso: bool = false
var _transicion_hud_tween: Tween = null

# Colores temáticos modernos (tonos sutiles, luminosos, elegantes y equilibrados)
const COLOR_VIVO_ACCENT: Color = Color(1.0, 0.96, 0.82, 1.0)          # Crema amarillento luminoso
const COLOR_VIVO_JOY_BASE: Color = Color(0.98, 0.95, 0.88, 0.92)      # Base joystick crema suave
const COLOR_VIVO_JOY_THUMB: Color = Color(1.0, 0.97, 0.90, 0.96)     # Palanca joystick crema luminoso
const COLOR_VIVO_BTN_MOD: Color = Color(1.0, 0.97, 0.90, 0.96)       # Botón pausa / elementos vivo
const COLOR_VIVO_PANEL_BG: Color = Color(0.10, 0.10, 0.12, 0.92)     # Fondo panel
const COLOR_VIVO_BORDER: Color = Color(0.95, 0.90, 0.75, 0.90)        # Borde panel vivo crema
const COLOR_VIVO_BORDER_HOVER: Color = Color(1.0, 0.96, 0.85, 0.95)

const COLOR_FANTASMA_ACCENT: Color = Color(0.60, 0.84, 1.0, 1.0)    # Azul cielo claro puro
const COLOR_FANTASMA_JOY_BASE: Color = Color(0.68, 0.86, 1.0, 0.92) # Base joystick azul claro
const COLOR_FANTASMA_JOY_THUMB: Color = Color(0.68, 0.86, 1.0, 0.95)# Palanca azul clara
const COLOR_FANTASMA_BTN_MOD: Color = Color(0.85, 0.93, 1.0, 0.96)  # Botón pausa / elementos fantasma
const COLOR_FANTASMA_PANEL_BG: Color = Color(0.06, 0.10, 0.18, 0.94)# Fondo panel azul noche
const COLOR_FANTASMA_BORDER: Color = Color(0.55, 0.84, 1.0, 0.90)   # Borde panel fantasma
const COLOR_FANTASMA_BORDER_HOVER: Color = Color(0.70, 0.90, 1.0, 0.95)

func _ready():
	add_to_group("ui_tactil")
	var es_fantasma_inicial = false
	if is_instance_valid(RedManager) and RedManager.es_un_jugador:
		es_fantasma_inicial = (RedManager.personaje_activo_solo == "fantasma")
	es_fantasma_ui = es_fantasma_inicial
	if es_fantasma_inicial:
		color_personaje_ui = COLOR_FANTASMA_ACCENT
	else:
		color_personaje_ui = COLOR_VIVO_ACCENT
		
	_inicializar_joystick()
	if has_node("HUD_Puntuacion"):
		$HUD_Puntuacion.visible = true
		$HUD_Puntuacion.modulate.a = 0.0
	_aplicar_estilo_textos_y_botones(self)
	_crear_indicador_ping()
	_crear_hud_un_jugador()
	HudConfigManager.aplicar_a_hud(self)
	_inicializar_controles_opciones_hud()
	
	var gm = _obtener_gamepad_manager()
	if is_instance_valid(gm):
		if not gm.control_conectado_cambiado.is_connected(_on_control_conectado_cambiado):
			gm.control_conectado_cambiado.connect(_on_control_conectado_cambiado)
		if not gm.modo_control_cambiado.is_connected(_on_modo_control_cambiado):
			gm.modo_control_cambiado.connect(_on_modo_control_cambiado)
	
	# Comprobar si el nivel actual tiene intro de capítulo activa para iniciar oculto
	var nivel_propietario = get_parent() as NivelBase
	if not nivel_propietario and get_tree() and get_tree().current_scene is NivelBase:
		nivel_propietario = get_tree().current_scene as NivelBase
		
	if is_instance_valid(nivel_propietario) and nivel_propietario.mostrar_intro_capitulo:
		ocultar_para_intro_nivel()
	else:
		_actualizar_visibilidad_elementos_juego()

var label_ping: Label = null
@onready var boton_cambiar_personaje: TouchScreenButton = get_node_or_null("Area_Camara/Zona_Botones_Accion/Boton_Cambiar_Personaje")
var overlay_transicion: ColorRect = null
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
	var es_fant = (destino == "fantasma")
	configurar_estilo_personaje(es_fant, true, duracion)
	_actualizar_boton_cambio(destino)
	_aplicar_estilo_textos_y_botones(self)

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

func _actualizar_boton_cambio(_personaje_activo: String) -> void:
	if not is_instance_valid(boton_cambiar_personaje):
		boton_cambiar_personaje = get_node_or_null("Area_Camara/Zona_Botones_Accion/Boton_Cambiar_Personaje")
	if is_instance_valid(boton_cambiar_personaje):
		boton_cambiar_personaje.queue_redraw()


const TEX_JOYSTICK_BASE = preload("res://assets/ui/controles/joystick_base.png")
const TEX_JOYSTICK_THUMB = preload("res://assets/ui/controles/joystick_thumb.png")
const RATIO_JOYSTICK_THUMB: float = 352.0 / 640.0

func _inicializar_joystick():
	if not joystick: return
	
	joystick.joystick_mode = 1 # JOYSTICK_DYNAMIC
	joystick.joystick_size = 200.0
	joystick.tip_size = joystick.joystick_size * RATIO_JOYSTICK_THUMB
	joystick.deadzone_ratio = 0.0
	joystick.clampzone_ratio = 1.0
	joystick.initial_offset_ratio = Vector2(0.3, 0.5)
	joystick.visibility_mode = 0 # VISIBILITY_ALWAYS
	
	joystick.action_left = &"mover_izquierda"
	joystick.action_right = &"mover_derecha"
	joystick.action_up = &"mover_adelante"
	joystick.action_down = &"mover_atras"
	
	_style_base = StyleBoxTexture.new()
	_style_base.texture = TEX_JOYSTICK_BASE
	
	_style_tip = StyleBoxTexture.new()
	_style_tip.texture = TEX_JOYSTICK_THUMB
	
	joystick.add_theme_stylebox_override(&"normal_joystick", _style_base)
	joystick.add_theme_stylebox_override(&"pressed_joystick", _style_base)
	joystick.add_theme_stylebox_override(&"normal_tip", _style_tip)
	joystick.add_theme_stylebox_override(&"pressed_tip", _style_tip)
	
	_actualizar_estilo_joystick(false)
	joystick.gui_input.connect(_on_joystick_gui_input)

var es_fantasma_ui: bool = false
var color_personaje_ui: Color = COLOR_VIVO_ACCENT
var _style_base: StyleBoxTexture = null
var _style_tip: StyleBoxTexture = null
var _joystick_tween: Tween = null

func obtener_color_ui() -> Color:
	return color_personaje_ui

func es_fantasma_actual() -> bool:
	return es_fantasma_ui

func configurar_estilo_personaje(es_fantasma: bool, con_transicion: bool = true, duracion: float = 0.45):
	es_fantasma_ui = es_fantasma
	color_personaje_ui = COLOR_FANTASMA_ACCENT if es_fantasma else COLOR_VIVO_ACCENT
	_actualizar_estilo_joystick(con_transicion, duracion)
	_redibujar_botones_accion()

func _actualizar_estilo_joystick(con_transicion: bool = true, duracion: float = 0.45):
	if not joystick or not _style_base or not _style_tip:
		return
	
	var es_fantasma = es_fantasma_ui
	var target_base = COLOR_FANTASMA_JOY_BASE if es_fantasma else COLOR_VIVO_JOY_BASE
	var target_tip = COLOR_FANTASMA_JOY_THUMB if es_fantasma else COLOR_VIVO_JOY_THUMB
	var target_btn_pausa = COLOR_FANTASMA_BTN_MOD if es_fantasma else COLOR_VIVO_BTN_MOD
	
	var btn_pausa = get_node_or_null("HUD_Menu/Boton_Pausa")
	
	if _joystick_tween and _joystick_tween.is_running():
		_joystick_tween.kill()
		
	if con_transicion:
		var t_trans = clampf(duracion * 0.75, 0.35, 1.2)
		_joystick_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_joystick_tween.tween_property(_style_base, "modulate_color", target_base, t_trans)
		_joystick_tween.tween_property(_style_tip, "modulate_color", target_tip, t_trans)
		if is_instance_valid(btn_pausa):
			_joystick_tween.tween_property(btn_pausa, "modulate", target_btn_pausa, t_trans)
	else:
		_style_base.modulate_color = target_base
		_style_tip.modulate_color = target_tip
		if is_instance_valid(btn_pausa):
			btn_pausa.modulate = target_btn_pausa
var _ultimo_tiempo_toque_camara : float = -10.0
var _ultima_pos_toque_camara : Vector2 = Vector2.ZERO
var _arrastre_acumulado_toque : float = 0.0
var _solicitud_centrado_camara : bool = false
const TIEMPO_DOBLE_TOQUE : float = 0.35
const DISTANCIA_MAX_DOBLE_TOQUE : float = 45.0

func _on_joystick_gui_input(event: InputEvent):
	if event is InputEventScreenTouch:
		if event.is_pressed():
			if joystick_dedo == -1:
				joystick_dedo = event.index
				if camara_dedo == event.index:
					camara_dedo = -1
		else:
			if joystick_dedo == event.index:
				joystick_dedo = -1
				Input.action_release("mover_izquierda")
				Input.action_release("mover_derecha")
				Input.action_release("mover_adelante")
				Input.action_release("mover_atras")
	elif event is InputEventScreenDrag:
		if joystick_dedo == -1:
			joystick_dedo = event.index

func esta_bloqueado_para_juego() -> bool:
	if intro_nivel_en_progreso:
		return true
	if not is_visible_in_tree():
		return true
	var panel_p = get_node_or_null("Panel_Pausa")
	if is_instance_valid(panel_p) and panel_p.visible:
		return true
	var panel_o = get_node_or_null("Panel_Opciones")
	if is_instance_valid(panel_o) and panel_o.visible:
		return true
	if has_node("AjusteHUD") or has_node("AjusteControl") or has_node("ModoFoto"):
		return true
	return false

func _esta_sobre_joystick(pos: Vector2) -> bool:
	if not is_instance_valid(joystick) or not joystick.is_visible_in_tree():
		return false
	var rect_joy = joystick.get_global_rect()
	if rect_joy.size.x > 0 and rect_joy.size.y > 0:
		return rect_joy.has_point(pos)
	var screen_sz = get_viewport_rect().size
	return Rect2(0, screen_sz.y * 0.4, screen_sz.x * 0.5, screen_sz.y * 0.6).has_point(pos)

func _obtener_boton_en_pos(pos: Vector2) -> Node:
	# 1. Comprobar botón de pausa / menú superior
	var btn_pausa = get_node_or_null("HUD_Menu/Boton_Pausa")
	if is_instance_valid(btn_pausa) and btn_pausa.is_visible_in_tree():
		if btn_pausa.get_global_rect().has_point(pos):
			return btn_pausa

	# 2. Comprobar botones táctiles de acción (Salto, Interactuar, Cambiar Personaje)
	var zona_botones = get_node_or_null("Area_Camara/Zona_Botones_Accion")
	if not is_instance_valid(zona_botones):
		zona_botones = find_child("Zona_Botones_Accion", true, false)

	if is_instance_valid(zona_botones) and zona_botones.is_visible_in_tree():
		var mejor_boton: Node = null
		var menor_dist: float = 1e9

		for hijo in zona_botones.get_children():
			if not hijo.is_visible_in_tree():
				continue
			if hijo is TouchScreenButton:
				var shape = hijo.shape
				if shape is CircleShape2D:
					var centro = hijo.global_position
					var radio = shape.radius * hijo.global_scale.x * 1.25 # Margen de contacto táctil
					var dist = pos.distance_to(centro)
					if dist <= radio and dist < menor_dist:
						menor_dist = dist
						mejor_boton = hijo
				elif shape is RectangleShape2D:
					var rect = Rect2(hijo.global_position - shape.size * 0.5 * hijo.global_scale, shape.size * hijo.global_scale)
					if rect.has_point(pos):
						var dist_c = pos.distance_to(hijo.global_position)
						if dist_c < menor_dist:
							menor_dist = dist_c
							mejor_boton = hijo
			elif hijo is Control:
				if hijo.get_global_rect().has_point(pos):
					var dist_c = pos.distance_to(hijo.global_position + hijo.size * 0.5)
					if dist_c < menor_dist:
						menor_dist = dist_c
						mejor_boton = hijo

		if mejor_boton != null:
			return mejor_boton

	return null

func _esta_sobre_boton(pos: Vector2) -> bool:
	return _obtener_boton_en_pos(pos) != null

func _ejecutar_accion_boton(boton: Node) -> void:
	if not is_instance_valid(boton) or not boton.is_visible_in_tree():
		return

	if boton is TouchScreenButton:
		var act = boton.action
		if act != "":
			Input.action_press(act)
			var ev_press = InputEventAction.new()
			ev_press.action = act
			ev_press.pressed = true
			Input.parse_input_event(ev_press)

			var timer = get_tree().create_timer(0.12)
			timer.timeout.connect(func():
				var ev_release = InputEventAction.new()
				ev_release.action = act
				ev_release.pressed = false
				Input.parse_input_event(ev_release)
				Input.action_release(act)
			)

		if boton.has_method("animar_pulsacion"):
			boton.animar_pulsacion()
		elif boton is CanvasItem:
			boton.queue_redraw()

		if boton == boton_cambiar_personaje:
			_on_btn_cambiar_personaje_pressed()

	elif boton is Button:
		if boton.name == "Boton_Pausa":
			_on_boton_pausa_pressed()
		else:
			boton.emit_signal("pressed")

func _input(event):
	if esta_bloqueado_para_juego():
		arrastre_camara = Vector2.ZERO
		camara_dedo = -1
		joystick_dedo = -1
		dedos_en_botones.clear()
		Input.action_release("mover_izquierda")
		Input.action_release("mover_derecha")
		Input.action_release("mover_adelante")
		Input.action_release("mover_atras")
		return

	var mitad_pantalla = get_viewport_rect().size.x * 0.5

	if event is InputEventScreenTouch:
		if event.is_pressed():
			# 1. Mitad izquierda: territorio exclusivo del Joystick / mano izquierda
			# La regla de movimiento de cámara NUNCA opera ni interviene aquí.
			if event.position.x < mitad_pantalla or _esta_sobre_joystick(event.position):
				if joystick_dedo == -1:
					joystick_dedo = event.index
				if camara_dedo == event.index:
					camara_dedo = -1
				return

			# 2. Mitad derecha: Toque inicial directo sobre un botón del HUD
			var boton = _obtener_boton_en_pos(event.position)
			if boton != null:
				dedos_en_botones[event.index] = boton
				_ultimo_tiempo_toque_camara = -10.0
				return

			# 3. Mitad derecha: Toque en área de cámara (movimiento y orientación con mano derecha)
			if camara_dedo == -1 and event.index != joystick_dedo:
				camara_dedo = event.index
				_arrastre_acumulado_toque = 0.0
				_ultimo_delta_arrastre = Vector2.ZERO

				var tiempo_actual = Time.get_ticks_msec() / 1000.0
				var delta_tiempo = tiempo_actual - _ultimo_tiempo_toque_camara
				var dist = event.position.distance_to(_ultima_pos_toque_camara)

				if delta_tiempo <= TIEMPO_DOBLE_TOQUE and dist <= DISTANCIA_MAX_DOBLE_TOQUE:
					# Doble toque rápido detectado en zona libre de la cámara
					_solicitud_centrado_camara = true
					_ultimo_tiempo_toque_camara = -10.0
				else:
					_ultimo_tiempo_toque_camara = tiempo_actual
					_ultima_pos_toque_camara = event.position
		else:
			# Dedo levantado / pantalla soltada
			if event.index == joystick_dedo:
				joystick_dedo = -1
				Input.action_release("mover_izquierda")
				Input.action_release("mover_derecha")
				Input.action_release("mover_adelante")
				Input.action_release("mover_atras")
				return

			if event.index in dedos_en_botones:
				dedos_en_botones.erase(event.index)
				return

			if event.index == camara_dedo:
				camara_dedo = -1

				if _arrastre_acumulado_toque > 25.0:
					_ultimo_tiempo_toque_camara = -10.0

				_ultimo_delta_arrastre = Vector2.ZERO
				_arrastre_acumulado_toque = 0.0
				get_viewport().set_input_as_handled()
				return

	elif event is InputEventScreenDrag:
		var mitad_pantalla_drag = get_viewport_rect().size.x * 0.5

		# 1. Ignorar si proviene del dedo del joystick para no interferir en su control
		if event.index == joystick_dedo:
			return

		# 2. Ignorar si es un dedo presionando un botón directamente
		if event.index in dedos_en_botones:
			return

		# 3. Arrastre de cámara existente (dedo ya asignado en la mitad derecha)
		if event.index == camara_dedo:
			# El arrastre de cámara continúa suavemente sin interrupción incluso sobre botones
			arrastre_camara += event.relative
			_arrastre_acumulado_toque += event.relative.length()
			_ultimo_delta_arrastre = event.relative
			get_viewport().set_input_as_handled()
			return

		# 4. Asignación si camara_dedo no estaba activo, SOLO si ocurre en la mitad derecha y no sobre botones
		if camara_dedo == -1 and event.position.x >= mitad_pantalla_drag and not _esta_sobre_boton(event.position - event.relative):
			camara_dedo = event.index
			arrastre_camara += event.relative
			_arrastre_acumulado_toque += event.relative.length()
			_ultimo_delta_arrastre = event.relative
			get_viewport().set_input_as_handled()
			return

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
			var tex_emerald = null
			if ResourceLoader.exists("res://assets/ui/iconos/moneda_esmeralda.png"):
				tex_emerald = load("res://assets/ui/iconos/moneda_esmeralda.png")
			elif ResourceLoader.exists("res://assets/modelos/provisional/RuinsGLB/Accessories/AncientCoinEmerald_AncientCoinEmerald_1_Color.png"):
				tex_emerald = load("res://assets/modelos/provisional/RuinsGLB/Accessories/AncientCoinEmerald_AncientCoinEmerald_1_Color.png")
			if tex_emerald:
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
			var tex_ruby = null
			if ResourceLoader.exists("res://assets/ui/iconos/moneda_rubi.png"):
				tex_ruby = load("res://assets/ui/iconos/moneda_rubi.png")
			elif ResourceLoader.exists("res://assets/modelos/provisional/RuinsGLB/Accessories/AncientCoinRuby_AncientGoldCoinRuby_1_Color.png"):
				tex_ruby = load("res://assets/modelos/provisional/RuinsGLB/Accessories/AncientCoinRuby_AncientGoldCoinRuby_1_Color.png")
			if tex_ruby:
				icono_moneda.texture = tex_ruby
			icono_moneda.self_modulate = Color(1.0, 0.4, 0.4) # Tinte rojo
			
			if is_instance_valid(ScoreManager):
				ScoreManager.score_vivo_changed.connect(callback_vivo)
				_on_score_vivo_changed(ScoreManager.score_vivo)
				
			if personaje.has_signal("estado_interaccion_actualizado"):
				var cb_vivo = Callable(self, "_on_vivo_interaccion_actualizado")
				if not personaje.estado_interaccion_actualizado.is_connected(cb_vivo):
					personaje.estado_interaccion_actualizado.connect(cb_vivo)
				if personaje.has_method("puede_interactuar"):
					actualizar_boton_vivo(personaje.puede_interactuar())
				else:
					actualizar_boton_vivo(false)
	else:
		if es_fantasma:
			aplicar_estilo_fantasma()
		else:
			aplicar_estilo_jugador()
			if personaje.has_signal("estado_interaccion_actualizado"):
				var cb_vivo = Callable(self, "_on_vivo_interaccion_actualizado")
				if not personaje.estado_interaccion_actualizado.is_connected(cb_vivo):
					personaje.estado_interaccion_actualizado.connect(cb_vivo)
				if personaje.has_method("puede_interactuar"):
					actualizar_boton_vivo(personaje.puede_interactuar())
				else:
					actualizar_boton_vivo(false)

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
	
	if is_instance_valid(texto_puntuacion):
		texto_puntuacion.add_theme_color_override(&"font_color", Color(1.0, 0.96, 0.88, 1.0))
		texto_puntuacion.add_theme_color_override(&"font_outline_color", Color(0.18, 0.12, 0.04, 0.95))
		
	var btn_interact = get_node_or_null("Area_Camara/Zona_Botones_Accion/Boton_Interactuar")
	if btn_interact and btn_interact.has_method("actualizar_estado_habilidad"):
		btn_interact.actualizar_estado_habilidad(false, 1.0)
		
	_redibujar_botones_accion()

func aplicar_estilo_fantasma():
	configurar_estilo_personaje(true)
	_aplicar_estilo_textos_y_botones(self)
	
	if is_instance_valid(texto_puntuacion):
		texto_puntuacion.add_theme_color_override(&"font_color", Color(0.90, 0.96, 1.0, 1.0))
		texto_puntuacion.add_theme_color_override(&"font_outline_color", Color(0.04, 0.10, 0.18, 0.95))
		
	_redibujar_botones_accion()

func _redibujar_botones_accion():
	var zona = get_node_or_null("Area_Camara/Zona_Botones_Accion")
	if is_instance_valid(zona):
		for hijo in zona.get_children():
			if hijo is CanvasItem:
				hijo.queue_redraw()

func actualizar_boton_aura(activo: bool, progreso: float):
	var btn = get_node_or_null("Area_Camara/Zona_Botones_Accion/Boton_Interactuar")
	if btn and btn.has_method("actualizar_estado_habilidad"):
		btn.actualizar_estado_habilidad(activo, progreso)

func _on_vivo_interaccion_actualizado(puede_interactuar: bool):
	actualizar_boton_vivo(puede_interactuar)

func actualizar_boton_vivo(puede_interactuar: bool):
	var btn = get_node_or_null("Area_Camara/Zona_Botones_Accion/Boton_Interactuar")
	if btn and btn.has_method("actualizar_estado_habilidad_vivo"):
		btn.actualizar_estado_habilidad_vivo(puede_interactuar)

func _aplicar_estilo_textos_y_botones(nodo: Node):
	var es_fantasma = es_fantasma_ui
	if is_instance_valid(_personaje_conectado):
		es_fantasma = _personaje_conectado.is_in_group("fantasmas") or _personaje_conectado.name.to_lower().contains("fantasma") or _personaje_conectado.has_node("HabilidadAura")
	elif is_instance_valid(RedManager) and RedManager.es_un_jugador:
		es_fantasma = (RedManager.personaje_activo_solo == "fantasma")
	
	var color_borde = COLOR_FANTASMA_BORDER if es_fantasma else COLOR_VIVO_BORDER
	var color_borde_hover = COLOR_FANTASMA_BORDER_HOVER if es_fantasma else COLOR_VIVO_BORDER_HOVER
	
	_estilar_nodo_recursivo(nodo, color_borde, color_borde_hover, es_fantasma)

func _estilar_nodo_recursivo(nodo: Node, color_borde: Color, color_borde_hover: Color, es_fantasma: bool = false):
	# Evitar procesar menús pausados u opciones si están ocultos durante el juego
	if (nodo.name == "Panel_Pausa" or nodo.name == "Panel_Opciones") and (nodo is CanvasItem and not (nodo as CanvasItem).visible):
		return
		
	if nodo is Label:
		nodo.add_theme_color_override(&"font_color", Color(1.0, 1.0, 1.0, 1.0))
		nodo.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
		nodo.add_theme_constant_override(&"outline_size", 8)
		nodo.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
		nodo.add_theme_constant_override(&"shadow_offset_x", 2)
		nodo.add_theme_constant_override(&"shadow_offset_y", 2)
		
	elif nodo is Button:
		if nodo.name == "Boton_Pausa":
			nodo.text = ""
			nodo.icon = preload("res://assets/ui/controles/boton_pausa.png")
			nodo.expand_icon = true
			nodo.custom_minimum_size = Vector2(110, 110)
			
			var style_p = StyleBoxEmpty.new()
			nodo.add_theme_stylebox_override(&"normal", style_p)
			nodo.add_theme_stylebox_override(&"hover", style_p)
			nodo.add_theme_stylebox_override(&"pressed", style_p)
			nodo.add_theme_stylebox_override(&"focus", style_p)
			
			nodo.modulate = COLOR_FANTASMA_BTN_MOD if es_fantasma else COLOR_VIVO_BTN_MOD
		else:
			nodo.material = null
			nodo.add_theme_color_override(&"font_color", Color(1.0, 1.0, 1.0, 1.0))
			nodo.add_theme_color_override(&"font_pressed_color", Color(0.9, 0.9, 0.9, 1.0))
			nodo.add_theme_color_override(&"font_hover_color", color_borde_hover)
			nodo.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
			nodo.add_theme_constant_override(&"outline_size", 6)
			
			if nodo.name == "Boton_Personalizar_HUD" or nodo.name == "Boton_Mapear_Control":
				nodo.add_theme_font_size_override(&"font_size", 20)
			elif nodo.name == "Boton_Reiniciar" or nodo.name == "Boton_Reiniciar_Nivel" or nodo.name == "Boton_Modo_Foto":
				nodo.add_theme_font_size_override(&"font_size", 21)
			else:
				nodo.add_theme_font_size_override(&"font_size", 22)
			
			var style_normal = StyleBoxFlat.new()
			style_normal.bg_color = COLOR_FANTASMA_PANEL_BG if es_fantasma else COLOR_VIVO_PANEL_BG
			style_normal.border_color = color_borde
			style_normal.border_width_left = 2
			style_normal.border_width_top = 2
			style_normal.border_width_right = 2
			style_normal.border_width_bottom = 2
			style_normal.set_corner_radius_all(14)
			style_normal.content_margin_top = 8
			style_normal.content_margin_bottom = 8
			style_normal.content_margin_left = 16
			style_normal.content_margin_right = 16
			if es_fantasma:
				style_normal.shadow_color = Color(0.1, 0.6, 0.9, 0.25)
				style_normal.shadow_size = 6
			else:
				style_normal.shadow_color = Color(0.5, 0.35, 0.1, 0.20)
				style_normal.shadow_size = 6
			
			var style_hover = style_normal.duplicate()
			style_hover.bg_color = Color(0.14, 0.26, 0.42, 0.92) if es_fantasma else Color(0.20, 0.18, 0.12, 0.95)
			style_hover.border_color = color_borde_hover
			
			var style_pressed = style_normal.duplicate()
			style_pressed.bg_color = Color(0.04, 0.08, 0.16, 0.95) if es_fantasma else Color(0.08, 0.07, 0.04, 0.95)
			style_pressed.border_color = color_borde
			
			nodo.add_theme_stylebox_override(&"normal", style_normal)
			nodo.add_theme_stylebox_override(&"hover", style_hover)
			nodo.add_theme_stylebox_override(&"pressed", style_pressed)
			nodo.add_theme_stylebox_override(&"focus", style_hover)

	elif nodo is Panel and (nodo.name == "Panel_Pausa" or nodo.name == "Panel_Opciones"):
		nodo.material = null
		var style_panel = StyleBoxFlat.new()
		style_panel.bg_color = COLOR_FANTASMA_PANEL_BG if es_fantasma else COLOR_VIVO_PANEL_BG
		style_panel.border_color = color_borde
		style_panel.border_width_left = 2
		style_panel.border_width_top = 2
		style_panel.border_width_right = 2
		style_panel.border_width_bottom = 2
		style_panel.set_corner_radius_all(20)
		style_panel.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
		style_panel.shadow_size = 22
		style_panel.shadow_offset = Vector2(0, 6)
		nodo.add_theme_stylebox_override(&"panel", style_panel)

	elif nodo is HSlider:
		nodo.custom_minimum_size.y = maxf(nodo.custom_minimum_size.y, 38.0)
		var style_slider_bg = StyleBoxFlat.new()
		style_slider_bg.bg_color = Color(0.12, 0.15, 0.22, 0.90) if es_fantasma else Color(0.18, 0.16, 0.12, 0.90)
		style_slider_bg.border_color = Color(0.3, 0.35, 0.45, 0.6) if es_fantasma else Color(0.4, 0.35, 0.25, 0.6)
		style_slider_bg.border_width_left = 1
		style_slider_bg.border_width_top = 1
		style_slider_bg.border_width_right = 1
		style_slider_bg.border_width_bottom = 1
		style_slider_bg.set_corner_radius_all(6)
		style_slider_bg.content_margin_top = 6
		style_slider_bg.content_margin_bottom = 6
		nodo.add_theme_stylebox_override(&"slider", style_slider_bg)
		
		var style_slider_area = StyleBoxFlat.new()
		style_slider_area.bg_color = color_borde
		style_slider_area.set_corner_radius_all(6)
		style_slider_area.content_margin_top = 6
		style_slider_area.content_margin_bottom = 6
		nodo.add_theme_stylebox_override(&"grabber_area", style_slider_area)
		nodo.add_theme_stylebox_override(&"grabber_area_highlight", style_slider_area)

	for hijo in nodo.get_children():
		_estilar_nodo_recursivo(hijo, color_borde, color_borde_hover, es_fantasma)



# --- Gestores de HUD: Menú de Pausa, Ajustes y Salida Segura ---

func _obtener_gamepad_manager() -> Node:
	if is_inside_tree() and get_tree() and get_tree().root:
		return get_tree().root.get_node_or_null("GamepadManager")
	return null

func ocultar_para_intro_nivel() -> void:
	intro_nivel_en_progreso = true
	visible = false
	modulate.a = 0.0
	
	if is_instance_valid(joystick):
		joystick.visible = false
		joystick.modulate.a = 0.0
	
	var zona = get_node_or_null("Area_Camara/Zona_Botones_Accion")
	if is_instance_valid(zona):
		zona.visible = false
		zona.modulate.a = 0.0
		
	var hud_menu = get_node_or_null("HUD_Menu")
	if is_instance_valid(hud_menu):
		hud_menu.visible = false
		hud_menu.modulate.a = 0.0
		
	var hud_puntuacion = get_node_or_null("HUD_Puntuacion")
	if is_instance_valid(hud_puntuacion):
		hud_puntuacion.visible = false
		hud_puntuacion.modulate.a = 0.0
		
	if is_instance_valid(label_ping) and is_instance_valid(label_ping.get_parent()):
		label_ping.get_parent().visible = false
		label_ping.get_parent().modulate.a = 0.0

func aparecer_con_transicion() -> void:
	intro_nivel_en_progreso = false
	
	if _transicion_hud_tween and _transicion_hud_tween.is_running():
		_transicion_hud_tween.kill()
		
	visible = true
	modulate.a = 1.0
	
	var cfg = HudConfigManager.cargar_config()
	var opacidad_final: float = cfg.get("hud_opacidad", 1.0)
	
	var gm = _obtener_gamepad_manager()
	var ocultar_tactil = is_instance_valid(gm) and gm.debe_ocultar_hud_tactil()
	
	var duracion: float = 0.5
	_transicion_hud_tween = create_tween().set_parallel(true)
	
	# 1. Transición del Joystick Virtual
	if is_instance_valid(joystick) and not ocultar_tactil:
		joystick.visible = true
		joystick.modulate.a = 0.0
		
		var screen_sz = get_viewport_rect().size
		var target_j_x: float = cfg.get("joystick_pos_ratio_x", 0.15) * screen_sz.x
		var target_j_y: float = cfg.get("joystick_pos_ratio_y", 0.75) * screen_sz.y
		joystick.pivot_offset = Vector2(target_j_x, target_j_y - screen_sz.y * 0.5)
		joystick.scale = Vector2(0.72, 0.72)
		
		_transicion_hud_tween.tween_property(joystick, "modulate:a", opacidad_final, duracion).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_transicion_hud_tween.tween_property(joystick, "scale", Vector2.ONE, duracion).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 2. Transición del Grupo de Botones de Acción (Salto, Interactuar, Cambiar)
	var zona = get_node_or_null("Area_Camara/Zona_Botones_Accion")
	if is_instance_valid(zona) and not ocultar_tactil:
		zona.visible = true
		zona.modulate.a = 0.0
		var escala_final_zona: float = cfg.get("botones_accion_scale", 1.39)
		var vec_escala_final = Vector2(escala_final_zona, escala_final_zona)
		
		zona.pivot_offset = Vector2(20, 20)
		zona.scale = vec_escala_final * 0.70
		
		_transicion_hud_tween.tween_property(zona, "modulate:a", opacidad_final, duracion).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_transicion_hud_tween.tween_property(zona, "scale", vec_escala_final, duracion).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 3. Transición del Botón de Pausa (HUD_Menu)
	var hud_menu = get_node_or_null("HUD_Menu")
	if is_instance_valid(hud_menu):
		hud_menu.visible = true
		hud_menu.modulate.a = 0.0
		hud_menu.pivot_offset = hud_menu.size * 0.5 if hud_menu.size != Vector2.ZERO else Vector2(55, 55)
		hud_menu.scale = Vector2(0.70, 0.70)
		
		_transicion_hud_tween.tween_property(hud_menu, "modulate:a", 1.0, duracion).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_transicion_hud_tween.tween_property(hud_menu, "scale", Vector2.ONE, duracion).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 4. Transición del Indicador de Ping
	if is_instance_valid(label_ping) and is_instance_valid(label_ping.get_parent()):
		var container_ping = label_ping.get_parent()
		container_ping.visible = true
		container_ping.modulate.a = 0.0
		_transicion_hud_tween.tween_property(container_ping, "modulate:a", 1.0, duracion).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# 5. El HUD de puntuación queda visible con alfa 0.0 para activarse con monedas
	var hud_puntuacion = get_node_or_null("HUD_Puntuacion")
	if is_instance_valid(hud_puntuacion):
		hud_puntuacion.visible = true
		hud_puntuacion.modulate.a = 0.0
	
	_transicion_hud_tween.chain().tween_callback(func():
		_actualizar_visibilidad_elementos_juego()
	)

func _actualizar_visibilidad_elementos_juego() -> void:
	var bloq = esta_bloqueado_para_juego()
	var en_editor = has_node("AjusteHUD") or has_node("AjusteControl") or has_node("ModoFoto")
	var gm = _obtener_gamepad_manager()
	var ocultar_por_control = is_instance_valid(gm) and gm.debe_ocultar_hud_tactil()
	
	var panel_p = get_node_or_null("Panel_Pausa")
	var panel_o = get_node_or_null("Panel_Opciones")
	var fondo_oscuro = get_node_or_null("Fondo_Oscuro")
	if is_instance_valid(fondo_oscuro):
		fondo_oscuro.visible = (panel_p != null and panel_p.visible) or (panel_o != null and panel_o.visible)
	
	if is_instance_valid(joystick):
		joystick.visible = not bloq and not ocultar_por_control
	var zona = get_node_or_null("Area_Camara/Zona_Botones_Accion")
	if is_instance_valid(zona):
		zona.visible = not bloq and not en_editor and not ocultar_por_control
	var hud_puntuacion = get_node_or_null("HUD_Puntuacion")
	if is_instance_valid(hud_puntuacion):
		hud_puntuacion.visible = not en_editor and not intro_nivel_en_progreso
	var hud_menu = get_node_or_null("HUD_Menu")
	if is_instance_valid(hud_menu):
		hud_menu.visible = not en_editor and not intro_nivel_en_progreso
	if is_instance_valid(label_ping) and is_instance_valid(label_ping.get_parent()):
		label_ping.get_parent().visible = not intro_nivel_en_progreso

func _on_control_conectado_cambiado(conectado: bool, _device_id: int) -> void:
	if conectado:
		joystick_dedo = -1
		camara_dedo = -1
		dedos_en_botones.clear()
		Input.action_release("mover_izquierda")
		Input.action_release("mover_derecha")
		Input.action_release("mover_adelante")
		Input.action_release("mover_atras")
		print("[ControlesTactiles] Control conectado -> Inicialmente ocultando controles en pantalla.")
	else:
		print("[ControlesTactiles] Control desconectado -> Restaurando controles en pantalla.")
	_actualizar_visibilidad_elementos_juego()

func _on_modo_control_cambiado(activo: bool) -> void:
	if activo:
		joystick_dedo = -1
		camara_dedo = -1
		dedos_en_botones.clear()
		Input.action_release("mover_izquierda")
		Input.action_release("mover_derecha")
		Input.action_release("mover_adelante")
		Input.action_release("mover_atras")
	_actualizar_visibilidad_elementos_juego()

func _unhandled_input(event: InputEvent) -> void:
	if has_node("ModoFoto"):
		return
		
	var panel_o = get_node_or_null("Panel_Opciones")
	var panel_p = get_node_or_null("Panel_Pausa")
	var ajuste_ctrl = get_node_or_null("AjusteControl")
	var ajuste_hud = get_node_or_null("AjusteHUD")
	
	var algun_menu_abierto = is_instance_valid(ajuste_ctrl) or is_instance_valid(ajuste_hud) or (is_instance_valid(panel_o) and panel_o.visible) or (is_instance_valid(panel_p) and panel_p.visible)
	
	# Botón B (ui_cancel) para Volver / Cancelar cuando un menú o pausa está abierto
	if algun_menu_abierto and (event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)):
		if is_instance_valid(ajuste_ctrl):
			ajuste_ctrl.cerrar()
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(ajuste_hud):
			ajuste_hud.queue_free()
			if is_instance_valid(panel_o):
				panel_o.visible = true
				_inicializar_controles_opciones_hud()
			_actualizar_visibilidad_elementos_juego()
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(panel_o) and panel_o.visible:
			_on_boton_cerrar_opciones_pressed()
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(panel_p) and panel_p.visible:
			_on_boton_continuar_pressed()
			get_viewport().set_input_as_handled()
			return

	# Botón Start / Escape (acción "pausa") para alternar pausa
	if event.is_action_pressed("pausa"):
		if is_instance_valid(ajuste_ctrl):
			ajuste_ctrl.cerrar()
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(ajuste_hud):
			ajuste_hud.queue_free()
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(panel_o) and panel_o.visible:
			_on_boton_cerrar_opciones_pressed()
			get_viewport().set_input_as_handled()
			return
			
		_on_boton_pausa_pressed()
		get_viewport().set_input_as_handled()

func _on_boton_pausa_pressed() -> void:
	var panel_p = get_node_or_null("Panel_Pausa")
	if panel_p:
		panel_p.visible = !panel_p.visible
		var panel_o = get_node_or_null("Panel_Opciones")
		if panel_o:
			panel_o.visible = false
		if panel_p.visible:
			_aplicar_estilo_textos_y_botones(panel_p)
			var btn_cont = panel_p.get_node_or_null("VBoxContainer/Boton_Continuar")
			var gm = _obtener_gamepad_manager()
			if is_instance_valid(btn_cont) and is_instance_valid(gm) and gm.hay_control_conectado():
				btn_cont.grab_focus()
	_actualizar_visibilidad_elementos_juego()
	print("[ControlesTactiles] Menú de Pausa alternado a: ", panel_p.visible if panel_p else false)

func _on_boton_continuar_pressed() -> void:
	var panel_p = get_node_or_null("Panel_Pausa")
	if panel_p:
		panel_p.visible = false
	_actualizar_visibilidad_elementos_juego()

func _on_boton_reiniciar_pressed() -> void:
	var panel_p = get_node_or_null("Panel_Pausa")
	if panel_p:
		panel_p.visible = false
	_actualizar_visibilidad_elementos_juego()
	
	# Reiniciar ÚNICAMENTE al personaje activo actual (no a ambos personajes)
	var pj_activo: Node = null
	if is_instance_valid(_personaje_conectado) and _personaje_conectado.has_method("reaparecer"):
		pj_activo = _personaje_conectado
	else:
		var jugadores = get_tree().get_nodes_in_group("jugadores")
		if jugadores.is_empty():
			var escena = get_tree().current_scene
			if escena:
				var pj_vivo = escena.find_child("Jugador", true, false)
				if pj_vivo: jugadores.append(pj_vivo)
				var pj_fant = escena.find_child("Fantasma", true, false)
				if pj_fant: jugadores.append(pj_fant)
		for pj in jugadores:
			if pj.has_method("es_activo") and pj.es_activo():
				pj_activo = pj
				break
				
	if is_instance_valid(pj_activo) and pj_activo.has_method("reaparecer"):
		pj_activo.reaparecer()
		print("[ControlesTactiles] Solo el personaje activo (%s) fue reiniciado a su punto de control." % pj_activo.name)

func _on_boton_reiniciar_nivel_pressed() -> void:
	var panel_p = get_node_or_null("Panel_Pausa")
	if panel_p:
		panel_p.visible = false
	_actualizar_visibilidad_elementos_juego()
	
	print("[ControlesTactiles] Reiniciando nivel completo...")
	if is_instance_valid(RedManager) and RedManager.has_method("reintentar_nivel_actual"):
		RedManager.reintentar_nivel_actual()
	else:
		get_tree().reload_current_scene()

func _on_boton_modo_foto_pressed() -> void:
	var panel_p = get_node_or_null("Panel_Pausa")
	if panel_p:
		panel_p.visible = false
	_actualizar_visibilidad_elementos_juego()
	
	var escena_foto = load("res://scenes/ui/modo_foto.tscn")
	if escena_foto:
		var modo_foto = escena_foto.instantiate()
		modo_foto.name = "ModoFoto"
		add_child(modo_foto)
		_actualizar_visibilidad_elementos_juego()
		modo_foto.cerrado.connect(func():
			if is_instance_valid(panel_p):
				panel_p.visible = true
				var gm = _obtener_gamepad_manager()
				if is_instance_valid(gm) and gm.hay_control_conectado():
					var btn_foto = panel_p.get_node_or_null("VBoxContainer/Boton_Modo_Foto")
					if is_instance_valid(btn_foto):
						btn_foto.grab_focus()
			_actualizar_visibilidad_elementos_juego()
		)
	print("[ControlesTactiles] Modo Foto activado.")

func _on_boton_opciones_pressed() -> void:
	var panel_p = get_node_or_null("Panel_Pausa")
	var panel_o = get_node_or_null("Panel_Opciones")
	if panel_o:
		panel_o.visible = true
		_aplicar_estilo_textos_y_botones(panel_o)
		_inicializar_controles_opciones_hud()
		var gm = _obtener_gamepad_manager()
		if is_instance_valid(gm) and gm.hay_control_conectado():
			var btn_hud = panel_o.get_node_or_null("VBoxContainer/Boton_Personalizar_HUD")
			if is_instance_valid(btn_hud):
				btn_hud.grab_focus()
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
		var gm = _obtener_gamepad_manager()
		if is_instance_valid(gm) and gm.hay_control_conectado():
			var btn_opc = panel_p.get_node_or_null("VBoxContainer/Boton_Opciones")
			if is_instance_valid(btn_opc):
				btn_opc.grab_focus()
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
			
	_actualizar_texto_boton_vibracion()
	_actualizar_texto_boton_fps()

func _on_boton_vibracion_pressed() -> void:
	if is_instance_valid(VibrationManager):
		var nuevo_estado = not VibrationManager.esta_habilitada()
		VibrationManager.establecer_habilitada(nuevo_estado)
		_actualizar_texto_boton_vibracion()
		if nuevo_estado:
			VibrationManager.vibrar(60, 0.5, 0.2, 0.12)

func _actualizar_texto_boton_vibracion() -> void:
	var btn_vib = get_node_or_null("Panel_Opciones/VBoxContainer/Boton_Vibracion")
	if is_instance_valid(btn_vib) and is_instance_valid(VibrationManager):
		var activa = VibrationManager.esta_habilitada()
		btn_vib.text = "📳 Vibración: Activada" if activa else "📳 Vibración: Desactivada"

func _on_boton_fps_pressed() -> void:
	var fps_node = get_node_or_null("/root/FPSCounter")
	if is_instance_valid(fps_node):
		fps_node.alternar()
		_actualizar_texto_boton_fps()

func _actualizar_texto_boton_fps() -> void:
	var btn_fps = get_node_or_null("Panel_Opciones/VBoxContainer/Boton_FPS")
	var fps_node = get_node_or_null("/root/FPSCounter")
	if is_instance_valid(btn_fps) and is_instance_valid(fps_node):
		var activa = fps_node.esta_activo()
		btn_fps.text = "📊 Mostrar FPS: Activado" if activa else "📊 Mostrar FPS: Desactivado"

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

func _on_boton_mapear_control_pressed() -> void:
	var panel_o = get_node_or_null("Panel_Opciones")
	if panel_o:
		panel_o.visible = false
		
	var escena_ctrl = load("res://scenes/ui/ajuste_control.tscn")
	if escena_ctrl:
		var ctrl_modal = escena_ctrl.instantiate()
		add_child(ctrl_modal)
		_actualizar_visibilidad_elementos_juego()
		ctrl_modal.cerrado.connect(func():
			if panel_o:
				panel_o.visible = true
				var btn_map = panel_o.get_node_or_null("VBoxContainer/Boton_Mapear_Control")
				if is_instance_valid(btn_map):
					btn_map.grab_focus()
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
