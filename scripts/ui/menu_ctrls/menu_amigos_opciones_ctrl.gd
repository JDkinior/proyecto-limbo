extends Node
class_name MenuAmigosOpcionesCtrl

var menu: Control

func init(p_menu: Control):
	menu = p_menu
	_conectar_senales()
	_cargar_opciones()
	_actualizar_lista_amigos()

func _conectar_senales():
	var btn_add = menu.get_node_or_null("PanelAmigos/VBoxContainer/HBoxAdd/BtnAgregar")
	if is_instance_valid(btn_add):
		btn_add.pressed.connect(_on_btn_agregar_amigo_pressed)
		
	var btn_del = menu.get_node_or_null("PanelAmigos/VBoxContainer/BtnEliminar")
	if is_instance_valid(btn_del):
		btn_del.pressed.connect(_on_btn_eliminar_amigo_pressed)
		
	var btn_vol_amigos = menu.get_node_or_null("PanelAmigos/VBoxContainer/BtnVolver")
	if is_instance_valid(btn_vol_amigos):
		btn_vol_amigos.pressed.connect(_on_btn_volver_amigos_pressed)
	
	if is_instance_valid(menu.volume_slider):
		menu.volume_slider.value_changed.connect(_on_volume_slider_value_changed)
	if is_instance_valid(menu.btn_fullscreen):
		menu.btn_fullscreen.toggled.connect(_on_btn_fullscreen_toggled)
		
	var btn_volver_opc = menu.get_node_or_null("PanelOpciones/VBoxContainer/BtnVolver")
	if is_instance_valid(btn_volver_opc):
		btn_volver_opc.pressed.connect(_on_btn_volver_opciones_pressed)
		
	# Controles de Personalización del HUD
	if is_instance_valid(menu.btn_ajustar_hud):
		menu.btn_ajustar_hud.pressed.connect(_on_btn_ajustar_hud_pressed)
	if is_instance_valid(menu.slider_tamano_hud):
		menu.slider_tamano_hud.value_changed.connect(_on_slider_tamano_hud_changed)
	if is_instance_valid(menu.slider_tamano_joy):
		menu.slider_tamano_joy.value_changed.connect(_on_slider_tamano_joy_changed)

func _on_btn_agregar_amigo_pressed():
	var nombre = menu.amigo_nombre_input.text.strip_edges()
	var ip = menu.amigo_ip_input.text.strip_edges()
	if nombre.is_empty() or ip.is_empty():
		return
		
	if not is_instance_valid(menu) or not menu.is_inside_tree(): return
	var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
	if is_instance_valid(RedManager):
		RedManager.agregar_amigo(nombre, ip)
		menu.amigo_nombre_input.clear()
		menu.amigo_ip_input.clear()
		_actualizar_lista_amigos()

func _actualizar_lista_amigos():
	if not is_instance_valid(menu) or not menu.is_inside_tree(): return
	var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
	if not is_instance_valid(RedManager): return
	
	menu.amigos_dict = RedManager.cargar_amigos()
	menu.lista_amigos.clear()
	
	menu.quick_join_option.clear()
	menu.quick_join_option.add_item("Seleccionar Amigo Rápido...")
	
	for nombre in menu.amigos_dict:
		var ip = menu.amigos_dict[nombre]
		menu.lista_amigos.add_item(nombre + " (" + ip + ")")
		menu.quick_join_option.add_item(nombre)

func _on_btn_eliminar_amigo_pressed():
	var selected_idx = menu.lista_amigos.get_selected_items()
	if selected_idx.size() > 0:
		var texto = menu.lista_amigos.get_item_text(selected_idx[0])
		var nombre = texto.split(" (")[0]
		if not is_instance_valid(menu) or not menu.is_inside_tree(): return
		var RedManager = menu.get_tree().root.get_node_or_null("RedManager")
		if is_instance_valid(RedManager):
			RedManager.eliminar_amigo(nombre)
			_actualizar_lista_amigos()

func _on_btn_volver_amigos_pressed():
	menu.mostrar_panel(menu.panel_principal)

func _on_volume_slider_value_changed(value):
	var bus_index = AudioServer.get_bus_index("Master")
	if bus_index != -1:
		var db = linear_to_db(value)
		AudioServer.set_bus_volume_db(bus_index, db)
		_guardar_opciones()

func _on_btn_fullscreen_toggled(button_pressed):
	if button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_guardar_opciones()

func _on_btn_volver_opciones_pressed():
	menu.mostrar_panel(menu.panel_principal)

func _on_btn_ajustar_hud_pressed():
	var escena_editor = load("res://scenes/ui/ajuste_hud.tscn")
	if escena_editor:
		var editor = escena_editor.instantiate()
		menu.add_child(editor)
		editor.cerrado.connect(func():
			_cargar_opciones()
		)

func _on_slider_tamano_hud_changed(val: float):
	var cfg = HudConfigManager.cargar_config()
	cfg["botones_accion_scale"] = val
	HudConfigManager.guardar_config(cfg)

func _on_slider_tamano_joy_changed(val: float):
	var cfg = HudConfigManager.cargar_config()
	cfg["joystick_scale"] = val
	HudConfigManager.guardar_config(cfg)

func _guardar_opciones():
	var config = ConfigFile.new()
	var _err = config.load("user://opciones.cfg")
	var bus_index = AudioServer.get_bus_index("Master")
	if bus_index != -1:
		config.set_value("audio", "master_volume", db_to_linear(AudioServer.get_bus_volume_db(bus_index)))
	config.set_value("video", "fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	config.save("user://opciones.cfg")

func _cargar_opciones():
	var config = ConfigFile.new()
	var err = config.load("user://opciones.cfg")
	if err == OK:
		var vol = config.get_value("audio", "master_volume", 0.8)
		if is_instance_valid(menu.volume_slider):
			menu.volume_slider.value = vol
		var bus_index = AudioServer.get_bus_index("Master")
		if bus_index != -1:
			AudioServer.set_bus_volume_db(bus_index, linear_to_db(vol))
			
		var fs = config.get_value("video", "fullscreen", false)
		if is_instance_valid(menu.btn_fullscreen):
			menu.btn_fullscreen.button_pressed = fs
		if fs:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		if is_instance_valid(menu.volume_slider):
			menu.volume_slider.value = 0.8
		if is_instance_valid(menu.btn_fullscreen):
			menu.btn_fullscreen.button_pressed = false
			
	# Cargar valores del HUD a los sliders de opciones
	var hud_cfg = HudConfigManager.cargar_config()
	if is_instance_valid(menu.slider_tamano_hud):
		menu.slider_tamano_hud.set_value_no_signal(hud_cfg.get("botones_accion_scale", 1.39))
	if is_instance_valid(menu.slider_tamano_joy):
		menu.slider_tamano_joy.set_value_no_signal(hud_cfg.get("joystick_scale", 1.0))
