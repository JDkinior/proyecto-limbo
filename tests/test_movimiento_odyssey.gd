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
