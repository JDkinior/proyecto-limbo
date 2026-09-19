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

func _ready() -> void:
	# 1. Optimizar renderizado, planos de corte y oclusión
	OptimizadorCulling.optimizar_nivel(self)
	
	# 2. Validar que el nivel contiene los componentes mínimos requeridos
	_validar_estructura_minima()
	
	# 3. Contar coleccionables e inicializar el marcador sincronizado
	_inicializar_puntuacion.call_deferred()

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
