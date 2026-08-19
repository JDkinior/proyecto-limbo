extends Control

var arrastre_camara : Vector2 = Vector2.ZERO
var _ultimo_tiempo_toque: float = -10.0
var _ultima_pos_toque: Vector2 = Vector2.ZERO
var _arrastre_acumulado: float = 0.0
var _solicitud_centrado: bool = false
const TIEMPO_DOBLE_TOQUE: float = 0.35
const DISTANCIA_MAX_DOBLE_TOQUE: float = 45.0

func _gui_input(event):
	if event is InputEventScreenTouch:
		if event.is_pressed():
			_arrastre_acumulado = 0.0
			var tiempo_actual = Time.get_ticks_msec() / 1000.0
			var delta_tiempo = tiempo_actual - _ultimo_tiempo_toque
			var dist = event.position.distance_to(_ultima_pos_toque)
			
			if delta_tiempo <= TIEMPO_DOBLE_TOQUE and dist <= DISTANCIA_MAX_DOBLE_TOQUE:
				_solicitud_centrado = true
				_ultimo_tiempo_toque = -10.0
			else:
				_ultimo_tiempo_toque = tiempo_actual
				_ultima_pos_toque = event.position
		else:
			if _arrastre_acumulado > 25.0:
				_ultimo_tiempo_toque = -10.0
				
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		arrastre_camara += event.relative
		_arrastre_acumulado += event.relative.length()

func consumir_arrastre() -> Vector2:
	var temp = arrastre_camara
	arrastre_camara = Vector2.ZERO
	return temp

func consumir_centrado_camara() -> bool:
	var temp = _solicitud_centrado
	_solicitud_centrado = false
	return temp
