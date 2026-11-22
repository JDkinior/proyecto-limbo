@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

func suite_name() -> String:
	return "boss_espectral"

func suite_setup(_ctx: Dictionary) -> void:
	pass

func _crear_boss() -> BossEspectral:
	var scene := ResourceLoader.load("res://scenes/components/peligros/boss_espectral.tscn", "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
	var inst := track(scene.instantiate()) as BossEspectral
	return inst

func _crear_plataforma(altura: float, pos: Vector3) -> PlataformaColiseo:
	var scene := ResourceLoader.load("res://scenes/components/peligros/plataforma_coliseo.tscn", "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
	var p := track(scene.instantiate()) as PlataformaColiseo
	p.position = pos
	p.altura_elevada = altura
	p._ready()
	return p

func _crear_mock_fantasma(pos: Vector3) -> Dictionary:
	var f := track(Node3D.new())
	f.name = "Fantasma"
	f.add_to_group("fantasmas")
	f.position = pos
	var aura := track(HabilidadAura.new())
	aura.name = "HabilidadAura"
	f.add_child(aura)
	return {"fantasma": f, "aura": aura}

func test_boss_instantiation_y_nodos() -> void:
	var boss := _crear_boss()
	assert_ne(boss, null, "boss_espectral.tscn debe instanciar BossEspectral")
	assert_true(boss.is_in_group("bosses_espectrales"), "Debe pertenecer al grupo bosses_espectrales")
	assert_eq(boss.vida_maxima, 3, "El jefe debe tener 3 puntos de vida por defecto")
	assert_true(boss.escala_modelo >= 2.0, "El jefe debe ser grande en comparación con los personajes")

	var modelo_esp := boss.get_node_or_null("Visual/ModeloEspectral")
	var modelo_arm := boss.get_node_or_null("Visual/ModeloArmadura")
	assert_ne(modelo_esp, null, "Debe existir Visual/ModeloEspectral (boss_espectral.glb)")
	assert_ne(modelo_arm, null, "Debe existir Visual/ModeloArmadura (boss_armadura.glb)")

	for parte_esp in ["Boss_Cuerpo", "Boss_Copete", "Boss_Ojos", "Boss_Cejas", "Boss_Mano_L", "Boss_Mano_R"]:
		assert_ne(modelo_esp.get_node_or_null(parte_esp), null, "Debe existir nodo espectral: " + parte_esp)
	for parte_arm in BossEspectral.ARMADURA_PIEZAS_ORDEN:
		assert_ne(modelo_arm.get_node_or_null(parte_arm), null, "Debe existir pieza de armadura: " + parte_arm)

func test_boss_estado_inicial_solo_armadura_en_suelo() -> void:
	var boss := _crear_boss()
	boss._ready()

	assert_eq(boss.estado_actual, BossEspectral.Estado.DORMIDO_ARMADURA, "Debe iniciar en DORMIDO_ARMADURA")
	assert_eq(boss.vida_actual, 3, "Debe iniciar con 3 de vida")
	assert_eq(boss.collision_layer, 0, "Dormido no debe tener colisión activa")

	var modelo_arm := boss.get_node("Visual/ModeloArmadura") as Node3D
	var modelo_esp := boss.get_node("Visual/ModeloEspectral") as Node3D
	assert_true(modelo_arm.visible, "La armadura debe ser visible en el suelo al inicio")
	assert_false(modelo_esp.visible, "El espectro debe estar oculto antes de que lleguen ambos personajes")
	assert_ne(boss._silueta_aviso, null, "La silueta de aviso debe crearse")
	assert_false(boss._silueta_aviso.visible, "La silueta debe estar oculta mientras está dormido")

	# Verificar que el casco está mucho más abajo en el suelo que su pose ensamblada
	var casco := modelo_arm.get_node("Boss_Armadura_Casco") as MeshInstance3D
	assert_eq(casco.layers, 1, "La armadura debe habitar Capa 1 (sólida para ambos)")
	var pose_ens: Dictionary = boss._armadura_poses_ensambladas["Boss_Armadura_Casco"]
	assert_true(casco.position.y < (pose_ens["pos"] as Vector3).y - 0.8, "El casco debe reposar en el suelo debajo de su altura ensamblada")

func test_boss_requiere_ambos_personajes_para_despertar() -> void:
	var boss := _crear_boss()
	boss.position = Vector3(0.0, 3.5, -75.5)
	boss.radio_activacion_arena = 13.5

	var plat1 := _crear_plataforma(1.5, Vector3(-6.5, 0.06, 3.6))
	var plat2 := _crear_plataforma(6.55, Vector3(6.3, 0.06, 1.8))
	boss.plataformas_combate = [plat1, plat2]
	boss._ready()

	var vivo := track(CharacterBody3D.new())
	var mock_f := _crear_mock_fantasma(Vector3(0.0, 3.5, -40.0)) # Fantasma lejos fuera del coliseo
	var fantasma: Node3D = mock_f["fantasma"]

	boss._jugador_vivo_ref = vivo
	boss._fantasma_ref = fantasma

	# 1. Solo el Vivo entra al coliseo -> NO despierta todavía
	vivo.position = Vector3(0.0, 3.5, -68.0)
	boss.procesar_ciclo_boss(0.016)
	assert_eq(boss.estado_actual, BossEspectral.Estado.DORMIDO_ARMADURA, "No debe despertar si solo llegó el Vivo")
	assert_false(plat1.esta_elevada, "Las plataformas no deben elevarse antes de que lleguen ambos")

	# 2. Solo el Fantasma entra al coliseo (Vivo sale lejos) -> NO despierta todavía
	vivo.position = Vector3(0.0, 3.5, -40.0)
	fantasma.position = Vector3(2.0, 3.5, -68.0)
	boss.procesar_ciclo_boss(0.016)
	assert_eq(boss.estado_actual, BossEspectral.Estado.DORMIDO_ARMADURA, "No debe despertar si solo llegó el Fantasma")

	# 3. Llegan AMBOS al coliseo -> ¡Despierta y se elevan las plataformas!
	var senal_recibida := {"desperto": false}
	boss.boss_despertado.connect(func(): senal_recibida["desperto"] = true)

	vivo.position = Vector3(-2.0, 3.5, -68.0)
	boss.procesar_ciclo_boss(0.016)
	assert_true(senal_recibida["desperto"], "Debe emitir boss_despertado al llegar ambos personajes")
	assert_eq(boss.estado_actual, BossEspectral.Estado.COMBATE_INTANGIBLE, "Tras despertar debe entrar en COMBATE_INTANGIBLE")
	assert_true(plat1.esta_elevada, "Plataforma 1 debe elevarse al iniciar la pelea")
	assert_true(plat2.esta_elevada, "Plataforma 2 debe elevarse al iniciar la pelea")
	assert_true(absf(plat1.position.y - (0.06 + 1.5)) < 0.05, "Plataforma 1 debe alcanzar su altura elevada")
	assert_true(absf(plat2.position.y - (0.06 + 6.55)) < 0.05, "Plataforma 2 debe alcanzar su altura elevada")

func test_boss_visibilidad_vivo_vs_fantasma_armadura_solida() -> void:
	var boss := _crear_boss()
	boss._ready()
	boss.iniciar_despertar()

	assert_eq(boss.estado_actual, BossEspectral.Estado.COMBATE_INTANGIBLE)

	# 1. Armadura: 100% sólida en Capa 1 (visible para Vivo y Fantasma) y ensamblada
	var modelo_arm := boss.get_node("Visual/ModeloArmadura") as Node3D
	for nombre_pieza in BossEspectral.ARMADURA_PIEZAS_ORDEN:
		var pieza := modelo_arm.get_node(nombre_pieza) as MeshInstance3D
		assert_eq(pieza.layers, 1, "Armadura %s debe estar en Capa 1" % nombre_pieza)
		var pose_ens: Dictionary = boss._armadura_poses_ensambladas[nombre_pieza]
		assert_true(pieza.position.distance_to(pose_ens["pos"]) < 0.01, "Armadura %s debe estar ensamblada" % nombre_pieza)

	# 2. Cuerpo espectral completo: Capa 3 (visible para Fantasma, oculto para Vivo)
	var cuerpo := boss.get_node("Visual/ModeloEspectral/Boss_Cuerpo") as MeshInstance3D
	assert_true(boss.modelo_espectral.visible, "El modelo espectral completo debe ser visible para el Fantasma")
	assert_eq(cuerpo.layers, 4, "Cuerpo espectral completo debe estar en Capa 3 mientras es intangible")

	# 3. Silueta semitransparente: Capa 2 (visible SOLO para Vivo, oculto para Fantasma)
	assert_true(boss._silueta_aviso.visible, "La silueta semitransparente debe mostrarse al Vivo mientras es intangible")
	var sil_cuerpo := boss._silueta_aviso.get_node("Boss_Cuerpo") as MeshInstance3D
	assert_eq(sil_cuerpo.layers, 2, "La silueta semitransparente debe habitar Capa 2 (exclusivo Vivo)")
	var mask_vivo: int = 1048575 & ~(1 << 2)
	var mask_fantasma: int = 1048575 & ~(1 << 1)
	assert_true((mask_vivo & 2) != 0 and (mask_vivo & 4) == 0, "Vivo ve silueta (Capa 2) y NO el cuerpo completo (Capa 3)")
	assert_true((mask_fantasma & 4) != 0 and (mask_fantasma & 2) == 0, "Fantasma ve cuerpo completo (Capa 3) y NO silueta (Capa 2)")
	assert_true((mask_vivo & 1) != 0 and (mask_fantasma & 1) != 0, "Ambos ven la armadura sólida en Capa 1")

func test_boss_aura_fantasma_hace_tangible_y_revierte() -> void:
	var boss := _crear_boss()
	boss.position = Vector3(0.0, 3.5, -75.5)
	boss._ready()
	boss.iniciar_despertar()

	var mock_f := _crear_mock_fantasma(Vector3(3.0, 3.5, -75.5)) # Fantasma en el suelo cerca del jefe
	var fantasma: Node3D = mock_f["fantasma"]
	var aura: HabilidadAura = mock_f["aura"]
	boss._fantasma_ref = fantasma

	# Aura apagada -> intangible
	boss._verificar_tangibilidad_con_aura(0.016)
	assert_false(boss._esta_tangible, "Con aura apagada el jefe debe seguir intangible")
	assert_eq(boss.estado_actual, BossEspectral.Estado.COMBATE_INTANGIBLE)

	# Activar aura del Fantasma cerca del jefe -> tangible y vulnerable
	aura.activa = true
	aura.radio_actual = 6.0
	boss._verificar_tangibilidad_con_aura(0.016)
	assert_true(boss._esta_tangible, "El aura del Fantasma cerca del jefe debe volverlo tangible")
	assert_eq(boss.estado_actual, BossEspectral.Estado.TANGIBLE_VULNERABLE)
	assert_true((boss.collision_layer & 2) != 0, "Tangible debe habilitar colisión física en Capa 2")

	var cuerpo := boss.get_node("Visual/ModeloEspectral/Boss_Cuerpo") as MeshInstance3D
	assert_true((cuerpo.layers & 1) != 0, "Tangible debe mostrar el cuerpo completo en Capa 1 para el Vivo")
	assert_false(boss._silueta_aviso.visible, "Al volverse tangible la silueta semitransparente debe ocultarse")
	assert_true(boss.halo_objetivo.visible, "El halo objetivo sobre la cabeza debe mostrarse al ser tangible")

	# Apagar aura -> permanece durante tiempo_gracia_tangible y luego vuelve a intangible
	aura.activa = false
	aura.radio_actual = 0.0
	boss._verificar_tangibilidad_con_aura(boss.tiempo_gracia_tangible * 0.5)
	assert_true(boss._esta_tangible, "Debe mantenerse tangible durante el tiempo de gracia")

	boss._verificar_tangibilidad_con_aura(boss.tiempo_gracia_tangible + 0.1)
	assert_false(boss._esta_tangible, "Tras expirar el tiempo de gracia debe volver a ser intangible")
	assert_eq(boss.estado_actual, BossEspectral.Estado.COMBATE_INTANGIBLE)
	assert_eq(cuerpo.layers, 4, "Cuerpo completo debe regresar a Capa 3")
	assert_true(boss._silueta_aviso.visible, "Silueta semitransparente debe reaparecer para el Vivo")

func test_boss_inmune_intangible_y_embate_terrestre() -> void:
	var boss := _crear_boss()
	boss._ready()
	boss.iniciar_despertar()

	var vivo := track(CharacterBody3D.new())
	# Intento de pisotón mientras es intangible -> NO daña
	boss.recibir_impacto_pisoton(vivo)
	assert_eq(boss.vida_actual, 3, "No debe recibir daño por pisotón mientras es intangible")

	# Hacerlo tangible pero intentar Embate desde el suelo -> armadura bloquea daño
	boss._establecer_tangibilidad(true)
	boss.recibir_impacto(vivo)
	assert_eq(boss.vida_actual, 3, "El Embate terrestre no debe dañar al jefe; requiere escalar y pisarlo arriba")

func test_boss_tres_pisotones_derrota_y_caida_armadura() -> void:
	var boss := _crear_boss()
	boss.position = Vector3(0.0, 3.5, -75.5)
	boss.tiempo_invulnerabilidad_golpe = 1.0
	var plat := _crear_plataforma(3.0, Vector3(-6.8, 0.06, -2.9))
	boss.plataformas_combate = [plat]
	boss._ready()
	boss.iniciar_despertar()
	assert_true(plat.esta_elevada)

	var vivo := track(CharacterBody3D.new())
	boss._jugador_vivo_ref = vivo

	var eventos := {"danos": [], "derrotado": false, "puerta_activada": false}
	boss.boss_danado.connect(func(rest: int, _max: int): eventos["danos"].append(rest))
	boss.boss_derrotado.connect(func(): eventos["derrotado"] = true)
	boss.signal_activado.connect(func(): eventos["puerta_activada"] = true)

	# --- GOLPE 1 (3 -> 2) via detección real de pisotón desde arriba ---
	boss._establecer_tangibilidad(true)
	var alt_cabeza := boss.obtener_altura_cabeza_global()
	vivo.position = Vector3(0.4, alt_cabeza + BossEspectral.ALTURA_PIES_VIVO_LOCAL + 0.15, -75.5)
	vivo.velocity = Vector3(0.0, -4.5, 0.0)
	var golpeo_1 := boss._verificar_pisoton_vivo(vivo)
	assert_true(golpeo_1, "Pisotón sobre la coronilla siendo tangible debe conectar")
	assert_eq(boss.vida_actual, 2, "Debe bajar a 2 puntos de vida tras el 1er pisotón")
	assert_eq(boss.estado_actual, BossEspectral.Estado.ATURDIDO_GOLPE)
	assert_gt(vivo.velocity.y, 2.0, "El Vivo debe rebotar hacia arriba tras pisar al jefe")

	# Golpe repetido durante invulnerabilidad -> ignorado
	boss.recibir_impacto_pisoton(vivo)
	assert_eq(boss.vida_actual, 2, "No debe recibir doble daño durante la invulnerabilidad")

	# Recuperación tras golpe 1
	boss.procesar_ciclo_boss(1.2)
	assert_eq(boss.estado_actual, BossEspectral.Estado.COMBATE_INTANGIBLE, "Debe volver a COMBATE_INTANGIBLE tras recuperarse")

	# --- GOLPE 2 (2 -> 1) ---
	boss._establecer_tangibilidad(true)
	vivo.velocity = Vector3(0.0, -4.0, 0.0)
	boss._verificar_pisoton_vivo(vivo)
	assert_eq(boss.vida_actual, 1, "Debe bajar a 1 punto de vida tras el 2do pisotón")
	assert_false(eventos["derrotado"], "No debe morir todavía con 1 punto de vida")
	boss.procesar_ciclo_boss(1.2)
	assert_eq(boss.estado_actual, BossEspectral.Estado.COMBATE_INTANGIBLE)

	# --- GOLPE 3 (1 -> 0: DERROTA FINAL) ---
	boss._establecer_tangibilidad(true)
	vivo.velocity = Vector3(0.0, -5.0, 0.0)
	boss._verificar_pisoton_vivo(vivo)
	assert_eq(boss.vida_actual, 0, "Al 3er pisotón la vida debe llegar a 0")
	assert_eq(boss.estado_actual, BossEspectral.Estado.DERROTADO, "Debe pasar a estado DERROTADO")
	assert_true(eventos["derrotado"], "Debe emitir boss_derrotado")
	assert_true(eventos["puerta_activada"], "Debe emitir signal_activado para abrir la salida del coliseo")
	assert_eq(eventos["danos"].size(), 3, "Debe haber emitido 3 eventos de daño (2, 1, 0)")

	# Espectro desaparece por completo
	assert_false(boss.modelo_espectral.visible, "El espectro debe desaparecer al ser derrotado")
	assert_false(boss._silueta_aviso.visible, "La silueta debe desaparecer al ser derrotado")
	assert_eq(boss.collision_layer, 0, "Colisión física debe desactivarse al morir")

	# La armadura cae al suelo del coliseo y permanece visible
	assert_true(boss.modelo_armadura.visible, "La armadura caída debe permanecer visible en el suelo")
	var casco := boss.modelo_armadura.get_node("Boss_Armadura_Casco") as Node3D
	var pose_ens: Dictionary = boss._armadura_poses_ensambladas["Boss_Armadura_Casco"]
	assert_true(casco.position.y < (pose_ens["pos"] as Vector3).y - 0.8, "Al morir el jefe, la armadura debe haber caído al suelo")
	assert_false(plat.esta_elevada, "Las plataformas del coliseo deben descender tras derrotar al jefe")

func test_nivel_2_integracion_coliseo_boss() -> void:
	var escena_n2 := ResourceLoader.load("res://scenes/levels/nivel 2.tscn", "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
	assert_ne(escena_n2, null, "nivel 2.tscn debe cargarse correctamente")
	var nivel := track(escena_n2.instantiate()) as Node3D
	assert_ne(nivel, null, "nivel 2.tscn debe instanciarse")

	var isla_coliseo := nivel.get_node_or_null("Islas/Isla9_ColiseoBoss")
	assert_ne(isla_coliseo, null, "Debe existir Isla9_ColiseoBoss al final del nivel 2")

	var coliseo := nivel.get_node_or_null("ColiseoBoss") as Node3D
	assert_ne(coliseo, null, "Debe existir el contenedor ColiseoBoss")

	var boss := coliseo.get_node_or_null("BossEspectral") as BossEspectral
	assert_ne(boss, null, "Debe existir BossEspectral dentro de ColiseoBoss")
	assert_eq(boss.vida_maxima, 3, "BossEspectral en Nivel 2 debe tener 3 puntos de vida")
	assert_eq(boss.plataformas_combate.size(), 5, "BossEspectral debe tener 5 plataformas elevables vinculadas")

	var altura_previa: float = 0.0
	var plataformas_n2: Array[PlataformaColiseo] = []
	for i in range(1, 6):
		var p := coliseo.get_node_or_null("PlataformasCombate/PlataformaColiseo_%d" % i) as PlataformaColiseo
		assert_ne(p, null, "Debe existir PlataformaColiseo_%d" % i)
		assert_true(absf(p.position.y - 0.06) < 0.05, "Plataforma %d debe reposar en base y=0.06" % i)
		assert_true(p.radio_plataforma <= 1.35, "Las islas del coliseo deben ser pequeñas (radio <= 1.35)")
		assert_true(p.obtener_profundidad_roca() < p.altura_elevada - 0.25, "La roca de la isla %d no debe atravesar el suelo" % i)
		assert_gt(p.altura_elevada, altura_previa, "Las plataformas deben formar un ascenso progresivo")
		assert_gt(Vector2(p.position.x, p.position.z).length(), 5.0, "Cada plataforma debe rodear al jefe a distancia segura")
		if not plataformas_n2.is_empty():
			var prev_p := plataformas_n2[plataformas_n2.size() - 1]
			var dist_xz := Vector2(p.position.x - prev_p.position.x, p.position.z - prev_p.position.z).length()
			var delta_y := p.altura_elevada - prev_p.altura_elevada
			assert_true(delta_y <= 1.75, "El salto vertical entre islas %d y %d debe ser alcanzable" % [i - 1, i])
			assert_true(dist_xz <= 5.6, "La distancia horizontal entre islas %d y %d debe ser saltable" % [i - 1, i])
		plataformas_n2.append(p)
		altura_previa = p.altura_elevada

	var alt_cabeza := boss.obtener_altura_cabeza_global()
	assert_true(absf(plataformas_n2[2].altura_elevada - alt_cabeza) <= 0.65, "Alrededor de 3 plataformas arriba debe quedar a altura de salto sobre el copete del jefe")
	assert_true(altura_previa > alt_cabeza, "La plataforma más alta debe superar la coronilla del jefe")

	var puerta := nivel.get_node_or_null("Mecanismos/PuertaSalidaColiseo") as PuertaInteractiva
	assert_ne(puerta, null, "Debe existir PuertaSalidaColiseo a la salida del coliseo")
	assert_eq(puerta.disparador_objetivo, boss, "PuertaSalidaColiseo debe abrirse al derrotar a BossEspectral")

	var goal := nivel.get_node_or_null("ZonaReunionFinal/Goal") as Node3D
	assert_ne(goal, null, "Goal debe existir después del coliseo")
	assert_true(goal.position.z < coliseo.position.z - 15.0, "Goal debe ubicarse en la isla posterior al coliseo")

func test_boss_calibracion_bordes_pisoton() -> void:
	var boss := _crear_boss()
	boss.position = Vector3(0.0, 3.5, -75.5)
	boss._ready()
	boss.iniciar_despertar()
	boss._establecer_tangibilidad(true)

	var vivo := track(CharacterBody3D.new())
	var alt_cabeza := boss.obtener_altura_cabeza_global()

	# 1. Demasiado lejos horizontalmente -> NO conecta
	vivo.position = Vector3(boss.radio_pisoton_cabeza + 1.5, alt_cabeza + BossEspectral.ALTURA_PIES_VIVO_LOCAL, -75.5)
	vivo.velocity = Vector3(0.0, -4.0, 0.0)
	assert_false(boss._verificar_pisoton_vivo(vivo), "No debe conectar pisotón fuera del radio horizontal de la cabeza")
	assert_eq(boss.vida_actual, 3)

	# 2. Subiendo (vel_y > 1.5) -> NO conecta
	vivo.position = Vector3(0.0, alt_cabeza + BossEspectral.ALTURA_PIES_VIVO_LOCAL, -75.5)
	vivo.velocity = Vector3(0.0, 5.0, 0.0)
	assert_false(boss._verificar_pisoton_vivo(vivo), "No debe conectar pisotón mientras el Vivo está ascendiendo")
	assert_eq(boss.vida_actual, 3)

	# 3. Demasiado alto en el aire -> NO conecta
	vivo.position = Vector3(0.0, alt_cabeza + BossEspectral.ALTURA_PIES_VIVO_LOCAL + 2.5, -75.5)
	vivo.velocity = Vector3(0.0, -3.0, 0.0)
	assert_false(boss._verificar_pisoton_vivo(vivo), "No debe conectar pisotón estando demasiado alto en el aire")
	assert_eq(boss.vida_actual, 3)

	# 4. A nivel del suelo (debajo de la armadura) -> NO conecta
	vivo.position = Vector3(0.5, 4.0, -75.5)
	vivo.velocity = Vector3(0.0, -2.0, 0.0)
	assert_false(boss._verificar_pisoton_vivo(vivo), "No debe conectar pisotón a nivel del suelo sin escalar plataformas")
	assert_eq(boss.vida_actual, 3)

	# 5. Al caer con precisión sobre el copete superior -> SÍ conecta
	vivo.position = Vector3(0.3, alt_cabeza + BossEspectral.ALTURA_PIES_VIVO_LOCAL + 0.2, -75.5)
	vivo.velocity = Vector3(0.0, -6.0, 0.0)
	assert_true(boss._verificar_pisoton_vivo(vivo), "Debe conectar pisotón preciso sobre la coronilla del jefe")
	assert_eq(boss.vida_actual, 2)

func test_boss_un_pisoton_con_aura_activa_en_arbol_solo_quita_una_vida() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	assert_ne(tree, null, "Debe existir SceneTree activo para probar la rama in-tree")

	var boss := _crear_boss()
	boss.position = Vector3(0.0, 3.5, -75.5)
	boss.tiempo_invulnerabilidad_golpe = 1.6
	boss.duracion_hit_stop = 0.0
	tree.root.add_child(boss)
	boss.set_physics_process(false)
	boss._aplicar_estado_dormido_inmediato()
	assert_true(boss.is_inside_tree(), "El boss debe estar dentro del SceneTree para probar el tween de compresión")

	# Finalizar despertar para entrar en combate activo dentro del árbol
	boss.iniciar_despertar()
	if boss._tween_principal != null and boss._tween_principal.is_valid():
		boss._tween_principal.kill()
	boss._limpiar_tweens_armadura()
	boss._finalizar_despertar()

	var mock_f := _crear_mock_fantasma(Vector3(2.0, 3.5, -75.5))
	var fantasma: Node3D = mock_f["fantasma"]
	var aura: HabilidadAura = mock_f["aura"]
	aura.activa = true
	aura.radio_actual = 6.0
	boss._fantasma_ref = fantasma

	var vivo := track(CharacterBody3D.new())
	boss._jugador_vivo_ref = vivo

	var estado_ev := {"danos": [], "derrotado": false}
	boss.boss_danado.connect(func(rest: int, _max: int): estado_ev["danos"].append(rest))
	boss.boss_derrotado.connect(func(): estado_ev["derrotado"] = true)

	# Frame inicial: el Aura del Fantasma vuelve tangible al jefe (vivo lejos aún)
	vivo.position = Vector3(10.0, 3.5, -75.5)
	boss.procesar_ciclo_boss(0.016)
	assert_eq(boss.estado_actual, BossEspectral.Estado.TANGIBLE_VULNERABLE)

	# --- GOLPE 1: Vivo cae sobre la coronilla y permanece encima 10 frames con Aura activa ---
	var alt_cabeza := boss.obtener_altura_cabeza_global()
	vivo.position = Vector3(0.2, alt_cabeza + BossEspectral.ALTURA_PIES_VIVO_LOCAL + 0.1, -75.5)
	vivo.velocity = Vector3(0.0, -4.5, 0.0)
	for _i in range(10):
		boss.procesar_ciclo_boss(0.016)
		vivo.velocity = Vector3.ZERO
	assert_eq(boss.vida_actual, 2, "Un solo pisotón con Aura activa debe quitar solo 1 vida (3 -> 2)")
	assert_eq(boss.estado_actual, BossEspectral.Estado.ATURDIDO_GOLPE, "Debe entrar inmediatamente en ATURDIDO_GOLPE")
	assert_false(estado_ev["derrotado"], "No debe morir tras el 1er golpe")
	assert_eq(estado_ev["danos"].size(), 1, "Debe emitir exactamente 1 evento de daño por el 1er pisotón")

	# Simular fin de compresión e invulnerabilidad del 1er golpe
	if boss._tween_principal != null and boss._tween_principal.is_valid():
		boss._tween_principal.kill()
	boss._en_compresion_pisoton = false
	boss._iniciar_recuperacion_golpe()
	boss.procesar_ciclo_boss(1.8)
	assert_eq(boss.estado_actual, BossEspectral.Estado.COMBATE_INTANGIBLE)

	# --- GOLPE 2: Re-activar tangibilidad con Aura y pisar nuevamente (10 frames seguidos) ---
	vivo.position = Vector3(10.0, 3.5, -75.5)
	boss.procesar_ciclo_boss(0.016)
	assert_eq(boss.estado_actual, BossEspectral.Estado.TANGIBLE_VULNERABLE)

	alt_cabeza = boss.obtener_altura_cabeza_global()
	vivo.position = Vector3(0.2, alt_cabeza + BossEspectral.ALTURA_PIES_VIVO_LOCAL + 0.1, -75.5)
	vivo.velocity = Vector3(0.0, -4.5, 0.0)
	for _i in range(10):
		boss.procesar_ciclo_boss(0.016)
		vivo.velocity = Vector3.ZERO
	assert_eq(boss.vida_actual, 1, "El 2do pisotón con Aura activa debe dejar exactamente 1 vida (2 -> 1)")
	assert_eq(boss.estado_actual, BossEspectral.Estado.ATURDIDO_GOLPE)
	assert_false(estado_ev["derrotado"], "No debe morir tras el 2do golpe")
	assert_eq(estado_ev["danos"].size(), 2, "Debe llevar exactamente 2 eventos de daño")

	# Simular fin de compresión e invulnerabilidad del 2do golpe
	if boss._tween_principal != null and boss._tween_principal.is_valid():
		boss._tween_principal.kill()
	boss._en_compresion_pisoton = false
	boss._iniciar_recuperacion_golpe()
	boss.procesar_ciclo_boss(1.8)
	assert_eq(boss.estado_actual, BossEspectral.Estado.COMBATE_INTANGIBLE)

	# --- GOLPE 3: Tercer y último pisotón ---
	vivo.position = Vector3(10.0, 3.5, -75.5)
	boss.procesar_ciclo_boss(0.016)
	assert_eq(boss.estado_actual, BossEspectral.Estado.TANGIBLE_VULNERABLE)

	alt_cabeza = boss.obtener_altura_cabeza_global()
	vivo.position = Vector3(0.2, alt_cabeza + BossEspectral.ALTURA_PIES_VIVO_LOCAL + 0.1, -75.5)
	vivo.velocity = Vector3(0.0, -4.5, 0.0)
	for _i in range(5):
		boss.procesar_ciclo_boss(0.016)
		vivo.velocity = Vector3.ZERO
	assert_eq(boss.vida_actual, 0, "Al 3er pisotón debe bajar a 0 de vida")
	assert_eq(boss.estado_actual, BossEspectral.Estado.DERROTADO, "Debe quedar inmediatamente en estado DERROTADO")
	assert_eq(estado_ev["danos"].size(), 3, "Debe haber emitido exactamente 3 eventos de daño (2, 1, 0)")

	if boss._tween_principal != null and boss._tween_principal.is_valid():
		boss._tween_principal.kill()
	boss._en_compresion_pisoton = false
	boss._iniciar_secuencia_derrota()
	assert_true(estado_ev["derrotado"], "Al 3er pisotón debe emitir boss_derrotado")

	if boss._tween_principal != null and boss._tween_principal.is_valid():
		boss._tween_principal.kill()
	boss._limpiar_tweens_armadura()
	if boss.get_parent() != null:
		boss.get_parent().remove_child(boss)

func test_boss_gira_hacia_fantasma_y_lanza_tornado_que_empuja() -> void:
	var boss := _crear_boss()
	boss.position = Vector3.ZERO
	boss._ready()
	boss.iniciar_despertar()

	var vivo := track(CharacterBody3D.new())
	vivo.position = Vector3(-8.5, 0.0, 4.0)
	boss._jugador_vivo_ref = vivo

	var fantasma := track(CharacterBody3D.new())
	fantasma.name = "Fantasma"
	fantasma.add_to_group("fantasmas")
	fantasma.position = Vector3(5.5, 0.2, 2.5)
	var aura := track(HabilidadAura.new())
	aura.name = "HabilidadAura"
	fantasma.add_child(aura)
	boss._fantasma_ref = fantasma

	# Forzar evaluación inmediata sin esperar cooldowns iniciales
	boss._temporizador_decision = 0.0
	boss._cooldown_tornado = 0.0
	boss.procesar_ciclo_boss(0.016)
	assert_eq(boss.estado_actual, BossEspectral.Estado.PREPARANDO_TORNADO, "Debe iniciar PREPARANDO_TORNADO hacia el Fantasma")

	# Avanzar varios pasos para que el jefe rote hacia la posición del Fantasma
	for _i in range(18):
		boss.procesar_ciclo_boss(0.03)
		if boss.estado_actual != BossEspectral.Estado.PREPARANDO_TORNADO:
			break

	var dir_a_fantasma := Vector3(fantasma.position.x - boss.position.x, 0.0, fantasma.position.z - boss.position.z).normalized()
	var frente_boss := Vector3(sin(boss.rotation.y), 0.0, cos(boss.rotation.y)).normalized()
	assert_gt(frente_boss.dot(dir_a_fantasma), 0.85, "El jefe debe girar para encarar al Fantasma al preparar el tornado")

	# Terminar preparación y lanzar tornado
	var seguridad := 0
	while boss.estado_actual == BossEspectral.Estado.PREPARANDO_TORNADO and seguridad < 40:
		boss.procesar_ciclo_boss(0.05)
		seguridad += 1

	assert_eq(boss.estado_actual, BossEspectral.Estado.LANZANDO_TORNADO, "Debe pasar a LANZANDO_TORNADO tras cargar")
	assert_eq(boss._tornados_activos.size(), 1, "En Fase 1 debe lanzar 1 proyectil tornado")

	var tornado: ProyectilTornadoBoss = boss._tornados_activos[0]
	assert_ne(tornado, null, "El proyectil tornado debe ser válido")

	# Colocar tornado alcanzando al Fantasma y comprobar empuje hacia afuera
	tornado.position = fantasma.position - Vector3(0.4, 0.2, 0.2)
	fantasma.velocity = Vector3.ZERO
	tornado.procesar_tornado(0.016)
	assert_gt(Vector2(fantasma.velocity.x, fantasma.velocity.z).length(), 2.0, "El tornado debe empujar horizontalmente al Fantasma")
	var dir_empuje := Vector3(fantasma.velocity.x, 0.0, fantasma.velocity.z).normalized()
	assert_gt(dir_empuje.dot(dir_a_fantasma), 0.2, "El empuje debe alejar al Fantasma del jefe/centro")

	boss._limpiar_entidades_combate(true)

func test_boss_gira_hacia_vivo_rompe_isla_y_regenera_en_nueva_posicion() -> void:
	var boss := _crear_boss()
	boss.position = Vector3.ZERO
	var plat1 := _crear_plataforma(1.5, Vector3(-6.5, 0.06, 3.6))
	var plat2 := _crear_plataforma(3.0, Vector3(-6.8, 0.06, -2.9))
	var plat3 := _crear_plataforma(4.45, Vector3(-1.0, 0.06, -7.3))
	boss.plataformas_combate = [plat1, plat2, plat3]
	boss._ready()
	boss.iniciar_despertar()

	assert_eq(plat2.estado_isla, PlataformaColiseo.EstadoIsla.ACTIVA, "La isla debe comenzar ACTIVA tras despertar")
	var pos_inicial_plat2 := plat2.obtener_posicion_base()

	var vivo := track(CharacterBody3D.new())
	vivo.position = plat2.position + Vector3(0.0, 0.6, 0.0)
	boss._jugador_vivo_ref = vivo

	var mock_f := _crear_mock_fantasma(Vector3(9.5, 0.2, 0.0))
	boss._fantasma_ref = mock_f["fantasma"]

	boss._temporizador_decision = 0.0
	boss._cooldown_romper_plataforma = 0.0
	boss.procesar_ciclo_boss(0.016)
	assert_eq(boss.estado_actual, BossEspectral.Estado.APUNTANDO_PLATAFORMA, "Debe apuntar a la isla donde subió el Vivo")
	assert_eq(boss._plataforma_objetivo, plat2, "La isla objetivo debe ser la que ocupa el Vivo")

	# Avanzar hasta completar puntería y entrar en ruptura
	for _i in range(30):
		boss.procesar_ciclo_boss(0.03)
		if boss.estado_actual != BossEspectral.Estado.APUNTANDO_PLATAFORMA:
			break

	var dir_a_vivo := Vector3(vivo.position.x - boss.position.x, 0.0, vivo.position.z - boss.position.z).normalized()
	var frente_boss := Vector3(sin(boss.rotation.y), 0.0, cos(boss.rotation.y)).normalized()
	assert_gt(frente_boss.dot(dir_a_vivo), 0.85, "El jefe debe haber girado hacia la isla del Vivo")
	assert_eq(boss.estado_actual, BossEspectral.Estado.ROMPIENDO_PLATAFORMA, "Debe pasar a ROMPIENDO_PLATAFORMA")

	# Esperar el barrido lateral del puño hasta el impacto (t >= 0.24s) -> desintegración instantánea
	for _i in range(12):
		boss.procesar_ciclo_boss(0.03)
		if plat2.esta_destruida():
			break

	assert_true(plat2.esta_destruida(), "La isla debe desintegrarse instantáneamente al recibir el golpe lateral del puño")
	assert_eq(plat2.collision_layer, 0, "Una isla destruida debe deshabilitar su colisión")

	# Avanzar ciclo del jefe hasta que la isla se regenere en una nueva posición
	for _i in range(15):
		boss.procesar_ciclo_boss(0.25)
		if plat2.esta_disponible():
			break

	assert_true(plat2.esta_disponible(), "La isla destruida debe regenerarse y volver a estar ACTIVA")
	assert_eq(plat2.collision_layer, 1, "La isla regenerada debe reactivar su colisión en Capa 1")
	var pos_nueva := plat2.obtener_posicion_base()
	var dist_cambio := Vector2(pos_nueva.x - pos_inicial_plat2.x, pos_nueva.z - pos_inicial_plat2.z).length()
	assert_gt(dist_cambio, 1.5, "La isla regenerada debe aparecer en una nueva posición distinta")
	var radio_nuevo := Vector2(pos_nueva.x, pos_nueva.z).length()
	assert_true(radio_nuevo >= boss.radio_min_islas - 0.1 and radio_nuevo <= boss.radio_max_islas + 0.1, "La nueva posición debe permanecer dentro del anillo válido del coliseo")

func test_aura_congela_boss_en_pleno_ataque_y_cancela_ruptura_isla() -> void:
	var boss := _crear_boss()
	boss.position = Vector3.ZERO
	var plat := _crear_plataforma(3.0, Vector3(6.5, 0.06, 0.0))
	boss.plataformas_combate = [plat]
	boss._ready()
	boss.iniciar_despertar()

	var vivo := track(CharacterBody3D.new())
	vivo.position = plat.position + Vector3(0.0, 0.5, 0.0)
	boss._jugador_vivo_ref = vivo

	var mock_f := _crear_mock_fantasma(Vector3(2.2, 1.5, 0.0))
	var aura: HabilidadAura = mock_f["aura"]
	boss._fantasma_ref = mock_f["fantasma"]

	# Iniciar ataque de puntería sobre la isla del Vivo
	boss._temporizador_decision = 0.0
	boss._cooldown_romper_plataforma = 0.0
	boss.procesar_ciclo_boss(0.016)
	assert_eq(boss.estado_actual, BossEspectral.Estado.APUNTANDO_PLATAFORMA)

	# Activar el Aura del Fantasma cerca mientras el Boss apunta -> congela e interrumpe ataque
	aura.activa = true
	aura.radio_actual = 6.0
	boss.procesar_ciclo_boss(0.016)
	assert_eq(boss.estado_actual, BossEspectral.Estado.TANGIBLE_VULNERABLE, "El Aura debe congelar al jefe incluso en mitad de un ataque")
	assert_eq(boss._plataforma_objetivo, null, "Debe limpiar la plataforma objetivo al interrumpir el ataque")
	assert_eq(plat.estado_isla, PlataformaColiseo.EstadoIsla.ACTIVA, "La isla apuntada debe mantenerse ACTIVA")

	# Verificar también que si la isla ya estaba agrietándose, congelar al jefe salva la isla
	aura.activa = false
	boss._establecer_tangibilidad(false)
	plat.iniciar_ruptura(1.2)
	assert_true(plat.esta_agrietandose())
	aura.activa = true
	aura.radio_actual = 6.0
	boss.procesar_ciclo_boss(0.016)
	assert_eq(boss.estado_actual, BossEspectral.Estado.TANGIBLE_VULNERABLE)
	assert_eq(plat.estado_isla, PlataformaColiseo.EstadoIsla.ACTIVA, "Congelar al jefe mientras una isla se agrieta debe cancelar la ruptura")

func test_escalado_dificultad_tres_fases_oscilacion_y_mini_espectros() -> void:
	var boss := _crear_boss()
	boss.position = Vector3.ZERO
	boss.tiempo_invulnerabilidad_golpe = 0.8
	var p1 := _crear_plataforma(1.5, Vector3(-6.5, 0.06, 3.6))
	var p2 := _crear_plataforma(3.0, Vector3(-6.8, 0.06, -2.9))
	var p3 := _crear_plataforma(4.45, Vector3(-1.0, 0.06, -7.3))
	var p4 := _crear_plataforma(5.85, Vector3(5.8, 0.06, -4.6))
	var p5 := _crear_plataforma(6.55, Vector3(6.3, 0.06, 1.8))
	boss.plataformas_combate = [p1, p2, p3, p4, p5]
	boss._ready()
	boss.iniciar_despertar()

	var fantasma := track(CharacterBody3D.new())
	fantasma.position = Vector3(8.5, 0.2, 0.0)
	boss._fantasma_ref = fantasma

	var vivo := track(CharacterBody3D.new())
	boss._jugador_vivo_ref = vivo

	# FASE 1: 3 HP, sin oscilación, 1 tornado
	assert_eq(boss.obtener_fase_actual(), 1)
	assert_false(p1.oscilacion_vertical_activa, "Fase 1 no debe tener oscilación vertical aún")
	var pos_p1_f1 := p1.obtener_posicion_base()
	boss._lanzar_rafaga_tornados(fantasma)
	assert_eq(boss._tornados_activos.size(), 1, "Fase 1 lanza 1 tornado")
	boss._limpiar_entidades_combate(true)

	# PISOTÓN 1 -> FASE 2: 2 HP, islas se reubican + oscilan arriba/abajo + 2 tornados
	boss._establecer_tangibilidad(true)
	vivo.position = Vector3(0.2, boss.obtener_altura_cabeza_global() + BossEspectral.ALTURA_PIES_VIVO_LOCAL + 0.1, 0.0)
	vivo.velocity = Vector3(0.0, -5.0, 0.0)
	assert_true(boss._verificar_pisoton_vivo(vivo))
	vivo.position = Vector3(11.0, 0.0, 0.0)
	boss.procesar_ciclo_boss(1.0)
	assert_eq(boss.obtener_fase_actual(), 2, "Tras el 1er pisotón debe entrar en Fase 2")
	assert_true(p1.oscilacion_vertical_activa, "Fase 2 debe activar oscilación vertical en las islas")
	assert_gt(p1.amplitud_oscilacion, 0.4)
	assert_gt(Vector2(p1.obtener_posicion_base().x - pos_p1_f1.x, p1.obtener_posicion_base().z - pos_p1_f1.z).length(), 0.2, "Las islas deben cambiar de posición al subir de fase")

	var y_base_p1 := p1.obtener_posicion_base().y + p1.altura_elevada
	p1.procesar_isla(0.35)
	assert_true(absf(p1.position.y - y_base_p1) > 0.02, "La isla debe subir y bajar con su oscilación en Fase 2")

	boss._lanzar_rafaga_tornados(fantasma)
	assert_eq(boss._tornados_activos.size(), 2, "Fase 2 debe lanzar ráfaga de 2 tornados")
	boss._limpiar_entidades_combate(true)

	# PISOTÓN 2 -> FASE 3: 1 HP, oscilación intensa + 3 tornados + invocación de mini espectros
	boss._establecer_tangibilidad(true)
	vivo.position = Vector3(0.2, boss.obtener_altura_cabeza_global() + BossEspectral.ALTURA_PIES_VIVO_LOCAL + 0.1, 0.0)
	vivo.velocity = Vector3(0.0, -5.0, 0.0)
	assert_true(boss._verificar_pisoton_vivo(vivo))
	vivo.position = Vector3(11.0, 0.0, 0.0)
	boss.procesar_ciclo_boss(1.0)
	assert_eq(boss.obtener_fase_actual(), 3, "Tras el 2do pisotón debe entrar en Fase 3")
	assert_gt(p1.amplitud_oscilacion, 0.7, "Fase 3 debe aumentar amplitud de oscilación")

	boss._lanzar_rafaga_tornados(fantasma)
	assert_eq(boss._tornados_activos.size(), 3, "Fase 3 debe lanzar ráfaga de 3 tornados")

	# Permitir que el jefe inicie y complete INVOCANDO_ESPECTROS
	boss.estado_actual = BossEspectral.Estado.COMBATE_INTANGIBLE
	boss._temporizador_decision = 0.0
	boss._cooldown_invocacion = 0.0
	boss.procesar_ciclo_boss(0.016)
	assert_eq(boss.estado_actual, BossEspectral.Estado.INVOCANDO_ESPECTROS, "Fase 3 debe invocar mini espectros")

	for _i in range(25):
		boss.procesar_ciclo_boss(0.08)
	assert_gt(boss._mini_espectros_activos.size(), 0, "Debe haber invocado mini espectros en Fase 3")
	var minion := boss._mini_espectros_activos[0]
	assert_true(minion is EnemigoEspectral and bool(minion.get("es_clon")), "Los esbirros invocados deben ser mini EnemigoEspectral")

	# PISOTÓN 3 -> DERROTADO: limpieza completa de tornados, mini espectros y bajada de islas
	boss._establecer_tangibilidad(true)
	vivo.position = Vector3(0.2, boss.obtener_altura_cabeza_global() + BossEspectral.ALTURA_PIES_VIVO_LOCAL + 0.1, 0.0)
	vivo.velocity = Vector3(0.0, -5.0, 0.0)
	assert_true(boss._verificar_pisoton_vivo(vivo))
	assert_eq(boss.estado_actual, BossEspectral.Estado.DERROTADO)
	assert_eq(boss._tornados_activos.size(), 0, "Al morir el jefe debe limpiar todos los tornados")
	assert_eq(boss._mini_espectros_activos.size(), 0, "Al morir el jefe debe limpiar todos los mini espectros")
	assert_false(p1.oscilacion_vertical_activa, "Las islas deben dejar de oscilar tras derrotar al jefe")
	assert_false(p1.esta_elevada, "Las islas deben descender tras derrotar al jefe")

func test_plataforma_coliseo_usa_isla_flotante_y_sin_colision_duplicada() -> void:
	var plat := _crear_plataforma(3.0, Vector3(0.0, 0.06, 0.0))
	var isla_vis := plat.get_node_or_null("Visual/IslaVisual") as IslaFlotante
	assert_ne(isla_vis, null, "PlataformaColiseo debe usar una instancia real de IslaFlotante en Visual/IslaVisual")
	assert_false(isla_vis.generar_pasto, "Las plataformas rocosas del coliseo deben desactivar generar_pasto")
	assert_false(isla_vis.pasto_distancia, "Las plataformas rocosas del coliseo deben desactivar pasto_distancia")
	assert_eq(isla_vis.collision_layer, 0, "La isla visual interna no debe tener colisión física duplicada")
	var col_interna := isla_vis.get_node_or_null("CollisionShape3D") as CollisionShape3D
	assert_ne(col_interna, null)
	assert_true(col_interna.disabled, "El CollisionShape3D interno de IslaVisual debe permanecer deshabilitado")
	assert_false(plat.mesh_capitel.visible, "Capitel heredado debe estar oculto")
	assert_false(plat.mesh_fuste.visible, "Fuste heredado debe estar oculto")
	assert_false(plat.mesh_aro.visible, "AroRunico heredado debe estar oculto")

func test_boss_lanza_punos_alternados_y_corredor_central_tornados_dobles_seguro() -> void:
	var boss := _crear_boss()
	boss.position = Vector3.ZERO
	var plat := _crear_plataforma(3.0, Vector3(6.5, 0.06, 0.0))
	boss.plataformas_combate = [plat]
	boss._ready()
	boss.iniciar_despertar()

	var fantasma := track(CharacterBody3D.new())
	fantasma.name = "Fantasma"
	fantasma.add_to_group("fantasmas")
	fantasma.position = Vector3(0.0, 0.2, 8.0)
	boss._fantasma_ref = fantasma

	# 1. Primer ataque de puño hacia la isla
	boss._iniciar_apuntar_plataforma(plat)
	var mano_1 := boss._mano_golpe_actual
	assert_true(mano_1 == 1 or mano_1 == -1, "Debe seleccionar una mano válida para lanzar")

	# Avanzar carga hasta entrar en lanzamiento (ROMPIENDO_PLATAFORMA) y volar ~0.22s
	for _i in range(30):
		boss.procesar_ciclo_boss(0.03)
		if boss.estado_actual == BossEspectral.Estado.ROMPIENDO_PLATAFORMA:
			break
	assert_eq(boss.estado_actual, BossEspectral.Estado.ROMPIENDO_PLATAFORMA)
	for _i in range(7):
		boss.procesar_ciclo_boss(0.03)

	var mano_activa: Node3D = boss._glb_mano_der if mano_1 == 1 else boss._glb_mano_izq
	var base_activa: Vector3 = boss._pos_base_mano_der if mano_1 == 1 else boss._pos_base_mano_izq
	var arm_activa: Node3D = boss._arm_mano_der if mano_1 == 1 else boss._arm_mano_izq
	var mano_opuesta: Node3D = boss._glb_mano_izq if mano_1 == 1 else boss._glb_mano_der
	var base_opuesta: Vector3 = boss._pos_base_mano_izq if mano_1 == 1 else boss._pos_base_mano_der

	assert_gt(mano_activa.position.distance_to(base_activa), 1.2, "El puño espectral lanzado debe volar lejos del cuerpo hacia la isla")
	assert_gt(arm_activa.position.distance_to(base_activa + (boss._arm_offset_mano_der if mano_1 == 1 else boss._arm_offset_mano_izq)), 1.2, "El guantelete de armadura debe volar junto con el puño espectral")
	assert_true(mano_opuesta.position.distance_to(base_opuesta) < 0.7, "La mano opuesta debe permanecer junto al jefe")

	# Terminar regreso del puño y regenerar la isla para verificar el segundo golpe alternado
	for _i in range(25):
		boss.procesar_ciclo_boss(0.04)
	if plat.esta_destruida():
		plat.regenerar_en_posicion(Vector3(6.5, 0.06, 0.0), false)
	else:
		plat.cancelar_ruptura()
	boss._iniciar_apuntar_plataforma(plat)
	assert_eq(boss._mano_golpe_actual, -mano_1, "El segundo golpe debe alternar hacia el otro puño")
	assert_true(absf(boss._dir_barrido_puno_mundo.length() - 1.0) < 0.1, "Debe calcular dirección lateral normalizada para el barrido del puño")
	boss._cancelar_ataque_activo(false)
	boss.estado_actual = BossEspectral.Estado.COMBATE_INTANGIBLE

	# 2. Fase 2: corredor central libre al lanzar 2 tornados
	boss.vida_actual = 2
	fantasma.position = Vector3(0.0, 0.2, 6.0)
	boss.rotation.y = 0.0
	boss._lanzar_rafaga_tornados(fantasma)
	assert_eq(boss._tornados_activos.size(), 2, "Fase 2 debe lanzar 2 tornados")

	var t0: ProyectilTornadoBoss = boss._tornados_activos[0]
	var t1: ProyectilTornadoBoss = boss._tornados_activos[1]
	fantasma.velocity = Vector3.ZERO
	for _i in range(9):
		fantasma.position = Vector3(0.0, 0.2, t0.position.z)
		t0.procesar_tornado(0.05)
		t1.procesar_tornado(0.05)
	assert_eq(fantasma.velocity, Vector3.ZERO, "Pasar exactamente por la mitad entre los dos tornados NO debe empujar al Fantasma")

	# Al tocar directamente uno de los dos tornados sí debe empujarlo
	fantasma.position = t0.position + Vector3(0.2, 0.2, 0.0)
	t0.procesar_tornado(0.016)
	assert_gt(Vector2(fantasma.velocity.x, fantasma.velocity.z).length(), 2.0, "Tocar directamente uno de los dos tornados sí debe empujar al Fantasma")

	boss._limpiar_entidades_combate(true)

func test_islas_pequenas_no_atraviesan_suelo_y_regeneracion_siempre_escalable() -> void:
	var boss := _crear_boss()
	boss.position = Vector3.ZERO
	var p1 := _crear_plataforma(1.65, Vector3(-5.6, 0.06, 3.6))
	var p2 := _crear_plataforma(3.2, Vector3(-6.3, 0.06, -1.2))
	var p3 := _crear_plataforma(4.75, Vector3(-3.2, 0.06, -5.4))
	var p4 := _crear_plataforma(5.35, Vector3(2.0, 0.06, -5.8))
	var p5 := _crear_plataforma(5.85, Vector3(5.8, 0.06, -2.2))
	var lista: Array[PlataformaColiseo] = [p1, p2, p3, p4, p5]
	boss.plataformas_combate = [p1, p2, p3, p4, p5]
	boss._ready()
	boss.iniciar_despertar()

	for i in range(lista.size()):
		var p := lista[i]
		assert_true(p.radio_plataforma <= 1.25, "Las islas deben mantenerse compactas por defecto")
		assert_true(p.obtener_profundidad_roca() < p.altura_elevada - 0.3, "La base rocosa no debe llegar al suelo en la isla %d" % (i + 1))

	# Oscilación en Fase 3 sobre la isla más baja nunca debe hundirla bajo el suelo
	p1.configurar_oscilacion(true, 0.74, 2.25, 0.0)
	for step in range(30):
		p1.procesar_isla(0.1)
		assert_true(p1.position.y >= p1.obtener_posicion_base().y + p1.obtener_profundidad_roca() + 0.10, "La oscilación vertical no debe hundir la isla bajo el suelo")

	# Simular destrucción y regeneración varias veces en Fase 2
	boss.vida_actual = 2
	boss._reorganizar_islas_nueva_fase(false)
	for i in range(lista.size() - 1):
		var a := lista[i].obtener_posicion_base()
		var b := lista[i + 1].obtener_posicion_base()
		var d_consec := Vector2(a.x - b.x, a.z - b.z).length()
		assert_true(d_consec <= 5.6, "Reorganización por fase debe mantener secuencia escalable (%f m)" % d_consec)
		assert_true(d_consec >= 2.8, "Las islas reorganizadas no deben amontonarse entre sí (%f m)" % d_consec)

	for idx_rot in [1, 2, 0, 3]:
		var target := lista[idx_rot]
		target.destruir_inmediatamente(Vector3.RIGHT)
		assert_true(target.esta_destruida())
		var nueva := boss._calcular_nueva_posicion_isla(target)
		target.regenerar_en_posicion(nueva, false)
		if idx_rot > 0:
			var pb := lista[idx_rot - 1].obtener_posicion_base()
			assert_true(Vector2(nueva.x - pb.x, nueva.z - pb.z).length() <= 6.4, "Isla regenerada debe permanecer alcanzable desde el peldaño anterior")

func test_fase_3_invocacion_animada_y_mini_espectros_esperando_en_plataformas() -> void:
	var boss := _crear_boss()
	boss.position = Vector3.ZERO
	var p1 := _crear_plataforma(1.65, Vector3(-5.6, 0.06, 3.6))
	var p2 := _crear_plataforma(3.2, Vector3(-6.3, 0.06, -1.2))
	var p3 := _crear_plataforma(4.75, Vector3(-3.2, 0.06, -5.4))
	var p4 := _crear_plataforma(5.35, Vector3(2.0, 0.06, -5.8))
	var p5 := _crear_plataforma(5.85, Vector3(5.8, 0.06, -2.2))
	boss.plataformas_combate = [p1, p2, p3, p4, p5]
	boss._ready()
	boss.iniciar_despertar()
	boss.vida_actual = 1

	var vivo := track(CharacterBody3D.new())
	vivo.position = Vector3(0.0, 0.54, 7.0) # Abajo en el suelo del coliseo
	boss._jugador_vivo_ref = vivo

	boss._iniciar_invocacion_espectros()
	assert_eq(boss.estado_actual, BossEspectral.Estado.INVOCANDO_ESPECTROS)
	assert_gt(boss._plataformas_invocacion_objetivo.size(), 0, "Debe elegir plataformas objetivo para el ritual de invocación")

	# Avanzar canalización + liberación de invocación
	for _i in range(30):
		boss.procesar_ciclo_boss(0.08)

	assert_eq(boss._mini_espectros_activos.size(), 2, "Fase 3 debe invocar 2 mini espectros")
	for m in boss._mini_espectros_activos:
		var esp := m as EnemigoEspectral
		assert_ne(esp, null)
		assert_true(esp.modo_guardia_plataforma, "Los mini espectros de Fase 3 deben invocar con modo_guardia_plataforma activado")
		assert_ne(esp.plataforma_asignada, null, "Cada mini espectro debe tener una plataforma elevada asignada")
		var pos_plat := esp.plataforma_asignada.position
		assert_true(absf(esp.position.y - (pos_plat.y + esp.altura_flotacion)) < 0.2, "Debe aparecer encima de su plataforma asignada")
		assert_true(Vector2(esp.position.x - pos_plat.x, esp.position.z - pos_plat.z).length() <= 1.0, "Debe esperar centrado sobre su plataforma")

		# Simular ciclo del mini espectro mientras el Vivo sigue en el suelo: NO debe desvanecerse ni bajar al suelo
		esp._jugador_vivo_ref = vivo
		for _step in range(10):
			esp.procesar_ciclo_ia(0.25)
		assert_ne(esp.estado_actual, EnemigoEspectral.Estado.INACTIVO_OCULTO, "El mini espectro debe seguir esperando en la plataforma aunque el Vivo esté en el suelo")
		assert_true(absf(esp.position.y - (pos_plat.y + esp.altura_flotacion)) < 0.3, "El mini espectro debe permanecer arriba sobre su plataforma")

	boss._limpiar_entidades_combate(true)

func test_pisoton_lanza_vivo_al_frente_y_boss_se_enoja_antes_de_fase_2() -> void:
	var boss := _crear_boss()
	boss.position = Vector3.ZERO
	boss.offset_punto_control = Vector3(0.0, 0.6, 11.5)
	boss.tiempo_invulnerabilidad_golpe = 2.0
	var p1 := _crear_plataforma(1.65, Vector3(-5.6, 0.06, 3.6))
	var p2 := _crear_plataforma(3.2, Vector3(-6.3, 0.06, -1.2))
	boss.plataformas_combate = [p1, p2]
	boss._ready()
	boss.iniciar_despertar()
	boss._establecer_tangibilidad(true)

	var vivo := track(CharacterBody3D.new())
	vivo.position = Vector3(-0.3, boss.obtener_altura_cabeza_global() + BossEspectral.ALTURA_PIES_VIVO_LOCAL + 0.1, -0.4)
	vivo.velocity = Vector3(0.0, -4.0, 0.0)
	boss._jugador_vivo_ref = vivo

	assert_true(boss._verificar_pisoton_vivo(vivo))
	assert_eq(boss.vida_actual, 2)
	assert_eq(boss.estado_actual, BossEspectral.Estado.ATURDIDO_GOLPE)
	assert_gt(vivo.velocity.z, 6.0, "El pisotón debe devolver al Vivo hacia el suelo al frente del coliseo (+Z)")
	assert_gt(vivo.velocity.y, 4.0, "El pisotón debe impulsar en arco al Vivo")
	assert_eq(boss._fase_aplicada, 1, "No debe activar Fase 2 instantáneamente; primero debe hacer la animación de enojo")

	# Durante la mitad del enojo: sigue en ATURDIDO_GOLPE, ojos arden y aún NO cambió a Fase 2
	boss.procesar_ciclo_boss(0.8)
	assert_eq(boss.estado_actual, BossEspectral.Estado.ATURDIDO_GOLPE)
	assert_gt(boss._mat_rojo.emission_energy_multiplier, 5.5, "Durante el enojo los ojos/boca deben arder intensamente")
	assert_eq(boss._fase_aplicada, 1, "Fase 2 debe esperar a que termine la animación de enojo y temblor")

	# Al finalizar la animación de enojo -> entra en Fase 2
	boss.procesar_ciclo_boss(1.4)
	assert_eq(boss.estado_actual, BossEspectral.Estado.COMBATE_INTANGIBLE)
	assert_eq(boss._fase_aplicada, 2, "Al completar el enojo debe arrancar la Fase 2")

func test_repulsion_cercania_fuerte_para_vivo_y_fantasma() -> void:
	var boss := _crear_boss()
	boss.position = Vector3.ZERO
	boss._ready()
	boss.iniciar_despertar()

	var vivo := track(CharacterBody3D.new())
	vivo.position = Vector3(0.0, 0.6, 1.8) # Pegado debajo del jefe
	boss._jugador_vivo_ref = vivo

	var fantasma := track(CharacterBody3D.new())
	fantasma.name = "Fantasma"
	fantasma.add_to_group("fantasmas")
	fantasma.position = Vector3(-1.9, 0.8, 0.0) # Demasiado cerca del jefe sin Aura activa
	var aura := track(HabilidadAura.new())
	aura.name = "HabilidadAura"
	fantasma.add_child(aura)
	boss._fantasma_ref = fantasma

	boss._verificar_repulsion_cercania(vivo, fantasma)
	var vel_v := Vector2(vivo.velocity.x, vivo.velocity.z).length()
	var vel_f := Vector2(fantasma.velocity.x, fantasma.velocity.z).length()
	assert_gt(vel_v, 12.0, "Acercarse mucho siendo Vivo debe repelerlo con fuerza hacia atrás")
	assert_gt(vel_f, 12.0, "Acercarse mucho siendo Fantasma sin Aura también debe repelerlo hacia atrás")
	assert_gt(float(boss._empuje_activo_vivo["tiempo"]), 0.2, "El empuje al Vivo debe sostenerse para lograr mayor distancia")
	assert_gt(float(boss._empuje_activo_fantasma["tiempo"]), 0.2, "El empuje al Fantasma debe sostenerse para lograr mayor distancia")

	# Si el Fantasma activa el Aura desde distancia media (5.0m), congela al Boss sin repelerlo
	fantasma.position = Vector3(0.0, 0.6, 5.2)
	fantasma.velocity = Vector3.ZERO
	boss._empuje_activo_fantasma["tiempo"] = 0.0
	aura.activa = true
	aura.radio_actual = 6.5
	boss.procesar_ciclo_boss(0.016)
	assert_eq(boss.estado_actual, BossEspectral.Estado.TANGIBLE_VULNERABLE, "El Aura del Fantasma a distancia media debe congelar al jefe normalmente")
	assert_eq(fantasma.velocity, Vector3.ZERO, "Al congelarlo con el Aura no debe repeler al Fantasma")

func test_camara_inteligente_centra_en_jefe_y_adapta_pitch_y_distancia() -> void:
	var escena_j = ResourceLoader.load("res://scenes/characters/jugador.tscn", "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
	var jugador := track(escena_j.instantiate()) as Jugador
	var boss := _crear_boss()
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.add_child(boss)
		tree.root.add_child(jugador)

	boss.global_position = Vector3.ZERO
	boss.iniciar_despertar()
	jugador.jefe_camara_override = boss
	jugador.objetivo_rotacion_y = PI * 0.75 # Mirando hacia otro lado inicialmente

	# 1. Fuera de la arena (> 20 m): no debe activar la cámara del jefe
	jugador.global_position = Vector3(0.0, 0.0, 24.0)
	assert_eq(jugador.obtener_jefe_camara_activo(), null, "Fuera del coliseo no debe activar cámara de jefe")

	# 2. En zona media frente al jefe (z = +5.5): yaw debe apuntar a 0.0 (-Z) y ampliar distancia
	jugador.global_position = Vector3(0.0, 0.0, 5.5)
	assert_eq(jugador.obtener_jefe_camara_activo(), boss, "Dentro de la arena debe detectar al BossEspectral")
	var enc_frente := jugador.calcular_encuadre_camara_jefe(boss)
	assert_true(absf(angle_difference(float(enc_frente["yaw"]), 0.0)) < 0.05, "Desde +Z el yaw de cámara debe apuntar hacia 0.0 (-Z)")
	assert_gt(float(enc_frente["distancia_extra"]), 1.2, "En zona media debe alejar la cámara dinámicamente para ampliar encuadre")
	var pivote_off_frente: Vector3 = enc_frente["offset_pivote"]
	assert_true(pivote_off_frente.z < -0.25, "El pivote debe adelantarse sutilmente hacia el centro (-Z)")

	# 2b. En el borde del coliseo (z = +8.5): la distancia se comprime al cuenco seguro sin rebasar pilares/linternas y mantiene al personaje en cuadro
	jugador.global_position = Vector3(0.0, 0.0, 8.5)
	var enc_borde := jugador.calcular_encuadre_camara_jefe(boss)
	assert_true(float(enc_borde["radio_camara_estimado"]) <= boss.obtener_radio_camara_seguro() + 0.35, "La cámara en el borde no debe salirse del radio seguro de la arena")
	assert_true(float(enc_borde["distancia_extra"]) < float(enc_frente["distancia_extra"]), "Cerca del borde debe comprimirse suavemente para evitar chocar con pilares/faroles")
	assert_true(float(enc_borde["altura_extra"]) <= 0.55, "La altura extra en el borde no debe exceder 0.55m para no sacar al personaje por abajo")
	assert_true((enc_borde["offset_pivote"] as Vector3).length() < 0.35, "El offset del pivote debe atenuarse cerca del borde para mantener centrado al jugador")
	assert_true(jugador.DISTANCIA_CAMARA + float(enc_borde["distancia_extra"]) >= 2.8, "La distancia mínima en el borde debe mantenerse segura sin colapsar sobre el personaje")

	# 3. A la izquierda del jefe en zona media (x = -5.5): yaw debe apuntar a -PI/2 (+X)
	jugador.global_position = Vector3(-5.5, 0.0, 0.0)
	var enc_izq := jugador.calcular_encuadre_camara_jefe(boss)
	assert_true(absf(angle_difference(float(enc_izq["yaw"]), -PI * 0.5)) < 0.05, "Desde -X el yaw de cámara debe apuntar hacia -PI/2 (+X)")

	# Procesar cámara suavemente -> debe girar desde su ángulo inicial hacia el jefe (-PI/2) y aumentar distancia
	var diff_inicial: float = absf(angle_difference(jugador.objetivo_rotacion_y, float(enc_izq["yaw"])))
	for _i in range(28):
		jugador.procesar_camara_base(0.05)
	var diff_final: float = absf(angle_difference(jugador.objetivo_rotacion_y, float(enc_izq["yaw"])))
	assert_true(diff_final < diff_inicial * 0.35, "procesar_camara_base debe orientar suavemente la cámara hacia el jefe")
	assert_gt(jugador.obtener_distancia_camara_deseada(), jugador.DISTANCIA_CAMARA + 1.0, "La distancia deseada debe incrementarse al enfocar al jefe")
	assert_true(jugador.esta_enfocando_jefe(), "Debe reportar esta_enfocando_jefe() == true")

	# 4. Arriba sobre una plataforma (y = +5.5): pitch más negativo mirando hacia abajo y mayor distancia
	jugador.global_position = Vector3(-6.0, 5.5, 0.0)
	var enc_alto := jugador.calcular_encuadre_camara_jefe(boss)
	assert_true(float(enc_alto["pitch"]) < float(enc_frente["pitch"]) - 0.25, "Sobre una plataforma elevada la cámara debe mirar más hacia abajo")

	# 5. Justo sobre la cabeza del jefe (dist_h < 1.0 m): peso_yaw debe anularse para evitar giros bruscos
	jugador.global_position = Vector3(0.4, 5.5, 0.4)
	var enc_encima := jugador.calcular_encuadre_camara_jefe(boss)
	assert_true(is_zero_approx(float(enc_encima["peso_yaw"])), "Justo sobre la cabeza del jefe peso_yaw debe ser 0 para evitar giro de 180°")

func test_camara_inteligente_respeta_pausa_manual_centrado_y_derrota() -> void:
	var escena_j = ResourceLoader.load("res://scenes/characters/jugador.tscn", "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
	var jugador := track(escena_j.instantiate()) as Jugador
	var boss := _crear_boss()
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.add_child(boss)
		tree.root.add_child(jugador)

	boss.global_position = Vector3.ZERO
	boss.iniciar_despertar()
	jugador.jefe_camara_override = boss
	jugador.global_position = Vector3(0.0, 0.0, 10.0)

	# 1. Pausa manual activa: el jugador mira a PI/2 manualmente y la cámara respeta esa orientación temporalmente
	jugador.objetivo_rotacion_y = PI * 0.5
	jugador._tiempo_pausa_camara_jefe = 1.2
	for _i in range(6):
		jugador.procesar_camara_base(0.05)
	assert_true(absf(angle_difference(jugador.objetivo_rotacion_y, PI * 0.5)) < 0.02, "Durante la pausa manual no debe forzar el giro hacia el jefe")

	# 2. Centrar cámara manualmente dentro de la arena limpia la pausa y apunta directo al jefe (yaw = 0.0)
	jugador.centrar_camara_inmediatamente()
	assert_true(is_zero_approx(jugador._tiempo_pausa_camara_jefe), "centrar_camara_inmediatamente debe limpiar la pausa manual")
	assert_true(absf(angle_difference(jugador.objetivo_rotacion_y, 0.0)) < 0.05, "centrar_camara_inmediatamente debe apuntar al jefe dentro de la arena")

	# Procesar unos frames para consolidar _factor_camara_jefe > 0.5
	for _i in range(12):
		jugador.procesar_camara_base(0.05)
	assert_gt(jugador._factor_camara_jefe, 0.5)

	# 3. Al derrotar al jefe (Estado.DERROTADO), deja de enfocarlo y retorna suavemente distancia/pivote y pitch a neutro
	jugador.objetivo_rotacion_x = -0.56
	boss.estado_actual = BossEspectral.Estado.DERROTADO
	assert_eq(jugador.obtener_jefe_camara_activo(), null, "Un jefe DERROTADO no debe seguir siendo objetivo de cámara")
	for _i in range(25):
		jugador.procesar_camara_base(0.05)
	assert_true(jugador._factor_camara_jefe < 0.1, "Tras derrotar al jefe el factor de cámara debe disiparse")
	assert_true(jugador._distancia_extra_jefe_actual < 0.1, "La distancia extra de jefe debe volver suavemente a 0 tras la derrota")
	assert_gt(jugador.objetivo_rotacion_x, -0.35, "Tras derrotar al jefe el pitch debe recuperarse hacia PITCH_DEFECTO_CAMARA sin quedarse mirando abajo")

func test_camara_jefe_estabilidad_centro_precision_movimiento_y_aire() -> void:
	var escena_j = ResourceLoader.load("res://scenes/characters/jugador.tscn", "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
	var jugador := track(escena_j.instantiate()) as Jugador
	var boss := _crear_boss()
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.add_child(boss)
		tree.root.add_child(jugador)

	boss.global_position = Vector3.ZERO
	boss._posicion_centro_arena = Vector3.ZERO
	boss.iniciar_despertar()
	jugador.jefe_camara_override = boss
	jugador.global_position = Vector3(0.0, 0.0, 6.0)

	# 1. Estabilidad ante giro/patrulla del jefe en el centro: el foco queda anclado en _posicion_centro_arena
	var foco_base := boss.obtener_punto_foco_camara()
	var enc_inicial := jugador.calcular_encuadre_camara_jefe(boss)
	boss.global_position = Vector3(1.8, 0.0, -1.2)
	boss.rotation.y = PI
	var foco_patrulla := boss.obtener_punto_foco_camara()
	var enc_patrulla := jugador.calcular_encuadre_camara_jefe(boss)
	assert_true(foco_base.is_equal_approx(foco_patrulla), "El punto de foco debe mantenerse anclado al centro aunque el jefe patrulle y gire")
	assert_true(absf(angle_difference(float(enc_inicial["yaw"]), float(enc_patrulla["yaw"]))) < 0.001, "El yaw de la cámara no debe oscilar cuando el jefe gira en el centro")

	# Consolidar enfoque de cámara sobre el jefe
	for _i in range(15):
		jugador.procesar_camara_base(0.05)
	assert_true(jugador.esta_enfocando_jefe(), "La cámara debe estar enfocando al jefe")

	# 2. Precisión de movimiento: mantener input lateral mientras rota el pivote conserva trayectoria recta
	var pivote := jugador.obtener_pivote_camara()
	pivote.global_rotation = Vector3.ZERO
	var dir_1 := jugador.calcular_direccion_movimiento_con_input(Vector2(1.0, 0.0))
	pivote.global_rotation = Vector3(0.0, 0.35, 0.0)
	var dir_2 := jugador.calcular_direccion_movimiento_con_input(Vector2(1.0, 0.0))
	assert_gt(dir_1.dot(dir_2), 0.999, "Mantener la misma dirección de movimiento debe conservar trayectoria recta aunque gire la cámara")

	# Al cambiar claramente de dirección (> ~22°) debe actualizar al ángulo actual de la cámara
	var dir_adelante := jugador.calcular_direccion_movimiento_con_input(Vector2(0.0, -1.0))
	var forward_pivote := -Basis(Vector3.UP, 0.35).z
	assert_gt(dir_adelante.dot(forward_pivote), 0.99, "Al cambiar dirección de input debe alinearse a la orientación actual de la cámara")

	# Regresión joystick analógico: girar suavemente en pasos pequeños (~8°) debe actualizar el ancla acumulada a la cámara actual
	pivote.global_rotation = Vector3(0.0, 0.0, 0.0)
	jugador.calcular_direccion_movimiento_con_input(Vector2(0.0, -1.0))
	pivote.global_rotation = Vector3(0.0, 0.35, 0.0)
	for step_ang in range(1, 12):
		var ang_rad := deg_to_rad(8.0 * float(step_ang))
		var v_stick := Vector2(sin(ang_rad), -cos(ang_rad))
		jugador.calcular_direccion_movimiento_con_input(v_stick)
	assert_true(absf(angle_difference(jugador._yaw_movimiento_anclado, 0.35)) < 0.02, "Girar suavemente el stick en incrementos de 8° debe actualizar _yaw_movimiento_anclado hacia el yaw actual de cámara")

	# Regresión pausa manual de cámara (stick derecho) y deriva grande en el borde (> 0.42 rad)
	pivote.global_rotation = Vector3(0.0, 0.0, 0.0)
	jugador._tiempo_pausa_camara_jefe = 0.0
	jugador.calcular_direccion_movimiento_con_input(Vector2(0.0, -1.0))
	pivote.global_rotation = Vector3(0.0, 0.25, 0.0)
	jugador._tiempo_pausa_camara_jefe = 1.0
	jugador.calcular_direccion_movimiento_con_input(Vector2(0.0, -1.0))
	assert_true(absf(angle_difference(jugador._yaw_movimiento_anclado, 0.25)) < 0.02, "Con pausa manual activa por stick derecho la dirección debe seguir el yaw actual de la cámara")

	jugador._tiempo_pausa_camara_jefe = 0.0
	pivote.global_rotation = Vector3(0.0, 0.75, 0.0)
	jugador.calcular_direccion_movimiento_con_input(Vector2(0.0, -1.0))
	assert_true(absf(angle_difference(jugador._yaw_movimiento_anclado, 0.75)) < 0.02, "Si la cámara rota > 0.42 rad (por ejemplo cerca del borde) debe actualizar _yaw_movimiento_anclado")

	# 3. Seguimiento suave en el aire (fuera de zona muerta) sin congelarse hasta tocar plataforma
	jugador.global_position = Vector3(-5.5, 2.5, 0.0)
	jugador.velocity = Vector3(0.0, 4.0, 0.0)
	jugador.tiempo_desde_suelo = 0.25
	jugador.objetivo_rotacion_y = 0.25
	jugador._tiempo_pausa_camara_jefe = 0.0
	jugador.procesar_camara_base(0.05)
	var delta_aire: float = absf(angle_difference(jugador.objetivo_rotacion_y, 0.25))
	assert_gt(delta_aire, 0.01, "En el aire fuera de zona muerta debe girar suavemente hacia el jefe sin esperar a pisar plataforma")

	jugador.velocity = Vector3.ZERO
	jugador.tiempo_desde_suelo = 0.0
	jugador.objetivo_rotacion_y = 0.25
	jugador._tiempo_pausa_camara_jefe = 0.0
	jugador.procesar_camara_base(0.05)
	var delta_suelo: float = absf(angle_difference(jugador.objetivo_rotacion_y, 0.25))
	assert_true(delta_aire < delta_suelo, "El giro de cámara en el aire debe ser más amortiguado que en el suelo")

	jugador.global_position = Vector3(0.0, 2.5, 6.0)
	jugador.velocity = Vector3(0.0, 4.0, 0.0)
	jugador.tiempo_desde_suelo = 0.25
	jugador.objetivo_rotacion_y = 0.12
	jugador._tiempo_pausa_camara_jefe = 0.0
	jugador.procesar_camara_base(0.05)
	assert_true(absf(angle_difference(jugador.objetivo_rotacion_y, 0.12)) < 0.001, "Dentro de la zona muerta en el aire no debe derivar")

	# 4. Cono de zona muerta (±14°) moviéndose en suelo en combate normal: evita micro-derivas innecesarias
	boss.estado_actual = BossEspectral.Estado.COMBATE_INTANGIBLE
	jugador.global_position = Vector3(0.0, 0.0, 6.0)
	jugador.velocity = Vector3(4.0, 0.0, 0.0)
	jugador.tiempo_desde_suelo = 0.0
	jugador.objetivo_rotacion_y = 0.12 # Dentro de ±0.24 rad respecto a yaw 0.0
	jugador.procesar_camara_base(0.05)
	assert_true(absf(angle_difference(jugador.objetivo_rotacion_y, 0.12)) < 0.001, "Dentro de la zona muerta caminando en combate normal la cámara no debe derivar")

	# 5. Al cambiar de personaje dentro de la arena prepara directamente la pose de cámara del jefe (y fuera de arena vuelve a rotation.y)
	jugador.global_position = Vector3(0.0, 0.0, 5.0)
	jugador.rotation.y = PI
	jugador._factor_camara_jefe = 0.0
	jugador._jefe_camara_activo = null
	jugador.objetivo_rotacion_y = PI
	jugador.preparar_pose_camara_transicion(-0.22)
	assert_true(jugador.esta_enfocando_jefe(), "preparar_pose_camara_transicion debe activar el enfoque al jefe dentro de la arena")
	assert_true(absf(angle_difference(jugador.objetivo_rotacion_y, 0.0)) < 0.05, "Debe orientar objetivo_rotacion_y directo al jefe, no a rotation.y")
	assert_true(absf(angle_difference(pivote.rotation.y, 0.0)) < 0.05, "Debe orientar pivote.rotation.y directo al jefe")
	var arm := jugador.obtener_spring_arm()
	assert_gt(arm.spring_length, jugador.DISTANCIA_CAMARA + 0.8, "Debe aplicar la distancia de cámara del jefe antes de iniciar la transición")
	assert_true(pivote.global_position.z < jugador.global_position.z - 0.25, "Debe aplicar el offset del pivote hacia el jefe en la pose inicial")

	jugador.global_position = Vector3(0.0, 0.0, 40.0)
	jugador.preparar_pose_camara_transicion(-0.22)
	assert_true(jugador._factor_camara_jefe == 0.0, "Fuera de la arena preparar_pose_camara_transicion debe dejar _factor_camara_jefe en 0.0")
	assert_true(absf(angle_difference(jugador.objetivo_rotacion_y, PI)) < 0.001, "Fuera de la arena debe usar rotation.y como orientación inicial")

func test_coliseo_colisiones_selladas_sin_huecos() -> void:
	var escena = ResourceLoader.load("res://scenes/entorno/estructuras/coliseo_boss.tscn", "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
	var coliseo := track(escena.instantiate()) as Node3D
	assert_true(is_instance_valid(coliseo), "Debe instanciar coliseo_boss.tscn")
	var colisiones := coliseo.get_node_or_null("ColisionesColiseo") as StaticBody3D
	assert_true(is_instance_valid(colisiones), "ColisionesColiseo debe existir")

	for pref in ["MuroGradasIzq_", "MuroGradasDer_"]:
		for i in range(1, 9):
			var nodo := colisiones.get_node_or_null("%s%d" % [pref, i]) as CollisionShape3D
			assert_true(is_instance_valid(nodo), "Debe existir %s%d" % [pref, i])
			var caja := nodo.shape as BoxShape3D
			assert_true(is_instance_valid(caja), "%s%d debe usar BoxShape3D" % [pref, i])
			assert_true(caja.size.y >= 12.0, "%s%d debe tener altura >= 12m para impedir saltos sobre las gradas" % [pref, i])
			assert_true(caja.size.z >= 5.0, "%s%d debe tener espesor radial >= 5m" % [pref, i])
			var dir_rad := Vector3(nodo.position.x, 0.0, nodo.position.z).normalized()
			assert_gt(absf(nodo.transform.basis.z.normalized().dot(dir_rad)), 0.99, "%s%d debe alinearse tangente al círculo del coliseo" % [pref, i])
			var radio_muro := Vector2(nodo.position.x, nodo.position.z).length()
			assert_gt(radio_muro, 14.5, "%s%d debe permanecer en el perímetro exterior (>= 14.5m) sin invadir la arena" % [pref, i])

	var m_izq := colisiones.get_node_or_null("MuroTunelSalidaIzq") as CollisionShape3D
	var m_der := colisiones.get_node_or_null("MuroTunelSalidaDer") as CollisionShape3D
	assert_true(is_instance_valid(m_izq) and is_instance_valid(m_der), "Deben existir flancos laterales del túnel de salida")

	var pared_suave := colisiones.get_node_or_null("ParedCircularSuave") as CollisionShape3D
	assert_true(is_instance_valid(pared_suave), "Debe existir ParedCircularSuave para suavizar el deslizamiento por el perímetro")
	var shape_suave := pared_suave.shape as ConcavePolygonShape3D
	assert_true(is_instance_valid(shape_suave), "ParedCircularSuave debe usar ConcavePolygonShape3D")
	var verts_suaves := shape_suave.get_faces()
	assert_true(verts_suaves.size() >= 384, "ParedCircularSuave debe tener >= 384 vértices (64 segmentos / 128 triángulos)")
	for v in verts_suaves:
		assert_false(absf(v.x) < 2.5 and v.z < -10.5, "ParedCircularSuave no debe bloquear el corredor trasero")

	# Verificar que el corredor de salida trasera (x en [-2.5, 2.5]) no quede bloqueado a altura de personaje
	for child in colisiones.get_children():
		if child is CollisionShape3D and child.name.begins_with("Muro"):
			var cs := child as CollisionShape3D
			assert_false(absf(cs.position.x) < 2.5 and cs.position.z < -12.0, "Ningún muro debe bloquear el corredor trasero (%s)" % cs.name)

func test_puno_en_plataforma_y_tornado_atrapando_hacen_reaparecer() -> void:
	var escena_j = ResourceLoader.load("res://scenes/characters/jugador.tscn", "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
	var escena_f = ResourceLoader.load("res://scenes/characters/fantasma.tscn", "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
	var jugador := track(escena_j.instantiate()) as Jugador
	var fantasma := track(escena_f.instantiate()) as Fantasma
	var boss := _crear_boss()
	var plat := _crear_plataforma(2.5, Vector3(6.0, 0.0, 0.0))
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.add_child(boss)
		tree.root.add_child(plat)
		tree.root.add_child(jugador)
		tree.root.add_child(fantasma)

	boss.global_position = Vector3.ZERO
	boss._posicion_centro_arena = Vector3.ZERO
	boss._y_suelo_arena = 0.0
	boss.plataformas_combate = [plat]
	jugador.punto_control = Vector3(0.0, 0.5, 11.5)
	fantasma.punto_control = Vector3(1.5, 0.5, 11.5)
	boss.iniciar_despertar()
	boss._finalizar_despertar()

	# (a) Puño en plataforma con Vivo encima -> señal + reaparecer()
	jugador.global_position = Vector3(plat.global_position.x, plat.global_position.y + 0.65, plat.global_position.z)
	boss._plataforma_objetivo = plat
	var vis_j := jugador.get_node("vivo") as Node3D
	var vis_f := fantasma.get_node("fantasma") as Node3D
	var golpeados: Array = []
	boss.vivo_golpeado_por_puno.connect(func(v): golpeados.append(v))
	boss._ejecutar_impacto_puno_en_isla()
	assert_eq(golpeados.size(), 1, "El golpe de puño a la plataforma con Vivo encima debe emitir vivo_golpeado_por_puno")
	assert_eq(jugador.scale, Vector3.ONE, "La raíz CharacterBody3D del Vivo debe mantener escala uniforme Vector3.ONE")
	assert_true(absf(vis_j.scale.x) < 0.45 and absf(vis_j.scale.y) > 0.55, "Al destruir la plataforma el nodo visual del Vivo debe iniciar su animación de desintegración antes de reaparecer")
	assert_true(jugador.global_position.distance_to(jugador.punto_control) > 1.0, "El Vivo no debe desaparecer instantáneamente en el frame 0 al romperse la plataforma")
	for _step_d in range(10):
		boss._actualizar_animaciones_muerte_personajes(0.05)
	assert_eq(jugador.scale, Vector3.ONE, "La raíz CharacterBody3D del Vivo debe seguir en Vector3.ONE tras desintegrarse")
	assert_true(vis_j.scale.abs().distance_to(Vector3(0.5, 0.5, 0.5)) < 0.05, "Tras completarse la desintegración el visual del Vivo debe restaurar su escala normal")
	assert_true(jugador.global_position.distance_to(jugador.punto_control) < 0.25, "El Vivo golpeado en plataforma por el puño debe reaparecer en su punto_control tras desintegrarse")

	# (b) Tornado succionando y atrapando al Fantasma -> peligro real + giro/compresión visual + reaparecer()
	var tornado := track(ProyectilTornadoBoss.new()) as ProyectilTornadoBoss
	tornado.velocidad = 0.0
	tornado.tiempo_vida = 3.0
	tornado.tiempo_atrapado_para_reaparecer = 0.55
	tornado.centro_arena = Vector3.ZERO
	tornado.objetivo_fantasma = fantasma
	if tree and tree.root:
		tree.root.add_child(tornado)
	tornado.global_position = Vector3(-4.0, 0.0, 2.0)

	var reaparecidos_tornado: Array = []
	tornado.fantasma_reaparecido_por_tornado.connect(func(f): reaparecidos_tornado.append(f))
	fantasma.global_position = tornado.global_position + Vector3(0.95, 0.35, 0.0)
	var dist_antes_succion := Vector2(fantasma.global_position.x - tornado.global_position.x, fantasma.global_position.z - tornado.global_position.z).length()
	tornado.procesar_tornado(0.15)
	var dist_despues_succion := Vector2(fantasma.global_position.x - tornado.global_position.x, fantasma.global_position.z - tornado.global_position.z).length()
	assert_true(dist_despues_succion < dist_antes_succion, "El tornado debe succionar al Fantasma hacia su núcleo para representar un peligro real")
	assert_eq(fantasma.scale, Vector3.ONE, "La raíz CharacterBody3D del Fantasma debe mantener escala uniforme Vector3.ONE durante la succión")
	assert_true(absf(vis_f.scale.x) < 0.48 and absf(vis_f.scale.y) > 0.52, "El visual del Fantasma atrapado en el vórtice debe comprimirse/estirarse girando antes de reaparecer")

	for _i in range(6):
		if not is_instance_valid(tornado) or tornado._disipado:
			break
		tornado.procesar_tornado(0.12)

	assert_eq(reaparecidos_tornado.size(), 1, "El tornado debe atrapar y hacer reaparecer al Fantasma rápidamente (~0.55s)")
	assert_eq(fantasma.scale, Vector3.ONE, "La raíz CharacterBody3D del Fantasma debe seguir en Vector3.ONE al reaparecer")
	assert_true(vis_f.scale.abs().distance_to(Vector3(0.5, 0.5, 0.5)) < 0.05, "Al reaparecer por el tornado el visual del Fantasma debe restaurar su escala normal")
	assert_true(fantasma.global_position.distance_to(fantasma.punto_control) < 0.25, "El Fantasma atrapado en el tornado debe reaparecer en su punto_control")

	# (c) Levitación inicial de plataformas y hundimiento por peso al saltar sobre ellas
	plat.sync_to_physics = false
	plat.elevar(false)
	var y_inicial_plat: float = plat.position.y
	plat.procesar_isla(0.35)
	assert_true(absf(plat.position.y - y_inicial_plat) > 0.015, "Las plataformas deben levitar suavemente desde el inicio (Fase 1)")
	var y_antes_salto: float = plat.position.y
	plat.registrar_impacto_peso(1.25)
	plat.procesar_isla(0.04)
	assert_true(plat.obtener_hundimiento_peso() > 0.08 and plat.position.y < y_antes_salto, "Al saltar sobre una plataforma debe bajar un poco mostrando el peso")

func test_aplastamiento_puno_en_suelo_contra_vivo() -> void:
	var escena_j = ResourceLoader.load("res://scenes/characters/jugador.tscn", "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
	var escena_f = ResourceLoader.load("res://scenes/characters/fantasma.tscn", "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
	var jugador := track(escena_j.instantiate()) as Jugador
	var fantasma := track(escena_f.instantiate()) as Fantasma
	var boss := _crear_boss()
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.add_child(boss)
		tree.root.add_child(jugador)
		tree.root.add_child(fantasma)

	boss.global_position = Vector3.ZERO
	boss._posicion_centro_arena = Vector3.ZERO
	boss._y_suelo_arena = 0.0
	jugador.punto_control = Vector3(0.0, 0.5, 11.5)
	fantasma.global_position = Vector3(-7.0, 0.0, 4.0)
	boss.iniciar_despertar()
	boss._finalizar_despertar()

	jugador.global_position = Vector3(0.0, 0.0, 6.0)
	boss._temporizador_decision = 0.0
	boss._cooldown_tornado = 2.5
	boss._cooldown_aplastamiento = 0.0

	var tornados_previos: int = boss._tornados_activos.size()
	var aplastados: Array = []
	boss.personaje_aplastado_por_puno.connect(func(pj): aplastados.append(pj))

	boss.procesar_ciclo_boss(0.05)
	assert_eq(boss.estado_actual, BossEspectral.Estado.PREPARANDO_APLASTAMIENTO, "Con Vivo en el suelo y tornado en cooldown debe preparar aplastamiento vertical")
	assert_eq(boss._tornados_activos.size(), tornados_previos, "El aplastamiento al Vivo no debe lanzar tornados")

	var lado_puno: float = float(boss._mano_golpe_actual if boss._mano_golpe_actual != 0 else -1)
	var arm_activa: Node3D = boss._arm_mano_der if lado_puno > 0.0 else boss._arm_mano_izq
	var eje_punta_local := Vector3(lado_puno, 0.0, 0.0)
	var dir_punta_prep: Vector3 = (arm_activa.transform.basis * eje_punta_local).normalized()
	assert_true(dir_punta_prep.z > 0.75, "Al preparar aplastamiento la punta de la mano debe apuntar hacia el frente (+Z), no de lado")

	var entro_aplastando: bool = false
	for _step in range(30):
		if aplastados.is_empty():
			jugador.global_position = Vector3(0.0, 0.0, 6.0)
		boss.procesar_ciclo_boss(0.05)
		if boss.estado_actual == BossEspectral.Estado.APLASTANDO_SUELO:
			entro_aplastando = true
		if aplastados.size() > 0:
			break

	var vis_j := jugador.get_node("vivo") as Node3D
	var dir_punta_imp: Vector3 = (arm_activa.transform.basis * eje_punta_local).normalized()
	assert_true(dir_punta_imp.z > 0.75, "Al aplastar en el suelo la mano y su brazalete deben quedar orientados hacia el frente (+Z)")
	assert_true(entro_aplastando, "Tras telegrafiar debe pasar a APLASTANDO_SUELO")
	assert_true(aplastados.has(jugador), "El golpe vertical del puño sobre el Vivo debe emitir personaje_aplastado_por_puno")
	assert_eq(jugador.scale, Vector3.ONE, "La raíz CharacterBody3D del Vivo debe mantener escala uniforme Vector3.ONE al ser aplastado")
	assert_true(absf(vis_j.scale.y) < 0.15 and absf(vis_j.scale.x) > 0.70, "Al ser aplastado el visual del Vivo debe quedar achatado en el suelo mientras el jefe retira la mano")
	assert_true(jugador.global_position.distance_to(jugador.punto_control) > 1.0, "El Vivo aplastado debe permanecer visible achatado al levantar la mano antes de reaparecer")

	for _step_post in range(12):
		boss.procesar_ciclo_boss(0.05)
	assert_eq(jugador.scale, Vector3.ONE, "La raíz CharacterBody3D del Vivo debe seguir en Vector3.ONE tras reaparecer")
	assert_true(vis_j.scale.abs().distance_to(Vector3(0.5, 0.5, 0.5)) < 0.05, "Tras mostrar al Vivo aplastado su visual debe restaurar su escala normal")
	assert_true(jugador.global_position.distance_to(jugador.punto_control) < 0.25, "El Vivo aplastado por el puño debe reaparecer en su punto_control tras retirar la mano")

	# Verificar fade rápido y progresivo en la emisión de los cristales de la armadura (rojo / azul / morado)
	var mat_c: StandardMaterial3D = boss._mat_cristal_armadura
	assert_ne(mat_c, null, "Debe existir material dinámico de cristales de armadura")
	boss._iniciar_preparar_aplastamiento(jugador)
	for _f in range(10):
		boss._actualizar_brillo_cristales_armadura(0.04, false)
	assert_true(mat_c.emission_energy_multiplier >= 3.5 and mat_c.emission.r > 0.85 and mat_c.emission.r > mat_c.emission.b, "Al atacar con puños los cristales deben brillar en rojo tras el fade rápido")
	boss._iniciar_preparar_tornado()
	assert_true(mat_c.emission.r > 0.35 and mat_c.emission.b < 0.75, "El cambio de color de rojo a azul no debe ser instantáneo, sino iniciar un fade progresivo")
	for _f in range(10):
		boss._actualizar_brillo_cristales_armadura(0.04, false)
	assert_true(mat_c.emission_energy_multiplier >= 3.5 and mat_c.emission.b > 0.85 and mat_c.emission.b > mat_c.emission.r, "Al tirar tornados los cristales deben completar el fade rápido a azul")
	boss._iniciar_invocacion_espectros()
	for _f in range(10):
		boss._actualizar_brillo_cristales_armadura(0.04, false)
	assert_true(mat_c.emission_energy_multiplier >= 3.5 and mat_c.emission.r > 0.55 and mat_c.emission.b > 0.85 and mat_c.emission.g < 0.4, "Al invocar espectros los cristales deben completar el fade rápido a morado")






