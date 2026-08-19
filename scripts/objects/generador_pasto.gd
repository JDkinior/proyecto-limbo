@tool
extends MultiMeshInstance3D
class_name GeneradorPasto

## ==========================================================
## GENERADOR Y PINCEL DE PASTO ESTILIZADO 3D (GODOT 4)
## Soporta generación automática por área y pintado interactivo
## con brocha sobre MeshInstance3D y plataformas para Proyecto Limbo.
## ==========================================================

@export_group("Modo de Generación")
## Elige si deseas que el pasto cubra un área rectangular automáticamente o pintarlo a mano con el pincel.
@export_enum("Pintado Manual con Pincel", "Área Rectangular Automática") var modo_distribucion: int = 1:
	set(valor):
		modo_distribucion = valor
		_solicitar_regeneracion()

@export_group("Herramienta Pincel 3D")
## Activa el pincel interactivo para pintar/borrar en el visor 3D al hacer clic sobre cualquier suelo o MeshInstance3D.
@export var activar_pincel: bool = false

## Radio o tamaño del pincel en metros.
@export_range(0.2, 15.0, 0.1) var radio_pincel: float = 1.5

## Cantidad de briznas que se colocan por cada pasada del pincel.
@export_range(1, 100, 1) var densidad_pincel: int = 10

## Alinea la inclinación de las briznas con la pendiente/inclinación de la superficie donde pintas.
@export var alinear_con_superficie: bool = true

## Forma geométrica del pincel (Círculo, Cuadrado o Triángulo).
@export_enum("Circular (Redondo)", "Cuadrado", "Triangular") var forma_pincel: int = 0

## Almacena las instancias pintadas para que se guarden permanentemente con tu escena.
@export var datos_pasto_pintado: Array[Transform3D] = []


@export_group("Filtro de Objetos a Pintar")
## Si arrastras o agregas nodos aquí (ej. SueloVivoBase, Plataformas), el pincel SOLO pintará sobre esos objetos y sus hijos. Si está vacío, pinta en cualquier superficie válida.
@export var solo_pintar_en_objetos: Array[NodePath] = []

## Ignora automáticamente personajes, faroles, árboles, monedas, botones y elementos interactivos para no pintarlos accidentalmente.
@export var ignorar_interactivos_y_personajes: bool = true

## Capas de física permitidas para pintar (por defecto capas de suelo/estructuras).
@export_flags_3d_physics var capas_colision_permitidas: int = 1



@export_group("Área y Densidad (Modo Automático)")
## Tamaño del terreno (Ancho X, Largo Z) donde se distribuirá el pasto en modo automático.
@export var area_tamano: Vector2 = Vector2(50.0, 50.0):
	set(valor):
		area_tamano = valor
		_solicitar_regeneracion()

## Cantidad total de mechones de pasto en modo automático.
@export_range(100, 50000, 100) var cantidad_instancias: int = 20000:
	set(valor):
		cantidad_instancias = valor
		_solicitar_regeneracion()

## Muestreo por rejilla con jitter: distribuye el pasto de forma 100% homogénea sin dejar calvas ni huecos vacíos.
@export var distribucion_uniforme_grid: bool = true:
	set(valor):
		distribucion_uniforme_grid = valor
		_solicitar_regeneracion()

@export_group("Estilo y Tamaño de las Briznas")
## Altura promedio de las briznas de pasto.
@export_range(0.1, 3.0, 0.05) var alto_pasto: float = 0.40:
	set(valor):
		alto_pasto = valor
		_solicitar_regeneracion()

## Grosor o anchura de la base de cada brizna (menor = más fino y estilizado).
@export_range(0.02, 0.8, 0.01) var ancho_pasto: float = 0.16:
	set(valor):
		ancho_pasto = valor
		_solicitar_regeneracion()

## Cantidad de briznas u hojas dentro de cada mechón (3 a 5 dan un aspecto muy orgánico).
@export_range(1, 6) var briznas_por_manojo: int = 4:
	set(valor):
		briznas_por_manojo = valor
		_solicitar_regeneracion()

## Qué tanto se abren y curvan las puntas hacia afuera respecto al centro del mechón.
@export_range(0.0, 0.5, 0.02) var curvatura_puntas: float = 0.10:
	set(valor):
		curvatura_puntas = valor
		_solicitar_regeneracion()

## Variación aleatoria de escala (Mínimo, Máximo) para dar naturalidad.
@export var variacion_escala: Vector2 = Vector2(0.65, 1.25):
	set(valor):
		variacion_escala = valor
		_solicitar_regeneracion()

@export_group("Plano y Materiales (Físico vs Espiritual)")
@export_enum("Auto (Según Personaje)", "Plano Físico (Verde)", "Plano Espiritual (Azul)") var modo_reino: int = 0:
	set(valor):
		modo_reino = valor
		_actualizar_material_por_reino()

@export var material_fisico: Material = preload("res://shaders/pasto_fisico_mat.tres")
@export var material_espiritual: Material = preload("res://shaders/pasto_espiritual_mat.tres")

@export_group("Control de Viento")
## Fuerza con la que se mecen las briznas (0.0 = quieto, 0.25 = brisa suave, 0.6 = viento fuerte).
@export_range(0.0, 2.0, 0.05) var fuerza_viento: float = 0.25:
	set(valor):
		fuerza_viento = valor
		_actualizar_parametro_shader("fuerza_viento", valor)

## Velocidad a la que viajan las ondas de viento.
@export_range(0.0, 10.0, 0.1) var velocidad_viento: float = 2.2:
	set(valor):
		velocidad_viento = valor
		_actualizar_parametro_shader("velocidad_viento", valor)

## Dirección hacia la que sopla el viento en los ejes (X, Z).
@export var direccion_viento: Vector2 = Vector2(1.0, 0.4):
	set(valor):
		direccion_viento = valor
		_actualizar_parametro_shader("direccion_viento", valor)

@export_group("Personalización Avanzada")
## Si deseas usar una malla 3D personalizada hecha en Blender en vez de la procedural.
@export var mesh_personalizado: Mesh = null:
	set(valor):
		mesh_personalizado = valor
		_solicitar_regeneracion()

@export var interactuar_con_personajes: bool = true

@export_group("Acciones")
@export var forzar_regenerar: bool = false:
	set(_v):
		generar()

var _jugador_ref: Node3D = null
var _fantasma_ref: Node3D = null
var _shader_mat: ShaderMaterial = null

func _actualizar_parametro_shader(param: String, valor: Variant) -> void:
	if material_override is ShaderMaterial:
		(material_override as ShaderMaterial).set_shader_parameter(param, valor)
	if material_fisico is ShaderMaterial:
		(material_fisico as ShaderMaterial).set_shader_parameter(param, valor)
	if material_espiritual is ShaderMaterial:
		(material_espiritual as ShaderMaterial).set_shader_parameter(param, valor)

func _ready() -> void:
	# Duplicar materiales para que cada GeneradorPasto tenga instancias independientes.
	# Esto es ESENCIAL en multijugador LAN donde ambos personajes comparten el mismo
	# proceso de Godot: sin duplicar, ambos modificarían el mismo ShaderMaterial.
	if material_fisico != null:
		material_fisico = material_fisico.duplicate()
	if material_espiritual != null:
		material_espiritual = material_espiritual.duplicate()
	# Optimización de renderizado (culling y sombras)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if visibility_range_end == 0.0:
		visibility_range_end = 65.0
		visibility_range_end_margin = 10.0
		visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

	_conectar_senales_personaje()
	_actualizar_material_por_reino()
	generar()

func _conectar_senales_personaje() -> void:
	if Engine.is_editor_hint():
		return
	if is_instance_valid(RedManager):
		if RedManager.has_signal("personaje_solo_cambiado") and not RedManager.personaje_solo_cambiado.is_connected(_on_personaje_cambiado):
			RedManager.personaje_solo_cambiado.connect(_on_personaje_cambiado)
		if RedManager.has_signal("reino_cambiado") and not RedManager.reino_cambiado.is_connected(_on_reino_cambiado):
			RedManager.reino_cambiado.connect(_on_reino_cambiado)

func _on_personaje_cambiado(_nuevo_personaje: String) -> void:
	_actualizar_material_por_reino()

func _on_reino_cambiado(es_fantasma: bool) -> void:
	if modo_reino == 0:
		var mat_correcto = material_espiritual if es_fantasma else material_fisico
		if material_override != mat_correcto:
			material_override = mat_correcto
			_shader_mat = material_override as ShaderMaterial if material_override is ShaderMaterial else null

func _actualizar_material_por_reino() -> void:
	if material_fisico == null:
		material_fisico = load("res://shaders/pasto_fisico_mat.tres").duplicate()
	if material_espiritual == null:
		material_espiritual = load("res://shaders/pasto_espiritual_mat.tres").duplicate()

	if modo_reino == 1:
		material_override = material_fisico
	elif modo_reino == 2:
		material_override = material_espiritual
	else:
		# Modo AUTO: en un solo jugador usamos personaje_activo_solo o la cámara activa.
		# En multijugador (LAN o en línea) ambos personajes están en la misma escena,
		# así que debemos detectar quién controla la cámara activa.
		var es_fantasma = _detectar_es_fantasma_por_camara_activa()
		material_override = material_espiritual if es_fantasma else material_fisico

	if material_override is ShaderMaterial:
		_shader_mat = material_override as ShaderMaterial

# Determina si el personaje que actualmente controla la cámara activa es fantasma.
# Funciona tanto en un jugador (personaje_activo_solo) como en multijugador LAN/online.
func _detectar_es_fantasma_por_camara_activa() -> bool:
	if Engine.is_editor_hint():
		return false

	# 1. Intentar detectar por la cámara activa (robusto en multijugador LAN y transición)
	var cam = get_viewport().get_camera_3d() if is_inside_tree() else null
	if is_instance_valid(cam):
		# Si es la cámara de transición, su cull_mask indica el plano activo en tiempo real
		if cam.name.contains("Transicion"):
			return (cam.cull_mask & (1 << 2)) != 0

		# Subir por el árbol de nodos desde la cámara buscando el CharacterBase dueño
		var nodo = cam.get_parent()
		while is_instance_valid(nodo):
			if nodo.is_in_group("fantasmas") or nodo.name.to_lower().contains("fantasma"):
				return true
			if nodo.is_in_group("vivos") or nodo.name.to_lower().contains("jugador") or nodo.name.to_lower().contains("vivo"):
				return false
			nodo = nodo.get_parent()

	# 2. Fallback: usar RedManager
	if is_instance_valid(RedManager):
		if RedManager.has_method("es_reino_espiritual_activo"):
			return RedManager.es_reino_espiritual_activo()
		if RedManager.es_un_jugador and "personaje_activo_solo" in RedManager:
			return RedManager.personaje_activo_solo == "fantasma"
		if "peer_personajes" in RedManager:
			var mi_id = RedManager.get_mi_peer_id()
			if RedManager.peer_personajes.has(mi_id):
				return RedManager.peer_personajes[mi_id] == "fantasma"
	return false

func _solicitar_regeneracion() -> void:
	if not is_inside_tree() or not is_node_ready():
		return
	if Engine.is_editor_hint():
		generar()

func generar() -> void:
	var mesh_a_usar: Mesh = mesh_personalizado
	if mesh_a_usar == null:
		mesh_a_usar = _crear_malla_pasto_procedural()

	if mesh_a_usar == null:
		return

	if multimesh == null:
		multimesh = MultiMesh.new()

	if multimesh.transform_format != MultiMesh.TRANSFORM_3D:
		multimesh.instance_count = 0
		multimesh.transform_format = MultiMesh.TRANSFORM_3D

	multimesh.mesh = mesh_a_usar

	# --- MODO 0: PINTADO MANUAL ---
	if modo_distribucion == 0:
		var total_pintado = datos_pasto_pintado.size()
		multimesh.instance_count = total_pintado
		for i in range(total_pintado):
			multimesh.set_instance_transform(i, datos_pasto_pintado[i])
		return

	# --- MODO 1: ÁREA RECTANGULAR AUTOMÁTICA ---
	var count = cantidad_instancias if (cantidad_instancias != null and cantidad_instancias > 0) else 20000
	var area = area_tamano if area_tamano != null else Vector2(50.0, 50.0)
	var esc_range = variacion_escala if variacion_escala != null else Vector2(0.65, 1.25)

	multimesh.instance_count = count

	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var half_x = area.x * 0.5
	var half_z = area.y * 0.5

	if distribucion_uniforme_grid and count > 0:
		# Distribución estratificada (Jittered Grid) para cobertura homogénea total sin huecos ni calvas
		var ratio = area.x / max(0.001, area.y)
		var cols = max(1, int(round(sqrt(float(count) * ratio))))
		var rows = max(1, int(ceil(float(count) / float(cols))))
		var delta_x = area.x / float(cols)
		var delta_z = area.y / float(rows)

		var idx = 0
		for r in range(rows):
			for c in range(cols):
				if idx >= count:
					break

				var px = -half_x + (float(c) + 0.5 + rng.randf_range(-0.42, 0.42)) * delta_x
				var pz = -half_z + (float(r) + 0.5 + rng.randf_range(-0.42, 0.42)) * delta_z
				var pos = Vector3(px, 0.0, pz)

				var rot_y = rng.randf_range(0.0, TAU)
				var escala_factor = rng.randf_range(esc_range.x, esc_range.y)
				var escala = Vector3(escala_factor, escala_factor, escala_factor)

				var t = Transform3D()
				t = t.scaled(escala)
				t = t.rotated(Vector3.UP, rot_y)
				t.origin = pos

				multimesh.set_instance_transform(idx, t)
				idx += 1
	else:
		# Distribución puramente aleatoria
		for i in range(count):
			var pos_x = rng.randf_range(-half_x, half_x)
			var pos_z = rng.randf_range(-half_z, half_z)
			var pos = Vector3(pos_x, 0.0, pos_z)

			var rot_y = rng.randf_range(0.0, TAU)
			var escala_factor = rng.randf_range(esc_range.x, esc_range.y)
			var escala = Vector3(escala_factor, escala_factor, escala_factor)

			var t = Transform3D()
			t = t.scaled(escala)
			t = t.rotated(Vector3.UP, rot_y)
			t.origin = pos

			multimesh.set_instance_transform(i, t)

# ==============================================================================
# MÉTODOS DEL PINCEL 3D (Pintar, Borrar, Limpiar)
# ==============================================================================

## Agrega un conjunto de briznas con posiciones y normales ya verificadas en superficie
func agregar_instancias_pintadas(posiciones_mundo: Array[Vector3], normales_mundo: Array[Vector3]) -> void:
	if modo_distribucion != 0:
		modo_distribucion = 0

	var esc_range = variacion_escala if variacion_escala != null else Vector2(0.65, 1.25)
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	for i in range(posiciones_mundo.size()):
		var pos_m = posiciones_mundo[i]
		var norm_m = normales_mundo[i]
		var local_pos = to_local(pos_m)
		var local_norm = (global_transform.basis.inverse() * norm_m).normalized() if alinear_con_superficie else Vector3.UP

		var rot_y = rng.randf_range(0.0, TAU)
		var factor_esc = rng.randf_range(esc_range.x, esc_range.y)
		var escala = Vector3(factor_esc, factor_esc, factor_esc)

		var t = Transform3D()
		if alinear_con_superficie and abs(local_norm.dot(Vector3.UP)) < 0.999:
			var eje_rot = Vector3.UP.cross(local_norm).normalized()
			var angulo_rot = Vector3.UP.angle_to(local_norm)
			if eje_rot.length_squared() > 0.001:
				t = t.rotated(eje_rot, angulo_rot)

		t = t.rotated_local(Vector3.UP, rot_y)
		t = t.scaled_local(escala)
		t.origin = local_pos

		datos_pasto_pintado.append(t)

	_actualizar_multimesh_pintado()

## Pinta un conjunto de briznas según la forma del pincel (Círculo, Cuadrado, Triángulo)
func pintar_en_posicion(pos_mundo: Vector3, normal_mundo: Vector3) -> void:
	if modo_distribucion != 0:
		modo_distribucion = 0 # Cambiar automáticamente a modo manual al pintar

	var local_center = to_local(pos_mundo)
	var esc_range = variacion_escala if variacion_escala != null else Vector2(0.65, 1.25)
	var radio = max(0.1, radio_pincel)
	var cantidad = max(1, densidad_pincel)

	var rng = RandomNumberGenerator.new()
	rng.randomize()

	# Calcular orientación local a partir de la normal del mundo
	var local_normal = (global_transform.basis.inverse() * normal_mundo).normalized() if alinear_con_superficie else Vector3.UP

	for _i in range(cantidad):
		var offset_2d = _generar_offset_forma(rng, radio, forma_pincel)
		var pos_instancia = local_center + Vector3(offset_2d.x, 0.0, offset_2d.y)

		var rot_y = rng.randf_range(0.0, TAU)
		var factor_esc = rng.randf_range(esc_range.x, esc_range.y)
		var escala = Vector3(factor_esc, factor_esc, factor_esc)

		var t = Transform3D()
		if alinear_con_superficie and abs(local_normal.dot(Vector3.UP)) < 0.999:
			var eje_rot = Vector3.UP.cross(local_normal).normalized()
			var angulo_rot = Vector3.UP.angle_to(local_normal)
			if eje_rot.length_squared() > 0.001:
				t = t.rotated(eje_rot, angulo_rot)

		t = t.rotated_local(Vector3.UP, rot_y)
		t = t.scaled_local(escala)
		t.origin = pos_instancia

		datos_pasto_pintado.append(t)

	_actualizar_multimesh_pintado()


## Borra las briznas que se encuentren dentro del área de la forma en la posición dada
func borrar_en_posicion(pos_mundo: Vector3, radio_borrado: float) -> void:
	if modo_distribucion != 0 or datos_pasto_pintado.is_empty():
		return

	var local_center = to_local(pos_mundo)
	var datos_filtrados: Array[Transform3D] = []

	for t in datos_pasto_pintado:
		var offset = Vector2(t.origin.x - local_center.x, t.origin.z - local_center.z)
		if not _esta_dentro_de_forma(offset, radio_borrado, forma_pincel):
			datos_filtrados.append(t)

	if datos_filtrados.size() != datos_pasto_pintado.size():
		datos_pasto_pintado = datos_filtrados
		_actualizar_multimesh_pintado()

## Genera un desplazamiento 2D aleatorio uniforme según la forma elegida
func _generar_offset_forma(rng: RandomNumberGenerator, radio: float, forma: int) -> Vector2:
	match forma:
		1: # Cuadrado de lado 2*radio
			return Vector2(rng.randf_range(-radio, radio), rng.randf_range(-radio, radio))
		2: # Triángulo equilátero
			var w = radio * 1.73205
			var v0 = Vector2(0.0, -radio)
			var v1 = Vector2(w * 0.5, radio * 0.5)
			var v2 = Vector2(-w * 0.5, radio * 0.5)
			var u = rng.randf()
			var v = rng.randf()
			if u + v > 1.0:
				u = 1.0 - u
				v = 1.0 - v
			return (1.0 - u - v) * v0 + u * v1 + v * v2
		_: # Círculo (Forma 0 por defecto)
			var r = sqrt(rng.randf()) * radio
			var theta = rng.randf_range(0.0, TAU)
			return Vector2(cos(theta) * r, sin(theta) * r)

## Comprueba si un punto 2D está dentro de la forma geométrica del pincel
func _esta_dentro_de_forma(offset: Vector2, radio: float, forma: int) -> bool:
	match forma:
		1: # Cuadrado
			return abs(offset.x) <= radio and abs(offset.y) <= radio
		2: # Triángulo equilátero
			var w = radio * 1.73205
			var v0 = Vector2(0.0, -radio)
			var v1 = Vector2(w * 0.5, radio * 0.5)
			var v2 = Vector2(-w * 0.5, radio * 0.5)
			var d1 = (offset.x - v1.x) * (v0.y - v1.y) - (offset.y - v1.y) * (v0.x - v1.x)
			var d2 = (offset.x - v2.x) * (v1.y - v2.y) - (offset.y - v2.y) * (v1.x - v2.x)
			var d3 = (offset.x - v0.x) * (v2.y - v0.y) - (offset.y - v0.y) * (v2.x - v0.x)
			var neg = (d1 < 0) or (d2 < 0) or (d3 < 0)
			var pos = (d1 > 0) or (d2 > 0) or (d3 > 0)
			return !(neg and pos)
		_: # Círculo
			return offset.length_squared() <= radio * radio


## Elimina todas las instancias pintadas
func limpiar_pasto_pintado() -> void:
	datos_pasto_pintado.clear()
	if multimesh:
		multimesh.instance_count = 0

func _actualizar_multimesh_pintado() -> void:
	if multimesh == null:
		generar()
		return

	var total = datos_pasto_pintado.size()
	multimesh.instance_count = total
	for i in range(total):
		multimesh.set_instance_transform(i, datos_pasto_pintado[i])

## Crea una malla de briznas afiladas en punta con curvatura y normales hemisféricas estilizadas
func _crear_malla_pasto_procedural() -> ArrayMesh:
	var num_briznas: int = max(1, briznas_por_manojo if briznas_por_manojo != null else 4)
	var h_cfg: float = alto_pasto if (alto_pasto != null and alto_pasto > 0.0) else 0.40
	var w_cfg: float = ancho_pasto if (ancho_pasto != null and ancho_pasto > 0.0) else 0.16
	var curva_cfg: float = curvatura_puntas if curvatura_puntas != null else 0.10

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rng = RandomNumberGenerator.new()
	rng.seed = 12345 # Semilla constante para que la forma base del mechón sea consistente

	for i in range(num_briznas):
		var angulo_base = i * (TAU / float(num_briznas))
		var angulo = angulo_base + rng.randf_range(-0.15, 0.15)
		var cos_a = cos(angulo)
		var sin_a = sin(angulo)

		var perp_x = -sin_a
		var perp_z = cos_a

		var factor_alto = rng.randf_range(0.85, 1.15)
		var h_actual = h_cfg * factor_alto
		var h_mid = h_actual * 0.55
		var w_base = w_cfg * 0.5
		var w_mid = w_base * 0.65
		var curva = curva_cfg * factor_alto

		var offset_mid = Vector3(cos_a * curva * 0.4, 0.0, sin_a * curva * 0.4)
		var offset_tip = Vector3(cos_a * curva, 0.0, sin_a * curva)

		var p_bl = Vector3(-perp_x * w_base, 0.0, -perp_z * w_base)
		var p_br = Vector3(perp_x * w_base, 0.0, perp_z * w_base)
		var p_ml = Vector3(-perp_x * w_mid, h_mid, -perp_z * w_mid) + offset_mid
		var p_mr = Vector3(perp_x * w_mid, h_mid, perp_z * w_mid) + offset_mid
		var p_tip = Vector3(0.0, h_actual, 0.0) + offset_tip

		var normal = Vector3(cos_a * 0.45, 0.78, sin_a * 0.45).normalized()

		# --- Segmento Inferior (Quad) ---
		st.set_normal(normal)
		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(p_bl)

		st.set_normal(normal)
		st.set_uv(Vector2(1.0, 0.0))
		st.add_vertex(p_br)

		st.set_normal(normal)
		st.set_uv(Vector2(0.85, 0.55))
		st.add_vertex(p_mr)

		st.set_normal(normal)
		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(p_bl)

		st.set_normal(normal)
		st.set_uv(Vector2(0.85, 0.55))
		st.add_vertex(p_mr)

		st.set_normal(normal)
		st.set_uv(Vector2(0.15, 0.55))
		st.add_vertex(p_ml)

		# --- Segmento Superior (Punta) ---
		st.set_normal(normal)
		st.set_uv(Vector2(0.15, 0.55))
		st.add_vertex(p_ml)

		st.set_normal(normal)
		st.set_uv(Vector2(0.85, 0.55))
		st.add_vertex(p_mr)

		st.set_normal(normal)
		st.set_uv(Vector2(0.5, 1.0))
		st.add_vertex(p_tip)

	return st.commit()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# En modo AUTO, actualizar el material cada frame según la cámara activa.
	# Esto garantiza que en multijugador LAN el pasto muestre el color correcto
	# para el personaje cuya cámara está activa en este cliente.
	if modo_reino == 0:
		var nuevo_es_fantasma = _detectar_es_fantasma_por_camara_activa()
		var mat_correcto = material_espiritual if nuevo_es_fantasma else material_fisico
		if material_override != mat_correcto:
			material_override = mat_correcto
			_shader_mat = material_override as ShaderMaterial if material_override is ShaderMaterial else null

	if not interactuar_con_personajes:
		return

	if _shader_mat == null and material_override is ShaderMaterial:
		_shader_mat = material_override as ShaderMaterial

	if _shader_mat == null:
		return

	# Buscar y pasar la posición del Jugador
	if not is_instance_valid(_jugador_ref):
		var vivos = get_tree().get_nodes_in_group("vivos")
		if vivos.size() > 0:
			_jugador_ref = vivos[0] as Node3D

	if is_instance_valid(_jugador_ref):
		_shader_mat.set_shader_parameter("posicion_jugador", _jugador_ref.global_position)
	else:
		_shader_mat.set_shader_parameter("posicion_jugador", Vector3(0, 9999, 0))

	# Buscar y pasar la posición del Fantasma
	if not is_instance_valid(_fantasma_ref):
		var fantasmas = get_tree().get_nodes_in_group("fantasmas")
		if fantasmas.size() > 0:
			_fantasma_ref = fantasmas[0] as Node3D

	if is_instance_valid(_fantasma_ref):
		_shader_mat.set_shader_parameter("posicion_fantasma", _fantasma_ref.global_position)
	else:
		_shader_mat.set_shader_parameter("posicion_fantasma", Vector3(0, 9999, 0))
