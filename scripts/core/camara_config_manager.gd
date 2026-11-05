@tool
extends Node

## ==============================================================================
## CAMARA CONFIG MANAGER (PROYECTO LIMBO)
## Gestor global persistente para la configuración de cámara y modos de video.
## Incluye soporte especializado para grabación en formato vertical 9:16
## (YouTube Shorts, TikTok, Instagram Reels) sin perder encuadre del personaje.
## Persiste la configuración en user://opciones.cfg.
## ==============================================================================

signal modo_shorts_cambiado(activo: bool)
signal guia_shorts_cambiada(activa: bool)
signal ocultar_controles_cambiado(activo: bool)
signal escala_render_cambiada(escala: float)
signal limite_fps_cambiado(fps: int)
signal distancia_camara_cambiada(nueva_distancia: float)
signal altura_camara_cambiada(nueva_altura: float)
signal camara_estatica_cambiada(activa: bool)
signal ajustes_camara_revertidos()
signal boton_rapido_hud_cambiado(activo: bool)

const CONFIG_PATH = "user://opciones.cfg"
const SECTION_CAMARA = "camara"
const KEY_MODO_SHORTS = "modo_shorts"
const KEY_MOSTRAR_GUIA = "mostrar_guia_shorts"
const KEY_OCULTAR_CONTROLES = "ocultar_controles_grabacion"
const KEY_ESCALA_RENDER = "escala_render"
const KEY_LIMITE_FPS = "limite_fps"
const KEY_DISTANCIA_CAMARA = "distancia_camara"
const KEY_ALTURA_CAMARA = "altura_camara"
const KEY_BOTON_RAPIDO_HUD = "boton_rapido_hud"

const OPCIONES_ESCALA: Array[float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
const OPCIONES_FPS: Array[int] = [30, 60, 90, 120]

# Parámetros Predeterminados de Cámara (Formato Vertical Shorts 9:16)
# - Altura SpringArm (0.65m) para elevar el personaje al tercio superior / centro seguro.
# - Distancia de cámara (5.2m) alejada para un encuadre amplio donde se aprecie el entorno y plataformas.
# - Pitch por defecto (-0.22 rad / ~ -12.6°) para visualizar claramente el suelo y plataformas debajo.
# - Desplazamiento vertical (-0.15m) asegurando que el personaje no quede tapado por los subtítulos o botones de Shorts/TikTok.
const ALTURA_SPRING_ARM: float = 0.65
const DISTANCIA_CAMARA: float = 5.2
const PITCH_DEFECTO: float = -0.22
const V_OFFSET: float = -0.15
const LIMITE_PITCH_MIN: float = -0.75
const LIMITE_PITCH_MAX: float = 0.25

# Constantes predeterminadas y rangos de ajuste libre
const DISTANCIA_CAMARA_DEFECTO: float = 5.2
const ALTURA_SPRING_ARM_DEFECTO: float = 0.65
const DISTANCIA_MIN: float = 1.8
const DISTANCIA_MAX: float = 12.0
const ALTURA_MIN: float = -1.0
const ALTURA_MAX: float = 3.5

# Aliases de compatibilidad
const ALTURA_SPRING_ARM_SHORTS: float = ALTURA_SPRING_ARM
const DISTANCIA_CAMARA_SHORTS: float = DISTANCIA_CAMARA
const PITCH_DEFECTO_SHORTS: float = PITCH_DEFECTO
const V_OFFSET_SHORTS: float = V_OFFSET
const LIMITE_PITCH_MIN_SHORTS: float = LIMITE_PITCH_MIN
const LIMITE_PITCH_MAX_SHORTS: float = LIMITE_PITCH_MAX

var _modo_shorts: bool = true
var _mostrar_guia: bool = false
var _ocultar_controles: bool = false
var _escala_render: float = 1.0
var _limite_fps: int = 60

# Ajustes dinámicos de encuadre durante el gameplay
var _distancia_camara: float = DISTANCIA_CAMARA_DEFECTO
var _altura_spring_arm: float = ALTURA_SPRING_ARM_DEFECTO
var _camara_estatica: bool = false
var _pos_camara_estatica: Vector3 = Vector3.ZERO
var _rot_camara_estatica: Vector3 = Vector3.ZERO
var _rot_x_arm_estatica: float = 0.0
var _mostrar_boton_rapido_hud: bool = false

# Nodos de la guía visual 9:16
var _capa_guia: CanvasLayer = null
var _overlay_guia: Control = null

# Toast de notificaciones de cámara en pantalla
var _capa_toast: CanvasLayer = null
var _panel_toast: PanelContainer = null
var _label_toast: Label = null
var _tween_toast: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Engine.is_editor_hint():
		_construir_guia_visual()
		_construir_toast_notificaciones()
	cargar_config()

# -----------------------------------------------------------------------------
# CONSULTAS Y CONTROL DE MODO SHORTS
# -----------------------------------------------------------------------------
func esta_modo_shorts_activo() -> bool:
	return true

func establecer_modo_shorts(_activo: bool) -> void:
	pass

func alternar_modo_shorts() -> bool:
	return true

# -----------------------------------------------------------------------------
# CONSULTAS Y CONTROL DE GUÍA VISUAL 9:16
# -----------------------------------------------------------------------------
func esta_guia_activa() -> bool:
	return _mostrar_guia

func establecer_guia_activa(activa: bool) -> void:
	if _mostrar_guia != activa:
		_mostrar_guia = activa
		guardar_config()
		_actualizar_visibilidad_guia()
		guia_shorts_cambiada.emit(_mostrar_guia)
		print("[CamaraConfigManager] Guía visual 9:16 establecida en: ", _mostrar_guia)

func alternar_guia() -> bool:
	establecer_guia_activa(!_mostrar_guia)
	return _mostrar_guia

# -----------------------------------------------------------------------------
# CONSULTAS Y CONTROL DE OCULTAR CONTROLES (EXCEPTO PAUSA)
# -----------------------------------------------------------------------------
func esta_ocultar_controles_activo() -> bool:
	return _ocultar_controles

func establecer_ocultar_controles(activo: bool) -> void:
	if _ocultar_controles != activo:
		_ocultar_controles = activo
		guardar_config()
		ocultar_controles_cambiado.emit(_ocultar_controles)
		print("[CamaraConfigManager] Ocultar controles (excepto pausa): ", _ocultar_controles)

func alternar_ocultar_controles() -> bool:
	establecer_ocultar_controles(!_ocultar_controles)
	return _ocultar_controles

# -----------------------------------------------------------------------------
# CONSULTAS Y CONTROL DE ESCALA DE RENDERIZADO 3D
# -----------------------------------------------------------------------------
func obtener_escala_render() -> float:
	return _escala_render

func aplicar_escala_render(nueva_escala: float) -> void:
	_escala_render = nueva_escala
	var vp = get_viewport()
	if vp:
		vp.scaling_3d_scale = _escala_render
	var tree = get_tree()
	if tree and tree.root and tree.root != vp:
		tree.root.scaling_3d_scale = _escala_render
	escala_render_cambiada.emit(_escala_render)
	print("[CamaraConfigManager] Escala de renderizado 3D aplicada: ", _escala_render)

func establecer_escala_render(valor: float) -> void:
	_escala_render = valor
	aplicar_escala_render(_escala_render)
	guardar_config()

func alternar_escala_render() -> float:
	var idx = -1
	for i in range(OPCIONES_ESCALA.size()):
		if is_equal_approx(OPCIONES_ESCALA[i], _escala_render):
			idx = i
			break
	if idx == -1:
		idx = 2 # Por defecto 1.0 (Nativa)
	idx = (idx + 1) % OPCIONES_ESCALA.size()
	establecer_escala_render(OPCIONES_ESCALA[idx])
	return _escala_render

func obtener_texto_escala_render() -> String:
	if is_equal_approx(_escala_render, 0.5):
		return "🔍 Escala 3D: 50% (Rendimiento)"
	elif is_equal_approx(_escala_render, 0.75):
		return "🔍 Escala 3D: 75% (Equilibrado)"
	elif is_equal_approx(_escala_render, 1.0):
		return "🔍 Escala 3D: 100% (Nativa)"
	elif is_equal_approx(_escala_render, 1.25):
		return "🔍 Escala 3D: 125% (Alta)"
	elif is_equal_approx(_escala_render, 1.5):
		return "🔍 Escala 3D: 150% (2K / Calidad)"
	elif is_equal_approx(_escala_render, 2.0):
		return "🔍 Escala 3D: 200% (4K / Supermuestreo)"
	else:
		return "🔍 Escala 3D: %d%%" % int(_escala_render * 100.0)

# -----------------------------------------------------------------------------
# CONSULTAS Y CONTROL DE LÍMITE DE FPS
# -----------------------------------------------------------------------------
func obtener_limite_fps() -> int:
	return _limite_fps

func aplicar_limite_fps(nuevo_fps: int) -> void:
	_limite_fps = nuevo_fps
	Engine.max_fps = _limite_fps
	limite_fps_cambiado.emit(_limite_fps)
	print("[CamaraConfigManager] Límite de FPS aplicado: ", _limite_fps)

func establecer_limite_fps(valor: int) -> void:
	_limite_fps = valor
	aplicar_limite_fps(_limite_fps)
	guardar_config()

func alternar_limite_fps() -> int:
	var idx = OPCIONES_FPS.find(_limite_fps)
	if idx == -1:
		idx = 1 # Por defecto 60 FPS
	idx = (idx + 1) % OPCIONES_FPS.size()
	establecer_limite_fps(OPCIONES_FPS[idx])
	return _limite_fps

func obtener_texto_limite_fps() -> String:
	if _limite_fps <= 0:
		return "⚡ Límite de FPS: Ilimitado"
	return "⚡ Límite de FPS: %d FPS" % _limite_fps

# -----------------------------------------------------------------------------
# PARÁMETROS DINÁMICOS DE CÁMARA (AJUSTES LIBRES DURANTE EL GAMEPLAY)
# -----------------------------------------------------------------------------
func obtener_altura_spring_arm() -> float:
	return _altura_spring_arm

func establecer_altura_camara(valor: float) -> void:
	var v_clamp = clampf(valor, ALTURA_MIN, ALTURA_MAX)
	if not is_equal_approx(_altura_spring_arm, v_clamp):
		_altura_spring_arm = v_clamp
		guardar_config()
		altura_camara_cambiada.emit(_altura_spring_arm)
		print("[CamaraConfigManager] Altura de cámara establecida en: ", _altura_spring_arm)

func modificar_altura_camara(delta_alt: float) -> float:
	establecer_altura_camara(_altura_spring_arm + delta_alt)
	return _altura_spring_arm

func obtener_distancia_camara() -> float:
	return _distancia_camara

func establecer_distancia_camara(valor: float) -> void:
	var v_clamp = clampf(valor, DISTANCIA_MIN, DISTANCIA_MAX)
	if not is_equal_approx(_distancia_camara, v_clamp):
		_distancia_camara = v_clamp
		guardar_config()
		distancia_camara_cambiada.emit(_distancia_camara)
		print("[CamaraConfigManager] Distancia de cámara establecida en: ", _distancia_camara)

func modificar_distancia_camara(delta_dist: float) -> float:
	establecer_distancia_camara(_distancia_camara + delta_dist)
	return _distancia_camara

func obtener_pitch_defecto() -> float:
	return PITCH_DEFECTO

func obtener_v_offset() -> float:
	return V_OFFSET

func obtener_limite_pitch_min() -> float:
	return LIMITE_PITCH_MIN

func obtener_limite_pitch_max() -> float:
	return LIMITE_PITCH_MAX

# -----------------------------------------------------------------------------
# CÁMARA ESTÁTICA / PUNTO FIJO PARA TOMAS DE SHORTS
# -----------------------------------------------------------------------------
func esta_camara_estatica() -> bool:
	return _camara_estatica

func fijar_camara_estatica(pos: Vector3, rot: Vector3, rot_x_arm: float = 0.0) -> void:
	_pos_camara_estatica = pos
	_rot_camara_estatica = rot
	_rot_x_arm_estatica = rot_x_arm
	_camara_estatica = true
	camara_estatica_cambiada.emit(true)
	print("[CamaraConfigManager] Cámara estática fijada en: ", pos, " rot: ", rot)

func desactivar_camara_estatica() -> void:
	if _camara_estatica:
		_camara_estatica = false
		camara_estatica_cambiada.emit(false)
		print("[CamaraConfigManager] Cámara estática desactivada, retornando a seguimiento de personaje.")

func establecer_camara_estatica(activa: bool) -> void:
	if activa:
		if not _camara_estatica:
			alternar_camara_estatica()
	else:
		if _camara_estatica:
			desactivar_camara_estatica()

func alternar_camara_estatica() -> bool:
	if _camara_estatica:
		desactivar_camara_estatica()
		return false
	else:
		var pos = Vector3.ZERO
		var rot = Vector3.ZERO
		var rot_arm = 0.0
		var pj = _obtener_personaje_activo()
		if is_instance_valid(pj) and pj.has_method("obtener_pivote_camara"):
			var pivote = pj.obtener_pivote_camara()
			if is_instance_valid(pivote):
				pos = pivote.global_position
				rot = pivote.rotation
				var arm = pj.obtener_spring_arm() if pj.has_method("obtener_spring_arm") else null
				if is_instance_valid(arm):
					rot_arm = arm.rotation.x
		else:
			var vp = get_viewport()
			if vp:
				var cam = vp.get_camera_3d()
				if is_instance_valid(cam):
					pos = cam.global_position
					rot = cam.global_rotation
		fijar_camara_estatica(pos, rot, rot_arm)
		return true

func obtener_posicion_camara_estatica() -> Vector3:
	return _pos_camara_estatica

func obtener_rotacion_camara_estatica() -> Vector3:
	return _rot_camara_estatica

func obtener_rot_x_arm_estatica() -> float:
	return _rot_x_arm_estatica

func establecer_posicion_camara_estatica(nueva_pos: Vector3) -> void:
	_pos_camara_estatica = nueva_pos

func mover_posicion_camara_estatica(delta_mundo: Vector3) -> void:
	_pos_camara_estatica += delta_mundo

func establecer_rotacion_camara_estatica(nueva_rot: Vector3) -> void:
	_rot_camara_estatica = nueva_rot

func establecer_rot_x_arm_estatica(nuevo_pitch: float) -> void:
	_rot_x_arm_estatica = clampf(nuevo_pitch, LIMITE_PITCH_MIN, LIMITE_PITCH_MAX)

func esta_boton_rapido_hud_activo() -> bool:
	return _mostrar_boton_rapido_hud

func establecer_boton_rapido_hud(activo: bool) -> void:
	if _mostrar_boton_rapido_hud != activo:
		_mostrar_boton_rapido_hud = activo
		guardar_config()
		boton_rapido_hud_cambiado.emit(_mostrar_boton_rapido_hud)

func alternar_boton_rapido_hud() -> bool:
	establecer_boton_rapido_hud(!_mostrar_boton_rapido_hud)
	return _mostrar_boton_rapido_hud

func revertir_ajustes_camara() -> void:
	_distancia_camara = DISTANCIA_CAMARA_DEFECTO
	_altura_spring_arm = ALTURA_SPRING_ARM_DEFECTO
	_camara_estatica = false
	guardar_config()
	distancia_camara_cambiada.emit(_distancia_camara)
	altura_camara_cambiada.emit(_altura_spring_arm)
	camara_estatica_cambiada.emit(false)
	ajustes_camara_revertidos.emit()
	print("[CamaraConfigManager] Ajustes de cámara revertidos a valores predeterminados (dist: 5.2, alt: 0.65, estatica: false).")

func es_configuracion_por_defecto() -> bool:
	return is_equal_approx(_distancia_camara, DISTANCIA_CAMARA_DEFECTO) \
		and is_equal_approx(_altura_spring_arm, ALTURA_SPRING_ARM_DEFECTO) \
		and not _camara_estatica

func _obtener_personaje_activo() -> Node:
	var tree = get_tree()
	if not tree:
		return null
	var jugadores = tree.get_nodes_in_group("jugadores")
	for pj in jugadores:
		if pj.has_method("es_activo") and pj.es_activo():
			return pj
	if jugadores.size() > 0:
		return jugadores[0]
	var escena = tree.current_scene
	if escena:
		var j = escena.find_child("Jugador", true, false)
		if is_instance_valid(j):
			return j
		var f = escena.find_child("Fantasma", true, false)
		if is_instance_valid(f):
			return f
	return null

# -----------------------------------------------------------------------------
# PERSISTENCIA DE CONFIGURACIÓN (user://opciones.cfg)
# -----------------------------------------------------------------------------
func cargar_config() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(CONFIG_PATH)
	if err == OK:
		if cfg.has_section(SECTION_CAMARA):
			_modo_shorts = cfg.get_value(SECTION_CAMARA, KEY_MODO_SHORTS, false)
			_mostrar_guia = cfg.get_value(SECTION_CAMARA, KEY_MOSTRAR_GUIA, false)
			_ocultar_controles = cfg.get_value(SECTION_CAMARA, KEY_OCULTAR_CONTROLES, false)
			_distancia_camara = cfg.get_value(SECTION_CAMARA, KEY_DISTANCIA_CAMARA, DISTANCIA_CAMARA_DEFECTO)
			_altura_spring_arm = cfg.get_value(SECTION_CAMARA, KEY_ALTURA_CAMARA, ALTURA_SPRING_ARM_DEFECTO)
			_mostrar_boton_rapido_hud = cfg.get_value(SECTION_CAMARA, KEY_BOTON_RAPIDO_HUD, false)
		elif cfg.has_section("video") and cfg.has_section_key("video", KEY_MODO_SHORTS):
			_modo_shorts = cfg.get_value("video", KEY_MODO_SHORTS, false)
			_mostrar_guia = cfg.get_value("video", KEY_MOSTRAR_GUIA, false)
			_ocultar_controles = cfg.get_value("video", KEY_OCULTAR_CONTROLES, false)
			_distancia_camara = cfg.get_value("video", KEY_DISTANCIA_CAMARA, DISTANCIA_CAMARA_DEFECTO)
			_altura_spring_arm = cfg.get_value("video", KEY_ALTURA_CAMARA, ALTURA_SPRING_ARM_DEFECTO)
		_escala_render = cfg.get_value("video", KEY_ESCALA_RENDER, 1.0)
		_limite_fps = cfg.get_value("video", KEY_LIMITE_FPS, 60)
	else:
		_modo_shorts = false
		_mostrar_guia = false
		_ocultar_controles = false
		_distancia_camara = DISTANCIA_CAMARA_DEFECTO
		_altura_spring_arm = ALTURA_SPRING_ARM_DEFECTO
		_mostrar_boton_rapido_hud = false
		_escala_render = 1.0
		_limite_fps = 60
	
	if OS.has_feature("mobile") or OS.get_name() in ["Android", "iOS"]:
		if _escala_render > 1.0:
			_escala_render = 1.0
		if _limite_fps > 60:
			_limite_fps = 60
	aplicar_escala_render(_escala_render)
	aplicar_limite_fps(_limite_fps)
	_actualizar_visibilidad_guia()

func guardar_config() -> void:
	var cfg = ConfigFile.new()
	var _err = cfg.load(CONFIG_PATH)
	cfg.set_value(SECTION_CAMARA, KEY_MODO_SHORTS, _modo_shorts)
	cfg.set_value(SECTION_CAMARA, KEY_MOSTRAR_GUIA, _mostrar_guia)
	cfg.set_value(SECTION_CAMARA, KEY_OCULTAR_CONTROLES, _ocultar_controles)
	cfg.set_value(SECTION_CAMARA, KEY_DISTANCIA_CAMARA, _distancia_camara)
	cfg.set_value(SECTION_CAMARA, KEY_ALTURA_CAMARA, _altura_spring_arm)
	cfg.set_value(SECTION_CAMARA, KEY_BOTON_RAPIDO_HUD, _mostrar_boton_rapido_hud)
	# Guardar también en sección video para consistencia con menus de video
	cfg.set_value("video", KEY_MODO_SHORTS, _modo_shorts)
	cfg.set_value("video", KEY_OCULTAR_CONTROLES, _ocultar_controles)
	cfg.set_value("video", KEY_ESCALA_RENDER, _escala_render)
	cfg.set_value("video", KEY_LIMITE_FPS, _limite_fps)
	var save_err = cfg.save(CONFIG_PATH)
	if save_err == OK:
		print("[CamaraConfigManager] Configuración de video guardada en: ", CONFIG_PATH)

# -----------------------------------------------------------------------------
# GUÍA VISUAL EN PANTALLA (OVERLAY 9:16)
# -----------------------------------------------------------------------------
func _construir_guia_visual() -> void:
	_capa_guia = CanvasLayer.new()
	_capa_guia.layer = 120
	_capa_guia.visible = false
	
	_overlay_guia = Control.new()
	_overlay_guia.name = "GuiaShortsOverlay"
	_overlay_guia.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_guia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_guia.draw.connect(_on_overlay_draw)
	
	_capa_guia.add_child(_overlay_guia)
	add_child(_capa_guia)
	
	get_viewport().size_changed.connect(_on_viewport_size_changed)

func _actualizar_visibilidad_guia() -> void:
	if is_instance_valid(_capa_guia):
		_capa_guia.visible = _mostrar_guia
		if _mostrar_guia and is_instance_valid(_overlay_guia):
			_overlay_guia.queue_redraw()

func _on_viewport_size_changed() -> void:
	if is_instance_valid(_overlay_guia) and _capa_guia.visible:
		_overlay_guia.queue_redraw()

func _on_overlay_draw() -> void:
	if not _mostrar_guia or not is_instance_valid(_overlay_guia):
		return
		
	var viewport_size = _overlay_guia.get_viewport_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return
		
	var ratio_9_16 = 9.0 / 16.0
	var ancho_9_16 = viewport_size.y * ratio_9_16
	
	# Si la pantalla es más ancha que 9:16 (típico en celular horizontal y PC)
	if viewport_size.x > ancho_9_16:
		var x_inicio = (viewport_size.x - ancho_9_16) * 0.5
		var x_fin = x_inicio + ancho_9_16
		
		# Sombrear los bordes laterales que serán recortados en el short
		var color_sombra = Color(0.0, 0.0, 0.0, 0.45)
		_overlay_guia.draw_rect(Rect2(0, 0, x_inicio, viewport_size.y), color_sombra)
		_overlay_guia.draw_rect(Rect2(x_fin, 0, viewport_size.x - x_fin, viewport_size.y), color_sombra)
		
		# Líneas guía de corte 9:16
		var color_linea = Color(1.0, 0.85, 0.25, 0.85)
		_overlay_guia.draw_line(Vector2(x_inicio, 0), Vector2(x_inicio, viewport_size.y), color_linea, 2.0)
		_overlay_guia.draw_line(Vector2(x_fin, 0), Vector2(x_fin, viewport_size.y), color_linea, 2.0)
		
		# Indicador superior de encuadre 9:16
		var color_badge = Color(1.0, 0.85, 0.25, 0.9)
		var font = ThemeDB.fallback_font
		if font:
			var txt = "📱 ENCUADRE 9:16 (SHORTS / REELS / TIKTOK)"
			font.draw_string(_overlay_guia.get_canvas_item(), Vector2(x_inicio + 12, 28), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color_badge)
			
			# Línea de zona segura inferior (subtítulos e interfaz de Shorts)
			var y_segura = viewport_size.y * 0.72
			var color_ui_shorts = Color(1.0, 0.35, 0.35, 0.6)
			_overlay_guia.draw_line(Vector2(x_inicio, y_segura), Vector2(x_fin, y_segura), color_ui_shorts, 1.5)
			font.draw_string(_overlay_guia.get_canvas_item(), Vector2(x_inicio + 12, y_segura - 8), "⚠️ Límite inferior seguro (subtítulos / interfaz de Shorts)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color_ui_shorts)

# -----------------------------------------------------------------------------
# TOAST DE NOTIFICACIÓN VISUAL EN PANTALLA
# -----------------------------------------------------------------------------
func _construir_toast_notificaciones() -> void:
	_capa_toast = CanvasLayer.new()
	_capa_toast.layer = 125
	
	_panel_toast = PanelContainer.new()
	_panel_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel_toast.offset_top = 40.0
	_panel_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel_toast.modulate.a = 0.0
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.14, 0.92)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(1.0, 0.85, 0.35, 0.90)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	_panel_toast.add_theme_stylebox_override("panel", sb)
	
	_label_toast = Label.new()
	_label_toast.text = ""
	_label_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_toast.add_theme_font_size_override("font_size", 16)
	_label_toast.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_label_toast.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	_label_toast.add_theme_constant_override("outline_size", 6)
	
	_panel_toast.add_child(_label_toast)
	_capa_toast.add_child(_panel_toast)
	add_child(_capa_toast)

func mostrar_notificacion_camara(mensaje: String) -> void:
	if not is_instance_valid(_label_toast) or not is_instance_valid(_panel_toast):
		return
	if _tween_toast and _tween_toast.is_running():
		_tween_toast.kill()
	
	_label_toast.text = mensaje
	_panel_toast.modulate.a = 0.0
	_panel_toast.position.y = 20.0
	
	_tween_toast = create_tween()
	_tween_toast.set_parallel(true)
	_tween_toast.tween_property(_panel_toast, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween_toast.tween_property(_panel_toast, "position:y", 45.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_toast.chain().tween_interval(1.4)
	_tween_toast.chain().tween_property(_panel_toast, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

# -----------------------------------------------------------------------------
# ATAJOS DE TECLADO GLOBALES DURANTE EL GAMEPLAY
# -----------------------------------------------------------------------------
func procesar_input_camara(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	
	# Evitar procesar en pantalla de inicio de juego
	var tree = get_tree()
	if tree and tree.current_scene and tree.current_scene.name == "MenuInicio":
		return false

	# Si el foco de la GUI está en un campo de texto, no interceptar teclas
	var vp = get_viewport()
	if vp:
		var foco = vp.gui_get_focus_owner()
		if foco is LineEdit or foco is TextEdit:
			return false

	# * (Asterisco / Numpad Multiply / Shift+8): Alternar proporción / guía visual 9:16 para Shorts
	if event.keycode == KEY_ASTERISK or event.keycode == KEY_KP_MULTIPLY or event.unicode == 42:
		var guia_activa = alternar_guia()
		mostrar_notificacion_camara("📱 Proporción 9:16 Shorts: ACTIVADA" if guia_activa else "📱 Proporción 9:16 Shorts: DESACTIVADA")
		return true

	# K o F6: Alternar cámara estática para tomas de Shorts
	if event.keycode == KEY_K or event.keycode == KEY_F6:
		var activa = alternar_camara_estatica()
		mostrar_notificacion_camara("📹 Cámara Estática: ACTIVADA (Punto Fijo)" if activa else "📹 Cámara Estática: DESACTIVADA (Siguiendo al personaje)")
		return true
	
	# + (o [ o PageUp): Control de Zoom - Acercar cámara (reducir distancia)
	if event.keycode == KEY_PLUS or event.keycode == KEY_KP_ADD or event.unicode == 43 or (event.keycode == KEY_EQUAL and not event.echo) or event.keycode == KEY_BRACKETLEFT or event.keycode == KEY_PAGEUP:
		var d = modificar_distancia_camara(-0.4)
		mostrar_notificacion_camara("🔍 Zoom / Distancia: %.1f m" % d)
		return true
		
	# - (o ] o PageDown): Control de Zoom - Alejar cámara (aumentar distancia)
	if (event.keycode == KEY_MINUS and not event.shift_pressed) or event.keycode == KEY_KP_SUBTRACT or event.unicode == 45 or event.keycode == KEY_BRACKETRIGHT or event.keycode == KEY_PAGEDOWN:
		var d = modificar_distancia_camara(0.4)
		mostrar_notificacion_camara("🔍 Zoom / Distancia: %.1f m" % d)
		return true
		
	# 8 (o Home): Control de Altura - Elevar cámara (arriba)
	if ((event.keycode == KEY_8 and not event.shift_pressed) or event.keycode == KEY_KP_8 or (event.unicode == 56 and not event.shift_pressed) or event.keycode == KEY_HOME):
		var h = modificar_altura_camara(0.2)
		mostrar_notificacion_camara("📐 Altura de Cámara: %.2f m" % h)
		return true
		
	# 2 (o End): Control de Altura - Bajar cámara (abajo)
	if ((event.keycode == KEY_2 and not event.shift_pressed) or event.keycode == KEY_KP_2 or (event.unicode == 50 and not event.shift_pressed) or event.keycode == KEY_END):
		var h = modificar_altura_camara(-0.2)
		mostrar_notificacion_camara("📐 Altura de Cámara: %.2f m" % h)
		return true
		
	# Backspace o F7: Revertir cámara a valores predeterminados
	if event.keycode == KEY_BACKSPACE or event.keycode == KEY_F7:
		revertir_ajustes_camara()
		mostrar_notificacion_camara("↺ Cámara restablecida a valores predeterminados")
		return true

	return false

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if procesar_input_camara(event):
		var vp = get_viewport()
		if vp:
			vp.set_input_as_handled()
