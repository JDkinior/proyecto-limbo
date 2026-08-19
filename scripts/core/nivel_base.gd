extends Node3D
class_name NivelBase

@export var tiempo_objetivo: float = 120.0 # Tiempo objetivo del nivel en segundos (modificable en inspector)

func _ready() -> void:
	# Aplicar optimizaciones automáticas de culling, frustum y sombras
	OptimizadorCulling.optimizar_nivel(self)
	
	# Contar monedas disponibles en el nivel al iniciar
	var resultado = {"vivo": 0, "fantasma": 0}
	
	# Buscar nodos de monedas por tipo o script recursivamente
	_contar_coleccionables_recursivo(self, resultado)
	
	# Si no se encontraron por recursión, buscar en el grupo "Coleccionables"
	var coleccionables_node = get_node_or_null("Coleccionables")
	if coleccionables_node:
		resultado["vivo"] = 0
		resultado["fantasma"] = 0
		for hijo in coleccionables_node.get_children():
			var script_path = ""
			if hijo.get_script():
				script_path = hijo.get_script().resource_path.to_lower()
			if hijo.name.to_lower().contains("fantasma") or script_path.contains("moneda_fantasma"):
				resultado["fantasma"] += 1
			elif hijo.name.to_lower().contains("vivo") or script_path.contains("coin") or script_path.contains("moneda_vivo"):
				resultado["vivo"] += 1
	
	if is_instance_valid(ScoreManager):
		ScoreManager.iniciar_nivel(tiempo_objetivo, resultado["vivo"], resultado["fantasma"])

func _contar_coleccionables_recursivo(nodo: Node, resultado: Dictionary) -> void:
	var script_p = ""
	if nodo.get_script():
		script_p = nodo.get_script().resource_path.to_lower()
	
	if script_p.contains("moneda_fantasma"):
		resultado["fantasma"] += 1
	elif (script_p.contains("coin") or script_p.contains("moneda_vivo")) and not script_p.contains("moneda_fantasma"):
		resultado["vivo"] += 1
	
	for hijo in nodo.get_children():
		_contar_coleccionables_recursivo(hijo, resultado)
