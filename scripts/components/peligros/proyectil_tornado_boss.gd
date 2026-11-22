extends Node3D
class_name ProyectilTornadoBoss

## ==============================================================================
## PROYECTIL TORNADO ESPIRITUAL DEL JEFE (PROYECTO LIMBO)
## Remolino móvil lanzado por el Espectro Guerrero hacia el Fantasma para
## alejarlo e impedirle usar el Aura con facilidad mientras el Vivo escala.
## ==============================================================================

signal fantasma_empujado(fantasma: Node3D, direccion: Vector3)
signal fantasma_reaparecido_por_tornado(fantasma: Node3D)
signal tornado_finalizado(tornado: ProyectilTornadoBoss)

const MAT_TORBELLINO_BASE = preload("res://shaders/components/peligros/torbellino_espiritual_mat.tres")
const MESH_ROCA_VORTICE = preload("res://assets/materiales/entorno/m_roca_vortice_a.tres")

@export var direccion: Vector3 = Vector3.FORWARD
@export var velocidad: float = 9.2
@export var tiempo_vida: float = 2.6
@export var radio_empuje: float = 1.45
@export var radio_atrapar: float = 1.65
@export var tiempo_atrapado_para_reaparecer: float = 0.55
@export var fuerza_empuje_continuo: float = 18.0
@export var fuerza_impulso_impacto: float = 5.8
@export var fuerza_giro_tangencial: float = 14.0
@export var fuerza_succion_nucleo: float = 7.8
@export var velocidad_giro_homing: float = 1.25
@export var altura_tornado: float = 3.4
@export var radio_maximo_arena: float = 11.6

var centro_arena: Vector3 = Vector3.ZERO
var objetivo_fantasma: Node3D = null

var _tiempo_vida_restante: float = 2.4
var _tiempo_acumulado: float = 0.0
var _cooldown_impacto: float = 0.0
var _tiempo_fantasma_atrapado: float = 0.0
var _vis_fantasma_capturado: bool = false
var _escala_vis_orig_fantasma: Vector3 = Vector3.ONE
var _rot_y_vis_orig_fantasma: float = 0.0
var _disipado: bool = false
var _visual_construido: bool = false

var _nodo_visual: Node3D = null
var _embudo: MeshInstance3D = null
var _particulas: CPUParticles3D = null
var _luz: OmniLight3D = null

func _ready() -> void:
	_tiempo_vida_restante = tiempo_vida
	_construir_visuales()
	if is_inside_tree() and is_instance_valid(_nodo_visual):
		_nodo_visual.scale = Vector3(0.1, 0.1, 0.1)
		var tw := create_tween()
		tw.tween_property(_nodo_visual, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _construir_visuales() -> void:
	if _visual_construido:
		return
	_visual_construido = true

	_nodo_visual = Node3D.new()
	_nodo_visual.name = "Visual"
	add_child(_nodo_visual)

	# 1. Embudo cónico reutilizando el shader de torbellino con tinte cian-violeta agresivo
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.15
	cyl.bottom_radius = 0.25
	cyl.height = altura_tornado
	cyl.radial_segments = 24
	cyl.rings = 14
	cyl.cap_top = false
	cyl.cap_bottom = false

	if MAT_TORBELLINO_BASE is ShaderMaterial:
		var mat := MAT_TORBELLINO_BASE.duplicate() as ShaderMaterial
		mat.set_shader_parameter("radio_base", 0.25)
		mat.set_shader_parameter("radio_cima", 1.15)
		mat.set_shader_parameter("altura_cono", altura_tornado)
		mat.set_shader_parameter("velocidad_giro", 3.6)
		mat.set_shader_parameter("color_profundo", Color(0.18, 0.35, 0.98, 0.62))
		mat.set_shader_parameter("color_medio", Color(0.24, 0.72, 1.0, 0.52))
		mat.set_shader_parameter("color_cima", Color(0.45, 0.92, 1.0, 0.42))
		mat.set_shader_parameter("color_cinta_nucleo", Color(0.45, 0.95, 1.0, 1.0))
		mat.set_shader_parameter("color_cinta_halo", Color(0.28, 0.45, 1.0, 1.0))
		cyl.material = mat

	_embudo = MeshInstance3D.new()
	_embudo.name = "EmbudoVortice"
	_embudo.mesh = cyl
	_embudo.position = Vector3(0.0, altura_tornado * 0.5 + 0.15, 0.0)
	_embudo.layers = 1 | 4 # Visible para Vivo y Fantasma
	_embudo.ignore_occlusion_culling = true
	_embudo.extra_cull_margin = 3.0
	_embudo.set_instance_shader_parameter("escala_xz", 1.0)
	_embudo.set_instance_shader_parameter("escala_y", 1.0)
	_nodo_visual.add_child(_embudo)

	# 2. Escombros/partículas girando en espiral dentro del tornado
	_particulas = CPUParticles3D.new()
	_particulas.name = "ParticulasVortice"
	_particulas.amount = 14
	_particulas.lifetime = 0.85
	_particulas.layers = 1 | 4
	_particulas.local_coords = true
	_particulas.ignore_occlusion_culling = true
	_particulas.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_particulas.emission_ring_axis = Vector3.UP
	_particulas.emission_ring_height = altura_tornado * 0.75
	_particulas.emission_ring_radius = 0.95
	_particulas.emission_ring_inner_radius = 0.28
	_particulas.direction = Vector3.UP
	_particulas.spread = 22.0
	_particulas.gravity = Vector3(0.0, 1.2, 0.0)
	_particulas.initial_velocity_min = 0.8
	_particulas.initial_velocity_max = 1.9
	_particulas.tangential_accel_min = 9.0
	_particulas.tangential_accel_max = 14.0
	_particulas.scale_amount_min = 0.18
	_particulas.scale_amount_max = 0.36
	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 0.3))
	curva.add_point(Vector2(0.45, 1.0))
	curva.add_point(Vector2(1.0, 0.05))
	_particulas.scale_amount_curve = curva
	if MESH_ROCA_VORTICE is Mesh:
		_particulas.mesh = MESH_ROCA_VORTICE
	_particulas.position = Vector3(0.0, altura_tornado * 0.45, 0.0)
	_particulas.emitting = true
	_nodo_visual.add_child(_particulas)

	# 3. Luz espiritual suave del torbellino
	_luz = OmniLight3D.new()
	_luz.name = "LuzVortice"
	_luz.light_color = Color(0.32, 0.82, 1.0)
	_luz.light_energy = 1.8
	_luz.omni_range = 4.2
	_luz.shadow_enabled = false
	_luz.position = Vector3(0.0, 1.4, 0.0)
	_nodo_visual.add_child(_luz)

func _physics_process(delta: float) -> void:
	procesar_tornado(delta)

func procesar_tornado(delta: float) -> void:
	if _disipado:
		return

	_tiempo_acumulado += delta
	_tiempo_vida_restante -= delta
	if _cooldown_impacto > 0.0:
		_cooldown_impacto = maxf(_cooldown_impacto - delta, 0.0)

	# Desplazamiento horizontal con curvatura de seguimiento (homing) hacia el Fantasma
	var dir_h := Vector3(direccion.x, 0.0, direccion.z)
	if dir_h.length_squared() < 0.0001:
		dir_h = Vector3.FORWARD
	else:
		dir_h = dir_h.normalized()

	var fantasma := _resolver_fantasma()
	var pos_actual := global_position if is_inside_tree() else position
	if is_instance_valid(fantasma) and velocidad_giro_homing > 0.0 and _tiempo_acumulado < 1.8:
		var pos_f_obj := fantasma.global_position if fantasma.is_inside_tree() else fantasma.position
		var hacia_f := Vector3(pos_f_obj.x - pos_actual.x, 0.0, pos_f_obj.z - pos_actual.z)
		if hacia_f.length_squared() > 0.25:
			var ang_actual := atan2(dir_h.x, dir_h.z)
			var ang_meta := atan2(hacia_f.x, hacia_f.z)
			var diff_ang := wrapf(ang_meta - ang_actual, -PI, PI)
			var giro_max := velocidad_giro_homing * delta
			var nuevo_ang := ang_actual + clampf(diff_ang, -giro_max, giro_max)
			dir_h = Vector3(sin(nuevo_ang), 0.0, cos(nuevo_ang)).normalized()
			direccion = dir_h

	var nueva_pos := pos_actual + dir_h * (velocidad * delta)
	nueva_pos.y = centro_arena.y
	if is_inside_tree():
		global_position = nueva_pos
	else:
		position = nueva_pos

	# Rotación veloz del embudo y pulsación energética
	if is_instance_valid(_nodo_visual):
		_nodo_visual.rotate_y(-deg_to_rad(420.0 * delta))
		if _tiempo_acumulado >= 0.2:
			_nodo_visual.scale.y = 1.0 + 0.08 * sin(_tiempo_acumulado * 9.5)

	# Succionar, arrastrar y atrapar al Fantasma si entra en el radio del tornado
	if is_instance_valid(fantasma):
		var vis_f := _obtener_nodo_visual_personaje(fantasma)
		var pos_f := fantasma.global_position if fantasma.is_inside_tree() else fantasma.position
		var dist_xz := Vector2(pos_f.x - nueva_pos.x, pos_f.z - nueva_pos.z).length()
		var en_rango_y: bool = pos_f.y >= (centro_arena.y - 0.8) and pos_f.y <= (centro_arena.y + altura_tornado + 1.5)
		if dist_xz <= maxf(radio_empuje, radio_atrapar) and en_rango_y:
			if not _vis_fantasma_capturado and is_instance_valid(vis_f):
				_vis_fantasma_capturado = true
				_escala_vis_orig_fantasma = vis_f.scale
				_rot_y_vis_orig_fantasma = vis_f.rotation.y
			_tiempo_fantasma_atrapado += delta
			_aplicar_empuje_a_fantasma(fantasma, pos_f, nueva_pos, dir_h, delta)
			var progreso_captura := clampf(_tiempo_fantasma_atrapado / maxf(tiempo_atrapado_para_reaparecer, 0.05), 0.0, 1.0)
			if is_instance_valid(vis_f):
				vis_f.scale = Vector3(
					_escala_vis_orig_fantasma.x * lerpf(1.0, 0.25, progreso_captura),
					_escala_vis_orig_fantasma.y * lerpf(1.0, 1.55, progreso_captura),
					_escala_vis_orig_fantasma.z * lerpf(1.0, 0.25, progreso_captura)
				)
				vis_f.rotate_y(deg_to_rad(540.0 * delta))
			if _tiempo_fantasma_atrapado >= tiempo_atrapado_para_reaparecer:
				_tiempo_fantasma_atrapado = 0.0
				_vis_fantasma_capturado = false
				if is_instance_valid(vis_f):
					vis_f.scale = _escala_vis_orig_fantasma
					vis_f.rotation.y = _rot_y_vis_orig_fantasma
				fantasma.scale = Vector3.ONE
				if fantasma.has_method("reaparecer"):
					fantasma.reaparecer()
				fantasma_reaparecido_por_tornado.emit(fantasma)
				disipar()
				return
		else:
			if _tiempo_fantasma_atrapado > 0.0:
				_tiempo_fantasma_atrapado = maxf(_tiempo_fantasma_atrapado - delta * 1.5, 0.0)
				if is_instance_valid(vis_f) and _vis_fantasma_capturado:
					vis_f.scale = vis_f.scale.lerp(_escala_vis_orig_fantasma, clampf(delta * 10.0, 0.0, 1.0))
					if _tiempo_fantasma_atrapado <= 0.0:
						vis_f.scale = _escala_vis_orig_fantasma
						vis_f.rotation.y = _rot_y_vis_orig_fantasma
						_vis_fantasma_capturado = false

	# Expiración por tiempo o al alcanzar los muros exteriores del coliseo
	var dist_centro := Vector2(nueva_pos.x - centro_arena.x, nueva_pos.z - centro_arena.z).length()
	if _tiempo_vida_restante <= 0.0 or dist_centro > radio_maximo_arena:
		disipar()

func _obtener_nodo_visual_personaje(pj: Node3D) -> Node3D:
	if not is_instance_valid(pj):
		return null
	for nombre in ["fantasma", "vivo", "Visual"]:
		var hijo := pj.get_node_or_null(nombre) as Node3D
		if is_instance_valid(hijo):
			return hijo
	return pj

func _resolver_fantasma() -> Node3D:
	if is_instance_valid(objetivo_fantasma):
		return objetivo_fantasma
	if is_inside_tree() and get_tree() != null:
		var lista := get_tree().get_nodes_in_group("fantasmas")
		if lista.size() > 0:
			objetivo_fantasma = lista[0] as Node3D
	return objetivo_fantasma

func _aplicar_empuje_a_fantasma(fantasma: Node3D, pos_f: Vector3, pos_tornado: Vector3, dir_h: Vector3, delta: float = 0.016) -> void:
	# Empujar en la dirección de arrastre del tornado alejando del centro, mientras succiona hacia el núcleo del vórtice
	var desde_centro := Vector3(pos_f.x - centro_arena.x, 0.0, pos_f.z - centro_arena.z)
	var dir_alejar_centro := desde_centro.normalized() if desde_centro.length_squared() > 0.01 else dir_h

	var hacia_nucleo := Vector3(pos_tornado.x - pos_f.x, 0.0, pos_tornado.z - pos_f.z)
	var dir_succion := hacia_nucleo.normalized() if hacia_nucleo.length_squared() > 0.005 else Vector3.ZERO

	var dir_push := (dir_alejar_centro * 0.55 + dir_h * 0.45)
	if dir_push.length_squared() < 0.001:
		dir_push = dir_h
	else:
		dir_push = dir_push.normalized()

	var tangencial := Vector3(dir_push.z, 0.0, -dir_push.x) * fuerza_giro_tangencial
	var fuerza_total := dir_push * fuerza_empuje_continuo + dir_succion * (fuerza_succion_nucleo * 3.0) + tangencial

	if fantasma.has_method("aplicar_fuerza_vortice"):
		fantasma.aplicar_fuerza_vortice(fuerza_total, 0.0)

	# Succión física hacia el centro del embudo en movimiento para atrapar al Fantasma
	var factor_succion := clampf(fuerza_succion_nucleo * delta, 0.0, 0.85)
	var pos_succionada := Vector3(
		lerpf(pos_f.x, pos_tornado.x, factor_succion),
		pos_f.y,
		lerpf(pos_f.z, pos_tornado.z, factor_succion)
	)
	if fantasma.is_inside_tree():
		fantasma.global_position = pos_succionada
	else:
		fantasma.position = pos_succionada

	# Interrumpir el aura del Fantasma al quedar atrapado en el vórtice
	var aura := fantasma.get_node_or_null("Aura")
	if is_instance_valid(aura) and "activa" in aura and bool(aura.get("activa")):
		if aura.has_method("desactivar_aura"):
			aura.call("desactivar_aura")
		else:
			aura.set("activa", false)

	if _cooldown_impacto <= 0.0:
		_cooldown_impacto = 0.42
		var impulso := dir_push * fuerza_impulso_impacto + Vector3(0.0, 1.8, 0.0)
		if fantasma.has_method("recibir_impulso_externo"):
			fantasma.recibir_impulso_externo(impulso)
		elif fantasma is CharacterBody3D:
			(fantasma as CharacterBody3D).velocity += impulso
		fantasma_empujado.emit(fantasma, dir_push)
		_feedback_empuje(fantasma)

func _feedback_empuje(fantasma: Node3D) -> void:
	if not is_inside_tree():
		return
	var es_activo: bool = fantasma.has_method("es_activo") and fantasma.es_activo()
	if es_activo:
		var vm := get_node_or_null("/root/VibrationManager")
		if is_instance_valid(vm) and vm.has_method("vibrar_dano"):
			vm.vibrar_dano()
	if fantasma.has_method("obtener_camara"):
		var cam := fantasma.obtener_camara() as Camera3D
		if is_instance_valid(cam):
			var tw := cam.create_tween()
			tw.tween_method(func(prog: float):
				if is_instance_valid(cam):
					var amp := (1.0 - prog) * 0.07
					cam.h_offset = randf_range(-1.0, 1.0) * amp
					cam.v_offset = randf_range(-1.0, 1.0) * amp
			, 0.0, 1.0, 0.18)
			tw.tween_callback(func():
				if is_instance_valid(cam):
					cam.h_offset = 0.0
					cam.v_offset = 0.0
			)

func disipar() -> void:
	if _disipado:
		return
	_disipado = true
	if is_instance_valid(objetivo_fantasma) and (_tiempo_fantasma_atrapado > 0.0 or _vis_fantasma_capturado):
		var vis_f := _obtener_nodo_visual_personaje(objetivo_fantasma)
		if is_instance_valid(vis_f) and _vis_fantasma_capturado:
			vis_f.scale = _escala_vis_orig_fantasma
			vis_f.rotation.y = _rot_y_vis_orig_fantasma
		objetivo_fantasma.scale = Vector3.ONE
	_vis_fantasma_capturado = false
	_tiempo_fantasma_atrapado = 0.0
	tornado_finalizado.emit(self)
	if not is_inside_tree():
		queue_free()
		return
	if is_instance_valid(_particulas):
		_particulas.emitting = false
	if is_instance_valid(_nodo_visual):
		var tw := create_tween()
		tw.tween_property(_nodo_visual, "scale", Vector3(0.02, 0.02, 0.02), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if is_instance_valid(_luz):
			tw.parallel().tween_property(_luz, "light_energy", 0.0, 0.18)
		tw.tween_callback(queue_free)
	else:
		queue_free()
