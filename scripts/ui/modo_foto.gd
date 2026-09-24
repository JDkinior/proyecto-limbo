extends Control
class_name ModoFoto

## ==============================================================================
## MODO FOTO — PROYECTO LIMBO (Inspirado en Super Mario Odyssey & Zelda: BotW)
## ==============================================================================
## Características principales:
## 1. Cámara orbital y libre 3D desacoplada del jugador.
## 2. Controles táctiles móviles ergonómicos (1 dedo: rotar, 2 dedos: desplazar/zoom).
## 3. Soporte para control / gamepad (sticks analógicos, gatillos para zoom y botones).
## 4. Congelamiento de tiempo en modo individual (efecto tiempo detenido estilo Odyssey).
## 5. 8 Filtros visuales artísticos mediante shader de pantalla (Otoño, Espiritual, B&W, Sepia, etc.).
## 6. Ajuste de inclinación / ángulo holandés (Roll Tilt) y zoom FOV de 15° a 90°.
## 7. Alternancia de enfoque de sujeto (Vivo, Fantasma, Cámara Libre).
## 8. Opciones de personaje: "Mirar a la cámara" y "Ocultar personaje".
## 9. Cuadrícula de tercios fotográfica (Rule of Thirds).
## 10. Captura de foto en alta resolución con efecto flash y guardado en user://fotos/.
## ==============================================================================

signal cerrado()

# Nombres de filtros disponibles
const NOMBRES_FILTROS: Array[String] = [
	"Normal",
	"Otoño Cálido",
	"Espiritual",
	"Cine B&W",
	"Vintage Sepia",
	"Vívido Pop",
	"Ensueño Pastel",
	"Silueta"
]

# Variables de cámara
var _camara_original: Camera3D = null
var _camara_foto: Camera3D = null
var _objetivo_enfoque: Vector3 = Vector3.ZERO
var _distancia_camara: float = 4.2
var _distancia_min: float = 0.8
var _distancia_max: float = 25.0

var _yaw: float = 0.0
var _pitch: float = 0.25
var _roll: float = 0.0
var _fov_actual: float = 70.0
var _min_fov: float = 18.0
var _max_fov: float = 90.0

# Sujetos
var _nodo_vivo: Node3D = null
var _nodo_fantasma: Node3D = null
var _sujeto_actual: int = 0 # 0: Vivo, 1: Fantasma, 2: Libre
var _rotacion_original_vivo: Vector3 = Vector3.ZERO
var _rotacion_original_fantasma: Vector3 = Vector3.ZERO
var _mirar_a_camara: bool = false
var _personajes_ocultos: bool = false

# Filtros y efectos
var _filtro_actual_idx: int = 0
var _vineta_activa: bool = false
var _cuadricula_activa: bool = false

# Estado general
var _es_solo: bool = true
var _ui_visible: bool = true
var _panel_ajustes_extra_abierto: bool = false
var _capturando_foto: bool = false

# Multi-touch para móvil y control de UI
var _toques_activos: Dictionary = {} # index -> Vector2
var _toques_en_ui: Dictionary = {} # index -> bool
var _mouse_en_ui: bool = false
var _distancia_pinch_inicial: float = 0.0
var _fov_pinch_inicial: float = 70.0
var _arrastrando_orbit: bool = false

# Iluminación y Reino
var _reino_espiritual_original: bool = false
var _luz_vivo_energia_original: float = 1.6
var _luz_fantasma_energia_original: float = 0.8

# Referencias a nodos UI
@onready var rect_filtro: ColorRect = $CanvasFiltro/FiltroColorRect
@onready var rect_cuadricula: Control = $CanvasFiltro/CuadriculaTercios
@onready var flash_rect: ColorRect = $CanvasHUD/FlashFoto
@onready var hud_contenedor: Control = $CanvasHUD/ContenedorUI
@onready var barra_superior: Control = $CanvasHUD/ContenedorUI/BarraSuperior
@onready var barra_inferior: Control = $CanvasHUD/ContenedorUI/BarraInferior
@onready var panel_lateral: Control = $CanvasHUD/ContenedorUI/PanelLateralAjustes
@onready var lbl_subtitulo: Label = $CanvasHUD/ContenedorUI/BarraSuperior/Margin/HBox/VBox/Label_Info
@onready var lbl_filtro_nombre: Label = $CanvasHUD/ContenedorUI/BarraInferior/Margin/HBox/BtnFiltro/LabelFiltro
@onready var card_toast_foto: Control = $CanvasHUD/ToastFoto
@onready var img_preview_foto: TextureRect = $CanvasHUD/ToastFoto/HBox/TextureRectPreview
@onready var lbl_ruta_foto: Label = $CanvasHUD/ToastFoto/HBox/VBox/LabelRuta
@onready var slider_zoom: HSlider = $CanvasHUD/ContenedorUI/PanelLateralAjustes/Margin/VBox/HBoxZoom/SliderZoom
@onready var slider_roll: HSlider = $CanvasHUD/ContenedorUI/PanelLateralAjustes/Margin/VBox/HBoxRoll/SliderRoll
@onready var slider_vineta: HSlider = $CanvasHUD/ContenedorUI/PanelLateralAjustes/Margin/VBox/HBoxVineta/SliderVineta
@onready var btn_sujeto: Button = $CanvasHUD/ContenedorUI/BarraInferior/Margin/HBox/BtnSujeto
@onready var btn_grid: Button = $CanvasHUD/ContenedorUI/PanelLateralAjustes/Margin/VBox/BtnGrid
@onready var btn_mirar: Button = $CanvasHUD/ContenedorUI/PanelLateralAjustes/Margin/VBox/BtnMirarCamara
@onready var btn_ocultar_pj: Button = $CanvasHUD/ContenedorUI/PanelLateralAjustes/Margin/VBox/BtnOcultarPersonaje

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_verificar_entorno_juego()
	_buscar_sujetos()
	_inicializar_camara_foto()
	_conectar_eventos_ui()
	_actualizar_textos_ui()
	_actualizar_shader_filtro()
	
	print("[ModoFoto] Inicializado con éxito. Sujeto inicial: ", _obtener_nombre_sujeto())

func _verificar_entorno_juego() -> void:
	var es_offline = (multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	_es_solo = is_instance_valid(RedManager) and (RedManager.es_un_jugador or es_offline)
	
	# En modo solitario, congelar el tiempo del juego como en Mario Odyssey y Zelda BotW
	if _es_solo:
		get_tree().paused = true
		print("[ModoFoto] Tiempo congelado para sesión fotográfica.")

func _buscar_sujetos() -> void:
	for pj in get_tree().get_nodes_in_group("jugadores"):
		if pj is Node3D:
			var nombre_low = pj.name.to_lower()
			if pj.is_in_group("fantasmas") or nombre_low.contains("fantasma"):
				_nodo_fantasma = pj
				_rotacion_original_fantasma = pj.rotation
			else:
				_nodo_vivo = pj
				_rotacion_original_vivo = pj.rotation
				
	# Si no se encontraron por grupo, buscar por nombre en la escena actual
	var escena = get_tree().current_scene
	if escena:
		if not _nodo_vivo:
			_nodo_vivo = escena.find_child("Jugador", true, false)
			if _nodo_vivo: _rotacion_original_vivo = _nodo_vivo.rotation
		if not _nodo_fantasma:
			_nodo_fantasma = escena.find_child("Fantasma", true, false)
			if _nodo_fantasma: _rotacion_original_fantasma = _nodo_fantasma.rotation

	# Registrar energías iniciales de luces y estado espiritual
	if is_instance_valid(_nodo_vivo):
		var lv = _nodo_vivo.get_node_or_null("OmniLight3D") as Light3D
		if is_instance_valid(lv):
			_luz_vivo_energia_original = lv.light_energy
	if is_instance_valid(_nodo_fantasma):
		var lf = _nodo_fantasma.get_node_or_null("OmniLight3D") as Light3D
		if is_instance_valid(lf):
			_luz_fantasma_energia_original = lf.light_energy
	if is_instance_valid(RedManager):
		_reino_espiritual_original = RedManager.reino_espiritual_activo

	# Sujeto inicial según personaje activo
	if is_instance_valid(RedManager) and RedManager.es_un_jugador and RedManager.personaje_activo_solo == "fantasma":
		_sujeto_actual = 1 if is_instance_valid(_nodo_fantasma) else 0
	else:
		_sujeto_actual = 0 if is_instance_valid(_nodo_vivo) else (1 if is_instance_valid(_nodo_fantasma) else 2)

func _inicializar_camara_foto() -> void:
	_camara_original = get_viewport().get_camera_3d()
	
	_camara_foto = Camera3D.new()
	_camara_foto.name = "CamaraModoFoto"
	_camara_foto.process_mode = Node.PROCESS_MODE_ALWAYS
	_camara_foto.top_level = true
	
	var parent_escena = get_tree().current_scene
	if parent_escena:
		parent_escena.add_child(_camara_foto)
	else:
		add_child(_camara_foto)
		
	# Establecer posición de enfoque inicial
	var nodo_s = _obtener_nodo_sujeto_actual()
	if is_instance_valid(nodo_s):
		_objetivo_enfoque = nodo_s.global_position + Vector3(0, 0.9, 0)
	elif is_instance_valid(_camara_original):
		_objetivo_enfoque = _camara_original.global_position - _camara_original.global_transform.basis.z * 3.5
	else:
		_objetivo_enfoque = Vector3.ZERO

	# Heredar propiedades de la cámara activa para una transición suave e imperceptible
	if is_instance_valid(_camara_original):
		_camara_foto.global_transform = _camara_original.global_transform
		_camara_foto.fov = _camara_original.fov
		_camara_foto.near = _camara_original.near
		_camara_foto.far = _camara_original.far
		_camara_foto.cull_mask = _camara_original.cull_mask
		_camara_foto.environment = _camara_original.environment
		_fov_actual = _camara_original.fov
		
		# Derivar distancia y ángulos respecto al objetivo
		var diff = _camara_foto.global_position - _objetivo_enfoque
		_distancia_camara = clampf(diff.length(), _distancia_min, _distancia_max)
		if _distancia_camara > 0.001:
			_yaw = atan2(diff.x, diff.z)
			var plano_xz = Vector2(diff.x, diff.z).length()
			_pitch = atan2(diff.y, plano_xz)
	else:
		_distancia_camara = 4.2
		_yaw = 0.0
		_pitch = 0.25
		_fov_actual = 70.0

	_camara_foto.current = true
	_actualizar_transform_camara()
	_aplicar_iluminacion_y_entorno_sujeto(_sujeto_actual == 1)

func _conectar_eventos_ui() -> void:
	# Sliders
	if is_instance_valid(slider_zoom):
		slider_zoom.min_value = _min_fov
		slider_zoom.max_value = _max_fov
		slider_zoom.value = _fov_actual
		slider_zoom.value_changed.connect(func(v: float):
			_fov_actual = v
			if is_instance_valid(_camara_foto):
				_camara_foto.fov = _fov_actual
		)
		
	if is_instance_valid(slider_roll):
		slider_roll.min_value = -45.0
		slider_roll.max_value = 45.0
		slider_roll.value = 0.0
		slider_roll.value_changed.connect(func(v: float):
			_roll = deg_to_rad(v)
		)
		
	if is_instance_valid(slider_vineta):
		slider_vineta.min_value = 0.0
		slider_vineta.max_value = 1.0
		slider_vineta.step = 0.05
		slider_vineta.value = 0.0
		slider_vineta.value_changed.connect(func(v: float):
			_actualizar_vineta_shader(v)
		)

	# Botones principales
	var btn_foto = $CanvasHUD/ContenedorUI/BarraInferior/Margin/HBox/BtnTomarFoto
	if is_instance_valid(btn_foto):
		btn_foto.pressed.connect(tomar_foto)
		
	var btn_filtro = $CanvasHUD/ContenedorUI/BarraInferior/Margin/HBox/BtnFiltro
	if is_instance_valid(btn_filtro):
		btn_filtro.pressed.connect(siguiente_filtro)
		
	var btn_sujeto = $CanvasHUD/ContenedorUI/BarraInferior/Margin/HBox/BtnSujeto
	if is_instance_valid(btn_sujeto):
		btn_sujeto.pressed.connect(alternar_sujeto)
		
	var btn_ajustes = $CanvasHUD/ContenedorUI/BarraInferior/Margin/HBox/BtnAjustesExtra
	if is_instance_valid(btn_ajustes):
		btn_ajustes.pressed.connect(alternar_panel_ajustes)
		
	var btn_ocultar = $CanvasHUD/ContenedorUI/BarraInferior/Margin/HBox/BtnOcultarUI
	if is_instance_valid(btn_ocultar):
		btn_ocultar.pressed.connect(alternar_interfaz)
		
	var btn_salir = $CanvasHUD/ContenedorUI/BarraSuperior/Margin/HBox/BtnSalir
	if is_instance_valid(btn_salir):
		btn_salir.pressed.connect(salir_modo_foto)
		
	# Botones del panel lateral
	var btn_grid = $CanvasHUD/ContenedorUI/PanelLateralAjustes/Margin/VBox/BtnGrid
	if is_instance_valid(btn_grid):
		btn_grid.pressed.connect(alternar_cuadricula)
		
	var btn_mirar = $CanvasHUD/ContenedorUI/PanelLateralAjustes/Margin/VBox/BtnMirarCamara
	if is_instance_valid(btn_mirar):
		btn_mirar.pressed.connect(alternar_mirar_a_camara)
		
	var btn_ocultar_pj = $CanvasHUD/ContenedorUI/PanelLateralAjustes/Margin/VBox/BtnOcultarPersonaje
	if is_instance_valid(btn_ocultar_pj):
		btn_ocultar_pj.pressed.connect(alternar_visibilidad_personajes)
		
	var btn_reset_cam = $CanvasHUD/ContenedorUI/PanelLateralAjustes/Margin/VBox/BtnResetearCamara
	if is_instance_valid(btn_reset_cam):
		btn_reset_cam.pressed.connect(resetear_posicion_camara)

# ------------------------------------------------------------------------------
# PROCESAMIENTO DE CÁMARA Y MOVIMIENTO SUAVE
# ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _capturando_foto:
		return
		
	_procesar_input_gamepad_y_teclado(delta)
	_actualizar_transform_camara()
	
	if _mirar_a_camara:
		_aplicar_mirar_a_camara()

func _actualizar_transform_camara() -> void:
	if not is_instance_valid(_camara_foto):
		return
		
	# Construir la base de rotación orbital mediante Euler YXZ
	var rot_basis = Basis.from_euler(Vector3(_pitch, _yaw, _roll), EULER_ORDER_YXZ)
	var offset = rot_basis * Vector3(0.0, 0.0, _distancia_camara)
	
	_camara_foto.global_position = _objetivo_enfoque + offset
	_camara_foto.basis = rot_basis
	_camara_foto.fov = _fov_actual

func _procesar_input_gamepad_y_teclado(delta: float) -> void:
	var stick_rot_x: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var stick_rot_y: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	var stick_mov_x: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var stick_mov_y: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	
	# Deadzone analógica
	const DEADZONE: float = 0.18
	if absf(stick_rot_x) < DEADZONE: stick_rot_x = 0.0
	if absf(stick_rot_y) < DEADZONE: stick_rot_y = 0.0
	if absf(stick_mov_x) < DEADZONE: stick_mov_x = 0.0
	if absf(stick_mov_y) < DEADZONE: stick_mov_y = 0.0

	# 1. Rotación orbital con stick derecho
	if stick_rot_x != 0.0 or stick_rot_y != 0.0:
		_yaw -= stick_rot_x * 2.4 * delta
		_pitch -= stick_rot_y * 1.8 * delta
		_pitch = clampf(_pitch, -deg_to_rad(82.0), deg_to_rad(82.0))
		
	# 2. Desplazamiento horizontal del objetivo con stick izquierdo o teclado
	var dir_mov = Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir_mov.z -= 1.0
	if Input.is_key_pressed(KEY_S): dir_mov.z += 1.0
	if Input.is_key_pressed(KEY_A): dir_mov.x -= 1.0
	if Input.is_key_pressed(KEY_D): dir_mov.x += 1.0
	
	dir_mov.x += stick_mov_x
	dir_mov.z += stick_mov_y
	
	if dir_mov.length_squared() > 0.01:
		var basis_h = Basis(Vector3.UP, _yaw)
		var avance = basis_h * Vector3(dir_mov.x, 0.0, dir_mov.z).normalized()
		var vel_desp = 5.0 * delta * (_distancia_camara / 4.0)
		_objetivo_enfoque += avance * vel_desp
		
	# 3. Elevación de cámara (Q/E o Bumpers)
	var elev: float = 0.0
	if Input.is_key_pressed(KEY_E) or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER):
		elev += 1.0
	if Input.is_key_pressed(KEY_Q) or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER):
		elev -= 1.0
	if elev != 0.0:
		_objetivo_enfoque.y += elev * 4.0 * delta

	# 4. Zoom / FOV con gatillos o teclas Z / C
	var zoom_in: float = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT)
	var zoom_out: float = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
	if Input.is_key_pressed(KEY_Z): zoom_in += 1.0
	if Input.is_key_pressed(KEY_C): zoom_out += 1.0
	
	if zoom_in > 0.1:
		_ajustar_fov(-30.0 * zoom_in * delta)
	elif zoom_out > 0.1:
		_ajustar_fov(30.0 * zoom_out * delta)

# ------------------------------------------------------------------------------
# GESTIÓN DE INPUT TÁCTIL (Móvil) Y ATAJOS
# ------------------------------------------------------------------------------

func _esta_sobre_ui(pos: Vector2) -> bool:
	if not _ui_visible:
		return false
		
	if is_instance_valid(barra_superior) and barra_superior.is_visible_in_tree():
		if barra_superior.get_global_rect().has_point(pos):
			return true
			
	if is_instance_valid(barra_inferior) and barra_inferior.is_visible_in_tree():
		if barra_inferior.get_global_rect().has_point(pos):
			return true
			
	if is_instance_valid(panel_lateral) and panel_lateral.is_visible_in_tree():
		# Margen de protección de 20px alrededor de los sliders para evitar que el dedo rote la cámara
		var rect_p = panel_lateral.get_global_rect().grow(20.0)
		if rect_p.has_point(pos):
			return true
			
	if is_instance_valid(card_toast_foto) and card_toast_foto.is_visible_in_tree():
		if card_toast_foto.get_global_rect().has_point(pos):
			return true
			
	return false

func _input(event: InputEvent) -> void:
	if _capturando_foto:
		return

	# Si la UI está oculta, cualquier toque o tecla la hace reaparecer
	if not _ui_visible:
		if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed) or (event is InputEventJoypadButton and event.pressed):
			mostrar_interfaz()
			get_viewport().set_input_as_handled()
			return

	# Control táctil / gestos de pantalla
	if event is InputEventScreenTouch:
		if event.pressed:
			if _esta_sobre_ui(event.position):
				_toques_en_ui[event.index] = true
				return
			_toques_activos[event.index] = event.position
			if _toques_activos.size() == 2:
				var p = _toques_activos.values()
				_distancia_pinch_inicial = p[0].distance_to(p[1])
				_fov_pinch_inicial = _fov_actual
		else:
			if _toques_en_ui.has(event.index):
				_toques_en_ui.erase(event.index)
				return
			_toques_activos.erase(event.index)
			if _toques_activos.is_empty():
				_arrastrando_orbit = false

	elif event is InputEventScreenDrag:
		if _toques_en_ui.get(event.index, false):
			return
		if not _toques_activos.has(event.index):
			return
		_toques_activos[event.index] = event.position
		
		# 1 dedo: Orbitar cámara
		if _toques_activos.size() == 1:
			var factor_sens: float = 0.0055 * (_fov_actual / 70.0)
			_yaw -= event.relative.x * factor_sens
			_pitch -= event.relative.y * factor_sens
			_pitch = clampf(_pitch, -deg_to_rad(82.0), deg_to_rad(82.0))
			
		# 2 dedos: Pinch zoom y paneo
		elif _toques_activos.size() == 2:
			var pts = _toques_activos.values()
			var dist_actual = pts[0].distance_to(pts[1])
			if _distancia_pinch_inicial > 10.0:
				var ratio = dist_actual / _distancia_pinch_inicial
				# Pellizcar abre o cierra el FOV
				var nuevo_fov = clampf(_fov_pinch_inicial / ratio, _min_fov, _max_fov)
				_fov_actual = nuevo_fov
				if is_instance_valid(slider_zoom):
					slider_zoom.value = _fov_actual
					
			# Paneo con dos dedos
			var rel_medio = event.relative * 0.5
			var basis_cam = Basis.from_euler(Vector3(_pitch, _yaw, 0.0), EULER_ORDER_YXZ)
			var desp = (basis_cam * Vector3(-rel_medio.x, rel_medio.y, 0.0)) * 0.008 * (_distancia_camara / 4.0)
			_objetivo_enfoque += desp

	# Zoom con rueda del ratón o clicks en desktop
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_ajustar_fov(-3.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_ajustar_fov(3.0)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _esta_sobre_ui(event.position):
					_mouse_en_ui = true
					return
				_mouse_en_ui = false
			else:
				_mouse_en_ui = false

	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if _mouse_en_ui or _esta_sobre_ui(event.position):
				return
			if _toques_activos.is_empty():
				var factor_sens: float = 0.0055 * (_fov_actual / 70.0)
				_yaw -= event.relative.x * factor_sens
				_pitch -= event.relative.y * factor_sens
				_pitch = clampf(_pitch, -deg_to_rad(82.0), deg_to_rad(82.0))

	# Atajos de Gamepad
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_A:
				tomar_foto()
				get_viewport().set_input_as_handled()
			JOY_BUTTON_B:
				salir_modo_foto()
				get_viewport().set_input_as_handled()
			JOY_BUTTON_X:
				alternar_interfaz()
				get_viewport().set_input_as_handled()
			JOY_BUTTON_Y:
				alternar_cuadricula()
				get_viewport().set_input_as_handled()
			JOY_BUTTON_DPAD_RIGHT:
				siguiente_filtro()
				get_viewport().set_input_as_handled()
			JOY_BUTTON_DPAD_LEFT:
				anterior_filtro()
				get_viewport().set_input_as_handled()

	# Tecla Escape para salir
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			salir_modo_foto()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE:
			tomar_foto()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_TAB:
			alternar_interfaz()
			get_viewport().set_input_as_handled()

func _ajustar_fov(delta_fov: float) -> void:
	_fov_actual = clampf(_fov_actual + delta_fov, _min_fov, _max_fov)
	if is_instance_valid(slider_zoom):
		slider_zoom.value = _fov_actual
	if is_instance_valid(_camara_foto):
		_camara_foto.fov = _fov_actual

# ------------------------------------------------------------------------------
# ACCIONES DE EDICIÓN Y AJUSTES
# ------------------------------------------------------------------------------

func siguiente_filtro() -> void:
	_filtro_actual_idx = (_filtro_actual_idx + 1) % NOMBRES_FILTROS.size()
	_actualizar_shader_filtro()
	_actualizar_textos_ui()

func anterior_filtro() -> void:
	_filtro_actual_idx = (_filtro_actual_idx - 1 + NOMBRES_FILTROS.size()) % NOMBRES_FILTROS.size()
	_actualizar_shader_filtro()
	_actualizar_textos_ui()

func _actualizar_shader_filtro() -> void:
	if not is_instance_valid(rect_filtro):
		return
	var mat = rect_filtro.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("modo_filtro", _filtro_actual_idx)
		mat.set_shader_parameter("intensidad_filtro", 1.0 if _filtro_actual_idx > 0 else 0.0)

func _actualizar_vineta_shader(val: float) -> void:
	if not is_instance_valid(rect_filtro):
		return
	var mat = rect_filtro.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("intensidad_vineta", val)

func alternar_cuadricula() -> void:
	_cuadricula_activa = !_cuadricula_activa
	if is_instance_valid(rect_cuadricula):
		rect_cuadricula.visible = _cuadricula_activa
	if is_instance_valid(btn_grid):
		btn_grid.text = "📐 Cuadrícula: SÍ" if _cuadricula_activa else "📐 Cuadrícula: NO"

func alternar_sujeto() -> void:
	_sujeto_actual = (_sujeto_actual + 1) % 3
	var nodo = _obtener_nodo_sujeto_actual()
	if is_instance_valid(nodo):
		var target_pos = nodo.global_position + Vector3(0, 0.9, 0)
		var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "_objetivo_enfoque", target_pos, 0.4)
	
	# Sincronizar iluminación, cielo y reino espiritual según el sujeto enfocado
	if _sujeto_actual == 0:
		_aplicar_iluminacion_y_entorno_sujeto(false)
	elif _sujeto_actual == 1:
		_aplicar_iluminacion_y_entorno_sujeto(true)
		
	# Si mirar a cámara está activo, restaurar rotación del sujeto anterior
	if _mirar_a_camara:
		if _sujeto_actual == 0 and is_instance_valid(_nodo_fantasma):
			_nodo_fantasma.rotation = _rotacion_original_fantasma
		elif _sujeto_actual == 1 and is_instance_valid(_nodo_vivo):
			_nodo_vivo.rotation = _rotacion_original_vivo
			
	_actualizar_textos_ui()

func _aplicar_iluminacion_y_entorno_sujeto(es_fantasma_sujeto: bool) -> void:
	if not is_instance_valid(_camara_foto):
		return
		
	if es_fantasma_sujeto:
		# 1. Configurar cámara con el entorno y cull mask del Fantasma (cielo místico, luz ambiental cian)
		if is_instance_valid(_nodo_fantasma) and _nodo_fantasma.has_method("obtener_entorno_personaje"):
			var env = _nodo_fantasma.obtener_entorno_personaje()
			if env:
				_camara_foto.environment = env
		if is_instance_valid(_nodo_fantasma) and _nodo_fantasma.has_method("obtener_cull_mask_personaje"):
			_camara_foto.cull_mask = _nodo_fantasma.obtener_cull_mask_personaje()
			
		# 2. Notificar a RedManager y al mundo que el reino espiritual está activo (pasto, monedas y niebla)
		if is_instance_valid(RedManager):
			RedManager.reino_espiritual_activo = true
			if RedManager.has_signal("reino_cambiado"):
				RedManager.reino_cambiado.emit(true)
				
		# 3. Ajustar fuentes de luz: apagar la luz amarilla del Vivo y activar la luz etérea del Fantasma
		if is_instance_valid(_nodo_vivo):
			var lv = _nodo_vivo.get_node_or_null("OmniLight3D") as Light3D
			if is_instance_valid(lv):
				lv.light_energy = 0.0
		if is_instance_valid(_nodo_fantasma):
			var lf = _nodo_fantasma.get_node_or_null("OmniLight3D") as Light3D
			if is_instance_valid(lf):
				lf.light_energy = maxf(_luz_fantasma_energia_original, 1.2)
	else:
		# 1. Configurar cámara con el entorno y cull mask del Vivo (cielo cálido, luz ámbar)
		if is_instance_valid(_nodo_vivo) and _nodo_vivo.has_method("obtener_entorno_personaje"):
			var env = _nodo_vivo.obtener_entorno_personaje()
			if env:
				_camara_foto.environment = env
		if is_instance_valid(_nodo_vivo) and _nodo_vivo.has_method("obtener_cull_mask_personaje"):
			_camara_foto.cull_mask = _nodo_vivo.obtener_cull_mask_personaje()
			
		# 2. Notificar a RedManager y al mundo que el reino espiritual está inactivo
		if is_instance_valid(RedManager):
			RedManager.reino_espiritual_activo = false
			if RedManager.has_signal("reino_cambiado"):
				RedManager.reino_cambiado.emit(false)
				
		# 3. Restaurar luces: luz cálida del Vivo activa, atenuar la del Fantasma
		if is_instance_valid(_nodo_vivo):
			var lv = _nodo_vivo.get_node_or_null("OmniLight3D") as Light3D
			if is_instance_valid(lv):
				lv.light_energy = _luz_vivo_energia_original
		if is_instance_valid(_nodo_fantasma):
			var lf = _nodo_fantasma.get_node_or_null("OmniLight3D") as Light3D
			if is_instance_valid(lf):
				lf.light_energy = 0.0

func alternar_mirar_a_camara() -> void:
	_mirar_a_camara = !_mirar_a_camara
	if is_instance_valid(btn_mirar):
		btn_mirar.text = "👀 Mirar a Cámara: SÍ" if _mirar_a_camara else "👀 Mirar a Cámara: NO"
		
	if not _mirar_a_camara:
		# Restaurar rotaciones originales
		if is_instance_valid(_nodo_vivo):
			_nodo_vivo.rotation = _rotacion_original_vivo
		if is_instance_valid(_nodo_fantasma):
			_nodo_fantasma.rotation = _rotacion_original_fantasma

func _aplicar_mirar_a_camara() -> void:
	if not is_instance_valid(_camara_foto):
		return
	var pos_cam = _camara_foto.global_position
	var nodos_a_girar: Array[Node3D] = []
	if _sujeto_actual == 0 and is_instance_valid(_nodo_vivo):
		nodos_a_girar.append(_nodo_vivo)
	elif _sujeto_actual == 1 and is_instance_valid(_nodo_fantasma):
		nodos_a_girar.append(_nodo_fantasma)
	else:
		if is_instance_valid(_nodo_vivo): nodos_a_girar.append(_nodo_vivo)
		if is_instance_valid(_nodo_fantasma): nodos_a_girar.append(_nodo_fantasma)
		
	for nodo in nodos_a_girar:
		var diff = pos_cam - nodo.global_position
		diff.y = 0.0
		if diff.length_squared() > 0.05:
			# Los modelos 3D tienen el frente invertido (rotación local de 180°),
			# por lo que atan2(-diff.x, -diff.z) hace que su rostro mire de frente a la cámara.
			var target_rot_y = atan2(-diff.x, -diff.z)
			nodo.rotation.y = lerp_angle(nodo.rotation.y, target_rot_y, 0.20)

func alternar_visibilidad_personajes() -> void:
	_personajes_ocultos = !_personajes_ocultos
	if is_instance_valid(_nodo_vivo):
		_nodo_vivo.visible = !_personajes_ocultos
	if is_instance_valid(_nodo_fantasma):
		_nodo_fantasma.visible = !_personajes_ocultos
		
	if is_instance_valid(btn_ocultar_pj):
		btn_ocultar_pj.text = "👻 Mostrar Personajes" if _personajes_ocultos else "👻 Ocultar Personajes"

func resetear_posicion_camara() -> void:
	var nodo = _obtener_nodo_sujeto_actual()
	if is_instance_valid(nodo):
		_objetivo_enfoque = nodo.global_position + Vector3(0, 0.9, 0)
	_distancia_camara = 4.2
	_roll = 0.0
	_fov_actual = 70.0
	if is_instance_valid(slider_zoom): slider_zoom.value = 70.0
	if is_instance_valid(slider_roll): slider_roll.value = 0.0
	if is_instance_valid(_camara_foto): _camara_foto.fov = 70.0

func alternar_panel_ajustes() -> void:
	_panel_ajustes_extra_abierto = !_panel_ajustes_extra_abierto
	if is_instance_valid(panel_lateral):
		panel_lateral.visible = _panel_ajustes_extra_abierto

func alternar_interfaz() -> void:
	if _ui_visible:
		ocultar_interfaz()
	else:
		mostrar_interfaz()

func ocultar_interfaz() -> void:
	_ui_visible = false
	if is_instance_valid(hud_contenedor):
		hud_contenedor.visible = false
	if is_instance_valid(rect_cuadricula):
		rect_cuadricula.visible = false

func mostrar_interfaz() -> void:
	_ui_visible = true
	if is_instance_valid(hud_contenedor):
		hud_contenedor.visible = true
	if is_instance_valid(rect_cuadricula):
		rect_cuadricula.visible = _cuadricula_activa

func _actualizar_textos_ui() -> void:
	var nombre_f = NOMBRES_FILTROS[_filtro_actual_idx]
	if is_instance_valid(lbl_filtro_nombre):
		lbl_filtro_nombre.text = "🎨 Filtro: " + nombre_f
		
	var sujeto_txt = _obtener_nombre_sujeto()
	if is_instance_valid(lbl_subtitulo):
		lbl_subtitulo.text = "Enfoque: " + sujeto_txt + "  |  Filtro: " + nombre_f
		
	if is_instance_valid(btn_sujeto):
		btn_sujeto.text = "👤 " + sujeto_txt

func _obtener_nodo_sujeto_actual() -> Node3D:
	match _sujeto_actual:
		0: return _nodo_vivo
		1: return _nodo_fantasma
		_: return null

func _obtener_nombre_sujeto() -> String:
	match _sujeto_actual:
		0: return "Vivo" if is_instance_valid(_nodo_vivo) else "Libre"
		1: return "Fantasma" if is_instance_valid(_nodo_fantasma) else "Libre"
		_: return "Libre"

# ------------------------------------------------------------------------------
# CAPTURA DE FOTOGRAFÍA (SNAPSHOT)
# ------------------------------------------------------------------------------

func tomar_foto() -> void:
	if _capturando_foto:
		return
	_capturando_foto = true
	
	# 1. Ocultar todos los elementos de interfaz y cuadrícula antes de capturar el viewport
	var ui_estaba_activa = _ui_visible
	var grid_estaba_activa = _cuadricula_activa
	if is_instance_valid(hud_contenedor): hud_contenedor.visible = false
	if is_instance_valid(rect_cuadricula): rect_cuadricula.visible = false
	
	# Esperar al siguiente cuadro renderizado para garantizar que la pantalla está completamente limpia
	await RenderingServer.frame_post_draw
	
	# 2. Capturar imagen del Viewport
	var vp = get_viewport()
	var img = vp.get_texture().get_image()
	
	# 3. Guardar en user://fotos/
	var dir_fotos = "user://fotos"
	if not DirAccess.dir_exists_absolute(dir_fotos):
		DirAccess.make_dir_absolute(dir_fotos)
		
	var time_dict = Time.get_datetime_dict_from_system()
	var nombre_archivo = "limbo_%04d-%02d-%02d_%02d-%02d-%02d.png" % [
		time_dict["year"], time_dict["month"], time_dict["day"],
		time_dict["hour"], time_dict["minute"], time_dict["second"]
	]
	var ruta_completa = dir_fotos + "/" + nombre_archivo
	var err = img.save_png(ruta_completa)
	if err == OK:
		print("[ModoFoto] Fotografía guardada exitosamente en: ", ruta_completa)
	else:
		push_warning("[ModoFoto] Error al guardar imagen: " + str(err))

	# 4. Efecto de destello de obturador (Flash)
	_reproducir_destello_flash()
	_reproducir_sonido_obturador()

	# 5. Restaurar UI
	if ui_estaba_activa:
		mostrar_interfaz()
	if grid_estaba_activa:
		rect_cuadricula.visible = true

	# 6. Mostrar miniatura (polaroid preview)
	_mostrar_toast_foto(img, nombre_archivo)
	
	_capturando_foto = false

func _reproducir_destello_flash() -> void:
	if not is_instance_valid(flash_rect):
		return
	flash_rect.visible = true
	flash_rect.modulate.a = 0.95
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash_rect, "modulate:a", 0.0, 0.28)
	tw.tween_callback(func(): flash_rect.visible = false)

func _reproducir_sonido_obturador() -> void:
	# Generador de sonido de clic de cámara sintético puro (sin depender de archivos wav externos)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	var samples = PackedByteArray()
	var num_samples = int(stream.mix_rate * 0.07)
	samples.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / float(num_samples)
		var env = exp(-t * 22.0)
		var freq = 1400.0 - t * 900.0
		var val = sin(t * freq * TAU * (1.0 - t * 0.35)) * env * 125.0
		samples[i] = clampi(int(val) + 128, 0, 255)
	stream.data = samples
	
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func _mostrar_toast_foto(img: Image, nombre_archivo: String) -> void:
	if not is_instance_valid(card_toast_foto):
		return
		
	var tex = ImageTexture.create_from_image(img)
	if is_instance_valid(img_preview_foto):
		img_preview_foto.texture = tex
	if is_instance_valid(lbl_ruta_foto):
		lbl_ruta_foto.text = "Fotos / " + nombre_archivo
		
	card_toast_foto.visible = true
	card_toast_foto.modulate.a = 0.0
	card_toast_foto.position.y = get_viewport_rect().size.y
	
	var target_y = get_viewport_rect().size.y - card_toast_foto.size.y - 85.0
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card_toast_foto, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(card_toast_foto, "position:y", target_y, 0.35)
	tw.tween_interval(2.6)
	tw.tween_property(card_toast_foto, "modulate:a", 0.0, 0.4)
	tw.parallel().tween_property(card_toast_foto, "position:y", get_viewport_rect().size.y, 0.4)
	tw.tween_callback(func(): card_toast_foto.visible = false)

# ------------------------------------------------------------------------------
# SALIDA Y LIMPIEZA
# ------------------------------------------------------------------------------

func salir_modo_foto() -> void:
	print("[ModoFoto] Saliendo del Modo Foto...")
	
	# 1. Restaurar rotaciones y visibilidad de personajes
	if is_instance_valid(_nodo_vivo):
		_nodo_vivo.rotation = _rotacion_original_vivo
		_nodo_vivo.visible = true
	if is_instance_valid(_nodo_fantasma):
		_nodo_fantasma.rotation = _rotacion_original_fantasma
		_nodo_fantasma.visible = true
		
	# 2. Restaurar reino e iluminación originales
	_aplicar_iluminacion_y_entorno_sujeto(_reino_espiritual_original)
	if is_instance_valid(_nodo_vivo):
		var lv = _nodo_vivo.get_node_or_null("OmniLight3D") as Light3D
		if is_instance_valid(lv):
			lv.light_energy = _luz_vivo_energia_original
			lv.visible = true
	if is_instance_valid(_nodo_fantasma):
		var lf = _nodo_fantasma.get_node_or_null("OmniLight3D") as Light3D
		if is_instance_valid(lf):
			lf.light_energy = _luz_fantasma_energia_original
			lf.visible = true

	# 3. Restaurar cámara original del jugador
	if is_instance_valid(_camara_original):
		_camara_original.current = true
	if is_instance_valid(_camara_foto):
		_camara_foto.queue_free()
		_camara_foto = null

	# 4. Despausar si estábamos en solitario
	if _es_solo:
		get_tree().paused = false
		
	cerrado.emit()
	queue_free()
