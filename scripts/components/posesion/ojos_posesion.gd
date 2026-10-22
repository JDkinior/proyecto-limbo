@tool
extends Node3D
class_name OjosPosesion

## ==============================================================================
## OJOS DE POSESIÓN ADAPTATIVOS (PROYECTO LIMBO)
## Representa fielmente los ojos del personaje Fantasma (3D, negros brillantes con
## reflejo especular) en la superficie frontal de objetos poseídos.
## Se adaptan independientemente a la curvatura y tamaño de la plataforma.
## ==============================================================================

enum Expresion {
	NORMAL,
	VELOCIDAD,
	SORPRESA,
	CERRADOS
}

@export var escala_ojos: Vector3 = Vector3(1.2, 1.2, 1.2):
	set(val):
		escala_ojos = val
		_actualizar_transform_base()

@export var parpadeo_activo: bool = true

var _tiempo_para_parpadeo: float = 3.0
var _duracion_parpadeo: float = 0.14
var _tiempo_parpadeo_actual: float = 0.0
var _esta_parpadeando: bool = false

var _offset_mirada_actual: Vector2 = Vector2.ZERO
var _offset_mirada_objetivo: Vector2 = Vector2.ZERO

var _expresion_actual: Expresion = Expresion.NORMAL
var _animando_aparicion: bool = false
var _tiempo_aparicion: float = 0.0

var _pos_base_izq: Vector3 = Vector3(-0.45, 0.0, 0.0)
var _pos_base_der: Vector3 = Vector3(0.45, 0.0, 0.0)
var _rot_base_izq: Vector3 = Vector3.ZERO
var _rot_base_der: Vector3 = Vector3.ZERO
var _escala_base_ojos: Vector3 = Vector3.ONE

@onready var nodo_modelo_ojos: Node3D = get_node_or_null("ModeloOjos")
@onready var ojo_izquierdo: Node3D = get_node_or_null("OjoIzquierdo")
@onready var ojo_derecho: Node3D = get_node_or_null("OjoDerecho")

const ESCENA_OJO_INDIVIDUAL = preload("res://assets/modelos/interactivos/ojo_fantasma_malla.glb")
const ESCENA_OJOS = preload("res://assets/modelos/interactivos/ojos_fantasma.glb")
const MATERIAL_OJOS = preload("res://assets/materiales/personajes/m_ojos_fantasma.tres")

func _ready() -> void:
	_configurar_mallas_ojos()
	_reiniciar_timer_parpadeo()
	var padre = get_parent()
	if padre and "esta_poseido" in padre and not Engine.is_editor_hint():
		visible = padre.esta_poseido
		if not visible:
			scale = Vector3.ZERO

func _configurar_mallas_ojos() -> void:
	if ojo_izquierdo == null:
		ojo_izquierdo = get_node_or_null("OjoIzquierdo") as Node3D
		if ojo_izquierdo == null:
			ojo_izquierdo = Node3D.new()
			ojo_izquierdo.name = "OjoIzquierdo"
			add_child(ojo_izquierdo)
	
	if ojo_derecho == null:
		ojo_derecho = get_node_or_null("OjoDerecho") as Node3D
		if ojo_derecho == null:
			ojo_derecho = Node3D.new()
			ojo_derecho.name = "OjoDerecho"
			add_child(ojo_derecho)
	
	if is_instance_valid(ojo_izquierdo) and ojo_izquierdo.get_child_count() == 0 and ESCENA_OJO_INDIVIDUAL != null:
		var malla_izq = ESCENA_OJO_INDIVIDUAL.instantiate()
		ojo_izquierdo.add_child(malla_izq)
	
	if is_instance_valid(ojo_derecho) and ojo_derecho.get_child_count() == 0 and ESCENA_OJO_INDIVIDUAL != null:
		var malla_der = ESCENA_OJO_INDIVIDUAL.instantiate()
		ojo_derecho.add_child(malla_der)

	if nodo_modelo_ojos == null:
		nodo_modelo_ojos = get_node_or_null("ModeloOjos") as Node3D
	if is_instance_valid(nodo_modelo_ojos):
		nodo_modelo_ojos.visible = false
	
	_aplicar_material_recursivo(ojo_izquierdo, MATERIAL_OJOS)
	_aplicar_material_recursivo(ojo_derecho, MATERIAL_OJOS)
	_actualizar_transform_base()

func _aplicar_material_recursivo(nodo: Node, mat: Material) -> void:
	if nodo is MeshInstance3D:
		var mi = nodo as MeshInstance3D
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for hijo in nodo.get_children():
		_aplicar_material_recursivo(hijo, mat)

func adaptar_a_superficie(pos_izq: Vector3, rot_izq: Vector3, pos_der: Vector3, rot_der: Vector3, escala_base: float = 1.0) -> void:
	_pos_base_izq = pos_izq
	_pos_base_der = pos_der
	_rot_base_izq = rot_izq
	_rot_base_der = rot_der
	_escala_base_ojos = escala_ojos * escala_base
	_actualizar_transform_base()

func _actualizar_transform_base() -> void:
	if is_instance_valid(ojo_izquierdo):
		ojo_izquierdo.position = _pos_base_izq
		ojo_izquierdo.rotation = _rot_base_izq
		ojo_izquierdo.scale = _escala_base_ojos
	if is_instance_valid(ojo_derecho):
		ojo_derecho.position = _pos_base_der
		ojo_derecho.rotation = _rot_base_der
		ojo_derecho.scale = _escala_base_ojos

func _process(delta: float) -> void:
	_procesar_animacion_aparicion(delta)
	_procesar_parpadeo(delta)
	_procesar_suavizado_mirada(delta)

func aparecer() -> void:
	visible = true
	_animando_aparicion = true
	_tiempo_aparicion = 0.0
	scale = Vector3.ZERO
	_expresion_actual = Expresion.SORPRESA
	_reiniciar_timer_parpadeo()

func desaparecer() -> void:
	var tween = create_tween()
	if tween:
		tween.tween_property(self, "scale", Vector3.ZERO, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): visible = false)
	else:
		visible = false

func _procesar_animacion_aparicion(delta: float) -> void:
	if not _animando_aparicion:
		return
	_tiempo_aparicion += delta
	var duracion = 0.35
	if _tiempo_aparicion >= duracion:
		_animando_aparicion = false
		scale = Vector3.ONE
		_expresion_actual = Expresion.NORMAL
		return
	
	# Efecto Overshoot / Bounce elástico
	var t = _tiempo_aparicion / duracion
	var s = 1.0 + sin(t * PI) * 0.35 * (1.0 - t)
	scale = Vector3.ONE * s

func _procesar_parpadeo(delta: float) -> void:
	if not parpadeo_activo or _animando_aparicion:
		return
	
	if _esta_parpadeando:
		_tiempo_parpadeo_actual += delta
		var factor = 0.0
		var mitad = _duracion_parpadeo * 0.5
		if _tiempo_parpadeo_actual < mitad:
			factor = _tiempo_parpadeo_actual / mitad
		else:
			factor = 1.0 - ((_tiempo_parpadeo_actual - mitad) / mitad)
		
		_aplicar_factor_parpadeo(clampf(factor, 0.0, 1.0))
		
		if _tiempo_parpadeo_actual >= _duracion_parpadeo:
			_esta_parpadeando = false
			_aplicar_factor_parpadeo(0.0)
			_reiniciar_timer_parpadeo()
	else:
		_tiempo_para_parpadeo -= delta
		if _tiempo_para_parpadeo <= 0.0:
			_esta_parpadeando = true
			_tiempo_parpadeo_actual = 0.0

func _reiniciar_timer_parpadeo() -> void:
	_tiempo_para_parpadeo = randf_range(2.2, 4.5)

func _aplicar_factor_parpadeo(factor: float) -> void:
	var escala_y = clampf(1.0 - factor * 0.92, 0.08, 1.0)
	if is_instance_valid(ojo_izquierdo):
		ojo_izquierdo.scale.y = _escala_base_ojos.y * escala_y
	if is_instance_valid(ojo_derecho):
		ojo_derecho.scale.y = _escala_base_ojos.y * escala_y

func actualizar_mirada(direccion_movimiento: Vector3, velocidad_relativa: float) -> void:
	var x = clampf(direccion_movimiento.x * 1.2, -1.0, 1.0)
	var y = clampf(-direccion_movimiento.z * 0.8, -0.6, 0.6)
	_offset_mirada_objetivo = Vector2(x, y)
	
	if velocidad_relativa > 0.8:
		_expresion_actual = Expresion.VELOCIDAD
	elif _expresion_actual == Expresion.VELOCIDAD and velocidad_relativa < 0.3:
		_expresion_actual = Expresion.NORMAL

func activar_expresion_sorpresa() -> void:
	_expresion_actual = Expresion.SORPRESA
	_offset_mirada_objetivo = Vector2(0.0, 0.2)
	var tween = create_tween()
	if tween:
		if is_instance_valid(ojo_izquierdo):
			tween.parallel().tween_property(ojo_izquierdo, "scale", _escala_base_ojos * 1.25, 0.12).set_trans(Tween.TRANS_BACK)
			tween.parallel().tween_property(ojo_izquierdo, "scale", _escala_base_ojos, 0.22)
		if is_instance_valid(ojo_derecho):
			tween.parallel().tween_property(ojo_derecho, "scale", _escala_base_ojos * 1.25, 0.12).set_trans(Tween.TRANS_BACK)
			tween.parallel().tween_property(ojo_derecho, "scale", _escala_base_ojos, 0.22)
	
	var tree = get_tree()
	if tree:
		tree.create_timer(0.45).timeout.connect(func():
			if _expresion_actual == Expresion.SORPRESA:
				_expresion_actual = Expresion.NORMAL
		)

func _procesar_suavizado_mirada(delta: float) -> void:
	_offset_mirada_actual = _offset_mirada_actual.lerp(_offset_mirada_objetivo, 12.0 * delta)
	var delta_mirada = Vector3(_offset_mirada_actual.x * 0.05, _offset_mirada_actual.y * 0.04, 0.0)
	if is_instance_valid(ojo_izquierdo):
		ojo_izquierdo.position = _pos_base_izq + delta_mirada
	if is_instance_valid(ojo_derecho):
		ojo_derecho.position = _pos_base_der + delta_mirada
