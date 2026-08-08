extends Node
class_name MenuAmigosOpcionesCtrl

var menu: Control

func init(p_menu: Control):
	menu = p_menu
	_conectar_senales()
	_cargar_opciones()
	_actualizar_lista_amigos()

func _conectar_senales():
	menu.get_node("PanelAmigos/VBoxContainer/HBoxAdd/BtnAgregar").pressed.connect(_on_btn_agregar_amigo_pressed)
	menu.get_node("PanelAmigos/VBoxContainer/BtnEliminar").pressed.connect(_on_btn_eliminar_amigo_pressed)
	menu.get_node("PanelAmigos/VBoxContainer/BtnVolver").pressed.connect(_on_btn_volver_amigos_pressed)
	
	menu.get_node("PanelOpciones/VBoxContainer/VolumeSlider").value_changed.connect(_on_volume_slider_value_changed)
	menu.get_node("PanelOpciones/VBoxContainer/BtnFullscreen").toggled.connect(_on_btn_fullscreen_toggled)
	menu.get_node("PanelOpciones/VBoxContainer/BtnVolver").pressed.connect(_on_btn_volver_opciones_pressed)

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

func _guardar_opciones():
	var config = ConfigFile.new()
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
		menu.volume_slider.value = vol
		var bus_index = AudioServer.get_bus_index("Master")
		if bus_index != -1:
			AudioServer.set_bus_volume_db(bus_index, linear_to_db(vol))
			
		var fs = config.get_value("video", "fullscreen", false)
		menu.btn_fullscreen.button_pressed = fs
		if fs:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		menu.volume_slider.value = 0.8
		menu.btn_fullscreen.button_pressed = false
