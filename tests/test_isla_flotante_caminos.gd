@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

func suite_name() -> String:
	return "isla_flotante_caminos"

func suite_setup(_ctx: Dictionary) -> void:
	pass

func test_pintura_caminos_y_evaluacion() -> void:
	var isla = track(IslaFlotante.new()) as IslaFlotante
	assert_ne(isla, null, "IslaFlotante instanciada")

	# Inicialmente sin caminos
	assert_eq(isla.trazos_pintura_caminos.size(), 0, "No debe haber trazos iniciales")
	var peso_cero = isla.calcular_peso_camino_en(Vector3.ZERO)
	assert_eq(peso_cero, 0.0, "El peso inicial en el centro debe ser 0.0")

	# Aplicar trazo de camino
	isla.aplicar_trazo_camino(Vector3.ZERO, 3.0, 1.0, false)
	assert_eq(isla.trazos_pintura_caminos.size(), 1, "Debe registrar 1 trazo de camino")

	# El centro debe tener peso máximo 1.0
	var peso_centro = isla.calcular_peso_camino_en(Vector3.ZERO)
	assert_gt(peso_centro, 0.9, "El peso en el centro del trazo debe ser ~1.0")

	# Lejos del trazo el peso debe ser 0.0
	var peso_lejos = isla.calcular_peso_camino_en(Vector3(10.0, 0.0, 10.0))
	assert_eq(peso_lejos, 0.0, "Fuera del radio el peso debe ser 0.0")

	# Deshacer trazo
	isla.deshacer_ultimo_trazo_camino()
	assert_eq(isla.trazos_pintura_caminos.size(), 0, "Al deshacer debe volver a 0 trazos")
	assert_eq(isla.calcular_peso_camino_en(Vector3.ZERO), 0.0, "Tras deshacer, peso debe ser 0.0")

	# Probar borrado continuo (borrar sobre trazo existente)
	isla.aplicar_trazo_camino(Vector3.ZERO, 3.0, 1.0, false)
	assert_gt(isla.calcular_peso_camino_en(Vector3.ZERO), 0.9, "Debe tener tierra pintada")
	isla.aplicar_trazo_camino(Vector3.ZERO, 3.0, 1.0, true)
	assert_true(isla.calcular_peso_camino_en(Vector3.ZERO) < 0.05, "Al borrar debe reducirse a ~0.0 césped")
	isla.trazos_pintura_caminos.clear()

	# Probar pintura de Tierra Clara (tipo = 0)
	isla.trazos_pintura_caminos.clear()
	isla.aplicar_trazo_camino(Vector3.ZERO, 3.0, 1.0, false, 0)
	assert_eq(isla.trazos_pintura_caminos.size(), 1, "Debe registrar 1 trazo de tierra clara")
	var pesos_tc = isla.calcular_pesos_superficie_en(Vector3.ZERO)
	assert_gt(pesos_tc.x, 0.9, "El peso de tierra clara (X) debe ser ~1.0")
	assert_eq(pesos_tc.y, 0.0, "El peso de tierra oscura (Y) debe ser 0.0")
	assert_eq(pesos_tc.z, 0.0, "El peso de roca (Z) debe ser 0.0")
	assert_eq(pesos_tc.w, 0.0, "El peso de pasto (W) debe ser 0.0")

	# Probar pintura de Tierra Oscura (tipo = 1)
	isla.trazos_pintura_caminos.clear()
	isla.aplicar_trazo_camino(Vector3.ZERO, 3.0, 1.0, false, 1)
	assert_eq(isla.trazos_pintura_caminos.size(), 1, "Debe registrar 1 trazo de tierra oscura")
	var pesos_to = isla.calcular_pesos_superficie_en(Vector3.ZERO)
	assert_gt(pesos_to.y, 0.9, "El peso de tierra oscura (Y) debe ser ~1.0")
	assert_eq(pesos_to.x, 0.0, "El peso de tierra clara (X) debe ser 0.0")
	assert_eq(pesos_to.z, 0.0, "El peso de roca (Z) debe ser 0.0")
	assert_eq(pesos_to.w, 0.0, "El peso de pasto (W) debe ser 0.0")

	# Probar pintura de Roca Base (tipo = 2)
	isla.trazos_pintura_caminos.clear()
	isla.aplicar_trazo_camino(Vector3.ZERO, 3.0, 1.0, false, 2)
	assert_eq(isla.trazos_pintura_caminos.size(), 1, "Debe registrar 1 trazo de roca")
	var pesos_c = isla.calcular_pesos_superficie_en(Vector3.ZERO)
	assert_gt(pesos_c.z, 0.9, "El peso de roca (Z) en el centro debe ser ~1.0")
	assert_eq(pesos_c.x, 0.0, "El peso de tierra clara (X) debe ser 0.0")
	assert_eq(pesos_c.y, 0.0, "El peso de tierra oscura (Y) debe ser 0.0")
	assert_eq(pesos_c.w, 0.0, "El peso de pasto (W) debe ser 0.0")

	# Probar borrado continuo sobre roca
	isla.aplicar_trazo_camino(Vector3.ZERO, 3.0, 1.0, true)
	assert_true(isla.calcular_peso_roca_en(Vector3.ZERO) < 0.05, "Al borrar debe reducirse la roca a ~0.0")
	isla.trazos_pintura_caminos.clear()

	# Probar pintura de Pasto (tipo = 3)
	isla.trazos_pintura_caminos.clear()
	isla.aplicar_trazo_camino(Vector3.ZERO, 3.0, 1.0, false, 3)
	assert_eq(isla.trazos_pintura_caminos.size(), 1, "Debe registrar 1 trazo de pasto")
	var pesos_p = isla.calcular_pesos_superficie_en(Vector3.ZERO)
	assert_gt(pesos_p.w, 0.9, "El peso de pasto (W) en el centro debe ser ~1.0")
	assert_eq(pesos_p.x, 0.0, "El peso de tierra clara (X) debe ser 0.0")
	assert_eq(pesos_p.y, 0.0, "El peso de tierra oscura (Y) debe ser 0.0")
	assert_eq(pesos_p.z, 0.0, "El peso de roca (Z) debe ser 0.0")

	# Probar borrado continuo sobre pasto
	isla.aplicar_trazo_camino(Vector3.ZERO, 3.0, 1.0, true)
	assert_true(isla.calcular_peso_pasto_en(Vector3.ZERO) < 0.05, "Al borrar debe reducirse el pasto a ~0.0")
	isla.trazos_pintura_caminos.clear()

	# Múltiples trazos y limpiar
	isla.aplicar_trazo_camino(Vector3(1.0, 0.0, 0.0), 2.0, 0.8, false)
	isla.aplicar_trazo_camino(Vector3(2.0, 0.0, 0.0), 2.0, 0.8, false)
	assert_eq(isla.trazos_pintura_caminos.size(), 2, "Debe tener 2 trazos")
	isla.limpiar_caminos()
	assert_eq(isla.trazos_pintura_caminos.size(), 0, "Al limpiar debe vaciarse el array")
	assert_eq(isla.calcular_peso_camino_en(Vector3(1.0, 0.0, 0.0)), 0.0, "Tras limpiar, peso debe ser 0.0")

	# Probar setter limpiar_todo_el_camino
	isla.aplicar_trazo_camino(Vector3.ZERO, 2.0, 1.0, false)
	assert_eq(isla.trazos_pintura_caminos.size(), 1)
	isla.set("limpiar_todo_el_camino", true)
	assert_eq(isla.trazos_pintura_caminos.size(), 0, "El setter limpiar_todo_el_camino debe vaciar trazos")


func test_malla_uv2_con_caminos() -> void:
	var isla = track(IslaFlotante.new()) as IslaFlotante
	isla.ancho = 10.0
	isla.largo = 10.0
	isla.generar_pasto = true
	# Pintar Tierra Clara (tipo = 0)
	isla.aplicar_trazo_camino(Vector3.ZERO, 3.0, 1.0, false, 0)
	isla.regenerar()

	assert_ne(isla._mesh_instance.mesh, null, "La malla debe generarse")
	var m = isla._mesh_instance.mesh
	var surf_count = m.get_surface_count()
	assert_gt(surf_count, 0, "Debe tener al menos 1 superficie")

	# Verificar si los vértices tienen UV2.x > 0 (Tierra Clara)
	var arrays = m.surface_get_arrays(0)
	var uv2_arr = arrays[Mesh.ARRAY_TEX_UV2] as PackedVector2Array
	assert_ne(uv2_arr.size(), 0, "Debe haber UV2 en la superficie de pasto")
	var max_uv2_x = 0.0
	for uv2 in uv2_arr:
		if uv2.x > max_uv2_x:
			max_uv2_x = uv2.x
	assert_gt(max_uv2_x, 0.5, "El peso máximo de UV2.x (Tierra Clara) debe ser significativo (> 0.5)")

	# Pintar Tierra Oscura (tipo = 1) y verificar UV2.y
	isla.trazos_pintura_caminos.clear()
	isla.aplicar_trazo_camino(Vector3.ZERO, 3.0, 1.0, false, 1)
	isla.regenerar()
	var arrays_to = isla._mesh_instance.mesh.surface_get_arrays(0)
	var uv2_arr_to = arrays_to[Mesh.ARRAY_TEX_UV2] as PackedVector2Array
	var max_uv2_y = 0.0
	for uv2 in uv2_arr_to:
		if uv2.y > max_uv2_y:
			max_uv2_y = uv2.y
	assert_gt(max_uv2_y, 0.5, "El peso máximo de UV2.y (Tierra Oscura) debe ser significativo (> 0.5)")

	# Pintar Roca Base (tipo = 2) y verificar UV.x
	isla.trazos_pintura_caminos.clear()
	isla.aplicar_trazo_camino(Vector3.ZERO, 3.0, 1.0, false, 2)
	isla.regenerar()
	var arrays_roca = isla._mesh_instance.mesh.surface_get_arrays(0)
	var uv_arr_roca = arrays_roca[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	var max_uv_x = 0.0
	for uv in uv_arr_roca:
		if uv.x > max_uv_x:
			max_uv_x = uv.x
	assert_gt(max_uv_x, 0.5, "El peso máximo de UV.x (Roca Base) debe ser significativo (> 0.5)")

	# Pintar Pasto (tipo = 3) y verificar UV.y
	isla.trazos_pintura_caminos.clear()
	isla.aplicar_trazo_camino(Vector3.ZERO, 3.0, 1.0, false, 3)
	isla.regenerar()
	var arrays_pasto = isla._mesh_instance.mesh.surface_get_arrays(0)
	var uv_arr_pasto = arrays_pasto[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	var max_uv_y = 0.0
	for uv in uv_arr_pasto:
		if uv.y > max_uv_y:
			max_uv_y = uv.y
	assert_gt(max_uv_y, 0.5, "El peso máximo de UV.y (Pasto) debe ser significativo (> 0.5)")


func test_malla_uv2_cuando_generar_pasto_es_falso() -> void:
	var isla = track(IslaFlotante.new()) as IslaFlotante
	isla.ancho = 10.0
	isla.largo = 10.0
	isla.generar_pasto = false
	isla.generar_rocas_satelite = false
	isla.aplicar_trazo_camino(Vector3.ZERO, 3.0, 1.0, false, 0)
	isla.regenerar()

	assert_ne(isla._mesh_instance.mesh, null, "La malla debe generarse")
	var m = isla._mesh_instance.mesh
	var arrays = m.surface_get_arrays(0)
	var uv2_arr = arrays[Mesh.ARRAY_TEX_UV2] as PackedVector2Array
	var max_uv2_x = 0.0
	if uv2_arr != null and uv2_arr.size() > 0:
		for uv2 in uv2_arr:
			if uv2.x > max_uv2_x:
				max_uv2_x = uv2.x
	assert_gt(max_uv2_x, 0.5, "El peso UV2.x en la superficie rocosa también debe recibir pintura de caminos")

	# Ahora pintar pasto sobre la isla de roca pura y verificar que se almacena en UV.y
	isla.trazos_pintura_caminos.clear()
	isla.aplicar_trazo_camino(Vector3.ZERO, 3.0, 1.0, false, 3)
	isla.regenerar()
	var m2 = isla._mesh_instance.mesh
	var arrays2 = m2.surface_get_arrays(0)
	var uv_arr = arrays2[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	var max_uv_y = 0.0
	if uv_arr != null and uv_arr.size() > 0:
		for uv in uv_arr:
			if uv.y > max_uv_y:
				max_uv_y = uv.y
	assert_gt(max_uv_y, 0.5, "El peso UV.y en la superficie rocosa debe registrar pintura de pasto")


func test_alternar_generar_pasto_mantiene_forma_y_materiales() -> void:
	var isla = track(IslaFlotante.new()) as IslaFlotante
	isla.ancho = 10.0
	isla.largo = 10.0
	isla.generar_rocas_satelite = false

	# 1. Con generar_pasto = true y faldón desactivado (por defecto)
	isla.generar_pasto = true
	isla.generar_faldon_pasto = false
	isla.regenerar()

	assert_ne(isla._mesh_instance.mesh, null, "La malla con pasto debe existir")
	assert_eq(isla._mesh_instance.mesh.get_surface_count(), 1, "Debe tener 1 superficie monolítica (sin generar malla de pasto secundaria)")
	var mat0 = isla._mesh_instance.get_surface_override_material(0) as ShaderMaterial
	assert_ne(mat0, null, "Superficie 0 debe tener material")
	var tiene_pasto = mat0.get_shader_parameter("habilitar_pasto_distancia")
	assert_eq(tiene_pasto, true, "Con generar_pasto activo, debe tener habilitar_pasto_distancia = true")
	var aabb_con_pasto = isla._mesh_instance.mesh.get_aabb()

	# 2. Con generar_pasto = false
	isla.generar_pasto = false
	isla.regenerar()

	assert_ne(isla._mesh_instance.mesh, null, "La malla de roca pura debe existir")
	assert_eq(isla._mesh_instance.mesh.get_surface_count(), 1, "Debe tener 1 superficie monolítica de roca")
	var mat_roca_pura = isla._mesh_instance.get_surface_override_material(0) as ShaderMaterial
	assert_ne(mat_roca_pura, null, "Superficie 0 debe tener material de roca pura")
	var tiene_pasto_dist = mat_roca_pura.get_shader_parameter("habilitar_pasto_distancia")
	assert_eq(mat_roca_pura.resource_path, "res://assets/materiales/entorno/m_isla_roca_pura.tres")
	assert_eq(tiene_pasto_dist, false)
	var aabb_sin_pasto = isla._mesh_instance.mesh.get_aabb()

	# La forma y dimensiones exteriores deben mantenerse (sin distorsión de faldón ni picos inflados)
	assert_true(absf(aabb_con_pasto.size.x - aabb_sin_pasto.size.x) < 0.1, "El ancho no debe cambiar por el pasto")
	assert_true(absf(aabb_con_pasto.size.z - aabb_sin_pasto.size.z) < 0.1, "El largo no debe cambiar por el pasto")


func test_inspeccionar_isla_camino_nodo() -> void:
	var tree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var isla = tree.root.find_child("IslaCamino", true, false) as IslaFlotante
	if isla == null:
		skip("IslaCamino no está en la escena activa")
		return
	isla.regenerar()
	assert_gt(isla.trazos_pintura_caminos.size(), 0, "IslaCamino debe tener trazos")
	var m = isla._mesh_instance.mesh
	assert_ne(m, null, "IslaCamino debe tener malla")
	assert_gt(m.get_surface_count(), 0, "Tiene al menos 1 superficie")
	var arr0 = m.surface_get_arrays(0)
	var uv2_0 = arr0[Mesh.ARRAY_TEX_UV2] as PackedVector2Array
	var max_0 = 0.0
	for uv in uv2_0:
		if uv.x > max_0:
			max_0 = uv.x
	assert_gt(max_0, 0.9, "Superficie 0 (pasto) tiene UV2 > 0.9")
	if m.get_surface_count() > 1:
		var arr1 = m.surface_get_arrays(1)
		var uv2_1 = arr1[Mesh.ARRAY_TEX_UV2] as PackedVector2Array
		var max_1 = 0.0
		for uv in uv2_1:
			if uv.x > max_1:
				max_1 = uv.x
		assert_gt(max_1, 0.9, "Superficie 1 (roca) tiene UV2 > 0.9")
	var max_uv2 = 0.0
	for s in range(m.get_surface_count()):
		var arr = m.surface_get_arrays(s)
		var uv2s = arr[Mesh.ARRAY_TEX_UV2] as PackedVector2Array
		if uv2s != null:
			for uv in uv2s:
				if uv.x > max_uv2:
					max_uv2 = uv.x
	assert_gt(max_uv2, 0.9, "Al menos una superficie de IslaCamino debe tener UV2 > 0.9")


func test_pinceles_mutua_exclusion_y_acciones() -> void:
	var isla = track(IslaFlotante.new()) as IslaFlotante
	assert_ne(isla, null)

	# 1. Por defecto ambos desactivados
	assert_eq(isla.activar_pincel_terreno, false)
	assert_eq(isla.activar_pincel_camino, false)

	# 2. Activar pincel terreno -> solo terreno activo
	isla.activar_pincel_terreno = true
	assert_eq(isla.activar_pincel_terreno, true, "Terreno debe estar activo")
	assert_eq(isla.activar_pincel_camino, false, "Camino debe permanecer desactivado")

	# 3. Activar pincel camino -> desactiva automáticamente terreno (mutua exclusión)
	isla.activar_pincel_camino = true
	assert_eq(isla.activar_pincel_camino, true, "Camino debe estar activo")
	assert_eq(isla.activar_pincel_terreno, false, "Terreno debe haberse desactivado")

	# 4. Volver a activar terreno -> desactiva automáticamente camino
	isla.activar_pincel_terreno = true
	assert_eq(isla.activar_pincel_terreno, true, "Terreno debe volver a estar activo")
	assert_eq(isla.activar_pincel_camino, false, "Camino debe haberse desactivado")

	# 5. Probar acción de esculpido (Elevar)
	var h_antes = isla.calcular_altura_en(Vector2.ZERO)
	isla.modo_pincel_terreno = IslaFlotante.ModoPincelTerreno.ELEVAR
	isla.aplicar_trazo_esculpido(Vector3.ZERO, 3.5, 2.0, 0, 0)
	var h_despues = isla.calcular_altura_en(Vector2.ZERO)
	assert_gt(h_despues, h_antes + 1.0, "Esculpir Elevar debe haber elevado el terreno")

	# 6. Probar acción de pintura de caminos (Tierra Clara)
	isla.activar_pincel_camino = true
	isla.modo_accion_camino = 0 # Tierra clara
	isla.aplicar_trazo_camino(Vector3.ZERO, 3.0, 0.9, false, 0)
	var pesos = isla.calcular_pesos_superficie_en(Vector3.ZERO)
	assert_gt(pesos.x, 0.7, "Debe registrar pintura de tierra clara")
	assert_eq(pesos.y, 0.0, "No debe registrar tierra oscura")

	# 7. Pintar tierra oscura
	isla.modo_accion_camino = 1 # Tierra oscura
	isla.aplicar_trazo_camino(Vector3.ZERO, 3.0, 0.9, false, 1)
	pesos = isla.calcular_pesos_superficie_en(Vector3.ZERO)
	assert_gt(pesos.y, 0.7, "Debe registrar pintura de tierra oscura")

	# 8. Pintar roca base
	isla.modo_accion_camino = 2 # Roca base
	isla.aplicar_trazo_camino(Vector3.ZERO, 3.0, 0.9, false, 2)
	pesos = isla.calcular_pesos_superficie_en(Vector3.ZERO)
	assert_gt(pesos.z, 0.7, "Debe registrar pintura de roca base")

	# 9. Pintar pasto
	isla.modo_accion_camino = 3 # Pasto
	isla.aplicar_trazo_camino(Vector3.ZERO, 3.0, 0.9, false, 3)
	pesos = isla.calcular_pesos_superficie_en(Vector3.ZERO)
	assert_gt(pesos.w, 0.7, "Debe registrar pintura de pasto")


func test_aislamiento_superficie_vs_acantilado() -> void:
	var isla = track(IslaFlotante.new()) as IslaFlotante
	assert_ne(isla, null)
	isla.ancho = 10.0
	isla.largo = 10.0
	isla.profundidad_roca = 6.0
	isla.aplicar_trazo_camino(Vector3.ZERO, 4.0, 1.0, false, 0)
	isla.regenerar()

	var mi = isla.get_node_or_null("MeshInstance3D") as MeshInstance3D
	assert_ne(mi, null, "MeshInstance3D debe existir")
	assert_ne(mi.mesh, null, "Malla debe estar generada")

	var arrays = mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uvs2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]

	assert_gt(verts.size(), 0, "Debe haber vértices generados")

	var count_superficie := 0
	var count_acantilado := 0

	for i in range(verts.size()):
		var col = colors[i]
		if col.a > 0.8:
			count_superficie += 1
			# Vértice de superficie: puede tener UV / UV2 de pintura
		elif col.a >= 0.5:
			count_acantilado += 1
			# Vértice de acantilado rocoso (COLOR.a = 0.55):
			# UV y UV2 deben ser estrictamente Vector2.ZERO para que nunca reciba pintura
			assert_eq(uvs[i], Vector2.ZERO, "UV en acantilado debe ser Vector2.ZERO")
			assert_eq(uvs2[i], Vector2.ZERO, "UV2 en acantilado debe ser Vector2.ZERO")

	assert_gt(count_superficie, 0, "Debe haber vértices etiquetados como superficie (a > 0.8)")
	assert_gt(count_acantilado, 0, "Debe haber vértices etiquetados como acantilado (a <= 0.55)")
