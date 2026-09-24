extends CanvasLayer

## ==============================================================================
## FPS COUNTER (PROYECTO LIMBO)
## Contador de FPS estilizado, persistente y configurable desde Ajustes.
## Capa superior que muestra rendimiento en tiempo real en PC y dispositivos móviles.
## ==============================================================================

const CONFIG_PATH = "user://opciones.cfg"
const SECTION_VIDEO = "video"
const KEY_MOSTRAR_FPS = "mostrar_fps"

signal estado_cambiado(activo: bool)

var _activo: bool = false
var _timer: float = 0.0
var _label_fps: Label = null
var _contenedor_badge: PanelContainer = null

func _ready() -> void:
	layer = 125
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construir_ui()
	_cargar_config()

func esta_activo() -> bool:
	return _activo

func establecer_activo(activo: bool) -> void:
	if _activo != activo:
		_activo = activo
		_guardar_config()
	if is_instance_valid(_contenedor_badge):
		_contenedor_badge.visible = _activo
	estado_cambiado.emit(_activo)
	print("[FPSCounter] Estado de visualización FPS establecido en: ", _activo)

func alternar() -> bool:
	establecer_activo(!_activo)
	return _activo

func _process(delta: float) -> void:
	if not _activo or not is_instance_valid(_label_fps) or not _contenedor_badge.visible:
		return

	_timer += delta
	if _timer >= 0.28:
		_timer = 0.0
		var fps = Engine.get_frames_per_second()
		_label_fps.text = "%d FPS" % fps

		if fps >= 55:
			_label_fps.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55))
		elif fps >= 30:
			_label_fps.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
		else:
			_label_fps.add_theme_color_override("font_color", Color(1.0, 0.40, 0.40))

func _construir_ui() -> void:
	_contenedor_badge = PanelContainer.new()
	_contenedor_badge.name = "FPSBadge"
	_contenedor_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contenedor_badge.offset_left = 18.0
	_contenedor_badge.offset_top = 16.0
	_contenedor_badge.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.10, 0.72)
	style.border_color = Color(0.25, 0.40, 0.55, 0.80)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.set_corner_radius_all(8)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	_contenedor_badge.add_theme_stylebox_override("panel", style)

	_label_fps = Label.new()
	_label_fps.name = "LabelFPS"
	_label_fps.text = "-- FPS"
	_label_fps.add_theme_font_size_override("font_size", 16)
	_label_fps.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55))
	_label_fps.add_theme_constant_override("outline_size", 4)
	_label_fps.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))

	_contenedor_badge.add_child(_label_fps)
	add_child(_contenedor_badge)

func _cargar_config() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(CONFIG_PATH)
	if err == OK and cfg.has_section(SECTION_VIDEO):
		_activo = cfg.get_value(SECTION_VIDEO, KEY_MOSTRAR_FPS, false)
	else:
		_activo = false
	if is_instance_valid(_contenedor_badge):
		_contenedor_badge.visible = _activo

func _guardar_config() -> void:
	var cfg = ConfigFile.new()
	var _err = cfg.load(CONFIG_PATH)
	cfg.set_value(SECTION_VIDEO, KEY_MOSTRAR_FPS, _activo)
	cfg.save(CONFIG_PATH)
