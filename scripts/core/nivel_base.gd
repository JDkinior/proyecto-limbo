extends Node3D
class_name NivelBase

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

## Nombres por defecto para cada capítulo (se usan si no hay texto personalizado).
const NOMBRES_CAPITULOS := {
	1: "El Despertar",
	2: "El Camino del Faro",
	3: "La Caída del Limbo",
	4: "El Último Umbral",
}

func _ready() -> void:
	# 1. Optimizar renderizado, planos de corte y oclusión
	OptimizadorCulling.optimizar_nivel(self)
	
	# 2. Validar que el nivel contiene los componentes mínimos requeridos
	_validar_estructura_minima()
	
	# 3. Contar coleccionables e inicializar el marcador sincronizado
	_inicializar_puntuacion.call_deferred()
	
	# 4. Mostrar el rótulo del capítulo con fade-in
	_mostrar_intro_capitulo()

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

	if is_instance_valid(ScoreManager):
		ScoreManager.iniciar_nivel(tiempo_objetivo, total_vivo, total_fantasma)

func _mostrar_intro_capitulo() -> void:
	if not mostrar_intro_capitulo:
		return

	var titulo: String = _obtener_titulo_intro()

	var canvas := CanvasLayer.new()
	canvas.name = "Intro_Capitulo"
	canvas.layer = 100
	add_child(canvas)

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
	var tw := create_tween()
	tw.tween_property(group, "modulate:a", 1.0, tiempo_fade_in)
	tw.tween_interval(tiempo_visible)
	tw.tween_property(group, "modulate:a", 0.0, tiempo_fade_out)
	tw.tween_callback(canvas.queue_free)

func _aplicar_peso_fuente(label: Label, embolden: float) -> void:
	var variacion := FontVariation.new()
	variacion.base_font = label.get_theme_font("font")
	variacion.variation_embolden = embolden
	label.add_theme_font_override("font", variacion)

func _obtener_titulo_intro() -> String:
	if not titulo_capitulo_personalizado.strip_edges().is_empty():
		return titulo_capitulo_personalizado.strip_edges()
	return NOMBRES_CAPITULOS.get(capitulo, "Capítulo %d" % capitulo)
