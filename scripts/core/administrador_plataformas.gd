extends Node3D
class_name AdministradorPlataformas

const CAPA_ESPIRITUAL := 1 << 2 # Layer 3: Plano_Espiritual

func _ready():
	print("[AdministradorPlataformas] Buscando y registrando plataformas en el mundo...")
	_configurar_plataformas(get_tree().root)

func _configurar_plataformas(nodo: Node) -> void:
	if nodo is StaticBody3D and _es_plataforma_aura(nodo):
		# Añadir PlataformaAura como componente hijo si no lo tiene
		var tiene_componente = false
		for hijo in nodo.get_children():
			if hijo is PlataformaAura:
				tiene_componente = true
				break
		
		if not tiene_componente:
			var componente = load("res://scripts/objects/plataforma_aura.gd").new()
			componente.name = "PlataformaAuraComponente"
			nodo.add_child(componente)
		
		# Registrar en el grupo plataformas_aura si no pertenece
		if not nodo.is_in_group("plataformas_aura"):
			nodo.add_to_group("plataformas_aura")
			
		print("[AdministradorPlataformas] Plataforma registrada y configurada: ", nodo.name)
		
	for hijo in nodo.get_children():
		_configurar_plataformas(hijo)

func _es_plataforma_aura(plataforma: StaticBody3D) -> bool:
	return (plataforma.collision_layer & CAPA_ESPIRITUAL) != 0 or (plataforma.collision_mask & CAPA_ESPIRITUAL) != 0
