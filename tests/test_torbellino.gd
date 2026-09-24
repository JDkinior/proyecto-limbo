@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

func suite_name() -> String:
	return "torbellino"

func test_torbellino_instantiation() -> void:
	var scene = load("res://scenes/components/peligros/torbellino.tscn")
	assert_ne(scene, null, "La escena torbellino.tscn debe existir")
	var instance = track(scene.instantiate()) as Torbellino
	assert_ne(instance, null, "Debe ser instancia de Torbellino")
	assert_true(instance.radio_influencia > 0.0, "Radio de influencia debe ser positivo")
	assert_true(instance.duracion_absorcion > 0.0, "Duracion de absorcion debe ser positiva")
	assert_true(instance.fuerza_succion_horizontal > 0.0, "Fuerza de succión horizontal debe ser positiva")
	assert_true(instance.fuerza_arrastre_vertical > 0.0, "Fuerza de arrastre vertical debe ser positiva")

func test_torbellino_child_nodes() -> void:
	var scene = load("res://scenes/components/peligros/torbellino.tscn")
	var instance = track(scene.instantiate()) as Torbellino
	assert_ne(instance, null, "Instancia creada")
	
	var area_inf = instance.get_node_or_null("AreaInfluencia")
	assert_ne(area_inf, null, "Debe existir AreaInfluencia")
	
	var area_abs = instance.get_node_or_null("AreaAbsorcion")
	assert_ne(area_abs, null, "Debe existir AreaAbsorcion")
	
	var visual = instance.get_node_or_null("Visual")
	assert_ne(visual, null, "Debe existir nodo Visual")
	
	var particles = instance.get_node_or_null("ParticulasVortice")
	assert_ne(particles, null, "Debe existir ParticulasVortice")
	
	var light = instance.get_node_or_null("LuzTorbellino")
	assert_ne(light, null, "Debe existir LuzTorbellino")

func test_torbellino_candidato_filter() -> void:
	var scene = load("res://scenes/components/peligros/torbellino.tscn")
	var instance = track(scene.instantiate()) as Torbellino
	
	var static_body = track(StaticBody3D.new())
	assert_false(instance._es_candidato_valido(static_body), "StaticBody3D no debe ser candidato")
	
	var char_body = track(CharacterBody3D.new())
	char_body.name = "Fantasma"
	char_body.add_to_group("fantasmas")
	assert_true(instance._es_candidato_valido(char_body), "Fantasma debe ser candidato valido")

func test_torbellino_movimiento_patrulla() -> void:
	var scene = load("res://scenes/components/peligros/torbellino.tscn")
	var instance = track(scene.instantiate()) as Torbellino
	
	instance.position = Vector3(0, 5, 0)
	instance._pos_inicial_mov = Vector3(0, 5, 0)
	instance.se_mueve = true
	instance.desplazamiento = Vector3(10, 0, 0)
	instance.velocidad_movimiento = 5.0
	instance.tiempo_espera_extremos = 0.0
	instance.movimiento_suave = false
	
	# Simular 1 segundo de movimiento: debe avanzar 5 unidades
	instance._procesar_movimiento_patrulla(1.0)
	assert_eq(instance.position, Vector3(5, 5, 0), "Debe avanzar hacia el destino")
	
	# Simular 1 segundo más: debe alcanzar el destino (10, 5, 0) y voltear dirección
	instance._procesar_movimiento_patrulla(1.0)
	assert_eq(instance.position, Vector3(10, 5, 0), "Debe llegar al extremo")
	assert_eq(instance._direccion_patrulla, -1.0, "Debe invertir la dirección al llegar al extremo")
	
	# Simular retorno
	instance._procesar_movimiento_patrulla(1.0)
	assert_eq(instance.position, Vector3(5, 5, 0), "Debe retornar hacia el origen")

func test_absorcion_giro_horario() -> void:
	# 1. Verificar fuerza tangencial del torbellino:
	# Desde las 12 en punto (0, -2), el vector radial al centro (0,0) es (0, 1).
	var dir_radial = Vector3(0.0, 0.0, 1.0)
	var dir_tangencial = Vector3(dir_radial.z, 0.0, -dir_radial.x)
	assert_gt(dir_tangencial.x, 0.0, "La fuerza tangencial en las 12 en punto debe apuntar hacia +X (hacia las 3 / horario)")

	# 2. Verificar parametrización trigonométrica horaria de absorción:
	# Inicio a las 12 en punto (offset: X=0, Z=-1)
	var offset = Vector3(0.0, 0.0, -1.0)
	var angulo_inicial = atan2(offset.x, -offset.z)
	assert_eq(angulo_inicial, 0.0, "El ángulo a las 12 en punto debe ser 0")

	# Avance horario (+delta de ángulo hacia las 3 en punto: PI/2)
	var angulo_3_en_punto = angulo_inicial + (PI * 0.5)
	var x_3 = sin(angulo_3_en_punto)
	var z_3 = -cos(angulo_3_en_punto)
	assert_gt(x_3, 0.99, "A las 3 en punto X debe ser +1.0 (a favor de las manecillas)")
	assert_true(absf(z_3) < 0.01, "A las 3 en punto Z debe ser 0.0")

	# Avance horario hacia las 6 en punto: PI
	var angulo_6_en_punto = angulo_inicial + PI
	var x_6 = sin(angulo_6_en_punto)
	var z_6 = -cos(angulo_6_en_punto)
	assert_true(absf(x_6) < 0.01, "A las 6 en punto X debe ser 0.0")
	assert_gt(z_6, 0.99, "A las 6 en punto Z debe ser +1.0 (a favor de las manecillas)")

