extends Area3D
class_name BotonPresion

# Botón de Presión Físico.
# Detecta cuerpos de la Capa 2 (Jugador Vivo y Cajas Empujables).
# Emite señales signal_activado y signal_desactivado.

signal signal_activado
signal signal_desactivado

var cuerpos_encima: int = 0
var nodo_boton: Node3D = null
var mesh_nodes: Array[MeshInstance3D] = []
var posicion_inicial_boton: Vector3 = Vector3.ZERO
var tween: Tween = null

@export var distancia_hundimiento: float = 0.08
@export var color_inactivo: Color = Color(0.9, 0.3, 0.2, 1.0)
@export var color_presionado: Color = Color(0.2, 0.9, 0.3, 1.0)

func _ready() -> void:
	# No pertenece a ninguna capa de colisión física (es intangible)
	collision_layer = 0
	
	# Detecta ÚNICAMENTE objetos en Capa 2 (Plano Físico)
	collision_mask = 1 << 1
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	_buscar_componentes_boton()
	
	if nodo_boton:
		posicion_inicial_boton = nodo_boton.position
		
	_configurar_material(color_inactivo, false)
		
	print("[BotonPresion] Inicializado en Capa 0, detectando Capa 2.")

func _buscar_componentes_boton() -> void:
	mesh_nodes.clear()
	
	# Buscar nodo 'Boton' (el 3D que se mueve al presionar)
	if has_node("Boton"):
		nodo_boton = get_node("Boton") as Node3D
	elif has_node("MeshInstance3D"):
		nodo_boton = get_node("MeshInstance3D") as Node3D
	else:
		# Fallback: buscar cualquier hijo que no sea CollisionShape3D ni Base boton
		for hijo in get_children():
			if hijo is Node3D and not (hijo is CollisionShape3D) and hijo.name != "Base boton":
				nodo_boton = hijo
				break

	if nodo_boton:
		if nodo_boton is MeshInstance3D:
			mesh_nodes.append(nodo_boton as MeshInstance3D)
		
		# Buscar todos los MeshInstance3D descendientes dentro del nodo del botón
		_recolectar_meshes(nodo_boton)

func _recolectar_meshes(nodo: Node) -> void:
	for hijo in nodo.get_children():
		if hijo is MeshInstance3D and not mesh_nodes.has(hijo):
			mesh_nodes.append(hijo as MeshInstance3D)
		if hijo.get_child_count() > 0:
			_recolectar_meshes(hijo)

func _on_body_entered(body: Node) -> void:
	cuerpos_encima += 1
	if cuerpos_encima == 1:
		signal_activado.emit()
		_animar_presion(true)
		print("[BotonPresion] Activado por: ", body.name)

func _on_body_exited(_body: Node) -> void:
	cuerpos_encima = max(0, cuerpos_encima - 1)
	if cuerpos_encima == 0:
		signal_desactivado.emit()
		_animar_presion(false)
		print("[BotonPresion] Desactivado")

func _animar_presion(presionado: bool) -> void:
	if not is_instance_valid(nodo_boton):
		return
		
	if tween:
		tween.kill()
		
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	if presionado:
		var target_pos = posicion_inicial_boton - Vector3(0, distancia_hundimiento, 0)
		tween.tween_property(nodo_boton, "position", target_pos, 0.15)
		_configurar_material(color_presionado, true)
	else:
		tween.tween_property(nodo_boton, "position", posicion_inicial_boton, 0.15)
		_configurar_material(color_inactivo, false)

func _configurar_material(color: Color, brillar: bool) -> void:
	for mesh_node in mesh_nodes:
		if not is_instance_valid(mesh_node):
			continue
			
		var surface_count = 1
		if mesh_node.mesh:
			surface_count = max(1, mesh_node.mesh.get_surface_count())
			
		for surf_idx in range(surface_count):
			var mat = mesh_node.get_active_material(surf_idx)
			if not mat and mesh_node.mesh and surf_idx < mesh_node.mesh.get_surface_count():
				mat = mesh_node.mesh.surface_get_material(surf_idx)
			if not mat:
				mat = StandardMaterial3D.new()
				
			mat = mat.duplicate()
			if mat is BaseMaterial3D:
				mat.albedo_color = color
				if brillar:
					mat.emission_enabled = true
					mat.emission = color
					mat.emission_energy_multiplier = 1.5
				else:
					mat.emission_enabled = false
					
			mesh_node.set_surface_override_material(surf_idx, mat)
