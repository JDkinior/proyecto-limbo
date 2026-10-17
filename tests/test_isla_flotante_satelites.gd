@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

func suite_name() -> String:
	return "isla_flotante_satelites"

func test_datos_rocas_satelite_para_levitacion() -> void:
	var isla = track(IslaFlotante.new()) as IslaFlotante
	assert_ne(isla, null, "IslaFlotante instanciada")

	isla.generar_rocas_satelite = true
	isla.cantidad_rocas_satelite = 4
	isla.regenerar()

	var mesh_inst = isla.get_node_or_null("MeshInstance3D") as MeshInstance3D
	assert_ne(mesh_inst, null, "MeshInstance3D debe existir")
	assert_ne(mesh_inst.mesh, null, "Mesh debe haberse generado")

	var mesh = mesh_inst.mesh
	var surface_count = mesh.get_surface_count()
	assert_gt(surface_count, 0, "Debe tener al menos una superficie")

	# Superficie de roca (superficie 1 si generar_pasto=true, o 0 si no)
	var surf_roca_idx = 1 if (isla.generar_pasto and surface_count > 1) else 0
	var arrays = mesh.surface_get_arrays(surf_roca_idx)
	var vertices = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var colors = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
	var uvs2_raw = arrays[Mesh.ARRAY_TEX_UV2]
	
	assert_gt(vertices.size(), 0, "Debe tener vértices de roca")
	assert_eq(colors.size(), vertices.size(), "Debe tener colores por vértice")

	var sat_count = 0
	var main_count = 0
	for i in range(colors.size()):
		var c = colors[i]
		if c.a < 0.5:
			sat_count += 1
		else:
			main_count += 1

	assert_gt(sat_count, 0, "Debe haber vértices de rocas satélite identificados con COLOR.a < 0.5")
	assert_gt(main_count, 0, "Debe haber vértices del cuerpo principal con COLOR.a >= 0.5")

	assert_ne(uvs2_raw, null, "ARRAY_TEX_UV2 debe existir en la superficie de roca")
	if uvs2_raw != null:
		var uvs2 = uvs2_raw as PackedVector2Array
		var sat_uv2_non_zero = false
		for i in range(colors.size()):
			if colors[i].a < 0.5 and uvs2[i].length_squared() > 0.0001:
				sat_uv2_non_zero = true
				break
		assert_true(sat_uv2_non_zero, "Los vértices de rocas satélite deben tener desplazamientos relativos en UV2")
