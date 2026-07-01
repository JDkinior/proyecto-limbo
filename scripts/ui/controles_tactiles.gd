extends Control

@onready var joystick = $Joystick_Virtual

var arrastre_camara : Vector2 = Vector2.ZERO
var _personaje_conectado: Node
var joystick_dedo : int = -1

func _ready():
	add_to_group("ui_tactil")
	_inicializar_joystick()

func _inicializar_joystick():
	if not joystick: return
	
	joystick.joystick_mode = 1 # JOYSTICK_DYNAMIC
	joystick.joystick_size = 200.0
	joystick.tip_size = 70.0
	joystick.deadzone_ratio = 0.0
	joystick.clampzone_ratio = 1.0
	joystick.initial_offset_ratio = Vector2(0.3, 0.5)
	joystick.visibility_mode = 0 # VISIBILITY_ALWAYS
	
	joystick.action_left = &"mover_izquierda"
	joystick.action_right = &"mover_derecha"
	joystick.action_up = &"mover_adelante"
	joystick.action_down = &"mover_atras"
	
	var style_base = StyleBoxFlat.new()
	style_base.bg_color = Color(1.0, 1.0, 0.0, 0.149)
	style_base.border_color = Color(1.0, 1.0, 0.0, 0.4)
	style_base.border_width_left = 2
	style_base.border_width_top = 2
	style_base.border_width_right = 2
	style_base.border_width_bottom = 2
	style_base.set_corner_radius_all(100)
	
	var style_tip = StyleBoxFlat.new()
	style_tip.bg_color = Color(1.0, 1.0, 0.0, 0.259)
	style_tip.set_corner_radius_all(35)
	
	joystick.add_theme_stylebox_override(&"normal_joystick", style_base)
	joystick.add_theme_stylebox_override(&"pressed_joystick", style_base)
	joystick.add_theme_stylebox_override(&"normal_tip", style_tip)
	joystick.add_theme_stylebox_override(&"pressed_tip", style_tip)
	
	joystick.gui_input.connect(_on_joystick_gui_input)

func _on_joystick_gui_input(event: InputEvent):
	if event is InputEventScreenTouch:
		if event.is_pressed():
			joystick_dedo = event.index
		else:
			joystick_dedo = -1
	elif event is InputEventScreenDrag:
		joystick_dedo = event.index

func _input(event):
	if event is InputEventScreenDrag:
		if joystick_dedo != -1 and event.index == joystick_dedo:
			return

		var mitad_pantalla = get_viewport_rect().size.x / 2
		if event.position.x > mitad_pantalla:
			arrastre_camara += event.relative

func consumir_arrastre() -> Vector2:
	var temp = arrastre_camara
	arrastre_camara = Vector2.ZERO
	return temp

func configurar_personaje_local(personaje: Node):
	var callback = Callable(self, "actualizar_boton_aura")
	if is_instance_valid(_personaje_conectado) and _personaje_conectado.has_signal("aura_estado_actualizado"):
		if _personaje_conectado.aura_estado_actualizado.is_connected(callback):
			_personaje_conectado.aura_estado_actualizado.disconnect(callback)

	_personaje_conectado = personaje

	if personaje is Fantasma:
		aplicar_estilo_fantasma()
		if not personaje.aura_estado_actualizado.is_connected(callback):
			personaje.aura_estado_actualizado.connect(callback)
	else:
		aplicar_estilo_jugador()

func aplicar_estilo_jugador():
	modulate = Color(1, 1, 1)
	_limpiar_shader_recursivo(self)

func aplicar_estilo_fantasma():
	var shader = Shader.new()
	shader.code = "shader_type canvas_item; uniform vec4 color_solido : source_color; void fragment() { vec4 tex = texture(TEXTURE, UV); COLOR = vec4(color_solido.rgb, tex.a * color_solido.a); }"
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("color_solido", Color(0.101, 0.442, 1.5, 0.306))

	modulate = Color(1, 1, 1)
	_aplicar_shader_recursivo(self, mat)

	var btn_interact = get_node_or_null("Area_Camara/Zona_Botones_Accion/Boton_Interactuar")
	if btn_interact and btn_interact.material:
		btn_interact.material = btn_interact.material.duplicate()

func actualizar_boton_aura(activo: bool, progreso: float):
	var btn = get_node_or_null("Area_Camara/Zona_Botones_Accion/Boton_Interactuar")
	if btn and btn.material:
		if not activo and progreso < 1.0 and progreso > 0.0:
			btn.material.set_shader_parameter("color_solido", Color(0.2, 0.2, 0.2, 0.3))
		else:
			btn.material.set_shader_parameter("color_solido", Color(0.101, 0.442, 1.5, 0.306))

func _aplicar_shader_recursivo(nodo: Node, material_shader: ShaderMaterial):
	if nodo is CanvasItem:
		nodo.material = material_shader

	for hijo in nodo.get_children():
		_aplicar_shader_recursivo(hijo, material_shader)

func _limpiar_shader_recursivo(nodo: Node):
	if nodo is CanvasItem:
		nodo.material = null

	for hijo in nodo.get_children():
		_limpiar_shader_recursivo(hijo)
