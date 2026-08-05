extends Control

@onready var lbl_titulo = $PanelContenedor/VBox/LblTitulo
@onready var lbl_tiempo = $PanelContenedor/VBox/ContenedorDetalles/HBoxTiempo/LblTiempoValor
@onready var lbl_monedas_vivo = $PanelContenedor/VBox/ContenedorTarjetas/TarjetaVivo/VBox/LblMonedasVivo
@onready var lbl_monedas_fantasma = $PanelContenedor/VBox/ContenedorTarjetas/TarjetaFantasma/VBox/LblMonedasFantasma

@onready var lbl_rango = $PanelContenedor/VBox/ContenedorRango/LblRangoLetra
@onready var lbl_rango_sub = $PanelContenedor/VBox/ContenedorRango/LblRangoSub

@onready var btn_siguiente = $PanelContenedor/VBox/HBoxBotones/BtnSiguiente
@onready var btn_reintentar = $PanelContenedor/VBox/HBoxBotones/BtnReintentar
@onready var btn_salir = $PanelContenedor/VBox/HBoxBotones/BtnSalir

var lbl_estado_voto: Label = null
var voto_propio: String = ""
var voto_companero: String = ""
var tiempo_autocontinuar: float = 5.0
var contando_autocontinuar: bool = false
var companero_desconectado: bool = false

func _ready() -> void:
	# Crear etiqueta de estado para avisos de votación y desconexión
	var vbox = get_node_or_null("PanelContenedor/VBox")
	if vbox:
		lbl_estado_voto = Label.new()
		lbl_estado_voto.name = "LblEstadoVoto"
		lbl_estado_voto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lbl_estado_voto)
		var hbox_bot = get_node_or_null("PanelContenedor/VBox/HBoxBotones")
		if hbox_bot:
			vbox.move_child(lbl_estado_voto, hbox_bot.get_index())

	# Conectar botones
	if btn_siguiente:
		btn_siguiente.pressed.connect(_on_btn_siguiente_pressed)
	if btn_reintentar:
		btn_reintentar.pressed.connect(_on_btn_reintentar_pressed)
	if btn_salir:
		btn_salir.pressed.connect(_on_btn_salir_pressed)

	if multiplayer and multiplayer.has_multiplayer_peer():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		multiplayer.peer_connected.connect(_on_peer_connected)

	if is_instance_valid(RedManager):
		RedManager.conexion_perdida.connect(_on_conexion_perdida)

	# Cargar datos desde ScoreManager y aplicar estética de menú
	_cargar_datos_resultados()
	_aplicar_estilo_resultados(self)

func _process(delta: float) -> void:
	if contando_autocontinuar:
		tiempo_autocontinuar -= delta
		var segs_left = max(0, int(ceil(tiempo_autocontinuar)))
		if is_instance_valid(lbl_estado_voto):
			if voto_propio == "siguiente" and voto_companero == "siguiente":
				lbl_estado_voto.text = "¡Ambos listos! Avanzando al siguiente nivel..."
			elif voto_propio == "siguiente":
				lbl_estado_voto.text = "Esperando compañero... Continuarás en %ds" % segs_left
			elif voto_companero == "siguiente":
				lbl_estado_voto.text = "El otro jugador quiere continuar... Avanzando en %ds" % segs_left

		if tiempo_autocontinuar <= 0.0:
			contando_autocontinuar = false
			_ejecutar_siguiente_nivel()

func _aplicar_estilo_resultados(nodo: Node) -> void:
	if nodo is Label:
		nodo.add_theme_color_override(&"font_color", Color(1.0, 1.0, 1.0, 1.0))
		nodo.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
		nodo.add_theme_constant_override(&"outline_size", 8)
		nodo.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
		nodo.add_theme_constant_override(&"shadow_offset_x", 2)
		nodo.add_theme_constant_override(&"shadow_offset_y", 2)
		
	elif nodo is Button:
		nodo.add_theme_color_override(&"font_color", Color(1.0, 1.0, 1.0, 1.0))
		nodo.add_theme_color_override(&"font_pressed_color", Color(0.9, 0.9, 0.9, 1.0))
		nodo.add_theme_color_override(&"font_hover_color", Color(1.0, 0.95, 0.6, 1.0))
		nodo.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
		nodo.add_theme_constant_override(&"outline_size", 6)
		
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.12, 0.14, 0.22, 0.90)
		style_normal.border_width_left = 0
		style_normal.border_width_top = 0
		style_normal.border_width_right = 0
		style_normal.border_width_bottom = 0
		style_normal.set_corner_radius_all(10)
		
		var style_hover = style_normal.duplicate()
		style_hover.bg_color = Color(0.18, 0.22, 0.35, 0.95)
		style_hover.border_color = Color(0.4, 0.5, 0.7, 0.5)
		style_hover.border_width_left = 1
		style_hover.border_width_top = 1
		style_hover.border_width_right = 1
		style_hover.border_width_bottom = 1
		
		nodo.add_theme_stylebox_override(&"normal", style_normal)
		nodo.add_theme_stylebox_override(&"hover", style_hover)
		nodo.add_theme_stylebox_override(&"pressed", style_normal)
		nodo.add_theme_stylebox_override(&"focus", style_hover)

	elif nodo is Panel or nodo is PanelContainer:
		var style_panel = StyleBoxFlat.new()
		style_panel.bg_color = Color(0.08, 0.10, 0.16, 0.92)
		style_panel.border_width_left = 0
		style_panel.border_width_top = 0
		style_panel.border_width_right = 0
		style_panel.border_width_bottom = 0
		style_panel.set_corner_radius_all(16)
		style_panel.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
		style_panel.shadow_size = 16
		style_panel.shadow_offset = Vector2(0, 4)
		nodo.add_theme_stylebox_override(&"panel", style_panel)

	for hijo in nodo.get_children():
		_aplicar_estilo_resultados(hijo)


func _cargar_datos_resultados() -> void:
	if not is_instance_valid(ScoreManager):
		return
		
	var t_trans = ScoreManager.tiempo_transcurrido
	var t_obj = ScoreManager.tiempo_objetivo
	var s_vivo = ScoreManager.score_vivo
	var tot_vivo = ScoreManager.total_monedas_vivo
	var s_fant = ScoreManager.score_fantasma
	var tot_fant = ScoreManager.total_monedas_fantasma
	
	# Formatear tiempo mm:ss
	var mins: int = int(t_trans) / 60
	var segs: int = int(t_trans) % 60
	var mins_obj: int = int(t_obj) / 60
	var segs_obj: int = int(t_obj) % 60
	
	if lbl_tiempo:
		lbl_tiempo.text = "%02d:%02d  /  Objetivo: %02d:%02d" % [mins, segs, mins_obj, segs_obj]
		
	if lbl_monedas_vivo:
		lbl_monedas_vivo.text = "%d / %d Esencias" % [s_vivo, max(tot_vivo, s_vivo)]
		
	if lbl_monedas_fantasma:
		lbl_monedas_fantasma.text = "%d / %d Fragmentos" % [s_fant, max(tot_fant, s_fant)]
		
	# Calcular Rango
	var total_monedas_conseguidas = s_vivo + s_fant
	var total_monedas_posibles = max(1, tot_vivo + tot_fant)
	var porcentaje_monedas = float(total_monedas_conseguidas) / float(total_monedas_posibles)
	var a_tiempo = t_trans <= t_obj
	
	var rango = "C"
	var desc_rango = "COMPLETADO"
	var color_rango = Color(0.7, 0.7, 0.7)
	
	if porcentaje_monedas >= 1.0 and a_tiempo:
		rango = "S"
		desc_rango = "¡PERFECTO!"
		color_rango = Color(1.0, 0.85, 0.2) # Dorado resplandeciente
	elif porcentaje_monedas >= 0.8 or a_tiempo:
		rango = "A"
		desc_rango = "EXCELENTE"
		color_rango = Color(0.2, 0.9, 0.4) # Verde Esmeralda
	elif porcentaje_monedas >= 0.5:
		rango = "B"
		desc_rango = "BUEN TRABAJO"
		color_rango = Color(0.25, 0.75, 1.0) # Azul Neón
	else:
		rango = "C"
		desc_rango = "COMPLETADO"
		color_rango = Color(0.7, 0.75, 0.8) # Plateado
		
	if lbl_rango:
		lbl_rango.text = rango
		lbl_rango.modulate = color_rango
	if lbl_rango_sub:
		lbl_rango_sub.text = desc_rango
		lbl_rango_sub.modulate = color_rango

func _on_btn_siguiente_pressed() -> void:
	if companero_desconectado: return
	
	voto_propio = "siguiente"
	if is_instance_valid(btn_siguiente): btn_siguiente.disabled = true
	if is_instance_valid(btn_reintentar): btn_reintentar.disabled = true

	if _hay_otro_jugador():
		rpc("rpc_registrar_voto", multiplayer.get_unique_id(), "siguiente")
	else:
		_ejecutar_siguiente_nivel()

func _on_btn_reintentar_pressed() -> void:
	if companero_desconectado: return
	
	voto_propio = "reintentar"
	if is_instance_valid(btn_siguiente): btn_siguiente.disabled = true
	if is_instance_valid(btn_reintentar): btn_reintentar.disabled = true

	if _hay_otro_jugador():
		rpc("rpc_registrar_voto", multiplayer.get_unique_id(), "reintentar")
	else:
		_ejecutar_reintentar_nivel()

func _on_btn_volver_pressed() -> void:
	if multiplayer.has_multiplayer_peer():
		rpc("rpc_notificar_salida", multiplayer.get_unique_id())
	
	print("[PantallaResultados] Volviendo al menú principal.")
	var FirebaseMatchmaking = get_tree().root.get_node_or_null("FirebaseMatchmaking")
	if is_instance_valid(FirebaseMatchmaking) and not FirebaseMatchmaking.mi_sala_id.is_empty():
		FirebaseMatchmaking.eliminar_mi_sala()
		FirebaseMatchmaking.limpiar()
		
	if is_instance_valid(RedManager) and RedManager.has_method("desconectar"):
		RedManager.desconectar()
	get_tree().change_scene_to_file("res://scenes/ui/menu_inicio.tscn")

func _on_btn_salir_pressed() -> void:
	if _hay_otro_jugador():
		rpc("rpc_notificar_salida", multiplayer.get_unique_id())
	
	print("[PantallaResultados] Volviendo al menú principal.")
	var FirebaseMatchmaking = get_tree().root.get_node_or_null("FirebaseMatchmaking")
	if is_instance_valid(FirebaseMatchmaking) and not FirebaseMatchmaking.mi_sala_id.is_empty():
		FirebaseMatchmaking.eliminar_mi_sala()
		FirebaseMatchmaking.limpiar()
		
	if is_instance_valid(RedManager) and RedManager.has_method("desconectar"):
		RedManager.desconectar()
	get_tree().change_scene_to_file("res://scenes/ui/menu_inicio.tscn")

@rpc("any_peer", "call_local", "reliable")
func rpc_registrar_voto(sender_id: int, tipo_voto: String) -> void:
	var es_mio = (sender_id == multiplayer.get_unique_id())
	if es_mio:
		voto_propio = tipo_voto
	else:
		voto_companero = tipo_voto

	if tipo_voto == "siguiente":
		if not contando_autocontinuar:
			contando_autocontinuar = true
			tiempo_autocontinuar = 5.0
			
		if voto_propio == "siguiente" and voto_companero == "siguiente":
			contando_autocontinuar = false
			_ejecutar_siguiente_nivel()

	elif tipo_voto == "reintentar":
		if not es_mio and is_instance_valid(lbl_estado_voto):
			lbl_estado_voto.text = "¡Tu compañero ha votado por Reintentar!"
		elif es_mio and is_instance_valid(lbl_estado_voto):
			lbl_estado_voto.text = "Has votado por Reintentar. Esperando compañero..."

		if voto_propio == "reintentar" and voto_companero == "reintentar":
			_ejecutar_reintentar_nivel()

@rpc("any_peer", "call_remote", "reliable")
func rpc_notificar_salida(_sender_id: int) -> void:
	_marcar_companero_desconectado("Tu compañero se ha salido de la partida.")

func _on_peer_disconnected(_peer_id: int) -> void:
	_marcar_companero_desconectado("Tu compañero se ha desconectado.")

func _on_conexion_perdida() -> void:
	_marcar_companero_desconectado("Conexión perdida con el compañero.")

func _on_peer_connected(_peer_id: int) -> void:
	companero_desconectado = false
	contando_autocontinuar = false
	voto_propio = ""
	voto_companero = ""
	if is_instance_valid(btn_siguiente): btn_siguiente.disabled = false
	if is_instance_valid(btn_reintentar): btn_reintentar.disabled = false
	if is_instance_valid(lbl_estado_voto):
		lbl_estado_voto.text = "¡Tu compañero se ha reconectado!"

func _marcar_companero_desconectado(motivo: String) -> void:
	companero_desconectado = true
	contando_autocontinuar = false
	if is_instance_valid(btn_siguiente): btn_siguiente.disabled = true
	if is_instance_valid(btn_reintentar): btn_reintentar.disabled = true
	if is_instance_valid(lbl_estado_voto):
		lbl_estado_voto.text = "⚠️ " + motivo

func _hay_otro_jugador() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return false
	return multiplayer.get_peers().size() > 0

func _ejecutar_siguiente_nivel() -> void:
	print("[PantallaResultados] Ejecutando avance a Siguiente Nivel...")
	if is_instance_valid(RedManager) and RedManager.has_method("completar_nivel"):
		RedManager.completar_nivel()
	else:
		get_tree().change_scene_to_file("res://scenes/levels/nivel 2.tscn")

func _ejecutar_reintentar_nivel() -> void:
	print("[PantallaResultados] Ejecutando Reintento de Nivel...")
	if is_instance_valid(RedManager) and RedManager.has_method("reintentar_nivel_actual"):
		RedManager.reintentar_nivel_actual()
	else:
		get_tree().reload_current_scene()

