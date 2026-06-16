extends TouchScreenButton

func _process(_delta):
	# Forzar actualización en cada fotograma
	queue_redraw()

func _draw():
	if shape is CircleShape2D:
		var radio = shape.radius
		
		# COLOR: Amarillo sutil semitransparente como se ve en tus capturas
		var color_relleno = Color(1, 1, 0.4, 0.25)
		var color_borde = Color(1, 1, 0.4, 0.5)
		
		# CORRECCIÓN DE ORIGEN:
		# Si la colisión en el inspector está centrada por defecto en el nodo,
		# el dibujo debe partir de Vector2.ZERO para acoplarse a la colisión celeste.
		var centro_corregido = Vector2.ZERO
		
		# Dibujar el área del botón de forma exacta
		draw_circle(centro_corregido, radio, color_relleno)
		draw_circle(centro_corregido, radio, color_borde, false, 2.0)
