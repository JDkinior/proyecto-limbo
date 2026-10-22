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


