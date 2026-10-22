@tool
extends Node3D
class_name CabezaFantasmaEmergente

## ==============================================================================
## CABEZA FANTASMA EMERGENTE - PROYECTO LIMBO
## Representa la parte superior del fantasma (con su copete hacia atrás)
## emergiendo suavemente de la plataforma cuando es poseída.
## Incorpora el modelo "Copete Poseido Fantasma.glb" con sus animaciones:
## "Idle fantasma copete", "Volar fantasma copete" y "Parar fantasma copete".
## ==============================================================================

const MATERIAL_ESPECTRAL = preload("res://assets/materiales/entorno/m_isla_espectral_poseida.tres")

const ANIM_IDLE: String = "Idle fantasma copete"
const ANIM_VOLAR: String = "Volar fantasma copete"
const ANIM_PARAR: String = "Parar fantasma copete"

enum EstadoCopete {
	IDLE,
	VOLANDO,
	PARANDO
}

var anim_player: AnimationPlayer = null
var _tween_animacion: Tween = null
var _estado_actual: EstadoCopete = EstadoCopete.IDLE
var _escala_original: Vector3 = Vector3.ONE

func _enter_tree() -> void:
	_buscar_anim_player()
	_aplicar_material_espectral()

func _ready() -> void:
	if scale.length_squared() > 0.001:
		_escala_original = scale
	_buscar_anim_player()
	_configurar_animaciones()
	_aplicar_material_espectral()
	
	var padre = get_parent()
	if padre and "esta_poseido" in padre and not Engine.is_editor_hint():
		visible = padre.esta_poseido
		if not visible:
			scale = _escala_original * 0.01
		elif anim_player:
			reproducir_idle()

func _buscar_anim_player() -> void:
	if anim_player == null:
		anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer

func _configurar_animaciones() -> void:
	if not anim_player:
		return
	
	for nombre_loop in [ANIM_IDLE, ANIM_VOLAR]:
		if anim_player.has_animation(nombre_loop):
			var anim = anim_player.get_animation(nombre_loop)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
	
	if anim_player.has_animation(ANIM_PARAR):
		var anim_parar = anim_player.get_animation(ANIM_PARAR)
		if anim_parar:
			anim_parar.loop_mode = Animation.LOOP_NONE
	
	if not anim_player.animation_finished.is_connected(_on_animacion_terminada):
		anim_player.animation_finished.connect(_on_animacion_terminada)

func _aplicar_material_espectral() -> void:
	_aplicar_recursivo(self)

func _aplicar_recursivo(nodo: Node) -> void:
	if nodo is MeshInstance3D:
		var mi = nodo as MeshInstance3D
		mi.material_override = MATERIAL_ESPECTRAL
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for h in nodo.get_children():
		_aplicar_recursivo(h)

func emerger(duracion: float = 0.35) -> void:
	visible = true
	_buscar_anim_player()
	_configurar_animaciones()
	_aplicar_material_espectral()
	
	if is_instance_valid(_tween_animacion):
		_tween_animacion.kill()
	scale = _escala_original * 0.01
	_tween_animacion = create_tween()
	if _tween_animacion:
		_tween_animacion.tween_property(self, "scale", _escala_original, duracion).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	reproducir_idle()

func ocultar_suave(duracion: float = 0.22) -> void:
	if is_instance_valid(_tween_animacion):
		_tween_animacion.kill()
	_tween_animacion = create_tween()
	if _tween_animacion:
		_tween_animacion.tween_property(self, "scale", _escala_original * 0.01, duracion).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_tween_animacion.finished.connect(func():
			visible = false
			_estado_actual = EstadoCopete.IDLE
			if anim_player:
				anim_player.stop()
		)
	else:
		visible = false
		_estado_actual = EstadoCopete.IDLE
		if anim_player:
			anim_player.stop()

func reproducir_idle() -> void:
	_estado_actual = EstadoCopete.IDLE
	if anim_player and anim_player.has_animation(ANIM_IDLE):
		if anim_player.current_animation != ANIM_IDLE:
			anim_player.play(ANIM_IDLE, 0.25)

func reproducir_volar() -> void:
	_estado_actual = EstadoCopete.VOLANDO
	if anim_player and anim_player.has_animation(ANIM_VOLAR):
		if anim_player.current_animation != ANIM_VOLAR:
			anim_player.play(ANIM_VOLAR, 0.18)

func reproducir_parar() -> void:
	_estado_actual = EstadoCopete.PARANDO
	if anim_player and anim_player.has_animation(ANIM_PARAR):
		# Transición inmediata a parar para que la inercia actúe en el momento del frenado
		anim_player.play(ANIM_PARAR, 0.08, 1.25)

func _on_animacion_terminada(nombre: StringName) -> void:
	if nombre == StringName(ANIM_PARAR) and visible:
		# Al terminar el látigo de inercia y asentarse, vuelve suavemente a idle
		if _estado_actual == EstadoCopete.PARANDO:
			reproducir_idle()

## Actualiza el estado de animación según la velocidad relativa y si el jugador está acelerando/conduciendo
func actualizar_movimiento(vel_relativa: float, acelerando: bool = true) -> void:
	if not visible or anim_player == null:
		return
	
	if acelerando and vel_relativa > 0.08:
		# Conduciendo activamente -> volar (inclinado hacia atrás)
		if _estado_actual != EstadoCopete.VOLANDO:
			reproducir_volar()
	elif _estado_actual == EstadoCopete.VOLANDO and (not acelerando or vel_relativa < 0.08):
		# Estaba volando y se soltó el control o comenzó a frenar -> ¡inicia Parar INMEDIATAMENTE!
		reproducir_parar()
	elif _estado_actual == EstadoCopete.PARANDO:
		# Si vuelve a acelerar con fuerza mientras frenaba, vuelve a volar
		if acelerando and vel_relativa > 0.18:
			reproducir_volar()
		# Si continúa frenando, permite que la animación 'Parar' complete su ciclo de inercia
	elif _estado_actual == EstadoCopete.IDLE:
		if acelerando and vel_relativa > 0.08:
			reproducir_volar()
		elif anim_player.current_animation != ANIM_IDLE:
			reproducir_idle()
