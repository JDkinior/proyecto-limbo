@tool
extends ObjetoPoseibleBase
class_name EngranajeEspiritual

## ==============================================================================
## ENGRANAJE MECÁNICO ESPIRITUAL (PROYECTO LIMBO)
## Rueda dentada o manivela monumental de piedra que el Fantasma puede poseer.
## Permite girar y accionar compuertas pesadas, puentes levadizos o plataformas
## móviles mediante rotación continua con el joystick.
## ==============================================================================

signal progreso_cambiado(progreso: float)
signal rotacion_cambiada(angulo_rad: float)
signal limite_alcanzado(es_maximo: bool)

@export_group("Mecánica de Rotación")
@export var velocidad_rotacion: float = 3.5
@export var rotaciones_completas_necesarias: float = 2.0
@export var tiene_limite: bool = true
@export var retorno_automatico: bool = false
@export var velocidad_retorno: float = 0.5

@export_group("Mecanismo Vinculado")
@export var mecanismo_objetivo: Node3D = null

@export_group("Referencias")
@export var nodo_rueda_giratoria: Node3D = null

var _angulo_acumulado: float = 0.0
var _progreso_normalizado: float = 0.0

func _ready() -> void:
	super()
	nombre_objeto = "Engranaje Espiritual"
	distancia_camara_posesion = 5.2
	altura_spring_arm_posesion = 1.6
	pitch_defecto_posesion = -0.20

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if not esta_poseido and retorno_automatico and _progreso_normalizado > 0.0:
		_angulo_acumulado = move_toward(_angulo_acumulado, 0.0, velocidad_retorno * 2.0 * PI * delta)
		_actualizar_progreso_y_mecanismo()

func procesar_input_posesion(delta: float, input_dir: Vector2, _acciones: Dictionary) -> void:
	if not esta_poseido:
		return
	
	var input_giro = input_dir.x
	if absf(input_giro) > 0.05:
		var delta_angulo = input_giro * velocidad_rotacion * delta
		var max_angulo = rotaciones_completas_necesarias * TAU
		
		if tiene_limite:
			var nuevo_angulo = clampf(_angulo_acumulado + delta_angulo, 0.0, max_angulo)
			if nuevo_angulo == max_angulo and _angulo_acumulado < max_angulo:
				limite_alcanzado.emit(true)
			elif nuevo_angulo == 0.0 and _angulo_acumulado > 0.0:
				limite_alcanzado.emit(false)
			_angulo_acumulado = nuevo_angulo
		else:
			_angulo_acumulado += delta_angulo
		
		_actualizar_progreso_y_mecanismo()
		
		if is_instance_valid(nodo_ojos):
			nodo_ojos.actualizar_mirada(Vector3(input_giro, 0.0, 0.0), absf(input_giro))

func _actualizar_progreso_y_mecanismo() -> void:
	var max_angulo = maxf(rotaciones_completas_necesarias * TAU, 0.001)
	_progreso_normalizado = clampf(_angulo_acumulado / max_angulo, 0.0, 1.0)
	
	if is_instance_valid(nodo_rueda_giratoria):
		nodo_rueda_giratoria.rotation.z = _angulo_acumulado
	
	progreso_cambiado.emit(_progreso_normalizado)
	rotacion_cambiada.emit(_angulo_acumulado)
	
	# Si hay un mecanismo objetivo que acepte progreso (puerta, puente, plataforma)
	if is_instance_valid(mecanismo_objetivo):
		if mecanismo_objetivo.has_method("establecer_progreso"):
			mecanismo_objetivo.establecer_progreso(_progreso_normalizado)
		elif "progreso" in mecanismo_objetivo:
			mecanismo_objetivo.set("progreso", _progreso_normalizado)
