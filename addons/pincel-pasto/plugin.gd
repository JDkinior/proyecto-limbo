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

# Barra de herramientas en el encabezado del visor 3D
var _toolbar: HBoxContainer = null
var _btn_activar_pincel: CheckBox = null
var _opt_forma: OptionButton = null
var _spin_radio: SpinBox = null
var _spin_densidad: SpinBox = null
var _btn_limpiar: Button = null

# Cursor visual 3D (Disco / Caja / Triángulo)
var _gizmo_cursor: MeshInstance3D = null
var _forma_actual_gizmo: int = -1

func _enter_tree() -> void:
	_crear_toolbar()
	_crear_gizmo_cursor()

func _exit_tree() -> void:
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
	_nodo_pasto = object as Node
	_sincronizar_toolbar_con_nodo()
	_actualizar_forma_gizmo()
	_actualizar_visibilidad()

func _make_visible(visible: bool) -> void:
	if _toolbar != null:
		_toolbar.visible = visible
	if not visible:
		_nodo_pasto = null
		_pintando = false
		_borrando = false
		_ocultar_cursor()

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

	if event is InputEventMouseMotion:
		var hit = _hacer_raycast(camera, event.position)
		if not hit.is_empty():
			_posicionar_cursor(hit.position, hit.normal, radio)

			if _pintando:
				if _ultima_pos_pintada.distance_squared_to(hit.position) > pow(radio * 0.25, 2):
					_ejecutar_pintado_con_proyeccion(camera, hit)
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
		var hit = _hacer_raycast(camera, mb.position)

		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.shift_pressed:
					# Shift + Clic Izquierdo = Borrar
					_borrando = true
					if not hit.is_empty() and _nodo_pasto.has_method("borrar_en_posicion"):
						_nodo_pasto.borrar_en_posicion(hit.position, radio)
					return AFTER_GUI_INPUT_STOP
				else:
					# Clic Izquierdo = Pintar con comprobación de superficie
					_pintando = true
					if not hit.is_empty():
						_ejecutar_pintado_con_proyeccion(camera, hit)
						_ultima_pos_pintada = hit.position
					return AFTER_GUI_INPUT_STOP
			else:
				_pintando = false
				_borrando = false
				_ultima_pos_pintada = Vector3.INF
				return AFTER_GUI_INPUT_PASS

		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				# Clic Derecho = Borrar
				_borrando = true
				if not hit.is_empty() and _nodo_pasto.has_method("borrar_en_posicion"):
					_nodo_pasto.borrar_en_posicion(hit.position, radio)
				return AFTER_GUI_INPUT_STOP
			else:
				_borrando = false
				return AFTER_GUI_INPUT_PASS

	return AFTER_GUI_INPUT_PASS

# ==============================================================================
# PINTADO CON PROYECCIÓN Y COMPROBACIÓN DE BORDES
# ==============================================================================

func _ejecutar_pintado_con_proyeccion(camera: Camera3D, hit_center: Dictionary) -> void:
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

	for _i in range(densidad):
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
# BARRA DE HERRAMIENTAS
# ==============================================================================

func _crear_toolbar() -> void:
	if _toolbar != null:
		return

	_toolbar = HBoxContainer.new()
	_toolbar.name = "ToolbarPincelPasto"
	_toolbar.visible = false

	var sep1 = VSeparator.new()
	_toolbar.add_child(sep1)

	_btn_activar_pincel = CheckBox.new()
	_btn_activar_pincel.text = "🌿 Pincel de Pasto"
	_btn_activar_pincel.toggled.connect(_on_pincel_toggled)
	_toolbar.add_child(_btn_activar_pincel)

	var lbl_forma = Label.new()
	lbl_forma.text = " Forma:"
	_toolbar.add_child(lbl_forma)

	_opt_forma = OptionButton.new()
	_opt_forma.add_item("⭕ Círculo", 0)
	_opt_forma.add_item("⬛ Cuadrado", 1)
	_opt_forma.add_item("🔺 Triángulo", 2)
	_opt_forma.item_selected.connect(_on_forma_selected)
	_toolbar.add_child(_opt_forma)

	var lbl_radio = Label.new()
	lbl_radio.text = " Radio:"
	_toolbar.add_child(lbl_radio)

	_spin_radio = SpinBox.new()
	_spin_radio.min_value = 0.2
	_spin_radio.max_value = 20.0
	_spin_radio.step = 0.1
	_spin_radio.value = 1.5
	_spin_radio.value_changed.connect(_on_radio_changed)
	_toolbar.add_child(_spin_radio)

	var lbl_den = Label.new()
	lbl_den.text = " Densidad:"
	_toolbar.add_child(lbl_den)

	_spin_densidad = SpinBox.new()
	_spin_densidad.min_value = 1
	_spin_densidad.max_value = 100
	_spin_densidad.step = 1
	_spin_densidad.value = 10
	_spin_densidad.value_changed.connect(_on_densidad_changed)
	_toolbar.add_child(_spin_densidad)

	_btn_limpiar = Button.new()
	_btn_limpiar.text = "🗑️ Limpiar Pasto"
	_btn_limpiar.pressed.connect(_on_limpiar_pressed)
	_toolbar.add_child(_btn_limpiar)

	var sep2 = VSeparator.new()
	_toolbar.add_child(sep2)

	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _toolbar)

func _destruir_toolbar() -> void:
	if is_instance_valid(_toolbar):
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _toolbar)
		_toolbar.queue_free()
		_toolbar = null

func _sincronizar_toolbar_con_nodo() -> void:
	if not is_instance_valid(_nodo_pasto) or not is_instance_valid(_btn_activar_pincel):
		return
	if "activar_pincel" in _nodo_pasto:
		_btn_activar_pincel.set_pressed_no_signal(_nodo_pasto.activar_pincel)
	if "forma_pincel" in _nodo_pasto and is_instance_valid(_opt_forma):
		_opt_forma.select(_nodo_pasto.forma_pincel)
	if "radio_pincel" in _nodo_pasto:
		_spin_radio.set_value_no_signal(_nodo_pasto.radio_pincel)
	if "densidad_pincel" in _nodo_pasto:
		_spin_densidad.set_value_no_signal(_nodo_pasto.densidad_pincel)

func _on_pincel_toggled(activo: bool) -> void:
	if is_instance_valid(_nodo_pasto) and "activar_pincel" in _nodo_pasto:
		_nodo_pasto.activar_pincel = activo
		_actualizar_visibilidad()

func _on_forma_selected(idx: int) -> void:
	if is_instance_valid(_nodo_pasto) and "forma_pincel" in _nodo_pasto:
		_nodo_pasto.forma_pincel = idx
		_actualizar_forma_gizmo()

func _on_radio_changed(val: float) -> void:
	if is_instance_valid(_nodo_pasto) and "radio_pincel" in _nodo_pasto:
		_nodo_pasto.radio_pincel = val

func _on_densidad_changed(val: float) -> void:
	if is_instance_valid(_nodo_pasto) and "densidad_pincel" in _nodo_pasto:
		_nodo_pasto.densidad_pincel = int(val)

func _on_limpiar_pressed() -> void:
	if is_instance_valid(_nodo_pasto) and _nodo_pasto.has_method("limpiar_pasto_pintado"):
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
