extends Node3D
class_name CristalInteractivo

## Radio adicional de detección para resonar cuando el aura del Fantasma se expande.
@export var radio_interaccion: float = 2.0

## Parámetros de iluminación (OmniLight3D)
@export var luz_energia_base: float = 0.9
@export var luz_energia_activa: float = 2.2
@export var luz_color_activa: Color = Color(0.4, 0.9, 1.0, 1.0)

## Parámetros de emisión del material del cristal
@export var emision_base: float = 0.45
@export var emision_activa: float = 1.15
@export var color_emision_base: Color = Color(0.25, 0.72, 0.95, 1.0)
@export var color_emision_activa: Color = Color(0.45, 0.92, 1.0, 1.0)

## Duraciones de transición
@export var duracion_activacion: float = 0.35
@export var duracion_retorno: float = 1.4

@onready var luz: OmniLight3D = get_node_or_null("OmniLight3D")
@onready var particulas: CPUParticles3D = get_node_or_null("ParticulasResonancia")

var _mesh_node: MeshInstance3D = null
var _material_instancia: StandardMaterial3D = null
var _esta_resonando: bool = false
var _tween_brillo: Tween = null
var _escala_base_mesh: Vector3 = Vector3.ONE

func _ready() -> void:
	_buscar_mesh_recursivo(self)
	_configurar_material()
	_asegurar_particulas()

	if is_instance_valid(luz):
		luz.light_energy = luz_energia_base

func _buscar_mesh_recursivo(nodo: Node) -> void:
	if _mesh_node != null:
		return
	if nodo != self and nodo is MeshInstance3D:
		_mesh_node = nodo
		_escala_base_mesh = _mesh_node.scale
		return
	for hijo in nodo.get_children():
		_buscar_mesh_recursivo(hijo)

func _configurar_material() -> void:
	if not is_instance_valid(_mesh_node):
		return
	
	# Usar material override si existe, o el material activo de la superficie 0
	var mat_original = _mesh_node.material_override
	if not mat_original and _mesh_node.mesh and _mesh_node.mesh.get_surface_count() > 0:
		mat_original = _mesh_node.get_active_material(0)
	
	if mat_original is StandardMaterial3D:
		_material_instancia = mat_original.duplicate() as StandardMaterial3D
	else:
		_material_instancia = StandardMaterial3D.new()
		_material_instancia.albedo_color = Color(0.48, 0.82, 0.98, 1)
		_material_instancia.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		_material_instancia.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material_instancia.roughness = 0.22
	
	_material_instancia.emission_enabled = true
	_material_instancia.emission = color_emision_base
	_material_instancia.emission_energy_multiplier = emision_base
	_mesh_node.material_override = _material_instancia

func _asegurar_particulas() -> void:
	if is_instance_valid(particulas):
		particulas.emitting = false
		return
	
	# Si la escena no tenía el nodo de partículas, lo generamos dinámicamente
	particulas = CPUParticles3D.new()
	particulas.name = "ParticulasResonancia"
	add_child(particulas)
	
	# Crear malla pequeña de destello tipo gema/diamante
	var quad = QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	
	var mat_part = StandardMaterial3D.new()
	mat_part.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_part.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat_part.albedo_color = Color(0.75, 0.95, 1.0, 0.9)
	mat_part.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = mat_part
	
	particulas.mesh = quad
	particulas.amount = 18
	particulas.lifetime = 1.3
	particulas.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particulas.emission_box_extents = Vector3(0.55, 0.85, 0.55)
	particulas.transform.origin = Vector3(0, 0.9, 0)
	particulas.gravity = Vector3(0, 1.1, 0)
	particulas.radial_accel_min = 0.1
	particulas.radial_accel_max = 0.5
	particulas.scale_amount_min = 0.4
	particulas.scale_amount_max = 1.2
	
	var grad = Gradient.new()
	grad.set_color(0, Color(0.5, 0.9, 1.0, 0.0))
	grad.add_point(0.2, Color(0.8, 0.98, 1.0, 0.95))
	grad.add_point(0.7, Color(0.4, 0.85, 1.0, 0.7))
	grad.set_color(1, Color(0.2, 0.6, 1.0, 0.0))
	particulas.color_ramp = grad
	
	particulas.emitting = false

func _process(_delta: float) -> void:
	var contacto_aura = _verificar_interaccion_aura()
	
	if contacto_aura and not _esta_resonando:
		_activar_resonancia()
	elif not contacto_aura and _esta_resonando:
		_desactivar_resonancia()

func _verificar_interaccion_aura() -> bool:
	var fantasmas = get_tree().get_nodes_in_group("fantasmas")
	for f in fantasmas:
		if not is_instance_valid(f):
			continue
		var aura = f.get("habilidad_aura")
		if is_instance_valid(aura) and aura.has_method("esta_activa") and aura.esta_activa():
			var pos_c_2d = Vector2(global_position.x, global_position.z)
			var pos_f_2d = Vector2(f.global_position.x, f.global_position.z)
			var dist = pos_c_2d.distance_to(pos_f_2d)
			var diff_y = abs(global_position.y - f.global_position.y)
			var radio_total = aura.obtener_radio() + radio_interaccion
			if dist <= radio_total and diff_y <= 3.5:
				return true
	return false

func _activar_resonancia() -> void:
	_esta_resonando = true
	
	if is_instance_valid(_tween_brillo) and _tween_brillo.is_valid():
		_tween_brillo.kill()
	
	_tween_brillo = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Transición suave del brillo del material
	if is_instance_valid(_material_instancia):
		_tween_brillo.tween_property(_material_instancia, "emission_energy_multiplier", emision_activa, duracion_activacion)
		_tween_brillo.tween_property(_material_instancia, "emission", color_emision_activa, duracion_activacion)
	
	# Transición de la luz OmniLight3D
	if is_instance_valid(luz):
		_tween_brillo.tween_property(luz, "light_energy", luz_energia_activa, duracion_activacion)
		_tween_brillo.tween_property(luz, "light_color", luz_color_activa, duracion_activacion)
	
	# Pequeño pulso de vida en la escala de la malla (3%)
	if is_instance_valid(_mesh_node):
		_tween_brillo.tween_property(_mesh_node, "scale", _escala_base_mesh * 1.035, duracion_activacion)
	
	# Activar emisión de partículas
	if is_instance_valid(particulas):
		particulas.emitting = true
		particulas.restart()

func _desactivar_resonancia() -> void:
	_esta_resonando = false
	
	if is_instance_valid(_tween_brillo) and _tween_brillo.is_valid():
		_tween_brillo.kill()
	
	_tween_brillo = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Retorno progresivo y orgánico a los valores base
	if is_instance_valid(_material_instancia):
		_tween_brillo.tween_property(_material_instancia, "emission_energy_multiplier", emision_base, duracion_retorno)
		_tween_brillo.tween_property(_material_instancia, "emission", color_emision_base, duracion_retorno)
	
	if is_instance_valid(luz):
		_tween_brillo.tween_property(luz, "light_energy", luz_energia_base, duracion_retorno)
		_tween_brillo.tween_property(luz, "light_color", Color(0.35, 0.82, 1.0, 1), duracion_retorno)
	
	if is_instance_valid(_mesh_node):
		_tween_brillo.tween_property(_mesh_node, "scale", _escala_base_mesh, duracion_retorno * 0.75)
	
	# Detener emisión continua (las partículas en vuelo terminan su ciclo naturalmente)
	if is_instance_valid(particulas):
		particulas.emitting = false
