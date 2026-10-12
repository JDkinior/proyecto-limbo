@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

func suite_name() -> String:
	return "habilidad_aura_retraccion"

func test_activacion_y_retraccion_anticipada() -> void:
	var tree = Engine.get_main_loop() as SceneTree
	var parent_dummy = track(Node3D.new()) as Node3D
	var aura_mesh = track(MeshInstance3D.new()) as MeshInstance3D
	aura_mesh.name = "Aura"
	parent_dummy.add_child(aura_mesh)

	var aura_script = load("res://scripts/characters/habilidad_aura.gd")
	var habilidad = track(aura_script.new()) as Node3D
	parent_dummy.add_child(habilidad)

	if tree and tree.root:
		tree.root.add_child(parent_dummy)

	# 1. Estado inicial
	assert_false(habilidad.esta_activa(), "Debe comenzar inactiva")
	assert_true(habilidad.cooldown_actual == 0.0, "Cooldown inicial debe ser 0")

	# 2. Primera activación
	habilidad.intentar_activar()
	assert_true(habilidad.esta_activa(), "Debe activarse tras intentar_activar()")
	assert_true(habilidad.get("_en_fase_aparicion"), "Debe entrar en fase de aparicion")

	# Simular 0.2 segundos de expansión
	habilidad._process(0.2)
	var radio_antes_cancelar: float = habilidad.obtener_radio()
	assert_true(radio_antes_cancelar > 0.0, "El radio debe ser mayor a 0 durante la expansion")

	# 3. Presionar de nuevo el botón mientras está activa -> debe retraerse inmediatamente
	habilidad.intentar_activar()
	assert_true(habilidad.esta_activa(), "Aun debe estar activa durante la retraccion")
	assert_true(habilidad.get("_en_fase_retraccion_rapida"), "Debe entrar en fase de retraccion rapida")
	assert_false(habilidad.get("_en_fase_aparicion"), "Debe haber salido de fase de aparicion")

	# Simular avance de retraccion
	habilidad._process(0.1)
	var radio_durante_retraccion: float = habilidad.obtener_radio()
	assert_true(radio_durante_retraccion < radio_antes_cancelar, "El radio debe disminuir durante la retraccion")

	# Simular avance hasta completar retracción
	habilidad._process(0.3)
	assert_false(habilidad.esta_activa(), "Debe quedar inactiva al terminar la retraccion")
	assert_true(habilidad.cooldown_actual > 0.0, "Debe entrar en cooldown tras retraerse")

	# Simular cooldown completo
	habilidad._process(habilidad.tiempo_recarga + 0.1)
	assert_true(habilidad.cooldown_actual == 0.0, "Cooldown debe expirar")
