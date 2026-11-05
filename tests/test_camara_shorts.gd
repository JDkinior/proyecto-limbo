@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

func suite_name() -> String:
	return "camara_shorts"

func test_camara_config_manager_valores_predeterminados() -> void:
	var script = load("res://scripts/core/camara_config_manager.gd")
	assert_ne(script, null, "El script camara_config_manager.gd debe existir")
	var mgr = track(script.new())
	assert_true(mgr.esta_modo_shorts_activo(), "Por defecto debe estar activo el encuadre vertical")
	assert_true(abs(mgr.obtener_altura_spring_arm() - 0.65) < 0.01, "Altura predeterminada debe ser 0.65")
	assert_true(abs(mgr.obtener_distancia_camara() - 5.2) < 0.01, "Distancia predeterminada debe ser 5.2")
	assert_true(abs(mgr.obtener_pitch_defecto() - (-0.22)) < 0.01, "Pitch predeterminado debe ser -0.22")
	assert_true(abs(mgr.obtener_v_offset() - (-0.15)) < 0.01, "v_offset predeterminado debe ser -0.15")

func test_jugador_adopta_configuracion_camara() -> void:
	var scene = load("res://scenes/characters/jugador.tscn")
	assert_ne(scene, null, "La escena jugador.tscn debe existir")
	var jugador = track(scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)) as Node
	assert_ne(jugador, null, "Debe ser instancia de nodo")
	
	var spring_arm = jugador.get_node_or_null("Node3D/SpringArm3D") as SpringArm3D
	assert_ne(spring_arm, null, "El jugador debe tener SpringArm3D")
	assert_true(abs(spring_arm.spring_length - 5.2) < 0.01, "SpringArm3D debe tener longitud 5.2 (Shorts)")
	assert_true(abs(spring_arm.position.y - 0.65) < 0.01, "SpringArm3D debe tener altura 0.65 (Shorts)")
	
	var cam = jugador.get_node_or_null("Node3D/SpringArm3D/Camera3D") as Camera3D
	assert_ne(cam, null, "El jugador debe tener Camera3D")
	assert_true(abs(cam.v_offset - (-0.15)) < 0.01, "Camera3D debe tener v_offset -0.15 (Shorts)")

func test_ocultar_controles_opcion() -> void:
	var script = load("res://scripts/core/camara_config_manager.gd")
	var mgr = track(script.new())
	mgr.establecer_ocultar_controles(false)
	assert_false(mgr.esta_ocultar_controles_activo(), "Por defecto ocultar controles debe ser false")
	
	var activo = mgr.alternar_ocultar_controles()
	assert_true(activo, "Alternar debe activar ocultar controles")
	assert_true(mgr.esta_ocultar_controles_activo(), "Debe reportar activo")
	
	var inactivo = mgr.alternar_ocultar_controles()
	assert_false(inactivo, "Alternar de nuevo debe desactivar ocultar controles")
	assert_false(mgr.esta_ocultar_controles_activo(), "Debe reportar inactivo")
	
	# Restaurar
	mgr.establecer_ocultar_controles(false)

func test_controles_tactiles_elementos_y_pausa() -> void:
	var scene = ResourceLoader.load("res://scenes/ui/controles_tactiles.tscn", "PackedScene", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	assert_ne(scene, null, "La escena controles_tactiles.tscn debe existir")
	var ui = track(scene.instantiate()) as Control
	assert_ne(ui, null)
	
	var joy = ui.get_node_or_null("Joystick_Virtual")
	var zona = ui.get_node_or_null("Area_Camara/Zona_Botones_Accion")
	var hud_menu = ui.get_node_or_null("HUD_Menu")
	var btn_pausa = ui.get_node_or_null("HUD_Menu/Boton_Pausa")
	var btn_ocultar = ui.get_node_or_null("Panel_Ajustes_Video/VBoxContainer/Boton_Ocultar_Controles")
	
	assert_ne(joy, null, "Joystick debe existir")
	assert_ne(zona, null, "Zona botones debe existir")
	assert_ne(hud_menu, null, "HUD_Menu debe existir")
	assert_ne(btn_pausa, null, "Boton_Pausa debe existir")
	assert_ne(btn_ocultar, null, "Boton_Ocultar_Controles debe existir")
	assert_true(btn_ocultar.text.contains("Excepto Pausa"), "El texto del botón debe indicar que la pausa se mantiene")

func test_distancia_camara_ajuste_y_revertir() -> void:
	var script = load("res://scripts/core/camara_config_manager.gd")
	var mgr = track(script.new())
	
	# Comprobar valor por defecto
	assert_true(abs(mgr.obtener_distancia_camara() - 5.2) < 0.01, "Distancia predeterminada debe ser 5.2m")
	
	# Modificar distancia
	mgr.establecer_distancia_camara(8.5)
	assert_true(abs(mgr.obtener_distancia_camara() - 8.5) < 0.01, "La distancia debe ajustarse a 8.5m")
	
	# Clamp en límites (mínimo y máximo)
	mgr.establecer_distancia_camara(0.5)
	assert_true(mgr.obtener_distancia_camara() >= 1.8, "Debe limitar al valor mínimo (1.8m)")
	
	mgr.establecer_distancia_camara(20.0)
	assert_true(mgr.obtener_distancia_camara() <= 12.0, "Debe limitar al valor máximo (12.0m)")
	
	# Revertir cambios
	mgr.revertir_ajustes_camara()
	assert_true(abs(mgr.obtener_distancia_camara() - 5.2) < 0.01, "Revertir debe restaurar la distancia a 5.2m")

func test_altura_camara_ajuste_y_revertir() -> void:
	var script = load("res://scripts/core/camara_config_manager.gd")
	var mgr = track(script.new())
	
	# Comprobar valor por defecto
	assert_true(abs(mgr.obtener_altura_spring_arm() - 0.65) < 0.01, "Altura predeterminada debe ser 0.65m")
	
	# Modificar altura
	mgr.establecer_altura_camara(2.4)
	assert_true(abs(mgr.obtener_altura_spring_arm() - 2.4) < 0.01, "La altura debe ajustarse a 2.4m")
	
	# Clamp en límites
	mgr.establecer_altura_camara(-5.0)
	assert_true(mgr.obtener_altura_spring_arm() >= -1.0, "Debe limitar al mínimo (-1.0m)")
	
	mgr.establecer_altura_camara(10.0)
	assert_true(mgr.obtener_altura_spring_arm() <= 3.5, "Debe limitar al máximo (3.5m)")
	
	# Revertir
	mgr.revertir_ajustes_camara()
	assert_true(abs(mgr.obtener_altura_spring_arm() - 0.65) < 0.01, "Revertir debe restaurar la altura a 0.65m")

func test_camara_estatica_activar_desactivar() -> void:
	var script = load("res://scripts/core/camara_config_manager.gd")
	var mgr = track(script.new())
	
	assert_false(mgr.esta_camara_estatica(), "Por defecto la cámara estática debe estar desactivada")
	
	var pos_fija = Vector3(10.0, 5.0, -15.0)
	var rot_fija = Vector3(0.0, 1.5, 0.0)
	mgr.fijar_camara_estatica(pos_fija, rot_fija, -0.3)
	
	assert_true(mgr.esta_camara_estatica(), "Cámara estática debe estar activa tras fijar")
	assert_true(mgr.obtener_posicion_camara_estatica().is_equal_approx(pos_fija), "La posición fija debe coincidir")
	assert_true(mgr.obtener_rotacion_camara_estatica().is_equal_approx(rot_fija), "La rotación fija debe coincidir")
	assert_true(abs(mgr.obtener_rot_x_arm_estatica() - (-0.3)) < 0.01, "El pitch del brazo debe coincidir")
	
	# Desactivar
	mgr.desactivar_camara_estatica()
	assert_false(mgr.esta_camara_estatica(), "Cámara estática debe desactivarse correctamente")
	
	# Revertir limpia estado estático
	mgr.fijar_camara_estatica(pos_fija, rot_fija)
	mgr.revertir_ajustes_camara()
	assert_false(mgr.esta_camara_estatica(), "Revertir debe desactivar la cámara estática")
	assert_true(mgr.es_configuracion_por_defecto(), "Debe reportar configuración por defecto tras revertir")

func test_panel_camara_tomas_elementos_ui() -> void:
	var scene = ResourceLoader.load("res://scenes/ui/controles_tactiles.tscn", "PackedScene", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	assert_ne(scene, null, "La escena controles_tactiles.tscn debe existir")
	var ui = track(scene.instantiate()) as Control
	assert_ne(ui, null)
	
	var btn_pausa_cam = ui.get_node_or_null("Panel_Pausa/VBoxContainer/Boton_Camara_Tomas")
	assert_ne(btn_pausa_cam, null, "El botón de tomas en Panel_Pausa debe existir")
	
	var panel_cam = ui.get_node_or_null("Panel_Camara_Tomas")
	assert_ne(panel_cam, null, "Panel_Camara_Tomas debe existir")
	
	var slider_dist = ui.get_node_or_null("Panel_Camara_Tomas/VBoxContainer/Slider_Distancia")
	assert_ne(slider_dist, null, "Slider de distancia debe existir")
	
	var slider_alt = ui.get_node_or_null("Panel_Camara_Tomas/VBoxContainer/Slider_Altura")
	assert_ne(slider_alt, null, "Slider de altura debe existir")
	
	var btn_est = ui.get_node_or_null("Panel_Camara_Tomas/VBoxContainer/Boton_Camara_Estatica")
	assert_ne(btn_est, null, "Botón de cámara estática debe existir")
	
	var btn_rev = ui.get_node_or_null("Panel_Camara_Tomas/VBoxContainer/Boton_Revertir_Camara")
	assert_ne(btn_rev, null, "Botón de revertir ajustes de cámara debe existir")
	
	var btn_hud_rapido = ui.get_node_or_null("Panel_Camara_Tomas/VBoxContainer/Boton_Toggle_HUD_Rapido")
	assert_ne(btn_hud_rapido, null, "Botón de activar acceso rápido en HUD debe existir")
	
	var btn_cerrar = ui.get_node_or_null("Panel_Camara_Tomas/VBoxContainer/Boton_Cerrar_Camara_Tomas")
	assert_ne(btn_cerrar, null, "Botón de cerrar panel debe existir")
	
	# Verificar que botones de HUD nunca capturen foco (evitar interferencia con botón A de salto en mando)
	var btn_cam_rapida = ui.get_node_or_null("HUD_Boton_Camara/Boton_Camara_Rapida") as Button
	assert_ne(btn_cam_rapida, null, "Boton_Camara_Rapida debe existir")
	assert_eq(btn_cam_rapida.focus_mode, Control.FOCUS_NONE, "Boton_Camara_Rapida no debe capturar foco para no colisionar con salto en mando")
	
	var btn_pausa = ui.get_node_or_null("HUD_Menu/Boton_Pausa") as Button
	assert_ne(btn_pausa, null, "Boton_Pausa debe existir")
	assert_eq(btn_pausa.focus_mode, Control.FOCUS_NONE, "Boton_Pausa no debe capturar foco para no colisionar con salto en mando")

func test_atajos_teclado_camara_shorts() -> void:
	var script = load("res://scripts/core/camara_config_manager.gd")
	var mgr = track(script.new())
	assert_true(mgr.has_method("procesar_input_camara"), "CamaraConfigManager debe implementar procesar_input_camara")
	
	# 1. Probar atajo '*' para alternar guía de proporción de Shorts
	mgr.establecer_guia_activa(false)
	var ev_star = InputEventKey.new()
	ev_star.keycode = KEY_ASTERISK
	ev_star.pressed = true
	ev_star.echo = false
	var manejado_star = mgr.procesar_input_camara(ev_star)
	assert_true(manejado_star, "Tecla '*' debe ser procesada")
	assert_true(mgr.esta_guia_activa(), "La tecla '*' debe activar la guía 9:16 de Shorts")
	
	mgr.procesar_input_camara(ev_star)
	assert_false(mgr.esta_guia_activa(), "La tecla '*' debe alternar y desactivar la guía 9:16 de Shorts")
	
	# 2. Probar atajo '+' (Zoom In / Acercar distancia)
	mgr.establecer_distancia_camara(5.2)
	var ev_plus = InputEventKey.new()
	ev_plus.keycode = KEY_PLUS
	ev_plus.pressed = true
	ev_plus.echo = false
	var manejado_plus = mgr.procesar_input_camara(ev_plus)
	assert_true(manejado_plus, "Tecla '+' debe ser procesada")
	assert_true(abs(mgr.obtener_distancia_camara() - 4.8) < 0.01, "La tecla '+' debe acercar la cámara (zoom in)")
	
	# 3. Probar atajo '-' (Zoom Out / Alejar distancia)
	var ev_minus = InputEventKey.new()
	ev_minus.keycode = KEY_MINUS
	ev_minus.pressed = true
	ev_minus.echo = false
	var manejado_minus = mgr.procesar_input_camara(ev_minus)
	assert_true(manejado_minus, "Tecla '-' debe ser procesada")
	assert_true(abs(mgr.obtener_distancia_camara() - 5.2) < 0.01, "La tecla '-' debe alejar la cámara (zoom out)")
	
	# 4. Probar atajo '8' (Subir altura)
	mgr.establecer_altura_camara(0.65)
	var ev_8 = InputEventKey.new()
	ev_8.keycode = KEY_8
	ev_8.pressed = true
	ev_8.echo = false
	var manejado_8 = mgr.procesar_input_camara(ev_8)
	assert_true(manejado_8, "Tecla '8' debe ser procesada")
	assert_true(abs(mgr.obtener_altura_spring_arm() - 0.85) < 0.01, "La tecla '8' debe elevar la altura de la cámara")
	
	# 5. Probar atajo '2' (Bajar altura)
	var ev_2 = InputEventKey.new()
	ev_2.keycode = KEY_2
	ev_2.pressed = true
	ev_2.echo = false
	var manejado_2 = mgr.procesar_input_camara(ev_2)
	assert_true(manejado_2, "Tecla '2' debe ser procesada")
	assert_true(abs(mgr.obtener_altura_spring_arm() - 0.65) < 0.01, "La tecla '2' debe bajar la altura de la cámara")
	
	# Restaurar
	mgr.revertir_ajustes_camara()
	mgr.establecer_guia_activa(false)

func test_camara_estatica_mover_y_posicion() -> void:
	var script = load("res://scripts/core/camara_config_manager.gd")
	var mgr = track(script.new())
	
	var pos_inicial = Vector3(5.0, 3.0, 10.0)
	mgr.fijar_camara_estatica(pos_inicial, Vector3.ZERO)
	assert_true(mgr.esta_camara_estatica())
	assert_true(mgr.obtener_posicion_camara_estatica().is_equal_approx(pos_inicial))
	
	# Mover posición estática (ej. con joystick)
	var delta_mov = Vector3(1.5, 0.5, -2.0)
	mgr.mover_posicion_camara_estatica(delta_mov)
	assert_true(mgr.obtener_posicion_camara_estatica().is_equal_approx(pos_inicial + delta_mov), "La posición de la cámara estática debe actualizarse con el desplazamiento del joystick")
	
	# Establecer posición directa
	var pos_directa = Vector3(-4.0, 2.0, 8.0)
	mgr.establecer_posicion_camara_estatica(pos_directa)
	assert_true(mgr.obtener_posicion_camara_estatica().is_equal_approx(pos_directa), "establecer_posicion_camara_estatica debe asignar la posición exacta")
	
	mgr.desactivar_camara_estatica()

func test_posesion_camara_estatica_mantiene_zoom() -> void:
	var script_mgr = load("res://scripts/core/camara_config_manager.gd")
	var mgr = track(script_mgr.new())
	
	mgr.establecer_distancia_camara(5.2)
	mgr.establecer_altura_camara(0.65)
	
	# Activar cámara estática
	mgr.fijar_camara_estatica(Vector3(10.0, 5.0, 10.0), Vector3.ZERO)
	assert_true(mgr.esta_camara_estatica())
	
	# Comprobar que los parámetros deseados permanecen constantes en 5.2m y 0.65m
	assert_true(abs(mgr.obtener_distancia_camara() - 5.2) < 0.01, "La distancia de cámara con cámara estática debe mantenerse en 5.2m")
	assert_true(abs(mgr.obtener_altura_spring_arm() - 0.65) < 0.01, "La altura de cámara con cámara estática debe mantenerse en 0.65m")
	
	mgr.desactivar_camara_estatica()


func test_cambio_personaje_camara_estatica_sin_salto() -> void:
	var script_mgr = load("res://scripts/core/camara_config_manager.gd")
	var mgr = track(script_mgr.new())
	
	var pos_toma_fija = Vector3(10.0, 4.0, 15.0)
	var rot_toma_fija = Vector3(0.0, 0.8, 0.0)
	mgr.fijar_camara_estatica(pos_toma_fija, rot_toma_fija)
	
	# Verificar que red_manager respeta la cámara estática en cambio de personajes
	var red_script = load("res://scripts/core/red_manager.gd")
	assert_ne(red_script, null, "RedManager debe existir")
	
	# Comprobar que obtener_posicion_camara_estatica entrega exactamente la posición fija
	assert_true(mgr.obtener_posicion_camara_estatica().is_equal_approx(pos_toma_fija), "La posición estática en CamaraConfigManager debe coincidir con pos_toma_fija")
	assert_true(mgr.obtener_rotacion_camara_estatica().is_equal_approx(rot_toma_fija), "La rotación estática debe coincidir")
	
	mgr.desactivar_camara_estatica()





