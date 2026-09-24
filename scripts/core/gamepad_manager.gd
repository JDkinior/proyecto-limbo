extends Node

## GamepadManager
## Administrador global para detección automática de controles (mandos/gamepads),
## mapeo de botones, almacenamiento de configuración y sincronización con InputMap.

static var instancia: Node = null

signal control_conectado_cambiado(conectado: bool, device_id: int)
signal modo_control_cambiado(activo: bool)
signal mapeo_actualizado()

const CONFIG_PATH = "user://opciones.cfg"
const SECTION_GAMEPAD = "gamepad"

const ACCIONES_CONFIGURABLES: Array[Dictionary] = [
	{
		"id": "saltar",
		"nombre": "Saltar",
		"descripcion": "Salto, doble salto y planear en el aire",
		"tipo_defecto": "button",
		"indice_defecto": JOY_BUTTON_A
	},
	{
		"id": "interactuar",
		"nombre": "Interactuar / Habilidad",
		"descripcion": "Operar palancas, manivelas, cajas y aura fantasmal",
		"tipo_defecto": "button",
		"indice_defecto": JOY_BUTTON_B
	},
	{
		"id": "cambiar_personaje",
		"nombre": "Cambiar Personaje",
		"descripcion": "Alternar entre Vivo y Fantasma (Modo 1 Jugador)",
		"tipo_defecto": "button",
		"indice_defecto": JOY_BUTTON_Y
	},
	{
		"id": "pausa",
		"nombre": "Pausa / Menú",
		"descripcion": "Abrir o reanudar el menú de pausa y ajustes",
		"tipo_defecto": "button",
		"indice_defecto": JOY_BUTTON_START
	},
	{
		"id": "centrar_camara",
		"nombre": "Centrar Cámara",
		"descripcion": "Alinear la cámara inmediatamente tras el personaje",
		"tipo_defecto": "button",
		"indice_defecto": JOY_BUTTON_RIGHT_STICK
	}
]

var control_conectado: bool = false
var modo_control_activo: bool = false
var dispositivo_activo: int = 0
var nombre_control: String = ""
var mapeos_actuales: Dictionary = {}

func _enter_tree() -> void:
	instancia = self

static func get_instancia() -> Node:
	return instancia

func _ready() -> void:
	instancia = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Detectar estado inicial de mandos conectados
	_actualizar_estado_conexion_inicial()
	
	# Conectar señal del motor para cambios en caliente de conexión
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	
	# Cargar configuración guardada y aplicar mappings
	cargar_config()
	aplicar_mapeos_a_inputmap()

func _actualizar_estado_conexion_inicial() -> void:
	var joypads = Input.get_connected_joypads()
	if joypads.size() > 0:
		dispositivo_activo = joypads[0]
		nombre_control = Input.get_joy_name(dispositivo_activo)
		control_conectado = true
		modo_control_activo = true
		print("[GamepadManager] Control detectado al inicio: '", nombre_control, "' (ID: ", dispositivo_activo, ")")
	else:
		dispositivo_activo = 0
		nombre_control = ""
		control_conectado = false
		modo_control_activo = false
		print("[GamepadManager] No se detectó control conectado al inicio.")

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	var joypads = Input.get_connected_joypads()
	var previo = control_conectado
	
	if connected:
		dispositivo_activo = device
		nombre_control = Input.get_joy_name(device)
		control_conectado = true
		modo_control_activo = true
		print("[GamepadManager] Control CONECTADO: '", nombre_control, "' (ID: ", device, ")")
	else:
		if joypads.size() > 0:
			dispositivo_activo = joypads[0]
			nombre_control = Input.get_joy_name(dispositivo_activo)
			control_conectado = true
			print("[GamepadManager] Control desconectado, pero aún queda activo: '", nombre_control, "'")
		else:
			control_conectado = false
			modo_control_activo = false
			nombre_control = ""
			print("[GamepadManager] Control DESCONECTADO: Ningún control restante.")
			
	if previo != control_conectado:
		control_conectado_cambiado.emit(control_conectado, dispositivo_activo)
	modo_control_cambiado.emit(modo_control_activo)

func _input(event: InputEvent) -> void:
	# 1. Respaldo de detección: si no estaba marcado conectado pero se recibe input físico de mando
	if not control_conectado:
		if event is InputEventJoypadButton and event.is_pressed():
			dispositivo_activo = event.device
			nombre_control = Input.get_joy_name(event.device)
			control_conectado = true
			modo_control_activo = true
			print("[GamepadManager] Input de control recibido en dispositivo ", event.device, " -> Marcando como conectado.")
			control_conectado_cambiado.emit(true, event.device)
			modo_control_cambiado.emit(true)
			return
		elif event is InputEventJoypadMotion and abs(event.axis_value) > 0.4:
			dispositivo_activo = event.device
			nombre_control = Input.get_joy_name(event.device)
			control_conectado = true
			modo_control_activo = true
			print("[GamepadManager] Movimiento de control recibido en dispositivo ", event.device, " -> Marcando como conectado.")
			control_conectado_cambiado.emit(true, event.device)
			modo_control_cambiado.emit(true)
			return

	# 2. Alternancia dinámica entre Táctil y Mando cuando hay un control conectado:
	if control_conectado:
		# Si se toca o arrastra en la pantalla (o clic con mouse simulando toque) -> Mostrar HUD táctil
		if (event is InputEventScreenTouch and event.is_pressed()) or event is InputEventScreenDrag or (event is InputEventMouseButton and event.is_pressed()):
			if modo_control_activo:
				modo_control_activo = false
				print("[GamepadManager] Toque en pantalla detectado -> Mostrando HUD táctil.")
				modo_control_cambiado.emit(false)
		# Si se presiona cualquier botón o se mueve un stick con intención (> 0.25) -> Ocultar HUD táctil
		elif (event is InputEventJoypadButton and event.is_pressed()) or (event is InputEventJoypadMotion and abs(event.axis_value) > 0.25):
			if not modo_control_activo:
				modo_control_activo = true
				print("[GamepadManager] Entrada física de control detectada -> Ocultando HUD táctil.")
				modo_control_cambiado.emit(true)

func hay_control_conectado() -> bool:
	return control_conectado

func esta_modo_control_activo() -> bool:
	return control_conectado and modo_control_activo

func debe_ocultar_hud_tactil() -> bool:
	return control_conectado and modo_control_activo

func obtener_nombre_control() -> String:
	if not control_conectado:
		return "Ninguno"
	if nombre_control.strip_edges().is_empty():
		return "Control Compatible"
	return nombre_control

# ===================================================================
# GESTIÓN DE CONFIGURACIÓN Y PERSISTENCIA (user://opciones.cfg)
# ===================================================================

func obtener_defaults() -> Dictionary:
	var defs: Dictionary = {}
	for item in ACCIONES_CONFIGURABLES:
		defs[item["id"]] = {
			"tipo": item["tipo_defecto"],
			"indice": item["indice_defecto"]
		}
	return defs

func cargar_config() -> void:
	var config_file = ConfigFile.new()
	var err = config_file.load(CONFIG_PATH)
	var defaults = obtener_defaults()
	mapeos_actuales = defaults.duplicate(true)
	
	if err == OK and config_file.has_section(SECTION_GAMEPAD):
		for item in ACCIONES_CONFIGURABLES:
			var id_act = item["id"]
			if config_file.has_section_key(SECTION_GAMEPAD, id_act + "_tipo") and config_file.has_section_key(SECTION_GAMEPAD, id_act + "_indice"):
				var t = str(config_file.get_value(SECTION_GAMEPAD, id_act + "_tipo", item["tipo_defecto"]))
				var idx = int(config_file.get_value(SECTION_GAMEPAD, id_act + "_indice", item["indice_defecto"]))
				mapeos_actuales[id_act] = {
					"tipo": t,
					"indice": idx
				}

func guardar_config() -> void:
	var config_file = ConfigFile.new()
	var _err = config_file.load(CONFIG_PATH)
	
	for id_act in mapeos_actuales.keys():
		var data = mapeos_actuales[id_act]
		config_file.set_value(SECTION_GAMEPAD, id_act + "_tipo", data.get("tipo", "button"))
		config_file.set_value(SECTION_GAMEPAD, id_act + "_indice", data.get("indice", 0))
		
	var save_err = config_file.save(CONFIG_PATH)
	if save_err == OK:
		print("[GamepadManager] Mapeos de control guardados en: ", CONFIG_PATH)
	else:
		push_error("[GamepadManager] Error al guardar mapeos de control: " + str(save_err))

func restablecer_predeterminados() -> void:
	mapeos_actuales = obtener_defaults()
	guardar_config()
	aplicar_mapeos_a_inputmap()
	mapeo_actualizado.emit()
	print("[GamepadManager] Mapeos restablecidos a los valores predeterminados.")

func asignar_mapeo(id_accion: String, tipo: String, indice: int) -> void:
	if not mapeos_actuales.has(id_accion):
		return
		
	# Si otra acción configurable ya tenía este botón o gatillo, intercambiar (swap)
	var accion_en_conflicto = ""
	for otra_id in mapeos_actuales.keys():
		if otra_id != id_accion:
			var mapa = mapeos_actuales[otra_id]
			if mapa.get("tipo") == tipo and mapa.get("indice") == indice:
				accion_en_conflicto = otra_id
				break
				
	if accion_en_conflicto != "":
		var previo_de_esta = mapeos_actuales[id_accion]
		mapeos_actuales[accion_en_conflicto] = {
			"tipo": previo_de_esta.get("tipo", "button"),
			"indice": previo_de_esta.get("indice", JOY_BUTTON_A)
		}
		print("[GamepadManager] Conflicto resuelto: Intercambiado con '", accion_en_conflicto, "'")
		
	mapeos_actuales[id_accion] = {
		"tipo": tipo,
		"indice": indice
	}
	
	guardar_config()
	aplicar_mapeos_a_inputmap()
	mapeo_actualizado.emit()

# ===================================================================
# APLICACIÓN AL INPUTMAP DEL MOTOR
# ===================================================================

func aplicar_mapeos_a_inputmap() -> void:
	# 1. Asegurar movimiento analógico (Stick Izquierdo) y D-Pad
	_configurar_movimiento_por_defecto()
	
	# 2. Asegurar navegación de UI en menús con A (Aceptar), B (Volver/Cancelar), D-Pad y Stick
	_configurar_acciones_ui_mando()
	
	# 3. Configurar botones de acción
	for item in ACCIONES_CONFIGURABLES:
		var id_act: String = item["id"]
		if not InputMap.has_action(id_act):
			InputMap.add_action(id_act, 0.2)
			
		# Eliminar eventos de joypad anteriores de esta acción
		for ev in InputMap.action_get_events(id_act):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				InputMap.action_erase_event(id_act, ev)
				
		var cfg = mapeos_actuales.get(id_act, {"tipo": item["tipo_defecto"], "indice": item["indice_defecto"]})
		var tipo: String = cfg.get("tipo", "button")
		var indice: int = cfg.get("indice", 0)
		
		if tipo == "button":
			var btn_ev = InputEventJoypadButton.new()
			btn_ev.device = -1
			btn_ev.button_index = indice
			InputMap.action_add_event(id_act, btn_ev)
		elif tipo == "axis":
			var axis_ev = InputEventJoypadMotion.new()
			axis_ev.device = -1
			axis_ev.axis = indice
			axis_ev.axis_value = 1.0
			InputMap.action_add_event(id_act, axis_ev)
			
		# Respaldo de teclas de teclado
		_asegurar_teclas_respaldo(id_act)

func _configurar_movimiento_por_defecto() -> void:
	_asegurar_evento_movimiento("mover_izquierda", JOY_AXIS_LEFT_X, -1.0, JOY_BUTTON_DPAD_LEFT, KEY_A, KEY_LEFT)
	_asegurar_evento_movimiento("mover_derecha", JOY_AXIS_LEFT_X, 1.0, JOY_BUTTON_DPAD_RIGHT, KEY_D, KEY_RIGHT)
	_asegurar_evento_movimiento("mover_adelante", JOY_AXIS_LEFT_Y, -1.0, JOY_BUTTON_DPAD_UP, KEY_W, KEY_UP)
	_asegurar_evento_movimiento("mover_atras", JOY_AXIS_LEFT_Y, 1.0, JOY_BUTTON_DPAD_DOWN, KEY_S, KEY_DOWN)

func _asegurar_evento_movimiento(accion: String, axis: JoyAxis, axis_val: float, dpad_btn: JoyButton, key1: Key, key2: Key) -> void:
	if not InputMap.has_action(accion):
		InputMap.add_action(accion, 0.2)
		
	var tiene_motion = false
	var tiene_dpad = false
	var tiene_k1 = false
	var tiene_k2 = false
	
	for ev in InputMap.action_get_events(accion):
		if ev is InputEventJoypadMotion and ev.axis == axis and sign(ev.axis_value) == sign(axis_val):
			tiene_motion = true
		elif ev is InputEventJoypadButton and ev.button_index == dpad_btn:
			tiene_dpad = true
		elif ev is InputEventKey:
			if ev.physical_keycode == key1 or ev.keycode == key1:
				tiene_k1 = true
			if ev.physical_keycode == key2 or ev.keycode == key2:
				tiene_k2 = true
				
	if not tiene_motion:
		var motion = InputEventJoypadMotion.new()
		motion.device = -1
		motion.axis = axis
		motion.axis_value = axis_val
		InputMap.action_add_event(accion, motion)
		
	if not tiene_dpad:
		var dpad = InputEventJoypadButton.new()
		dpad.device = -1
		dpad.button_index = dpad_btn
		InputMap.action_add_event(accion, dpad)
		
	if not tiene_k1:
		var k1 = InputEventKey.new()
		k1.physical_keycode = key1
		InputMap.action_add_event(accion, k1)
		
	if not tiene_k2:
		var k2 = InputEventKey.new()
		k2.physical_keycode = key2
		InputMap.action_add_event(accion, k2)

func _asegurar_teclas_respaldo(id_act: String) -> void:
	match id_act:
		"pausa":
			_asegurar_tecla(id_act, KEY_ESCAPE)
		"centrar_camara":
			_asegurar_tecla(id_act, KEY_R)
		"saltar":
			_asegurar_tecla(id_act, KEY_SPACE)
		"interactuar":
			_asegurar_tecla(id_act, KEY_E)
		"cambiar_personaje":
			_asegurar_tecla(id_act, KEY_TAB)
			_asegurar_tecla(id_act, KEY_C)

func _asegurar_tecla(accion: String, keycode: Key) -> void:
	for ev in InputMap.action_get_events(accion):
		if ev is InputEventKey and (ev.physical_keycode == keycode or ev.keycode == keycode):
			return
	var key_ev = InputEventKey.new()
	key_ev.physical_keycode = keycode
	InputMap.action_add_event(accion, key_ev)

func _configurar_acciones_ui_mando() -> void:
	# Botón A: Aceptar / Seleccionar
	_asegurar_evento_joy_action("ui_accept", JOY_BUTTON_A)
	_asegurar_evento_joy_action("ui_select", JOY_BUTTON_A)
	
	# Botón B: Cancelar / Volver
	_asegurar_evento_joy_action("ui_cancel", JOY_BUTTON_B)
	
	# D-Pad y Stick Izquierdo para navegación direccional en menús
	_asegurar_evento_joy_action("ui_up", JOY_BUTTON_DPAD_UP)
	_asegurar_evento_joy_action("ui_down", JOY_BUTTON_DPAD_DOWN)
	_asegurar_evento_joy_action("ui_left", JOY_BUTTON_DPAD_LEFT)
	_asegurar_evento_joy_action("ui_right", JOY_BUTTON_DPAD_RIGHT)
	_asegurar_evento_joy_motion("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_asegurar_evento_joy_motion("ui_down", JOY_AXIS_LEFT_Y, 1.0)
	_asegurar_evento_joy_motion("ui_left", JOY_AXIS_LEFT_X, -1.0)
	_asegurar_evento_joy_motion("ui_right", JOY_AXIS_LEFT_X, 1.0)

func _asegurar_evento_joy_action(accion: String, boton: JoyButton) -> void:
	if not InputMap.has_action(accion):
		InputMap.add_action(accion, 0.2)
	var tiene = false
	for ev in InputMap.action_get_events(accion):
		if ev is InputEventJoypadButton and ev.button_index == boton:
			tiene = true
			break
	if not tiene:
		var btn_ev = InputEventJoypadButton.new()
		btn_ev.device = -1
		btn_ev.button_index = boton
		InputMap.action_add_event(accion, btn_ev)

func _asegurar_evento_joy_motion(accion: String, axis: JoyAxis, axis_val: float) -> void:
	if not InputMap.has_action(accion):
		InputMap.add_action(accion, 0.2)
	var tiene = false
	for ev in InputMap.action_get_events(accion):
		if ev is InputEventJoypadMotion and ev.axis == axis and sign(ev.axis_value) == sign(axis_val):
			tiene = true
			break
	if not tiene:
		var motion_ev = InputEventJoypadMotion.new()
		motion_ev.device = -1
		motion_ev.axis = axis
		motion_ev.axis_value = axis_val
		InputMap.action_add_event(accion, motion_ev)

# ===================================================================
# FORMATO Y NOMBRES LEGIBLES PARA LA INTERFAZ
# ===================================================================

static func obtener_texto_boton(tipo: String, indice: int) -> String:
	if tipo == "axis":
		match indice:
			JOY_AXIS_TRIGGER_LEFT: return "LT / L2 (Gatillo Izq.)"
			JOY_AXIS_TRIGGER_RIGHT: return "RT / R2 (Gatillo Der.)"
			JOY_AXIS_LEFT_X: return "Stick Izquierdo (X)"
			JOY_AXIS_LEFT_Y: return "Stick Izquierdo (Y)"
			JOY_AXIS_RIGHT_X: return "Stick Derecho (X)"
			JOY_AXIS_RIGHT_Y: return "Stick Derecho (Y)"
			_: return "Gatillo " + str(indice)
	elif tipo == "button":
		match indice:
			JOY_BUTTON_A: return "A / ✕ (Cruz)"
			JOY_BUTTON_B: return "B / ○ (Círculo)"
			JOY_BUTTON_X: return "X / □ (Cuadrado)"
			JOY_BUTTON_Y: return "Y / △ (Triángulo)"
			JOY_BUTTON_BACK: return "Back / Select / Share"
			JOY_BUTTON_START: return "Start / Options / Menú"
			JOY_BUTTON_LEFT_STICK: return "L3 (Stick Izq.)"
			JOY_BUTTON_RIGHT_STICK: return "R3 (Stick Der.)"
			JOY_BUTTON_LEFT_SHOULDER: return "LB / L1"
			JOY_BUTTON_RIGHT_SHOULDER: return "RB / R1"
			JOY_BUTTON_DPAD_UP: return "D-Pad Arriba"
			JOY_BUTTON_DPAD_DOWN: return "D-Pad Abajo"
			JOY_BUTTON_DPAD_LEFT: return "D-Pad Izquierda"
			JOY_BUTTON_DPAD_RIGHT: return "D-Pad Derecha"
			JOY_BUTTON_GUIDE: return "Guía / Home"
			JOY_BUTTON_MISC1: return "Captura / Compartir"
			_: return "Botón " + str(indice)
	return "Sin Asignar"
