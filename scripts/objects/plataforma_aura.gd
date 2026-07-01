extends StaticBody3D
class_name PlataformaAura

const CAPA_FISICA := 1 << 1 # Layer 2: Plano_Fisico
const CAPA_ESPIRITUAL := 1 << 2 # Layer 3: Plano_Espiritual
const CAPAS_PLATAFORMA_ACTIVA := CAPA_FISICA | CAPA_ESPIRITUAL

# Variable local para almacenar el estado sincronizado
var esta_activa : bool = false
var area_contacto: Area3D = null

func _ready():
	inicializar_plataforma()

func inicializar_plataforma() -> void:
	if not is_in_group("plataformas_aura"):
		add_to_group("plataformas_aura")
		
	# Crear área de contacto dinámica para detectar al fantasma sin fallos de físicas
	if not has_node("AreaContacto"):
		area_contacto = Area3D.new()
		area_contacto.name = "AreaContacto"
		# Configurar área para detectar solo al fantasma (capa 3 / valor 4)
		area_contacto.collision_layer = 0 # No colisiona con nada
		area_contacto.collision_mask = 1 << 2 # Capa 3: Plano Espiritual
		add_child(area_contacto)
		
		# Buscar las colisiones de la plataforma para duplicarlas en el área
		for hijo in get_children():
			if hijo is CollisionShape3D:
				var shape_copy = CollisionShape3D.new()
				shape_copy.shape = hijo.shape
				shape_copy.transform = hijo.transform
				# Expandir ligeramente la colisión para tener un margen de contacto robusto
				shape_copy.scale = Vector3(1.02, 1.05, 1.02)
				area_contacto.add_child(shape_copy)
				
	# Aseguramos el estado inicial desactivado
	actualizar_estado(false)

func esta_siendo_tocada_por_fantasma() -> bool:
	if area_contacto and area_contacto.has_overlapping_bodies():
		return true
	return false

@rpc("any_peer", "call_local", "reliable")
func rpc_sincronizar_estado(activo: bool) -> void:
	actualizar_estado(activo)

func actualizar_estado(activo: bool) -> void:
	esta_activa = activo
	if activo:
		# Activa: sólido para vivo y fantasma
		collision_layer = CAPAS_PLATAFORMA_ACTIVA
		collision_mask = CAPAS_PLATAFORMA_ACTIVA
		_cambiar_opacidad(1.0)
	else:
		# Inactiva: sólo sólido para el fantasma
		collision_layer = CAPA_ESPIRITUAL
		collision_mask = CAPA_ESPIRITUAL
		_cambiar_opacidad(0.5)

func _cambiar_opacidad(opacidad: float) -> void:
	_cambiar_opacidad_recursivo(self, opacidad)

func _cambiar_opacidad_recursivo(nodo: Node, opacidad: float) -> void:
	if nodo is MeshInstance3D:
		# Modificar material_override si existe
		if nodo.material_override:
			var mat = nodo.material_override.duplicate()
			if mat is BaseMaterial3D:
				if opacidad >= 1.0:
					mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				else:
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
				
				if "alpha_scissor" in mat:
					mat.alpha_scissor = 0.5
				var color = mat.albedo_color
				color.a = opacidad
				mat.albedo_color = color
			nodo.material_override = mat
		
		# Modificar materiales de cada superficie
		if nodo.get_mesh():
			for i in range(nodo.get_mesh().get_surface_count()):
				var material = nodo.get_active_material(i)
				if not material:
					material = nodo.get_mesh().surface_get_material(i)
				if material:
					material = material.duplicate()
					if material is BaseMaterial3D:
						if opacidad >= 1.0:
							material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
						else:
							material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
						
						if "alpha_scissor" in material:
							material.alpha_scissor = 0.5
						var color = material.albedo_color
						color.a = opacidad
						material.albedo_color = color
					nodo.set_surface_override_material(i, material)
	for hijo in nodo.get_children():
		_cambiar_opacidad_recursivo(hijo, opacidad)
