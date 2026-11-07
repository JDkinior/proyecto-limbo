@tool
extends WorldEnvironment
class_name ControladorEntornoVisual

## ==============================================================================
## CONTROLADOR DE ENTORNO Y PREVISUALIZADOR DE REINOS (PROYECTO LIMBO)
## Permite al diseñador alternar entre la atmósfera del Reino Vivo y el Reino
## Espiritual en el editor con un solo clic, incluyendo cielo, niebla, pasto
## y materiales espectrales de plataformas / islas flotantes, sin alterar el runtime.
## ==============================================================================

const ENTORNO_FANTASMA = preload("res://assets/materiales/entorno/entorno_fantasma.tres")

@export_group("Previsualización de Reino (Editor)")
## Activa el Reino Espiritual (cielo cian, niebla mística, pasto y plataformas espectrales) en el editor.
@export var previsualizar_reino_espiritual: bool = false:
	set(valor):
		previsualizar_reino_espiritual = valor
		if Engine.is_editor_hint():
			_actualizar_previsualizacion()

@export_group("Recursos del Nivel")
## Entorno asignado al Reino Vivo para este nivel. Si no se asigna, toma el actual.
@export var entorno_vivo: Environment = null:
	set(valor):
		entorno_vivo = valor
		if Engine.is_editor_hint() and not previsualizar_reino_espiritual and entorno_vivo != null:
			environment = entorno_vivo

func _ready() -> void:
	_asegurar_entorno_vivo()
	
	if not Engine.is_editor_hint():
		# En runtime siempre arrancar de forma segura con el Reino Vivo
		previsualizar_reino_espiritual = false
		_restaurar_reino_vivo()
		_conmutar_pasto(false)
		_conmutar_islas(false)

func _asegurar_entorno_vivo() -> void:
	if entorno_vivo == null and environment != null and environment != ENTORNO_FANTASMA:
		entorno_vivo = environment

func _actualizar_previsualizacion() -> void:
	_asegurar_entorno_vivo()
	
	if previsualizar_reino_espiritual:
		environment = ENTORNO_FANTASMA
		_conmutar_pasto(true)
		_conmutar_islas(true)
	else:
		_restaurar_reino_vivo()
		_conmutar_pasto(false)
		_conmutar_islas(false)

func _restaurar_reino_vivo() -> void:
	if is_instance_valid(entorno_vivo):
		environment = entorno_vivo

func _conmutar_pasto(es_espiritual: bool) -> void:
	var escena_raiz := _obtener_raiz_escena()
	if not is_instance_valid(escena_raiz):
		return
		
	var multimeshes := escena_raiz.find_children("*", "MultiMeshInstance3D", true, false)
	for mm in multimeshes:
		if mm is GeneradorPasto:
			var gen := mm as GeneradorPasto
			if es_espiritual and gen.material_espiritual != null:
				gen.material_override = gen.material_espiritual
			elif not es_espiritual and gen.material_fisico != null:
				gen.material_override = gen.material_fisico

func _conmutar_islas(es_espiritual: bool) -> void:
	var escena_raiz := _obtener_raiz_escena()
	if not is_instance_valid(escena_raiz):
		return
		
	var visitados: Dictionary = {}
	
	# 1. Búsqueda por StaticBody3D e inspección de clase IslaFlotante
	var cuerpos := escena_raiz.find_children("*", "StaticBody3D", true, false)
	for cuerpo in cuerpos:
		if (cuerpo is IslaFlotante or "vista_fantasma_en_editor" in cuerpo) and not visitados.has(cuerpo):
			visitados[cuerpo] = true
			cuerpo.vista_fantasma_en_editor = es_espiritual
			
	# 2. Grupo "islas" si está disponible en el árbol
	if get_tree():
		for nodo in get_tree().get_nodes_in_group("islas"):
			if is_instance_valid(nodo) and not visitados.has(nodo) and "vista_fantasma_en_editor" in nodo:
				visitados[nodo] = true
				nodo.vista_fantasma_en_editor = es_espiritual

func _obtener_raiz_escena() -> Node:
	if Engine.is_editor_hint():
		var root := get_tree().edited_scene_root if get_tree() else null
		if is_instance_valid(root):
			return root
	elif is_instance_valid(get_tree()) and is_instance_valid(get_tree().current_scene):
		return get_tree().current_scene
	return get_parent()
