extends Node3D
class_name AdministradorPlataformas

const CAPA_FISICA := 1 << 1 # Layer 2: Plano_Fisico
const CAPA_ESPIRITUAL := 1 << 2 # Layer 3: Plano_Espiritual
const CAPAS_PLATAFORMA_ACTIVA := CAPA_FISICA | CAPA_ESPIRITUAL

# Variables para sincronizar plataformas entre fantasma y jugador
var plataformas_activas: Dictionary = {}  # {nodo_path: bool}
var fantasma_ref: Node3D = null
var jugador_ref: Node3D = null

var anterior_estado: Dictionary = {}

func _ready():
	# Buscar referencias a los personajes
	fantasma_ref = get_node_or_null("../Fantasma")
	jugador_ref = get_node_or_null("../Jugador")
	
	if fantasma_ref:
		print("AdministradorPlataformas: Fantasma encontrado")
	else:
		print("AdministradorPlataformas: Fantasma NO encontrado")
	
	if jugador_ref:
		print("AdministradorPlataformas: Jugador encontrado")
	else:
		print("AdministradorPlataformas: Jugador NO encontrado")

func _process(_delta):
	# Sincronizar el estado de plataformas
	if fantasma_ref and fantasma_ref.has_method("obtener_plataformas_activas"):
		var nuevo_estado = fantasma_ref.obtener_plataformas_activas()
		
		# Solo actualizar si el estado cambió
		if nuevo_estado != anterior_estado:
			_aplicar_cambios_plataformas(nuevo_estado)
			anterior_estado = nuevo_estado.duplicate()

func _aplicar_cambios_plataformas(nuevo_estado: Dictionary) -> void:
	"""Aplica los cambios de estado de plataformas detectados"""
	# Detectar cambios en cada plataforma
	for ruta_plataforma in nuevo_estado:
		var nuevo_valor = nuevo_estado[ruta_plataforma]
		var valor_anterior = plataformas_activas.get(ruta_plataforma, false)
		
		if nuevo_valor != valor_anterior:
			plataformas_activas[ruta_plataforma] = nuevo_valor
			_notificar_cambio_plataforma(ruta_plataforma, nuevo_valor)
	
	# Limpiar plataformas removidas
	for ruta_plataforma in plataformas_activas.keys():
		if ruta_plataforma not in nuevo_estado:
			plataformas_activas.erase(ruta_plataforma)

func _notificar_cambio_plataforma(ruta_plataforma: String, activa: bool) -> void:
	"""Notifica al jugador vivo sobre los cambios de plataformas"""
	var plataforma = get_tree().root.get_node_or_null(ruta_plataforma)
	if plataforma:
		_aplicar_colisiones_plataforma(plataforma, activa)

func _aplicar_colisiones_plataforma(plataforma: Node3D, activa: bool) -> void:
	"""Aplica los cambios de colisión a una plataforma"""
	if activa:
		# Activa: sólido para vivo y fantasma.
		plataforma.collision_layer = CAPAS_PLATAFORMA_ACTIVA
		plataforma.collision_mask = CAPAS_PLATAFORMA_ACTIVA
		_cambiar_opacidad_plataforma(plataforma, 1.0)
		print("Plataforma %s activada" % plataforma.name)
	else:
		# Inactiva: solo sólido para el fantasma.
		# Esto permite que el fantasma camine sobre ella pero el vivo la atraviese
		plataforma.collision_layer = CAPA_ESPIRITUAL
		plataforma.collision_mask = CAPA_ESPIRITUAL
		_cambiar_opacidad_plataforma(plataforma, 0.5)
		print("Plataforma %s desactivada" % plataforma.name)

func _cambiar_opacidad_plataforma(plataforma: Node3D, opacidad: float) -> void:
	"""Cambia la opacidad de todos los MeshInstance3D de una plataforma de forma recursiva"""
	_cambiar_opacidad_recursivo(plataforma, opacidad)

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

func obtener_plataformas_activas() -> Dictionary:
	"""Retorna el estado actual de las plataformas"""
	return plataformas_activas.duplicate()
