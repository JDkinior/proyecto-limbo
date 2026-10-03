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

const CONFIG_PATH = "user://opciones.cfg"
const SECTION_CAMARA = "camara"
const KEY_MODO_SHORTS = "modo_shorts"
const KEY_MOSTRAR_GUIA = "mostrar_guia_shorts"
const KEY_OCULTAR_CONTROLES = "ocultar_controles_grabacion"

# Parámetros Modo Normal (Por Defecto - Mantiene la cámara original intacta)
const ALTURA_SPRING_ARM_NORMAL: float = 1.35
const DISTANCIA_CAMARA_NORMAL: float = 3.5
const PITCH_DEFECTO_NORMAL: float = -0.14
const V_OFFSET_NORMAL: float = 0.0
const LIMITE_PITCH_MIN_NORMAL: float = -0.70
const LIMITE_PITCH_MAX_NORMAL: float = 0.35

# Parámetros Modo Grabación Shorts (Formato Vertical 9:16)
# - Altura SpringArm reducida (0.65m) para elevar el personaje al tercio superior / centro seguro.
# - Distancia de cámara (5.2m) alejada para un encuadre amplio donde se aprecie el entorno y plataformas.
# - Pitch por defecto (-0.22 rad / ~ -12.6°) para visualizar claramente el suelo y plataformas debajo.
# - Desplazamiento vertical (-0.15m) asegurando que el personaje no quede tapado por los subtítulos o botones de Shorts/TikTok.
const ALTURA_SPRING_ARM_SHORTS: float = 0.65
const DISTANCIA_CAMARA_SHORTS: float = 5.2
const PITCH_DEFECTO_SHORTS: float = -0.22
const V_OFFSET_SHORTS: float = -0.15
const LIMITE_PITCH_MIN_SHORTS: float = -0.75
const LIMITE_PITCH_MAX_SHORTS: float = 0.25

var _modo_shorts: bool = false
var _mostrar_guia: bool = false
var _ocultar_controles: bool = false

# Nodos de la guía visual 9:16
var _capa_guia: CanvasLayer = null
var _overlay_guia: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Engine.is_editor_hint():
		_construir_guia_visual()
	cargar_config()

# -----------------------------------------------------------------------------
# CONSULTAS Y CONTROL DE MODO SHORTS
# -----------------------------------------------------------------------------
func esta_modo_shorts_activo() -> bool:
	return _modo_shorts

func establecer_modo_shorts(activo: bool) -> void:
	if _modo_shorts != activo:
		_modo_shorts = activo
		guardar_config()
		modo_shorts_cambiado.emit(_modo_shorts)
		print("[CamaraConfigManager] Modo Grabación Shorts establecido en: ", _modo_shorts)

func alternar_modo_shorts() -> bool:
	establecer_modo_shorts(!_modo_shorts)
	return _modo_shorts

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
# PARÁMETROS DINÁMICOS DE CÁMARA
# -----------------------------------------------------------------------------
func obtener_altura_spring_arm() -> float:
	return ALTURA_SPRING_ARM_SHORTS if _modo_shorts else ALTURA_SPRING_ARM_NORMAL

func obtener_distancia_camara() -> float:
	return DISTANCIA_CAMARA_SHORTS if _modo_shorts else DISTANCIA_CAMARA_NORMAL

func obtener_pitch_defecto() -> float:
	return PITCH_DEFECTO_SHORTS if _modo_shorts else PITCH_DEFECTO_NORMAL

func obtener_v_offset() -> float:
	return V_OFFSET_SHORTS if _modo_shorts else V_OFFSET_NORMAL

func obtener_limite_pitch_min() -> float:
	return LIMITE_PITCH_MIN_SHORTS if _modo_shorts else LIMITE_PITCH_MIN_NORMAL

func obtener_limite_pitch_max() -> float:
	return LIMITE_PITCH_MAX_SHORTS if _modo_shorts else LIMITE_PITCH_MAX_NORMAL

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
		elif cfg.has_section("video") and cfg.has_section_key("video", KEY_MODO_SHORTS):
			_modo_shorts = cfg.get_value("video", KEY_MODO_SHORTS, false)
			_mostrar_guia = cfg.get_value("video", KEY_MOSTRAR_GUIA, false)
			_ocultar_controles = cfg.get_value("video", KEY_OCULTAR_CONTROLES, false)
	else:
		_modo_shorts = false
		_mostrar_guia = false
		_ocultar_controles = false
	_actualizar_visibilidad_guia()

func guardar_config() -> void:
	var cfg = ConfigFile.new()
	var _err = cfg.load(CONFIG_PATH)
	cfg.set_value(SECTION_CAMARA, KEY_MODO_SHORTS, _modo_shorts)
	cfg.set_value(SECTION_CAMARA, KEY_MOSTRAR_GUIA, _mostrar_guia)
	cfg.set_value(SECTION_CAMARA, KEY_OCULTAR_CONTROLES, _ocultar_controles)
	# Guardar también en sección video para consistencia con menus de video
	cfg.set_value("video", KEY_MODO_SHORTS, _modo_shorts)
	cfg.set_value("video", KEY_OCULTAR_CONTROLES, _ocultar_controles)
	var save_err = cfg.save(CONFIG_PATH)
	if save_err == OK:
		print("[CamaraConfigManager] Configuración de cámara guardada en: ", CONFIG_PATH)

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
