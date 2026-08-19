extends RefCounted
class_name OptimizadorCulling

## ==============================================================================
## OPTIMIZADOR DE CULLING Y RENDERIZADO 3D (PROYECTO LIMBO - GODOT 4)
## Aplica reglas inteligentes de Occlusion Culling, Distance Culling (LOD),
## Frustum Clipping y Optimización de Sombras a niveles y entidades.
## ==============================================================================

const DISTANCIA_CORTE_CAMARA_DEFAULT: float = 130.0
const DISTANCIA_SOMBRA_MAXIMA: float = 60.0

const RANGO_VISIBILIDAD_PASTO: float = 65.0
const RANGO_VISIBILIDAD_CRISTALES: float = 60.0
const RANGO_VISIBILIDAD_FAROLES: float = 75.0
const RANGO_VISIBILIDAD_ARBOLES: float = 85.0
const RANGO_VISIBILIDAD_MONEDAS: float = 80.0
const RANGO_VISIBILIDAD_PARTICULAS: float = 45.0

## Optimiza automáticamente todo un nivel o rama del árbol de nodos
static func optimizar_nivel(nodo_raiz: Node) -> void:
	if not is_instance_valid(nodo_raiz):
		return
	
	_recorrer_y_optimizar(nodo_raiz)

static func _recorrer_y_optimizar(nodo: Node) -> void:
	# 1. Optimización de Cámaras 3D (Frustum Culling)
	if nodo is Camera3D:
		_optimizar_camara(nodo)
	
	# 2. Optimización de Luces y Sombras
	elif nodo is DirectionalLight3D:
		_optimizar_luz_direccional(nodo)
	elif nodo is OmniLight3D:
		_optimizar_luz_omni(nodo)
		
	# 3. Optimización de Pasto y MultiMeshes (Distance Culling)
	elif nodo is MultiMeshInstance3D:
		_optimizar_multimesh(nodo)
		
	# 4. Optimización de Partículas
	elif nodo is CPUParticles3D or nodo is GPUParticles3D:
		_optimizar_particulas(nodo)
		
	# 5. Optimización de Mallas Decorativas (MeshInstance3D)
	elif nodo is MeshInstance3D:
		_optimizar_malla_decorativa(nodo)
		
	# 6. Optimización de Cuerpos Estáticos y Plataformas (Occlusion Culling)
	elif nodo is StaticBody3D:
		_optimizar_static_body(nodo)

	# Recorrer recursivamente los hijos
	for hijo in nodo.get_children():
		_recorrer_y_optimizar(hijo)

## Ajusta los planos de corte cercano/lejano para no calcular geometría fuera de la niebla
static func _optimizar_camara(cam: Camera3D) -> void:
	if cam.far > 200.0:
		cam.far = DISTANCIA_CORTE_CAMARA_DEFAULT
	if cam.near < 0.05:
		cam.near = 0.1

## Limita el rango de cálculo de sombras para no desperdiciar GPU en objetos lejanos
static func _optimizar_luz_direccional(luz: DirectionalLight3D) -> void:
	if luz.directional_shadow_max_distance > DISTANCIA_SOMBRA_MAXIMA:
		luz.directional_shadow_max_distance = DISTANCIA_SOMBRA_MAXIMA
	luz.directional_shadow_blend_splits = true

static func _optimizar_luz_omni(luz: OmniLight3D) -> void:
	# Asegurar atenuación suave y evitar sombras en luces de relleno pequeñas
	if luz.omni_range > 20.0:
		luz.omni_range = 20.0

static func _optimizar_multimesh(mm: MultiMeshInstance3D) -> void:
	# El pasto no necesita proyectar sombras sobre sí mismo ni sobre el mundo
	mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	# Si no tiene configurado un rango de visibilidad, asignarle uno con fade suave
	if mm.visibility_range_end == 0.0:
		mm.visibility_range_end = RANGO_VISIBILIDAD_PASTO
		mm.visibility_range_end_margin = 10.0
		mm.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

static func _optimizar_particulas(part: GeometryInstance3D) -> void:
	if part.visibility_range_end == 0.0:
		part.visibility_range_end = RANGO_VISIBILIDAD_PARTICULAS
		part.visibility_range_end_margin = 6.0
		part.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

static func _optimizar_malla_decorativa(mesh_inst: MeshInstance3D) -> void:
	var nombre_low = mesh_inst.name.to_lower()
	var padre_nombre_low = mesh_inst.get_parent().name.to_lower() if mesh_inst.get_parent() else ""
	
	# Árboles y copas
	if nombre_low.contains("canopy") or nombre_low.contains("trunk") or padre_nombre_low.contains("arbol"):
		if mesh_inst.visibility_range_end == 0.0:
			mesh_inst.visibility_range_end = RANGO_VISIBILIDAD_ARBOLES
			mesh_inst.visibility_range_end_margin = 10.0
			mesh_inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			
	# Cristales
	elif nombre_low.contains("cristal") or padre_nombre_low.contains("cristal") or nombre_low.contains("glowcrystal") or nombre_low.contains("monolith"):
		if mesh_inst.visibility_range_end == 0.0:
			mesh_inst.visibility_range_end = RANGO_VISIBILIDAD_CRISTALES
			mesh_inst.visibility_range_end_margin = 8.0
			mesh_inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

	# Faroles
	elif nombre_low.contains("farol") or padre_nombre_low.contains("farol"):
		if mesh_inst.visibility_range_end == 0.0:
			mesh_inst.visibility_range_end = RANGO_VISIBILIDAD_FAROLES
			mesh_inst.visibility_range_end_margin = 10.0
			mesh_inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			
	# Monedas
	elif nombre_low.contains("coin") or nombre_low.contains("moneda") or padre_nombre_low.contains("moneda"):
		if mesh_inst.visibility_range_end == 0.0:
			mesh_inst.visibility_range_end = RANGO_VISIBILIDAD_MONEDAS
			mesh_inst.visibility_range_end_margin = 10.0
			mesh_inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

	# Nubes
	elif nombre_low.contains("nube") or padre_nombre_low.contains("nube") or nombre_low.contains("puff"):
		if mesh_inst.visibility_range_end == 0.0:
			mesh_inst.visibility_range_end = 125.0
			mesh_inst.visibility_range_end_margin = 15.0
			mesh_inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

## Optimiza cuerpos estáticos grandes añadiéndoles oclusores si carecen de uno
static func _optimizar_static_body(body: StaticBody3D) -> void:
	# No añadir oclusores a plataformas espirituales transparentes/activables por aura
	if body.is_in_group("plataformas_aura") or body.name.to_lower().contains("cristal") or body.name.to_lower().contains("vidrio"):
		return
		
	# Verificar si ya tiene un oclusor
	for hijo in body.get_children():
		if hijo is OccluderInstance3D:
			return
			
	# Buscar colisionador de tipo caja con tamaño suficiente para ocluir (> 2.5m)
	for hijo in body.get_children():
		if hijo is CollisionShape3D and hijo.shape is BoxShape3D:
			var box = hijo.shape as BoxShape3D
			if box.size.x >= 2.5 or box.size.y >= 2.5 or box.size.z >= 2.5:
				agregar_oclusor_caja(body, box.size, hijo.transform)
				break

## Crea y añade programáticamente un OccluderInstance3D tipo caja a un StaticBody3D o Node3D
static func agregar_oclusor_caja(padre: Node3D, dimensiones: Vector3, transform_local: Transform3D = Transform3D.IDENTITY) -> OccluderInstance3D:
	if not is_instance_valid(padre):
		return null
		
	# Comprobar si ya tiene un oclusor
	for hijo in padre.get_children():
		if hijo is OccluderInstance3D:
			return hijo
			
	var occluder_inst = OccluderInstance3D.new()
	occluder_inst.name = "OccluderInstance3D"
	
	var box_occ = BoxOccluder3D.new()
	box_occ.size = dimensiones
	occluder_inst.occluder = box_occ
	occluder_inst.transform = transform_local
	
	padre.add_child(occluder_inst)
	return occluder_inst
