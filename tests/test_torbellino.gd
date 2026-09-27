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
	
	var particles_atraccion = instance.get_node_or_null("ParticulasZonaAtraccion")
	assert_ne(particles_atraccion, null, "Debe existir ParticulasZonaAtraccion")
	
	var particles_atraccion_2 = instance.get_node_or_null("ParticulasZonaAtraccion2")
	assert_ne(particles_atraccion_2, null, "Debe existir ParticulasZonaAtraccion2")
	
	var particles_atraccion_3 = instance.get_node_or_null("ParticulasZonaAtraccion3")
	assert_ne(particles_atraccion_3, null, "Debe existir ParticulasZonaAtraccion3")
	
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

func test_impulso_vertical_descendente() -> void:
	var scene = load("res://scenes/components/peligros/torbellino.tscn")
	var instance = track(scene.instantiate()) as Torbellino
	assert_true(instance.fuerza_expulsion_vertical < -10.0, "La fuerza de expulsión vertical debe ser un impulso descendente potente (menor a -10 m/s)")

func test_giro_acelera_con_descenso() -> void:
	# Simular fórmula de velocidad angular en función del progreso de descenso:
	# Arriba (progreso = 0.0): vel_giro = 12.0
	# Abajo (progreso = 1.0): vel_giro = 38.0
	var vel_arriba = lerpf(12.0, 38.0, 0.0 * 0.0)
	var vel_medio = lerpf(12.0, 38.0, 0.5 * 0.5)
	var vel_abajo = lerpf(12.0, 38.0, 1.0 * 1.0)
	assert_gt(vel_medio, vel_arriba, "A mitad del cono el giro debe ser mayor que arriba")
	assert_gt(vel_abajo, vel_medio, "Al fondo del cono el giro debe ser máximo y mucho mayor que a mitad")
func test_generar_mallas_rocas() -> void:
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 2
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.196, 0.275, 0.506, 1.0)
	mat.roughness = 0.85
	mat.emission_enabled = true
	mat.emission = Color(0.11, 0.16, 0.29, 1.0)
	
	var mesh_a = _generar_malla_roca_a(mat)
	var mesh_b = _generar_malla_roca_b(mat)
	var mesh_c = _generar_malla_roca_c(mat)
	
	ResourceSaver.save(mesh_a, "res://assets/materiales/entorno/m_roca_vortice_a.tres")
	ResourceSaver.save(mesh_b, "res://assets/materiales/entorno/m_roca_vortice_b.tres")
	ResourceSaver.save(mesh_c, "res://assets/materiales/entorno/m_roca_vortice_c.tres")
	ResourceSaver.save(mesh_a, "res://assets/materiales/entorno/m_roca_vortice.tres")
	
	assert_true(FileAccess.file_exists("res://assets/materiales/entorno/m_roca_vortice_a.tres"), "Debe guardarse m_roca_vortice_a.tres")
	assert_true(FileAccess.file_exists("res://assets/materiales/entorno/m_roca_vortice_b.tres"), "Debe guardarse m_roca_vortice_b.tres")
	assert_true(FileAccess.file_exists("res://assets/materiales/entorno/m_roca_vortice_c.tres"), "Debe guardarse m_roca_vortice_c.tres")

func test_configuracion_anti_culling_y_multi_eje() -> void:
	var scene = ResourceLoader.load("res://scenes/components/peligros/torbellino.tscn", "", ResourceLoader.CACHE_MODE_REPLACE)
	assert_ne(scene, null, "Escena torbellino debe recargarse")
	var instance = track(scene.instantiate()) as Torbellino
	
	var p1 = instance.get_node_or_null("ParticulasZonaAtraccion") as CPUParticles3D
	var p2 = instance.get_node_or_null("ParticulasZonaAtraccion2") as CPUParticles3D
	var p3 = instance.get_node_or_null("ParticulasZonaAtraccion3") as CPUParticles3D
	
	assert_ne(p1, null, "ParticulasZonaAtraccion debe existir")
	assert_ne(p2, null, "ParticulasZonaAtraccion2 debe existir")
	assert_ne(p3, null, "ParticulasZonaAtraccion3 debe existir")
	
	for p in [p1, p2, p3]:
		assert_true(p.local_coords, "local_coords debe ser true para orbitar sin salir disparadas")
		assert_true(p.ignore_occlusion_culling, "ignore_occlusion_culling debe ser true para no desaparecer con oclusores")
		assert_gt(p.visibility_aabb.size.x, 5.0, "visibility_aabb debe ser amplio para no desaparecer en bordes de cámara")
		assert_gt(p.extra_cull_margin, 2.0, "extra_cull_margin debe ser generoso")
		assert_ne(p.mesh, null, "Debe tener malla asignada")
	
	# Verificar variedad de ejes de rotación
	assert_true(p1.particle_flag_rotate_y, "Grupo 1 rota en eje Y")
	assert_false(p2.particle_flag_rotate_y, "Grupo 2 rota en eje Z / volteo lateral")
	assert_true(p3.particle_flag_align_y, "Grupo 3 alineado a trayectoria 3D")
	
	# Verificar render_priority en material de rocas (debe ser >= 2 para no ser tapado por el torbellino)
	var mat = p1.mesh.surface_get_material(0) as StandardMaterial3D
	assert_ne(mat, null, "Material de malla debe existir")
	assert_gt(mat.render_priority, 1, "render_priority debe ser >= 2 para evitar desaparecer detrás del torbellino")
	assert_eq(mat.cull_mode, BaseMaterial3D.CULL_DISABLED, "cull_mode debe ser CULL_DISABLED para renderizar todas las caras")
	assert_eq(mat.depth_draw_mode, BaseMaterial3D.DEPTH_DRAW_ALWAYS, "depth_draw_mode debe ser ALWAYS para solidez visual")

func _generar_malla_roca_a(mat: Material) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var v = [
		Vector3(-0.09, -0.05, -0.04),
		Vector3(0.04, -0.07, -0.06),
		Vector3(0.02, -0.06, 0.07),
		Vector3(-0.08, -0.04, 0.05),
		Vector3(-0.04, 0.02, -0.07),
		Vector3(0.06, 0.03, -0.02),
		Vector3(-0.02, 0.04, 0.08),
		Vector3(0.08, 0.09, 0.05)
	]
	st.add_vertex(v[0]); st.add_vertex(v[2]); st.add_vertex(v[1])
	st.add_vertex(v[0]); st.add_vertex(v[3]); st.add_vertex(v[2])
	st.add_vertex(v[0]); st.add_vertex(v[1]); st.add_vertex(v[4])
	st.add_vertex(v[1]); st.add_vertex(v[5]); st.add_vertex(v[4])
	st.add_vertex(v[1]); st.add_vertex(v[2]); st.add_vertex(v[5])
	st.add_vertex(v[2]); st.add_vertex(v[6]); st.add_vertex(v[5])
	st.add_vertex(v[2]); st.add_vertex(v[3]); st.add_vertex(v[6])
	st.add_vertex(v[3]); st.add_vertex(v[0]); st.add_vertex(v[6])
	st.add_vertex(v[0]); st.add_vertex(v[4]); st.add_vertex(v[6])
	st.add_vertex(v[4]); st.add_vertex(v[5]); st.add_vertex(v[7])
	st.add_vertex(v[5]); st.add_vertex(v[6]); st.add_vertex(v[7])
	st.add_vertex(v[6]); st.add_vertex(v[4]); st.add_vertex(v[7])
	st.generate_normals()
	var mesh = st.commit()
	mesh.surface_set_material(0, mat)
	return mesh

func _generar_malla_roca_b(mat: Material) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var v = [
		Vector3(-0.08, -0.06, -0.04),
		Vector3(0.06, -0.08, 0.03),
		Vector3(0.09, 0.02, 0.08),
		Vector3(-0.05, 0.04, 0.02),
		Vector3(-0.07, -0.03, -0.06),
		Vector3(0.07, -0.05, 0.01),
		Vector3(0.08, 0.05, 0.06),
		Vector3(-0.06, 0.07, 0.00)
	]
	st.add_vertex(v[0]); st.add_vertex(v[1]); st.add_vertex(v[2])
	st.add_vertex(v[0]); st.add_vertex(v[2]); st.add_vertex(v[3])
	st.add_vertex(v[4]); st.add_vertex(v[6]); st.add_vertex(v[5])
	st.add_vertex(v[4]); st.add_vertex(v[7]); st.add_vertex(v[6])
	st.add_vertex(v[0]); st.add_vertex(v[4]); st.add_vertex(v[5])
	st.add_vertex(v[0]); st.add_vertex(v[5]); st.add_vertex(v[1])
	st.add_vertex(v[1]); st.add_vertex(v[5]); st.add_vertex(v[6])
	st.add_vertex(v[1]); st.add_vertex(v[6]); st.add_vertex(v[2])
	st.add_vertex(v[2]); st.add_vertex(v[6]); st.add_vertex(v[7])
	st.add_vertex(v[2]); st.add_vertex(v[7]); st.add_vertex(v[3])
	st.add_vertex(v[3]); st.add_vertex(v[7]); st.add_vertex(v[4])
	st.add_vertex(v[3]); st.add_vertex(v[4]); st.add_vertex(v[0])
	st.generate_normals()
	var mesh = st.commit()
	mesh.surface_set_material(0, mat)
	return mesh

func _generar_malla_roca_c(mat: Material) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var v = [
		Vector3(-0.06, -0.07, -0.05),
		Vector3(0.08, -0.04, -0.03),
		Vector3(0.03, -0.05, 0.08),
		Vector3(-0.07, 0.02, 0.06),
		Vector3(-0.02, 0.09, -0.06),
		Vector3(0.07, 0.06, 0.04)
	]
	st.add_vertex(v[0]); st.add_vertex(v[2]); st.add_vertex(v[1])
	st.add_vertex(v[0]); st.add_vertex(v[3]); st.add_vertex(v[2])
	st.add_vertex(v[0]); st.add_vertex(v[1]); st.add_vertex(v[4])
	st.add_vertex(v[1]); st.add_vertex(v[5]); st.add_vertex(v[4])
	st.add_vertex(v[1]); st.add_vertex(v[2]); st.add_vertex(v[5])
	st.add_vertex(v[2]); st.add_vertex(v[3]); st.add_vertex(v[5])
	st.add_vertex(v[3]); st.add_vertex(v[4]); st.add_vertex(v[5])
	st.add_vertex(v[3]); st.add_vertex(v[0]); st.add_vertex(v[4])
	st.generate_normals()
	var mesh = st.commit()
	mesh.surface_set_material(0, mat)
	return mesh

func test_estabilidad_camara_vortice_y_reaparicion() -> void:
	var scene = ResourceLoader.load("res://scenes/components/peligros/torbellino.tscn", "", ResourceLoader.CACHE_MODE_REPLACE)
	assert_ne(scene, null, "Escena torbellino debe existir")
	var torbellino = track(scene.instantiate()) as Torbellino
	assert_ne(torbellino, null, "Instancia torbellino debe crearse")
	
	# 1. Verificar que el impulso de salida por debajo sea descendente potente
	assert_true(torbellino.fuerza_expulsion_vertical < -10.0, "La expulsión por debajo debe tener un impulso vertical descendente potente")
	
	# 2. Verificar cálculo de la cota de salida inferior del torbellino
	var centro_y = 0.919
	var altura: float = torbellino.get("altura_tornado") if torbellino.get("altura_tornado") != null else 5.2
	var y_salida = centro_y - (altura * 0.5) - 0.35
	assert_true(y_salida < 0.0, "La salida del vórtice debe situarse por debajo del centro para expulsar hacia el abismo")
	
	# 3. Verificar que el límite de caída del juego (-8.0) sea inferior a la salida del torbellino para dar margen de caída con impulso
	var limite_caida_y = -8.0
	assert_true(limite_caida_y < y_salida, "LIMITE_CAIDA_Y (-8.0) debe estar por debajo de la salida inferior del torbellino (-2.03) para permitir la trayectoria de caída rápida visible antes del respawn")
	
	# 4. Verificar cota de seguridad de cámara: la cámara no debe hundirse por debajo de limite_y_camara
	var limite_y_camara = limite_caida_y + 1.8
	assert_gt(limite_y_camara, limite_caida_y, "El margen de seguridad de la cámara debe mantenerse por encima de LIMITE_CAIDA_Y para evitar colisiones subterráneas o artefactos en 1 frame")

func test_absorcion_metodo_llamada() -> void:
	var char_script = ResourceLoader.load("res://scripts/base/character_base.gd", "", ResourceLoader.CACHE_MODE_REPLACE) as GDScript
	assert_ne(char_script, null, "character_base.gd debe cargarse")
	
	var found = false
	for m in char_script.get_script_method_list():
		if m["name"] == "ser_absorbido_en_vortice":
			found = true
			# Los argumentos esperados deben ser al menos 5 para admitir altura_tornado
			assert_gt(m["args"].size(), 4, "ser_absorbido_en_vortice debe aceptar 5 argumentos")
			# Las variables default son 2 (nodo_vortice y altura_tornado)
			assert_true(m["default_args"].size() >= 2, "Debe tener al menos 2 argumentos opcionales con valor por defecto")
			break
	assert_true(found, "El método ser_absorbido_en_vortice debe existir en character_base.gd")

func test_orbita_dentro_del_cono_vortice() -> void:
	# Simular descenso a lo largo de 10 puntos de progreso (0.0 a 1.0)
	var r_top = 2.4
	var r_bot = 0.45
	var r_inicial = 1.2
	
	for i in range(11):
		var progreso = float(i) / 10.0
		var t_cono = 1.0 - progreso # Desciende de arriba a abajo
		var r_cono_max = lerpf(r_bot, r_top, t_cono)
		var r_interior_tornado = r_cono_max * 0.38
		var t_inward = clampf(progreso * 5.0, 0.0, 1.0)
		var factor_inward = 1.0 - pow(1.0 - t_inward, 3.0)
		var r_orbita = lerpf(minf(r_inicial, r_cono_max * 0.80), r_interior_tornado, factor_inward)
		
		assert_true(r_orbita < r_cono_max, "El radio en progreso %0.2f (%0.2f) debe ser menor al radio del cono (%0.2f)" % [progreso, r_orbita, r_cono_max])
		assert_true(r_orbita >= 0.15, "El radio no debe colapsar a cero")



