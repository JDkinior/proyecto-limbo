@tool
extends EditorPlugin

## ==============================================================================
## PLUGIN: PINCEL DE PASTO 3D (GODOT 4)
## Permite pintar y borrar pasto en tiempo real sobre cualquier superficie
## o MeshInstance3D con formas geométricas (Círculo, Cuadrado, Triángulo),
## filtrado inteligente de objetos y detección estricta de bordes sin vacío.
## ==============================================================================

var _nodo_pasto: Node = null
var _pintando: bool = false
var _borrando: bool = false
var _ultima_pos_pintada: Vector3 = Vector3.INF

# ==============================================================================
# CONFIGURACIÓN Y PRESETS DE PINCELES PERSONALIZABLES
# ==============================================================================

const RUTA_PINCELES_JSON = "res://addons/pincel-pasto/pinceles.json"

const PINCELES_PREDETERMINADOS = {
	"🌱 Césped Suave": {"radio": 1.5, "densidad": 25, "forma": 0},
	"🌿 Pradera Densa": {"radio": 2.2, "densidad": 200, "forma": 0},
	"🌾 Pasto Silvestre": {"radio": 2.8, "densidad": 60, "forma": 0},
	"🍃 Detalle Fino": {"radio": 0.7, "densidad": 120, "forma": 0},
	"🚜 Relleno Masivo": {"radio": 6.0, "densidad": 500, "forma": 0},
	"🍩 Corona Perimetral": {"radio": 2.0, "densidad": 180, "forma": 3},
	"➖ Sendero / Borde": {"radio": 1.2, "densidad": 150, "forma": 4}
}

var _pinceles_personalizados: Dictionary = {}

# Control de trazo para Deshacer / Rehacer (Ctrl+Z)
var _trazo_en_curso: bool = false
var _datos_antes_del_trazo: Array[Transform3D] = []
var _modo_antes_del_trazo: int = 0
var _era_borrado: bool = false

# Barra de herramientas en el encabezado del visor 3D (ultra-compacta)
var _toolbar: HBoxContainer = null
var _btn_activar_pincel: Button = null
var _opt_pincel: OptionButton = null
var _btn_ajustes: Button = null

# Menú flotante / Panel de configuración detallada del pincel
var _popup_ajustes: PopupPanel = null
var _opt_forma: OptionButton = null
var _spin_radio: SpinBox = null
var _slider_radio: HSlider = null
var _spin_densidad: SpinBox = null
var _slider_densidad: HSlider = null
var _chk_no_repintar: CheckBox = null
var _btn_guardar_pincel: Button = null
var _btn_borrar_pincel: Button = null
var _btn_limpiar: Button = null

# Diálogo para guardar nuevo preset
var _dialog_guardar_pincel: ConfirmationDialog = null
var _input_nombre_pincel: LineEdit = null

# Rejilla espacial para optimizar la opción "No Repintar" O(1)
var _grid_espacial: Dictionary = {}
var _grid_cell_size: float = 0.20

# Cursor visual 3D (Disco / Caja / Triángulo / Corona / Línea)
var _gizmo_cursor: MeshInstance3D = null
var _forma_actual_gizmo: int = -1

func _enter_tree() -> void:
	_cargar_pinceles_desde_disco()
	_crear_toolbar()
	_crear_gizmo_cursor()

func _exit_tree() -> void:
	if _trazo_en_curso:
		_finalizar_trazo()
	_destruir_dialogo_guardar_pincel()
	_destruir_popup_ajustes()
	_destruir_toolbar()
	_destruir_gizmo_cursor()

func _handles(object: Object) -> bool:
	if object == null:
		return false
	if object is GeneradorPasto:
		return true
	if object is Node:
		var scr = (object as Node).get_script()
		if scr != null and scr is Script and scr.resource_path.ends_with("generador_pasto.gd"):
			return true
	return false

func _edit(object: Object) -> void:
	if _trazo_en_curso:
		_finalizar_trazo()
	_nodo_pasto = object as Node
	_sincronizar_toolbar_con_nodo()
	_actualizar_forma_gizmo()
	_actualizar_visibilidad()

func _make_visible(visible: bool) -> void:
	if _toolbar != null:
		_toolbar.visible = visible
	if not visible:
		if is_instance_valid(_popup_ajustes):
			_popup_ajustes.hide()
		if _trazo_en_curso:
			_finalizar_trazo()
		_nodo_pasto = null
		_pintando = false
		_borrando = false
		_ocultar_cursor()

# ==============================================================================
# GESTIÓN DE TRAZOS Y DESHACER / REHACER (CTRL+Z)
# ==============================================================================

func _iniciar_trazo(es_borrado: bool) -> void:
	if not is_instance_valid(_nodo_pasto):
		return
	_trazo_en_curso = true
	_era_borrado = es_borrado
	if "datos_pasto_pintado" in _nodo_pasto and _nodo_pasto.datos_pasto_pintado != null:
		_datos_antes_del_trazo = _nodo_pasto.datos_pasto_pintado.duplicate()
	else:
		_datos_antes_del_trazo = []
	_modo_antes_del_trazo = _nodo_pasto.modo_distribucion if "modo_distribucion" in _nodo_pasto else 0

	if not es_borrado:
		var no_rep = false
		var dist_m = 0.0
		if is_instance_valid(_chk_no_repintar):
			no_rep = _chk_no_repintar.button_pressed
		elif "evitar_repintar" in _nodo_pasto:
			no_rep = _nodo_pasto.evitar_repintar
		if "distancia_minima_repintar" in _nodo_pasto:
			dist_m = _nodo_pasto.distancia_minima_repintar

		if dist_m <= 0.0:
			var dens = 25
			if "densidad_pincel" in _nodo_pasto:
				dens = _nodo_pasto.densidad_pincel
			dist_m = clampf(0.85 / sqrt(maxf(1.0, float(dens))), 0.02, 1.5)

		if no_rep:
			_iniciar_grid_espacial(dist_m)

func _finalizar_trazo() -> void:
	_limpiar_grid_espacial()
	if not _trazo_en_curso or not is_instance_valid(_nodo_pasto):
		_trazo_en_curso = false
		_pintando = false
		_borrando = false
		_ultima_pos_pintada = Vector3.INF
		_datos_antes_del_trazo = []
		return

	_trazo_en_curso = false
	_pintando = false
	_borrando = false
	_ultima_pos_pintada = Vector3.INF

	var datos_actuales: Array[Transform3D] = []
	if "datos_pasto_pintado" in _nodo_pasto and _nodo_pasto.datos_pasto_pintado != null:
		datos_actuales = _nodo_pasto.datos_pasto_pintado

	var cambio_datos: bool = (datos_actuales.size() != _datos_antes_del_trazo.size()) or (datos_actuales != _datos_antes_del_trazo)
	var modo_actual: int = _nodo_pasto.modo_distribucion if "modo_distribucion" in _nodo_pasto else 0
	var cambio_modo: bool = (modo_actual != _modo_antes_del_trazo)

	if cambio_datos or cambio_modo:
		var ur = get_undo_redo()
		if ur != null:
			var accion_nombre = "Borrar Pasto" if _era_borrado else "Pintar Pasto"
			ur.create_action(accion_nombre)
			if cambio_modo:
				ur.add_do_property(_nodo_pasto, "modo_distribucion", modo_actual)
				ur.add_undo_property(_nodo_pasto, "modo_distribucion", _modo_antes_del_trazo)
			ur.add_do_property(_nodo_pasto, "datos_pasto_pintado", datos_actuales.duplicate())
			ur.add_undo_property(_nodo_pasto, "datos_pasto_pintado", _datos_antes_del_trazo.duplicate())
			ur.add_do_method(_nodo_pasto, "_actualizar_multimesh_pintado")
			ur.add_undo_method(_nodo_pasto, "_actualizar_multimesh_pintado")
			ur.commit_action(false)

	_datos_antes_del_trazo = []

# ==============================================================================
# PROCESAMIENTO DE ENTRADA EN EL VISOR 3D
# ==============================================================================

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if not is_instance_valid(_nodo_pasto):
		_ocultar_cursor()
		return AFTER_GUI_INPUT_PASS

	var pincel_activo = false
	if "activar_pincel" in _nodo_pasto:
		pincel_activo = _nodo_pasto.activar_pincel

	if not pincel_activo:
		_ocultar_cursor()
		return AFTER_GUI_INPUT_PASS

	var radio: float = 1.5
	if "radio_pincel" in _nodo_pasto:
		radio = _nodo_pasto.radio_pincel

	_actualizar_forma_gizmo()

	# --- Atajos de Teclado: [ y ] para cambiar radio del pincel en tiempo real ---
	if event is InputEventKey:
		var ke = event as InputEventKey
		if ke.pressed and not ke.echo:
			if ke.keycode == KEY_BRACKETLEFT:
				var nuevo_r = maxf(0.1, radio - 0.2)
				_on_radio_changed(nuevo_r)
				return AFTER_GUI_INPUT_STOP
			elif ke.keycode == KEY_BRACKETRIGHT:
				var nuevo_r = radio + 0.2
				_on_radio_changed(nuevo_r)
				return AFTER_GUI_INPUT_STOP

	if event is InputEventMouseMotion:
		var hit = _hacer_raycast(camera, event.position)
		if not hit.is_empty():
			_posicionar_cursor(hit.position, hit.normal, radio)

			if _pintando:
				var dist = _ultima_pos_pintada.distance_to(hit.position)
				var dist_paso = clampf(radio * 0.25, 0.10, 0.60)
				if dist >= dist_paso:
					var num_pasos = clampi(int(dist / dist_paso), 1, 10)
					for s in range(1, num_pasos + 1):
						var sub_pos = _ultima_pos_pintada.lerp(hit.position, float(s) / float(num_pasos))
						var sub_hit = {"position": sub_pos, "normal": hit.normal}
						_ejecutar_pintado_con_proyeccion(camera, sub_hit, true, dist_paso)
					_ultima_pos_pintada = hit.position
				return AFTER_GUI_INPUT_STOP

			if _borrando:
				if _nodo_pasto.has_method("borrar_en_posicion"):
					_nodo_pasto.borrar_en_posicion(hit.position, radio)
				return AFTER_GUI_INPUT_STOP
		else:
			_ocultar_cursor()

	elif event is InputEventMouseButton:
		var mb = event as InputEventMouseButton

		# --- Atajos de Rueda del Ratón: Shift+Rueda (Radio) y Shift+Ctrl+Rueda (Densidad) ---
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.shift_pressed:
			if mb.ctrl_pressed:
				var cur_d = int(_spin_densidad.value) if is_instance_valid(_spin_densidad) else 25
				_on_densidad_changed(cur_d + 5)
			else:
				_on_radio_changed(radio + 0.2)
			return AFTER_GUI_INPUT_STOP
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.shift_pressed:
			if mb.ctrl_pressed:
				var cur_d = int(_spin_densidad.value) if is_instance_valid(_spin_densidad) else 25
				_on_densidad_changed(maxi(1, cur_d - 5))
			else:
				_on_radio_changed(maxf(0.1, radio - 0.2))
			return AFTER_GUI_INPUT_STOP

		var hit = _hacer_raycast(camera, mb.position)

		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.shift_pressed:
					# Shift + Clic Izquierdo = Borrar
					_iniciar_trazo(true)
					_borrando = true
					_pintando = false
					if not hit.is_empty() and _nodo_pasto.has_method("borrar_en_posicion"):
						_nodo_pasto.borrar_en_posicion(hit.position, radio)
					return AFTER_GUI_INPUT_STOP
				else:
					# Clic Izquierdo = Pintar con comprobación de superficie
					_iniciar_trazo(false)
					_pintando = true
					_borrando = false
					if not hit.is_empty():
						_ejecutar_pintado_con_proyeccion(camera, hit, false)
						_ultima_pos_pintada = hit.position
					return AFTER_GUI_INPUT_STOP
			else:
				if _trazo_en_curso:
					_finalizar_trazo()
				else:
					_pintando = false
					_borrando = false
					_ultima_pos_pintada = Vector3.INF
				return AFTER_GUI_INPUT_PASS

		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				# Clic Derecho = Borrar
				_iniciar_trazo(true)
				_borrando = true
				_pintando = false
				if not hit.is_empty() and _nodo_pasto.has_method("borrar_en_posicion"):
					_nodo_pasto.borrar_en_posicion(hit.position, radio)
				return AFTER_GUI_INPUT_STOP
			else:
				if _trazo_en_curso:
					_finalizar_trazo()
				else:
					_borrando = false
				return AFTER_GUI_INPUT_PASS

	return AFTER_GUI_INPUT_PASS

# ==============================================================================
# REJILLA ESPACIAL (SPATIAL GRID) PARA "NO REPINTAR" O(1)
# ==============================================================================

func _iniciar_grid_espacial(cell_size: float) -> void:
	_grid_espacial.clear()
	_grid_cell_size = max(0.05, cell_size)
	if not is_instance_valid(_nodo_pasto) or not ("datos_pasto_pintado" in _nodo_pasto):
		return
	var datos: Array = _nodo_pasto.datos_pasto_pintado
	if datos == null:
		return
	for t in datos:
		if t is Transform3D:
			_agregar_a_grid(t.origin)

func _agregar_a_grid(pos_local: Vector3) -> void:
	var cx = int(floor(pos_local.x / _grid_cell_size))
	var cz = int(floor(pos_local.z / _grid_cell_size))
	var key = Vector2i(cx, cz)
	if not _grid_espacial.has(key):
		_grid_espacial[key] = []
	_grid_espacial[key].append(Vector2(pos_local.x, pos_local.z))

func _posicion_ocupada_en_grid(pos_local: Vector3, dist_min_sq: float) -> bool:
	var px = pos_local.x
	var pz = pos_local.z
	var cx = int(floor(px / _grid_cell_size))
	var cz = int(floor(pz / _grid_cell_size))

	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var key = Vector2i(cx + dx, cz + dz)
			if _grid_espacial.has(key):
				var lista: Array = _grid_espacial[key]
				for p2d in lista:
					var d2 = (p2d.x - px) * (p2d.x - px) + (p2d.y - pz) * (p2d.y - pz)
					if d2 < dist_min_sq:
						return true
	return false

func _limpiar_grid_espacial() -> void:
	_grid_espacial.clear()

# ==============================================================================
# PINTADO CON PROYECCIÓN Y COMPROBACIÓN DE BORDES
# ==============================================================================

func _calcular_area_forma(forma: int, radio: float) -> float:
	var r2 = radio * radio
	match forma:
		1: # Cuadrado (lado 2r): (2r)^2 = 4 * r^2
			return 4.0 * r2
		2: # Triángulo equilátero circunscrito en r: (3*sqrt(3)/4) * r^2 ≈ 1.299038 * r^2
			return 1.299038 * r2
		3: # Corona / Anillo (r_out=r, r_in=0.5r): PI * (r^2 - 0.25r^2) = 0.75 * PI * r^2
			return 0.75 * PI * r2
		4: # Sendero / Línea (largo 2r, ancho 0.5r): 2r * 0.5r = r^2
			return r2
		_: # Círculo (radio r): PI * r^2
			return PI * r2

func _ejecutar_pintado_con_proyeccion(camera: Camera3D, hit_center: Dictionary, es_arrastre: bool = false, dist_paso: float = 0.25) -> void:
	if not is_instance_valid(_nodo_pasto):
		return

	var center_pos: Vector3 = hit_center.position
	var center_norm: Vector3 = hit_center.normal
	var radio: float = 1.5
	var densidad: int = 10
	var forma: int = 0
	var solo_nodos: Array = []
	var ignorar_interactivos: bool = true
	var collision_mask: int = 0xFFFFFFFF

	if "radio_pincel" in _nodo_pasto:
		radio = _nodo_pasto.radio_pincel
	if "densidad_pincel" in _nodo_pasto:
		densidad = _nodo_pasto.densidad_pincel
	if "forma_pincel" in _nodo_pasto:
		forma = _nodo_pasto.forma_pincel
	if "solo_pintar_en_objetos" in _nodo_pasto and _nodo_pasto.solo_pintar_en_objetos != null:
		solo_nodos = _nodo_pasto.solo_pintar_en_objetos
	if "ignorar_interactivos_y_personajes" in _nodo_pasto:
		ignorar_interactivos = _nodo_pasto.ignorar_interactivos_y_personajes
	if "capas_colision_permitidas" in _nodo_pasto and _nodo_pasto.capas_colision_permitidas > 0:
		collision_mask = _nodo_pasto.capas_colision_permitidas

	var no_repintar: bool = false
	var dist_min: float = 0.0
	if is_instance_valid(_chk_no_repintar):
		no_repintar = _chk_no_repintar.button_pressed
	elif "evitar_repintar" in _nodo_pasto:
		no_repintar = _nodo_pasto.evitar_repintar
	if "distancia_minima_repintar" in _nodo_pasto:
		dist_min = _nodo_pasto.distancia_minima_repintar

	# Si no se ha fijado una distancia manual, calcularla dinámicamente según la densidad deseada
	if dist_min <= 0.0:
		dist_min = clampf(0.85 / sqrt(maxf(1.0, float(densidad))), 0.02, 1.5)
	var dist_min_sq: float = dist_min * dist_min

	var space_state = camera.get_world_3d().direct_space_state
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	# Construir base tangencial sobre la superficie
	var up_vec = center_norm.normalized()
	var tangent = Vector3.RIGHT
	if abs(up_vec.dot(Vector3.UP)) < 0.99:
		tangent = up_vec.cross(Vector3.UP).normalized()
	else:
		tangent = up_vec.cross(Vector3.FORWARD).normalized()
	var bitangent = up_vec.cross(tangent).normalized()

	var posiciones_validas: Array[Vector3] = []
	var normales_validas: Array[Vector3] = []

	var cantidad_muestras: int = 1
	if not es_arrastre:
		# Clic único / Estampa completa: el número de briznas cubre exactamente el área total geométrica
		var area_total = _calcular_area_forma(forma, radio)
		cantidad_muestras = clampi(int(round(densidad * area_total)), 1, 30000)
	else:
		# Arrastre continuo: cada paso añade únicamente la cantidad de briznas correspondiente
		# al área nueva barrida por el pincel (largo del paso * ancho efectivo de la forma),
		# garantizando que la densidad visual sea 100% homogénea e idéntica a la del clic simple.
		var ancho_efectivo = radio * 2.0
		match forma:
			0: ancho_efectivo = radio * 1.5708 # Ancho promedio del disco circular
			2: ancho_efectivo = radio * 1.30
			3: ancho_efectivo = radio * 1.50
			4: ancho_efectivo = radio * 0.50
		var area_paso = dist_paso * ancho_efectivo
		cantidad_muestras = clampi(int(round(densidad * area_paso)), 1, 5000)

	for _i in range(cantidad_muestras):
		var offset_2d = Vector2.ZERO
		match forma:
			1: # Cuadrado
				offset_2d = Vector2(rng.randf_range(-radio, radio), rng.randf_range(-radio, radio))
			2: # Triángulo
				var w = radio * 1.73205
				var v0 = Vector2(0.0, -radio)
				var v1 = Vector2(w * 0.5, radio * 0.5)
				var v2 = Vector2(-w * 0.5, radio * 0.5)
				var u = rng.randf()
				var v = rng.randf()
				if u + v > 1.0:
					u = 1.0 - u
					v = 1.0 - v
				offset_2d = (1.0 - u - v) * v0 + u * v1 + v * v2
			3: # Corona / Anillo (radio interior = 0.5 * radio)
				var r_in_sq = 0.25 * radio * radio
				var r_out_sq = radio * radio
				var r = sqrt(rng.randf_range(r_in_sq, r_out_sq))
				var theta = rng.randf_range(0.0, TAU)
				offset_2d = Vector2(cos(theta) * r, sin(theta) * r)
			4: # Sendero / Línea (largo 2*radio, ancho 0.5*radio)
				offset_2d = Vector2(rng.randf_range(-radio, radio), rng.randf_range(-radio * 0.25, radio * 0.25))
			_: # Círculo
				var r = sqrt(rng.randf()) * radio
				var theta = rng.randf_range(0.0, TAU)
				offset_2d = Vector2(cos(theta) * r, sin(theta) * r)

		var pos_candidata = center_pos + tangent * offset_2d.x + bitangent * offset_2d.y

		# Comprobar con raycast vertical si hay suelo real bajo esta brizna
		var ray_from = pos_candidata + up_vec * 0.8
		var ray_to = pos_candidata - up_vec * 1.5
		var query = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.collision_mask = collision_mask

		var probe_hit = space_state.intersect_ray(query)
		if probe_hit.is_empty():
			# No hay superficie física sólida debajo (está en el vacío fuera del borde) -> DESCARTAR
			continue

		var col = probe_hit.collider
		if ignorar_interactivos and _es_objeto_ignorado(col):
			# Cayó encima de un farol, árbol o personaje -> DESCARTAR
			continue

		if not solo_nodos.is_empty() and not _pertenece_a_nodos_permitidos(col, solo_nodos):
			# Cayó fuera de los objetos autorizados -> DESCARTAR
			continue

		# Comprobar si ya existe pasto cerca (opción No Repintar)
		if no_repintar:
			var pos_local = _nodo_pasto.to_local(probe_hit.position)
			if _posicion_ocupada_en_grid(pos_local, dist_min_sq):
				continue
			_agregar_a_grid(pos_local)

		posiciones_validas.append(probe_hit.position)
		normales_validas.append(probe_hit.normal)

	if not posiciones_validas.is_empty():
		if _nodo_pasto.has_method("agregar_instancias_pintadas"):
			_nodo_pasto.agregar_instancias_pintadas(posiciones_validas, normales_validas)
		elif _nodo_pasto.has_method("pintar_en_posicion"):
			_nodo_pasto.pintar_en_posicion(center_pos, center_norm)

# ==============================================================================
# RAYCAST CON FILTRADO DE OBJETOS
# ==============================================================================

func _hacer_raycast(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var space_state = camera.get_world_3d().direct_space_state
	var from = camera.project_ray_origin(mouse_pos)
	var dir = camera.project_ray_normal(mouse_pos)
	var to = from + dir * 2500.0

	var solo_nodos: Array = []
	var ignorar_interactivos: bool = true
	var collision_mask: int = 0xFFFFFFFF

	if is_instance_valid(_nodo_pasto):
		if "solo_pintar_en_objetos" in _nodo_pasto and _nodo_pasto.solo_pintar_en_objetos != null:
			solo_nodos = _nodo_pasto.solo_pintar_en_objetos
		if "ignorar_interactivos_y_personajes" in _nodo_pasto:
			ignorar_interactivos = _nodo_pasto.ignorar_interactivos_y_personajes
		if "capas_colision_permitidas" in _nodo_pasto and _nodo_pasto.capas_colision_permitidas > 0:
			collision_mask = _nodo_pasto.capas_colision_permitidas

	var exclude_rids: Array[RID] = []
	var max_intentos = 10

	while max_intentos > 0:
		max_intentos -= 1
		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.collision_mask = collision_mask
		query.exclude = exclude_rids

		var result = space_state.intersect_ray(query)
		if result.is_empty():
			break

		var collider = result.collider
		var es_valido = true

		if is_instance_valid(collider):
			if ignorar_interactivos and _es_objeto_ignorado(collider):
				es_valido = false

			if es_valido and not solo_nodos.is_empty():
				if not _pertenece_a_nodos_permitidos(collider, solo_nodos):
					es_valido = false

		if es_valido:
			return result
		else:
			if is_instance_valid(collider) and "get_rid" in collider:
				exclude_rids.append(collider.get_rid())
			else:
				break

	if solo_nodos.is_empty() and is_instance_valid(_nodo_pasto) and _nodo_pasto is Node3D:
		var plano = Plane(Vector3.UP, (_nodo_pasto as Node3D).global_position.y)
		var hit_plane = plano.intersects_ray(from, dir)
		if hit_plane != null:
			return {"position": hit_plane, "normal": Vector3.UP}

	return {}

func _es_objeto_ignorado(node: Object) -> bool:
	if not (node is Node):
		return false
	var actual: Node = node as Node
	while actual != null and actual != actual.get_tree().root:
		if actual is CharacterBody3D:
			return true
		for grupo in ["vivos", "fantasmas", "personajes", "coleccionables", "interactivos", "faroles", "monedas", "botones"]:
			if actual.is_in_group(grupo):
				return true
		var n = actual.name.to_lower()
		if n.begins_with("jugador") or n.begins_with("fantasma") or n.begins_with("farol") \
		   or n.begins_with("moneda") or n.begins_with("cristal") or n.begins_with("boton") \
		   or n.begins_with("interruptor") or n.begins_with("goal") or n.begins_with("puerta") \
		   or n.begins_with("caja_empujable") or n.begins_with("arbol"):
			return true
		actual = actual.get_parent()
	return false

func _pertenece_a_nodos_permitidos(collider: Node, lista_rutas: Array) -> bool:
	var nodos_permitidos: Array[Node] = []
	for ruta in lista_rutas:
		if ruta is NodePath and not ruta.is_empty():
			var n = _nodo_pasto.get_node_or_null(ruta)
			if n == null:
				var root_scene = EditorInterface.get_edited_scene_root()
				if is_instance_valid(root_scene):
					n = root_scene.get_node_or_null(ruta)
			if n != null:
				nodos_permitidos.append(n)

	if nodos_permitidos.is_empty():
		return true

	var actual: Node = collider
	while actual != null and actual != actual.get_tree().root:
		if actual in nodos_permitidos:
			return true
		actual = actual.get_parent()

	return false

# ==============================================================================
# GESTIÓN DE PINCELES PERSONALIZADOS Y PRESETS
# ==============================================================================

func _cargar_pinceles_desde_disco() -> void:
	_pinceles_personalizados.clear()
	if FileAccess.file_exists(RUTA_PINCELES_JSON):
		var f = FileAccess.open(RUTA_PINCELES_JSON, FileAccess.READ)
		if f != null:
			var txt = f.get_as_text()
			var json = JSON.new()
			if json.parse(txt) == OK and json.data is Dictionary:
				var dict = json.data as Dictionary
				if dict.has("pinceles_personalizados") and dict["pinceles_personalizados"] is Dictionary:
					_pinceles_personalizados = dict["pinceles_personalizados"].duplicate()

func _guardar_pinceles_a_disco() -> void:
	var dict = {
		"version": 1,
		"pinceles_personalizados": _pinceles_personalizados
	}
	var f = FileAccess.open(RUTA_PINCELES_JSON, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(dict, "\t"))

func _actualizar_opciones_selector_pinceles() -> void:
	if not is_instance_valid(_opt_pincel):
		return
	_opt_pincel.clear()
	var idx = 0
	# Añadir pinceles predeterminados
	for nombre in PINCELES_PREDETERMINADOS.keys():
		_opt_pincel.add_item(nombre, idx)
		_opt_pincel.set_item_metadata(idx, {"tipo": "predeterminado", "nombre": nombre, "datos": PINCELES_PREDETERMINADOS[nombre]})
		idx += 1

	# Añadir pinceles personalizados
	for nombre in _pinceles_personalizados.keys():
		_opt_pincel.add_item("⭐ " + nombre, idx)
		_opt_pincel.set_item_metadata(idx, {"tipo": "personalizado", "nombre": nombre, "datos": _pinceles_personalizados[nombre]})
		idx += 1

func _on_pincel_selected(idx: int) -> void:
	if not is_instance_valid(_opt_pincel):
		return
	var meta = _opt_pincel.get_item_metadata(idx)
	if meta == null or not (meta is Dictionary):
		return
	var datos = meta.get("datos", {})
	var tipo = meta.get("tipo", "")

	if is_instance_valid(_btn_borrar_pincel):
		_btn_borrar_pincel.disabled = (tipo != "personalizado")

	if datos.has("radio"):
		_on_radio_changed(float(datos["radio"]))

	if datos.has("densidad"):
		_on_densidad_changed(float(datos["densidad"]))

	if datos.has("forma"):
		var f = int(datos["forma"])
		if is_instance_valid(_opt_forma):
			_opt_forma.select(f)
		_on_forma_selected(f)

	_actualizar_texto_boton_ajustes()

func _on_guardar_pincel_pressed() -> void:
	_crear_dialogo_guardar_pincel()
	if is_instance_valid(_dialog_guardar_pincel):
		_input_nombre_pincel.text = "Nuevo Pincel %d" % (_pinceles_personalizados.size() + 1)
		_input_nombre_pincel.select_all()
		_dialog_guardar_pincel.popup_centered(Vector2i(340, 120))
		_input_nombre_pincel.grab_focus()

func _crear_dialogo_guardar_pincel() -> void:
	if _dialog_guardar_pincel != null:
		return
	_dialog_guardar_pincel = ConfirmationDialog.new()
	_dialog_guardar_pincel.title = "Guardar Pincel Personalizado"
	_dialog_guardar_pincel.ok_button_text = "Guardar"
	_dialog_guardar_pincel.cancel_button_text = "Cancelar"

	var vbox = VBoxContainer.new()
	var lbl = Label.new()
	lbl.text = "Nombre del nuevo pincel:"
	vbox.add_child(lbl)

	_input_nombre_pincel = LineEdit.new()
	_input_nombre_pincel.placeholder_text = "Ej. Césped Espeso"
	_input_nombre_pincel.text_submitted.connect(func(_t): _on_guardar_pincel_confirmado())
	vbox.add_child(_input_nombre_pincel)

	_dialog_guardar_pincel.add_child(vbox)
	_dialog_guardar_pincel.confirmed.connect(_on_guardar_pincel_confirmado)
	EditorInterface.get_base_control().add_child(_dialog_guardar_pincel)

func _destruir_dialogo_guardar_pincel() -> void:
	if is_instance_valid(_dialog_guardar_pincel):
		_dialog_guardar_pincel.queue_free()
		_dialog_guardar_pincel = null
		_input_nombre_pincel = null

func _on_guardar_pincel_confirmado() -> void:
	if not is_instance_valid(_input_nombre_pincel):
		return
	var nom = _input_nombre_pincel.text.strip_edges()
	if nom.is_empty():
		return
	if is_instance_valid(_dialog_guardar_pincel):
		_dialog_guardar_pincel.hide()

	var r = _spin_radio.value if is_instance_valid(_spin_radio) else 1.5
	var d = int(_spin_densidad.value) if is_instance_valid(_spin_densidad) else 25
	var f = _opt_forma.selected if is_instance_valid(_opt_forma) else 0

	_pinceles_personalizados[nom] = {
		"radio": r,
		"densidad": d,
		"forma": f
	}
	_guardar_pinceles_a_disco()
	_actualizar_opciones_selector_pinceles()

	# Seleccionar el nuevo pincel guardado
	for i in range(_opt_pincel.item_count):
		var meta = _opt_pincel.get_item_metadata(i)
		if meta is Dictionary and meta.get("tipo") == "personalizado" and meta.get("nombre") == nom:
			_opt_pincel.select(i)
			if is_instance_valid(_btn_borrar_pincel):
				_btn_borrar_pincel.disabled = false
			break

func _on_borrar_pincel_pressed() -> void:
	if not is_instance_valid(_opt_pincel):
		return
	var idx = _opt_pincel.selected
	var meta = _opt_pincel.get_item_metadata(idx)
	if meta is Dictionary and meta.get("tipo") == "personalizado":
		var nom = meta.get("nombre", "")
		if _pinceles_personalizados.has(nom):
			_pinceles_personalizados.erase(nom)
			_guardar_pinceles_a_disco()
			_actualizar_opciones_selector_pinceles()
			_opt_pincel.select(0)
			_on_pincel_selected(0)

# ==============================================================================
# BARRA DE HERRAMIENTAS ULTRA-COMPACTA Y PANEL DE AJUSTES
# ==============================================================================

func _crear_toolbar() -> void:
	if _toolbar != null:
		return

	_toolbar = HBoxContainer.new()
	_toolbar.name = "ToolbarPincelPasto"
	_toolbar.visible = false

	var sep1 = VSeparator.new()
	_toolbar.add_child(sep1)

	# 1. Botón activar/desactivar pincel
	_btn_activar_pincel = Button.new()
	_btn_activar_pincel.text = "🌿 Pasto"
	_btn_activar_pincel.toggle_mode = true
	_btn_activar_pincel.tooltip_text = "Activar / Desactivar Pincel de Pasto 3D\n(Clic izq. = Pintar, Shift+Clic o Clic der. = Borrar)"
	_btn_activar_pincel.toggled.connect(_on_pincel_toggled)
	_toolbar.add_child(_btn_activar_pincel)

	# 2. Selector compacto de presets de pincel
	_opt_pincel = OptionButton.new()
	_opt_pincel.custom_minimum_size = Vector2(110, 0)
	_opt_pincel.fit_to_longest_item = false
	_opt_pincel.tooltip_text = "Elige un pincel predeterminado o personalizado"
	_opt_pincel.item_selected.connect(_on_pincel_selected)
	_toolbar.add_child(_opt_pincel)
	_actualizar_opciones_selector_pinceles()

	# 3. Botón indicador y desplegable de configuración detallada
	_btn_ajustes = Button.new()
	_btn_ajustes.text = "⚙️ R: 1.5m | D: 25"
	_btn_ajustes.tooltip_text = "Configuración del Pincel (Radio, Densidad, Forma, No Repintar, Presets, Limpiar)"
	_btn_ajustes.pressed.connect(_on_ajustes_pressed)
	_toolbar.add_child(_btn_ajustes)

	var sep2 = VSeparator.new()
	_toolbar.add_child(sep2)

	_crear_popup_ajustes()
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _toolbar)

func _destruir_toolbar() -> void:
	_destruir_popup_ajustes()
	if is_instance_valid(_toolbar):
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _toolbar)
		_toolbar.queue_free()
		_toolbar = null

func _crear_popup_ajustes() -> void:
	if _popup_ajustes != null:
		return

	_popup_ajustes = PopupPanel.new()
	_popup_ajustes.name = "PopupAjustesPincelPasto"

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.custom_minimum_size = Vector2(300, 0)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# --- Encabezado ---
	var lbl_titulo = Label.new()
	lbl_titulo.text = "⚙️ Ajustes del Pincel de Pasto"
	lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl_titulo)

	var sep_title = HSeparator.new()
	vbox.add_child(sep_title)

	# --- Forma del Pincel ---
	var hbox_forma = HBoxContainer.new()
	var lbl_forma = Label.new()
	lbl_forma.text = "Forma:"
	lbl_forma.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_forma.add_child(lbl_forma)

	_opt_forma = OptionButton.new()
	_opt_forma.add_item("⭕ Círculo", 0)
	_opt_forma.add_item("⬛ Cuadrado", 1)
	_opt_forma.add_item("🔺 Triángulo", 2)
	_opt_forma.add_item("🍩 Corona / Anillo", 3)
	_opt_forma.add_item("➖ Sendero / Línea", 4)
	_opt_forma.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opt_forma.item_selected.connect(_on_forma_selected)
	hbox_forma.add_child(_opt_forma)
	vbox.add_child(hbox_forma)

	# --- Radio del Pincel ---
	var vbox_radio = VBoxContainer.new()
	var hbox_radio_lbl = HBoxContainer.new()
	var lbl_radio = Label.new()
	lbl_radio.text = "Radio del Pincel:"
	lbl_radio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_radio_lbl.add_child(lbl_radio)

	_spin_radio = SpinBox.new()
	_spin_radio.min_value = 0.1
	_spin_radio.max_value = 50.0
	_spin_radio.step = 0.1
	_spin_radio.value = 1.5
	_spin_radio.suffix = " m"
	_spin_radio.allow_greater = true
	_spin_radio.value_changed.connect(_on_radio_changed)
	hbox_radio_lbl.add_child(_spin_radio)
	vbox_radio.add_child(hbox_radio_lbl)

	_slider_radio = HSlider.new()
	_slider_radio.min_value = 0.2
	_slider_radio.max_value = 15.0
	_slider_radio.step = 0.1
	_slider_radio.value = 1.5
	_slider_radio.value_changed.connect(func(v): _on_radio_changed(v))
	vbox_radio.add_child(_slider_radio)
	vbox.add_child(vbox_radio)

	# --- Densidad del Pincel ---
	var vbox_den = VBoxContainer.new()
	var hbox_den_lbl = HBoxContainer.new()
	var lbl_den = Label.new()
	lbl_den.text = "Densidad (briznas/m²):"
	lbl_den.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_den_lbl.add_child(lbl_den)

	_spin_densidad = SpinBox.new()
	_spin_densidad.min_value = 1
	_spin_densidad.max_value = 10000
	_spin_densidad.step = 1
	_spin_densidad.value = 25
	_spin_densidad.allow_greater = true
	_spin_densidad.value_changed.connect(_on_densidad_changed)
	hbox_den_lbl.add_child(_spin_densidad)
	vbox_den.add_child(hbox_den_lbl)

	_slider_densidad = HSlider.new()
	_slider_densidad.min_value = 1
	_slider_densidad.max_value = 500
	_slider_densidad.step = 1
	_slider_densidad.value = 25
	_slider_densidad.value_changed.connect(func(v): _on_densidad_changed(v))
	vbox_den.add_child(_slider_densidad)
	vbox.add_child(vbox_den)

	# --- Opción No Repintar ---
	_chk_no_repintar = CheckBox.new()
	_chk_no_repintar.text = "🔒 No repintar sobre zonas ya pintadas"
	_chk_no_repintar.tooltip_text = "Evita acumular pasto en las mismas zonas manteniendo la densidad constante."
	_chk_no_repintar.toggled.connect(_on_no_repintar_toggled)
	vbox.add_child(_chk_no_repintar)

	# --- Gestión de Presets ---
	var hbox_presets = HBoxContainer.new()
	_btn_guardar_pincel = Button.new()
	_btn_guardar_pincel.text = "💾 Guardar Pincel"
	_btn_guardar_pincel.tooltip_text = "Guardar configuración actual como preset personalizado"
	_btn_guardar_pincel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_guardar_pincel.pressed.connect(_on_guardar_pincel_pressed)
	hbox_presets.add_child(_btn_guardar_pincel)

	_btn_borrar_pincel = Button.new()
	_btn_borrar_pincel.text = "❌ Borrar Pincel"
	_btn_borrar_pincel.tooltip_text = "Eliminar preset personalizado seleccionado"
	_btn_borrar_pincel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_borrar_pincel.disabled = true
	_btn_borrar_pincel.pressed.connect(_on_borrar_pincel_pressed)
	hbox_presets.add_child(_btn_borrar_pincel)
	vbox.add_child(hbox_presets)

	var sep_act = HSeparator.new()
	vbox.add_child(sep_act)

	# --- Botón Limpiar Todo ---
	_btn_limpiar = Button.new()
	_btn_limpiar.text = "🗑️ Limpiar Todo el Pasto Pintado"
	_btn_limpiar.tooltip_text = "Borra todo el pasto pintado en este objeto (compatible con Ctrl+Z)"
	_btn_limpiar.pressed.connect(_on_limpiar_pressed)
	vbox.add_child(_btn_limpiar)

	# --- Guía de atajos rápidos ---
	var lbl_atajos = Label.new()
	lbl_atajos.text = "💡 Atajos 3D:\n• Shift + Rueda o [ / ]: Radio del pincel\n• Ctrl + Shift + Rueda: Densidad\n• Clic der. o Shift + Clic: Borrar pasto"
	lbl_atajos.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.85))
	lbl_atajos.add_theme_font_size_override("font_size", 11)
	vbox.add_child(lbl_atajos)

	margin.add_child(vbox)
	_popup_ajustes.add_child(margin)

	EditorInterface.get_base_control().add_child(_popup_ajustes)

func _destruir_popup_ajustes() -> void:
	if is_instance_valid(_popup_ajustes):
		_popup_ajustes.queue_free()
		_popup_ajustes = null

func _on_ajustes_pressed() -> void:
	if not is_instance_valid(_popup_ajustes):
		_crear_popup_ajustes()
	if not is_instance_valid(_popup_ajustes):
		return
	if _popup_ajustes.visible:
		_popup_ajustes.hide()
		return
	var rect = _btn_ajustes.get_global_rect()
	var pos = Vector2i(int(rect.position.x), int(rect.position.y + rect.size.y + 4))
	_popup_ajustes.popup(Rect2i(pos, Vector2i(320, 360)))

func _actualizar_texto_boton_ajustes() -> void:
	if not is_instance_valid(_btn_ajustes):
		return
	var r = _spin_radio.value if is_instance_valid(_spin_radio) else 1.5
	var d = int(_spin_densidad.value) if is_instance_valid(_spin_densidad) else 25
	_btn_ajustes.text = "⚙️ R: %.1fm | D: %d" % [r, d]
	_btn_ajustes.tooltip_text = "Configuración del Pincel (Radio: %.1fm, Densidad: %d briznas/m²)" % [r, d]

func _sincronizar_toolbar_con_nodo() -> void:
	if not is_instance_valid(_nodo_pasto):
		return
	if "activar_pincel" in _nodo_pasto and is_instance_valid(_btn_activar_pincel):
		_btn_activar_pincel.set_pressed_no_signal(_nodo_pasto.activar_pincel)
	if "forma_pincel" in _nodo_pasto and is_instance_valid(_opt_forma):
		_opt_forma.select(_nodo_pasto.forma_pincel)
	if "radio_pincel" in _nodo_pasto:
		var r = _nodo_pasto.radio_pincel
		if is_instance_valid(_spin_radio):
			_spin_radio.set_value_no_signal(r)
		if is_instance_valid(_slider_radio):
			_slider_radio.set_value_no_signal(r)
	if "densidad_pincel" in _nodo_pasto:
		var d = _nodo_pasto.densidad_pincel
		if is_instance_valid(_spin_densidad):
			_spin_densidad.set_value_no_signal(d)
		if is_instance_valid(_slider_densidad):
			_slider_densidad.set_value_no_signal(d)
	if "evitar_repintar" in _nodo_pasto and is_instance_valid(_chk_no_repintar):
		_chk_no_repintar.set_pressed_no_signal(_nodo_pasto.evitar_repintar)
	_actualizar_texto_boton_ajustes()

func _on_pincel_toggled(activo: bool) -> void:
	if is_instance_valid(_nodo_pasto) and "activar_pincel" in _nodo_pasto:
		_nodo_pasto.activar_pincel = activo
		_actualizar_visibilidad()

func _on_forma_selected(idx: int) -> void:
	if is_instance_valid(_nodo_pasto) and "forma_pincel" in _nodo_pasto:
		_nodo_pasto.forma_pincel = idx
		_actualizar_forma_gizmo()

func _on_radio_changed(val: float) -> void:
	if is_instance_valid(_slider_radio) and abs(_slider_radio.value - val) > 0.05:
		_slider_radio.set_value_no_signal(val)
	if is_instance_valid(_spin_radio) and abs(_spin_radio.value - val) > 0.01:
		_spin_radio.set_value_no_signal(val)
	if is_instance_valid(_nodo_pasto) and "radio_pincel" in _nodo_pasto:
		_nodo_pasto.radio_pincel = val
	_actualizar_texto_boton_ajustes()
	_actualizar_forma_gizmo()

func _on_densidad_changed(val: float) -> void:
	var d = int(val)
	if is_instance_valid(_slider_densidad) and int(_slider_densidad.value) != d:
		_slider_densidad.set_value_no_signal(d)
	if is_instance_valid(_spin_densidad) and int(_spin_densidad.value) != d:
		_spin_densidad.set_value_no_signal(d)
	if is_instance_valid(_nodo_pasto) and "densidad_pincel" in _nodo_pasto:
		_nodo_pasto.densidad_pincel = d
	_actualizar_texto_boton_ajustes()

func _on_no_repintar_toggled(activo: bool) -> void:
	if is_instance_valid(_nodo_pasto) and "evitar_repintar" in _nodo_pasto:
		_nodo_pasto.evitar_repintar = activo

func _on_limpiar_pressed() -> void:
	if not is_instance_valid(_nodo_pasto) or not _nodo_pasto.has_method("limpiar_pasto_pintado"):
		return
	if "datos_pasto_pintado" in _nodo_pasto and _nodo_pasto.datos_pasto_pintado.is_empty():
		return

	var datos_previos: Array[Transform3D] = []
	if "datos_pasto_pintado" in _nodo_pasto and _nodo_pasto.datos_pasto_pintado != null:
		datos_previos = _nodo_pasto.datos_pasto_pintado.duplicate()

	var ur = get_undo_redo()
	if ur != null:
		ur.create_action("Limpiar Pasto")
		ur.add_do_property(_nodo_pasto, "datos_pasto_pintado", [] as Array[Transform3D])
		ur.add_undo_property(_nodo_pasto, "datos_pasto_pintado", datos_previos)
		ur.add_do_method(_nodo_pasto, "_actualizar_multimesh_pintado")
		ur.add_undo_method(_nodo_pasto, "_actualizar_multimesh_pintado")
		ur.commit_action(true)
	else:
		_nodo_pasto.limpiar_pasto_pintado()

# ==============================================================================
# GIZMO VISUAL 3D (Círculo, Cuadrado, Triángulo)
# ==============================================================================

func _crear_gizmo_cursor() -> void:
	if _gizmo_cursor != null:
		return

	_gizmo_cursor = MeshInstance3D.new()
	_gizmo_cursor.name = "_GizmoPincelPasto"

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.15, 0.95, 0.35, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true

	_gizmo_cursor.material_override = mat
	_gizmo_cursor.visible = false
	_gizmo_cursor.top_level = true
	_forma_actual_gizmo = -1
	_actualizar_forma_gizmo()

func _actualizar_forma_gizmo() -> void:
	if not is_instance_valid(_gizmo_cursor):
		return

	var forma: int = 0
	if is_instance_valid(_nodo_pasto) and "forma_pincel" in _nodo_pasto:
		forma = _nodo_pasto.forma_pincel

	if _forma_actual_gizmo == forma:
		return

	_forma_actual_gizmo = forma

	match forma:
		1: # Cuadrado
			var box = BoxMesh.new()
			box.size = Vector3(2.0, 0.04, 2.0)
			_gizmo_cursor.mesh = box
		2: # Triángulo
			var tri = CylinderMesh.new()
			tri.top_radius = 1.0
			tri.bottom_radius = 1.0
			tri.height = 0.04
			tri.radial_segments = 3
			_gizmo_cursor.mesh = tri
		3: # Corona / Anillo
			var torus = TorusMesh.new()
			torus.inner_radius = 0.5
			torus.outer_radius = 1.0
			torus.rings = 32
			torus.ring_segments = 4
			_gizmo_cursor.mesh = torus
		4: # Sendero / Línea
			var line_box = BoxMesh.new()
			line_box.size = Vector3(2.0, 0.04, 0.5)
			_gizmo_cursor.mesh = line_box
		_: # Círculo
			var cyl = CylinderMesh.new()
			cyl.top_radius = 1.0
			cyl.bottom_radius = 1.0
			cyl.height = 0.04
			cyl.radial_segments = 32
			_gizmo_cursor.mesh = cyl

func _destruir_gizmo_cursor() -> void:
	if is_instance_valid(_gizmo_cursor):
		if _gizmo_cursor.get_parent() != null:
			_gizmo_cursor.get_parent().remove_child(_gizmo_cursor)
		_gizmo_cursor.queue_free()
		_gizmo_cursor = null

func _asegurar_gizmo_en_arbol() -> void:
	if not is_instance_valid(_gizmo_cursor):
		_crear_gizmo_cursor()

	if is_instance_valid(_nodo_pasto) and _nodo_pasto.is_inside_tree():
		if _gizmo_cursor.get_parent() != _nodo_pasto:
			if _gizmo_cursor.get_parent() != null:
				_gizmo_cursor.get_parent().remove_child(_gizmo_cursor)
			_nodo_pasto.add_child(_gizmo_cursor)

func _posicionar_cursor(pos: Vector3, normal: Vector3, radio: float) -> void:
	_asegurar_gizmo_en_arbol()
	if not is_instance_valid(_gizmo_cursor):
		return

	_gizmo_cursor.visible = true

	var rot_basis = Basis.IDENTITY
	if abs(normal.dot(Vector3.UP)) < 0.999:
		var eje = Vector3.UP.cross(normal).normalized()
		var angulo = Vector3.UP.angle_to(normal)
		if eje.length_squared() > 0.001:
			rot_basis = Basis(eje, angulo)

	# Asignar la rotación orientada y la escala exacta del radio
	_gizmo_cursor.global_basis = rot_basis.scaled(Vector3(radio, 1.0, radio))
	_gizmo_cursor.global_position = pos + normal * 0.03

func _ocultar_cursor() -> void:
	if is_instance_valid(_gizmo_cursor):
		_gizmo_cursor.visible = false

func _actualizar_visibilidad() -> void:
	var mostrar = is_instance_valid(_nodo_pasto) and ("activar_pincel" in _nodo_pasto) and _nodo_pasto.activar_pincel
	if not mostrar:
		_ocultar_cursor()
