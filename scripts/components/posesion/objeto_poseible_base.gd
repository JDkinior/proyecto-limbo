@tool
extends CharacterBody3D
class_name ObjetoPoseibleBase

## ==============================================================================
## CLASE BASE: OBJETO POSEÍBLE POR EL FANTASMA - PROYECTO LIMBO
## Inspirado en Super Mario Odyssey / Kirby and the Forgotten Land.
## Permite al Fantasma poseer objetos físicos, transformando su control,
## adaptando dinámicamente la cámara y mostrando ojos expresivos y aura translúcida.
## ==============================================================================

signal posesion_iniciada(fantasma: CharacterBase)
signal posesion_terminada()
signal estado_posesion_actualizado(esta_poseido: bool)

@export_group("Identidad y Tipo")
@export var nombre_objeto: String = "Objeto Poseíble"
@export var puede_ser_poseido: bool = true

@export_group("Adaptación de Cámara")
## Distancia del SpringArm cuando el fantasma posee este objeto específico.
@export var distancia_camara_posesion: float = 6.5
## Altura vertical del pivote de cámara respecto al centro del objeto.
@export var altura_spring_arm_posesion: float = 1.8
## Inclinación vertical (pitch en radianes) por defecto de la cámara.
@export var pitch_defecto_posesion: float = -0.22
## Desplazamiento vertical (v_offset) de la lente de la cámara.
@export var v_offset_camara_posesion: float = 0.0
## Multiplicador de alejamiento si el modo grabación Shorts (9:16 vertical) está activo.
@export var multiplicador_distancia_shorts: float = 1.25

@export_group("Parámetros Físicos y Eyección")
## Fuerza con la que el fantasma sale disparado hacia arriba al desposeer.
@export var fuerza_eyeccion_fantasma: float = 10.5
## Impulso horizontal opcional al salir.
@export var impulso_eyeccion_horizontal: float = 0.0

@export_group("Referencias de Nodos")
@export var nodo_ojos: OjosPosesion = null
@export var nodo_cabeza: Node3D = null
@export var marcador_foco_camara: Marker3D = null
@export var marcador_punto_eyeccion: Marker3D = null
@export var area_deteccion_posesion: Area3D = null

var fantasma_poseedor: Node3D = null
var esta_poseido: bool = false
var es_candidato_posesion: bool = false

# Diccionario para restaurar materiales originales al desposeer
var _materiales_originales_cache: Dictionary = {}
var _mallas_objetivo: Array[MeshInstance3D] = []

const MATERIAL_POSESION_DEFAULT = preload("res://assets/materiales/entorno/m_isla_espectral_poseida.tres")
const SHADER_INDICADOR = preload("res://shaders/components/posesion/indicador_objeto_poseible.gdshader")
var _material_posesion_instancia: Material = null
var _material_indicador_instancia: ShaderMaterial = null
var _tween_resalte: Tween = null

func _ready() -> void:
	add_to_group("objetos_poseibles")
	_inicializar_material_posesion()
	_inicializar_material_indicador()
	_recopilar_mallas_para_shader()
	_asegurar_zona_deteccion()
	_configurar_colisiones_base()
	
	if is_instance_valid(nodo_cabeza):
		nodo_cabeza.visible = esta_poseido
		if not esta_poseido:
			var orig = nodo_cabeza.get("_escala_original")
			if orig is Vector3:
				nodo_cabeza.scale = orig * 0.01
			else:
				nodo_cabeza.scale = nodo_cabeza.scale * 0.01
	
	if Engine.is_editor_hint():
		return

func _inicializar_material_posesion() -> void:
	if not _material_posesion_instancia:
		_material_posesion_instancia = MATERIAL_POSESION_DEFAULT

func _inicializar_material_indicador() -> void:
	if not _material_indicador_instancia:
		_material_indicador_instancia = ShaderMaterial.new()
		_material_indicador_instancia.shader = SHADER_INDICADOR
		_material_indicador_instancia.set_shader_parameter("intensidad", 0.0)

func _recopilar_mallas_para_shader() -> void:
	_mallas_objetivo.clear()
	_materiales_originales_cache.clear()
	for child in find_children("*", "MeshInstance3D", true, false):
		var mesh_inst = child as MeshInstance3D
		# No alterar los ojos, el copete ni partículas
		if is_instance_valid(nodo_ojos) and (mesh_inst == nodo_ojos.ojo_izquierdo or mesh_inst == nodo_ojos.ojo_derecho or nodo_ojos.is_ancestor_of(mesh_inst)):
			continue
		if is_instance_valid(nodo_cabeza) and (mesh_inst == nodo_cabeza or nodo_cabeza.is_ancestor_of(mesh_inst)):
			continue
		var mira = get("nodo_mira")
		if is_instance_valid(mira) and (mesh_inst == mira or mira.is_ancestor_of(mesh_inst)):
			continue
		_mallas_objetivo.append(mesh_inst)
		_materiales_originales_cache[mesh_inst] = mesh_inst.material_override

func _asegurar_zona_deteccion() -> void:
	if not area_deteccion_posesion:
		area_deteccion_posesion = get_node_or_null("AreaPosesion") as Area3D
	
	if not area_deteccion_posesion and not Engine.is_editor_hint():
		area_deteccion_posesion = Area3D.new()
		area_deteccion_posesion.name = "AreaPosesion"
		var shape_col = CollisionShape3D.new()
		var sphere = SphereShape3D.new()
		sphere.radius = 3.5
		shape_col.shape = sphere
		area_deteccion_posesion.add_child(shape_col)
		add_child(area_deteccion_posesion)
	
	if area_deteccion_posesion:
		# Detecta al Fantasma (Capa 3 = valor 4)
		area_deteccion_posesion.collision_layer = 0
		area_deteccion_posesion.collision_mask = 1 << 2 # Capa 3

func _configurar_colisiones_base() -> void:
	# Por defecto, los objetos poseíbles forman parte del entorno (Capa 1)
	# y son sólidos transitables para el Vivo (Capa 2)
	collision_layer = (1 << 0) | (1 << 1)
	collision_mask = (1 << 0) # Colisiona con el entorno mundial

# ─────────────────────────────────────────────────────────────────────────────
# CONSULTAS DE CÁMARA ADAPTATIVA (REQUERIMIENTO CENTRAL)
# ─────────────────────────────────────────────────────────────────────────────

func obtener_distancia_camara_adaptada() -> float:
	return distancia_camara_posesion * multiplicador_distancia_shorts

func obtener_altura_camara_adaptada() -> float:
	return altura_spring_arm_posesion

func obtener_pitch_camara_adaptado() -> float:
	return pitch_defecto_posesion

func obtener_v_offset_camara_adaptado() -> float:
	return v_offset_camara_posesion

func obtener_posicion_foco_camara() -> Vector3:
	if is_instance_valid(marcador_foco_camara):
		return marcador_foco_camara.global_position
	return global_position + Vector3(0.0, altura_spring_arm_posesion * 0.4, 0.0)

func obtener_punto_eyeccion() -> Vector3:
	if is_instance_valid(marcador_punto_eyeccion):
		return marcador_punto_eyeccion.global_position
	return global_position + Vector3(0.0, 1.8, 0.0)

# ─────────────────────────────────────────────────────────────────────────────
# CICLO DE POSESIÓN
# ─────────────────────────────────────────────────────────────────────────────

func iniciar_posesion(fantasma: Node3D) -> bool:
	if not puede_ser_poseido or esta_poseido:
		return false
	
	establecer_resalte_candidato(false)
	for mesh_inst in _mallas_objetivo:
		if is_instance_valid(mesh_inst):
			mesh_inst.material_overlay = null
			
	fantasma_poseedor = fantasma
	esta_poseido = true
	
	_aplicar_efectos_visuales_posesion(true)
	
	if is_instance_valid(nodo_ojos):
		nodo_ojos.aparecer()
	
	if is_instance_valid(nodo_cabeza):
		if nodo_cabeza.has_method("emerger"):
			nodo_cabeza.emerger()
		else:
			nodo_cabeza.visible = true
	
	_al_iniciar_posesion()
	
	posesion_iniciada.emit(fantasma)
	estado_posesion_actualizado.emit(true)
	return true

func terminar_posesion() -> void:
	if not esta_poseido:
		return
	
	var fantasma_saliente = fantasma_poseedor
	esta_poseido = false
	fantasma_poseedor = null
	
	_aplicar_efectos_visuales_posesion(false)
	
	if is_instance_valid(nodo_ojos):
		nodo_ojos.desaparecer()
	
	if is_instance_valid(nodo_cabeza):
		if nodo_cabeza.has_method("ocultar_suave"):
			nodo_cabeza.ocultar_suave()
		else:
			nodo_cabeza.visible = false
	
	_al_terminar_posesion()
	
	posesion_terminada.emit()
	estado_posesion_actualizado.emit(false)
	
	# Expulsar al fantasma en el punto de eyección con salto hacia arriba
	if is_instance_valid(fantasma_saliente):
		var pos_salida = obtener_punto_eyeccion()
		fantasma_saliente.global_position = pos_salida
		if "velocity" in fantasma_saliente:
			fantasma_saliente.velocity = Vector3.UP * fuerza_eyeccion_fantasma
		if not Engine.is_editor_hint() and fantasma_saliente.has_method("_iniciar_animacion_salto_fantasma"):
			fantasma_saliente._iniciar_animacion_salto_fantasma()

func _aplicar_efectos_visuales_posesion(activar: bool) -> void:
	if _mallas_objetivo.is_empty():
		_recopilar_mallas_para_shader()
	if activar:
		for mesh_inst in _mallas_objetivo:
			if is_instance_valid(mesh_inst):
				mesh_inst.material_override = _material_posesion_instancia
	else:
		for mesh_inst in _mallas_objetivo:
			if is_instance_valid(mesh_inst):
				var mat_orig = _materiales_originales_cache.get(mesh_inst, null)
				mesh_inst.material_override = mat_orig

## Activa o desactiva el resalte azul sutil cuando el Fantasma se aproxima a este objeto
func establecer_resalte_candidato(activo: bool) -> void:
	if es_candidato_posesion == activo:
		return
	es_candidato_posesion = activo
	_aplicar_efectos_resalte_candidato(activo)

func _aplicar_efectos_resalte_candidato(activo: bool) -> void:
	if Engine.is_editor_hint():
		return
	_inicializar_material_indicador()
	if not is_instance_valid(_material_indicador_instancia):
		return
	
	if _mallas_objetivo.is_empty():
		_recopilar_mallas_para_shader()
	
	if is_instance_valid(_tween_resalte):
		_tween_resalte.kill()
	
	if activo and not esta_poseido and puede_ser_poseido:
		for mesh_inst in _mallas_objetivo:
			if is_instance_valid(mesh_inst):
				mesh_inst.material_overlay = _material_indicador_instancia
		
		_tween_resalte = create_tween()
		if _tween_resalte:
			var valor_actual: float = _material_indicador_instancia.get_shader_parameter("intensidad") if _material_indicador_instancia else 0.0
			_tween_resalte.tween_method(_actualizar_intensidad_indicador, valor_actual, 1.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_tween_resalte = create_tween()
		if _tween_resalte:
			var valor_actual: float = _material_indicador_instancia.get_shader_parameter("intensidad") if _material_indicador_instancia else 1.0
			_tween_resalte.tween_method(_actualizar_intensidad_indicador, valor_actual, 0.0, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			_tween_resalte.finished.connect(_limpiar_overlay_indicador)

func _actualizar_intensidad_indicador(val: float) -> void:
	if is_instance_valid(_material_indicador_instancia):
		_material_indicador_instancia.set_shader_parameter("intensidad", val)

func _limpiar_overlay_indicador() -> void:
	if not es_candidato_posesion:
		for mesh_inst in _mallas_objetivo:
			if is_instance_valid(mesh_inst) and mesh_inst.material_overlay == _material_indicador_instancia:
				mesh_inst.material_overlay = null

# Métodos virtuales para ser extendidos por subclases
func _al_iniciar_posesion() -> void:
	pass

func _al_terminar_posesion() -> void:
	pass

func procesar_input_posesion(_delta: float, _input_dir: Vector2, _acciones: Dictionary) -> void:
	pass
