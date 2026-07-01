extends Node3D
class_name AdministradorPlataformas

const CAPA_ESPIRITUAL := 1 << 2 # Layer 3: Plano_Espiritual

func _ready():
	print("[AdministradorPlataformas] Buscando y registrando plataformas en el mundo...")
	_configurar_plataformas(get_tree().root)

func _configurar_plataformas(nodo: Node) -> void:
	if nodo is StaticBody3D and _es_plataforma_aura(nodo):
		# Asignar el script PlataformaAura si no tiene uno
		if not nodo.get_script():
			nodo.set_script(load("res://scripts/objects/plataforma_aura.gd"))
			# Inicializar manualmente ya que _ready() no se vuelve a disparar al cambiar el script en runtime
			if nodo.has_method("inicializar_plataforma"):
				nodo.inicializar_plataforma()
		
		# Registrar en el grupo plataformas_aura si no pertenece
		if not nodo.is_in_group("plataformas_aura"):
			nodo.add_to_group("plataformas_aura")
			
		print("[AdministradorPlataformas] Plataforma registrada y configurada: ", nodo.name)
		
	for hijo in nodo.get_children():
		_configurar_plataformas(hijo)

func _es_plataforma_aura(plataforma: StaticBody3D) -> bool:
	return (plataforma.collision_layer & CAPA_ESPIRITUAL) != 0 or (plataforma.collision_mask & CAPA_ESPIRITUAL) != 0
