@tool
extends MultiMeshInstance3D
class_name GeneradorPasto

const RecursoDatosPasto = preload("res://scripts/entorno/vegetacion/recurso_datos_pasto.gd")

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
@export_range(0.2, 30.0, 0.1, "or_greater") var radio_pincel: float = 1.5

## Densidad o cantidad de briznas del pincel (se adapta proporcionalmente al radio para mantener una densidad constante).
@export_range(1, 10000, 1, "or_greater") var densidad_pincel: int = 25

## Alinea la inclinación de las briznas con la pendiente/inclinación de la superficie donde pintas.
@export var alinear_con_superficie: bool = true

## Pendiente máxima en grados permitida para pintar pasto (evita que se pinte en paredes verticales, riscos y esquinas).
@export_range(10.0, 85.0, 1.0) var pendiente_maxima: float = 55.0

## Botón en el Inspector para limpiar automáticamente todas las briznas que hayan quedado en paredes, esquinas o riscos.
@export var limpiar_pasto_en_paredes: bool = false:
	set(valor):
		if valor:
			limpiar_pasto_en_pendientes()
			limpiar_pasto_en_paredes = false

## Forma geométrica del pincel (Círculo, Cuadrado, Triángulo, Corona, Sendero).
@export_enum("Circular (Redondo)", "Cuadrado", "Triangular", "Corona (Anillo)", "Sendero (Línea)") var forma_pincel: int = 0

## Si está activo, el pincel no colocará briznas en zonas donde ya se haya pintado pasto previamente.
@export var evitar_repintar: bool = false

## Distancia mínima de separación entre briznas para evitar repintar (en metros).
## Si se establece en 0.0, se calcula automáticamente según la densidad del pincel.
@export_range(0.0, 1.5, 0.01) var distancia_minima_repintar: float = 0.0

@export_group("Datos de Pasto Pintado (Binario)")
## Ruta al archivo binario (.res) que almacena las instancias pintadas.
## Almacenar las instancias en un archivo .res externo evita inflar la escena .tscn
## y elimina las advertencias del editor y los tirones de carga.
@export_file("*.res") var archivo_datos_pasto: String = "":
	set(valor):
		archivo_datos_pasto = valor
		if not _datos_modificados:
			_cargar_recurso_datos()
			if modo_distribucion == 0 and multimesh != null:
				_actualizar_multimesh_pintado()

## Variables en memoria (NO exportadas para que Godot NUNCA las escriba en texto dentro del .tscn)
var recurso_datos: Resource = null
var datos_pasto_pintado: Array[Transform3D] = []
var _datos_modificados: bool = false
var _inicializado: bool = false
var _indices_por_isla: Dictionary = {}

func _cargar_recurso_datos() -> void:
	if archivo_datos_pasto.is_empty():
		return
	if ResourceLoader.exists(archivo_datos_pasto):
		recurso_datos = load(archivo_datos_pasto)

## Obtiene el conjunto de transformaciones activas (prioriza memoria editada, luego recurso binario).
func obtener_datos_pintados() -> Array[Transform3D]:
	if _datos_modificados:
		return datos_pasto_pintado
	if not datos_pasto_pintado.is_empty():
		return datos_pasto_pintado
	if recurso_datos != null and "transforms" in recurso_datos and not recurso_datos.transforms.is_empty():
		return recurso_datos.transforms
	if not archivo_datos_pasto.is_empty() and ResourceLoader.exists(archivo_datos_pasto):
		_cargar_recurso_datos()
		if recurso_datos != null and "transforms" in recurso_datos:
			return recurso_datos.transforms
	return []

func _asegurar_datos_editables() -> void:
	if not _datos_modificados and datos_pasto_pintado.is_empty():
		var datos = obtener_datos_pintados()
		if not datos.is_empty():
			datos_pasto_pintado = (datos as Array[Transform3D]).duplicate()


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

## Profundidad de enraizamiento en el terreno (en metros). Un valor pequeño (0.005 = 5mm)
## asienta las raíces perfectamente en la superficie sin que atraviesen la base ni floten.
@export_range(0.0, 0.05, 0.001, "or_greater") var enterramiento_raiz: float = 0.005:
	set(valor):
		var diff = valor - enterramiento_raiz
		enterramiento_raiz = valor
		if _inicializado and abs(diff) > 0.0001 and Engine.is_editor_hint():
			_ajustar_profundidad_raiz(diff)

@export_group("Plano y Materiales (Físico vs Espiritual)")
@export_enum("Auto (Según Personaje)", "Plano Físico (Verde)", "Plano Espiritual (Azul)") var modo_reino: int = 0:
	set(valor):
		modo_reino = valor
		_actualizar_material_por_reino()

@export var material_fisico: Material = preload("res://shaders/entorno/vegetacion/pasto_fisico_mat.tres")
@export var material_espiritual: Material = preload("res://shaders/entorno/vegetacion/pasto_espiritual_mat.tres")

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

@export_group("Rendimiento y Visibilidad")
## Distancia máxima en metros a la que se dibuja el pasto durante el juego (100m con fade continuo por brizna).
@export_range(10.0, 300.0, 5.0) var distancia_visibilidad_juego: float = 100.0:
	set(valor):
		distancia_visibilidad_juego = valor
		_aplicar_configuracion_visibilidad()

## Si está activo, en el editor de Godot no habrá límite de distancia para diseñar y construir cómodamente sin que el pasto desaparezca.
@export var deshabilitar_culling_en_editor: bool = true:
	set(valor):
		deshabilitar_culling_en_editor = valor
		_aplicar_configuracion_visibilidad()

@export_group("Acciones")
@export var forzar_regenerar: bool = false:
	set(_v):
		generar()

var _jugador_ref: Node3D = null
var _fantasma_ref: Node3D = null
var _pos_jugador_ant: Vector3 = Vector3(0, 9999, 0)
var _pos_fantasma_ant: Vector3 = Vector3(0, 9999, 0)
var _tiempo_reintento_busqueda: float = 0.0
var _shader_mat: ShaderMaterial = null
var _chunks: Array[MultiMeshInstance3D] = []
const TAMANO_CHUNK: float = 8.0

func _actualizar_parametro_shader(param: String, valor: Variant) -> void:
	if material_override is ShaderMaterial:
		(material_override as ShaderMaterial).set_shader_parameter(param, valor)
	if material_fisico is ShaderMaterial:
		(material_fisico as ShaderMaterial).set_shader_parameter(param, valor)
	if material_espiritual is ShaderMaterial:
		(material_espiritual as ShaderMaterial).set_shader_parameter(param, valor)

func _aplicar_configuracion_visibilidad() -> void:
	if not is_inside_tree():
		return
	if Engine.is_editor_hint() and deshabilitar_culling_en_editor:
		# En el editor: culling por distancia desactivado para ver todo el nivel libremente
		visibility_range_end = 0.0
		visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	else:
		if modo_distribucion == 0:
			# En runtime modo pintado (chunks): los chunks hijos manejan individualmente su propia distancia.
			# El nodo padre contenedor NO debe tener visibility_range_end para no ocultar chunks en otras islas.
			visibility_range_end = 0.0
		else:
			# En el juego: culling estricto de alto rendimiento con corte limpio y margen de histéresis
			visibility_range_end = distancia_visibilidad_juego
		visibility_range_end_margin = 4.0
		visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_auto_guardar_en_recurso_si_es_necesario()
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		if modo_distribucion == 0:
			_actualizar_multimesh_pintado()

func _auto_guardar_en_recurso_si_es_necesario() -> void:
	if modo_distribucion != 0:
		return
	if _datos_modificados and not datos_pasto_pintado.is_empty():
		guardar_a_recurso_binario("", false)
	elif not datos_pasto_pintado.is_empty() and archivo_datos_pasto.is_empty():
		guardar_a_recurso_binario("", false)

	# Fundamental: vaciar temporalmente las instancias del multimesh del nodo para que
	# Godot NO serialice instancias dentro del archivo de texto .tscn.
	if multimesh:
		multimesh.instance_count = 0

func _enter_tree() -> void:
	if not is_in_group("generador_pasto"):
		add_to_group("generador_pasto")

func _ready() -> void:
	if not is_in_group("generador_pasto"):
		add_to_group("generador_pasto")
	# Asegurar instancias independientes de materiales para cada reino.
	# Esto es ESENCIAL en multijugador LAN donde ambos personajes comparten el mismo
	# proceso de Godot: sin duplicar, ambos modificarían el mismo ShaderMaterial.
	if material_fisico != null:
		material_fisico = material_fisico.duplicate()
	else:
		material_fisico = load("res://shaders/entorno/vegetacion/pasto_fisico_mat.tres").duplicate()

	if material_espiritual != null:
		material_espiritual = material_espiritual.duplicate()
	else:
		material_espiritual = load("res://shaders/entorno/vegetacion/pasto_espiritual_mat.tres").duplicate()

	material_fisico.render_priority = 2
	material_espiritual.render_priority = 2

	# Asegurar colores exactos e inalterables para cada reino
	if material_fisico is ShaderMaterial:
		var mat_fisico := material_fisico as ShaderMaterial
		mat_fisico.set_shader_parameter("color_base", Color(0.38, 0.24, 0.02, 1.0))
		mat_fisico.set_shader_parameter("color_punta", Color(0.66, 0.49, 0.07, 1.0))

	if material_espiritual is ShaderMaterial:
		var mat_espiritual := material_espiritual as ShaderMaterial
		mat_espiritual.set_shader_parameter("color_base", Color(0.02, 0.16, 0.36, 1.0))
		mat_espiritual.set_shader_parameter("color_punta", Color(0.045, 0.35, 0.65, 1.0))
		mat_espiritual.set_shader_parameter("color_base_secundario", Color(0.015, 0.13, 0.30, 1.0))
		mat_espiritual.set_shader_parameter("color_punta_secundario", Color(0.05, 0.38, 0.68, 1.0))
		mat_espiritual.set_shader_parameter("variacion_macro_escala", 0.10)
		mat_espiritual.set_shader_parameter("variacion_brizna_fuerza", 0.45)
		mat_espiritual.set_shader_parameter("suavizado_gradiente", 0.80)
		mat_espiritual.set_shader_parameter("curva_gradiente", 1.25)
		mat_espiritual.set_shader_parameter("saturacion", 0.90)
		mat_espiritual.set_shader_parameter("brillo_puntas", 0.03)
		mat_espiritual.set_shader_parameter("translucidencia", 0.05)
		mat_espiritual.set_shader_parameter("oclusion_base", 0.38)

	# Optimización de renderizado y culling
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 6.0
	_aplicar_configuracion_visibilidad()

	_conectar_senales_personaje()
	_buscar_referencias_personajes()
	_actualizar_material_por_reino()
	generar()
	_inicializado = true

func _get_red_manager() -> Node:
	if Engine.is_editor_hint():
		return null
	if is_inside_tree():
		return get_tree().root.get_node_or_null("RedManager")
	return null

func _buscar_referencias_personajes() -> void:
	if Engine.is_editor_hint():
		return
	var red_mgr = _get_red_manager()
	if not is_instance_valid(_jugador_ref):
		if is_instance_valid(red_mgr) and "jugador_vivo" in red_mgr and is_instance_valid(red_mgr.jugador_vivo):
			_jugador_ref = red_mgr.jugador_vivo
		elif is_inside_tree():
			var vivos = get_tree().get_nodes_in_group("vivos")
			if vivos.size() > 0:
				_jugador_ref = vivos[0] as Node3D

	if not is_instance_valid(_fantasma_ref):
		if is_instance_valid(red_mgr) and "fantasma" in red_mgr and is_instance_valid(red_mgr.fantasma):
			_fantasma_ref = red_mgr.fantasma
		elif is_inside_tree():
			var fantasmas = get_tree().get_nodes_in_group("fantasmas")
			if fantasmas.size() > 0:
				_fantasma_ref = fantasmas[0] as Node3D

func _conectar_senales_personaje() -> void:
	if Engine.is_editor_hint():
		return
	var red_mgr = _get_red_manager()
	if is_instance_valid(red_mgr):
		if red_mgr.has_signal("personaje_solo_cambiado") and not red_mgr.personaje_solo_cambiado.is_connected(_on_personaje_cambiado):
			red_mgr.personaje_solo_cambiado.connect(_on_personaje_cambiado)
		if red_mgr.has_signal("reino_cambiado") and not red_mgr.reino_cambiado.is_connected(_on_reino_cambiado):
			red_mgr.reino_cambiado.connect(_on_reino_cambiado)

func _on_personaje_cambiado(_nuevo_personaje: String) -> void:
	_actualizar_material_por_reino()

func _on_reino_cambiado(es_fantasma: bool) -> void:
	if modo_reino == 0:
		var mat_correcto = material_espiritual if es_fantasma else material_fisico
		if mat_correcto != null and material_override != mat_correcto:
			material_override = mat_correcto
			_shader_mat = material_override as ShaderMaterial if material_override is ShaderMaterial else null
			_actualizar_material_chunks()
			print("[GeneradorPasto] Reino cambiado (es_fantasma=%s) -> Material: %s" % [es_fantasma, "ESPIRITUAL (Azul)" if es_fantasma else "FISICO (Dorado/Otoño)"])

func _actualizar_material_chunks() -> void:
	for chunk in _chunks:
		if is_instance_valid(chunk) and chunk.material_override != material_override:
			chunk.material_override = material_override

func _actualizar_material_por_reino() -> void:
	if material_fisico == null:
		material_fisico = load("res://shaders/entorno/vegetacion/pasto_fisico_mat.tres")
	if material_espiritual == null:
		material_espiritual = load("res://shaders/entorno/vegetacion/pasto_espiritual_mat.tres")
	if material_fisico:
		material_fisico.render_priority = 2
	if material_espiritual:
		material_espiritual.render_priority = 2

	var mat_correcto: Material = null
	if modo_reino == 1:
		mat_correcto = material_fisico
	elif modo_reino == 2:
		mat_correcto = material_espiritual
	else:
		# Modo AUTO: en un solo jugador usamos RedManager o la cámara activa.
		# En multijugador (LAN o en línea) ambos personajes están en la misma escena,
		# así que debemos detectar quién controla la cámara activa.
		var es_fantasma = _detectar_es_fantasma_por_camara_activa()
		mat_correcto = material_espiritual if es_fantasma else material_fisico

	if mat_correcto != null and material_override == mat_correcto and _chunks.size() > 0 and is_instance_valid(_chunks[0]) and _chunks[0].material_override == mat_correcto:
		return

	material_override = mat_correcto
	if material_override is ShaderMaterial:
		_shader_mat = material_override as ShaderMaterial
	else:
		_shader_mat = null
	_actualizar_material_chunks()
	print("[GeneradorPasto] Material asignado: %s" % ["ESPIRITUAL (Azul)" if material_override == material_espiritual else "FISICO (Dorado/Otoño)"])

# Determina si el personaje que actualmente controla la cámara activa es fantasma.
# Funciona tanto en un jugador (personaje_activo_solo) como en multijugador LAN/online.
func _detectar_es_fantasma_por_camara_activa() -> bool:
	if Engine.is_editor_hint():
		return false

	# 1. RedManager es la fuente autoritativa en runtime (un jugador y multijugador)
	var red_mgr = _get_red_manager()
	if is_instance_valid(red_mgr):
		if red_mgr.has_method("es_reino_espiritual_activo"):
			return red_mgr.es_reino_espiritual_activo()
		if "es_un_jugador" in red_mgr and red_mgr.es_un_jugador and "personaje_activo_solo" in red_mgr:
			return red_mgr.personaje_activo_solo == "fantasma"
		if "peer_personajes" in red_mgr and red_mgr.has_method("get_mi_peer_id"):
			var mi_id = red_mgr.get_mi_peer_id()
			if red_mgr.peer_personajes.has(mi_id):
				return red_mgr.peer_personajes[mi_id] == "fantasma"

	# 2. Fallback por cámara activa sólo si RedManager no está presente
	var cam = get_viewport().get_camera_3d() if is_inside_tree() else null
	if is_instance_valid(cam):
		if cam.name.contains("Transicion"):
			if is_instance_valid(red_mgr) and "transicion_en_progreso" in red_mgr and red_mgr.transicion_en_progreso:
				return (cam.cull_mask & (1 << 2)) != 0

		# Subir por el árbol de nodos desde la cámara buscando el CharacterBase dueño
		var nodo = cam.get_parent()
		while is_instance_valid(nodo):
			if nodo.is_in_group("fantasmas") or nodo.name.to_lower().contains("fantasma"):
				return true
			if nodo.is_in_group("vivos") or nodo.name.to_lower().contains("jugador") or nodo.name.to_lower().contains("vivo"):
				return false
			nodo = nodo.get_parent()

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
		if Engine.is_editor_hint():
			_actualizar_multimesh_pintado()
		else:
			_construir_chunks_runtime(obtener_datos_pintados(), mesh_a_usar)
		return

	# --- MODO 1: ÁREA RECTANGULAR AUTOMÁTICA ---
	var count = cantidad_instancias if (cantidad_instancias != null and cantidad_instancias > 0) else 20000
	var area = area_tamano if area_tamano != null else Vector2(50.0, 50.0)
	var esc_range = variacion_escala if variacion_escala != null else Vector2(0.65, 1.25)

	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var half_x = area.x * 0.5
	var half_z = area.y * 0.5

	var transforms_generados: Array[Transform3D] = []
	transforms_generados.resize(count)

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

				transforms_generados[idx] = t
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

			transforms_generados[i] = t

	if Engine.is_editor_hint():
		multimesh.instance_count = count
		for i in range(count):
			multimesh.set_instance_transform(i, transforms_generados[i])
		var aabb_calc = AABB(Vector3(-half_x - 1.0, -1.0, -half_z - 1.0), Vector3(area.x + 2.0, (alto_pasto if alto_pasto != null else 0.5) * 2.0 + 2.0, area.y + 2.0))
		multimesh.custom_aabb = aabb_calc
		custom_aabb = aabb_calc
	else:
		_construir_chunks_runtime(transforms_generados, mesh_a_usar)

# ==============================================================================
# MÉTODOS DEL PINCEL 3D (Pintar, Borrar, Limpiar)
# ==============================================================================

## Agrega un conjunto de briznas con posiciones y normales ya verificadas en superficie
func agregar_instancias_pintadas(posiciones_mundo: Array[Vector3], normales_mundo: Array[Vector3]) -> void:
	if modo_distribucion != 0:
		modo_distribucion = 0

	_asegurar_datos_editables()

	var esc_range = variacion_escala if variacion_escala != null else Vector2(0.65, 1.25)
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var cos_max = cos(deg_to_rad(pendiente_maxima))
	var nuevas_instancias: Array[Transform3D] = []

	var inv_xf_pasto = global_transform.affine_inverse()
	var inv_basis = global_transform.basis.inverse() if alinear_con_superficie else Basis()

	for i in range(posiciones_mundo.size()):
		var norm_m = normales_mundo[i]
		# Filtro estricto: no colocar briznas en paredes, riscos ni pendientes excesivas
		if norm_m.dot(Vector3.UP) < cos_max:
			continue

		var pos_m = posiciones_mundo[i]
		var local_pos = inv_xf_pasto * pos_m
		var local_norm = (inv_basis * norm_m).normalized() if alinear_con_superficie else Vector3.UP

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
		t.origin = local_pos - local_norm * enterramiento_raiz

		datos_pasto_pintado.append(t)
		nuevas_instancias.append(t)

	if not nuevas_instancias.is_empty():
		_indices_por_isla.clear()
		_datos_modificados = true
		_actualizar_multimesh_pintado()


func _anadir_instancias_incrementales(_nuevas: Array[Transform3D]) -> void:
	_indices_por_isla.clear()
	_actualizar_multimesh_pintado()


## Pinta un conjunto de briznas según la forma del pincel (Círculo, Cuadrado, Triángulo)
func pintar_en_posicion(pos_mundo: Vector3, normal_mundo: Vector3) -> void:
	var cos_max = cos(deg_to_rad(pendiente_maxima))
	if normal_mundo.dot(Vector3.UP) < cos_max:
		return # No pintar sobre paredes, riscos o esquinas pronunciadas

	if modo_distribucion != 0:
		modo_distribucion = 0 # Cambiar automáticamente a modo manual al pintar

	_asegurar_datos_editables()

	var local_center = to_local(pos_mundo)
	var esc_range = variacion_escala if variacion_escala != null else Vector2(0.65, 1.25)
	var radio = max(0.1, radio_pincel)
	var densidad = max(1, densidad_pincel)

	# Adaptar la cantidad de briznas al área geométrica real (m²) con tope de seguridad
	var r2 = radio * radio
	var area_forma: float = PI * r2
	match forma_pincel:
		1: area_forma = 4.0 * r2
		2: area_forma = 1.299038 * r2
		3: area_forma = 0.75 * PI * r2
		4: area_forma = r2
		_: area_forma = PI * r2

	var cantidad = clampi(int(round(densidad * area_forma)), 1, 30000)

	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var local_normal = (global_transform.basis.inverse() * normal_mundo).normalized() if alinear_con_superficie else Vector3.UP

	var dist_min = distancia_minima_repintar
	if dist_min <= 0.0:
		dist_min = clampf(0.85 / sqrt(maxf(1.0, float(densidad))), 0.02, 1.5)
	var dist_min_sq = dist_min * dist_min

	# Rejilla local ultra-rápida para "No Repintar" O(1)
	var cell_size = maxf(0.15, dist_min)
	var grid_local: Dictionary = {}
	if evitar_repintar and not datos_pasto_pintado.is_empty():
		var r_query_sq = (radio + dist_min + 0.5) * (radio + dist_min + 0.5)
		for t_existente in datos_pasto_pintado:
			var d2 = Vector2(t_existente.origin.x - local_center.x, t_existente.origin.z - local_center.z).length_squared()
			if d2 <= r_query_sq:
				var cx = int(floor(t_existente.origin.x / cell_size))
				var cz = int(floor(t_existente.origin.z / cell_size))
				var key = Vector2i(cx, cz)
				if not grid_local.has(key):
					grid_local[key] = []
				grid_local[key].append(Vector2(t_existente.origin.x, t_existente.origin.z))

	var nuevas_instancias: Array[Transform3D] = []

	for _i in range(cantidad):
		var offset_2d = _generar_offset_forma(rng, radio, forma_pincel)
		var pos_instancia = local_center + Vector3(offset_2d.x, 0.0, offset_2d.y)

		if evitar_repintar and not grid_local.is_empty():
			var cx = int(floor(pos_instancia.x / cell_size))
			var cz = int(floor(pos_instancia.z / cell_size))
			var ocupado = false
			for dx in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					var key = Vector2i(cx + dx, cz + dz)
					if grid_local.has(key):
						for p2 in grid_local[key]:
							if (p2.x - pos_instancia.x) * (p2.x - pos_instancia.x) + (p2.y - pos_instancia.z) * (p2.y - pos_instancia.z) < dist_min_sq:
								ocupado = true
								break
					if ocupado:
						break
				if ocupado:
					break
			if ocupado:
				continue

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
		t.origin = pos_instancia - local_normal * enterramiento_raiz

		datos_pasto_pintado.append(t)
		nuevas_instancias.append(t)

		if evitar_repintar:
			var cx_new = int(floor(pos_instancia.x / cell_size))
			var cz_new = int(floor(pos_instancia.z / cell_size))
			var key_new = Vector2i(cx_new, cz_new)
			if not grid_local.has(key_new):
				grid_local[key_new] = []
			grid_local[key_new].append(Vector2(pos_instancia.x, pos_instancia.z))

	if not nuevas_instancias.is_empty():
		_datos_modificados = true
		_anadir_instancias_incrementales(nuevas_instancias)


## Borra las briznas que se encuentren dentro del área de la forma en la posición dada
func borrar_en_posicion(pos_mundo: Vector3, radio_borrado: float) -> void:
	if modo_distribucion != 0:
		return
	_asegurar_datos_editables()
	if datos_pasto_pintado.is_empty():
		return

	var local_center = to_local(pos_mundo)
	var datos_filtrados: Array[Transform3D] = []

	for t in datos_pasto_pintado:
		var offset = Vector2(t.origin.x - local_center.x, t.origin.z - local_center.z)
		if not _esta_dentro_de_forma(offset, radio_borrado, forma_pincel):
			datos_filtrados.append(t)

	if datos_filtrados.size() != datos_pasto_pintado.size():
		datos_pasto_pintado = datos_filtrados
		_indices_por_isla.clear()
		_datos_modificados = true
		_actualizar_multimesh_pintado()


## Elimina automáticamente todas las briznas que hayan quedado pintadas en paredes verticales, esquinas o riscos.
func limpiar_pasto_en_pendientes(angulo_max: float = -1.0) -> int:
	var ang = angulo_max if angulo_max > 0.0 else pendiente_maxima
	var cos_min = cos(deg_to_rad(ang))
	_asegurar_datos_editables()
	if datos_pasto_pintado.is_empty():
		return 0

	var datos_filtrados: Array[Transform3D] = []
	var eliminadas = 0

	# Buscar islas flotantes en la escena para comprobar cota de superficie superior
	var islas: Array[Node] = []
	var n_actual = get_parent()
	while n_actual != null and n_actual != get_tree().root:
		if n_actual.has_method("calcular_altura_en"):
			islas.append(n_actual)
			break
		n_actual = n_actual.get_parent()

	if islas.is_empty() and get_tree() != null:
		for n in get_tree().get_nodes_in_group("islas"):
			if n.has_method("calcular_altura_en"):
				islas.append(n)
		if islas.is_empty() and get_parent() != null:
			for hijo in get_parent().get_children():
				if hijo.has_method("calcular_altura_en"):
					islas.append(hijo)

	for t in datos_pasto_pintado:
		var es_invalida = false

		# 1. Comprobar inclinación de la brizna (en espacio global)
		var up_brizna = (global_transform.basis * t.basis.y).normalized()
		if up_brizna.dot(Vector3.UP) < cos_min:
			es_invalida = true

		# 2. Comprobar si cayó en el cuerpo rocoso inferior de una isla
		if not es_invalida and not islas.is_empty():
			var pos_mundo = to_global(t.origin)
			for isla in islas:
				var pos_loc_isla = isla.to_local(pos_mundo)
				var r_max_isla = maxf(isla.ancho, isla.largo) * 0.75 if ("ancho" in isla) else 50.0
				if Vector2(pos_loc_isla.x, pos_loc_isla.z).length() <= r_max_isla:
					var h_sup = isla.calcular_altura_en(Vector2(pos_loc_isla.x, pos_loc_isla.z))
					if pos_loc_isla.y < h_sup - 0.25:
						es_invalida = true
						break

		if es_invalida:
			eliminadas += 1
		else:
			datos_filtrados.append(t)

	if eliminadas > 0:
		datos_pasto_pintado = datos_filtrados
		_indices_por_isla.clear()
		_datos_modificados = true
		_actualizar_multimesh_pintado()
		print("[GeneradorPasto] Se limpiaron con éxito %d briznas en paredes y esquinas (pendiente > %.1f°)." % [eliminadas, ang])

	return eliminadas


## Obtiene de forma indexada O(1) los índices de las instancias de pasto pertenecientes a una isla
func _obtener_indices_de_isla(isla: Node) -> Array:
	if _indices_por_isla.has(isla):
		return _indices_por_isla[isla]

	var indices: Array = []
	if not is_instance_valid(isla) or datos_pasto_pintado.is_empty():
		return indices

	var mat_pasto_a_isla: Transform3D
	if is_inside_tree() and isla.is_inside_tree():
		mat_pasto_a_isla = isla.global_transform.affine_inverse() * global_transform
	elif get_parent() == isla:
		mat_pasto_a_isla = transform
	else:
		mat_pasto_a_isla = isla.transform.affine_inverse() * transform

	var radio_x = (isla.ancho * 0.5 * 1.25) if ("ancho" in isla) else 50.0
	var radio_z = (isla.largo * 0.5 * 1.25) if ("largo" in isla) else 50.0
	var rx_sq = radio_x * radio_x
	var rz_sq = radio_z * radio_z
	var prof_roca = isla.profundidad_roca if ("profundidad_roca" in isla) else 10.0
	var alt_sup = isla.altura_superficie if ("altura_superficie" in isla) else 0.0
	var alt_max = isla.altura_montana if ("altura_montana" in isla) else 10.0
	var tiene_calc_h = isla.has_method("calcular_altura_en")

	for i in range(datos_pasto_pintado.size()):
		var t = datos_pasto_pintado[i]
		var p_isla = mat_pasto_a_isla * t.origin
		if abs(p_isla.x) > radio_x or abs(p_isla.z) > radio_z:
			continue
		var pos_xz = Vector2(p_isla.x, p_isla.z)
		if isla.has_method("tiene_punto_en_superficie"):
			if not isla.tiene_punto_en_superficie(pos_xz):
				continue
		else:
			if (pos_xz.x * pos_xz.x) / rx_sq + (pos_xz.y * pos_xz.y) / rz_sq > 1.15:
				continue
		if p_isla.y < -prof_roca * 0.7 or p_isla.y > alt_sup + alt_max + 12.0:
			continue
		if tiene_calc_h:
			var h = isla.calcular_altura_en(pos_xz)
			if abs(p_isla.y - h) > 4.5:
				continue
		indices.append(i)

	_indices_por_isla[isla] = indices
	return indices


## Mueve y rota automáticamente las briznas de pasto que pertenecen a una isla cuando ésta se desplaza.
## Elimina completamente el problema del "pasto flotante" en el editor y en gameplay.
func mover_pasto_con_isla(isla: Node, ant: Transform3D, act: Transform3D) -> int:
	if modo_distribucion != 0:
		return 0
	if not is_instance_valid(isla) or isla == self:
		return 0
	if isla.is_ancestor_of(self):
		return 0
	if not is_inside_tree() or not isla.is_inside_tree():
		return 0
	if ant.is_equal_approx(act):
		return 0

	_asegurar_datos_editables()
	if datos_pasto_pintado.is_empty():
		return 0

	var delta_local = global_transform.affine_inverse() * act * ant.affine_inverse() * global_transform
	var indices = _obtener_indices_de_isla(isla)
	if indices.is_empty():
		return 0

	for idx in indices:
		var t_ant = datos_pasto_pintado[idx]
		var t_nuevo = delta_local * t_ant
		datos_pasto_pintado[idx] = t_nuevo
		if multimesh != null and idx < multimesh.instance_count:
			multimesh.set_instance_transform(idx, t_nuevo)

	_datos_modificados = true
	return indices.size()


## Adapta dinámicamente la altura (Y) y orientación de las briznas pintadas a la deformación del terreno de una isla.
## Optimizado analíticamente sin raycasts físicos ni bloqueos de I/O para ejecución en <1ms.
func adaptar_a_superficie_isla(isla: Node, centro_afectado: Vector2 = Vector2.INF, radio_afectado: float = -1.0) -> int:
	if modo_distribucion != 0:
		return 0
	_asegurar_datos_editables()
	if datos_pasto_pintado.is_empty():
		return 0
	if not is_instance_valid(isla) or not isla.has_method("calcular_altura_en"):
		return 0

	var indices = _obtener_indices_de_isla(isla)
	if indices.is_empty():
		return 0

	# 1. Precomputar matrices de transformación entre el generador de pasto y la isla
	var mat_pasto_a_isla: Transform3D
	if is_inside_tree() and isla.is_inside_tree():
		mat_pasto_a_isla = isla.global_transform.affine_inverse() * global_transform
	elif get_parent() == isla:
		mat_pasto_a_isla = transform
	else:
		mat_pasto_a_isla = isla.transform.affine_inverse() * transform
	var mat_isla_a_pasto: Transform3D = mat_pasto_a_isla.affine_inverse()

	# Filtro espacial de pincel localizado O(K)
	var usar_filtro_trazo = (radio_afectado > 0.0 and centro_afectado.x != INF)
	var r_stroke_margen = radio_afectado + 0.6
	var r_stroke_sq = r_stroke_margen * r_stroke_margen

	# Pre-calcular caja envolvente en espacio del pasto para filtrado O(1) de 2 floats sin matrix multiplication
	var min_pasto_x = -INF
	var max_pasto_x = INF
	var min_pasto_z = -INF
	var max_pasto_z = INF
	if usar_filtro_trazo:
		var c_pasto = mat_isla_a_pasto * Vector3(centro_afectado.x, 0.0, centro_afectado.y)
		min_pasto_x = c_pasto.x - r_stroke_margen
		max_pasto_x = c_pasto.x + r_stroke_margen
		min_pasto_z = c_pasto.z - r_stroke_margen
		max_pasto_z = c_pasto.z + r_stroke_margen

	var rot_isla_a_pasto_basis = mat_isla_a_pasto.basis
	var rad_max_pend = deg_to_rad(pendiente_maxima)
	var eps = 0.35
	var adaptadas = 0

	for idx in indices:
		var t = datos_pasto_pintado[idx]

		# Filtro A ultrarrápido: Descarte O(1) con 4 floats en espacio local de pasto
		if usar_filtro_trazo:
			if t.origin.x < min_pasto_x or t.origin.x > max_pasto_x or t.origin.z < min_pasto_z or t.origin.z > max_pasto_z:
				continue

		# Transformar origen de la brizna al espacio local de la isla O(1)
		var pos_loc_isla = mat_pasto_a_isla * t.origin

		# Filtro B: Radio radial circular del trazo
		if usar_filtro_trazo:
			var dx_s = pos_loc_isla.x - centro_afectado.x
			var dz_s = pos_loc_isla.z - centro_afectado.y
			if (dx_s * dx_s + dz_s * dz_s) > r_stroke_sq:
				continue

		var px = pos_loc_isla.x
		var pz = pos_loc_isla.z
		var pos_xz = Vector2(px, pz)

		# 2. Calcular la nueva altura analítica exacta con 3 muestras forward (60% más rápido)
		var h_calc = isla.calcular_altura_en(pos_xz)
		var h_x1 = isla.calcular_altura_en(pos_xz + Vector2(eps, 0.0))
		var h_z1 = isla.calcular_altura_en(pos_xz + Vector2(0.0, eps))
		var dx = (h_x1 - h_calc) / eps
		var dz = (h_z1 - h_calc) / eps
		var nueva_norm_isla = Vector3(-dx, 1.0, -dz).normalized()
		var pos_sup_isla = Vector3(px, h_calc, pz)

		# Aplicar enterramiento de raíz perpendicular a la superficie
		var pt_isla_enraizado = pos_sup_isla - nueva_norm_isla * enterramiento_raiz

		# Convertir la nueva posición al espacio local de este GeneradorPasto
		var nueva_pos_local = mat_isla_a_pasto * pt_isla_enraizado

		# Solo actualizar si la altura o posición cambió
		var delta_pos_sq = (nueva_pos_local - t.origin).length_squared()
		if delta_pos_sq > 0.000004 or abs(pos_loc_isla.y - pt_isla_enraizado.y) > 0.01:
			var local_norm = (rot_isla_a_pasto_basis * nueva_norm_isla).normalized()
			var escala_actual = t.basis.get_scale()

			# Extraer azimut horizontal original proyectado al plano XZ
			var fwd_x = t.basis.z.x
			var fwd_z = t.basis.z.z
			if fwd_x * fwd_x + fwd_z * fwd_z < 0.0001:
				fwd_x = t.basis.x.z
				fwd_z = -t.basis.x.x
			var ang_yaw = atan2(fwd_x, fwd_z)

			# Construir orientación limpia sin distorsión
			var t_nuevo = Transform3D()
			if alinear_con_superficie and abs(local_norm.dot(Vector3.UP)) < 0.999:
				var eje_tilt = Vector3.UP.cross(local_norm).normalized()
				var ang_tilt = Vector3.UP.angle_to(local_norm)
				ang_tilt = minf(ang_tilt, rad_max_pend)
				if eje_tilt.length_squared() > 0.001:
					t_nuevo = t_nuevo.rotated(eje_tilt, ang_tilt)

			t_nuevo = t_nuevo.rotated_local(Vector3.UP, ang_yaw)
			t_nuevo = t_nuevo.scaled_local(escala_actual)
			t_nuevo.origin = nueva_pos_local

			datos_pasto_pintado[idx] = t_nuevo
			adaptadas += 1

			# Actualizar instancia en el MultiMesh inmediatamente
			if multimesh != null and idx < multimesh.instance_count:
				multimesh.set_instance_transform(idx, t_nuevo)

	if adaptadas > 0:
		_datos_modificados = true

	return adaptadas


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
		3: # Corona / Anillo (radio interior = 0.5 * radio)
			var r_in_sq = 0.25 * radio * radio
			var r_out_sq = radio * radio
			var r = sqrt(rng.randf_range(r_in_sq, r_out_sq))
			var theta = rng.randf_range(0.0, TAU)
			return Vector2(cos(theta) * r, sin(theta) * r)
		4: # Sendero / Línea (largo 2*radio, ancho 0.5*radio)
			return Vector2(rng.randf_range(-radio, radio), rng.randf_range(-radio * 0.25, radio * 0.25))
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
		3: # Corona / Anillo
			var d_sq = offset.length_squared()
			return d_sq <= radio * radio and d_sq >= 0.25 * radio * radio
		4: # Sendero / Línea
			return abs(offset.x) <= radio and abs(offset.y) <= radio * 0.25
		_: # Círculo
			return offset.length_squared() <= radio * radio


## Elimina todas las instancias pintadas
func limpiar_pasto_pintado() -> void:
	modo_distribucion = 0
	datos_pasto_pintado.clear()
	_indices_por_isla.clear()
	recurso_datos = null
	archivo_datos_pasto = ""
	_datos_modificados = true
	if multimesh:
		multimesh.instance_count = 0
		multimesh.custom_aabb = AABB()
	custom_aabb = AABB()
	notify_property_list_changed()

## Actualiza la visualización del multimesh con las briznas pintadas actuales
func actualizar_multimesh_pintado() -> void:
	_actualizar_multimesh_pintado()

var _snapshots_undo: Dictionary = {}
var _siguiente_snapshot_id: int = 1

## Almacena una copia de los datos en memoria y retorna un ID numérico ligero para el historial Undo/Redo.
## Esto evita enviar arrays gigantescos (de >4MB) por el canal TCP del debugger de Godot,
## previniendo el error "core/debugger/remote_debugger_peer.cpp:116".
func guardar_snapshot_undo(datos: Array) -> int:
	var id = _siguiente_snapshot_id
	_siguiente_snapshot_id += 1
	var arr: Array[Transform3D] = []
	for item in datos:
		if item is Transform3D:
			arr.append(item)
	_snapshots_undo[id] = arr
	# Mantener un historial en RAM acotado a los últimos 20 trazos
	if _snapshots_undo.size() > 20:
		var min_id = 999999999
		for k in _snapshots_undo.keys():
			if k < min_id:
				min_id = k
		_snapshots_undo.erase(min_id)
	return id

## Restaura el snapshot correspondiente al ID (invocado por Undo/Redo con carga de red de solo 4 bytes)
func restaurar_snapshot_undo(id: int, ruta_archivo: String = "") -> void:
	if _snapshots_undo.has(id):
		asignar_datos_pintados(_snapshots_undo[id], ruta_archivo)

## Asigna y actualiza directamente el arreglo de briznas pintadas (utilizado por Undo/Redo)
func asignar_datos_pintados(nuevos_datos: Array, ruta_archivo: String = "") -> void:
	var arr: Array[Transform3D] = []
	for item in nuevos_datos:
		if item is Transform3D:
			arr.append(item)
	datos_pasto_pintado = arr
	_indices_por_isla.clear()
	_datos_modificados = true
	archivo_datos_pasto = ruta_archivo
	if arr.is_empty():
		recurso_datos = null
		if multimesh:
			multimesh.instance_count = 0
			multimesh.custom_aabb = AABB()
		custom_aabb = AABB()
	else:
		_actualizar_multimesh_pintado()
	notify_property_list_changed()

## Ajusta en tiempo real la profundidad de las raíces de todas las briznas pintadas
func _ajustar_profundidad_raiz(diff: float) -> void:
	_asegurar_datos_editables()
	if datos_pasto_pintado.is_empty():
		return

	for i in range(datos_pasto_pintado.size()):
		var t = datos_pasto_pintado[i]
		var up_dir = t.basis.y.normalized()
		# Si diff > 0 (mayor enterramiento), baja a lo largo de la normal; si diff < 0 (menor enterramiento), sube a ras de suelo.
		t.origin -= up_dir * diff
		datos_pasto_pintado[i] = t
		if multimesh != null and i < multimesh.instance_count:
			multimesh.set_instance_transform(i, t)

	_datos_modificados = true
	if not archivo_datos_pasto.is_empty():
		guardar_a_recurso_binario(archivo_datos_pasto)

func _actualizar_multimesh_pintado() -> void:
	var datos = obtener_datos_pintados()
	if not Engine.is_editor_hint():
		var mesh_a_usar: Mesh = mesh_personalizado
		if mesh_a_usar == null:
			mesh_a_usar = _crear_malla_pasto_procedural()
		_construir_chunks_runtime(datos, mesh_a_usar)
		return

	if multimesh == null:
		generar()
		return

	var total = datos.size()
	multimesh.instance_count = total
	var min_pos = Vector3(999999.0, 999999.0, 999999.0)
	var max_pos = Vector3(-999999.0, -999999.0, -999999.0)

	for i in range(total):
		var t = datos[i]
		multimesh.set_instance_transform(i, t)
		var ox = t.origin.x
		var oy = t.origin.y
		var oz = t.origin.z
		if ox < min_pos.x: min_pos.x = ox
		if ox > max_pos.x: max_pos.x = ox
		if oy < min_pos.y: min_pos.y = oy
		if oy > max_pos.y: max_pos.y = oy
		if oz < min_pos.z: min_pos.z = oz
		if oz > max_pos.z: max_pos.z = oz

	if total > 0:
		var alt_extra = (alto_pasto if alto_pasto != null else 0.5) * 2.0 + 1.0
		min_pos -= Vector3(1.0, 0.5, 1.0)
		max_pos += Vector3(1.0, alt_extra, 1.0)
		var aabb_p = AABB(min_pos, max_pos - min_pos)
		multimesh.custom_aabb = aabb_p
		custom_aabb = aabb_p
	else:
		multimesh.custom_aabb = AABB()
		custom_aabb = AABB()

## Exporta las instancias pintadas actuales a un archivo de recurso binario (.res)
## y limpia el arreglo en escena para dejar el archivo .tscn ultraligero.
func guardar_a_recurso_binario(ruta_archivo: String = "", restaurar_multimesh_en_editor: bool = true) -> bool:
	var datos = obtener_datos_pintados()
	if datos.is_empty():
		push_warning("[GeneradorPasto] No hay instancias pintadas para exportar.")
		return false
	
	if ruta_archivo.is_empty():
		if not archivo_datos_pasto.is_empty():
			ruta_archivo = archivo_datos_pasto
		elif recurso_datos != null and not recurso_datos.resource_path.is_empty():
			ruta_archivo = recurso_datos.resource_path
		else:
			var prefijo := name.to_lower()
			if owner != null and not owner.scene_file_path.is_empty():
				prefijo = owner.scene_file_path.get_file().get_basename().to_lower().replace(" ", "_")
			elif is_inside_tree() and get_tree().current_scene != null and not get_tree().current_scene.scene_file_path.is_empty():
				prefijo = get_tree().current_scene.scene_file_path.get_file().get_basename().to_lower().replace(" ", "_")
			ruta_archivo = "res://scenes/levels/pasto_" + prefijo + "_datos.res"
	
	var res := RecursoDatosPasto.new()
	res.transforms = (datos as Array[Transform3D]).duplicate()
	var err := ResourceSaver.save(res, ruta_archivo)
	if err == OK:
		recurso_datos = res
		archivo_datos_pasto = ruta_archivo
		datos_pasto_pintado.clear()
		_datos_modificados = false
		_actualizar_multimesh_pintado()
		notify_property_list_changed()
		print("[GeneradorPasto] Datos exportados exitosamente a: ", ruta_archivo)
		return true
	else:
		push_error("[GeneradorPasto] Error al guardar recurso binario: ", err)
		return false

func _construir_chunks_runtime(transforms: Array[Transform3D], mesh_a_usar: Mesh) -> void:
	for chunk in _chunks:
		if is_instance_valid(chunk):
			chunk.queue_free()
	_chunks.clear()

	if transforms.is_empty() or mesh_a_usar == null:
		if multimesh:
			multimesh.instance_count = 0
		return

	# Agrupar las transformaciones en una cuadrícula espacial (X, Z) de TAMANO_CHUNK (12m x 12m)
	var celdas: Dictionary = {}
	for t in transforms:
		var cx = int(floor(t.origin.x / TAMANO_CHUNK))
		var cz = int(floor(t.origin.z / TAMANO_CHUNK))
		var key = Vector2i(cx, cz)
		if not celdas.has(key):
			celdas[key] = []
		celdas[key].append(t)

	var h_pasto = alto_pasto if alto_pasto != null else 0.45
	var mat_actual = material_override if material_override != null else material_fisico

	for key in celdas:
		var lista: Array = celdas[key]
		var total_chunk = lista.size()
		if total_chunk == 0:
			continue

		var min_p = Vector3(999999.0, 999999.0, 999999.0)
		var max_p = Vector3(-999999.0, -999999.0, -999999.0)

		for i in range(total_chunk):
			var t_orig: Transform3D = lista[i]
			min_p.x = minf(min_p.x, t_orig.origin.x - 0.5)
			min_p.y = minf(min_p.y, t_orig.origin.y - 0.2)
			min_p.z = minf(min_p.z, t_orig.origin.z - 0.5)
			max_p.x = maxf(max_p.x, t_orig.origin.x + 0.5)
			max_p.y = maxf(max_p.y, t_orig.origin.y + h_pasto + 0.5)
			max_p.z = maxf(max_p.z, t_orig.origin.z + 0.5)

		var chunk_center = (min_p + max_p) * 0.5
		var half_size = (max_p - min_p) * 0.5
		var aabb_local = AABB(-half_size, max_p - min_p)

		var chunk_inst = MultiMeshInstance3D.new()
		chunk_inst.name = "PastoChunk_%d_%d" % [key.x, key.y]
		chunk_inst.position = chunk_center

		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh_a_usar
		mm.instance_count = total_chunk

		for i in range(total_chunk):
			var t: Transform3D = lista[i]
			t.origin -= chunk_center
			mm.set_instance_transform(i, t)

		mm.custom_aabb = aabb_local
		chunk_inst.custom_aabb = aabb_local
		chunk_inst.multimesh = mm
		chunk_inst.material_override = mat_actual
		chunk_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chunk_inst.ignore_occlusion_culling = true
		chunk_inst.extra_cull_margin = 0.5
		chunk_inst.visibility_range_end = distancia_visibilidad_juego
		chunk_inst.visibility_range_end_margin = 8.0
		chunk_inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

		add_child(chunk_inst)
		_chunks.append(chunk_inst)

	# Vaciar el multimesh propio y AABB en runtime para permitir Frustum Culling limpio por chunks
	if multimesh:
		multimesh.instance_count = 0
		multimesh.custom_aabb = AABB()
	custom_aabb = AABB()

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

	if not interactuar_con_personajes:
		return

	if _shader_mat == null and material_override is ShaderMaterial:
		_shader_mat = material_override as ShaderMaterial

	if _shader_mat == null:
		return

	# Reintentar búsqueda de personajes si aún no son válidos (restringido a 1 vez por segundo para evitar GC churn)
	if not is_instance_valid(_jugador_ref) or not is_instance_valid(_fantasma_ref):
		_tiempo_reintento_busqueda += _delta
		if _tiempo_reintento_busqueda >= 1.0:
			_tiempo_reintento_busqueda = 0.0
			_buscar_referencias_personajes()

	# Actualizar posición Jugador solo si se movió (dirty check para evitar llamadas redundantes)
	var pos_j = _jugador_ref.global_position if is_instance_valid(_jugador_ref) else Vector3(0, 9999, 0)
	if pos_j.distance_squared_to(_pos_jugador_ant) > 0.0004:
		_pos_jugador_ant = pos_j
		_shader_mat.set_shader_parameter("posicion_jugador", pos_j)

	# Actualizar posición Fantasma solo si se movió
	var pos_f = _fantasma_ref.global_position if is_instance_valid(_fantasma_ref) else Vector3(0, 9999, 0)
	if pos_f.distance_squared_to(_pos_fantasma_ant) > 0.0004:
		_pos_fantasma_ant = pos_f
		_shader_mat.set_shader_parameter("posicion_fantasma", pos_f)
