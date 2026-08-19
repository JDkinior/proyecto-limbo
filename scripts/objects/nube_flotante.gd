class_name NubeFlotante
extends Node3D

# ===================================================================
# NUBE FLOTANTE ESTILIZADA 3D
# Proyecto Limbo - Comportamiento de deriva y flotación orgánica
# ===================================================================

@export_group("Movimiento de Deriva")
@export var velocidad: float = 2.2
@export var direccion: Vector3 = Vector3(1.0, 0.0, 0.25)
@export var auto_wrap: bool = true
@export var limites_min: Vector3 = Vector3(-60.0, 2.0, -60.0)
@export var limites_max: Vector3 = Vector3(60.0, 35.0, 60.0)

@export_group("Oscilación y Flotación")
@export var amplitud_flotacion: float = 0.35
@export var frecuencia_flotacion: float = 0.75
@export var amplitud_rotacion: float = 1.5 # en grados
@export var velocidad_rotacion: float = 0.4

var _offset_tiempo: float = 0.0
var _posicion_base_y: float = 0.0
var _rotacion_base_y: float = 0.0
var _dir_normalizada: Vector3 = Vector3.RIGHT

func _ready() -> void:
	# Desincronizar la fase según la posición inicial única de cada nube
	_offset_tiempo = (global_position.x * 0.37 + global_position.z * 0.71)
	_posicion_base_y = position.y
	_rotacion_base_y = rotation.y
	_dir_normalizada = direccion.normalized() if direccion.length_squared() > 0.001 else Vector3.RIGHT

func _process(delta: float) -> void:
	var t: float = (Time.get_ticks_msec() / 1000.0) + _offset_tiempo

	# 1. Deriva horizontal continua
	position += _dir_normalizada * (velocidad * delta)

	# 2. Oscilación suave vertical (efecto flotante)
	var onda_y: float = sin(t * frecuencia_flotacion) * amplitud_flotacion
	position.y = _posicion_base_y + onda_y

	# 3. Micro-balanceo suave de rotación
	var balanceo: float = deg_to_rad(sin(t * velocidad_rotacion) * amplitud_rotacion)
	rotation.z = balanceo * 0.5
	rotation.y = _rotacion_base_y + balanceo

	# 4. Envoltura de límites (Looping continuo en el escenario)
	if auto_wrap:
		_verificar_limites()

func _verificar_limites() -> void:
	# Si la nube sale del área máxima por X o Z, reaparece en el extremo opuesto
	if position.x > limites_max.x:
		position.x = limites_min.x
	elif position.x < limites_min.x:
		position.x = limites_max.x

	if position.z > limites_max.z:
		position.z = limites_min.z
	elif position.z < limites_min.z:
		position.z = limites_max.z
