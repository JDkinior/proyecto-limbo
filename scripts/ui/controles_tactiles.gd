extends Control

@onready var joystick = $Joystick_Virtual
@onready var icono_moneda = $HUD_Puntuacion/Contenedor_Puntuacion/Icono_Moneda
@onready var texto_puntuacion = $HUD_Puntuacion/Contenedor_Puntuacion/Texto_Puntuacion

var arrastre_camara : Vector2 = Vector2.ZERO
var _personaje_conectado: Node
var joystick_dedo : int = -1

func _ready():
	add_to_group("ui_tactil")
	_inicializar_joystick()
	if has_node("HUD_Puntuacion"):
		$HUD_Puntuacion.visible = false

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

	# Desconectar señales de score anteriores para evitar duplicados
	var callback_vivo = Callable(self, "_on_score_vivo_changed")
	var callback_fantasma = Callable(self, "_on_score_fantasma_changed")
	if is_instance_valid(ScoreManager):
		if ScoreManager.score_vivo_changed.is_connected(callback_vivo):
			ScoreManager.score_vivo_changed.disconnect(callback_vivo)
		if ScoreManager.score_fantasma_changed.is_connected(callback_fantasma):
			ScoreManager.score_fantasma_changed.disconnect(callback_fantasma)

	_personaje_conectado = personaje

	# Garantizar que las referencias del HUD estén resueltas si se llama antes del _ready() de esta escena
	if not is_instance_valid(icono_moneda):
		icono_moneda = get_node_or_null("HUD_Puntuacion/Contenedor_Puntuacion/Icono_Moneda")
	if not is_instance_valid(texto_puntuacion):
		texto_puntuacion = get_node_or_null("HUD_Puntuacion/Contenedor_Puntuacion/Texto_Puntuacion")

	if is_instance_valid(icono_moneda) and is_instance_valid(texto_puntuacion):
		var hud_puntuacion = get_node_or_null("HUD_Puntuacion")
		if hud_puntuacion:
			hud_puntuacion.visible = true
			
		if personaje is Fantasma:
			aplicar_estilo_fantasma()
			# Cargar textura de esmeralda y modular a verde espectral
			var tex_emerald = load("res://assets/Modelos/Provicional/RuinsGLB/Accessories/AncientCoinEmerald_AncientCoinEmerald_1_Color.png")
			icono_moneda.texture = tex_emerald
			icono_moneda.self_modulate = Color(0.4, 1.0, 0.4) # Tinte verde
			
			# Conectar señal de puntuación del fantasma
			if is_instance_valid(ScoreManager):
				ScoreManager.score_fantasma_changed.connect(callback_fantasma)
				_on_score_fantasma_changed(ScoreManager.score_fantasma)
				
			if not personaje.aura_estado_actualizado.is_connected(callback):
				personaje.aura_estado_actualizado.connect(callback)
		else:
			aplicar_estilo_jugador()
			# Cargar textura de rubí y modular a rojo vida
			var tex_ruby = load("res://assets/Modelos/Provicional/RuinsGLB/Accessories/AncientCoinRuby_AncientGoldCoinRuby_1_Color.png")
			icono_moneda.texture = tex_ruby
			icono_moneda.self_modulate = Color(1.0, 0.4, 0.4) # Tinte rojo
			
			# Conectar señal de puntuación del jugador vivo
			if is_instance_valid(ScoreManager):
				ScoreManager.score_vivo_changed.connect(callback_vivo)
				_on_score_vivo_changed(ScoreManager.score_vivo)

func _on_score_vivo_changed(new_score: int) -> void:
	if is_instance_valid(texto_puntuacion):
		texto_puntuacion.text = "Esencias de Vida: %d" % new_score

func _on_score_fantasma_changed(new_score: int) -> void:
	if is_instance_valid(texto_puntuacion):
		texto_puntuacion.text = "Fragmentos Espectrales: %d" % new_score

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

# --- Gestores de HUD: Menú de Pausa, Ajustes y Salida Segura ---

func _on_boton_pausa_pressed() -> void:
	var panel_p = get_node_or_null("Panel_Pausa")
	if panel_p:
		panel_p.visible = !panel_p.visible
		# Ocultar panel de opciones por seguridad al alternar pausa
		var panel_o = get_node_or_null("Panel_Opciones")
		if panel_o:
			panel_o.visible = false
		print("[ControlesTactiles] Menú de Pausa alternado a: ", panel_p.visible)

func _on_boton_continuar_pressed() -> void:
	var panel_p = get_node_or_null("Panel_Pausa")
	if panel_p:
		panel_p.visible = false

func _on_boton_opciones_pressed() -> void:
	var panel_p = get_node_or_null("Panel_Pausa")
	var panel_o = get_node_or_null("Panel_Opciones")
	if panel_o:
		panel_o.visible = true
	if panel_p:
		panel_p.visible = false
	print("[ControlesTactiles] Entrando a Ajustes (Ocultando Pausa)")

func _on_boton_cerrar_opciones_pressed() -> void:
	var panel_p = get_node_or_null("Panel_Pausa")
	var panel_o = get_node_or_null("Panel_Opciones")
	if panel_o:
		panel_o.visible = false
	if panel_p:
		panel_p.visible = true
	print("[ControlesTactiles] Volviendo a Menú de Pausa (Ocultando Ajustes)")

func _on_boton_salir_pressed() -> void:
	print("[ControlesTactiles] Iniciando desconexión segura del entorno P2P...")
	
	# 1. Liberar datos, detener broadcasters de LAN, cerrar puertos UPNP y limpiar referencias
	if is_instance_valid(RedManager):
		if RedManager.has_method("desconectar"):
			RedManager.desconectar()
			
	# 2. Desasociar explícitamente el peer de red de Godot por seguridad
	if multiplayer:
		multiplayer.multiplayer_peer = null
		
	# 3. Volver de forma limpia al menú de inicio y liberar recursos huérfanos
	get_tree().change_scene_to_file("res://scenes/ui/menu_inicio.tscn")

