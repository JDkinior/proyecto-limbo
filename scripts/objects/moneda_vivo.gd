extends ColeccionableBase

# Moneda para el Jugador Vivo.
# Detecta únicamente al jugador Vivo (Capa 2) y se destruye de forma sincronizada.
# Cuando es vista por el Fantasma (o en el reino espiritual), se muestra de color azul espiritual.

var _material_azul: StandardMaterial3D = null
var _luz: OmniLight3D = null
var _mesh_instances: Array[MeshInstance3D] = []

const COLOR_LUZ_VIVO := Color(1.0, 0.8, 0.2, 1.0)
const COLOR_LUZ_FANTASMA := Color(0.25, 0.75, 1.0, 1.0)

func _configurar_colision() -> void:
	add_to_group("monedas_vivo")
	# Detecta ÚNICAMENTE al jugador Vivo (Capa 2)
	collision_mask = 1 << 1

func _configurar_visual() -> void:
	_luz = get_node_or_null("OmniLight3D")
	_crear_material_espiritual()
	_recolectar_mesh_instances(self)
	
	if is_instance_valid(RedManager):
		if RedManager.has_signal("reino_cambiado") and not RedManager.reino_cambiado.is_connected(_on_reino_cambiado):
			RedManager.reino_cambiado.connect(_on_reino_cambiado)
		if RedManager.has_signal("personaje_solo_cambiado") and not RedManager.personaje_solo_cambiado.is_connected(_on_personaje_cambiado):
			RedManager.personaje_solo_cambiado.connect(_on_personaje_cambiado)
			
	_actualizar_apariencia()
	_actualizar_apariencia.call_deferred()

func _crear_material_espiritual() -> void:
	_material_azul = StandardMaterial3D.new()
	_material_azul.albedo_color = Color(0.32, 0.78, 1.0, 1.0)
	_material_azul.metallic = 0.88
	_material_azul.roughness = 0.12
	_material_azul.emission_enabled = true
	_material_azul.emission = Color(0.15, 0.65, 1.0, 1.0)
	_material_azul.emission_energy_multiplier = 1.6
	_material_azul.rim_enabled = true
	_material_azul.rim = 0.85
	_material_azul.rim_tint = 0.5

func _recolectar_mesh_instances(nodo: Node) -> void:
	if nodo is MeshInstance3D:
		_mesh_instances.append(nodo)
	for hijo in nodo.get_children():
		_recolectar_mesh_instances(hijo)

func _on_reino_cambiado(es_fantasma: bool) -> void:
	_aplicar_apariencia_espiritual(es_fantasma)

func _on_personaje_cambiado(_nuevo_personaje: String) -> void:
	_actualizar_apariencia()

func _actualizar_apariencia() -> void:
	_aplicar_apariencia_espiritual(_es_reino_fantasma())

func _es_reino_fantasma() -> bool:
	if Engine.is_editor_hint():
		return false
		
	# 1. Cámara activa del viewport
	var cam = get_viewport().get_camera_3d() if is_inside_tree() else null
	if is_instance_valid(cam):
		if cam.name.contains("Transicion"):
			return (cam.cull_mask & (1 << 2)) != 0
		var nodo: Node = cam.get_parent()
		while is_instance_valid(nodo):
			if nodo.is_in_group("fantasmas") or nodo.name.to_lower().contains("fantasma"):
				return true
			if nodo.is_in_group("vivos") or nodo.name.to_lower().contains("jugador") or nodo.name.to_lower().contains("vivo"):
				return false
			nodo = nodo.get_parent()
			
	# 2. RedManager (un jugador y multijugador)
	if is_instance_valid(RedManager):
		if RedManager.has_method("es_reino_espiritual_activo"):
			return RedManager.es_reino_espiritual_activo()
		if RedManager.es_un_jugador and "personaje_activo_solo" in RedManager:
			return RedManager.personaje_activo_solo == "fantasma"
		if "peer_personajes" in RedManager:
			var mi_id = RedManager.get_mi_peer_id()
			if RedManager.peer_personajes.has(mi_id):
				return RedManager.peer_personajes[mi_id] == "fantasma"
				
	return false

func _aplicar_apariencia_espiritual(es_espiritual: bool) -> void:
	for mesh_inst in _mesh_instances:
		if is_instance_valid(mesh_inst):
			mesh_inst.material_override = _material_azul if es_espiritual else null
			
	if is_instance_valid(_luz):
		_luz.light_color = COLOR_LUZ_FANTASMA if es_espiritual else COLOR_LUZ_VIVO

func _puede_ser_recogido_por(body: Node) -> bool:
	return body is Jugador

func _aplicar_puntuacion() -> void:
	if is_instance_valid(ScoreManager):
		ScoreManager.add_score_vivo(value)
	else:
		push_warning("[MonedaVivo] ScoreManager no disponible.")
