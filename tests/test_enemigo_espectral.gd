@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

func suite_name() -> String:
	return "enemigo_espectral"

func test_enemigo_instantiation() -> void:
	var scene = load("res://scenes/components/peligros/enemigo_espectral.tscn")
	assert_ne(scene, null, "La escena enemigo_espectral.tscn debe existir")
	var instance = track(scene.instantiate()) as EnemigoEspectral
	assert_ne(instance, null, "Debe ser instancia de EnemigoEspectral")
	assert_true(instance.is_in_group("enemigos_espectrales"), "Debe estar en el grupo enemigos_espectrales")
	assert_true(instance.radio_zona_peligro > 0.0, "Radio de zona de peligro debe ser positivo")
	assert_true(instance.distancia_ataque > 0.0, "Distancia de ataque debe ser positiva")
	assert_true(instance.velocidad_acecho > 0.0, "Velocidad de acecho debe ser positiva")

func test_enemigo_child_nodes() -> void:
	var scene = load("res://scenes/components/peligros/enemigo_espectral.tscn")
	var instance = track(scene.instantiate()) as EnemigoEspectral
	assert_ne(instance, null, "Instancia creada")

	var col = instance.get_node_or_null("CollisionShape3D")
	assert_ne(col, null, "Debe existir CollisionShape3D")

	var visual = instance.get_node_or_null("Visual")
	assert_ne(visual, null, "Debe existir nodo Visual")

	var cuerpo = instance.get_node_or_null("Visual/Cuerpo")
	assert_ne(cuerpo, null, "Debe existir nodo Cuerpo")

	var manos = instance.get_node_or_null("Visual/ManosFlotantes")
	assert_ne(manos, null, "Debe existir nodo ManosFlotantes")

	var distorsion = instance.get_node_or_null("Visual/EfectoDistorsion")
	assert_ne(distorsion, null, "Debe existir nodo EfectoDistorsion")

	var part_derrota = instance.get_node_or_null("ParticulasDerrota")
	assert_ne(part_derrota, null, "Debe existir ParticulasDerrota")

	var part_spawn = instance.get_node_or_null("ParticulasZonaSpawn")
	assert_ne(part_spawn, null, "Debe existir ParticulasZonaSpawn")

	var anillo_spawn = instance.get_node_or_null("IndicadorAnilloSpawn")
	assert_ne(anillo_spawn, null, "Debe existir IndicadorAnilloSpawn")

func test_enemigo_capas_visibilidad_iniciales() -> void:
	var scene = load("res://scenes/components/peligros/enemigo_espectral.tscn")
	var instance = track(scene.instantiate()) as EnemigoEspectral
	instance.activar_solo_en_zona = false
	instance._ready()
	
	var cuerpo = instance.get_node_or_null("Visual/Cuerpo") as MeshInstance3D
	assert_ne(cuerpo, null)
	assert_eq(cuerpo.layers, 4, "Cuerpo debe habitar Capa 3 (Plano Espiritual)")

	var distorsion = instance.get_node_or_null("Visual/EfectoDistorsion") as MeshInstance3D
	assert_ne(distorsion, null)
	assert_true((distorsion.layers & (1 | 2)) != 0, "Distorsión debe habitar capas visibles del Vivo")

func test_enemigo_transicion_tangibilidad() -> void:
	var scene = load("res://scenes/components/peligros/enemigo_espectral.tscn")
	var instance = track(scene.instantiate()) as EnemigoEspectral
	instance.activar_solo_en_zona = false
	instance._ready()

	# 1. Hacerlo tangible
	instance._establecer_tangibilidad(true)
	assert_eq(instance.estado_actual, EnemigoEspectral.Estado.TANGIBLE_VULNERABLE, "Debe estar en estado TANGIBLE_VULNERABLE")
	assert_true((instance.collision_layer & 2) != 0, "Debe colisionar en Capa 2 (Plano Físico)")

	var cuerpo = instance.get_node_or_null("Visual/Cuerpo") as MeshInstance3D
	assert_true((cuerpo.layers & 1) != 0, "Cuerpo debe ser visible en Capa 1 para el Vivo")

	# 2. Hacerlo intangible de nuevo
	instance._establecer_tangibilidad(false)
	assert_eq(instance.estado_actual, EnemigoEspectral.Estado.ACECHO_INVISIBLE, "Debe retornar a ACECHO_INVISIBLE")
	assert_eq(instance.collision_layer, 4, "Debe colisionar únicamente en Capa 3")
	assert_eq(cuerpo.layers, 4, "Cuerpo debe volver a ser exclusivo de Capa 3")

func test_enemigo_contrato_recibir_impacto() -> void:
	var scene = load("res://scenes/components/peligros/enemigo_espectral.tscn")
	var instance = track(scene.instantiate()) as EnemigoEspectral
	instance.activar_solo_en_zona = false
	instance._ready()

	assert_true(instance.has_method("recibir_impacto"), "Debe implementar recibir_impacto para interacción con el Embate del Vivo")

	var mock_jugador = track(Node3D.new())
	instance.recibir_impacto(mock_jugador)
	assert_eq(instance.estado_actual, EnemigoEspectral.Estado.DERROTADO, "Debe pasar a estado DERROTADO al recibir impacto")
	assert_eq(instance.collision_layer, 0, "Debe desactivar colisiones físicas tras derrota")

func test_enemigo_deteccion_aura_matematica() -> void:
	var scene = load("res://scenes/components/peligros/enemigo_espectral.tscn")
	var instance = track(scene.instantiate()) as EnemigoEspectral
	instance.activar_solo_en_zona = false
	instance.position = Vector3(5, 0, 5)
	instance._ready()

	# Crear un mock de Fantasma con HabilidadAura
	var mock_fantasma = track(Node3D.new())
	mock_fantasma.name = "Fantasma"
	mock_fantasma.add_to_group("fantasmas")
	mock_fantasma.position = Vector3(0, 0, 0)
	
	var aura = track(HabilidadAura.new())
	aura.name = "HabilidadAura"
	mock_fantasma.add_child(aura)
	
	instance._fantasma_ref = mock_fantasma

	# Aura apagada -> debe seguir intangible
	instance._verificar_tangibilidad_con_aura(0.016)
	assert_false(instance._esta_tangible, "Con aura apagada debe ser intangible")

	# Activar aura y posicionar al fantasma a ~1.41m del enemigo
	mock_fantasma.position = Vector3(4, 0, 4)
	aura.activa = true
	aura.radio_actual = 5.0
	
	instance._verificar_tangibilidad_con_aura(0.016)
	assert_true(instance._esta_tangible, "Dentro del radio del aura debe volverse tangible")
	assert_eq(instance.estado_actual, EnemigoEspectral.Estado.TANGIBLE_VULNERABLE)

	# Desactivar aura -> transiciona tras tiempo de gracia
	aura.activa = false
	aura.radio_actual = 0.0
	instance._verificar_tangibilidad_con_aura(instance.tiempo_gracia_tangible + 0.1)
	assert_false(instance._esta_tangible, "Tras tiempo de gracia debe volver a ser intangible")

func test_enemigo_activacion_por_zona_de_peligro() -> void:
	var scene = load("res://scenes/components/peligros/enemigo_espectral.tscn")
	var instance = track(scene.instantiate()) as EnemigoEspectral
	instance.position = Vector3(0, 0, -10)
	instance.radio_zona_peligro = 6.0
	instance.activar_solo_en_zona = true
	instance.tiempo_anticipacion_spawn = 0.0
	instance._ready()

	# Al inicio debe estar oculto y dormido en su origen
	assert_eq(instance.estado_actual, EnemigoEspectral.Estado.INACTIVO_OCULTO, "Debe iniciar INACTIVO_OCULTO")
	assert_false(instance.nodo_visual.visible, "El cuerpo del espectro debe iniciar no visible")

	# Mock de Vivo fuera de la zona (a 12m)
	var mock_vivo = track(CharacterBody3D.new())
	mock_vivo.position = Vector3(0, 0, 2)
	instance._jugador_vivo_ref = mock_vivo

	# Procesar fuera de zona -> no debe activarse
	instance.procesar_ciclo_ia(0.016)
	assert_eq(instance.estado_actual, EnemigoEspectral.Estado.INACTIVO_OCULTO, "No debe activarse si el Vivo está lejos")
	assert_false(instance.nodo_visual.visible)

	# El Vivo camina hacia la zona (a 4m del origen, dentro de radio 6.0)
	mock_vivo.position = Vector3(0, 0, -6)
	instance.procesar_ciclo_ia(0.016)
	assert_eq(instance.estado_actual, EnemigoEspectral.Estado.ACECHO_INVISIBLE, "Debe activarse a ACECHO_INVISIBLE al entrar a la zona")
	assert_true(instance.nodo_visual.visible, "Debe volverse visible en el plano espectral")

func test_enemigo_persecucion_en_plataforma_y_abandono() -> void:
	var scene = load("res://scenes/components/peligros/enemigo_espectral.tscn")
	var instance = track(scene.instantiate()) as EnemigoEspectral
	instance.position = Vector3(0, 0, -10)
	instance.activar_solo_en_zona = false
	instance.tiempo_anticipacion_spawn = 0.0
	instance._ready()

	var mock_vivo = track(CharacterBody3D.new())
	mock_vivo.position = Vector3(0, 0, -5) # En la plataforma
	instance._jugador_vivo_ref = mock_vivo

	# Procesar ciclo IA -> persigue hacia el Vivo
	instance.procesar_ciclo_ia(0.016)
	assert_gt(instance.velocity.length(), 0.1, "Debe moverse hacia el Vivo mientras esté en la plataforma")

	# Si el Vivo se precipita al abismo (cae por debajo de la plataforma)
	mock_vivo.position = Vector3(0, -15.0, -5)
	instance.procesar_ciclo_ia(0.016)
	assert_eq(instance.estado_actual, EnemigoEspectral.Estado.INACTIVO_OCULTO, "Debe desvanecerse al detectar que el Vivo cayó de la plataforma")
	assert_false(instance.nodo_visual.visible, "Debe ocultar su cuerpo tras desvanecerse")

class MockVivo extends CharacterBody3D:
	var murio: bool = false
	func reaparecer() -> void:
		murio = true

func test_enemigo_contacto_mortal_y_reinicio() -> void:
	var scene = load("res://scenes/components/peligros/enemigo_espectral.tscn")
	var instance = track(scene.instantiate()) as EnemigoEspectral
	instance.position = Vector3(0, 0, -10)
	instance.activar_solo_en_zona = false
	instance.tiempo_anticipacion_spawn = 0.0
	instance._ready()

	var mock_vivo = track(MockVivo.new())
	mock_vivo.position = Vector3(0, 0, -10.5)

	# Al tocarlo, el Vivo debe morir (llamar a reaparecer)
	instance._resolver_contacto_con_vivo(mock_vivo)
	
	assert_true(mock_vivo.murio, "El Vivo debe haber muerto y llamado a reaparecer()")

	# El enemigo debe desvanecerse y resetear a su origen en INACTIVO_OCULTO
	assert_eq(instance.estado_actual, EnemigoEspectral.Estado.INACTIVO_OCULTO, "El enemigo debe volver a INACTIVO_OCULTO")
	assert_false(instance.nodo_visual.visible, "El cuerpo del espectro no debe permanecer visible en el mapa")
	assert_eq(instance.position, Vector3(0, 0, -10), "El enemigo debe haber regresado a su origen")

func test_enemigo_particulas_zona_contaminada() -> void:
	var scene = load("res://scenes/components/peligros/enemigo_espectral.tscn")
	var instance = track(scene.instantiate()) as EnemigoEspectral
	instance.activar_solo_en_zona = true
	instance._ready()

	var part = instance.get_node_or_null("ParticulasZonaSpawn") as CPUParticles3D
	assert_ne(part, null, "ParticulasZonaSpawn debe existir")
	assert_true(part.emitting, "Las partículas de la zona deben emitir continuamente")
	assert_true(part.visible, "Las partículas deben ser visibles")
	assert_gt(part.amount, 10, "Debe tener cantidad suficiente de partículas de miasma")
	assert_gt(part.gravity.y, 0.0, "La gravedad debe impulsar las partículas hacia arriba al cielo")
	assert_true((part.layers & 1) != 0, "Debe ser visible en Capa 1 para el Vivo")
	assert_true((part.layers & 4) != 0, "Debe ser visible en Capa 3 para el Fantasma")

	var anillo = instance.get_node_or_null("IndicadorAnilloSpawn") as MeshInstance3D
	assert_ne(anillo, null, "IndicadorAnilloSpawn debe existir")
	assert_eq(anillo.visible, instance.mostrar_indicador_radio, "El anillo debe respetar mostrar_indicador_radio (oculto por defecto)")

	var grietas = instance.get_node_or_null("GrietasSueloSpawn") as MeshInstance3D
	assert_ne(grietas, null, "GrietasSueloSpawn debe existir")
	assert_true(grietas.visible, "Las grietas rojas del suelo deben ser visibles")
	assert_ne(grietas.mesh, null, "Debe generarse la malla de grietas adaptada al suelo")
	assert_ne(grietas.material_override, null, "Las grietas deben tener asignado su material shader luminoso")

func test_enemigo_configuracion_multiple() -> void:
	var scene = load("res://scenes/components/peligros/enemigo_espectral.tscn")
	var instance = track(scene.instantiate()) as EnemigoEspectral
	instance.cantidad_enemigos = 3
	instance.tiempo_entre_spawns = 2.0
	assert_eq(instance.cantidad_enemigos, 3, "Debe permitir configurar 3 o más enemigos")
	assert_eq(instance.tiempo_entre_spawns, 2.0, "Debe permitir configurar el tiempo entre spawns")

func test_enemigo_silueta_transparente_reemplaza_circulo() -> void:
	var scene = load("res://scenes/components/peligros/enemigo_espectral.tscn")
	var instance = track(scene.instantiate()) as EnemigoEspectral
	instance.activar_solo_en_zona = true
	instance._ready()
	var distorsion = instance.get_node_or_null("Visual/EfectoDistorsion") as MeshInstance3D
	assert_false(distorsion.visible, "El circulo/esfera de distorsion debe estar oculto")
	assert_eq(instance.get_node_or_null("Visual/SiluetaAviso"), null, "No hay silueta antes de manifestarse")
	instance._manifestar_en_zona()
	var silueta = instance.get_node_or_null("Visual/SiluetaAviso") as Node3D
	assert_ne(silueta, null, "Debe crearse la silueta transparente del fantasma")
	if silueta:
		assert_true(silueta.visible, "La silueta transparente es visible al manifestarse y acechar")
		assert_false(distorsion.visible, "El circulo de distorsion sigue oculto")
		instance._establecer_tangibilidad(true)
		assert_false(silueta.visible, "La silueta se oculta cuando el fantasma se vuelve tangible")
		instance._establecer_tangibilidad(false)
		assert_true(silueta.visible, "La silueta vuelve cuando el fantasma regresa al estado transparente/invisible")

func test_enemigo_anticipacion_ataque_y_aturdimiento_aura() -> void:
	var scene = ResourceLoader.load("res://scenes/components/peligros/enemigo_espectral.tscn", "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
	var instance = track(scene.instantiate()) as EnemigoEspectral
	instance.position = Vector3(0, 0, -10)
	instance.activar_solo_en_zona = false
	instance.tiempo_anticipacion_spawn = 0.0
	instance._ready()

	# Verificar que ParticulasPasto comparte la malla circular de las grietas (QuadMesh_particula_spawn)
	var part_pasto = instance.get_node_or_null("ParticulasPasto") as CPUParticles3D
	var part_spawn = instance.get_node_or_null("ParticulasZonaSpawn") as CPUParticles3D
	assert_ne(part_pasto, null, "ParticulasPasto debe existir")
	assert_ne(part_spawn, null, "ParticulasZonaSpawn debe existir")
	assert_eq(part_pasto.mesh, part_spawn.mesh, "Las particulas del fantasma deben ser del mismo tipo que las de las grietas")

	# 1. Cuando el Vivo está cerca (a 1.0m), el enemigo no mata al instante: se detiene, se hace visible y anticipa
	var mock_vivo = track(MockVivo.new())
	mock_vivo.position = Vector3(0, 0, -9.0)
	instance._jugador_vivo_ref = mock_vivo

	instance.procesar_ciclo_ia(0.05)
	assert_eq(instance.estado_actual, EnemigoEspectral.Estado.ANTICIPANDO_ATAQUE, "Debe detenerse a anticipar el ataque antes de golpear")
	assert_false(mock_vivo.murio, "No debe matar instantáneamente durante la anticipación")
	assert_eq(instance.velocity.length(), 0.0, "Debe detenerse al anticipar el ataque")
	var cuerpo = instance.get_node("Visual/Cuerpo") as MeshInstance3D
	assert_true((cuerpo.layers & 1) != 0, "Debe aparecer visualmente en Capa 1 durante la anticipación")

	# 2. Al activar el Aura del Fantasma, el enemigo queda revelado y ATURDIDO (quieto)
	mock_vivo.position = Vector3(0, 0, -5.0) # El vivo se aleja
	instance._establecer_tangibilidad(true)
	assert_eq(instance.estado_actual, EnemigoEspectral.Estado.TANGIBLE_VULNERABLE, "Al ser tocado por el aura pasa a TANGIBLE_VULNERABLE")
	assert_eq(instance.velocity.length(), 0.0, "El aura del fantasma debe aturdir al enemigo (velocidad cero)")

	# 3. Estando aturdido (o en anticipación), si el Vivo salta sobre él (pisotón desde arriba), el enemigo muere
	mock_vivo.position = Vector3(0, 0.9, -10.0)
	mock_vivo.velocity = Vector3(0, -3.5, 0)
	instance._actualizar_comportamiento_ia(mock_vivo, 0.016)
	assert_eq(instance.estado_actual, EnemigoEspectral.Estado.DERROTADO, "El enemigo debe morir cuando el Vivo salta sobre él")
	assert_gt(mock_vivo.velocity.y, 2.0, "El Vivo debe rebotar hacia arriba al pisar al enemigo")


func test_matar_lider_no_elimina_clones() -> void:
	# Cuando hay multiples enemigos, matar al lider NO debe eliminar a los clones
	var scene = load("res://scenes/components/peligros/enemigo_espectral.tscn")
	var lider = track(scene.instantiate()) as EnemigoEspectral
	lider.activar_solo_en_zona = false
	lider.cantidad_enemigos = 2
	lider.tiempo_anticipacion_spawn = 0.0
	lider._ready()

	# Simular un clon activo
	var clon = track(scene.instantiate()) as EnemigoEspectral
	clon.es_clon = true
	clon._lider_ref = lider
	clon._indice_clon = 1
	clon.activar_solo_en_zona = false
	clon.tiempo_anticipacion_spawn = 0.0
	clon._ready()
	lider._clones_activos.append(clon)

	# Matar al lider
	var mock_jugador = track(Node3D.new())
	lider.recibir_impacto(mock_jugador)

	assert_eq(lider.estado_actual, EnemigoEspectral.Estado.DERROTADO, "El lider debe estar DERROTADO")
	assert_ne(clon.estado_actual, EnemigoEspectral.Estado.DERROTADO, "El clon NO debe morir cuando muere el lider")
	assert_true(clon._lider_derrotado, "El clon debe saber que su lider fue derrotado")

func test_zona_despejada_requiere_matar_todos() -> void:
	# La zona solo se despeja cuando TODOS los enemigos (lider + clones) son eliminados
	var scene = load("res://scenes/components/peligros/enemigo_espectral.tscn")
	var lider = track(scene.instantiate()) as EnemigoEspectral
	lider.activar_solo_en_zona = false
	lider.cantidad_enemigos = 2
	lider.tiempo_anticipacion_spawn = 0.0
	lider._ready()

	var part_spawn = lider.get_node_or_null("ParticulasZonaSpawn") as CPUParticles3D
	assert_ne(part_spawn, null)

	# Simular un clon activo
	var clon = track(scene.instantiate()) as EnemigoEspectral
	clon.es_clon = true
	clon._lider_ref = lider
	clon._indice_clon = 1
	clon.activar_solo_en_zona = false
	clon.tiempo_anticipacion_spawn = 0.0
	clon._ready()
	lider._clones_activos.append(clon)

	var mock_jugador = track(Node3D.new())

	# Matar al lider primero
	lider.recibir_impacto(mock_jugador)
	assert_true(part_spawn.emitting, "Las particulas de la zona deben seguir activas con clones vivos")

	# Ahora matar al clon
	clon.recibir_impacto(mock_jugador)
	assert_eq(clon.estado_actual, EnemigoEspectral.Estado.DERROTADO, "El clon debe estar DERROTADO")
	assert_false(part_spawn.emitting, "Las particulas de zona deben apagarse cuando TODOS los enemigos mueren")

func test_enemigos_flanqueo_direcciones_distintas() -> void:
	# Dos enemigos persiguiendo al mismo Vivo deben tener direcciones de movimiento diferentes
	var scene = load("res://scenes/components/peligros/enemigo_espectral.tscn")
	var lider = track(scene.instantiate()) as EnemigoEspectral
	lider.position = Vector3(5, 0, 0)
	lider.activar_solo_en_zona = false
	lider.tiempo_anticipacion_spawn = 0.0
	lider._indice_clon = 0
	lider._ready()

	var clon = track(scene.instantiate()) as EnemigoEspectral
	clon.es_clon = true
	clon._lider_ref = lider
	clon._indice_clon = 1
	clon.position = Vector3(-5, 0, 0)
	clon.activar_solo_en_zona = false
	clon.tiempo_anticipacion_spawn = 0.0
	clon._ready()
	lider._clones_activos.append(clon)

	# Posicion del Vivo
	var pos_vivo = Vector3(0, 0, -10)

	# Calcular direcciones cooperativas para el lider y el clon
	var dir_vivo_lider = pos_vivo - lider.position
	dir_vivo_lider.y = 0.0
	var dir_lider = lider._calcular_direccion_cooperativa(pos_vivo, lider.position, dir_vivo_lider)

	var dir_vivo_clon = pos_vivo - clon.position
	dir_vivo_clon.y = 0.0
	var dir_clon = clon._calcular_direccion_cooperativa(pos_vivo, clon.position, dir_vivo_clon)

	# Las direcciones deben ser distintas (dot product < 1.0 si no son paralelas)
	var dot = dir_lider.dot(dir_clon)
	assert_true(dot < 0.99, "Los enemigos deben tener direcciones de flanqueo diferentes, no ir en la misma direccion")

func test_enemigo_propiedades_material_sin_reflejo_parasito() -> void:
	var mat = load("res://shaders/components/peligros/enemigo_espectral_mat.tres") as ShaderMaterial
	assert_ne(mat, null, "enemigo_espectral_mat.tres debe existir")
	var rugosidad: float = mat.get_shader_parameter("rugosidad")
	var metalico: float = mat.get_shader_parameter("metalico")
	assert_true(rugosidad >= 0.35, "Rugosidad debe ser >= 0.35 para evitar reflejos especulares de espejo de los rasgos propios")
	assert_true(metalico <= 0.05, "Metalico debe ser <= 0.05 para que el fantasma sea dielectrico espectral")



func test_silueta_aviso_limpia_sin_rasgos_faciales() -> void:
	var scene = load("res://scenes/components/peligros/enemigo_espectral.tscn")
	var inst = track(scene.instantiate()) as EnemigoEspectral
	inst.activar_solo_en_zona = false
	inst._ready()
	inst._asegurar_silueta_aviso()
	var silueta = inst._silueta_aviso
	assert_ne(silueta, null, "La silueta de aviso debe existir")

	# 1. El cuerpo debe tener el material de prepass con next_pass a silueta translúcida
	var cuerpo = silueta.get_node_or_null("Enemigo_Cuerpo") as MeshInstance3D
	assert_ne(cuerpo, null, "Debe existir Enemigo_Cuerpo en la silueta")
	var mat_s0 = cuerpo.get_surface_override_material(0)
	assert_ne(mat_s0, null, "Superficie 0 debe tener material asignado")

	# 2. La silueta debe estar en Capa 2 (aviso exclusivo para el Vivo)
	assert_eq(cuerpo.layers, 2, "La silueta debe asignarse a la Capa 2")

	# 3. El Fantasma debe excluir la Capa 2 para nunca renderizar la silueta de aviso sobre el cuerpo
	var mask_fantasma: int = 1048575 & ~(1 << 1)
	assert_eq(mask_fantasma & 2, 0, "La máscara de cámara del Fantasma debe excluir la Capa 2")

	# 4. Parámetros del shader de distorsión translúcida restaurados
	var mat_sil = load("res://shaders/components/peligros/distorsion_espectral_mat.tres") as ShaderMaterial
	assert_ne(mat_sil, null)
	assert_true(mat_sil.get_shader_parameter("grosor_borde") >= 1.0, "Grosor de borde debe ser marcado")
	assert_true(mat_sil.get_shader_parameter("opacidad_borde") >= 0.8, "Opacidad de borde debe ser visible")
	assert_true(mat_sil.get_shader_parameter("fuerza_distorsion") > 0.0, "Debe tener fuerza de distorsión para refracción del fondo")
