@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

## ==============================================================================
## SUITE DE PRUEBAS AUTOMATIZADAS: SISTEMA DE POSESIÓN ESPECTRAL DE OBJETOS
## Verifica el ciclo de posesión, control de objetos, adaptación de cámara y efectos.
## ==============================================================================

func suite_name() -> String:
	return "posesion_objetos"

func _recargar_scripts_posesion() -> void:
	var base = load("res://scripts/entorno/isla_flotante.gd")
	if base and base.has_method("reload"):
		base.reload()
	var taxi = load("res://scripts/components/posesion/plataforma_taxi.gd")
	if taxi and taxi.has_method("reload"):
		taxi.reload()
	var ojos = load("res://scripts/components/posesion/ojos_posesion.gd")
	if ojos and ojos.has_method("reload"):
		ojos.reload()
	var canon = load("res://scripts/components/posesion/canon_espiritual.gd")
	if canon and canon.has_method("reload"):
		canon.reload()
	var mira = load("res://scripts/components/posesion/mira_canon_espiritual.gd")
	if mira and mira.has_method("reload"):
		mira.reload()

func test_ojos_posesion_instanciacion_y_expresiones() -> void:
	_recargar_scripts_posesion()
	var script = load("res://scripts/components/posesion/ojos_posesion.gd")
	assert_ne(script, null, "El script de ojos_posesion.gd debe existir")
	
	var ojos = track(script.new()) as OjosPosesion
	ojos._ready()
	
	assert_ne(ojos.ojo_izquierdo, null, "Debe tener ojo izquierdo")
	assert_ne(ojos.ojo_derecho, null, "Debe tener ojo derecho")
	
	# Probar aparición
	ojos.aparecer()
	assert_true(ojos.visible, "Debe volverse visible al aparecer")
	assert_true(ojos._animando_aparicion, "Debe estar en animación de aparición")
	
	# Simular avance de animación de aparición
	ojos._process(0.4)
	assert_false(ojos._animando_aparicion, "Debe completar la animación de aparición")
	assert_true(absf(ojos.scale.x - 1.0) < 0.05, "La escala debe estabilizarse en 1.0")
	
	# Probar actualización de mirada
	ojos.actualizar_mirada(Vector3(1.0, 0.0, -1.0), 0.9)
	ojos._process(0.1)
	assert_true(ojos._offset_mirada_objetivo.x > 0.0, "La mirada debe apuntar a la derecha")

func test_adaptacion_camara_en_objeto_poseible_base() -> void:
	var tree = Engine.get_main_loop() as SceneTree
	var script = load("res://scripts/components/posesion/objeto_poseible_base.gd")
	assert_ne(script, null, "El script de objeto_poseible_base.gd debe existir")
	
	var obj = track(script.new()) as ObjetoPoseibleBase
	obj.distancia_camara_posesion = 8.0
	obj.altura_spring_arm_posesion = 2.5
	obj.pitch_defecto_posesion = -0.30
	obj.multiplicador_distancia_shorts = 1.30
	
	if tree and tree.root:
		tree.root.add_child(obj)
	
	# Distancia adaptada predeterminada en formato Shorts (8.0 * 1.30 = 10.4)
	var dist_adaptada = obj.obtener_distancia_camara_adaptada()
	assert_true(absf(dist_adaptada - (8.0 * 1.30)) < 0.05, "La distancia debe adaptarse con encuadre vertical")
	assert_true(absf(obj.obtener_altura_camara_adaptada() - 2.5) < 0.01, "La altura debe ser 2.5")
	assert_true(absf(obj.obtener_pitch_camara_adaptado() - (-0.30)) < 0.01, "El pitch debe ser -0.30")

func test_plataforma_taxi_vuelo_libre_y_limites() -> void:
	_recargar_scripts_posesion()
	var script = load("res://scripts/components/posesion/plataforma_taxi.gd")
	assert_ne(script, null, "El script de plataforma_taxi.gd debe existir")
	
	var taxi = track(script.new()) as PlataformaTaxi
	taxi.modo_ejes = PlataformaTaxi.ModoEjes.HORIZONTAL
	taxi.velocidad_crucero = 12.0
	taxi.radio_maximo_vuelo = 30.0
	
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.add_child(taxi)
		
	taxi._ready()
	
	assert_false(taxi.esta_poseido, "Debe iniciar sin estar poseído")
	assert_false(taxi.esta_vivo_a_bordo(), "Al inicio el vivo no debe estar a bordo")
	
	# Simular inicio de posesión
	var fantasma_dummy = track(CharacterBody3D.new()) as CharacterBody3D
	taxi.iniciar_posesion(fantasma_dummy)
	assert_true(taxi.esta_poseido, "Debe estar poseído tras iniciar_posesion()")
	
	# Procesar input de avance hacia adelante con botón de salto (efectos / turbo)
	var acciones = {
		"saltar": true,
		"saltar_just_pressed": true,
		"efecto": true,
		"turbo": true
	}
	taxi.procesar_input_posesion(0.1, Vector2(0.0, -1.0), acciones)
	assert_true(taxi.velocity.z < 0.0, "La velocidad debe acelerar hacia adelante (Z negativo)")
	
	# Desposeer: verificar que no se devuelve de inmediato sino que espera unos segundos
	taxi.terminar_posesion()
	assert_false(taxi.esta_poseido, "Debe volver a estado no poseído")
	assert_true(taxi.velocity == Vector3.ZERO, "Debe frenar al salir el fantasma")
	assert_true(taxi._temporizador_espera_retorno > 0.0, "La plataforma debe activar temporizador de espera antes de regresar")
	assert_true(taxi.tiempo_espera_retorno >= 3.0, "El tiempo de espera debe ser de al menos 3 segundos")

func test_plataforma_taxi_riel_direccional() -> void:
	_recargar_scripts_posesion()
	var script = load("res://scripts/components/posesion/plataforma_taxi.gd")
	var taxi = track(script.new()) as PlataformaTaxi
	taxi.modo_vuelo = PlataformaTaxi.ModoVuelo.RIEL_DIRECCIONAL
	taxi.direccion_riel = Vector3.RIGHT # Eje X
	taxi.distancia_maxima_riel = 20.0
	taxi._ready()
	
	var fantasma_dummy = track(CharacterBody3D.new()) as CharacterBody3D
	taxi.iniciar_posesion(fantasma_dummy)
	
	# Input positivo adelante en riel
	taxi.procesar_input_posesion(0.1, Vector2(0.0, -1.0), {})
	assert_true(taxi.velocity.x > 0.0, "Debe moverse a lo largo del eje X definido en el riel")
	
	taxi.terminar_posesion()

func test_plataforma_taxi_eje_vertical() -> void:
	_recargar_scripts_posesion()
	var script = load("res://scripts/components/posesion/plataforma_taxi.gd")
	var taxi = track(script.new()) as PlataformaTaxi
	taxi.modo_ejes = PlataformaTaxi.ModoEjes.VERTICAL
	taxi.velocidad_crucero = 10.0
	
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.add_child(taxi)
	taxi._ready()
	
	var fantasma_dummy = track(CharacterBody3D.new()) as CharacterBody3D
	taxi.iniciar_posesion(fantasma_dummy)
	
	# Stick vertical arriba (W / Up = input_dir.y negativo)
	taxi.procesar_input_posesion(0.1, Vector2(0.0, -1.0), {})
	assert_true(taxi.velocity.y > 0.0, "En modo vertical, avanzar el stick/tecla debe acelerar hacia arriba (Y positivo)")
	
	# Stick vertical abajo (S / Down = input_dir.y positivo)
	taxi.procesar_input_posesion(0.2, Vector2(0.0, 1.0), {})
	assert_true(taxi.velocity.y < 0.0, "En modo vertical, retroceder el stick/tecla debe descender (Y negativo)")
	
	taxi.terminar_posesion()

func test_canon_espiritual_punteria_y_disparo() -> void:
	var script = load("res://scripts/components/posesion/canon_espiritual.gd")
	if script and script.has_method("reload"):
		script.reload()
	assert_ne(script, null, "El script de canon_espiritual.gd debe existir")
	
	var canon = track(script.new()) as CanonEspiritual
	canon.fuerza_disparo = 30.0
	canon._ready()
	
	var fantasma_dummy = track(CharacterBody3D.new()) as CharacterBody3D
	canon.iniciar_posesion(fantasma_dummy)
	
	# Cargar un jugador vivo en la recámara
	var tree = Engine.get_main_loop() as SceneTree
	var vivo_dummy = track(CharacterBody3D.new()) as CharacterBody3D
	vivo_dummy.name = "JugadorVivoSimulado"
	if tree and tree.root:
		tree.root.add_child(canon)
		tree.root.add_child(vivo_dummy)
		
	canon._on_cuerpo_recamara_entro(vivo_dummy)
	assert_eq(canon._jugador_cargado, null, "El jugador NO debe ser succionado automáticamente solo por pisar el área")
	
	# Al presionar el botón de acción (intentar_interactuar), entra en la recámara
	var exito_interaccion = canon.intentar_interactuar(vivo_dummy)
	assert_true(exito_interaccion, "intentar_interactuar debe devolver true al entrar el jugador")
	assert_ne(canon._jugador_cargado, null, "El jugador debe estar cargado en el cañón tras pulsar acción")
	assert_true(canon.obtener_direccion_disparo().y > 0.0, "La dirección de disparo debe apuntar hacia arriba en el cielo")
	
	# Disparar
	canon.ejecutar_disparo()
	assert_true(vivo_dummy.velocity.length() > 20.0, "El jugador vivo debe salir disparado con alta velocidad")
	assert_true(vivo_dummy.velocity.y > 0.0, "El vivo debe ser lanzado hacia arriba")
	assert_true(canon._recoil_offset_z > 0.0, "El cañón debe registrar retroceso visual (recoil)")

func test_canon_vivo_entra_sin_disparo_y_fantasma_apunta_y_dispara() -> void:
	var script = load("res://scripts/components/posesion/canon_espiritual.gd")
	if script and script.has_method("reload"):
		script.reload()
	assert_ne(script, null, "El script de canon_espiritual.gd debe existir")
	
	var canon = track(script.new()) as CanonEspiritual
	canon.fuerza_disparo = 32.0
	canon._ready()
	
	var tree = Engine.get_main_loop() as SceneTree
	var vivo_dummy = track(CharacterBody3D.new()) as CharacterBody3D
	vivo_dummy.name = "VivoTest"
	var fantasma_dummy = track(CharacterBody3D.new()) as CharacterBody3D
	fantasma_dummy.name = "FantasmaTest"
	
	if tree and tree.root:
		tree.root.add_child(canon)
		tree.root.add_child(vivo_dummy)
		tree.root.add_child(fantasma_dummy)
	
	# 1. El vivo entra al cañón sin estar poseído
	assert_false(canon.esta_poseido, "El cañón inicialmente no está poseído")
	var entra_exito = canon.intentar_interactuar(vivo_dummy)
	assert_true(entra_exito, "El vivo debe poder entrar al cañón sin estar poseído")
	assert_eq(canon._jugador_cargado, vivo_dummy, "El vivo debe permanecer cargado en la recámara")
	
	# 2. El proceso de físicas NO debe dispararlo automáticamente al entrar
	for _i in range(5):
		canon._physics_process(0.016)
	assert_eq(canon._jugador_cargado, vivo_dummy, "El vivo NO debe ser disparado al instante por interactuar")
	
	# 3. El vivo no puede disparar interactuando de nuevo
	var intento_disparo_vivo = canon.intentar_interactuar(vivo_dummy)
	assert_eq(canon._jugador_cargado, vivo_dummy, "El vivo no debe poder dispararse a sí mismo interactuando")
	
	# 4. El fantasma posee el cañón con el vivo adentro
	canon.iniciar_posesion(fantasma_dummy)
	assert_true(canon.esta_poseido, "El fantasma debe poder poseer el cañón con el vivo adentro")
	assert_eq(canon._jugador_cargado, vivo_dummy, "El vivo sigue dentro del cañón tras la posesión")
	
	# 5. El fantasma calibra y elige la dirección (Yaw y Pitch)
	var yaw_previo = canon._angulo_yaw
	var pitch_previo = canon._angulo_pitch
	canon.procesar_input_posesion(0.1, Vector2(1.0, -1.0), {})
	assert_ne(canon._angulo_yaw, yaw_previo, "El fantasma debe poder rotar el ángulo Yaw")
	assert_ne(canon._angulo_pitch, pitch_previo, "El fantasma debe poder ajustar la elevación Pitch")
	var dir_elegida = canon.obtener_direccion_disparo()
	
	# 6. El fantasma dispara el cañón
	canon.procesar_input_posesion(0.016, Vector2.ZERO, {"disparar": true})
	assert_eq(canon._jugador_cargado, null, "El jugador vivo debe ser expulsado tras el disparo del fantasma")
	assert_true(vivo_dummy.velocity.length() > 25.0, "El vivo debe salir impulsado por el disparo")
	assert_true(vivo_dummy.velocity.dot(dir_elegida) > 0.0, "El vivo debe ser disparado en la dirección elegida por el fantasma")

func test_canon_espiritual_escena_con_modelos_glb() -> void:
	_recargar_scripts_posesion()
	var scene = ResourceLoader.load("res://scenes/components/posesion/canon_espiritual.tscn", "", ResourceLoader.CACHE_MODE_REPLACE)
	assert_ne(scene, null, "La escena de canon_espiritual.tscn debe existir")
	
	var canon = track(scene.instantiate()) as CanonEspiritual
	assert_ne(canon, null, "Debe instanciarse correctamente")
	
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.add_child(canon)
	canon._ready()
	
	var base_glb = canon.get_node_or_null("Canon_Base")
	assert_ne(base_glb, null, "Debe tener el modelo Canon_Base cargado")
	
	var tubo_glb = canon.get_node_or_null("PivoteCanon/Canon_Tubo")
	assert_ne(tubo_glb, null, "Debe tener el modelo Canon_Tubo cargado en el pivote")
	
	var boca = canon.get_node_or_null("PivoteCanon/BocaCanon")
	assert_ne(boca, null, "Debe tener el marcador de boca de cañón")
	assert_true(canon.obtener_direccion_disparo().y > 0.0, "La dirección de disparo del cañón con modelos GLB debe apuntar hacia arriba")
	
	var cabeza = canon.get_node_or_null("PivoteCanon/CabezaFantasmaEmergente")
	assert_ne(cabeza, null, "El cañón debe tener el nodo CabezaFantasmaEmergente en PivoteCanon")
	var ojos = canon.get_node_or_null("PivoteCanon/OjosPosesion")
	assert_ne(ojos, null, "El cañón debe tener el nodo OjosPosesion")
	
	# Verificar que inician ocultos antes de poseer
	assert_false(cabeza.visible, "El copete del cañón debe iniciar oculto")
	assert_false(ojos.visible, "Los ojos del cañón deben iniciar ocultos")
	
	var fantasma_test = track(CharacterBody3D.new()) as CharacterBody3D
	canon.iniciar_posesion(fantasma_test)
	assert_true(cabeza.visible, "El copete del cañón debe emerger al poseerlo")
	assert_true(ojos.visible, "Los ojos del cañón deben aparecer al poseerlo")
	assert_eq(canon.nodo_cabeza, cabeza, "nodo_cabeza debe estar asignado a CabezaFantasmaEmergente")
	assert_eq(canon.nodo_ojos, ojos, "nodo_ojos debe estar asignado a OjosPosesion")
	
	var mira = canon.get_node_or_null("PivoteCanon/MiraCanon")
	assert_ne(mira, null, "El cañón debe tener el nodo MiraCanon en PivoteCanon")
	assert_eq(canon.nodo_mira, mira, "nodo_mira debe estar asignado a MiraCanon")
	assert_true(mira.esta_activa, "La mira espiritual debe estar activa durante la posesión")
	
	# Verificar rotación: Yaw rota el objeto completo, Pitch rota solo el pivote del cañón
	var rot_y_inicial = canon.rotation.y
	var rot_pitch_inicial = canon.nodo_canon_giratorio.rotation.x
	canon.procesar_input_posesion(0.1, Vector2(1.0, 0.0), {})
	assert_ne(canon.rotation.y, rot_y_inicial, "El input horizontal debe rotar el objeto completo (root rotation.y)")
	assert_eq(canon.nodo_canon_giratorio.rotation.y, 0.0, "El pivote del cañón no debe rotar en yaw local")
	
	canon.procesar_input_posesion(0.1, Vector2(0.0, -1.0), {})
	assert_ne(canon.nodo_canon_giratorio.rotation.x, rot_pitch_inicial, "El input vertical debe rotar solo el cañón en elevación (pitch)")
	
	canon.terminar_posesion()
	assert_false(mira.esta_activa, "La mira debe ocultarse al terminar la posesión")

func test_engranaje_espiritual_rotacion_y_progreso() -> void:
	var script = load("res://scripts/components/posesion/engranaje_espiritual.gd")
	assert_ne(script, null, "El script de engranaje_espiritual.gd debe existir")
	
	var engranaje = track(script.new()) as EngranajeEspiritual
	engranaje.rotaciones_completas_necesarias = 1.0 # 1 vuelta = TAU
	engranaje.tiene_limite = true
	engranaje._ready()
	
	var fantasma_dummy = track(CharacterBody3D.new()) as CharacterBody3D
	engranaje.iniciar_posesion(fantasma_dummy)
	
	# Procesar input de giro
	engranaje.procesar_input_posesion(0.1, Vector2(1.0, 0.0), {})
	assert_true(engranaje._angulo_acumulado > 0.0, "El ángulo acumulado debe incrementar con el giro")
	assert_true(engranaje._progreso_normalizado > 0.0, "El progreso debe avanzar de 0 a 1")

func test_habilidad_posesion_ciclo_completo() -> void:
	var tree = Engine.get_main_loop() as SceneTree
	
	# Simular fantasma con estructura contractual
	var fantasma_dummy = track(CharacterBody3D.new()) as CharacterBody3D
	fantasma_dummy.name = "Fantasma"
	fantasma_dummy.add_to_group("fantasmas")
	
	var modelo = track(Node3D.new()) as Node3D
	modelo.name = "fantasma"
	fantasma_dummy.add_child(modelo)
	
	var habilidad_script = load("res://scripts/characters/habilidad_posesion.gd")
	var habilidad = track(habilidad_script.new()) as HabilidadPosesion
	fantasma_dummy.add_child(habilidad)
	habilidad.fantasma = fantasma_dummy
	
	# Crear un objeto poseible cercano
	var obj_script = load("res://scripts/components/posesion/objeto_poseible_base.gd")
	var obj_poseible = track(obj_script.new()) as ObjetoPoseibleBase
	obj_poseible.add_to_group("objetos_poseibles")
	
	if tree and tree.root:
		tree.root.add_child(obj_poseible)
		tree.root.add_child(fantasma_dummy)
	
	fantasma_dummy.global_position = Vector3.ZERO
	obj_poseible.global_position = Vector3(0.0, 0.0, 2.0)
	
	# 1. Simular detección
	habilidad._actualizar_objeto_candidato_cercano()
	assert_true(habilidad.puede_poseer_algo(), "Debe detectar el objeto poseible cercano como candidato")
	assert_eq(habilidad.objeto_candidato_cercano, obj_poseible, "El objeto candidato debe ser el objeto poseible")
	assert_true(obj_poseible.es_candidato_posesion, "El objeto poseible debe tener activo el resalte azul de candidato")
	
	# 2. Iniciar picada
	habilidad.intentar_poseer()
	assert_true(habilidad._en_transicion_picada, "Debe entrar en estado de picada espectral")
	
	# 3. Completar la picada y fusionarse
	habilidad._procesar_transicion_picada(0.35)
	assert_true(habilidad.esta_poseyendo(), "Debe estar en estado de posesión activa tras el impacto")
	assert_true(obj_poseible.esta_poseido, "El objeto debe reportarse poseído")
	assert_false(obj_poseible.es_candidato_posesion, "Al poseerse debe apagarse el resalte de candidato")
	assert_false(modelo.visible, "El modelo del fantasma debe ocultarse durante la posesión")
	
	# 4. Desposeer y salir
	habilidad.desposeer()
	assert_false(habilidad.esta_poseyendo(), "Debe dejar de estar poseyendo")
	assert_false(obj_poseible.esta_poseido, "El objeto debe volver a reposo")
	assert_true(modelo.visible, "El modelo del fantasma debe volver a ser visible")

func test_camara_libre_orbital_durante_posesion() -> void:
	var tree = Engine.get_main_loop() as SceneTree
	var obj_script = load("res://scripts/components/posesion/objeto_poseible_base.gd")
	var obj = track(obj_script.new()) as ObjetoPoseibleBase
	obj.distancia_camara_posesion = 7.0
	obj.altura_spring_arm_posesion = 2.0
	
	# Verificar que el objeto poseible expone distancias adaptadas sin restringir el giro orbital
	assert_true(obj.obtener_distancia_camara_adaptada() > 0.0, "La distancia adaptada debe ser válida")
	assert_true(obj.obtener_altura_camara_adaptada() > 0.0, "La altura adaptada debe ser válida")
	assert_eq(obj.get("bloquear_rotacion_camara"), null, "El objeto poseible no debe fijar ni bloquear la rotación de cámara")

func test_indicador_azul_candidato_posesion() -> void:
	var script = load("res://scripts/components/posesion/objeto_poseible_base.gd")
	assert_ne(script, null, "El script de objeto_poseible_base.gd debe existir")
	
	var obj = track(script.new()) as ObjetoPoseibleBase
	obj._ready()
	
	assert_false(obj.es_candidato_posesion, "Inicialmente no debe ser candidato")
	
	# Al acercarse el fantasma
	obj.establecer_resalte_candidato(true)
	assert_true(obj.es_candidato_posesion, "Debe registrarse como candidato activo")
	
	# Al alejarse el fantasma
	obj.establecer_resalte_candidato(false)
	assert_false(obj.es_candidato_posesion, "Debe desactivar el resalte al alejarse")

func test_plataforma_procedural_posesion_mecanica() -> void:
	var tree = Engine.get_main_loop() as SceneTree
	var isla = track(IslaFlotante.new()) as IslaFlotante
	assert_ne(isla, null, "IslaFlotante debe poder instanciarse")
	
	# Inicialmente no es poseíble
	assert_false(isla.puede_ser_poseida, "Por defecto no es poseíble")
	assert_eq(isla.tipo_comportamiento, IslaFlotante.TipoComportamiento.ESTANDAR, "Por defecto es tipo ESTANDAR")
	
	# Activar posesión
	isla.puede_ser_poseida = true
	assert_true(isla.puede_ser_poseida, "La propiedad puede_ser_poseida debe ser true")
	assert_true(isla.puede_ser_poseido, "La propiedad compatible puede_ser_poseido debe ser true")
	assert_eq(isla.tipo_comportamiento, IslaFlotante.TipoComportamiento.POSEIBLE, "Activar posesión debe cambiar el comportamiento a POSEIBLE")
	
	if tree and tree.root:
		tree.root.add_child(isla)
	isla._ready()
	
	assert_true(isla.is_in_group("objetos_poseibles"), "Una isla procedural con posesión activa debe pertenecer al grupo objetos_poseibles")
	assert_false(isla.esta_poseido, "Inicialmente no debe estar poseída")
	
	# Resalte azul de candidato
	isla.establecer_resalte_candidato(true)
	assert_true(isla.es_candidato_posesion, "Debe marcarse como candidato cercano para el fantasma")
	isla.establecer_resalte_candidato(false)
	assert_false(isla.es_candidato_posesion, "Debe limpiar el estado de candidato al alejarse")
	
	# Simular posesión por el Fantasma
	var fantasma_dummy = track(CharacterBody3D.new()) as CharacterBody3D
	fantasma_dummy.name = "FantasmaTest"
	if tree and tree.root:
		tree.root.add_child(fantasma_dummy)
		
	var exito_pos = isla.iniciar_posesion(fantasma_dummy)
	assert_true(exito_pos, "iniciar_posesion debe retornar true")
	assert_true(isla.esta_poseido, "La isla procedural debe reportarse como poseída")
	
	# Procesar movimiento horizontal
	isla.modo_ejes = IslaFlotante.ModoEjes.HORIZONTAL
	var pos_previa = isla.global_position
	isla.procesar_input_posesion(0.1, Vector2(0.0, -1.0), {"turbo": true})
	assert_true(isla.velocity.z < 0.0, "La plataforma procedural debe acelerar hacia adelante (Z negativo)")
	assert_true(isla.constant_linear_velocity.z < 0.0, "constant_linear_velocity debe actualizarse para arrastrar a los pasajeros")
	assert_ne(isla.global_position, pos_previa, "La posición física de la isla debe cambiar al desplazarse")
	
	# Desposeer: temporizador de espera y retorno suave
	isla.terminar_posesion()
	assert_false(isla.esta_poseido, "La isla procedural debe volver al estado de reposo tras desposeer")
	assert_eq(isla.velocity, Vector3.ZERO, "La velocidad debe anularse al salir el fantasma")
	assert_true(isla._temporizador_espera_retorno > 0.0, "Debe iniciar el tiempo de espera antes de retornar al origen")

func test_plataforma_taxi_hereda_isla_flotante_procedural() -> void:
	_recargar_scripts_posesion()
	var scene = load("res://scenes/components/posesion/plataforma_taxi.tscn")
	assert_ne(scene, null, "La escena plataforma_taxi.tscn debe existir")
	
	var taxi = track(scene.instantiate()) as PlataformaTaxi
	assert_ne(taxi, null, "Debe instanciarse como PlataformaTaxi")
	assert_true(taxi is IslaFlotante, "PlataformaTaxi debe heredar de IslaFlotante para ser procedural")
	assert_true(taxi.puede_ser_poseida, "PlataformaTaxi debe tener puede_ser_poseida en true")
	assert_eq(taxi.tipo_comportamiento, IslaFlotante.TipoComportamiento.POSEIBLE, "PlataformaTaxi debe ser de tipo POSEIBLE")
	
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.add_child(taxi)
	taxi._ready()
	
	assert_true(taxi.is_in_group("objetos_poseibles"), "PlataformaTaxi debe estar en objetos_poseibles")
	assert_ne(taxi.get_node_or_null("MeshInstance3D"), null, "Debe tener MeshInstance3D para la malla procedural")
	assert_ne(taxi.get_node_or_null("CollisionShape3D"), null, "Debe tener CollisionShape3D procedural")
	assert_ne(taxi.get_node_or_null("CabezaFantasmaEmergente"), null, "Debe tener el nodo CabezaFantasmaEmergente")
	assert_ne(taxi.get_node_or_null("OjosPosesion"), null, "Debe tener el nodo OjosPosesion")
	assert_ne(taxi.get_node_or_null("AreaPosesion"), null, "Debe tener el AreaPosesion")
	
	# Verificar que el copete y los ojos inician ocultos en reposo
	assert_false(taxi.nodo_cabeza.visible, "El copete no debe estar visible en reposo antes de poseer")
	assert_false(taxi.nodo_ojos.visible, "Los ojos no deben estar visibles en reposo antes de poseer")
	
	# Probar emergencia al poseer
	var fantasma_dummy = track(CharacterBody3D.new()) as CharacterBody3D
	taxi.iniciar_posesion(fantasma_dummy)
	assert_true(taxi.nodo_cabeza.visible, "La cabeza con copete debe emerger y volverse visible al poseer")
	var cabeza = taxi.nodo_cabeza as CabezaFantasmaEmergente
	if cabeza:
		assert_ne(cabeza.find_child("CopetePoseidoFantasma", true, false), null, "Debe instanciar CopetePoseidoFantasma")
		if cabeza.anim_player:
			assert_true(cabeza.anim_player.has_animation("Idle fantasma copete"), "Debe tener animación Idle fantasma copete")
			assert_true(cabeza.anim_player.has_animation("Volar fantasma copete"), "Debe tener animación Volar fantasma copete")
			assert_true(cabeza.anim_player.has_animation("Parar fantasma copete"), "Debe tener animación Parar fantasma copete")
	assert_true(taxi.nodo_ojos.visible, "Los ojos deben mostrarse en el exterior al poseer")
	var op = taxi.nodo_ojos as OjosPosesion
	assert_ne(op, null, "nodo_ojos debe ser OjosPosesion")
	var izq = op.ojo_izquierdo
	var der = op.ojo_derecho
	assert_ne(izq, null, "Debe tener ojo_izquierdo")
	assert_ne(der, null, "Debe tener ojo_derecho")
	assert_gt(izq.get_child_count(), 0, "ojo_izquierdo debe tener malla")
	assert_gt(der.get_child_count(), 0, "ojo_derecho debe tener malla")
	assert_true(izq.visible, "ojo_izquierdo debe ser visible")
	assert_true(der.visible, "ojo_derecho debe ser visible")
	# Imprimir posiciones en fallo para diagnóstico
	var dist_ojos = izq.position.distance_to(der.position)
	assert_true(dist_ojos >= 0.70, "La distancia entre ojos debe ser adecuada (mínimo 0.70m), actual: " + str(dist_ojos) + " izq: " + str(izq.position) + " der: " + str(der.position))
	assert_true(absf(taxi.nodo_ojos.rotation.x) < 0.02, "Los ojos deben estar erguidos y sin inclinación vertical (pitch 0)")
	assert_true(taxi.nodo_ojos.position.z < 0.0 and taxi.nodo_ojos.position.z >= -(taxi.largo * 0.65), "Los ojos deben posicionarse adaptados a la superficie frontal de la roca")
	assert_true(taxi.nodo_ojos.position.y >= taxi.altura_superficie - 0.55, "Los ojos deben situarse en la cara frontal vertical de la roca")
	
	# Probar ocultamiento y restauración de material al desposeer
	taxi.terminar_posesion()
	assert_false(taxi.esta_poseido, "Debe desposeerse correctamente")
	var mat_actual = taxi.get_node("MeshInstance3D").get_surface_override_material(0)
	assert_true(mat_actual != IslaFlotante.MAT_ISLA_ESPECTRAL_POSEIDA, "Al desposeer debe restaurar el material normal de la roca")
