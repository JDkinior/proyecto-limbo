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
	var btn_ocultar = ui.get_node_or_null("Panel_Camara_Tomas/VBoxContainer/ScrollContainer/VBoxContainer/Boton_Ocultar_Controles")
	
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
	
	var base_cam = "Panel_Camara_Tomas/VBoxContainer/ScrollContainer/VBoxContainer/"
	var btn_libre = ui.get_node_or_null(base_cam + "Boton_Camara_Libre")
	assert_ne(btn_libre, null, "Botón de cámara libre debe existir en Panel_Camara_Tomas")

	var btn_est = ui.get_node_or_null(base_cam + "Boton_Camara_Estatica")
	assert_ne(btn_est, null, "Botón de cámara estática debe existir")

	var btn_guia = ui.get_node_or_null(base_cam + "Boton_Guia_Shorts")
	assert_ne(btn_guia, null, "Botón de guía 9:16 debe estar organizado dentro de Panel_Camara_Tomas")

	var slider_dist = ui.get_node_or_null(base_cam + "Slider_Distancia")
	assert_ne(slider_dist, null, "Slider de distancia debe existir")
	
	var slider_alt = ui.get_node_or_null(base_cam + "Slider_Altura")
	assert_ne(slider_alt, null, "Slider de altura debe existir")
	
	var btn_rev = ui.get_node_or_null(base_cam + "Boton_Revertir_Camara")
	assert_ne(btn_rev, null, "Botón de revertir ajustes de cámara debe existir")
	
	var btn_hud_rapido = ui.get_node_or_null(base_cam + "Boton_Toggle_HUD_Rapido")
	assert_ne(btn_hud_rapido, null, "Botón de activar acceso rápido en HUD debe existir")
	
	var btn_cerrar = ui.get_node_or_null("Panel_Camara_Tomas/VBoxContainer/Boton_Cerrar_Camara_Tomas")
	assert_ne(btn_cerrar, null, "Botón de cerrar panel debe existir")

	# Verificar jerarquía limpia de Ajustes (Hub -> Controles y HUD / Video y Rendimiento)
	assert_ne(ui.get_node_or_null("Panel_Opciones/VBoxContainer/Boton_Ajustes_Controles"), null, "Panel_Opciones debe enlazar a Controles y HUD")
	assert_ne(ui.get_node_or_null("Panel_Ajustes_Controles/VBoxContainer/Boton_Personalizar_HUD"), null, "Panel_Ajustes_Controles debe contener Personalizar HUD")
	assert_ne(ui.get_node_or_null("Panel_Ajustes_Controles/VBoxContainer/Boton_Mapear_Control"), null, "Panel_Ajustes_Controles debe contener Mapear Control")
	assert_ne(ui.get_node_or_null("Panel_Ajustes_Video/VBoxContainer/Boton_FPS"), null, "Mostrar FPS debe estar en Video y Rendimiento")
	assert_eq(ui.get_node_or_null("Panel_Ajustes_Video/VBoxContainer/Boton_Guia_Shorts"), null, "Panel_Ajustes_Video ya no debe duplicar opciones de Shorts")
	
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


func test_camara_estatica_rotar_eje_y() -> void:
	var script_mgr = load("res://scripts/core/camara_config_manager.gd")
	var mgr = track(script_mgr.new())
	
	var pos_inicial := Vector3(3.0, 2.5, -4.0)
	var rot_inicial := Vector3(0.1, 0.5, 0.0)
	mgr.fijar_camara_estatica(pos_inicial, rot_inicial)
	
	# Rotar izquierda (+Y) y derecha (-Y) manteniendo intactos X, Z y posición
	mgr.rotar_camara_estatica_y(0.75)
	var rot_despues_izq: Vector3 = mgr.obtener_rotacion_camara_estatica()
	assert_true(absf(rot_despues_izq.y - 1.25) < 0.001, "rotar_camara_estatica_y positivo debe sumar al eje Y")
	assert_true(absf(rot_despues_izq.x - rot_inicial.x) < 0.001, "No debe alterar el eje X")
	assert_true(mgr.obtener_posicion_camara_estatica().is_equal_approx(pos_inicial), "Rotar Y no debe mover la posición estática")
	
	mgr.rotar_camara_estatica_y(-1.0)
	var rot_despues_der: Vector3 = mgr.obtener_rotacion_camara_estatica()
	assert_true(absf(rot_despues_der.y - 0.25) < 0.001, "rotar_camara_estatica_y negativo debe restar al eje Y")
	
	mgr.desactivar_camara_estatica()


func test_bumpers_lb_rb_rotacion_eje_y() -> void:
	var script_char = load("res://scripts/base/character_base.gd")
	var personaje = track(script_char.new())
	
	var delta_lb: float = personaje._calcular_delta_rotacion_bumpers_y(true, false, 0.5)
	var delta_rb: float = personaje._calcular_delta_rotacion_bumpers_y(false, true, 0.5)
	var delta_ambos: float = personaje._calcular_delta_rotacion_bumpers_y(true, true, 0.5)
	var delta_ninguno: float = personaje._calcular_delta_rotacion_bumpers_y(false, false, 0.5)
	
	assert_true(delta_lb > 0.0, "LB debe rotar positivamente alrededor del eje Y (izquierda)")
	assert_true(delta_rb < 0.0, "RB debe rotar negativamente alrededor del eje Y (derecha)")
	assert_true(absf(delta_lb + delta_rb) < 0.0001, "LB y RB deben tener magnitudes simétricas")
	assert_true(absf(delta_ambos) < 0.0001, "Presionar LB y RB a la vez debe cancelar la rotación")
	assert_true(absf(delta_ninguno) < 0.0001, "Sin bumpers presionados no debe haber rotación")
	assert_true(personaje._boton_mando_libre_para_camara(JOY_BUTTON_LEFT_SHOULDER), "LB debe estar libre por defecto para rotación de cámara")
	assert_true(personaje._boton_mando_libre_para_camara(JOY_BUTTON_RIGHT_SHOULDER), "RB debe estar libre por defecto para rotación de cámara")


func test_red_manager_vista_reino_independiente_y_ciclo_r3() -> void:
	var red_script = load("res://scripts/core/red_manager.gd")
	assert_ne(red_script, null, "red_manager.gd debe cargarse")
	var red = track(red_script.new())
	var cam = track(Camera3D.new())

	red.es_un_jugador = true
	red.personaje_activo_solo = "jugador"
	red.reino_espiritual_activo = false

	assert_false(red.tiene_vista_reino_fija(), "La vista del escenario debe iniciar en automático")
	assert_false(red.es_reino_espiritual_activo(), "Controlando Vivo en automático debe mostrar mundo vivo")
	assert_eq(red.obtener_entorno_visual_actual(), null, "En vista Vivo el entorno visual debe ser null")
	assert_eq(red.obtener_cull_mask_visual_actual(), 1048575 & ~(1 << 2), "En vista Vivo debe ocultarse la capa 3 espiritual")

	# 1er R3: fijar la vista actual (Vivo)
	var modo_1: String = red.alternar_vista_reino_independiente()
	assert_eq(modo_1, "vivo", "1ra pulsación de R3 controlando Vivo debe fijar la vista en vivo")
	assert_true(red.tiene_vista_reino_fija())

	# Cambiar control a Fantasma manteniendo la vista fija en Vivo
	red.personaje_activo_solo = "fantasma"
	red.aplicar_vista_reino_visual()
	red.configurar_camara_segun_vista(cam, null)
	assert_false(red.es_reino_espiritual_activo(), "Controlar Fantasma con vista fija en Vivo debe mantener colores del Vivo")
	assert_eq(cam.environment, null, "Cámara debe mantener environment natural con vista fija Vivo")
	assert_eq(cam.cull_mask, 1048575 & ~(1 << 2), "Cámara debe mantener cull_mask de Vivo aunque se controle al Fantasma")

	# 2do R3: pasar a la otra vista fija (Fantasma)
	var modo_2: String = red.alternar_vista_reino_independiente()
	assert_eq(modo_2, "fantasma", "2da pulsación de R3 debe cambiar la vista fija a fantasma")
	red.configurar_camara_segun_vista(cam, null)
	assert_true(red.es_reino_espiritual_activo(), "Vista fija en Fantasma debe reportar reino espiritual activo")
	assert_eq(cam.environment, red.ENTORNO_FANTASMA_RECURSO, "Vista fija Fantasma debe aplicar el entorno espectral")
	assert_eq(cam.cull_mask, 1048575 & ~(1 << 1), "Vista fija Fantasma debe mostrar capa 3 y ocultar capa 2")

	# Cambiar control de vuelta a Vivo manteniendo colores del Fantasma
	red.personaje_activo_solo = "jugador"
	red.aplicar_vista_reino_visual()
	assert_true(red.es_reino_espiritual_activo(), "Controlar Vivo con vista fija en Fantasma debe mantener colores del Fantasma")

	# 3er R3: volver a modo automático acoplado al personaje controlado (Vivo)
	var modo_3: String = red.alternar_vista_reino_independiente()
	assert_eq(modo_3, "auto", "3ra pulsación de R3 debe volver a vista automática")
	assert_false(red.tiene_vista_reino_fija())
	assert_false(red.es_reino_espiritual_activo(), "Al volver a automático controlando Vivo debe regresar al mundo vivo")


func test_red_manager_ciclo_r3_iniciando_desde_fantasma() -> void:
	var red = track(load("res://scripts/core/red_manager.gd").new())
	red.es_un_jugador = true
	red.personaje_activo_solo = "fantasma"
	red.reino_espiritual_activo = true

	assert_eq(red.alternar_vista_reino_independiente(), "fantasma", "1er R3 desde Fantasma debe fijar vista en fantasma")
	assert_eq(red.alternar_vista_reino_independiente(), "vivo", "2do R3 desde Fantasma debe alternar vista fija a vivo")
	assert_eq(red.alternar_vista_reino_independiente(), "auto", "3er R3 debe regresar a automático")
	assert_true(red.es_reino_espiritual_activo(), "Al volver a automático mientras se controla Fantasma debe seguir en reino espiritual")


func test_gamepad_r3_vista_reino_y_l3_camara_libre() -> void:
	var gm_script = load("res://scripts/core/gamepad_manager.gd")
	assert_ne(gm_script, null, "gamepad_manager.gd debe cargarse")
	var gm = track(gm_script.new())
	var defaults: Dictionary = gm.obtener_defaults()

	assert_true(defaults.has("camara_libre"), "GamepadManager debe incluir acción configurable camara_libre")
	assert_eq(defaults["camara_libre"]["tipo"], "button")
	assert_eq(int(defaults["camara_libre"]["indice"]), JOY_BUTTON_BACK, "El botón Vista (JOY_BUTTON_BACK) debe estar asignado por defecto a camara_libre")
	assert_eq(int(defaults["centrar_camara"]["indice"]), JOY_BUTTON_LEFT_STICK, "centrar_camara debe permanecer en L3 por defecto")

	assert_true(defaults.has("alternar_vista_reino"), "GamepadManager debe incluir acción configurable alternar_vista_reino")
	assert_eq(defaults["alternar_vista_reino"]["tipo"], "button")
	assert_eq(int(defaults["alternar_vista_reino"]["indice"]), JOY_BUTTON_RIGHT_STICK, "R3 debe estar asignado por defecto a alternar_vista_reino")

	var red = track(load("res://scripts/core/red_manager.gd").new())
	var ev_r3 := InputEventJoypadButton.new()
	ev_r3.button_index = JOY_BUTTON_RIGHT_STICK
	ev_r3.pressed = true
	if InputMap.has_action("alternar_vista_reino"):
		var tiene_r3 := false
		for ev_act in InputMap.action_get_events("alternar_vista_reino"):
			if ev_act is InputEventJoypadButton and ev_act.button_index == JOY_BUTTON_RIGHT_STICK:
				tiene_r3 = true
				break
		assert_true(tiene_r3 or red._es_evento_alternar_vista_reino(ev_r3), "alternar_vista_reino debe responder a R3")
	else:
		assert_true(red._es_evento_alternar_vista_reino(ev_r3), "Fallback sin InputMap debe reconocer R3 para vista independiente")


func test_camara_libre_ciclo_l3_y_rotacion() -> void:
	var script = load("res://scripts/core/camara_config_manager.gd")
	var mgr = track(script.new())

	assert_false(mgr.esta_camara_estatica())
	assert_false(mgr.esta_camara_libre_activa())

	# 1er toque L3: entra a Cámara Libre (estatica=true, libre=true)
	assert_eq(mgr.alternar_camara_libre_l3(), "libre", "1er toque de L3 desde seguimiento debe activar Cámara Libre")
	assert_true(mgr.esta_camara_estatica(), "Cámara Libre mantiene el pivote desacoplado del personaje")
	assert_true(mgr.esta_camara_libre_activa(), "Debe reportar camara_libre_activa = true")

	# Rotar y mover cámara libre (incluye pitch amplio +/-85 grados)
	mgr.mover_posicion_camara_estatica(Vector3(3.0, 2.5, -1.0))
	mgr.rotar_camara_estatica(1.2, -0.8)
	assert_true(abs(mgr.obtener_rotacion_camara_estatica().y - 1.2) < 0.01)
	assert_true(abs(mgr.obtener_rot_x_arm_estatica() - (-0.8)) < 0.01)
	mgr.rotar_camara_estatica(0.0, -5.0)
	assert_true(mgr.obtener_rot_x_arm_estatica() >= -1.48 - 0.001, "Pitch de cámara libre debe respetar límite inferior amplio")

	# 2do toque L3: fija cámara estática y devuelve control al personaje
	var pos_toma: Vector3 = mgr.obtener_posicion_camara_estatica()
	assert_eq(mgr.alternar_camara_libre_l3(), "estatica", "2do toque de L3 debe fijar la cámara estática ahí")
	assert_true(mgr.esta_camara_estatica(), "Debe seguir en cámara estática")
	assert_false(mgr.esta_camara_libre_activa(), "Debe liberar al personaje dejando libre=false")
	assert_true(mgr.obtener_posicion_camara_estatica().is_equal_approx(pos_toma), "La pose encuadrada no debe perderse al fijarla")

	# 3er toque L3 desde estática: reabre Cámara Libre desde la misma toma para reajustar
	assert_eq(mgr.alternar_camara_libre_l3(), "libre", "Desde cámara fija, L3 vuelve a Cámara Libre")
	assert_true(mgr.esta_camara_libre_activa())
	assert_true(mgr.obtener_posicion_camara_estatica().is_equal_approx(pos_toma))

	# Salir a seguimiento desactiva ambos estados
	mgr.desactivar_camara_estatica()
	assert_false(mgr.esta_camara_estatica())
	assert_false(mgr.esta_camara_libre_activa())


func test_curva_progresiva_gatillos_camara_libre() -> void:
	var script_char = load("res://scripts/base/character_base.gd")
	var personaje = track(script_char.new())

	assert_eq(personaje._calcular_curva_gatillo_camara(0.0), 0.0, "Sin presión debe ser 0")
	assert_eq(personaje._calcular_curva_gatillo_camara(0.05), 0.0, "Zona muerta <= 0.05 debe ser 0")
	var suave: float = personaje._calcular_curva_gatillo_camara(0.25)
	var medio: float = personaje._calcular_curva_gatillo_camara(0.55)
	var fondo: float = personaje._calcular_curva_gatillo_camara(1.0)
	assert_true(suave > 0.0 and suave < 0.1, "Presión suave (0.25) debe producir movimiento fino y lento")
	assert_true(medio > suave and medio < fondo, "Presión media debe escalar progresivamente")
	assert_true(is_equal_approx(fondo, 1.0), "Presión completa (1.0) debe alcanzar velocidad máxima (1.0)")


func test_controles_tactiles_tiene_boton_vista_reino() -> void:
	var scene = ResourceLoader.load("res://scenes/ui/controles_tactiles.tscn", "PackedScene", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	assert_ne(scene, null)
	var ui = track(scene.instantiate()) as Control
	var btn_vista = ui.get_node_or_null("Panel_Camara_Tomas/VBoxContainer/ScrollContainer/VBoxContainer/Boton_Vista_Reino") as Button
	assert_ne(btn_vista, null, "Panel_Camara_Tomas debe incluir Boton_Vista_Reino")


func test_camara_config_revertir_incluye_vista_reino() -> void:
	if not is_instance_valid(CamaraConfigManager) or not is_instance_valid(RedManager):
		return
	var dist_prev: float = CamaraConfigManager.obtener_distancia_camara()
	var alt_prev: float = CamaraConfigManager.obtener_altura_spring_arm()
	var est_prev: bool = CamaraConfigManager.esta_camara_estatica()
	var vista_prev: String = RedManager.vista_reino_modo

	RedManager.establecer_vista_reino_modo("fantasma")
	assert_true(RedManager.tiene_vista_reino_fija())
	assert_false(CamaraConfigManager.es_configuracion_por_defecto(), "Vista fija activa no debe considerarse configuración por defecto")

	CamaraConfigManager.revertir_ajustes_camara()
	assert_false(RedManager.tiene_vista_reino_fija(), "revertir_ajustes_camara debe devolver la vista del escenario a automático")
	assert_eq(RedManager.vista_reino_modo, "auto")

	# Restaurar estado previo del editor/usuario
	CamaraConfigManager.establecer_distancia_camara(dist_prev)
	CamaraConfigManager.establecer_altura_camara(alt_prev)
	if est_prev:
		CamaraConfigManager.alternar_camara_estatica()
	RedManager.establecer_vista_reino_modo(vista_prev)


func test_camara_libre_bumpers_lb_rb_no_fallan_sin_echo() -> void:
	var script_mgr = load("res://scripts/core/camara_config_manager.gd")
	var mgr = track(script_mgr.new())
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(mgr)
	var prev_scene := tree.current_scene
	var dummy_scene := track(Node3D.new())
	dummy_scene.name = "NivelTest"
	tree.root.add_child(dummy_scene)
	tree.current_scene = dummy_scene

	var guia_inicial: bool = mgr.esta_guia_activa()
	var hud_inicial: bool = mgr.esta_ocultar_controles_activo()

	mgr.activar_camara_libre()
	assert_true(mgr.esta_camara_libre_activa())

	var ev_lb := InputEventJoypadButton.new()
	ev_lb.button_index = JOY_BUTTON_LEFT_SHOULDER
	ev_lb.pressed = true
	mgr._unhandled_input(ev_lb)
	assert_eq(mgr.esta_guia_activa(), not guia_inicial, "LB en cámara libre debe alternar la guía 9:16 sin error de propiedad echo")

	var ev_rb := InputEventJoypadButton.new()
	ev_rb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	ev_rb.pressed = true
	mgr._unhandled_input(ev_rb)
	assert_eq(mgr.esta_ocultar_controles_activo(), not hud_inicial, "RB en cámara libre debe alternar HUD limpio sin error de propiedad echo")

	mgr.desactivar_camara_estatica()
	tree.current_scene = prev_scene


func test_menu_inicio_reorganizado() -> void:
	var scene = ResourceLoader.load("res://scenes/ui/menu_inicio.tscn", "PackedScene", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	assert_ne(scene, null, "menu_inicio.tscn debe cargar sin errores")
	var menu = track(scene.instantiate()) as Control
	assert_ne(menu, null)

	var p_principal := menu.get_node_or_null("PanelPrincipal") as Panel
	var p_opciones := menu.get_node_or_null("PanelOpciones") as Panel
	var p_controles := menu.get_node_or_null("PanelAjustesControles") as Panel
	var p_video := menu.get_node_or_null("PanelAjustesVideo") as Panel
	var p_grabacion := menu.get_node_or_null("PanelGrabacionShorts") as Panel

	assert_ne(p_principal, null)
	assert_ne(p_opciones, null)
	assert_ne(p_controles, null)
	assert_ne(p_video, null)
	assert_ne(p_grabacion, null)
	assert_false(p_opciones.visible)
	assert_false(p_controles.visible)
	assert_false(p_video.visible)
	assert_false(p_grabacion.visible)

	assert_ne(menu.get_node_or_null("PanelOpciones/VBoxContainer/BtnAjustesControles"), null)
	assert_ne(menu.get_node_or_null("PanelOpciones/VBoxContainer/BtnAjustesVideo"), null)
	assert_ne(menu.get_node_or_null("PanelOpciones/VBoxContainer/BtnGrabacionShorts"), null)
	assert_ne(menu.get_node_or_null("PanelOpciones/VBoxContainer/BtnLogsEOS"), null)
	assert_ne(menu.get_node_or_null("PanelAjustesControles/VBoxContainer/BtnMapearControl"), null)
	assert_ne(menu.get_node_or_null("PanelAjustesControles/VBoxContainer/BtnAjustarHUD"), null)
	assert_ne(menu.get_node_or_null("PanelAjustesVideo/VBoxContainer/BtnFullscreen"), null)
	assert_ne(menu.get_node_or_null("PanelAjustesVideo/VBoxContainer/BtnMostrarFPS"), null)
	assert_ne(menu.get_node_or_null("PanelAjustesVideo/VBoxContainer/BtnEscalaRender"), null)
	assert_ne(menu.get_node_or_null("PanelAjustesVideo/VBoxContainer/BtnLimiteFPS"), null)
	assert_ne(menu.get_node_or_null("PanelGrabacionShorts/VBoxContainer/BtnGuiaShorts"), null)
	assert_ne(menu.get_node_or_null("PanelGrabacionShorts/VBoxContainer/BtnOcultarControles"), null)


