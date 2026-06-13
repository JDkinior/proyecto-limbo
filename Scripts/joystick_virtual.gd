extends Control

@onready var base = $Base
@onready var palanca = $Palanca

var radio_maximo : float = 100.0
var tocando : bool = false
var vector_salida : Vector2 = Vector2.ZERO
var id_dedo : int = -1 # Guarda qué dedo activó el joystick

func _ready():
	# Centrar la palanca en el origen (0,0) considerando su propio radio (35)
	if palanca:
		palanca.position = Vector2.ZERO - Vector2(35, 35)

func _input(event):
	# 1. DETECTAR EL TOQUE INICIAL (Pulsar la pantalla)
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		# Convertimos la posición del toque al espacio local del joystick.
		var centro_joystick = global_position + Vector2(size.x * 0.5, size.y * 0.5)
		var distancia = event.position.distance_to(centro_joystick)
		
		if event.is_pressed():
			# Solo se activa si NO estamos tocando ya, y si el toque fue dentro del radio del joystick.
			if not tocando and distancia <= radio_maximo:
				tocando = true
				if event is InputEventScreenTouch:
					id_dedo = event.index
				else:
					id_dedo = -2
				var posicion_local = event.position - global_position
				_actualizar_joystick(posicion_local)
		else:
			# Detectar cuando se levanta el dedo/mouse correcto
			var es_el_mismo_dedo = (event is InputEventScreenTouch and event.index == id_dedo) or (event is InputEventMouseButton and id_dedo == -2)
			if es_el_mismo_dedo:
				tocando = false
				id_dedo = -1
				vector_salida = Vector2.ZERO
				palanca.position = Vector2.ZERO - Vector2(35, 35)

	# 2. DETECTAR EL ARRASTRE (Mover el dedo)
	if event is InputEventScreenDrag or (event is InputEventMouseMotion and tocando):
		var es_el_mismo_dedo = (event is InputEventScreenDrag and event.index == id_dedo) or (event is InputEventMouseMotion and id_dedo == -2)
		
		if tocando and es_el_mismo_dedo:
			var posicion_local = event.position - global_position
			_actualizar_joystick(posicion_local)

# Función interna para procesar el movimiento de la palanca y calcular el vector
func _actualizar_joystick(posicion_local: Vector2):
	# Limitar el movimiento al radio máximo esférico
	if posicion_local.length() > radio_maximo:
		posicion_local = posicion_local.normalized() * radio_maximo
		
	# Mover el nodo visual restando el desfase de su centro
	palanca.position = posicion_local - Vector2(35, 35)
	
	# Calcular el vector analógico final (-1 a 1) para el personaje
	vector_salida = posicion_local / radio_maximo

func _process(_delta):
	queue_redraw()

func _draw():
	# Dibujar la Base (Centro local 0,0)
	draw_circle(Vector2.ZERO, radio_maximo, Color(1.0, 1.0, 0.0, 0.149))
	draw_circle(Vector2.ZERO, radio_maximo, Color(1.0, 1.0, 0.0, 0.4), false, 1.5)

	# Dibujar la Palanca
	if palanca:
		var centro_palanca = palanca.position + Vector2(35, 35)
		draw_circle(centro_palanca, 35.0, Color(1.0, 1.0, 0.0, 0.259))
