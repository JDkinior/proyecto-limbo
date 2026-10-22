@tool
extends Node3D
class_name MiraCanonEspiritual

## ==============================================================================
## MIRA Y TRAYECTORIA ESPIRITUAL DEL CAÑÓN (PROYECTO LIMBO)
## Proyecta una retícula holográfica cyan procedural y una guía de energía
## a lo largo de la línea de apuntado del cañón poseído.
## ==============================================================================

@export var alcance_maximo: float = 38.0
@export var cantidad_puntos_trayectoria: int = 7
@export var color_espiritual: Color = Color(0.25, 0.9, 1.0, 0.92)

const SHADER_MIRA = preload("res://shaders/components/posesion/mira_canon.gdshader")

var nodo_origen: Node3D = null
var esta_activa: bool = false

var _raycast: RayCast3D = null
var _malla_reticula: MeshInstance3D = null
var _puntos_trayectoria: Array[MeshInstance3D] = []
var _material_mira: ShaderMaterial = null
var _material_punto: StandardMaterial3D = null
var _fase_animacion: float = 0.0
var _escala_actual: float = 0.0
var _escala_objetivo: float = 0.0
var _pulso_disparo: float = 0.0

func _ready() -> void:
	_inicializar_materiales()
	_construir_nodos()
	visible = false
	set_process(false)

func _inicializar_materiales() -> void:
	if not _material_mira:
		_material_mira = ShaderMaterial.new()
		_material_mira.shader = SHADER_MIRA
		_material_mira.set_shader_parameter("color_mira", color_espiritual)
	
	if not _material_punto:
		_material_punto = StandardMaterial3D.new()
		_material_punto.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material_punto.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material_punto.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_material_punto.albedo_color = color_espiritual

func _construir_nodos() -> void:
	# Raycast para detectar impactos con el entorno
	if not _raycast:
		_raycast = RayCast3D.new()
		_raycast.name = "RayCastMira"
		_raycast.enabled = false
		_raycast.collision_mask = 1 # Capa 1: Entorno/Mundo
		_raycast.collide_with_areas = false
		_raycast.collide_with_bodies = true
		_raycast.target_position = Vector3(0.0, 0.0, -alcance_maximo)
		add_child(_raycast)
	
	# Malla de la retícula (mira)
	if not _malla_reticula:
		_malla_reticula = MeshInstance3D.new()
		_malla_reticula.name = "Reticula"
		var quad = QuadMesh.new()
		quad.size = Vector2(1.5, 1.5)
		_malla_reticula.mesh = quad
		_malla_reticula.material_override = _material_mira
		_malla_reticula.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_malla_reticula)
	
	# Puntos luminosos de la trayectoria
	if _puntos_trayectoria.is_empty():
		var esfera = SphereMesh.new()
		esfera.radius = 0.065
		esfera.height = 0.13
		esfera.radial_segments = 8
		esfera.rings = 4
		
		for i in range(cantidad_puntos_trayectoria):
			var punto = MeshInstance3D.new()
			punto.name = "PuntoTrayectoria_%d" % i
			punto.mesh = esfera
			punto.material_override = _material_punto
			punto.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(punto)
			_puntos_trayectoria.append(punto)

func configurar_origen(origen: Node3D) -> void:
	nodo_origen = origen

func mostrar() -> void:
	esta_activa = true
	visible = true
	_escala_objetivo = 1.0
	_pulso_disparo = 0.0
	if _raycast:
		_raycast.enabled = true
	set_process(true)

func ocultar() -> void:
	esta_activa = false
	_escala_objetivo = 0.0
	if _raycast:
		_raycast.enabled = false

func pulsar_disparo() -> void:
	_pulso_disparo = 0.55

func _process(delta: float) -> void:
	# Transición suave de aparición/desaparición
	_escala_actual = move_toward(_escala_actual, _escala_objetivo, delta * 5.0)
	if not esta_activa and _escala_actual <= 0.01:
		visible = false
		set_process(false)
		return
	
	if _pulso_disparo > 0.0:
		_pulso_disparo = maxf(_pulso_disparo - delta * 2.5, 0.0)
	
	_fase_animacion = wrapf(_fase_animacion + delta * 1.8, 0.0, 1.0)
	
	var pos_inicio = nodo_origen.global_position if is_instance_valid(nodo_origen) else global_position
	var dir_adelante = -global_transform.basis.z.normalized()
	
	# Determinar punto de impacto con RayCast3D
	var punto_destino = pos_inicio + (dir_adelante * alcance_maximo)
	var colisiona = false
	var normal_colision = Vector3.UP
	
	if is_instance_valid(_raycast):
		_raycast.global_position = pos_inicio
		_raycast.target_position = _raycast.to_local(punto_destino)
		_raycast.force_raycast_update()
		if _raycast.is_colliding():
			colisiona = true
			punto_destino = _raycast.get_collision_point()
			normal_colision = _raycast.get_collision_normal()
	
	# Posicionar y orientar la retícula
	if is_instance_valid(_malla_reticula):
		var factor_escala = (_escala_actual + _pulso_disparo)
		_malla_reticula.global_position = punto_destino + (normal_colision * 0.04 if colisiona else Vector3.ZERO)
		_malla_reticula.scale = Vector3.ONE * factor_escala
		
		if colisiona and normal_colision.length_squared() > 0.5:
			# Alinear contra la superficie del impacto
			var up_ref = Vector3.UP if absf(normal_colision.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
			_malla_reticula.look_at(_malla_reticula.global_position + normal_colision, up_ref)
		else:
			# Mirar hacia el cañón en el aire
			_malla_reticula.look_at(pos_inicio, Vector3.UP)
	
	# Actualizar puntos de trayectoria con efecto de flujo de energía hacia el objetivo
	var total_puntos = _puntos_trayectoria.size()
	for i in range(total_puntos):
		var punto_mesh = _puntos_trayectoria[i]
		if not is_instance_valid(punto_mesh):
			continue
		
		# Fase normalizada a lo largo del segmento (0.0 = inicio, 1.0 = destino)
		var t_base = float(i + 1) / float(total_puntos + 1)
		var t = wrapf(t_base + (_fase_animacion / float(total_puntos + 1)), 0.05, 0.95)
		
		var pos_punto = pos_inicio.lerp(punto_destino, t)
		punto_mesh.global_position = pos_punto
		
		# Escala dinámica: más pequeño cerca de los extremos, visible en el centro
		var factor_fade = sin(t * PI)
		punto_mesh.scale = Vector3.ONE * (_escala_actual * factor_fade * (1.0 + _pulso_disparo * 0.5))
