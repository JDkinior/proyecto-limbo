extends RefCounted
class_name HudConfigManager

const CONFIG_PATH = "user://opciones.cfg"
const SECTION_HUD = "hud"

# Constantes de configuración por defecto
const DEFAULT_CONFIG: Dictionary = {
	# Joystick Virtual
	"joystick_pos_ratio_x": 0.15,
	"joystick_pos_ratio_y": 0.75,
	"joystick_scale": 1.0,
	"joystick_size": 200.0,
	
	# Grupo de Botones de Acción
	"botones_accion_pos_ratio_x": 0.84,
	"botones_accion_pos_ratio_y": 0.75,
	"botones_accion_scale": 1.39,
	
	# Desplazamientos individuales de botones (relativos al centro del grupo de acción)
	"btn_saltar_offset_x": 40.0,
	"btn_saltar_offset_y": 51.0,
	"btn_saltar_scale": 1.0,
	
	"btn_interactuar_offset_x": 40.0,
	"btn_interactuar_offset_y": -51.0,
	"btn_interactuar_scale": 1.0,
	
	"btn_cambiar_offset_x": -45.0,
	"btn_cambiar_offset_y": 0.0,
	"btn_cambiar_scale": 1.0,
	
	# Botón de Pausa
	"btn_pausa_pos_ratio_x": 0.92,
	"btn_pausa_pos_ratio_y": 0.06,
	"btn_pausa_scale": 1.0,
	
	# Opacidad de Controles
	"hud_opacidad": 1.0
}

static func obtener_defaults() -> Dictionary:
	return DEFAULT_CONFIG.duplicate(true)

static func cargar_config() -> Dictionary:
	var cfg = obtener_defaults()
	var config_file = ConfigFile.new()
	var err = config_file.load(CONFIG_PATH)
	
	if err == OK and config_file.has_section(SECTION_HUD):
		for clave in DEFAULT_CONFIG.keys():
			if config_file.has_section_key(SECTION_HUD, clave):
				cfg[clave] = config_file.get_value(SECTION_HUD, clave, DEFAULT_CONFIG[clave])
	return cfg

static func guardar_config(nueva_config: Dictionary) -> void:
	var config_file = ConfigFile.new()
	# Cargar archivo existente para no sobreescribir otras secciones (audio, video, etc.)
	var _err = config_file.load(CONFIG_PATH)
	
	for clave in DEFAULT_CONFIG.keys():
		if nueva_config.has(clave):
			config_file.set_value(SECTION_HUD, clave, nueva_config[clave])
		elif not config_file.has_section_key(SECTION_HUD, clave):
			config_file.set_value(SECTION_HUD, clave, DEFAULT_CONFIG[clave])
			
	var save_err = config_file.save(CONFIG_PATH)
	if save_err == OK:
		print("[HudConfigManager] Configuración de HUD guardada con éxito en: ", CONFIG_PATH)
	else:
		push_error("[HudConfigManager] Error al guardar configuración de HUD: " + str(save_err))

static func aplicar_a_hud(hud_root: Control, custom_cfg: Dictionary = {}) -> void:
	if not is_instance_valid(hud_root) or not hud_root.is_inside_tree():
		return
		
	var cfg = custom_cfg if not custom_cfg.is_empty() else cargar_config()
	var screen_size = hud_root.get_viewport_rect().size
	if screen_size.x <= 0 or screen_size.y <= 0:
		screen_size = Vector2(1080, 720)

	# 1. Aplicar a Joystick Virtual
	var joystick = hud_root.get_node_or_null("Joystick_Virtual")
	if is_instance_valid(joystick):
		var j_scale: float = cfg.get("joystick_scale", 1.0)
		var j_size: float = cfg.get("joystick_size", 200.0)
		if "joystick_size" in joystick:
			joystick.joystick_size = j_size * j_scale
		if "tip_size" in joystick:
			joystick.tip_size = (j_size * 0.35) * j_scale
		
		# Ajustar offset inicial en cuadrante inferior izquierdo o posición
		var target_j_x: float = cfg.get("joystick_pos_ratio_x", 0.15) * screen_size.x
		var target_j_y: float = cfg.get("joystick_pos_ratio_y", 0.75) * screen_size.y
		
		# Si joystick usa initial_offset_ratio
		if "initial_offset_ratio" in joystick:
			# El joystick por defecto abarca de x:[0, screen.x*0.5], y:[screen.y*0.5, screen.y]
			var quad_w = maxf(screen_size.x * 0.5, 1.0)
			var quad_h = maxf(screen_size.y * 0.5, 1.0)
			var ratio_x = clampf(target_j_x / quad_w, 0.05, 0.95)
			var ratio_y = clampf((target_j_y - screen_size.y * 0.5) / quad_h, 0.05, 0.95)
			joystick.initial_offset_ratio = Vector2(ratio_x, ratio_y)

	# 2. Aplicar a Grupo de Botones de Acción
	var area_camara = hud_root.get_node_or_null("Area_Camara")
	if is_instance_valid(area_camara):
		area_camara.scale = Vector2.ONE

	var zona_botones = hud_root.get_node_or_null("Area_Camara/Zona_Botones_Accion")
	if not is_instance_valid(zona_botones):
		zona_botones = hud_root.find_child("Zona_Botones_Accion", true, false)
		
	if is_instance_valid(zona_botones):
		var btn_scale: float = cfg.get("botones_accion_scale", 1.39)
		zona_botones.scale = Vector2(btn_scale, btn_scale)
		
		var target_bx: float = cfg.get("botones_accion_pos_ratio_x", 0.84) * screen_size.x
		var target_by: float = cfg.get("botones_accion_pos_ratio_y", 0.75) * screen_size.y
		zona_botones.global_position = Vector2(target_bx, target_by)

		# Botones individuales
		var btn_saltar = zona_botones.get_node_or_null("Boton_Saltar")
		if is_instance_valid(btn_saltar):
			btn_saltar.position = Vector2(
				cfg.get("btn_saltar_offset_x", 25.0),
				cfg.get("btn_saltar_offset_y", 42.0)
			)
			var s: float = cfg.get("btn_saltar_scale", 1.0)
			btn_saltar.scale = Vector2(s, s)
			
		var btn_interact = zona_botones.get_node_or_null("Boton_Interactuar")
		if is_instance_valid(btn_interact):
			btn_interact.position = Vector2(
				cfg.get("btn_interactuar_offset_x", 42.0),
				cfg.get("btn_interactuar_offset_y", -45.0)
			)
			var s: float = cfg.get("btn_interactuar_scale", 1.0)
			btn_interact.scale = Vector2(s, s)
			
		var btn_cambiar = zona_botones.get_node_or_null("Boton_Cambiar_Personaje")
		if is_instance_valid(btn_cambiar):
			btn_cambiar.position = Vector2(
				cfg.get("btn_cambiar_offset_x", -55.0),
				cfg.get("btn_cambiar_offset_y", -15.0)
			)
			var s: float = cfg.get("btn_cambiar_scale", 1.0)
			btn_cambiar.scale = Vector2(s, s)

	# 3. Aplicar a Botón de Pausa (HUD_Menu)
	var hud_menu = hud_root.get_node_or_null("HUD_Menu")
	if is_instance_valid(hud_menu):
		var p_scale: float = cfg.get("btn_pausa_scale", 1.0)
		hud_menu.scale = Vector2(p_scale, p_scale)
		var p_size_x = hud_menu.size.x if hud_menu.size.x > 0 else 120.0
		var target_px: float = cfg.get("btn_pausa_pos_ratio_x", 0.92) * screen_size.x - (p_size_x * 0.5 * p_scale)
		var target_py: float = cfg.get("btn_pausa_pos_ratio_y", 0.06) * screen_size.y
		hud_menu.global_position = Vector2(target_px, target_py)
		
	# 4. Modulación/Opacidad general si aplica
	var opacidad: float = cfg.get("hud_opacidad", 1.0)
	if is_instance_valid(joystick):
		joystick.modulate.a = opacidad
	if is_instance_valid(zona_botones):
		zona_botones.modulate.a = opacidad
