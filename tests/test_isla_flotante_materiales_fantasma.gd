@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

func suite_name() -> String:
	return "isla_flotante_materiales_fantasma"

func test_cambio_materiales_vivo_y_fantasma() -> void:
	var tree = Engine.get_main_loop() as SceneTree
	var isla = track(IslaFlotante.new()) as IslaFlotante
	assert_ne(isla, null, "IslaFlotante instanciada")

	if tree and tree.root:
		tree.root.add_child(isla)

	# 1. En vista por defecto del Reino Vivo
	isla.vista_fantasma_en_editor = false
	isla._actualizar_materiales()

	var mesh_inst = isla.get_node_or_null("MeshInstance3D") as MeshInstance3D
	assert_ne(mesh_inst, null, "MeshInstance3D debe existir")
	
	var mat_sup_vivo = mesh_inst.get_surface_override_material(0)
	var mat_roca_vivo = mesh_inst.get_surface_override_material(1)
	assert_eq(mat_sup_vivo, IslaFlotante.MAT_HIERBA_DEFAULT, "En Reino Vivo, superficie 0 debe ser hierba dorada por defecto")
	assert_eq(mat_roca_vivo, IslaFlotante.MAT_ROCA_DEFAULT, "En Reino Vivo, superficie 1 debe ser roca cálida por defecto")

	# 2. En vista del Reino Fantasma
	isla.vista_fantasma_en_editor = true
	isla._actualizar_materiales()

	var mat_sup_fant = mesh_inst.get_surface_override_material(0)
	var mat_roca_fant = mesh_inst.get_surface_override_material(1)
	assert_eq(mat_sup_fant, IslaFlotante.MAT_HIERBA_FANTASMA_DEFAULT, "En Reino Fantasma, superficie 0 debe ser material azul oscuro grisáceo")
	assert_eq(mat_roca_fant, IslaFlotante.MAT_ROCA_FANTASMA_DEFAULT, "En Reino Fantasma, superficie 1 debe ser roca azul oscura grisácea")
	assert_true(mat_sup_fant is ShaderMaterial, "Material de hierba fantasma debe ser ShaderMaterial")
	assert_true(mat_roca_fant is ShaderMaterial, "Material de roca fantasma debe ser ShaderMaterial")

	# 3. Retorno al Reino Vivo
	isla.vista_fantasma_en_editor = false
	isla._actualizar_materiales()

	assert_eq(mesh_inst.get_surface_override_material(0), IslaFlotante.MAT_HIERBA_DEFAULT, "Debe restaurar hierba dorada para el Vivo")
	assert_eq(mesh_inst.get_surface_override_material(1), IslaFlotante.MAT_ROCA_DEFAULT, "Debe restaurar roca cálida para el Vivo")

func test_plataforma_espiritual_conserva_material_propio() -> void:
	var tree = Engine.get_main_loop() as SceneTree
	var isla_esp = track(IslaFlotante.new()) as IslaFlotante
	isla_esp.tipo_comportamiento = IslaFlotante.TipoComportamiento.ESPIRITUAL

	if tree and tree.root:
		tree.root.add_child(isla_esp)

	var mesh_inst = isla_esp.get_node_or_null("MeshInstance3D") as MeshInstance3D
	assert_ne(mesh_inst, null, "MeshInstance3D espiritual debe existir")

	isla_esp.vista_fantasma_en_editor = true
	isla_esp._actualizar_materiales()
	var mat_0_fant = mesh_inst.get_surface_override_material(0)
	assert_ne(mat_0_fant, IslaFlotante.MAT_HIERBA_FANTASMA_DEFAULT, "Plataforma espiritual no debe ser reemplazada por hierba normal de fantasma")

	isla_esp.vista_fantasma_en_editor = false
	isla_esp._actualizar_materiales()
	var mat_0_vivo = mesh_inst.get_surface_override_material(0)
	assert_eq(mat_0_fant, mat_0_vivo, "Plataforma espiritual preserva su material espiritual en ambos estados")
