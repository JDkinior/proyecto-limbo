## Autoload singleton que gestiona todas las transiciones y pantallas de carga entre escenas.
## Agrega un CanvasLayer encima de todo con un overlay de fade a negro y animación de carga.
extends CanvasLayer

# ─── Señales ─────────────────────────────────────────────────────────
signal transicion_completada

# ─── Estado ──────────────────────────────────────────────────────────
enum Estado { OCULTO, FADE_IN, VISIBLE, FADE_OUT }
var estado: Estado = Estado.OCULTO
var _tween: Tween = null

# ─── Nodos del overlay ────────────────────────────────────────────────
var _fondo: ColorRect
var _contenido: VBoxContainer
var _lbl_personaje: Label
var _lbl_mensaje: Label
var _lbl_puntos: Label
var _barra: ProgressBar
var _icon_personaje: Label  # Emoji del personaje seleccionado

# ─── Mensajes cíclicos de carga ───────────────────────────────────────
const MENSAJES_VIVO = [
	"Despertando el plano físico...",
	"Cargando el mundo terrenal...",
	"Preparando al Jugador Vivo...",
	"Ajustando la gravedad...",
	"El sol comienza a brillar...",
]
const MENSAJES_FANTASMA = [
	"Atravesando el velo etéreo...",
	"Invocando el plano espiritual...",
	"Preparando al Fantasma...",
	"Tejiendo la niebla mística...",
	"La luna guía el camino...",
]

var _personaje_activo: String = "jugador"
var _tiempo_puntos: float = 0.0
var _tiempo_mensaje: float = 0.0
var _idx_mensaje: int = 0
var _num_puntos: int = 1

func _ready():
	layer = 200
	visible = false  # El CanvasLayer completo está oculto — no interfiere con ningún input
	_construir_overlay()
	# Detectar cuando una nueva escena ha sido cargada para hacer fade-out automático
	get_tree().node_added.connect(_on_nodo_agregado)

func _on_nodo_agregado(nodo: Node):
	# Cuando se carga una nueva escena del juego (no menú), hacemos fade-out
	if estado != Estado.VISIBLE:
		return
	# El nodo raíz de la nueva escena se agrega al árbol
	if nodo.get_parent() == get_tree().root and nodo != self:
		# Esperamos dos frames para que la escena termine de instanciarse
		await get_tree().process_frame
		await get_tree().process_frame
		ocultar_transicion()

func _construir_overlay():
	_fondo = ColorRect.new()
	_fondo.name = "FondoTransicion"
	_fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fondo.color = Color(0.04, 0.05, 0.1, 1.0)
	_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE  # No bloquear input cuando está oculto
	add_child(_fondo)

	_contenido = VBoxContainer.new()
	_contenido.set_anchors_preset(Control.PRESET_CENTER)
	_contenido.size = Vector2(380, 260)
	_contenido.offset_left = -190
	_contenido.offset_top = -130
	_contenido.offset_right = 190
	_contenido.offset_bottom = 130
	_contenido.alignment = BoxContainer.ALIGNMENT_CENTER
	_contenido.add_theme_constant_override("separation", 14)
	_fondo.add_child(_contenido)

	# Ícono / emoji grande del personaje
	_icon_personaje = Label.new()
	_icon_personaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_personaje.add_theme_font_size_override("font_size", 62)
	_icon_personaje.text = "☀️"
	_contenido.add_child(_icon_personaje)

	# Nombre del personaje
	_lbl_personaje = Label.new()
	_lbl_personaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_personaje.add_theme_font_size_override("font_size", 22)
	_lbl_personaje.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_lbl_personaje.text = "Jugador Vivo"
	_contenido.add_child(_lbl_personaje)

	# Separador visual
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	_contenido.add_child(sep)

	# Mensaje de carga dinámico
	_lbl_mensaje = Label.new()
	_lbl_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_mensaje.add_theme_font_size_override("font_size", 14)
	_lbl_mensaje.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0, 0.9))
	_lbl_mensaje.text = "Cargando nivel..."
	_lbl_mensaje.custom_minimum_size = Vector2(350, 0)
	_lbl_mensaje.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_contenido.add_child(_lbl_mensaje)

	# Animación de puntos
	_lbl_puntos = Label.new()
	_lbl_puntos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_puntos.add_theme_font_size_override("font_size", 28)
	_lbl_puntos.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0, 0.85))
	_lbl_puntos.text = "●"
	_contenido.add_child(_lbl_puntos)

	# Barra de progreso sutil (indeterminada)
	_barra = ProgressBar.new()
	_barra.custom_minimum_size = Vector2(300, 6)
	_barra.max_value = 100.0
	_barra.value = 0.0
	_barra.show_percentage = false
	var style_barra_bg = StyleBoxFlat.new()
	style_barra_bg.bg_color = Color(0.12, 0.18, 0.35, 0.7)
	style_barra_bg.set_corner_radius_all(6)
	var style_barra_fill = StyleBoxFlat.new()
	style_barra_fill.bg_color = Color(0.35, 0.75, 1.0, 0.9)
	style_barra_fill.set_corner_radius_all(6)
	_barra.add_theme_stylebox_override("background", style_barra_bg)
	_barra.add_theme_stylebox_override("fill", style_barra_fill)
	_contenido.add_child(_barra)

func _process(delta: float):
	if estado == Estado.OCULTO or estado == Estado.FADE_IN or estado == Estado.FADE_OUT:
		return

	# Animación de puntos pulsantes
	_tiempo_puntos += delta
	if _tiempo_puntos >= 0.38:
		_tiempo_puntos = 0.0
		_num_puntos = (_num_puntos % 3) + 1
		var puntos = ""
		for i in range(_num_puntos):
			puntos += "●"
		_lbl_puntos.text = puntos

	# Rotación de mensajes
	_tiempo_mensaje += delta
	if _tiempo_mensaje >= 2.4:
		_tiempo_mensaje = 0.0
		var mensajes = MENSAJES_VIVO if _personaje_activo == "jugador" else MENSAJES_FANTASMA
		_idx_mensaje = (_idx_mensaje + 1) % mensajes.size()
		_lbl_mensaje.text = mensajes[_idx_mensaje]

	# Barra progreso pseudo-indeterminada
	_barra.value = fmod(_barra.value + delta * 18.0, 100.0)
	var fill_val = abs(sin(_barra.value * PI / 100.0)) * 100.0
	_barra.value = fill_val

# ─── API Pública ──────────────────────────────────────────────────────

## Muestra la transición, luego llama al callback, luego desvanece al entrar al nivel.
## callback debe ser una Callable que inicia la carga real.
func iniciar_con_transicion(personaje: String, callback: Callable) -> void:
	_personaje_activo = personaje
	_preparar_contenido_personaje(personaje)
	estado = Estado.FADE_IN
	
	# Hacemos visible el CanvasLayer y arrancamos el fondo en transparente
	visible = true
	_fondo.modulate.a = 0.0
	
	if is_instance_valid(_tween) and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_parallel(false)
	_tween.tween_property(_fondo, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func():
		estado = Estado.VISIBLE
		_idx_mensaje = 0
		_tiempo_mensaje = 0.0
		_num_puntos = 1
		callback.call()
	)

## Llama esto cuando la nueva escena ya está lista para hacer fade out.
func ocultar_transicion() -> void:
	if estado == Estado.OCULTO:
		return
	estado = Estado.FADE_OUT
	if is_instance_valid(_tween) and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_parallel(false)
	_tween.tween_property(_fondo, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func():
		estado = Estado.OCULTO
		visible = false  # Ocultar el CanvasLayer completo — libera todos los inputs
		_fondo.modulate.a = 1.0  # Resetear para la próxima vez
		transicion_completada.emit()
	)



func _preparar_contenido_personaje(personaje: String):
	if personaje == "jugador":
		_icon_personaje.text = "☀️"
		_lbl_personaje.text = "Jugador Vivo"
		_lbl_personaje.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
		_lbl_puntos.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3, 0.9))
		var style_fill = StyleBoxFlat.new()
		style_fill.bg_color = Color(1.0, 0.75, 0.2, 0.9)
		style_fill.set_corner_radius_all(6)
		_barra.add_theme_stylebox_override("fill", style_fill)
		_lbl_mensaje.text = MENSAJES_VIVO[0]
		_fondo.color = Color(0.09, 0.07, 0.03, 1.0)
	else:
		_icon_personaje.text = "🌙"
		_lbl_personaje.text = "Fantasma"
		_lbl_personaje.add_theme_color_override("font_color", Color(0.4, 0.88, 1.0))
		_lbl_puntos.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0, 0.9))
		var style_fill = StyleBoxFlat.new()
		style_fill.bg_color = Color(0.25, 0.7, 1.0, 0.9)
		style_fill.set_corner_radius_all(6)
		_barra.add_theme_stylebox_override("fill", style_fill)
		_lbl_mensaje.text = MENSAJES_FANTASMA[0]
		_fondo.color = Color(0.03, 0.05, 0.12, 1.0)
