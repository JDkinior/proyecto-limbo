extends TouchScreenButton

var color_glow: Color = Color(1.0, 0.8, 0.2, 1.0)
var _ultimo_color: Color = Color(-1, -1, -1)
var es_fantasma: bool = false
var habilidad_activa: bool = false
var progreso_cooldown: float = 1.0 # 1.0 = Lista para usar, 0.0 = Recién usada
var _pulso_tiempo: float = 0.0

func _ready():
	_actualizar_color()
	queue_redraw()

func _process(delta: float):
	_actualizar_color()
	
	if habilidad_activa:
		_pulso_tiempo += delta * 6.0
		queue_redraw()
	elif progreso_cooldown < 1.0:
		queue_redraw()
	elif color_glow != _ultimo_color:
		_ultimo_color = color_glow
		queue_redraw()

func _actualizar_color():
	var parent_ui = get_tree().get_nodes_in_group("ui_tactil")
	if parent_ui.size() > 0 and parent_ui[0].has_method("obtener_color_ui"):
		color_glow = parent_ui[0].obtener_color_ui()
		# Si color_glow es azul/cyan espectral, estamos en modo Fantasma
		es_fantasma = (color_glow.b > 0.6 and color_glow.r < 0.6)

func actualizar_estado_habilidad(activo: bool, progreso: float):
	habilidad_activa = activo
	progreso_cooldown = clampf(progreso, 0.0, 1.0)
	queue_redraw()

func _draw():
	if not (shape is CircleShape2D):
		return
		
	var radio: float = shape.radius
	var centro = Vector2.ZERO
	var presionado = is_pressed()
	var es_boton_interactuar = (action == "interactuar" or name.to_lower().contains("interactuar"))
	
	# Determinar colores base según estado de habilidad y personaje
	var color_relleno: Color
	var color_borde: Color
	var color_icono: Color
	
	if es_boton_interactuar and es_fantasma:
		if habilidad_activa:
			# Estado ACTIVO: Brillo pulsante cyan intenso
			var factor_pulso = 0.5 + 0.5 * sin(_pulso_tiempo)
			color_relleno = Color(0.2, 0.85, 1.0, lerpf(0.35, 0.65, factor_pulso))
			color_borde = Color(0.6, 0.95, 1.0, 1.0)
			color_icono = Color(1.0, 1.0, 1.0, 1.0)
			
			# Anillo de onda exterior expandiéndose
			var radio_onda = radio * (1.08 + factor_pulso * 0.14)
			draw_arc(centro, radio_onda, 0, TAU, 32, Color(0.3, 0.85, 1.0, 0.5 * (1.0 - factor_pulso)), 2.5)
		elif progreso_cooldown < 1.0:
			# Estado COOLDOWN: Fondo oscuro atenuado con arco de progreso
			color_relleno = Color(0.08, 0.12, 0.20, 0.30)
			color_borde = Color(0.25, 0.45, 0.70, 0.35)
			color_icono = Color(0.5, 0.75, 0.95, 0.45)
		else:
			# Estado LISTO: Cyan místico brillante escarchado
			var alfa_bg = 0.45 if presionado else 0.24
			color_relleno = Color(0.18, 0.55, 0.75, alfa_bg)
			color_borde = Color(0.40, 0.88, 1.0, 0.95 if presionado else 0.80)
			color_icono = Color(0.95, 0.98, 1.0, 1.0)
	else:
		# Botón normal (Salto o Interactuar)
		if es_fantasma:
			var alfa_bg = 0.45 if presionado else 0.24
			color_relleno = Color(0.18, 0.55, 0.75, alfa_bg)
			color_borde = Color(0.40, 0.88, 1.0, 0.95 if presionado else 0.80)
			color_icono = Color(0.95, 0.98, 1.0, 1.0)
		else:
			var alfa_bg = 0.42 if presionado else 0.20
			color_relleno = Color(color_glow.r, color_glow.g, color_glow.b, alfa_bg)
			color_borde = Color(color_glow.r, color_glow.g, color_glow.b, 0.90 if presionado else 0.70)
			color_icono = Color(1.0, 1.0, 1.0, 0.95 if presionado else 0.85)

	# 1. Dibujar disco de fondo
	draw_circle(centro, radio, color_relleno)
	
	# 2. Dibujar borde principal
	var grosor_borde = 3.5 if presionado else 2.5
	draw_arc(centro, radio - (grosor_borde * 0.5), 0, TAU, 48, color_borde, grosor_borde)
	
	# 3. Dibujar arco de recarga (Cooldown Sweep)
	if es_boton_interactuar and es_fantasma and not habilidad_activa and progreso_cooldown < 1.0:
		var radio_cd = radio - 2.0
		var angulo_fin = -PI * 0.5 + (progreso_cooldown * TAU)
		draw_arc(centro, radio_cd, -PI * 0.5, angulo_fin, 48, Color(0.35, 0.85, 1.0, 0.95), 4.0)
		# Punto indicador en la punta del arco
		var pos_punta = centro + Vector2(cos(angulo_fin), sin(angulo_fin)) * radio_cd
		draw_circle(pos_punta, 3.0, Color(1.0, 1.0, 1.0, 0.9))

	# 4. Dibujar Iconografía
	if action == "saltar" or name.to_lower().contains("saltar"):
		_dibujar_icono_salto(centro, radio, color_icono)
	elif action == "cambiar_personaje" or name.to_lower().contains("cambiar"):
		_dibujar_icono_cambiar_personaje(centro, radio, color_icono)
	elif es_boton_interactuar:
		if es_fantasma:
			_dibujar_icono_aura(centro, radio, color_icono)
		else:
			_dibujar_icono_interactuar(centro, radio, color_icono)

func _dibujar_icono_cambiar_personaje(centro: Vector2, radio: float, color: Color):
	# 1. Flechas orbitales circulares de intercambio (Swap Orbit)
	var radio_orbita = radio * 0.44
	var grosor_arco = 2.5
	
	# Arco superior (de izquierda a derecha)
	draw_arc(centro, radio_orbita, -PI * 0.90, -PI * 0.10, 24, color, grosor_arco)
	# Punta de flecha superior derecha
	var p_sup = centro + Vector2(cos(-PI * 0.10), sin(-PI * 0.10)) * radio_orbita
	var flecha_sup = PackedVector2Array([
		p_sup + Vector2(radio * 0.05, -radio * 0.12),
		p_sup + Vector2(-radio * 0.12, -radio * 0.02),
		p_sup + Vector2(-radio * 0.02, radio * 0.10)
	])
	draw_colored_polygon(flecha_sup, color)
	
	# Arco inferior (de derecha a izquierda)
	draw_arc(centro, radio_orbita, PI * 0.10, PI * 0.90, 24, color, grosor_arco)
	# Punta de flecha inferior izquierda
	var p_inf = centro + Vector2(cos(PI * 0.90), sin(PI * 0.90)) * radio_orbita
	var flecha_inf = PackedVector2Array([
		p_inf + Vector2(-radio * 0.05, radio * 0.12),
		p_inf + Vector2(radio * 0.12, radio * 0.02),
		p_inf + Vector2(radio * 0.02, -radio * 0.10)
	])
	draw_colored_polygon(flecha_inf, color)
	
	# 2. Silueta central
	if es_fantasma:
		# Fantasma activo -> muestra icono del Vivo (persona con cabeza y hombros)
		var r_cabeza = radio * 0.12
		draw_circle(centro + Vector2(0, -radio * 0.09), r_cabeza, color)
		var pts_torso = PackedVector2Array([
			centro + Vector2(-radio * 0.18, radio * 0.22),
			centro + Vector2(-radio * 0.12, radio * 0.05),
			centro + Vector2(radio * 0.12, radio * 0.05),
			centro + Vector2(radio * 0.18, radio * 0.22)
		])
		draw_colored_polygon(pts_torso, color)
	else:
		# Vivo activo -> muestra icono del Fantasma (espíritu flotante)
		var r_fant = radio * 0.13
		draw_circle(centro + Vector2(0, -radio * 0.08), r_fant, color)
		var pts_fant = PackedVector2Array([
			centro + Vector2(-r_fant, -radio * 0.08),
			centro + Vector2(-radio * 0.14, radio * 0.14),
			centro + Vector2(-radio * 0.06, radio * 0.22),
			centro + Vector2(0, radio * 0.16),
			centro + Vector2(radio * 0.06, radio * 0.22),
			centro + Vector2(radio * 0.14, radio * 0.14),
			centro + Vector2(r_fant, -radio * 0.08)
		])
		draw_colored_polygon(pts_fant, color)

func _dibujar_icono_salto(centro: Vector2, radio: float, color: Color):
	# Flecha estilizada de salto hacia arriba
	var alto_punta = radio * 0.42
	var ancho_punta = radio * 0.36
	var pts_triangulo = PackedVector2Array([
		centro + Vector2(0, -alto_punta),
		centro + Vector2(-ancho_punta, 0.0),
		centro + Vector2(ancho_punta, 0.0)
	])
	draw_colored_polygon(pts_triangulo, color)
	
	# Barra horizontal estilizada en la base
	var y_base = centro.y + radio * 0.22
	draw_line(Vector2(centro.x - ancho_punta * 0.75, y_base), Vector2(centro.x + ancho_punta * 0.75, y_base), color, 3.0)

func _dibujar_icono_aura(centro: Vector2, radio: float, color: Color):
	# Estrella espectral de 4 puntas (Aura del Fantasma)
	var radio_largo = radio * 0.44
	var radio_corto = radio * 0.14
	var pts_estrella = PackedVector2Array([
		centro + Vector2(0, -radio_largo),
		centro + Vector2(radio_corto, -radio_corto),
		centro + Vector2(radio_largo, 0),
		centro + Vector2(radio_corto, radio_corto),
		centro + Vector2(0, radio_largo),
		centro + Vector2(-radio_corto, radio_corto),
		centro + Vector2(-radio_largo, 0),
		centro + Vector2(-radio_corto, -radio_corto)
	])
	draw_colored_polygon(pts_estrella, color)
	
	# Núcleo brillante central
	draw_circle(centro, radio * 0.09, Color(1.0, 1.0, 1.0, color.a))

func _dibujar_icono_interactuar(centro: Vector2, radio: float, color: Color):
	# Anillo y rombo de interacción física
	draw_arc(centro, radio * 0.32, 0, TAU, 32, color, 2.5)
	var r_rombo = radio * 0.16
	var pts_rombo = PackedVector2Array([
		centro + Vector2(0, -r_rombo),
		centro + Vector2(r_rombo, 0),
		centro + Vector2(0, r_rombo),
		centro + Vector2(-r_rombo, 0)
	])
	draw_colored_polygon(pts_rombo, color)

