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
const RANGO_VISIBILIDAD_CRISTALES: float = 90.0
const RANGO_VISIBILIDAD_FAROLES: float = 100.0
const RANGO_VISIBILIDAD_ARBOLES: float = 125.0
const RANGO_VISIBILIDAD_MONEDAS: float = 90.0
const RANGO_VISIBILIDAD_PARTICULAS: float = 55.0

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
		
	# 7. Personajes (Siluetas y Occlusion Culling Seguro)
	elif nodo is CharacterBody3D and (nodo.is_in_group("jugadores") or nodo.is_in_group("vivos") or nodo.is_in_group("fantasmas") or nodo.has_method("actualizar_silueta_oclusion")):
		_optimizar_personaje(nodo)
		return

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
	
	# Si no tiene configurado un rango de visibilidad, asignarle uno de alto rendimiento con corte limpio
	if mm.visibility_range_end == 0.0:
		mm.visibility_range_end = RANGO_VISIBILIDAD_PASTO
		mm.visibility_range_end_margin = 4.0
		mm.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

static func _optimizar_particulas(part: GeometryInstance3D) -> void:
	var nombre_low = part.name.to_lower()
	if nombre_low.contains("hoja") or nombre_low.contains("atraccion") or nombre_low.contains("vortice") or nombre_low.contains("torbellino") or nombre_low.contains("roca"):
		part.ignore_occlusion_culling = true
		part.extra_cull_margin = maxf(part.extra_cull_margin, 4.0)

	if part.visibility_range_end == 0.0:
		part.visibility_range_end = RANGO_VISIBILIDAD_PARTICULAS
		part.visibility_range_end_margin = 3.0
		part.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

static func _optimizar_malla_decorativa(mesh_inst: MeshInstance3D) -> void:
	var nombre_low = mesh_inst.name.to_lower()
	var padre_nombre_low = mesh_inst.get_parent().name.to_lower() if mesh_inst.get_parent() else ""
	
	# Árboles y copas (ampliar margen para evitar que las hojas se corten en los bordes del encuadre por viento/AABB)
	if nombre_low.contains("canopy") or nombre_low.contains("trunk") or padre_nombre_low.contains("arbol") or nombre_low.contains("arbol"):
		mesh_inst.extra_cull_margin = maxf(mesh_inst.extra_cull_margin, 4.0)
		if mesh_inst.visibility_range_end == 0.0:
			mesh_inst.visibility_range_end = RANGO_VISIBILIDAD_ARBOLES
			mesh_inst.visibility_range_end_margin = 5.0
			mesh_inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			
	# Cristales
	elif nombre_low.contains("cristal") or padre_nombre_low.contains("cristal") or nombre_low.contains("glowcrystal") or nombre_low.contains("monolith"):
		mesh_inst.extra_cull_margin = maxf(mesh_inst.extra_cull_margin, 1.5)
		if mesh_inst.visibility_range_end == 0.0:
			mesh_inst.visibility_range_end = RANGO_VISIBILIDAD_CRISTALES
			mesh_inst.visibility_range_end_margin = 4.0
			mesh_inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

	# Faroles
	elif nombre_low.contains("farol") or padre_nombre_low.contains("farol"):
		mesh_inst.extra_cull_margin = maxf(mesh_inst.extra_cull_margin, 1.5)
		if mesh_inst.visibility_range_end == 0.0:
			mesh_inst.visibility_range_end = RANGO_VISIBILIDAD_FAROLES
			mesh_inst.visibility_range_end_margin = 4.0
			mesh_inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			
	# Monedas
	elif nombre_low.contains("coin") or nombre_low.contains("moneda") or padre_nombre_low.contains("moneda"):
		mesh_inst.extra_cull_margin = maxf(mesh_inst.extra_cull_margin, 1.0)
		if mesh_inst.visibility_range_end == 0.0:
			mesh_inst.visibility_range_end = RANGO_VISIBILIDAD_MONEDAS
			mesh_inst.visibility_range_end_margin = 4.0
			mesh_inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

	# Nubes
	elif nombre_low.contains("nube") or padre_nombre_low.contains("nube") or nombre_low.contains("puff"):
		mesh_inst.extra_cull_margin = maxf(mesh_inst.extra_cull_margin, 6.0)
		if mesh_inst.visibility_range_end == 0.0:
			mesh_inst.visibility_range_end = 130.0
			mesh_inst.visibility_range_end_margin = 5.0
			mesh_inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

## Optimiza cuerpos estáticos grandes añadiéndoles oclusores si carecen de uno
static func _optimizar_static_body(body: StaticBody3D) -> void:
	# 1. No añadir oclusores si el cuerpo o su rama es invisible
	if not body.is_visible_in_tree():
		return

	# 2. No añadir oclusores a árboles, ramas ni elementos orgánicos del entorno
	var nombre_low = body.name.to_lower()
	var padre_nombre_low = body.get_parent().name.to_lower() if body.get_parent() else ""
	if nombre_low.contains("arbol") or padre_nombre_low.contains("arbol") or nombre_low.contains("canopy") or nombre_low.contains("trunk"):
		return

	# 3. No añadir oclusores a plataformas espirituales transparentes/activables por aura o cristales
	if body.is_in_group("plataformas_aura") or nombre_low.contains("cristal") or nombre_low.contains("vidrio"):
		return
		
	# 4. Verificar si ya tiene un oclusor
	for hijo in body.get_children():
		if hijo is OccluderInstance3D:
			return
			
	# 5. Solo añadir oclusores a muros o estructuras masivas opacas (grandes en al menos 2 dimensiones, ej. ancho y alto >= 3m)
	for hijo in body.get_children():
		if hijo is CollisionShape3D and hijo.shape is BoxShape3D:
			var box = hijo.shape as BoxShape3D
			var ejes_grandes = 0
			if box.size.x >= 3.0: ejes_grandes += 1
			if box.size.y >= 3.0: ejes_grandes += 1
			if box.size.z >= 3.0: ejes_grandes += 1
			if ejes_grandes >= 2:
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

## Optimiza mallas de personajes para compatibilidad con siluetas y X-Ray evitando que Occlusion Culling las descarte
static func _optimizar_personaje(personaje: Node) -> void:
	if personaje.has_method("actualizar_silueta_oclusion"):
		personaje.actualizar_silueta_oclusion()
	_asegurar_ignore_occlusion_personaje(personaje)

static func _asegurar_ignore_occlusion_personaje(nodo: Node) -> void:
	if nodo is MeshInstance3D and nodo.mesh:
		if nodo.name != "Aura" and nodo.name != "HaloSuave":
			nodo.ignore_occlusion_culling = true
			nodo.extra_cull_margin = maxf(nodo.extra_cull_margin, 0.5)
	for hijo in nodo.get_children():
		_asegurar_ignore_occlusion_personaje(hijo)

