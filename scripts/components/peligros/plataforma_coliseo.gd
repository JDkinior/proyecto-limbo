@tool
extends AnimatableBody3D
class_name PlataformaColiseo

## ==============================================================================
## PEQUEÑA ISLA FLOTANTE DEL COLISEO (PROYECTO LIMBO)
## Utiliza instancias reales de IslaFlotante (rocosa pequeña con satélites)
## montadas sobre un AnimatableBody3D sincronizado con física para elevarse,
## oscilar en Fases 2-3, agrietarse, romperse y regenerarse en nuevas posiciones.
## ==============================================================================

signal plataforma_elevada
signal plataforma_descendida
signal plataforma_agrietandose(isla: PlataformaColiseo)
signal plataforma_destruida(isla: PlataformaColiseo)
signal plataforma_regenerada(isla: PlataformaColiseo)

enum EstadoIsla {
	OCULTA,
	ACTIVA,
	AGRIETANDOSE,
	DESTRUIDA,
	REGENERANDO
}

const ESCENA_ISLA_FLOTANTE: PackedScene = preload("res://scenes/entorno/isla_flotante.tscn")

@export_group("Elevación del Coliseo")
## Altura en metros que asciende la superficie superior sobre el nivel base del suelo.
@export_range(0.5, 12.0, 0.05) var altura_elevada: float = 1.65
## Radio de la pequeña isla transitable en metros.
@export_range(0.8, 4.0, 0.1) var radio_plataforma: float = 1.2:
	set(valor):
		radio_plataforma = valor
		if is_inside_tree():
			_reconstruir_geometria()
## Parámetro heredado mantenido por compatibilidad de escenas (las islas ahora son flotantes).
@export_range(2.0, 14.0, 0.25) var altura_columna: float = 7.5
## Retardo escalonado antes de empezar a subir al iniciar la pelea.
@export_range(0.0, 3.0, 0.05) var retardo_elevacion: float = 0.0
## Duración en segundos de la subida de la isla.
@export_range(0.2, 4.0, 0.05) var duracion_elevacion: float = 1.15
## Si es verdadero, en el editor se previsualiza en su altura elevada para facilitar el diseño.
@export var previsualizar_elevada_en_editor: bool = false:
	set(valor):
		previsualizar_elevada_en_editor = valor
		if Engine.is_editor_hint() and is_inside_tree():
			_actualizar_preview_editor()

var esta_elevada: bool = false
var estado_isla: EstadoIsla = EstadoIsla.OCULTA
var oscilacion_vertical_activa: bool = false
var amplitud_oscilacion: float = 0.0
var velocidad_oscilacion: float = 1.6
var fase_oscilacion: float = 0.0
@export var amplitud_levitacion_base: float = 0.14
@export var velocidad_levitacion_base: float = 1.45
@export var hundimiento_impacto_max: float = 0.28
@export var hundimiento_reposo_peso: float = 0.08

var _pos_base_local: Vector3 = Vector3.ZERO
var _pos_base_capturada: bool = false
var _tween_mov: Tween = null
var _mat_alerta_overlay: StandardMaterial3D = null

var _timer_ruptura: float = 0.0
var _duracion_aviso_ruptura: float = 1.25
var _objetivo_marcado_boss: bool = false
var _tiempo_isla: float = 0.0
var _isla_visual: IslaFlotante = null
var _mesh_isla: MeshInstance3D = null
var _profundidad_roca_actual: float = 1.05
var _hundimiento_peso: float = 0.0
var _velocidad_hundimiento: float = 0.0
var _tenia_jugador_encima: bool = false

@onready var mesh_capitel: MeshInstance3D = get_node_or_null("Visual/Capitel")
@onready var mesh_fuste: MeshInstance3D = get_node_or_null("Visual/Fuste")
@onready var mesh_aro: MeshInstance3D = get_node_or_null("Visual/AroRunico")
@onready var colision: CollisionShape3D = get_node_or_null("CollisionShape3D")
@onready var particulas_polvo: CPUParticles3D = get_node_or_null("ParticulasPolvo")

func _ready() -> void:
	sync_to_physics = true
	collision_layer = 1 # Capa 1: Estructura global (sólida para Vivo y Fantasma)
	collision_mask = 0
	add_to_group("plataformas_coliseo")

	_asegurar_nodos()
	_reconstruir_geometria()

	if Engine.is_editor_hint():
		_actualizar_preview_editor()
	else:
		_pos_base_local = position
		_pos_base_capturada = true
		var visual := get_node_or_null("Visual") as Node3D
		if is_instance_valid(visual):
			visual.position = Vector3.ZERO
			visual.scale = Vector3.ONE
			visual.visible = false
		esta_elevada = false
		estado_isla = EstadoIsla.OCULTA
		_aplicar_colision_activa(false)
		_aplicar_alerta_visual(0.0)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	procesar_isla(delta)

func procesar_isla(delta: float) -> void:
	_tiempo_isla += delta
	var visual := get_node_or_null("Visual") as Node3D

	# 1. Fase de agrietamiento previo a la destrucción
	if estado_isla == EstadoIsla.AGRIETANDOSE:
		_timer_ruptura = maxf(_timer_ruptura - delta, 0.0)
		var progreso := 1.0 - clampf(_timer_ruptura / maxf(_duracion_aviso_ruptura, 0.01), 0.0, 1.0)
		if is_instance_valid(visual):
			var amp_shake := lerpf(0.04, 0.16, progreso)
			visual.position = Vector3(
				sin(_tiempo_isla * 55.0) * amp_shake,
				cos(_tiempo_isla * 68.0) * amp_shake * 0.45,
				cos(_tiempo_isla * 49.0) * amp_shake
			)
		var pulso_alerta := 0.5 + 0.5 * sin(_tiempo_isla * lerpf(12.0, 28.0, progreso))
		_aplicar_alerta_visual(lerpf(0.32, 0.68, pulso_alerta))

		if _timer_ruptura <= 0.0:
			_destruir_isla()
		return

	# 2. Pulsación sutil mientras el Boss prepara el puñetazo hacia esta isla
	if _objetivo_marcado_boss and estado_isla == EstadoIsla.ACTIVA:
		if is_instance_valid(visual):
			visual.position = Vector3(sin(_tiempo_isla * 34.0) * 0.035, 0.0, cos(_tiempo_isla * 29.0) * 0.035)
		_aplicar_alerta_visual(0.16 + 0.14 * (0.5 + 0.5 * sin(_tiempo_isla * 12.0)))

	# 3. Levitación constante desde el inicio + oscilación ampliada en Fases 2 y 3 + hundimiento al saltar encima
	_actualizar_hundimiento_peso(delta)
	var tween_activo: bool = _tween_mov != null and _tween_mov.is_valid()
	if estado_isla == EstadoIsla.ACTIVA and esta_elevada and not tween_activo:
		var amp_actual: float = amplitud_oscilacion if oscilacion_vertical_activa else amplitud_levitacion_base
		var vel_actual: float = velocidad_oscilacion if oscilacion_vertical_activa else velocidad_levitacion_base
		var offset_bob := sin(_tiempo_isla * vel_actual + fase_oscilacion) * amp_actual
		var y_min_segura := _pos_base_local.y + _profundidad_roca_actual + 0.14
		position.y = maxf(_pos_base_local.y + altura_elevada + offset_bob - _hundimiento_peso, y_min_segura)
		if is_instance_valid(visual) and not _objetivo_marcado_boss:
			visual.rotation = Vector3(
				sin(_tiempo_isla * (vel_actual * 0.85) + fase_oscilacion) * 0.022,
				0.0,
				cos(_tiempo_isla * (vel_actual * 0.75) + fase_oscilacion) * 0.022
			)

func registrar_impacto_peso(intensidad: float = 1.0) -> void:
	var fuerza := clampf(intensidad, 0.25, 2.2)
	_velocidad_hundimiento = maxf(_velocidad_hundimiento, 1.95 * fuerza)
	_hundimiento_peso = clampf(maxf(_hundimiento_peso, 0.06 * fuerza), 0.0, hundimiento_impacto_max)

func obtener_hundimiento_peso() -> float:
	return _hundimiento_peso

func _actualizar_hundimiento_peso(delta: float) -> void:
	if estado_isla != EstadoIsla.ACTIVA or not esta_elevada:
		_hundimiento_peso = move_toward(_hundimiento_peso, 0.0, delta * 1.5)
		_velocidad_hundimiento = 0.0
		_tenia_jugador_encima = false
		return

	var jugador_encima: Node3D = _detectar_personaje_encima()
	var hay_jugador := is_instance_valid(jugador_encima)
	if hay_jugador and not _tenia_jugador_encima:
		var factor_caida: float = 1.0
		if "velocity" in jugador_encima:
			var vel_y: float = float(jugador_encima.get("velocity").y)
			if vel_y < -0.5:
				factor_caida = clampf(absf(vel_y) / 6.5, 0.85, 1.75)
		registrar_impacto_peso(factor_caida)
	_tenia_jugador_encima = hay_jugador

	var meta_reposo: float = hundimiento_reposo_peso if hay_jugador else 0.0
	var rigidez: float = 34.0
	var amortiguacion: float = 8.5
	var aceleracion: float = (meta_reposo - _hundimiento_peso) * rigidez - _velocidad_hundimiento * amortiguacion
	_velocidad_hundimiento += aceleracion * delta
	_hundimiento_peso = clampf(_hundimiento_peso + _velocidad_hundimiento * delta, 0.0, hundimiento_impacto_max)
	if absf(_hundimiento_peso - meta_reposo) < 0.002 and absf(_velocidad_hundimiento) < 0.01:
		_hundimiento_peso = meta_reposo
		_velocidad_hundimiento = 0.0

func _detectar_personaje_encima() -> Node3D:
	if not is_inside_tree():
		return null
	var arbol := get_tree()
	if arbol == null:
		return null
	for grupo in ["jugadores", "fantasmas"]:
		for nodo in arbol.get_nodes_in_group(grupo):
			if nodo is Node3D and is_instance_valid(nodo):
				var n3d := nodo as Node3D
				if contiene_jugador_encima(n3d):
					return n3d
	return null

func _asegurar_nodos() -> void:
	var visual := get_node_or_null("Visual") as Node3D
	if visual == null:
		visual = Node3D.new()
		visual.name = "Visual"
		add_child(visual)

	if not is_instance_valid(mesh_capitel):
		mesh_capitel = visual.get_node_or_null("Capitel") as MeshInstance3D
	if not is_instance_valid(mesh_fuste):
		mesh_fuste = visual.get_node_or_null("Fuste") as MeshInstance3D
	if not is_instance_valid(mesh_aro):
		mesh_aro = visual.get_node_or_null("AroRunico") as MeshInstance3D

	# Limpiar y ocultar mallas heredadas de la versión de columna/toro
	for m_ant in [mesh_capitel, mesh_fuste, mesh_aro]:
		if is_instance_valid(m_ant):
			m_ant.visible = false
			m_ant.mesh = null

	if not is_instance_valid(_isla_visual):
		_isla_visual = visual.get_node_or_null("IslaVisual") as IslaFlotante
	if not is_instance_valid(_isla_visual) and ESCENA_ISLA_FLOTANTE != null:
		_isla_visual = ESCENA_ISLA_FLOTANTE.instantiate() as IslaFlotante
		if is_instance_valid(_isla_visual):
			_isla_visual.name = "IslaVisual"
			_configurar_parametros_isla_visual(_isla_visual)
			visual.add_child(_isla_visual)

	if not is_instance_valid(colision):
		colision = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not is_instance_valid(colision):
		colision = CollisionShape3D.new()
		colision.name = "CollisionShape3D"
		add_child(colision)

	if not is_instance_valid(particulas_polvo):
		particulas_polvo = get_node_or_null("ParticulasPolvo") as CPUParticles3D

func _configurar_parametros_isla_visual(isla: IslaFlotante) -> void:
	isla.preset = IslaFlotante.PresetTamano.PERSONALIZADA
	isla.tipo_comportamiento = IslaFlotante.TipoComportamiento.ESTANDAR
	isla.ancho = maxf(radio_plataforma * 1.85, 2.0)
	isla.largo = maxf(radio_plataforma * 1.85, 2.0)
	var prof_objetivo := clampf(minf(radio_plataforma * 0.85, maxf(altura_elevada - 0.55, 0.72)), 0.72, 1.10)
	isla.profundidad_roca = maxf(prof_objetivo, 1.0)
	var escala_y := clampf(prof_objetivo / maxf(isla.profundidad_roca * 1.08, 1.0), 0.68, 1.0)
	_profundidad_roca_actual = isla.profundidad_roca * 1.08 * escala_y
	isla.irregularidad_contorno = 0.20
	isla.segmentos_perimetro = 16
	isla.anillos_roca = 4
	isla.anillos_superficie = 2
	isla.intensidad_variacion = 0.30
	isla.altura_superficie = 0.0
	isla.variacion_superficie = 0.03
	isla.cantidad_picos_rocosos = 1
	isla.dispersion_picos = 0.20
	isla.generar_rocas_satelite = false
	isla.cantidad_rocas_satelite = 0
	isla.generar_pasto = false
	isla.pasto_distancia = false
	isla.generar_decoracion = false
	isla.semilla = 9001 + absi(int(round(altura_elevada * 100.0))) + absi(name.hash())
	isla.position = Vector3.ZERO
	isla.scale = Vector3(1.0, escala_y, 1.0)

func _reconstruir_geometria() -> void:
	_asegurar_nodos()

	if is_instance_valid(_isla_visual):
		_configurar_parametros_isla_visual(_isla_visual)
		_isla_visual._regeneracion_pendiente = false
		_isla_visual.regenerar()

		_mesh_isla = _isla_visual.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if is_instance_valid(_mesh_isla):
			_mesh_isla.layers = 1
			_mesh_isla.material_overlay = null

		_desactivar_colision_isla_visual()
		if is_inside_tree():
			_desactivar_colision_isla_visual.call_deferred()

	# Colisión única sobre el AnimatableBody3D (cubre la losa transitable sin sobresalir por debajo)
	var col_shape := CylinderShape3D.new()
	col_shape.radius = radio_plataforma * 0.94
	col_shape.height = 0.65
	colision.shape = col_shape
	colision.position = Vector3(0.0, -0.325, 0.0)

	if is_instance_valid(particulas_polvo):
		particulas_polvo.emission_ring_radius = radio_plataforma * 0.95
		particulas_polvo.emission_ring_inner_radius = radio_plataforma * 0.45

func obtener_profundidad_roca() -> float:
	return _profundidad_roca_actual

func _desactivar_colision_isla_visual() -> void:
	if not is_instance_valid(_isla_visual):
		return
	_isla_visual.collision_layer = 0
	_isla_visual.collision_mask = 0
	if _isla_visual.is_in_group("islas"):
		_isla_visual.remove_from_group("islas")
	var col_interna := _isla_visual.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if is_instance_valid(col_interna):
		if is_inside_tree():
			col_interna.set_deferred("disabled", true)
		else:
			col_interna.disabled = true
	if is_instance_valid(_mesh_isla):
		_mesh_isla.layers = 1

func _actualizar_preview_editor() -> void:
	var visual := get_node_or_null("Visual") as Node3D
	if not is_instance_valid(visual):
		return
	var offset_y: float = altura_elevada if previsualizar_elevada_en_editor else 0.0
	visual.position = Vector3(0.0, offset_y, 0.0)
	_aplicar_alerta_visual(0.0)

func _aplicar_alerta_visual(intensidad: float) -> void:
	if not is_instance_valid(_mesh_isla) and is_instance_valid(_isla_visual):
		_mesh_isla = _isla_visual.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not is_instance_valid(_mesh_isla):
		return

	if intensidad <= 0.001:
		_mesh_isla.material_overlay = null
		return

	if _mat_alerta_overlay == null:
		_mat_alerta_overlay = StandardMaterial3D.new()
		_mat_alerta_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_alerta_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_alerta_overlay.emission_enabled = true
	var a := clampf(intensidad, 0.0, 0.78)
	_mat_alerta_overlay.albedo_color = Color(1.0, 0.22, 0.08, a)
	_mat_alerta_overlay.emission = Color(1.0, 0.20, 0.05, 1.0)
	_mat_alerta_overlay.emission_energy_multiplier = 1.6
	_mesh_isla.material_overlay = _mat_alerta_overlay

func _aplicar_colision_activa(activa: bool) -> void:
	collision_layer = 1 if activa else 0
	if is_instance_valid(colision):
		if is_inside_tree():
			colision.set_deferred("disabled", not activa)
		else:
			colision.disabled = not activa
	_desactivar_colision_isla_visual()

func obtener_posicion_base() -> Vector3:
	return _pos_base_local if _pos_base_capturada else position

func obtener_posicion_elevada() -> Vector3:
	var base := obtener_posicion_base()
	return Vector3(base.x, base.y + altura_elevada, base.z)

func esta_disponible() -> bool:
	return estado_isla == EstadoIsla.ACTIVA and esta_elevada

func esta_agrietandose() -> bool:
	return estado_isla == EstadoIsla.AGRIETANDOSE

func esta_destruida() -> bool:
	return estado_isla == EstadoIsla.DESTRUIDA

func configurar_oscilacion(activa: bool, amplitud: float, velocidad: float, fase: float = 0.0) -> void:
	oscilacion_vertical_activa = activa
	amplitud_oscilacion = amplitud
	velocidad_oscilacion = velocidad
	fase_oscilacion = fase
	if not activa and esta_elevada and estado_isla == EstadoIsla.ACTIVA:
		if _tween_mov == null or not _tween_mov.is_valid():
			position.y = _pos_base_local.y + altura_elevada

func contiene_jugador_encima(jugador: Node3D) -> bool:
	if not is_instance_valid(jugador):
		return false
	if not esta_disponible() and not esta_agrietandose():
		return false
	var pos_j := jugador.global_position if (jugador.is_inside_tree() and is_inside_tree()) else jugador.position
	var pos_i := global_position if (is_inside_tree() and jugador.is_inside_tree()) else position
	var dist_xz := Vector2(pos_j.x - pos_i.x, pos_j.z - pos_i.z).length()
	if dist_xz > (radio_plataforma + 0.58):
		return false
	return pos_j.y >= (pos_i.y - 0.65) and pos_j.y <= (pos_i.y + 2.35)

func marcar_objetivo_boss(activo: bool) -> void:
	_objetivo_marcado_boss = activo
	if not activo and estado_isla == EstadoIsla.ACTIVA:
		var visual := get_node_or_null("Visual") as Node3D
		if is_instance_valid(visual):
			visual.position = Vector3.ZERO
		_aplicar_alerta_visual(0.0)

func iniciar_ruptura(duracion_aviso: float = 1.25) -> bool:
	if estado_isla != EstadoIsla.ACTIVA or not esta_elevada:
		return false
	_objetivo_marcado_boss = false
	estado_isla = EstadoIsla.AGRIETANDOSE
	_duracion_aviso_ruptura = maxf(duracion_aviso, 0.15)
	_timer_ruptura = _duracion_aviso_ruptura
	_aplicar_alerta_visual(0.45)
	if is_inside_tree() and is_instance_valid(particulas_polvo):
		particulas_polvo.restart()
		particulas_polvo.emitting = true
	plataforma_agrietandose.emit(self)
	return true

func cancelar_ruptura() -> void:
	var estaba_marcada := _objetivo_marcado_boss
	_objetivo_marcado_boss = false
	if estado_isla == EstadoIsla.AGRIETANDOSE or estaba_marcada:
		_timer_ruptura = 0.0
		if estado_isla == EstadoIsla.AGRIETANDOSE:
			estado_isla = EstadoIsla.ACTIVA
		var visual := get_node_or_null("Visual") as Node3D
		if is_instance_valid(visual):
			visual.position = Vector3.ZERO
		_aplicar_alerta_visual(0.0)

func destruir_inmediatamente(dir_impacto: Vector3 = Vector3.ZERO) -> bool:
	if estado_isla == EstadoIsla.DESTRUIDA or estado_isla == EstadoIsla.OCULTA:
		return false
	_destruir_isla(dir_impacto)
	return true

func _destruir_isla(dir_impacto: Vector3 = Vector3.ZERO) -> void:
	estado_isla = EstadoIsla.DESTRUIDA
	_objetivo_marcado_boss = false
	_timer_ruptura = 0.0
	if _tween_mov != null and _tween_mov.is_valid():
		_tween_mov.kill()
	_tween_mov = null

	_aplicar_colision_activa(false)
	var visual := get_node_or_null("Visual") as Node3D
	if is_instance_valid(visual):
		visual.position = Vector3.ZERO
		visual.visible = false
	_aplicar_alerta_visual(0.0)

	if is_inside_tree():
		_emitir_explosion_fragmentos(dir_impacto)

	plataforma_destruida.emit(self)

func regenerar_en_posicion(nueva_pos_base_local: Vector3, animado: bool = true) -> void:
	if _tween_mov != null and _tween_mov.is_valid():
		_tween_mov.kill()
	_tween_mov = null
	_pos_base_local = nueva_pos_base_local
	_pos_base_capturada = true
	_objetivo_marcado_boss = false
	_timer_ruptura = 0.0
	_tiempo_isla = 0.0
	esta_elevada = true

	if is_instance_valid(_isla_visual):
		_isla_visual.rotation.y = randf_range(0.0, TAU)

	var destino := obtener_posicion_elevada()
	_aplicar_colision_activa(true)
	_aplicar_alerta_visual(0.0)

	var visual := get_node_or_null("Visual") as Node3D
	if not animado or not is_inside_tree():
		position = destino
		if is_instance_valid(visual):
			visual.position = Vector3.ZERO
			visual.scale = Vector3.ONE
			visual.visible = true
		estado_isla = EstadoIsla.ACTIVA
		plataforma_regenerada.emit(self)
		return

	estado_isla = EstadoIsla.REGENERANDO
	position = destino - Vector3(0.0, 0.85, 0.0)
	if is_instance_valid(visual):
		visual.position = Vector3.ZERO
		visual.scale = Vector3(0.08, 0.08, 0.08)
		visual.visible = true
	_emitir_particulas_regeneracion(destino)

	_tween_mov = create_tween()
	_tween_mov.tween_property(self, "position", destino, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(visual):
		_tween_mov.parallel().tween_property(visual, "scale", Vector3.ONE, 0.52).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_mov.tween_callback(func():
		_tween_mov = null
		_tiempo_isla = 0.0
		estado_isla = EstadoIsla.ACTIVA
		plataforma_regenerada.emit(self)
	)

func reubicar_suavemente(nueva_pos_base_local: Vector3, duracion: float = 0.85, animado: bool = true) -> void:
	if estado_isla == EstadoIsla.DESTRUIDA:
		regenerar_en_posicion(nueva_pos_base_local, animado)
		return
	cancelar_ruptura()
	if _tween_mov != null and _tween_mov.is_valid():
		_tween_mov.kill()
	_tween_mov = null

	_pos_base_local = nueva_pos_base_local
	_pos_base_capturada = true
	var destino := obtener_posicion_elevada()
	_aplicar_colision_activa(true)

	var visual := get_node_or_null("Visual") as Node3D
	if is_instance_valid(visual):
		visual.position = Vector3.ZERO
		visual.scale = Vector3.ONE
		visual.visible = true

	if not animado or not is_inside_tree():
		position = destino
		if esta_elevada:
			estado_isla = EstadoIsla.ACTIVA
		return

	_tween_mov = create_tween()
	_tween_mov.tween_property(self, "position", destino, maxf(duracion, 0.2)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_mov.tween_callback(func():
		_tween_mov = null
	)

func elevar(animado: bool = true) -> void:
	if not _pos_base_capturada:
		_pos_base_local = position
		_pos_base_capturada = true
	if _tween_mov != null and _tween_mov.is_valid():
		_tween_mov.kill()
	_tween_mov = null

	var destino := obtener_posicion_elevada()
	esta_elevada = true
	_objetivo_marcado_boss = false
	_timer_ruptura = 0.0
	_tiempo_isla = 0.0
	_hundimiento_peso = 0.0
	_velocidad_hundimiento = 0.0
	_tenia_jugador_encima = false
	_aplicar_colision_activa(true)
	_aplicar_alerta_visual(0.0)

	var visual := get_node_or_null("Visual") as Node3D
	if is_instance_valid(visual):
		visual.position = Vector3.ZERO
		visual.scale = Vector3.ONE
		visual.visible = true

	if not animado or not is_inside_tree():
		position = destino
		estado_isla = EstadoIsla.ACTIVA
		plataforma_elevada.emit()
		return

	estado_isla = EstadoIsla.REGENERANDO
	var y_inicio_segura := maxf(_pos_base_local.y + _profundidad_roca_actual + 0.14, destino.y - 0.85)
	position = Vector3(destino.x, minf(y_inicio_segura, destino.y), destino.z)
	if is_instance_valid(visual):
		visual.scale = Vector3(0.12, 0.12, 0.12)
	_tween_mov = create_tween()
	if retardo_elevacion > 0.0:
		_tween_mov.tween_interval(retardo_elevacion)
	_tween_mov.tween_callback(func():
		if is_instance_valid(particulas_polvo):
			particulas_polvo.restart()
			particulas_polvo.emitting = true
	)
	_tween_mov.tween_property(self, "position", destino, duracion_elevacion).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(visual):
		_tween_mov.parallel().tween_property(visual, "scale", Vector3.ONE, duracion_elevacion * 0.85).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_mov.tween_callback(func():
		_tween_mov = null
		_tiempo_isla = 0.0
		estado_isla = EstadoIsla.ACTIVA
		plataforma_elevada.emit()
	)

func descender(animado: bool = true) -> void:
	if not _pos_base_capturada:
		_pos_base_local = position
		_pos_base_capturada = true
	if _tween_mov != null and _tween_mov.is_valid():
		_tween_mov.kill()
	_tween_mov = null

	cancelar_ruptura()
	oscilacion_vertical_activa = false
	amplitud_oscilacion = 0.0
	var destino := obtener_posicion_base()
	esta_elevada = false

	var visual := get_node_or_null("Visual") as Node3D
	_aplicar_alerta_visual(0.0)

	if not animado or not is_inside_tree():
		position = destino
		if is_instance_valid(visual):
			visual.position = Vector3.ZERO
			visual.scale = Vector3.ONE
			visual.visible = false
		_aplicar_colision_activa(false)
		estado_isla = EstadoIsla.OCULTA
		plataforma_descendida.emit()
		return

	_tween_mov = create_tween()
	if retardo_elevacion > 0.0:
		_tween_mov.tween_interval(retardo_elevacion * 0.4)
	_tween_mov.tween_property(self, "position", destino, duracion_elevacion * 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if is_instance_valid(visual):
		_tween_mov.parallel().tween_property(visual, "scale", Vector3(0.05, 0.05, 0.05), duracion_elevacion * 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween_mov.tween_callback(func():
		_tween_mov = null
		if is_instance_valid(visual):
			visual.position = Vector3.ZERO
			visual.scale = Vector3.ONE
			visual.visible = false
		_aplicar_colision_activa(false)
		estado_isla = EstadoIsla.OCULTA
		plataforma_descendida.emit()
	)

func _emitir_explosion_fragmentos(dir_impacto: Vector3 = Vector3.ZERO) -> void:
	var padre := get_parent()
	if not is_instance_valid(padre):
		return

	var dir_frag := Vector3.UP
	var dir_polvo := Vector3.UP
	if dir_impacto.length_squared() > 0.01:
		var dir_h := Vector3(dir_impacto.x, 0.0, dir_impacto.z)
		if dir_h.length_squared() > 0.01:
			dir_h = dir_h.normalized()
			dir_frag = (dir_h * 0.85 + Vector3(0.0, 0.55, 0.0)).normalized()
			dir_polvo = (dir_h * 0.5 + Vector3(0.0, 0.45, 0.0)).normalized()

	# 1. Fragmentos de roca lanzados en la dirección del golpe lateral
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 34
	p.lifetime = 0.95
	p.explosiveness = 0.96
	p.layers = 1 | 4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radio_plataforma * 0.72
	p.direction = dir_frag
	p.spread = 65.0
	p.initial_velocity_min = 4.2
	p.initial_velocity_max = 9.2
	p.gravity = Vector3(0.0, -15.0, 0.0)
	p.angular_velocity_min = -240.0
	p.angular_velocity_max = 240.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.45

	var c_frag := Curve.new()
	c_frag.add_point(Vector2(0.0, 1.0))
	c_frag.add_point(Vector2(0.7, 0.85))
	c_frag.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = c_frag

	var malla := BoxMesh.new()
	malla.size = Vector3(0.22, 0.18, 0.20)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.58, 0.50, 0.44, 1.0)
	mat.roughness = 0.85
	malla.material = mat
	p.mesh = malla

	padre.add_child(p)
	p.position = position + Vector3(0.0, -0.18, 0.0)
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.2, true, false, true).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free()
	)

	# 2. Nube instantánea de polvo/desintegración
	var p_polvo := CPUParticles3D.new()
	p_polvo.one_shot = true
	p_polvo.emitting = false
	p_polvo.amount = 24
	p_polvo.lifetime = 0.75
	p_polvo.explosiveness = 0.95
	p_polvo.layers = 1 | 4
	p_polvo.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p_polvo.emission_sphere_radius = radio_plataforma * 0.82
	p_polvo.direction = dir_polvo
	p_polvo.spread = 80.0
	p_polvo.initial_velocity_min = 1.8
	p_polvo.initial_velocity_max = 4.8
	p_polvo.gravity = Vector3(0.0, 0.6, 0.0)
	p_polvo.damping_min = 2.0
	p_polvo.damping_max = 3.8
	p_polvo.scale_amount_min = 0.9
	p_polvo.scale_amount_max = 1.8

	var c_polvo := Curve.new()
	c_polvo.add_point(Vector2(0.0, 0.5))
	c_polvo.add_point(Vector2(0.25, 1.15))
	c_polvo.add_point(Vector2(1.0, 0.0))
	p_polvo.scale_amount_curve = c_polvo

	var g_polvo := Gradient.new()
	g_polvo.colors = PackedColorArray([Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.65), Color(1, 1, 1, 0.0)])
	g_polvo.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	p_polvo.color_ramp = g_polvo

	var malla_polvo := SphereMesh.new()
	malla_polvo.radius = 0.16
	malla_polvo.height = 0.32
	malla_polvo.radial_segments = 6
	malla_polvo.rings = 3
	var mat_polvo := StandardMaterial3D.new()
	mat_polvo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_polvo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_polvo.vertex_color_use_as_albedo = true
	mat_polvo.albedo_color = Color(0.90, 0.80, 0.65, 0.85)
	malla_polvo.material = mat_polvo
	p_polvo.mesh = malla_polvo

	padre.add_child(p_polvo)
	p_polvo.position = position + Vector3(0.0, -0.1, 0.0)
	p_polvo.emitting = true
	get_tree().create_timer(p_polvo.lifetime + 0.2, true, false, true).timeout.connect(func():
		if is_instance_valid(p_polvo):
			p_polvo.queue_free()
	)

func _emitir_particulas_regeneracion(pos_local: Vector3) -> void:
	var padre := get_parent()
	if not is_instance_valid(padre):
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 18
	p.lifetime = 0.85
	p.explosiveness = 0.85
	p.layers = 1 | 4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_height = 0.2
	p.emission_ring_radius = radio_plataforma
	p.emission_ring_inner_radius = radio_plataforma * 0.4
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0.0, 1.4, 0.0)
	p.initial_velocity_min = 1.1
	p.initial_velocity_max = 2.6

	var malla := SphereMesh.new()
	malla.radius = 0.09
	malla.height = 0.18
	malla.radial_segments = 6
	malla.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.98, 0.78, 0.34, 0.9)
	malla.material = mat
	p.mesh = malla

	padre.add_child(p)
	p.position = pos_local + Vector3(0.0, -0.35, 0.0)
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.2, true, false, true).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free()
	)
