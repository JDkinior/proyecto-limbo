extends Area3D
class_name InterruptorAura

# Interruptor de Aura Espiritual.
# Se activa en cuanto el campo de la HabilidadAura del Fantasma se expande y toca
# el radio de detección de este interruptor, manteniéndose activo mientras
# el aura siga en contacto (e.g. hasta que se encoja y deje de tocarlo, o desaparezca).

signal signal_activado
signal signal_desactivado

@export_group("Configuración de Detección")
@export var radio_deteccion_switch: float = 1.2 # Radio de contacto del propio interruptor

var esta_activo: bool = false
var _iluminado_por_farol: bool = false
var mesh_node: MeshInstance3D = null
var _fantasma_cache: Node = null
var _material_cache: StandardMaterial3D = null

const COLOR_INACTIVO := Color(0.7, 0.3, 0.9, 0.4)
const COLOR_AZUL_ACTIVO := Color(0.1, 0.75, 1.0, 0.9)

func _ready() -> void:
	# Capa 3 (Plano Espiritual) para permitir detección por el haz de FarolEspiritual
	# sin generar colisión física con jugadores ni enemigos.
	collision_layer = 1 << 2
	collision_mask = 0
	
	mesh_node = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not mesh_node:
		for hijo in get_children():
			if hijo is MeshInstance3D:
				mesh_node = hijo
				break
	
	# Cachear material una sola vez para evitar memory leaks
	if is_instance_valid(mesh_node):
		var mat = mesh_node.get_active_material(0)
		if not mat and mesh_node.mesh:
			mat = mesh_node.mesh.surface_get_material(0)
		if mat:
			_material_cache = mat.duplicate() as StandardMaterial3D
		else:
			_material_cache = StandardMaterial3D.new()
		mesh_node.set_surface_override_material(0, _material_cache)
	
	_actualizar_material(false)
	print("[InterruptorAura] Inicializado con radio de detección: ", radio_deteccion_switch)

func _obtener_fantasma() -> Node:
	if not is_instance_valid(_fantasma_cache):
		var fantasmas = get_tree().get_nodes_in_group("fantasmas")
		_fantasma_cache = fantasmas[0] if fantasmas.size() > 0 else null
	return _fantasma_cache

func _process(_delta: float) -> void:
	var algun_aura_tocando = false
	
	# Usar referencia cacheada en vez de buscar cada frame
	var f = _obtener_fantasma()
	if is_instance_valid(f) and f.habilidad_aura:
		var aura = f.habilidad_aura
		if aura.esta_activa():
			# Distancia horizontal (eje X/Z) para simular el cilindro del aura
			var pos_switch_2d = Vector2(global_position.x, global_position.z)
			var pos_ghost_2d = Vector2(f.global_position.x, f.global_position.z)
			var distancia_horizontal = pos_switch_2d.distance_to(pos_ghost_2d)
			
			# Rango vertical máximo para evitar activar interruptores en pisos superiores/inferiores
			var diferencia_y = abs(global_position.y - f.global_position.y)
			
			# El aura toca el interruptor si la distancia es menor o igual al
			# radio actual del aura más el radio de detección del interruptor
			var radio_total_deteccion = aura.obtener_radio() + radio_deteccion_switch
			if distancia_horizontal <= radio_total_deteccion and diferencia_y <= 2.5:
				algun_aura_tocando = true
				
	# Emitir cambios de estado (por contacto de aura o por luz del FarolEspiritual)
	var nuevo_estado: bool = algun_aura_tocando or _iluminado_por_farol
	if nuevo_estado != esta_activo:
		cambiar_estado(nuevo_estado)

func activar_por_luz(activo: bool) -> void:
	_iluminado_por_farol = activo
	if _iluminado_por_farol and not esta_activo:
		cambiar_estado(true)

func cambiar_estado(activo: bool) -> void:
	if activo == esta_activo:
		return
	esta_activo = activo
	_actualizar_material(esta_activo)
	if esta_activo:
		signal_activado.emit()
		print("[InterruptorAura] ¡Activado! El aura o haz espiritual está en contacto.")
	else:
		signal_desactivado.emit()
		print("[InterruptorAura] ¡Desactivado! El aura o haz espiritual se disipó.")

func _actualizar_material(activo: bool) -> void:
	if not is_instance_valid(mesh_node) or not is_instance_valid(_material_cache):
		return
	
	# Reutilizar el material cacheado sin duplicar
	if _material_cache is BaseMaterial3D:
		if activo:
			_material_cache.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_material_cache.albedo_color = COLOR_AZUL_ACTIVO
			_material_cache.emission_enabled = true
			_material_cache.emission = Color(0.1, 0.75, 1.0)
			_material_cache.emission_energy_multiplier = 3.5
		else:
			_material_cache.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_material_cache.albedo_color = COLOR_INACTIVO
			_material_cache.emission_enabled = false
