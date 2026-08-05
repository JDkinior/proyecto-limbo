extends TouchScreenButton

var color_glow: Color = Color(1.0, 0.8, 0.2, 1.0)
var _ultimo_color: Color = Color(-1, -1, -1) # Force initial redraw

func _ready():
	_actualizar_color()
	queue_redraw()

func _process(_delta):
	# Solo redibujar si el color cambió
	_actualizar_color()
	if color_glow != _ultimo_color:
		_ultimo_color = color_glow
		queue_redraw()

func _actualizar_color():
	var parent_ui = get_tree().get_nodes_in_group("ui_tactil")
	if parent_ui.size() > 0 and parent_ui[0].has_method("obtener_color_ui"):
		color_glow = parent_ui[0].obtener_color_ui()

func _draw():
	if shape is CircleShape2D:
		var radio = shape.radius
		
		var color_relleno = Color(color_glow.r, color_glow.g, color_glow.b, 0.2)
		var color_borde = Color(color_glow.r, color_glow.g, color_glow.b, 0.65)
		
		var centro_corregido = Vector2.ZERO
		draw_circle(centro_corregido, radio, color_relleno)
		draw_circle(centro_corregido, radio, color_borde, false, 3.0)
