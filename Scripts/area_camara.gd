extends Control

var arrastre_camara : Vector2 = Vector2.ZERO

func _gui_input(event):
	# _gui_input solo se activa si el toque ocurre DENTRO de los límites de este nodo
	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		# Acumulamos el movimiento del dedo
		arrastre_camara += event.relative

func consumir_arrastre() -> Vector2:
	var temp = arrastre_camara
	arrastre_camara = Vector2.ZERO
	return temp
