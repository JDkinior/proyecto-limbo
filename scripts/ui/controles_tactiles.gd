extends Control

@onready var joystick = $Joystick_Virtual

var arrastre_camara : Vector2 = Vector2.ZERO
var _personaje_conectado: Node

func _input(event):
	if event is InputEventScreenDrag:
		if joystick and joystick.tocando and event.index == joystick.id_dedo:
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
