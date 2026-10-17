@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

func suite_name() -> String:
	return "camara_plataforma_espiritual"

func test_jugador_spring_arm_collision_mask() -> void:
	var scene = load("res://scenes/characters/jugador.tscn")
	assert_ne(scene, null, "La escena jugador.tscn debe existir")
	var jugador = track(scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)) as Node
	assert_ne(jugador, null, "Debe ser instancia de nodo")
	
	var arm = jugador.get_node_or_null("Node3D/SpringArm3D") as SpringArm3D
	assert_ne(arm, null, "El jugador debe tener SpringArm3D")
	
	# La máscara de colisión de la cámara del vivo debe ser 3 (Capa 1: Global y Capa 2: Físico),
	# EXCLUYENDO la Capa 3 (Plano Espiritual = 4) para evitar colisiones y zoom con plataformas espirituales inactivas
	assert_eq(arm.collision_mask, 3, "SpringArm3D de Jugador debe tener collision_mask = 3 (1|2)")
	assert_false((arm.collision_mask & (1 << 2)) != 0, "SpringArm3D de Jugador NO debe detectar Capa 3 (Plano Espiritual)")

func test_fantasma_spring_arm_collision_mask() -> void:
	var scene = load("res://scenes/characters/fantasma.tscn")
	assert_ne(scene, null, "La escena fantasma.tscn debe existir")
	var fantasma = track(scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)) as Node
	assert_ne(fantasma, null, "Debe ser instancia de nodo")
	
	var arm = fantasma.get_node_or_null("Node3D/SpringArm3D") as SpringArm3D
	assert_ne(arm, null, "El fantasma debe tener SpringArm3D")
	
	# La máscara de colisión de la cámara del fantasma debe ser 5 (Capa 1: Global y Capa 3: Espiritual),
	# EXCLUYENDO la Capa 2 (Plano Físico = 2)
	assert_eq(arm.collision_mask, 5, "SpringArm3D de Fantasma debe tener collision_mask = 5 (1|4)")
	assert_false((arm.collision_mask & (1 << 1)) != 0, "SpringArm3D de Fantasma NO debe detectar Capa 2 (Plano Físico)")

func test_fijar_camara_en_caida_estado() -> void:
	var scene = load("res://scenes/characters/jugador.tscn")
	var jugador: Jugador = track(scene.instantiate())
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.add_child(jugador)
	
	jugador.global_position = Vector3(10.0, 5.0, 2.0)
	var pivote = jugador.obtener_pivote_camara()
	assert_ne(pivote, null, "Debe tener pivote de cámara")
	pivote.global_position = jugador.global_position
	
	assert_false(jugador.esta_camara_fijada_en_caida(), "Inicialmente no debe estar fijada")
	
	jugador.fijar_camara_en_caida()
	assert_true(jugador.esta_camara_fijada_en_caida(), "Debe reportar cámara fijada en caída")
	assert_true(jugador.get("_pos_camara_fija_caida").is_equal_approx(Vector3(10.0, 5.0, 2.0)), "Posición fija debe registrarse")

func test_camara_se_mantiene_en_posicion_al_caer() -> void:
	var scene = load("res://scenes/characters/jugador.tscn")
	var jugador: Jugador = track(scene.instantiate())
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.add_child(jugador)
	
	jugador.global_position = Vector3(5.0, 8.0, -3.0)
	var pivote = jugador.obtener_pivote_camara()
	assert_ne(pivote, null, "Debe tener pivote de cámara")
	pivote.global_position = jugador.global_position
	
	# Activar fijación de cámara en la posición actual
	jugador.fijar_camara_en_caida()
	var pos_fija = jugador.get("_pos_camara_fija_caida")
	
	# Simular que el personaje cae verticalmente en el abismo
	jugador.global_position.y = 2.0
	jugador.velocity.y = -10.0
	
	# Procesar cámara durante la caída
	jugador.procesar_camara_base(0.016)
	
	# La cámara debe mantenerse exactamente en la posición fija original, sin seguir al personaje al abismo
	assert_true(pivote.global_position.is_equal_approx(pos_fija), "El pivote de la cámara debe mantenerse en la posición original donde cayó")
	assert_true(pivote.global_position.y > jugador.global_position.y + 4.0, "El pivote de la cámara debe estar por encima del personaje en caída")

func test_camara_se_restaura_al_reaparecer() -> void:
	var scene = load("res://scenes/characters/jugador.tscn")
	var jugador: Jugador = track(scene.instantiate())
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.add_child(jugador)
	
	var pos_inicio = Vector3(0.0, 2.0, 0.0)
	jugador.posicion_inicial = pos_inicio
	jugador.punto_control = pos_inicio
	jugador.global_position = Vector3(10.0, 15.0, 5.0)
	jugador.fijar_camara_en_caida()
	assert_true(jugador.esta_camara_fijada_en_caida(), "Cámara fijada en caída activa")
	
	# Al reaparecer tras caer al vacío
	jugador.reaparecer()
	
	assert_false(jugador.esta_camara_fijada_en_caida(), "El estado de cámara fija debe reiniciarse")
	assert_true(jugador.global_position.is_equal_approx(pos_inicio), "El personaje debe reaparecer en el punto de control")
	var pivote = jugador.obtener_pivote_camara()
	assert_ne(pivote, null, "Debe existir pivote de cámara tras reaparecer")
	assert_true(pivote.global_position.is_equal_approx(pos_inicio), "El pivote de cámara debe resetearse al punto de control")

func test_notificacion_desactivacion_plataforma_espiritual() -> void:
	var scene_jugador = load("res://scenes/characters/jugador.tscn")
	var jugador: Jugador = track(scene_jugador.instantiate())
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.add_child(jugador)
	
	var scene_plat = load("res://scenes/components/plataformas/plataforma_espiritual_base.tscn")
	var plataforma = track(scene_plat.instantiate()) as PlataformaEspiritualBase
	if tree and tree.root:
		tree.root.add_child(plataforma)
	
	plataforma.global_position = Vector3(12.0, 6.0, 0.0)
	jugador.global_position = Vector3(12.0, 6.0 + plataforma.altura_superficie + 0.1, 0.0)
	var pivote = jugador.obtener_pivote_camara()
	if pivote:
		pivote.global_position = jugador.global_position
	
	assert_false(jugador.esta_camara_fijada_en_caida(), "Inicialmente la cámara no está fijada")
	
	# Desactivar la plataforma y notificar a los personajes sobre ella
	plataforma._notificar_desactivacion_a_personajes()
	
	assert_true(jugador.esta_camara_fijada_en_caida(), "La cámara del jugador debe fijarse en su posición al desactivarse la plataforma")
