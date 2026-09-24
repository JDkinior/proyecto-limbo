extends TouchScreenButton

const TEX_SALTO_VIVO = preload("res://assets/ui/controles/salto_vivo.png")
const TEX_SALTO_FANTASMA = preload("res://assets/ui/controles/salto_fantasma.png")
const TEX_ACCION_VIVO = preload("res://assets/ui/controles/accion_vivo.png")
const TEX_ACCION_FANTASMA = preload("res://assets/ui/controles/accion_fantasma.png")
const TEX_CAMBIO_VIVO = preload("res://assets/ui/controles/boton_cambio_vivo.png")
const TEX_CAMBIO_FANTASMA = preload("res://assets/ui/controles/boton_cambio_fantasma.png")

const ASPECT_RATIO_BOTON: float = 443.0 / 411.0
const FACTOR_ESCALA_SOMBRA: float = 411.0 / 336.0 # Compensa el padding de sombras agrandadas para mantener el tamaño original del botón

const COLOR_VIVO_NORMAL: Color = Color(1.0, 0.97, 0.90, 0.98)
const COLOR_VIVO_PRESSED: Color = Color(0.88, 0.84, 0.76, 0.92)
const COLOR_VIVO_DISABLED: Color = Color(0.65, 0.60, 0.50, 0.42) # Opaco / atenuado cuando no hay objetivo

const COLOR_FANTASMA_NORMAL: Color = Color(0.70, 0.90, 1.0, 0.96)
const COLOR_FANTASMA_PRESSED: Color = Color(0.50, 0.80, 1.0, 0.92)

const COLOR_AURA_READY: Color = Color(0.70, 0.90, 1.0, 0.96)
const COLOR_AURA_ACTIVE: Color = Color(1.15, 1.35, 1.60, 1.0)
const COLOR_AURA_COOLDOWN_MOD: Color = Color(0.40, 0.60, 0.85, 0.55)
const COLOR_AURA_ARC: Color = Color(0.639, 0.831, 0.933, 0.95) # #a3d4ee cyan suave de carga
const COLOR_ONDA_HABILIDAD: Color = Color(0.984, 0.988, 0.992, 1.0) # #fbfcfd blanco espectral puro

var color_glow: Color = Color(1.0, 0.96, 0.82, 1.0)
var _color_render: Color = Color(1.0, 0.97, 0.90, 0.98)

var _ultimo_presionado: bool = false
var es_fantasma: bool = false
var habilidad_activa: bool = false
var progreso_cooldown: float = 1.0
var puede_interactuar_vivo: bool = false
var _pulso_tiempo: float = 0.0

var _pulso_visual_activo: bool = false
var _pulso_visual_tween: Tween = null

# Variables para transición suave entre iconos/texturas
var _tex_actual: Texture2D = null
var _tex_anterior: Texture2D = null
var _factor_fade_icono: float = 1.0
var _fade_tween: Tween = null

func _ready():
	_actualizar_color(1.0)
	_tex_actual = _obtener_textura_objetivo()
	_color_render = _obtener_color_objetivo()
	queue_redraw()

func animar_pulsacion() -> void:
	_pulso_visual_activo = true
	queue_redraw()
	if _pulso_visual_tween and _pulso_visual_tween.is_running():
		_pulso_visual_tween.kill()
	var escala_orig = scale
	_pulso_visual_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pulso_visual_tween.tween_property(self, "scale", escala_orig * 0.90, 0.06)
	_pulso_visual_tween.tween_property(self, "scale", escala_orig, 0.10)
	_pulso_visual_tween.tween_callback(func():
		_pulso_visual_activo = false
		scale = escala_orig
		queue_redraw()
	)

func _process(delta: float):
	_actualizar_color(delta)
	
	var presionado = is_pressed() or _pulso_visual_activo
	if presionado != _ultimo_presionado:
		_ultimo_presionado = presionado
		queue_redraw()
	
	if habilidad_activa:
		_pulso_tiempo += delta * 6.0
		queue_redraw()
	elif progreso_cooldown < 1.0 or _factor_fade_icono < 1.0:
		queue_redraw()

func _obtener_textura_objetivo() -> Texture2D:
	var es_boton_salto = (action == "saltar" or name.to_lower().contains("saltar"))
	var es_boton_interactuar = (action == "interactuar" or name.to_lower().contains("interactuar"))
	if es_boton_salto:
		return TEX_SALTO_FANTASMA if es_fantasma else TEX_SALTO_VIVO
	elif es_boton_interactuar:
		return TEX_ACCION_FANTASMA if es_fantasma else TEX_ACCION_VIVO
	else:
		return TEX_CAMBIO_VIVO if es_fantasma else TEX_CAMBIO_FANTASMA

func _obtener_color_objetivo() -> Color:
	var presionado = is_pressed() or _pulso_visual_activo
	var es_boton_interactuar = (action == "interactuar" or name.to_lower().contains("interactuar"))
	if es_fantasma and es_boton_interactuar:
		if habilidad_activa:
			return COLOR_AURA_ACTIVE
		elif progreso_cooldown < 1.0:
			return COLOR_AURA_COOLDOWN_MOD
		else:
			return COLOR_AURA_READY if not presionado else COLOR_FANTASMA_PRESSED
	elif not es_fantasma and es_boton_interactuar:
		if not puede_interactuar_vivo:
			return COLOR_VIVO_DISABLED
		else:
			return COLOR_VIVO_NORMAL if not presionado else COLOR_VIVO_PRESSED
	else:
		if es_fantasma:
			return COLOR_FANTASMA_NORMAL if not presionado else COLOR_FANTASMA_PRESSED
		else:
			return COLOR_VIVO_NORMAL if not presionado else COLOR_VIVO_PRESSED

func actualizar_estado_habilidad_vivo(puede_interactuar: bool):
	puede_interactuar_vivo = puede_interactuar
	queue_redraw()

func _iniciar_transicion_textura(nueva_tex: Texture2D):
	if _tex_actual == null:
		_tex_actual = nueva_tex
		_factor_fade_icono = 1.0
		return
		
	if _tex_actual != nueva_tex:
		_tex_anterior = _tex_actual
		_tex_actual = nueva_tex
		_factor_fade_icono = 0.0
		
		if _fade_tween and _fade_tween.is_running():
			_fade_tween.kill()
		_fade_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_fade_tween.tween_property(self, "_factor_fade_icono", 1.0, 0.45)

func _actualizar_color(delta: float):
	var parent_ui = get_tree().get_nodes_in_group("ui_tactil")
	var nuevo_es_fantasma = es_fantasma
	if parent_ui.size() > 0:
		if parent_ui[0].has_method("es_fantasma_actual"):
			nuevo_es_fantasma = parent_ui[0].es_fantasma_actual()
		elif parent_ui[0].has_method("obtener_color_ui"):
			color_glow = parent_ui[0].obtener_color_ui()
			nuevo_es_fantasma = (color_glow.b > color_glow.r)
		
	if nuevo_es_fantasma != es_fantasma:
		es_fantasma = nuevo_es_fantasma
		var nueva_tex = _obtener_textura_objetivo()
		_iniciar_transicion_textura(nueva_tex)
		
	var target = _obtener_color_objetivo()
	if _color_render != target:
		# Interpolación suave y continua del color sincronizada con el vuelo de la cámara
		var velocidad_lerp = 5.5 * delta
		_color_render = _color_render.lerp(target, clampf(velocidad_lerp, 0.0, 1.0))
		queue_redraw()

func actualizar_estado_habilidad(activo: bool, progreso: float):
	habilidad_activa = activo
	progreso_cooldown = clampf(progreso, 0.0, 1.0)
	queue_redraw()

func _draw():
	if not (shape is CircleShape2D):
		return
		
	var radio: float = shape.radius
	var centro = Vector2.ZERO
	var presionado = is_pressed() or _pulso_visual_activo
	var es_boton_salto = (action == "saltar" or name.to_lower().contains("saltar"))
	var es_boton_interactuar = (action == "interactuar" or name.to_lower().contains("interactuar"))
	var es_boton_cambiar = (action == "cambiar_personaje" or name.to_lower().contains("cambiar"))
	
	if es_boton_salto or es_boton_interactuar or es_boton_cambiar:
		if _tex_actual == null:
			_tex_actual = _obtener_textura_objetivo()
			
		var escala_click: float = 0.92 if presionado else 1.0
		var ancho: float = radio * 2.0 * FACTOR_ESCALA_SOMBRA * escala_click
		var alto: float = ancho * ASPECT_RATIO_BOTON
		var rect: Rect2 = Rect2(-ancho * 0.5, -alto * 0.5, ancho, alto)
		
		# Dibujar transición suave cruzada de textura si el personaje acaba de cambiar
		if _factor_fade_icono < 1.0 and _tex_anterior != null:
			var c_ant = _color_render
			c_ant.a *= (1.0 - _factor_fade_icono)
			draw_texture_rect(_tex_anterior, rect, false, c_ant)
			
			var c_act = _color_render
			c_act.a *= _factor_fade_icono
			draw_texture_rect(_tex_actual, rect, false, c_act)
		else:
			draw_texture_rect(_tex_actual, rect, false, _color_render)
		
		# Efectos especiales de aura fantasma
		if es_boton_interactuar and es_fantasma:
			# Compensar el desplazamiento de la sombra inferior para centrar el círculo exactamente en el cuerpo del hexágono
			var centro_aura: Vector2 = centro + Vector2(0.0, -2.0)
			var radio_aura: float = radio * 1.19 # ~47.6px, rodea con precisión y simetría las 6 puntas del hexágono
			
			if habilidad_activa:
				# 1. Anillo brillante en el perímetro exterior del hexágono
				var pulso_anillo = 0.75 + 0.25 * sin(_pulso_tiempo * 2.0)
				draw_arc(centro_aura, radio_aura, 0, TAU, 48, Color(COLOR_ONDA_HABILIDAD.r, COLOR_ONDA_HABILIDAD.g, COLOR_ONDA_HABILIDAD.b, 0.75 * pulso_anillo), 2.5)
				
				# 2. Primera onda de choque expansiva (#fbfcfd)
				var factor_onda1 = fmod(_pulso_tiempo * 0.35, 1.0)
				var radio_onda1 = radio_aura + factor_onda1 * (radio * 0.45)
				var alfa_onda1 = (1.0 - factor_onda1) * 0.85
				draw_arc(centro_aura, radio_onda1, 0, TAU, 48, Color(COLOR_ONDA_HABILIDAD.r, COLOR_ONDA_HABILIDAD.g, COLOR_ONDA_HABILIDAD.b, alfa_onda1), 2.5)
				
				# 3. Segunda onda de choque concéntrica desfasada (#fbfcfd)
				var factor_onda2 = fmod(_pulso_tiempo * 0.35 + 0.5, 1.0)
				var radio_onda2 = radio_aura + factor_onda2 * (radio * 0.45)
				var alfa_onda2 = (1.0 - factor_onda2) * 0.85
				draw_arc(centro_aura, radio_onda2, 0, TAU, 48, Color(COLOR_ONDA_HABILIDAD.r, COLOR_ONDA_HABILIDAD.g, COLOR_ONDA_HABILIDAD.b, alfa_onda2), 2.5)
				
			elif progreso_cooldown < 1.0:
				# Pista de fondo sutil del cooldown (#a3d4ee translúcido)
				draw_arc(centro_aura, radio_aura, 0, TAU, 48, Color(COLOR_AURA_ARC.r, COLOR_AURA_ARC.g, COLOR_AURA_ARC.b, 0.25), 2.5)
				
				# Arco de recarga (Cooldown Sweep en #a3d4ee)
				var angulo_fin = -PI * 0.5 + (progreso_cooldown * TAU)
				draw_arc(centro_aura, radio_aura, -PI * 0.5, angulo_fin, 48, COLOR_AURA_ARC, 4.0)
				
				# Punto indicador brillante en la punta del arco (#fbfcfd)
				var pos_punta = centro_aura + Vector2(cos(angulo_fin), sin(angulo_fin)) * radio_aura
				draw_circle(pos_punta, 4.0, Color(0.984, 0.988, 0.992, 1.0))
