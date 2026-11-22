@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

## ==============================================================================
## SUITE DE PRUEBAS AUTOMATIZADAS: CALIBRACIÓN DE MOVIMIENTO ODYSSEY (M1-01)
## Verifica tiempos de tolerancia (coyote/buffer 0.12s), acrobacias aéreas del Vivo
## (Dive y Ground Pound), derrape físico visible y Side Flip tipo Odyssey.
## ==============================================================================

func suite_name() -> String:
	return "movimiento_odyssey"

func test_parametros_base_tolerancia() -> void:
	var code = FileAccess.get_file_as_string("res://scripts/base/character_base.gd")
	assert_true(code.contains("@export var TIEMPO_COYOTE : float = 0.12"), "TIEMPO_COYOTE base debe calibrarse en 0.12s")
	assert_true(code.contains("@export var TIEMPO_BUFFER_SALTO : float = 0.12"), "TIEMPO_BUFFER_SALTO base debe calibrarse en 0.12s")
	assert_true(code.contains("var esta_derrapando: bool = false"), "Debe implementar variable esta_derrapando en character_base.gd")
	assert_true(code.contains("func _al_iniciar_derrape"), "Debe implementar hook virtual _al_iniciar_derrape")
	assert_true(code.contains("func _al_procesar_derrape"), "Debe implementar hook virtual _al_procesar_derrape")
	assert_true(code.contains("_al_realizar_salto_derrape"), "Debe implementar salto invertido Side Flip tras derrape")

func test_calibracion_jugador_vivo() -> void:
	var code = FileAccess.get_file_as_string("res://scripts/characters/jugador.gd")
	assert_true(code.contains("TIEMPO_COYOTE = 0.12"), "Jugador: Coyote time calibrado en 0.12s")
	assert_true(code.contains("TIEMPO_BUFFER_SALTO = 0.12"), "Jugador: Buffer de salto calibrado en 0.12s")
	assert_true(code.contains("MULTIPLICADOR_SEGUNDO_SALTO = 0.95"), "Jugador: Segundo salto elástico calibrado")
	assert_true(code.contains("MAX_SALTOS = 2"), "Jugador: Mantiene doble salto acrobático")
	assert_true(code.contains("PUEDE_PLANEAR = false"), "Jugador: No debe planear (exclusivo del Fantasma)")

func test_jugador_dive_y_ground_pound() -> void:
	var code = FileAccess.get_file_as_string("res://scripts/characters/jugador.gd")
	assert_true(code.contains("func ejecutar_ground_pound()"), "Jugador debe implementar ejecutar_ground_pound()")
	assert_true(code.contains("func ejecutar_dive("), "Jugador debe implementar ejecutar_dive()")
	assert_true(code.contains("_dive_realizado_en_aire"), "Jugador debe limitar dive aéreo a 1 vez por vuelo para evitar vuelo infinito")
	assert_true(code.contains("func _al_aterrizar_ground_pound("), "Jugador debe implementar _al_aterrizar_ground_pound()")
	assert_true(code.contains("_tiempo_squash_ground_pound"), "Jugador debe tener animación de impacto squash para el ground pound")
	assert_true(code.contains("VENTANA_SALTO_GROUND_POUND"), "Jugador debe poseer ventana de rebote potenciado tras ground pound")
	assert_true(code.contains("func _al_iniciar_derrape("), "Jugador debe implementar _al_iniciar_derrape() con inclinación hacia atrás")
	assert_true(code.contains("func _al_procesar_derrape("), "Jugador debe implementar _al_procesar_derrape() con partículas elevadas")

func test_calibracion_fantasma() -> void:
	var code = FileAccess.get_file_as_string("res://scripts/characters/fantasma.gd")
	assert_true(code.contains("TIEMPO_COYOTE = 0.12"), "Fantasma: Coyote time calibrado en 0.12s")
	assert_true(code.contains("TIEMPO_BUFFER_SALTO = 0.12"), "Fantasma: Buffer de salto calibrado en 0.12s")
	assert_true(code.contains("MAX_SALTOS = 1"), "Fantasma: Salto único con planeo")
	assert_true(code.contains("PUEDE_PLANEAR = true"), "Fantasma: Planeo prolongado habilitado")
	assert_true(code.contains("MULTIPLICADOR_GRAVEDAD_APICE = 0.38"), "Fantasma: Suspensión flotante en el ápice calibrada")
	assert_true(code.contains("UMBRAL_VELOCIDAD_APICE = 1.8"), "Fantasma: Umbral de velocidad en ápice calibrado")
	assert_true(code.contains("MULTIPLICADOR_VELOCIDAD_PLANEO = 1.20"), "Fantasma: Multiplicador de velocidad de planeo calibrado")
	assert_true(code.contains("func _al_iniciar_derrape("), "Fantasma debe responder al derrape con inclinación y estela espectral")

func test_sombra_aterrizaje_vivo_y_fantasma() -> void:
	var escena_j = ResourceLoader.load("res://scenes/characters/jugador.tscn", "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
	var escena_f = ResourceLoader.load("res://scenes/characters/fantasma.tscn", "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
	var jugador := track(escena_j.instantiate()) as Jugador
	var fantasma := track(escena_f.instantiate()) as Fantasma
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.add_child(jugador)
		tree.root.add_child(fantasma)

	# 1. Nodos creados y recursos compartidos
	assert_true(is_instance_valid(jugador._mesh_sombra_aterrizaje), "Jugador debe inicializar _mesh_sombra_aterrizaje")
	assert_true(is_instance_valid(fantasma._mesh_sombra_aterrizaje), "Fantasma debe inicializar _mesh_sombra_aterrizaje")
	assert_true(jugador._mesh_sombra_aterrizaje.top_level, "La sombra del Jugador debe usar top_level = true")
	assert_true(fantasma._mesh_sombra_aterrizaje.top_level, "La sombra del Fantasma debe usar top_level = true")
	assert_eq(jugador._mesh_sombra_aterrizaje.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "La sombra proyectada no debe arrojar sombra adicional")
	assert_eq(fantasma._mesh_sombra_aterrizaje.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "La sombra del Fantasma no debe arrojar sombra adicional")

	assert_true(is_instance_valid(jugador._raycast_sombra_aterrizaje), "Jugador debe inicializar _raycast_sombra_aterrizaje")
	assert_true(is_instance_valid(fantasma._raycast_sombra_aterrizaje), "Fantasma debe inicializar _raycast_sombra_aterrizaje")
	assert_true(jugador._raycast_sombra_aterrizaje.exclude_parent, "El raycast del Jugador debe excluir al padre")
	assert_true(fantasma._raycast_sombra_aterrizaje.exclude_parent, "El raycast del Fantasma debe excluir al padre")
	assert_eq(jugador._raycast_sombra_aterrizaje.collision_mask, 3, "El raycast del Jugador debe usar collision_mask == 3")
	assert_eq(fantasma._raycast_sombra_aterrizaje.collision_mask, 5, "El raycast del Fantasma debe usar collision_mask == 5")
	assert_eq(jugador._mesh_sombra_aterrizaje.mesh, fantasma._mesh_sombra_aterrizaje.mesh, "Vivo y Fantasma deben reutilizar el mismo PlaneMesh")
	assert_eq(jugador._material_sombra_aterrizaje.albedo_texture, fantasma._material_sombra_aterrizaje.albedo_texture, "Vivo y Fantasma deben reutilizar la misma GradientTexture2D")

	# 2. Variación de escala y opacidad por altura manteniendo legibilidad
	var params_suelo := jugador.calcular_parametros_sombra_aterrizaje(0.0)
	var params_alto := jugador.calcular_parametros_sombra_aterrizaje(6.0)
	assert_true(float(params_alto["escala"]) < float(params_suelo["escala"]), "A mayor altura la escala de la sombra debe reducirse")
	assert_true(float(params_alto["opacidad"]) < float(params_suelo["opacidad"]), "A mayor altura la opacidad de la sombra debe reducirse")
	assert_true(float(params_alto["escala"]) >= jugador.SOMBRA_TAMANO_BASE * jugador.SOMBRA_ESCALA_MIN_ALTURA - 0.01, "La escala en altura debe respetar el mínimo legible")
	assert_true(float(params_alto["opacidad"]) >= jugador.SOMBRA_OPACIDAD_AIRE_MIN - 0.01, "La opacidad en altura debe respetar el mínimo legible")

	# 3. Posicionamiento en superficie y ocultamiento en estados especiales (cañón)
	jugador.aplicar_sombra_aterrizaje_en_punto(Vector3(2.0, 1.0, -3.0), Vector3.UP, 2.0)
	assert_true(jugador._mesh_sombra_aterrizaje.visible, "aplicar_sombra_aterrizaje_en_punto debe hacer visible la sombra")
	assert_true(absf(jugador._mesh_sombra_aterrizaje.global_position.y - (1.0 + jugador.SOMBRA_OFFSET_SUPERFICIE)) < 0.005, "La sombra debe situarse sobre la superficie con SOMBRA_OFFSET_SUPERFICIE")
	jugador.en_canon = true
	assert_false(jugador.debe_mostrar_sombra_aterrizaje(), "En cañón debe_mostrar_sombra_aterrizaje() debe devolver false")
	jugador.actualizar_sombra_aterrizaje()
	assert_false(jugador._mesh_sombra_aterrizaje.visible, "actualizar_sombra_aterrizaje() debe ocultar la sombra mientras esté en cañón")
