extends Node
class_name PlataformaAura

const CAPA_FISICA := 1 << 1 # Layer 2: Plano_Fisico
const CAPA_ESPIRITUAL := 1 << 2 # Layer 3: Plano_Espiritual
const CAPAS_PLATAFORMA_ACTIVA := CAPA_FISICA | CAPA_ESPIRITUAL

# Variable local para almacenar el estado sincronizado
var esta_activa : bool = false
var area_contacto: Area3D = null
var _materiales_cacheados: Dictionary = {} # { MeshInstance3D: { "override": Material, "surfaces": Array[Material] } }

func _ready():
	inicializar_plataforma()

func inicializar_plataforma() -> void:
	var body = get_parent() as StaticBody3D
	if not body:
		return
		
	if not body.is_in_group("plataformas_aura"):
		body.add_to_group("plataformas_aura")
		
	# Crear área de contacto dinámica para detectar al fantasma sin fallos de físicas
	if not has_node("AreaContacto"):
		area_contacto = Area3D.new()
		area_contacto.name = "AreaContacto"
		# Configurar área para detectar solo al fantasma (capa 3 / valor 4)
		area_contacto.collision_layer = 0 # No colisiona con nada
		area_contacto.collision_mask = 1 << 2 # Capa 3: Plano Espiritual
		add_child(area_contacto)
		
		# Buscar las colisiones de la plataforma para duplicarlas en el área
		for hijo in body.get_children():
			if hijo is CollisionShape3D:
				var shape_copy = CollisionShape3D.new()
				shape_copy.shape = hijo.shape
				shape_copy.transform = hijo.transform
				# Expandir ligeramente la colisión para tener un margen de contacto robusto
				shape_copy.scale = Vector3(1.02, 1.05, 1.02)
				area_contacto.add_child(shape_copy)
				
	# Aseguramos el estado inicial desactivado
	actualizar_estado(false)
	_cachear_materiales(body)

func esta_siendo_tocada_por_fantasma() -> bool:
	if area_contacto:
		for body in area_contacto.get_overlapping_bodies():
			if body is Fantasma:
				return true
	return false

@rpc("any_peer", "call_local", "reliable")
func rpc_sincronizar_estado(activo: bool) -> void:
	actualizar_estado(activo)

func actualizar_estado(activo: bool) -> void:
	esta_activa = activo
	var body = get_parent() as StaticBody3D
	if body:
		if activo:
			# Activa: sólido para vivo y fantasma
			body.collision_layer = CAPAS_PLATAFORMA_ACTIVA
			body.collision_mask = CAPAS_PLATAFORMA_ACTIVA
			_cambiar_opacidad(1.0)
		else:
			# Inactiva: sólo sólido para el fantasma
			body.collision_layer = CAPA_ESPIRITUAL
			body.collision_mask = CAPA_ESPIRITUAL
			_cambiar_opacidad(0.5)

func _cambiar_opacidad(opacidad: float) -> void:
	var body = get_parent() as StaticBody3D
	if body:
		_cambiar_opacidad_recursivo(body, opacidad)

func _cachear_materiales(nodo: Node) -> void:
	if nodo is MeshInstance3D:
		var cache_entry = {"override": null, "surfaces": []}
		if nodo.material_override:
			cache_entry["override"] = nodo.material_override.duplicate()
			nodo.material_override = cache_entry["override"]
		if nodo.get_mesh():
			for i in range(nodo.get_mesh().get_surface_count()):
				var material = nodo.get_active_material(i)
				if not material:
					material = nodo.get_mesh().surface_get_material(i)
				if material:
					var mat_dup = material.duplicate()
					nodo.set_surface_override_material(i, mat_dup)
					cache_entry["surfaces"].append(mat_dup)
				else:
					cache_entry["surfaces"].append(null)
		_materiales_cacheados[nodo] = cache_entry
	for hijo in nodo.get_children():
		_cachear_materiales(hijo)

func _cambiar_opacidad_recursivo(nodo: Node, opacidad: float) -> void:
	if nodo is MeshInstance3D:
		# Use cached override material if available
		if _materiales_cacheados.has(nodo):
			var cache = _materiales_cacheados[nodo]
			if cache["override"] and cache["override"] is BaseMaterial3D:
				var mat = cache["override"]
				if opacidad >= 1.0:
					mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				else:
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
				if "alpha_scissor" in mat:
					mat.alpha_scissor = 0.5
				var color = mat.albedo_color
				color.a = opacidad
				mat.albedo_color = color
			for mat in cache["surfaces"]:
				if mat and mat is BaseMaterial3D:
					if opacidad >= 1.0:
						mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					else:
						mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
					if "alpha_scissor" in mat:
						mat.alpha_scissor = 0.5
					var color = mat.albedo_color
					color.a = opacidad
					mat.albedo_color = color
		else:
			# Fallback for non-cached meshes (e.g. dynamically added)
			if nodo.material_override and nodo.material_override is BaseMaterial3D:
				if opacidad >= 1.0:
					nodo.material_override.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				else:
					nodo.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
				var color = nodo.material_override.albedo_color
				color.a = opacidad
				nodo.material_override.albedo_color = color
	for hijo in nodo.get_children():
		_cambiar_opacidad_recursivo(hijo, opacidad)
