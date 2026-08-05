extends "res://scripts/objects/elemento_interactivo_base.gd"
class_name PlataformaEspiritualBase

# Plataforma Espiritual.
# Al activarse, se vuelve visible (opacidad = 1.0) y activa su colisión en la Capa 2
# y Capa 3 para que tanto el jugador Vivo como el Fantasma puedan caminar sobre ella.
# Al desactivarse, se vuelve invisible (opacidad = 0.0) e intangible (sin colisiones).

@export_group("Configuración Visual")
@export var opacidad_activa: float = 1.0
@export var opacidad_inactiva: float = 0.0

var _materiales_cacheados: Dictionary = {} # { MeshInstance3D: { "override": Material, "surfaces": Array[Material] } }

func _ready() -> void:
	# Por defecto, pertenece a la Capa 3 (Plano Espiritual)
	collision_layer = 1 << 2
	collision_mask = 1 << 2
	
	# Llamar a super() para conectar el disparador_objetivo
	super()
	_cachear_materiales(self)

func actualizar_comportamiento(activo: bool) -> void:
	if activo:
		# Activa: sólida para el Vivo (Capa 2) y el Fantasma (Capa 3)
		collision_layer = (1 << 1) | (1 << 2)
		collision_mask = (1 << 1) | (1 << 2)
		_cambiar_opacidad(opacidad_activa)
	else:
		# Inactiva: invisible e intangible para ambos
		collision_layer = 0
		collision_mask = 0
		_cambiar_opacidad(opacidad_inactiva)

func _cambiar_opacidad(opacidad: float) -> void:
	_cambiar_opacidad_recursivo(self, opacidad)

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
