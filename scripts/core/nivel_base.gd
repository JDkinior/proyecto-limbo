extends Node3D
class_name NivelBase

const CatalogoNiveles = preload("res://scripts/core/catalogo_niveles.gd")

## ==============================================================================
## CLASE MAESTRA DE NIVEL (NivelBase) - PROYECTO LIMBO
## Todo mapa o nivel debe heredar o tener este script adjunto a su nodo raíz.
## Administra:
## 1. Validación de contratos mínimos de nivel (personajes, UI, meta).
## 2. Optimización automática de renderizado, culling y sombras.
## 3. Conteo instantáneo de coleccionables e inicialización de métricas en ScoreManager.
## ==============================================================================

@export_group("Configuración del Nivel")
@export var tiempo_objetivo: float = 120.0 ## Tiempo en segundos para completar el nivel y obtener 3 estrellas.

@export_group("Intro del Capítulo")
@export var mostrar_intro_capitulo: bool = true ## Muestra el rótulo con fade-in al entrar al nivel.
@export_enum("1", "2", "3", "4") var capitulo: int = 1 ## Número de capítulo que corresponde a este nivel.
@export_multiline var titulo_capitulo_personalizado: String = "" ## Texto personalizado del rótulo. Si se deja vacío usa el nombre por defecto del capítulo.
@export_range(0.2, 4.0, 0.1) var tiempo_fade_in: float = 1.0
@export_range(0.5, 10.0, 0.1) var tiempo_visible: float = 2.5
@export_range(0.2, 4.0, 0.1) var tiempo_fade_out: float = 1.0

## Nombres por defecto para cada capítulo (delegado a CatalogoNiveles).
const NOMBRES_CAPITULOS := CatalogoNiveles.NOMBRES_CAPITULOS

const MAT_HIERBA_FANTASMA = preload("res://assets/materiales/entorno/m_isla_hierba_fantasma.tres")
const MAT_ROCA_FANTASMA = preload("res://assets/materiales/entorno/m_isla_roca_fantasma.tres")
const MAT_ESPIRITUAL = preload("res://assets/materiales/entorno/m_isla_espiritual.tres")
const MAT_PASTO_ESPIRITUAL = preload("res://shaders/entorno/vegetacion/pasto_espiritual_mat.tres")
const MAT_PASTO_FISICO = preload("res://shaders/entorno/vegetacion/pasto_fisico_mat.tres")

signal intro_capitulo_finalizada

var intro_en_curso: bool = false
var _intro_tween: Tween = null
var _intro_canvas: CanvasLayer = null
var _puntuacion_inicializada: bool = false

func _ready() -> void:
	# 1. Optimizar renderizado, planos de corte y oclusión
	OptimizadorCulling.optimizar_nivel(self)
	
	# 2. Validar que el nivel contiene los componentes mínimos requeridos
	_validar_estructura_minima()
	
	# 3. Precalentar pipelines gráficos y entornos de ambos reinos
	_precalentar_pipelines_graficos()
	
	# 4. Si hay intro de capítulo, ocultar HUD y reproducir intro; de lo contrario inicializar directamente
	if mostrar_intro_capitulo:
		_ocultar_hud_inicial()
		_mostrar_intro_capitulo()
	else:
		_inicializar_puntuacion.call_deferred()

func _ocultar_hud_inicial() -> void:
	var uis = get_tree().get_nodes_in_group("ui_tactil")
	for ui in uis:
		if is_instance_valid(ui) and ui.has_method("ocultar_para_intro_nivel"):
			ui.ocultar_para_intro_nivel()

func _precalentar_pipelines_graficos() -> void:
	# Pre-inicializar y compilar en GPU todos los recursos, entornos y shaders
	# de ambos reinos (Vivo y Fantasma / Capa 3) durante el arranque del nivel,
	# eliminando al 100% el micro-congelamiento en el primer cambio de personaje.
	var red_mgr = get_node_or_null("/root/RedManager")
	if not is_instance_valid(red_mgr):
		return
	red_mgr.buscar_personajes_en_escena()
	
	var env_fant: Environment = null
	var env_vivo: Environment = null
	if is_instance_valid(red_mgr.fantasma) and red_mgr.fantasma.has_method("obtener_entorno_personaje"):
		env_fant = red_mgr.fantasma.obtener_entorno_personaje()
	if is_instance_valid(red_mgr.jugador_vivo) and red_mgr.jugador_vivo.has_method("obtener_entorno_personaje"):
		env_vivo = red_mgr.jugador_vivo.obtener_entorno_personaje()

	# Obtener o esperar la cámara activa
	var cam_activa: Camera3D = get_viewport().get_camera_3d()
	if not is_instance_valid(cam_activa) and is_instance_valid(red_mgr.jugador_vivo):
		cam_activa = red_mgr.jugador_vivo.obtener_camara()
	if not is_instance_valid(cam_activa):
		await get_tree().process_frame
		cam_activa = get_viewport().get_camera_3d()

	if not is_instance_valid(cam_activa):
		return

	# Telón negro temporal (Capa 128) para que el pre-calentamiento sea 100% invisible al jugador
	var canvas_telon := CanvasLayer.new()
	canvas_telon.layer = 128
	var rect_negro := ColorRect.new()
	rect_negro.color = Color(0.04, 0.05, 0.07, 1.0)
	rect_negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_telon.add_child(rect_negro)
	add_child(canvas_telon)

	# Crear contenedor con proxies miniatura de todos los materiales espirituales frente al lente
	var prewarm_holder := Node3D.new()
	prewarm_holder.name = "PrewarmShadersHolder"
	cam_activa.add_child(prewarm_holder)
	prewarm_holder.position = Vector3(0.0, 0.0, -0.35)

	var mats_to_warm: Array[Material] = [
		MAT_HIERBA_FANTASMA,
		MAT_ROCA_FANTASMA,
		MAT_ESPIRITUAL,
		MAT_PASTO_ESPIRITUAL,
		MAT_PASTO_FISICO
	]

	if is_instance_valid(red_mgr.fantasma):
		for mesh_hijo in red_mgr.fantasma.find_children("*", "MeshInstance3D", true, false):
			if mesh_hijo.material_override and not mats_to_warm.has(mesh_hijo.material_override):
				mats_to_warm.append(mesh_hijo.material_override)
			if mesh_hijo.mesh:
				for s in range(mesh_hijo.mesh.get_surface_count()):
					var s_mat = mesh_hijo.get_active_material(s)
					if s_mat and not mats_to_warm.has(s_mat):
						mats_to_warm.append(s_mat)

	for i in range(mats_to_warm.size()):
		var mat = mats_to_warm[i]
		if mat == null: continue
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.02, 0.02)
		q.material = mat
		mi.mesh = q
		mi.position = Vector3((i - float(mats_to_warm.size()) * 0.5) * 0.03, 0.0, 0.0)
		mi.layers = 1048575 # Visible en todas las capas
		prewarm_holder.add_child(mi)

	# Proxy MultiMesh para compilar en GPU el pipeline instanciado de la vegetación
	for mat_pasto in [MAT_PASTO_ESPIRITUAL, MAT_PASTO_FISICO]:
		if mat_pasto != null:
			var mm_inst := MultiMeshInstance3D.new()
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.instance_count = 1
			var qm := QuadMesh.new()
			qm.size = Vector2(0.01, 0.01)
			mm.mesh = qm
			mm.set_instance_transform(0, Transform3D(Basis(), Vector3(0, 0, 0)))
			mm_inst.multimesh = mm
			mm_inst.material_override = mat_pasto
			mm_inst.layers = 1048575
			prewarm_holder.add_child(mm_inst)

	var env_original = cam_activa.environment
	var mask_original = cam_activa.cull_mask

	# FRAME 1: Forzar compilación de shaders del Fantasma, cielo espiritual, fog y post-procesado
	if env_fant:
		cam_activa.environment = env_fant
	cam_activa.cull_mask = 1048575 # Abarca todas las capas (1, 2, 3, 4)

	await RenderingServer.frame_post_draw

	# FRAME 2: Restaurar configuración y compilar shaders del Reino Vivo
	cam_activa.environment = env_original if env_original else env_vivo
	cam_activa.cull_mask = mask_original if mask_original != 0 else (1 << 0) | (1 << 1)

	await RenderingServer.frame_post_draw

	# Limpieza
	if is_instance_valid(prewarm_holder):
		prewarm_holder.queue_free()
	if is_instance_valid(canvas_telon):
		canvas_telon.queue_free()

func _validar_estructura_minima() -> void:
	var tiene_vivo = false
	var tiene_fantasma = false
	var tiene_ui = false
	var tiene_goal = false

	for nodo in get_tree().get_nodes_in_group("jugadores"):
		if nodo is CharacterBase:
			if nodo.is_in_group("fantasmas") or nodo.name.to_lower().contains("fantasma"):
				tiene_fantasma = true
			else:
				tiene_vivo = true

	if not tiene_vivo and get_node_or_null("Jugador"): tiene_vivo = true
	if not tiene_fantasma and get_node_or_null("Fantasma"): tiene_fantasma = true
	if get_tree().get_nodes_in_group("ui_tactil").size() > 0 or get_node_or_null("Controles_Tactiles"): tiene_ui = true
	if find_child("Goal", true, false) != null: tiene_goal = true

	if not tiene_vivo:
		push_warning("[NivelBase] AVISO: No se detectó al 'Jugador' (Vivo) en la escena.")
	if not tiene_fantasma:
		push_warning("[NivelBase] AVISO: No se detectó al 'Fantasma' en la escena.")
	if not tiene_ui:
		push_warning("[NivelBase] AVISO: No se detectaron los 'Controles_Tactiles' (HUD) en la escena.")
	if not tiene_goal:
		push_warning("[NivelBase] AVISO: No se detectó la meta 'Goal' en la escena. Los jugadores no podrán finalizar el nivel.")

func _inicializar_puntuacion() -> void:
	var total_vivo: int = 0
	var total_fantasma: int = 0
	
	# Método prioritario y rápido: Buscar por grupos globales indexados en O(1)
	var nodos_monedas_vivo = get_tree().get_nodes_in_group("monedas_vivo")
	var nodos_monedas_fant = get_tree().get_nodes_in_group("monedas_fantasma")
	
	if nodos_monedas_vivo.size() > 0 or nodos_monedas_fant.size() > 0:
		total_vivo = nodos_monedas_vivo.size()
		total_fantasma = nodos_monedas_fant.size()
	else:
		# Fallback: buscar dentro del contenedor dedicado 'Coleccionables' u 'ObjetosInteractivos'
		var contenedor = get_node_or_null("Coleccionables")
		if not contenedor:
			contenedor = get_node_or_null("ObjetosInteractivos")
		if contenedor:
			for hijo in contenedor.get_children():
				var nombre_low = hijo.name.to_lower()
				var script_path = hijo.get_script().resource_path.to_lower() if hijo.get_script() else ""
				if nombre_low.contains("fantasma") or script_path.contains("fantasma"):
					total_fantasma += 1
				elif nombre_low.contains("vivo") or nombre_low.contains("coin") or script_path.contains("vivo"):
					total_vivo += 1

	_puntuacion_inicializada = true
	if is_instance_valid(ScoreManager):
		ScoreManager.iniciar_nivel(tiempo_objetivo, total_vivo, total_fantasma)

func _unhandled_input(event: InputEvent) -> void:
	if intro_en_curso:
		if (event is InputEventScreenTouch and event.pressed) or \
		   (event is InputEventMouseButton and event.pressed) or \
		   (event is InputEventKey and event.pressed and not event.echo) or \
		   (event is InputEventJoypadButton and event.pressed):
			_saltar_intro_capitulo()
			get_viewport().set_input_as_handled()

func _saltar_intro_capitulo() -> void:
	if not intro_en_curso:
		return
	if is_instance_valid(_intro_tween) and _intro_tween.is_running():
		_intro_tween.kill()
	
	if is_instance_valid(_intro_canvas):
		var overlay = _intro_canvas.get_node_or_null("Overlay")
		if is_instance_valid(overlay):
			var tw_salto = create_tween()
			tw_salto.tween_property(overlay, "modulate:a", 0.0, 0.20).set_trans(Tween.TRANS_SINE)
			tw_salto.tween_callback(func():
				if is_instance_valid(_intro_canvas):
					_intro_canvas.queue_free()
				_al_desaparecer_intro_capitulo()
			)
		else:
			if is_instance_valid(_intro_canvas):
				_intro_canvas.queue_free()
			_al_desaparecer_intro_capitulo()
	else:
		_al_desaparecer_intro_capitulo()

func _mostrar_intro_capitulo() -> void:
	if not mostrar_intro_capitulo:
		_al_desaparecer_intro_capitulo()
		return

	intro_en_curso = true
	var titulo: String = _obtener_titulo_intro()

	var canvas := CanvasLayer.new()
	canvas.name = "Intro_Capitulo"
	canvas.layer = 100
	add_child(canvas)
	_intro_canvas = canvas

	var overlay := Control.new()
	overlay.name = "Overlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(overlay)

	var franja := TextureRect.new()
	franja.name = "Franja"
	franja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	franja.anchor_left = 0.0
	franja.anchor_right = 1.0
	franja.anchor_top = 0.5
	franja.anchor_bottom = 0.5
	franja.offset_top = -420
	franja.offset_bottom = 420
	franja.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	franja.stretch_mode = TextureRect.STRETCH_SCALE
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 0.45, 0.55, 0.7, 1.0])
	grad.colors = PackedColorArray([
		Color(0, 0, 0, 0.0),
		Color(0, 0, 0, 0.16),
		Color(0, 0, 0, 0.45),
		Color(0, 0, 0, 0.45),
		Color(0, 0, 0, 0.16),
		Color(0, 0, 0, 0.0),
	])
	var grad_tex := GradientTexture2D.new()
	grad_tex.width = 64
	grad_tex.height = 64
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_LINEAR
	grad_tex.fill_from = Vector2(0, 0)
	grad_tex.fill_to = Vector2(0, 1)
	franja.texture = grad_tex
	overlay.add_child(franja)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(centro)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 12)
	columna.alignment = BoxContainer.ALIGNMENT_CENTER
	centro.add_child(columna)

	var label_capitulo := Label.new()
	label_capitulo.name = "Label_Capitulo"
	label_capitulo.text = "Capítulo %d" % capitulo
	label_capitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_capitulo.add_theme_font_size_override("font_size", 26)
	label_capitulo.add_theme_color_override("font_color", Color(1.0, 0.92, 0.62))
	label_capitulo.add_theme_constant_override("shadow_offset_x", 2)
	label_capitulo.add_theme_constant_override("shadow_offset_y", 2)
	label_capitulo.add_theme_constant_override("shadow_outline_size", 0)
	label_capitulo.add_theme_constant_override("shadow_size", 12)
	label_capitulo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	_aplicar_peso_fuente(label_capitulo, -0.4)
	columna.add_child(label_capitulo)

	var label_titulo := Label.new()
	label_titulo.name = "Label_Titulo"
	label_titulo.text = titulo
	label_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_titulo.add_theme_font_size_override("font_size", 52)
	label_titulo.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	label_titulo.add_theme_constant_override("shadow_offset_x", 2)
	label_titulo.add_theme_constant_override("shadow_offset_y", 2)
	label_titulo.add_theme_constant_override("shadow_outline_size", 0)
	label_titulo.add_theme_constant_override("shadow_size", 16)
	label_titulo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	_aplicar_peso_fuente(label_titulo, 1.0)
	columna.add_child(label_titulo)

	var group := overlay
	group.modulate.a = 0.0
	_intro_tween = create_tween()
	_intro_tween.tween_property(group, "modulate:a", 1.0, tiempo_fade_in)
	_intro_tween.tween_interval(tiempo_visible)
	_intro_tween.tween_property(group, "modulate:a", 0.0, tiempo_fade_out)
	_intro_tween.tween_callback(func():
		intro_en_curso = false
		if is_instance_valid(canvas):
			canvas.queue_free()
		_al_desaparecer_intro_capitulo()
	)

func _al_desaparecer_intro_capitulo() -> void:
	intro_en_curso = false
	intro_capitulo_finalizada.emit()
	
	# Inicializar cronómetro y marcador sincronizado al comenzar la jugabilidad real
	if not _puntuacion_inicializada:
		_inicializar_puntuacion()
	
	# Activar y mostrar controles con transición suave
	var uis = get_tree().get_nodes_in_group("ui_tactil")
	for ui in uis:
		if is_instance_valid(ui) and ui.has_method("aparecer_con_transicion"):
			ui.aparecer_con_transicion()

func _aplicar_peso_fuente(label: Label, embolden: float) -> void:
	var variacion := FontVariation.new()
	variacion.base_font = label.get_theme_font("font")
	variacion.variation_embolden = embolden
	label.add_theme_font_override("font", variacion)

func _obtener_titulo_intro() -> String:
	if not titulo_capitulo_personalizado.strip_edges().is_empty():
		return titulo_capitulo_personalizado.strip_edges()
	return CatalogoNiveles.obtener_titulo_capitulo(capitulo)
