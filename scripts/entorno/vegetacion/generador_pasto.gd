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
var _buffer_pintado: PackedFloat32Array = PackedFloat32Array()
const GRID_CELL_SIZE: float = 2.0
var _grid_instancias: Dictionary = {}
var _grid_valido: bool = false

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
			_grid_valido = false


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

## Activa la curvatura automática hacia abajo de las briznas cuando se acercan al borde de las islas.
@export var curvar_en_bordes_isla: bool = true:
	set(valor):
		curvar_en_bordes_isla = valor
		_actualizar_parametro_shader("habilitar_caida_borde", valor)
		_solicitar_regeneracion()

## Distancia desde el borde de la isla (en metros) donde las briznas comienzan a curvarse hacia abajo.
@export_range(0.1, 2.5, 0.05) var margen_curvatura_borde: float = 0.72:
	set(valor):
		margen_curvatura_borde = valor
		_solicitar_regeneracion()

## Cuánto caen verticalmente las puntas de las briznas en el borde de la isla (en metros).
@export_range(0.0, 1.5, 0.02) var caida_vertical_borde: float = 0.34:
	set(valor):
		caida_vertical_borde = valor
		_actualizar_parametro_shader("caida_borde_vertical", valor)

## Cuánto se asoman las briznas hacia afuera del borde al curvarse hacia abajo (en metros).
@export_range(0.0, 1.0, 0.02) var empuje_exterior_borde: float = 0.16:
	set(valor):
		empuje_exterior_borde = valor
		_actualizar_parametro_shader("empuje_borde_exterior", valor)

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
var _curvatura_borde_editor_sincronizada: bool = false
var _curvatura_borde_editor_v2: bool = false
var _curvatura_borde_editor_v3: bool = false
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

	# El material físico conserva los parámetros definidos por la escena, para
	# que la vista de juego coincida exactamente con la previsualización del editor.

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

	if multimesh.transform_format != MultiMesh.TRANSFORM_3D or not multimesh.use_custom_data:
		multimesh.instance_count = 0
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = true

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
		var custom_borde_auto: PackedColorArray = _calcular_custom_data_bordes(transforms_generados)
		multimesh.instance_count = count
		for i in range(count):
			multimesh.set_instance_transform(i, transforms_generados[i])
			multimesh.set_instance_custom_data(i, custom_borde_auto[i])
		var aabb_calc = AABB(Vector3(-half_x - 1.0, -1.0, -half_z - 1.0), Vector3(area.x + 2.0, (alto_pasto if alto_pasto != null else 0.5) * 2.0 + 2.0, area.y + 2.0))
		multimesh.custom_aabb = aabb_calc
		custom_aabb = aabb_calc
	else:
		_construir_chunks_runtime(transforms_generados, mesh_a_usar)

# ==============================================================================
# MÉTODOS DEL PINCEL 3D (Pintar, Borrar, Limpiar)
# ==============================================================================

## Obtiene la altura y normal exacta sobre la cara triangular de la isla bajo una coordenada de mundo.
## Garantiza que lo que se pinta en el visor 3D se asiente en la superficie con 0 mm de error.
func _obtener_info_superficie_en(pos_mundo: Vector3, normal_defecto: Vector3) -> Dictionary:
	var islas: Array[Node] = _obtener_islas_escena()
	var mejor_isla: Node = null
	var menor_dist_vert: float = 99999.0
	var mejor_info: Dictionary = {}

	for isla in islas:
		if not is_instance_valid(isla) or not isla.is_inside_tree():
			continue
		var p_loc: Vector3 = isla.global_transform.affine_inverse() * pos_mundo
		var pos_xz := Vector2(p_loc.x, p_loc.z)
		if isla.has_method("tiene_punto_en_superficie") and isla.tiene_punto_en_superficie(pos_xz):
			var h_calc: float = 0.0
			var norm_isla: Vector3 = Vector3.UP
			var dist_borde: float = 999.0
			var dir_afuera := Vector2(1.0, 0.0)

			if isla.has_method("evaluar_punto_malla_superficie"):
				var info: Dictionary = isla.evaluar_punto_malla_superficie(pos_xz)
				dist_borde = float(info.get("dist_borde", 999.0))
				if dist_borde < -0.15:
					continue
				h_calc = float(info.get("altura", p_loc.y))
				norm_isla = info.get("normal", Vector3.UP)
				dir_afuera = info.get("dir_afuera", Vector2(1.0, 0.0))
			elif isla.has_method("calcular_altura_en"):
				h_calc = float(isla.calcular_altura_en(pos_xz))
				norm_isla = isla.calcular_normal_superficie_en(pos_xz) if isla.has_method("calcular_normal_superficie_en") else Vector3.UP

			var pt_mundo: Vector3 = isla.global_transform * Vector3(pos_xz.x, h_calc, pos_xz.y)
			var d_vert: float = absf(pos_mundo.y - pt_mundo.y)
			if d_vert < menor_dist_vert:
				menor_dist_vert = d_vert
				mejor_isla = isla
				var norm_mundo: Vector3 = (isla.global_transform.basis * norm_isla).normalized()
				mejor_info = {
					"isla": isla,
					"pos_mundo": pt_mundo,
					"normal_mundo": norm_mundo,
					"dist_borde": dist_borde,
					"dir_afuera": dir_afuera
				}

	if mejor_isla != null and menor_dist_vert < 3.5:
		return mejor_info

	return {
		"isla": null,
		"pos_mundo": pos_mundo,
		"normal_mundo": normal_defecto,
		"dist_borde": 999.0,
		"dir_afuera": Vector2(1.0, 0.0)
	}


## Agrega un conjunto de briznas con posiciones y normales ya verificadas en superficie
func agregar_instancias_pintadas(posiciones_mundo: Array[Vector3], normales_mundo: Array[Vector3]) -> void:
	if modo_distribucion != 0:
		modo_distribucion = 0

	_asegurar_datos_editables()

	var esc_range = variacion_escala if variacion_escala != null else Vector2(0.65, 1.25)
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var cos_max = cos(deg_to_rad(pendiente_maxima))
	var rad_max_pend = deg_to_rad(pendiente_maxima)
	var nuevas_instancias: Array[Transform3D] = []

	var inv_xf_pasto = global_transform.affine_inverse()
	var inv_basis = global_transform.basis.inverse() if alinear_con_superficie else Basis()

	for i in range(posiciones_mundo.size()):
		var norm_m = normales_mundo[i]
		# Filtro estricto: no colocar briznas en paredes, riscos ni pendientes excesivas
		if norm_m.dot(Vector3.UP) < cos_max:
			continue

		var pos_m = posiciones_mundo[i]
		var info_sup = _obtener_info_superficie_en(pos_m, norm_m)
		if info_sup.isla != null:
			pos_m = info_sup.pos_mundo
			norm_m = info_sup.normal_mundo

		var local_pos = inv_xf_pasto * pos_m
		var local_norm = (inv_basis * norm_m).normalized() if alinear_con_superficie else Vector3.UP

		var rot_y = rng.randf_range(0.0, TAU)
		var factor_esc = rng.randf_range(esc_range.x, esc_range.y)
		var escala = Vector3(factor_esc, factor_esc, factor_esc)

		var t = Transform3D()
		if alinear_con_superficie and abs(local_norm.dot(Vector3.UP)) < 0.999:
			var norm_suave: Vector3 = local_norm.lerp(Vector3.UP, 0.35).normalized()
			var eje_rot = Vector3.UP.cross(norm_suave).normalized()
			var angulo_rot = minf(Vector3.UP.angle_to(norm_suave), rad_max_pend * 0.65)
			if eje_rot.length_squared() > 0.001:
				t = t.rotated(eje_rot, angulo_rot)

		t = t.rotated_local(Vector3.UP, rot_y)
		t = t.scaled_local(escala)
		t.origin = local_pos - local_norm * enterramiento_raiz

		datos_pasto_pintado.append(t)
		nuevas_instancias.append(t)

	if not nuevas_instancias.is_empty():
		_datos_modificados = true
		_anadir_instancias_incrementales(nuevas_instancias)


func _escribir_instancia_en_buffer(buf: PackedFloat32Array, index: int, t: Transform3D, c: Color) -> void:
	var base: int = index * 16
	# Fila 0
	buf[base + 0] = t.basis.x.x
	buf[base + 1] = t.basis.y.x
	buf[base + 2] = t.basis.z.x
	buf[base + 3] = t.origin.x
	# Fila 1
	buf[base + 4] = t.basis.x.y
	buf[base + 5] = t.basis.y.y
	buf[base + 6] = t.basis.z.y
	buf[base + 7] = t.origin.y
	# Fila 2
	buf[base + 8] = t.basis.x.z
	buf[base + 9] = t.basis.y.z
	buf[base + 10] = t.basis.z.z
	buf[base + 11] = t.origin.z
	# Fila 3 (Curvatura y dirección al borde)
	buf[base + 12] = c.r
	buf[base + 13] = c.g
	buf[base + 14] = c.b
	buf[base + 15] = c.a


func _copiar_instancia_en_buffer(buf: PackedFloat32Array, dest_index: int, src_index: int) -> void:
	var dest_base: int = dest_index * 16
	var src_base: int = src_index * 16
	for k in range(16):
		buf[dest_base + k] = buf[src_base + k]


func _reconstruir_grid_espacial() -> void:
	_grid_instancias.clear()
	var total: int = datos_pasto_pintado.size()
	for i in range(total):
		var pos: Vector3 = datos_pasto_pintado[i].origin
		var cx: int = int(floor(pos.x / GRID_CELL_SIZE))
		var cz: int = int(floor(pos.z / GRID_CELL_SIZE))
		var key := Vector2i(cx, cz)
		if not _grid_instancias.has(key):
			_grid_instancias[key] = []
		_grid_instancias[key].append(i)
	_grid_valido = true


func _agregar_instancia_a_grid(idx: int, pos: Vector3) -> void:
	if not _grid_valido:
		return
	var cx: int = int(floor(pos.x / GRID_CELL_SIZE))
	var cz: int = int(floor(pos.z / GRID_CELL_SIZE))
	var key := Vector2i(cx, cz)
	if not _grid_instancias.has(key):
		_grid_instancias[key] = []
	_grid_instancias[key].append(idx)


func _actualizar_indice_en_grid(viejo_idx: int, nuevo_idx: int, pos: Vector3) -> void:
	if not _grid_valido:
		return
	var cx: int = int(floor(pos.x / GRID_CELL_SIZE))
	var cz: int = int(floor(pos.z / GRID_CELL_SIZE))
	var key := Vector2i(cx, cz)
	if _grid_instancias.has(key):
		var arr: Array = _grid_instancias[key]
		var pos_in_arr: int = arr.find(viejo_idx)
		if pos_in_arr != -1:
			arr[pos_in_arr] = nuevo_idx


func _remover_indice_de_grid(idx: int, pos: Vector3) -> void:
	if not _grid_valido:
		return
	var cx: int = int(floor(pos.x / GRID_CELL_SIZE))
	var cz: int = int(floor(pos.z / GRID_CELL_SIZE))
	var key := Vector2i(cx, cz)
	if _grid_instancias.has(key):
		var arr: Array = _grid_instancias[key]
		var pos_in_arr: int = arr.find(idx)
		if pos_in_arr != -1:
			arr.remove_at(pos_in_arr)


func obtener_posiciones_en_radio(centro_local: Vector3, radio: float) -> Array[Vector3]:
	var res: Array[Vector3] = []
	var total: int = datos_pasto_pintado.size()
	if total == 0:
		return res
	if not _grid_valido:
		_reconstruir_grid_espacial()

	var min_cx: int = int(floor((centro_local.x - radio) / GRID_CELL_SIZE))
	var max_cx: int = int(floor((centro_local.x + radio) / GRID_CELL_SIZE))
	var min_cz: int = int(floor((centro_local.z - radio) / GRID_CELL_SIZE))
	var max_cz: int = int(floor((centro_local.z + radio) / GRID_CELL_SIZE))
	var r2: float = radio * radio

	var vistos: Dictionary = {}
	for cx in range(min_cx, max_cx + 1):
		for cz in range(min_cz, max_cz + 1):
			var key := Vector2i(cx, cz)
			if _grid_instancias.has(key):
				for idx in _grid_instancias[key]:
					if not vistos.has(idx) and idx < total:
						vistos[idx] = true
						var p: Vector3 = datos_pasto_pintado[idx].origin
						var dx: float = p.x - centro_local.x
						var dz: float = p.z - centro_local.z
						if (dx * dx + dz * dz) <= r2:
							res.append(p)
	return res


func _sincronizar_buffer_desde_multimesh_o_datos() -> void:
	var total: int = datos_pasto_pintado.size()
	if multimesh != null and multimesh.use_custom_data and multimesh.instance_count == total and multimesh.buffer.size() == total * 16:
		_buffer_pintado = multimesh.buffer.duplicate()
	else:
		_actualizar_multimesh_pintado()
		return
	if not _grid_valido:
		_reconstruir_grid_espacial()


func _anadir_instancias_incrementales(nuevas: Array[Transform3D]) -> void:
	if nuevas.is_empty():
		return
	_datos_modificados = true
	_indices_por_isla.clear()

	if not Engine.is_editor_hint():
		_actualizar_multimesh_pintado()
		return

	if multimesh == null:
		generar()
		return

	if not multimesh.use_custom_data:
		_actualizar_multimesh_pintado()
		return

	var total_actual: int = datos_pasto_pintado.size()
	var k: int = nuevas.size()
	var count_anterior: int = total_actual - k

	if _buffer_pintado.size() != count_anterior * 16:
		_sincronizar_buffer_desde_multimesh_o_datos()
		if _buffer_pintado.size() == total_actual * 16:
			return

	if not _grid_valido:
		_reconstruir_grid_espacial()

	# Calcular curvatura SOLO para las K nuevas instancias (ultrarrápido O(K))
	var custom_nuevas: PackedColorArray = _calcular_custom_data_bordes(nuevas)

	# Ampliar buffer y escribir las nuevas instancias
	_buffer_pintado.resize(total_actual * 16)
	for i in range(k):
		var dest_idx: int = count_anterior + i
		var t: Transform3D = nuevas[i]
		_escribir_instancia_en_buffer(_buffer_pintado, dest_idx, t, custom_nuevas[i])
		_agregar_instancia_a_grid(dest_idx, t.origin)
		custom_aabb = custom_aabb.expand(t.origin)

	# Actualizar MultiMesh en una única llamada C++
	multimesh.instance_count = total_actual
	multimesh.buffer = _buffer_pintado
	multimesh.custom_aabb = custom_aabb


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

	var dist_min = distancia_minima_repintar
	if dist_min <= 0.0:
		dist_min = clampf(0.85 / sqrt(maxf(1.0, float(densidad))), 0.02, 1.5)
	var dist_min_sq = dist_min * dist_min

	# Rejilla local ultra-rápida para "No Repintar" O(1)
	var cell_size = maxf(0.15, dist_min)
	var grid_local: Dictionary = {}
	if evitar_repintar and not datos_pasto_pintado.is_empty():
		var r_query = radio + dist_min + 0.5
		var existentes_cercanas = obtener_posiciones_en_radio(local_center, r_query)
		for p in existentes_cercanas:
			var cx = int(floor(p.x / cell_size))
			var cz = int(floor(p.z / cell_size))
			var key = Vector2i(cx, cz)
			if not grid_local.has(key):
				grid_local[key] = []
			grid_local[key].append(Vector2(p.x, p.z))

	var rad_max_pend = deg_to_rad(pendiente_maxima)
	var nuevas_instancias: Array[Transform3D] = []

	for _i in range(cantidad):
		var offset_2d = _generar_offset_forma(rng, radio, forma_pincel)
		var pos_instancia = local_center + Vector3(offset_2d.x, 0.0, offset_2d.y)
		var pos_m = to_global(pos_instancia)
		var norm_m = normal_mundo

		# Asentar directamente sobre la malla triangular exacta de la isla
		var info_sup = _obtener_info_superficie_en(pos_m, norm_m)
		if info_sup.isla == null:
			continue # Ignorar puntos que caen en el vacío fuera de la isla
		pos_m = info_sup.pos_mundo
		norm_m = info_sup.normal_mundo
		pos_instancia = to_local(pos_m)

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

		var local_normal = (global_transform.basis.inverse() * norm_m).normalized() if alinear_con_superficie else Vector3.UP

		var rot_y = rng.randf_range(0.0, TAU)
		var factor_esc = rng.randf_range(esc_range.x, esc_range.y)
		var escala = Vector3(factor_esc, factor_esc, factor_esc)

		var t = Transform3D()
		if alinear_con_superficie and abs(local_normal.dot(Vector3.UP)) < 0.999:
			var norm_suave: Vector3 = local_normal.lerp(Vector3.UP, 0.35).normalized()
			var eje_rot = Vector3.UP.cross(norm_suave).normalized()
			var angulo_rot = minf(Vector3.UP.angle_to(norm_suave), rad_max_pend * 0.65)
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
	var total_actual: int = datos_pasto_pintado.size()
	if total_actual == 0:
		return

	if not _grid_valido:
		_reconstruir_grid_espacial()

	if _buffer_pintado.size() != total_actual * 16:
		_sincronizar_buffer_desde_multimesh_o_datos()

	var local_center: Vector3 = to_local(pos_mundo)
	var min_cx: int = int(floor((local_center.x - radio_borrado) / GRID_CELL_SIZE))
	var max_cx: int = int(floor((local_center.x + radio_borrado) / GRID_CELL_SIZE))
	var min_cz: int = int(floor((local_center.z - radio_borrado) / GRID_CELL_SIZE))
	var max_cz: int = int(floor((local_center.z + radio_borrado) / GRID_CELL_SIZE))

	var candidatos_set: Dictionary = {}
	for cx in range(min_cx, max_cx + 1):
		for cz in range(min_cz, max_cz + 1):
			var key := Vector2i(cx, cz)
			if _grid_instancias.has(key):
				for idx in _grid_instancias[key]:
					candidatos_set[idx] = true

	if candidatos_set.is_empty():
		return

	var indices_a_borrar: Array[int] = []
	for idx in candidatos_set.keys():
		if idx >= total_actual:
			continue
		var t: Transform3D = datos_pasto_pintado[idx]
		var offset := Vector2(t.origin.x - local_center.x, t.origin.z - local_center.z)
		if _esta_dentro_de_forma(offset, radio_borrado, forma_pincel):
			indices_a_borrar.append(idx)

	if indices_a_borrar.is_empty():
		return

	indices_a_borrar.sort()
	var current_count: int = total_actual

	for i in range(indices_a_borrar.size() - 1, -1, -1):
		var idx: int = indices_a_borrar[i]
		var last_idx: int = current_count - 1
		var pos_borrada: Vector3 = datos_pasto_pintado[idx].origin
		_remover_indice_de_grid(idx, pos_borrada)

		if idx < last_idx:
			var t_last: Transform3D = datos_pasto_pintado[last_idx]
			datos_pasto_pintado[idx] = t_last
			_copiar_instancia_en_buffer(_buffer_pintado, idx, last_idx)
			_actualizar_indice_en_grid(last_idx, idx, t_last.origin)

		current_count -= 1

	datos_pasto_pintado.resize(current_count)
	_buffer_pintado.resize(current_count * 16)
	_indices_por_isla.clear()
	_datos_modificados = true

	if multimesh != null:
		multimesh.instance_count = current_count
		if current_count > 0:
			multimesh.buffer = _buffer_pintado
		else:
			multimesh.custom_aabb = AABB()
			custom_aabb = AABB()


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

	var perim_ant: Array = isla._perimetro_pts_anterior if ("_perimetro_pts_anterior" in isla) else []
	var max_r_ant: float = 0.0
	for p_ant in perim_ant:
		var r_a: float = Vector2(p_ant.x, p_ant.z).length()
		if r_a > max_r_ant:
			max_r_ant = r_a

	var radio_x: float = maxf((float(isla.ancho) * 0.5 * 1.35) if ("ancho" in isla) else 50.0, max_r_ant * 1.25)
	var radio_z: float = maxf((float(isla.largo) * 0.5 * 1.35) if ("largo" in isla) else 50.0, max_r_ant * 1.25)
	var rx_sq: float = radio_x * radio_x
	var rz_sq: float = radio_z * radio_z
	var prof_roca: float = float(isla.profundidad_roca) if ("profundidad_roca" in isla) else 10.0
	var alt_sup: float = float(isla.altura_superficie) if ("altura_superficie" in isla) else 0.0
	var alt_max: float = float(isla.altura_montana) if ("altura_montana" in isla) else 10.0
	var tiene_calc_h: bool = isla.has_method("calcular_altura_en")
	var tiene_estimar: bool = isla.has_method("_estimar_radio_en_angulo")

	var tiene_eval_malla: bool = isla.has_method("evaluar_punto_malla_superficie")

	for i in range(datos_pasto_pintado.size()):
		var t: Transform3D = datos_pasto_pintado[i]
		var p_isla: Vector3 = mat_pasto_a_isla * t.origin
		if absf(p_isla.x) > radio_x or absf(p_isla.z) > radio_z:
			continue
		var pos_xz := Vector2(p_isla.x, p_isla.z)
		var dentro: bool = false
		if isla.has_method("tiene_punto_en_superficie"):
			dentro = isla.tiene_punto_en_superficie(pos_xz)
		elif not perim_ant.is_empty() and tiene_estimar:
			var ang_p: float = atan2(pos_xz.y, pos_xz.x)
			var r_ant: float = float(isla._estimar_radio_en_angulo(ang_p, perim_ant))
			if pos_xz.length() <= r_ant + 0.15:
				dentro = true
		elif (pos_xz.x * pos_xz.x) / rx_sq + (pos_xz.y * pos_xz.y) / rz_sq <= 1.0:
			dentro = true
		if not dentro:
			continue
		if p_isla.y < -prof_roca * 0.7 or p_isla.y > alt_sup + alt_max + 15.0:
			continue
		if tiene_eval_malla:
			var info_chk: Dictionary = isla.evaluar_punto_malla_superficie(pos_xz)
			var d_borde: float = float(info_chk.get("dist_borde", 999.0))
			if d_borde < -0.15:
				continue
			var h_malla: float = float(info_chk.get("altura", 0.0))
			if absf(p_isla.y - h_malla) > 1.25:
				continue
		elif tiene_calc_h:
			var h: float = float(isla.calcular_altura_en(pos_xz))
			if absf(p_isla.y - h) > 1.25:
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


## Adapta dinámicamente la altura (Y), el radio perimetral y la orientación de las briznas pintadas
## a la malla triangular real y forma/tamaño de una isla, actualizando también la curvatura de sus bordes.
func adaptar_a_superficie_isla(isla: Node, centro_afectado: Vector2 = Vector2.INF, radio_afectado: float = -1.0) -> int:
	if modo_distribucion != 0:
		return 0
	_asegurar_datos_editables()
	if datos_pasto_pintado.is_empty():
		return 0
	if not is_instance_valid(isla) or not isla.has_method("calcular_altura_en"):
		return 0

	var usar_filtro_trazo: bool = (radio_afectado > 0.0 and centro_afectado.x != INF)
	if not usar_filtro_trazo:
		_indices_por_isla.erase(isla)

	var indices: Array = _obtener_indices_de_isla(isla)
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
	var basis_isla_a_mundo: Basis = isla.global_transform.basis if (is_inside_tree() and isla.is_inside_tree()) else isla.transform.basis

	var r_stroke_margen: float = radio_afectado + 0.6
	var r_stroke_sq: float = r_stroke_margen * r_stroke_margen

	var min_pasto_x: float = -INF
	var max_pasto_x: float = INF
	var min_pasto_z: float = -INF
	var max_pasto_z: float = INF
	if usar_filtro_trazo:
		var c_pasto: Vector3 = mat_isla_a_pasto * Vector3(centro_afectado.x, 0.0, centro_afectado.y)
		min_pasto_x = c_pasto.x - r_stroke_margen
		max_pasto_x = c_pasto.x + r_stroke_margen
		min_pasto_z = c_pasto.z - r_stroke_margen
		max_pasto_z = c_pasto.z + r_stroke_margen

	# Detectar si la silueta o tamaño de la isla fue modificada explícitamente por el usuario
	var perim_ant: Array = isla._perimetro_pts_anterior if ("_perimetro_pts_anterior" in isla) else []
	var perim_act: Array = isla._perimetro_pts_cache if ("_perimetro_pts_cache" in isla) else []
	var tiene_estimar: bool = isla.has_method("_estimar_radio_en_angulo")
	var tiene_eval_malla: bool = isla.has_method("evaluar_punto_malla_superficie")
	var silueta_modificada_usr: bool = bool(isla._silueta_modificada_por_usuario) if ("_silueta_modificada_por_usuario" in isla) else false
	var silueta_cambio: bool = false
	if silueta_modificada_usr and not usar_filtro_trazo and not perim_ant.is_empty() and not perim_act.is_empty():
		if perim_ant.size() != perim_act.size():
			silueta_cambio = true
		else:
			for k in range(perim_act.size()):
				var p_a: Vector3 = perim_ant[k]
				var p_b: Vector3 = perim_act[k]
				if absf(p_a.x - p_b.x) > 0.005 or absf(p_a.z - p_b.z) > 0.005:
					silueta_cambio = true
					break

	var rot_isla_a_pasto_basis: Basis = mat_isla_a_pasto.basis
	var rad_max_pend: float = deg_to_rad(pendiente_maxima)
	var margen_curva: float = maxf(margen_curvatura_borde, 0.15)
	var eps: float = 0.35
	var adaptadas: int = 0

	for idx in indices:
		var t: Transform3D = datos_pasto_pintado[idx]

		if usar_filtro_trazo:
			if t.origin.x < min_pasto_x or t.origin.x > max_pasto_x or t.origin.z < min_pasto_z or t.origin.z > max_pasto_z:
				continue

		var pos_loc_isla: Vector3 = mat_pasto_a_isla * t.origin

		if usar_filtro_trazo:
			var dx_s: float = pos_loc_isla.x - centro_afectado.x
			var dz_s: float = pos_loc_isla.z - centro_afectado.y
			if (dx_s * dx_s + dz_s * dz_s) > r_stroke_sq:
				continue

		var pos_xz := Vector2(pos_loc_isla.x, pos_loc_isla.z)

		# Si cambió el tamaño o la forma de la isla en el Inspector, escalar proporcionalmente la posición radial de la brizna
		if silueta_cambio and tiene_estimar and pos_xz.length_squared() > 0.0001:
			var ang_r: float = atan2(pos_xz.y, pos_xz.x)
			var r_ant: float = float(isla._estimar_radio_en_angulo(ang_r, perim_ant))
			var r_nue: float = float(isla._estimar_radio_en_angulo(ang_r, perim_act))
			if r_ant > 0.05 and r_nue > 0.05:
				pos_xz *= (r_nue / r_ant)

		var h_calc: float = 0.0
		var nueva_norm_isla: Vector3 = Vector3.UP
		var dist_al_borde: float = 999.0
		var dir_afuera_isla := Vector2(1.0, 0.0)

		if tiene_eval_malla:
			var info_malla: Dictionary = isla.evaluar_punto_malla_superficie(pos_xz)
			var t_rad: float = float(info_malla.get("t_radial", 0.5))
			# Solo si la silueta cambió y una brizna quedó fuera de la cuerda, reubicarla dentro del borde
			if silueta_cambio and t_rad > 0.992:
				var jitter_borde: float = float((idx * 73) % 29) / 29.0
				var t_objetivo: float = 0.955 + jitter_borde * 0.032
				pos_xz *= (t_objetivo / maxf(t_rad, 0.001))
				info_malla = isla.evaluar_punto_malla_superficie(pos_xz)

			h_calc = float(info_malla.get("altura", 0.0))
			nueva_norm_isla = info_malla.get("normal", Vector3.UP)
			dist_al_borde = float(info_malla.get("dist_borde", 999.0))
			if dist_al_borde < -0.15:
				continue
			if absf(pos_loc_isla.y - h_calc) > 1.25:
				continue
			# Micro-variación radial determinista para que la transición de curvatura no forme una línea rígida
			var jitter_curva: float = (float((idx * 53) % 37) / 37.0 - 0.5) * (margen_curva * 0.28)
			dist_al_borde += jitter_curva
		else:
			h_calc = float(isla.calcular_altura_en(pos_xz))
			if absf(pos_loc_isla.y - h_calc) > 1.25:
				continue
			var h_x1: float = float(isla.calcular_altura_en(pos_xz + Vector2(eps, 0.0)))
			var h_z1: float = float(isla.calcular_altura_en(pos_xz + Vector2(0.0, eps)))
			var dx: float = (h_x1 - h_calc) / eps
			var dz: float = (h_z1 - h_calc) / eps
			nueva_norm_isla = Vector3(-dx, 1.0, -dz).normalized()

		var pos_sup_isla := Vector3(pos_xz.x, h_calc, pos_xz.y)
		var pt_isla_enraizado: Vector3 = pos_sup_isla - nueva_norm_isla * enterramiento_raiz
		var nueva_pos_local: Vector3 = mat_isla_a_pasto * pt_isla_enraizado

		var local_norm: Vector3 = (rot_isla_a_pasto_basis * nueva_norm_isla).normalized()
		var escala_actual: Vector3 = t.basis.get_scale()

		var fwd_x: float = t.basis.z.x
		var fwd_z: float = t.basis.z.z
		if fwd_x * fwd_x + fwd_z * fwd_z < 0.0001:
			fwd_x = t.basis.x.z
			fwd_z = -t.basis.x.x
		var ang_yaw: float = atan2(fwd_x, fwd_z)

		var t_nuevo := Transform3D()
		if alinear_con_superficie and absf(local_norm.dot(Vector3.UP)) < 0.999:
			var norm_suave: Vector3 = local_norm.lerp(Vector3.UP, 0.35).normalized()
			var eje_tilt: Vector3 = Vector3.UP.cross(norm_suave).normalized()
			var ang_tilt: float = minf(Vector3.UP.angle_to(norm_suave), rad_max_pend * 0.65)
			if eje_tilt.length_squared() > 0.001:
				t_nuevo = t_nuevo.rotated(eje_tilt, ang_tilt)

		t_nuevo = t_nuevo.rotated_local(Vector3.UP, ang_yaw)
		t_nuevo = t_nuevo.scaled_local(escala_actual)
		t_nuevo.origin = nueva_pos_local

		var delta_pos_sq: float = (nueva_pos_local - t.origin).length_squared()
		if delta_pos_sq > 0.000001 or absf(pos_loc_isla.y - pt_isla_enraizado.y) > 0.001 or silueta_cambio:
			datos_pasto_pintado[idx] = t_nuevo
			adaptadas += 1
			if multimesh != null and idx < multimesh.instance_count:
				multimesh.set_instance_transform(idx, t_nuevo)

		# Actualizar también el custom_data de curvatura de borde de esta instancia en vivo
		if multimesh != null and multimesh.use_custom_data and idx < multimesh.instance_count:
			var col_borde := Color(0.5, 0.5, 0.0, 0.0)
			if curvar_en_bordes_isla and dist_al_borde <= margen_curva and dist_al_borde >= -0.35:
				var t_b: float = clampf(1.0 - (maxf(dist_al_borde, 0.0) / margen_curva), 0.0, 1.0)
				var peso_b: float = t_b * t_b * (3.0 - 2.0 * t_b)
				if peso_b > 0.001:
					var dir_m: Vector3 = basis_isla_a_mundo * Vector3(dir_afuera_isla.x, 0.0, dir_afuera_isla.y)
					var dir_m_xz := Vector2(dir_m.x, dir_m.z)
					if dir_m_xz.length_squared() > 0.0001:
						dir_m_xz = dir_m_xz.normalized()
					else:
						dir_m_xz = dir_afuera_isla
					col_borde = Color(
						clampf(dir_m_xz.x * 0.5 + 0.5, 0.0, 1.0),
						clampf(dir_m_xz.y * 0.5 + 0.5, 0.0, 1.0),
						peso_b,
						1.0
					)
			multimesh.set_instance_custom_data(idx, col_borde)

	if not usar_filtro_trazo and isla in _islas_con_perimetro_anterior_procesado(isla):
		pass

	if adaptadas > 0:
		_datos_modificados = true

	return adaptadas


func _islas_con_perimetro_anterior_procesado(isla: Node) -> Array:
	if is_instance_valid(isla):
		if "_perimetro_pts_anterior" in isla and "_perimetro_pts_cache" in isla:
			isla._perimetro_pts_anterior = isla._perimetro_pts_cache.duplicate()
		if "_silueta_modificada_por_usuario" in isla:
			isla._silueta_modificada_por_usuario = false
	return []


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
	_buffer_pintado.clear()
	_grid_instancias.clear()
	_grid_valido = false
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

func _limpiar_historial_undo_viejo() -> void:
	if _snapshots_undo.size() > 20:
		var min_id = 999999999
		for k in _snapshots_undo.keys():
			if k < min_id:
				min_id = k
		_snapshots_undo.erase(min_id)

## Almacena una copia instantánea completa en RAM (transforms + buffer nativo GPU + AABB)
## Retorna un ID ligero de 4 bytes para que UndoRedo no congele ni transmita megabytes.
func guardar_snapshot_actual() -> int:
	var id = _siguiente_snapshot_id
	_siguiente_snapshot_id += 1
	var total = datos_pasto_pintado.size()
	var buf_copy = PackedFloat32Array()
	if _buffer_pintado.size() == total * 16:
		buf_copy = _buffer_pintado.duplicate()
	elif multimesh != null and multimesh.use_custom_data and multimesh.instance_count == total and multimesh.buffer.size() == total * 16:
		buf_copy = multimesh.buffer.duplicate()

	_snapshots_undo[id] = {
		"transforms": datos_pasto_pintado.duplicate(),
		"buffer": buf_copy,
		"aabb": custom_aabb
	}
	_limpiar_historial_undo_viejo()
	return id

## Retorna la cantidad de briznas registradas en un snapshot dado
func obtener_cantidad_en_snapshot(id: int) -> int:
	if _snapshots_undo.has(id):
		var snap = _snapshots_undo[id]
		if snap is Dictionary and snap.has("transforms"):
			return (snap["transforms"] as Array).size()
		elif snap is Array:
			return snap.size()
	return 0

## Almacena una copia de los datos en memoria y retorna un ID numérico ligero para el historial Undo/Redo.
## Esto evita enviar arrays gigantescos por el canal TCP del debugger de Godot.
func guardar_snapshot_undo(datos: Array) -> int:
	var id = _siguiente_snapshot_id
	_siguiente_snapshot_id += 1
	var arr: Array[Transform3D] = []
	for item in datos:
		if item is Transform3D:
			arr.append(item)

	var buf_copy = PackedFloat32Array()
	if _buffer_pintado.size() == arr.size() * 16:
		buf_copy = _buffer_pintado.duplicate()
	elif multimesh != null and multimesh.use_custom_data and multimesh.instance_count == arr.size() and multimesh.buffer.size() == arr.size() * 16:
		buf_copy = multimesh.buffer.duplicate()

	_snapshots_undo[id] = {
		"transforms": arr,
		"buffer": buf_copy,
		"aabb": custom_aabb
	}
	_limpiar_historial_undo_viejo()
	return id

## Restaura el snapshot correspondiente al ID en tiempo O(1) restaurando el buffer GPU directamente
func restaurar_snapshot_undo(id: int, ruta_archivo: String = "") -> void:
	if not _snapshots_undo.has(id):
		return
	var snap = _snapshots_undo[id]
	if snap is Dictionary and snap.has("transforms"):
		var arr: Array[Transform3D] = (snap["transforms"] as Array[Transform3D]).duplicate()
		datos_pasto_pintado = arr
		_indices_por_isla.clear()
		_datos_modificados = true
		archivo_datos_pasto = ruta_archivo
		_grid_valido = false

		if arr.is_empty():
			recurso_datos = null
			_buffer_pintado.clear()
			_grid_instancias.clear()
			if multimesh:
				multimesh.instance_count = 0
				multimesh.custom_aabb = AABB()
			custom_aabb = AABB()
		else:
			var buf: PackedFloat32Array = snap.get("buffer", PackedFloat32Array())
			if buf.size() == arr.size() * 16 and multimesh != null:
				# Restauración instantánea directa a MultiMesh (0.1 ms sin recálculo de mallas ni islas)
				_buffer_pintado = buf.duplicate()
				multimesh.instance_count = arr.size()
				multimesh.buffer = _buffer_pintado
				var snap_aabb: AABB = snap.get("aabb", AABB())
				if snap_aabb.size != Vector3.ZERO:
					custom_aabb = snap_aabb
					multimesh.custom_aabb = snap_aabb
			else:
				# Fallback por si el snapshot no contenía buffer
				_actualizar_multimesh_pintado()
		notify_property_list_changed()
	elif snap is Array:
		asignar_datos_pintados(snap, ruta_archivo)

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
	_grid_valido = false
	if arr.is_empty():
		recurso_datos = null
		_buffer_pintado.clear()
		_grid_instancias.clear()
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

func _obtener_islas_escena() -> Array[Node]:
	var islas: Array[Node] = []
	var tree: SceneTree = get_tree() if is_inside_tree() else null
	var root_node: Node = tree.root if tree != null else null
	var n_actual: Node = get_parent()
	while n_actual != null and n_actual != root_node:
		if n_actual.has_method("calcular_altura_en"):
			islas.append(n_actual)
			break
		n_actual = n_actual.get_parent()
	if islas.is_empty() and tree != null:
		for n in tree.get_nodes_in_group("islas"):
			if is_instance_valid(n) and n.has_method("calcular_altura_en") and not islas.has(n):
				islas.append(n)
	if get_parent() != null:
		for hijo in get_parent().get_children():
			if is_instance_valid(hijo) and hijo.has_method("calcular_altura_en") and not islas.has(hijo):
				islas.append(hijo)
	return islas


## Calcula para cada brizna su cercanía y dirección radial hacia el borde de su isla:
## - R, G: dirección horizontal hacia afuera del borde en espacio global (codificada en 0..1)
## - B: peso de curvatura hacia abajo (0.0 en el interior de la isla -> 1.0 en el filo del borde)
func _calcular_custom_data_bordes(datos: Array[Transform3D]) -> PackedColorArray:
	var total: int = datos.size()
	var resultado: PackedColorArray = PackedColorArray()
	resultado.resize(total)
	var color_neutro := Color(0.5, 0.5, 0.0, 0.0)
	for i in range(total):
		resultado[i] = color_neutro

	if not curvar_en_bordes_isla or total == 0:
		return resultado

	var islas: Array[Node] = _obtener_islas_escena()
	if islas.is_empty():
		return resultado

	var margen: float = maxf(margen_curvatura_borde, 0.15)
	var usar_global: bool = is_inside_tree()

	for isla in islas:
		if not is_instance_valid(isla):
			continue
		if "_perimetro_pts_cache" in isla and isla._perimetro_pts_cache.is_empty() and isla.has_method("regenerar"):
			isla.regenerar()

		var mat_pasto_a_isla: Transform3D
		if usar_global and isla.is_inside_tree():
			mat_pasto_a_isla = isla.global_transform.affine_inverse() * global_transform
		elif get_parent() == isla:
			mat_pasto_a_isla = transform
		else:
			mat_pasto_a_isla = isla.transform.affine_inverse() * transform

		var basis_isla_a_mundo: Basis = isla.global_transform.basis if (usar_global and isla.is_inside_tree()) else isla.transform.basis
		var ancho_isla: float = float(isla.ancho) if ("ancho" in isla) else 10.0
		var largo_isla: float = float(isla.largo) if ("largo" in isla) else 10.0
		var radio_x: float = ancho_isla * 0.5 * 1.35
		var radio_z: float = largo_isla * 0.5 * 1.35
		var prof_roca: float = float(isla.profundidad_roca) if ("profundidad_roca" in isla) else 10.0
		var alt_sup: float = float(isla.altura_superficie) if ("altura_superficie" in isla) else 0.0
		var alt_max: float = float(isla.altura_montana) if ("altura_montana" in isla) else 10.0
		var tiene_eval_malla: bool = isla.has_method("evaluar_punto_malla_superficie")
		var perim_pts: Array = isla._perimetro_pts_cache if ("_perimetro_pts_cache" in isla) else []
		var tiene_estimar: bool = isla.has_method("_estimar_radio_en_angulo") and not perim_pts.is_empty()

		for i in range(total):
			if resultado[i].b > 0.001:
				continue
			var p_isla: Vector3 = mat_pasto_a_isla * datos[i].origin
			if absf(p_isla.x) > radio_x or absf(p_isla.z) > radio_z:
				continue
			if p_isla.y < -prof_roca * 0.7 or p_isla.y > alt_sup + alt_max + 15.0:
				continue

			var pos_xz := Vector2(p_isla.x, p_isla.z)
			var r_actual: float = pos_xz.length()
			if r_actual < 0.01:
				continue

			var dist_al_borde: float = 999.0
			var dir_local_xz := Vector2(pos_xz.x / r_actual, pos_xz.y / r_actual)

			if tiene_eval_malla:
				var info_b: Dictionary = isla.evaluar_punto_malla_superficie(pos_xz)
				dist_al_borde = float(info_b.get("dist_borde", 999.0))
				dir_local_xz = info_b.get("dir_afuera", dir_local_xz)
				var jitter_c: float = (float((i * 53) % 37) / 37.0 - 0.5) * (margen * 0.28)
				dist_al_borde += jitter_c
			else:
				var ang: float = atan2(pos_xz.y, pos_xz.x)
				var r_borde: float = 0.0
				if tiene_estimar:
					r_borde = float(isla._estimar_radio_en_angulo(ang, perim_pts))
				else:
					var ca: float = cos(ang)
					var sa: float = sin(ang)
					var rx_b: float = ancho_isla * 0.5
					var rz_b: float = largo_isla * 0.5
					r_borde = (rx_b * rz_b) / maxf(sqrt(rx_b * rx_b * sa * sa + rz_b * rz_b * ca * ca), 0.01)
				dist_al_borde = r_borde - r_actual

			if dist_al_borde < -0.35 or dist_al_borde > margen:
				continue

			var t_borde: float = clampf(1.0 - (maxf(dist_al_borde, 0.0) / margen), 0.0, 1.0)
			var peso: float = t_borde * t_borde * (3.0 - 2.0 * t_borde)
			if peso <= 0.001:
				continue

			var dir_local := Vector3(dir_local_xz.x, 0.0, dir_local_xz.y)
			var dir_mundo: Vector3 = (basis_isla_a_mundo * dir_local)
			var dir_xz := Vector2(dir_mundo.x, dir_mundo.z)
			if dir_xz.length_squared() > 0.0001:
				dir_xz = dir_xz.normalized()
			else:
				dir_xz = dir_local_xz

			resultado[i] = Color(
				clampf(dir_xz.x * 0.5 + 0.5, 0.0, 1.0),
				clampf(dir_xz.y * 0.5 + 0.5, 0.0, 1.0),
				peso,
				1.0
			)

	return resultado


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

	if not multimesh.use_custom_data:
		multimesh.instance_count = 0
		multimesh.use_custom_data = true

	var total = datos.size()
	var custom_bordes: PackedColorArray = _calcular_custom_data_bordes(datos)
	_buffer_pintado.resize(total * 16)
	var min_pos = Vector3(999999.0, 999999.0, 999999.0)
	var max_pos = Vector3(-999999.0, -999999.0, -999999.0)

	for i in range(total):
		var t = datos[i]
		_escribir_instancia_en_buffer(_buffer_pintado, i, t, custom_bordes[i])
		var ox = t.origin.x
		var oy = t.origin.y
		var oz = t.origin.z
		if ox < min_pos.x: min_pos.x = ox
		if ox > max_pos.x: max_pos.x = ox
		if oy < min_pos.y: min_pos.y = oy
		if oy > max_pos.y: max_pos.y = oy
		if oz < min_pos.z: min_pos.z = oz
		if oz > max_pos.z: max_pos.z = oz

	multimesh.instance_count = total
	if total > 0:
		multimesh.buffer = _buffer_pintado
		var alt_extra = (alto_pasto if alto_pasto != null else 0.5) * 2.0 + 1.0
		min_pos -= Vector3(1.0, 0.5, 1.0)
		max_pos += Vector3(1.0, alt_extra, 1.0)
		var aabb_p = AABB(min_pos, max_pos - min_pos)
		multimesh.custom_aabb = aabb_p
		custom_aabb = aabb_p
	else:
		multimesh.custom_aabb = AABB()
		custom_aabb = AABB()

	_reconstruir_grid_espacial()

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

	# Agrupar las transformaciones y sus datos de borde en una cuadrícula espacial (X, Z) de TAMANO_CHUNK
	var custom_bordes: PackedColorArray = _calcular_custom_data_bordes(transforms)
	var celdas: Dictionary = {}
	var celdas_custom: Dictionary = {}
	for idx_t in range(transforms.size()):
		var t: Transform3D = transforms[idx_t]
		var cx = int(floor(t.origin.x / TAMANO_CHUNK))
		var cz = int(floor(t.origin.z / TAMANO_CHUNK))
		var key = Vector2i(cx, cz)
		if not celdas.has(key):
			celdas[key] = []
			celdas_custom[key] = []
		celdas[key].append(t)
		celdas_custom[key].append(custom_bordes[idx_t])

	var h_pasto = alto_pasto if alto_pasto != null else 0.45
	var mat_actual = material_override if material_override != null else material_fisico

	for key in celdas:
		var lista: Array = celdas[key]
		var lista_custom: Array = celdas_custom[key]
		var total_chunk = lista.size()
		if total_chunk == 0:
			continue

		var min_p = Vector3(999999.0, 999999.0, 999999.0)
		var max_p = Vector3(-999999.0, -999999.0, -999999.0)

		for i in range(total_chunk):
			var t_orig: Transform3D = lista[i]
			min_p.x = minf(min_p.x, t_orig.origin.x - 0.5)
			min_p.y = minf(min_p.y, t_orig.origin.y - 0.5)
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
		mm.use_custom_data = true
		mm.mesh = mesh_a_usar
		mm.instance_count = total_chunk

		for i in range(total_chunk):
			var t: Transform3D = lista[i]
			t.origin -= chunk_center
			mm.set_instance_transform(i, t)
			mm.set_instance_custom_data(i, lista_custom[i] as Color)

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

## Crea una malla de briznas afiladas en punta con 4 tramos verticales para una curvatura suave y continua en bordes
func _crear_malla_pasto_procedural() -> ArrayMesh:
	var num_briznas: int = max(1, briznas_por_manojo if briznas_por_manojo != null else 4)
	var h_cfg: float = alto_pasto if (alto_pasto != null and alto_pasto > 0.0) else 0.40
	var w_cfg: float = ancho_pasto if (ancho_pasto != null and ancho_pasto > 0.0) else 0.16
	var curva_cfg: float = curvatura_puntas if curvatura_puntas != null else 0.10

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rng = RandomNumberGenerator.new()
	rng.seed = 12345 # Semilla constante para que la forma base del mechón sea consistente

	var niveles_t: Array[float] = [0.0, 0.28, 0.56, 0.80]
	var anchos_rel: Array[float] = [0.50, 0.43, 0.32, 0.17]

	for i in range(num_briznas):
		var angulo_base: float = float(i) * (TAU / float(num_briznas))
		var angulo: float = angulo_base + rng.randf_range(-0.15, 0.15)
		var cos_a: float = cos(angulo)
		var sin_a: float = sin(angulo)

		var perp_x: float = -sin_a
		var perp_z: float = cos_a

		var factor_alto: float = rng.randf_range(0.85, 1.15)
		var h_actual: float = h_cfg * factor_alto
		var curva: float = curva_cfg * factor_alto
		var normal: Vector3 = Vector3(cos_a * 0.45, 0.78, sin_a * 0.45).normalized()

		var pts_l: Array[Vector3] = []
		var pts_r: Array[Vector3] = []

		for k in range(niveles_t.size()):
			var tk: float = niveles_t[k]
			var wk: float = w_cfg * anchos_rel[k]
			var hk: float = h_actual * tk
			var off_k: float = curva * pow(tk, 1.5)
			var centro_k := Vector3(cos_a * off_k, hk, sin_a * off_k)
			pts_l.append(centro_k + Vector3(-perp_x * wk, 0.0, -perp_z * wk))
			pts_r.append(centro_k + Vector3(perp_x * wk, 0.0, perp_z * wk))

		var p_tip := Vector3(cos_a * curva, h_actual, sin_a * curva)

		for k in range(niveles_t.size() - 1):
			var t0: float = niveles_t[k]
			var t1: float = niveles_t[k + 1]
			var bl: Vector3 = pts_l[k]
			var br: Vector3 = pts_r[k]
			var tl: Vector3 = pts_l[k + 1]
			var tr: Vector3 = pts_r[k + 1]

			st.set_normal(normal)
			st.set_uv(Vector2(0.0, t0))
			st.add_vertex(bl)

			st.set_normal(normal)
			st.set_uv(Vector2(1.0, t0))
			st.add_vertex(br)

			st.set_normal(normal)
			st.set_uv(Vector2(0.85, t1))
			st.add_vertex(tr)

			st.set_normal(normal)
			st.set_uv(Vector2(0.0, t0))
			st.add_vertex(bl)

			st.set_normal(normal)
			st.set_uv(Vector2(0.85, t1))
			st.add_vertex(tr)

			st.set_normal(normal)
			st.set_uv(Vector2(0.15, t1))
			st.add_vertex(tl)

		var last_idx: int = niveles_t.size() - 1
		var t_last: float = niveles_t[last_idx]
		st.set_normal(normal)
		st.set_uv(Vector2(0.15, t_last))
		st.add_vertex(pts_l[last_idx])

		st.set_normal(normal)
		st.set_uv(Vector2(0.85, t_last))
		st.add_vertex(pts_r[last_idx])

		st.set_normal(normal)
		st.set_uv(Vector2(0.5, 1.0))
		st.add_vertex(p_tip)

	return st.commit()

func _sincronizar_todas_las_islas_y_bordes(recargar_desde_disco: bool = false) -> void:
	if recargar_desde_disco and not archivo_datos_pasto.is_empty() and ResourceLoader.exists(archivo_datos_pasto):
		recurso_datos = ResourceLoader.load(archivo_datos_pasto, "", ResourceLoader.CACHE_MODE_REPLACE)
		if recurso_datos != null and "transforms" in recurso_datos:
			datos_pasto_pintado = (recurso_datos.transforms as Array[Transform3D]).duplicate()
			_indices_por_isla.clear()
			_datos_modificados = false
	if modo_distribucion == 0:
		var islas: Array[Node] = _obtener_islas_escena()
		for isla in islas:
			if is_instance_valid(isla):
				if "_silueta_modificada_por_usuario" in isla:
					isla._silueta_modificada_por_usuario = false
				adaptar_a_superficie_isla(isla)
	generar()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if not _curvatura_borde_editor_v3:
			_curvatura_borde_editor_v3 = true
			_sincronizar_todas_las_islas_y_bordes(true)
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
