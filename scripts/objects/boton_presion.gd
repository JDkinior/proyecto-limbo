extends Area3D
class_name BotonPresion

# Botón de Presión Físico.
# Detecta cuerpos de la Capa 2 (Jugador Vivo y Cajas Empujables).
# Emite señales signal_activado y signal_desactivado.

signal signal_activado
signal signal_desactivado

var cuerpos_encima: int = 0
var mesh_node: MeshInstance3D = null
var posicion_inicial_mesh: Vector3 = Vector3.ZERO
var tween: Tween = null

const COLOR_INACTIVO := Color(0.9, 0.3, 0.2, 1.0)
const COLOR_PRESIONADO := Color(0.2, 0.9, 0.3, 1.0)

func _ready() -> void:
	# No pertenece a ninguna capa de colisión física (es intangible)
	collision_layer = 0
	
	# Detecta ÚNICAMENTE objetos en Capa 2 (Plano Físico)
	collision_mask = 1 << 1
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	mesh_node = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not mesh_node:
		for hijo in get_children():
			if hijo is MeshInstance3D:
				mesh_node = hijo
				break
				
	if mesh_node:
		posicion_inicial_mesh = mesh_node.position
		_configurar_material(COLOR_INACTIVO, false)
		
	print("[BotonPresion] Inicializado en Capa 0, detectando Capa 2.")

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
	if not is_instance_valid(mesh_node):
		return
		
	if tween:
		tween.kill()
		
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	if presionado:
		var target_pos = posicion_inicial_mesh - Vector3(0, 0.035, 0)
		tween.tween_property(mesh_node, "position", target_pos, 0.15)
		_configurar_material(COLOR_PRESIONADO, true)
	else:
		tween.tween_property(mesh_node, "position", posicion_inicial_mesh, 0.15)
		_configurar_material(COLOR_INACTIVO, false)

func _configurar_material(color: Color, brillar: bool) -> void:
	if not is_instance_valid(mesh_node):
		return
		
	var mat = mesh_node.get_active_material(0)
	if not mat and mesh_node.mesh:
		mat = mesh_node.mesh.surface_get_material(0)
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
			
	mesh_node.set_surface_override_material(0, mat)

