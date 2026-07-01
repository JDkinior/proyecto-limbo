extends "res://scripts/objects/elemento_interactivo_base.gd"
class_name PlataformaEspiritualBase

# Plataforma Espiritual.
# Al activarse, se vuelve visible (opacidad = 1.0) y activa su colisión en la Capa 2
# y Capa 3 para que tanto el jugador Vivo como el Fantasma puedan caminar sobre ella.
# Al desactivarse, se vuelve invisible (opacidad = 0.0) e intangible (sin colisiones).

@export_group("Configuración Visual")
@export var opacidad_activa: float = 1.0
@export var opacidad_inactiva: float = 0.0

func _ready() -> void:
	# Por defecto, pertenece a la Capa 3 (Plano Espiritual)
	collision_layer = 1 << 2
	collision_mask = 1 << 2
	
	# Llamar a super() para conectar el disparador_objetivo
	super()

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

func _cambiar_opacidad_recursivo(nodo: Node, opacidad: float) -> void:
	if nodo is MeshInstance3D:
		# Duplicar y modificar material_override si existe
		if nodo.material_override:
			var mat = nodo.material_override.duplicate()
			if mat is BaseMaterial3D:
				if opacidad >= 1.0:
					mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				else:
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
				var color = mat.albedo_color
				color.a = opacidad
				mat.albedo_color = color
			nodo.material_override = mat
		
		# Duplicar y modificar materiales de cada superficie del Mesh
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
						var color = material.albedo_color
						color.a = opacidad
						material.albedo_color = color
					nodo.set_surface_override_material(i, material)
					
	for hijo in nodo.get_children():
		_cambiar_opacidad_recursivo(hijo, opacidad)
