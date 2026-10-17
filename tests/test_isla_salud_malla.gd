@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

## Test de integridad y salud geométrica de las islas flotantes
## Verifica que no existan triángulos doblados, normales invertidas ni divergencia severa
## que causen facetas negras (terminator problem / shadow acne).
func suite_name() -> String:
	return "test_isla_salud_malla"

func test_salud_geometrica_isla_salto1() -> void:
	var script = ResourceLoader.load("res://scripts/entorno/isla_flotante.gd", "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
	var isla = script.new()
	isla.preset = isla.PresetTamano.PERSONALIZADA
	isla.ancho = 5.0
	isla.largo = 5.0
	isla.profundidad_roca = 2.0
	isla.irregularidad_contorno = 0.28
	isla.segmentos_perimetro = 18
	isla.anillos_roca = 5
	isla.anillos_superficie = 2
	isla.intensidad_variacion = 0.35
	isla.semilla = 53086525
	isla.generar_pasto = false
	isla.regenerar()

	var mesh_inst = isla.get_node_or_null("MeshInstance3D") as MeshInstance3D
	assert_ne(mesh_inst, null, "La isla debe instanciar MeshInstance3D")
	var mesh = mesh_inst.mesh
	assert_ne(mesh, null, "La malla de la isla no debe ser nula")

	var arr = mesh.surface_get_arrays(0)
	var verts = arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var norms = arr[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var indices = arr[Mesh.ARRAY_INDEX] as PackedInt32Array
	var num_tris = indices.size() / 3

	var normales_opuestas := 0
	for t in range(num_tris):
		var i0 = indices[t * 3]
		var i1 = indices[t * 3 + 1]
		var i2 = indices[t * 3 + 2]

		var v0 = verts[i0]
		var v1 = verts[i1]
		var v2 = verts[i2]

		var n0 = norms[i0]
		var n1 = norms[i1]
		var n2 = norms[i2]
		var n_avg = (n0 + n1 + n2).normalized()

		# Normal frontal geométrica en Godot: (v2 - v0) x (v1 - v0)
		var geo_n = (v2 - v0).cross(v1 - v0).normalized()

		# Una normal opuesta (dot < 0) apunta hacia adentro de la roca y genera facetas negras
		if geo_n.dot(n_avg) < 0.0:
			normales_opuestas += 1

	assert_eq(normales_opuestas, 0, "No debe haber ningún triángulo con normal de sombreado apuntando hacia adentro")
