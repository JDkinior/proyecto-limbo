@tool
extends EditorPlugin

## ==============================================================================
## PLUGIN: ESCULTOR DE ISLAS 3D (GODOT 4)
## Permite esculpir, elevar, hundir y aplanar terrazas transitables en tiempo real
## directamente en el visor 3D con Deshacer / Rehacer (Ctrl+Z) y gizmo interactivo.
## ==============================================================================

var _isla: IslaFlotante = null
var _esculpiendo: bool = false
var _ultima_pos_trazo: Vector3 = Vector3.INF
var _trazo_en_curso: bool = false
var _deformaciones_antes_del_trazo: Array[Dictionary] = []
var _modo_trazo_activo: int = 0
var _limitar_a_cero_activo: bool = false

# Barra de herramientas superior del visor 3D (ultra-compacta)
var _toolbar: HBoxContainer = null
var _btn_activar: Button = null
var _opt_modo: OptionButton = null
var _btn_ajustes: Button = null

# Menú flotante / Panel de configuración detallada del escultor
var _popup_ajustes: PopupPanel = null
var _opt_forma: OptionButton = null
var _spin_radio: SpinBox = null
var _slider_radio: HSlider = null
var _spin_fuerza: SpinBox = null
var _slider_fuerza: HSlider = null
var _btn_deshacer: Button = null
var _btn_limpiar: Button = null
var _chk_mesetas: CheckBox = null
var _opt_estilo_meseta: OptionButton = null

# Cursor visual 3D
var _gizmo_cursor: MeshInstance3D = null
var _forma_actual_gizmo: int = -1


func _enter_tree() -> void:
	_crear_toolbar()
	_crear_gizmo_cursor()


func _exit_tree() -> void:
	if _trazo_en_curso:
		_finalizar_trazo()
	_destruir_popup_ajustes()
	_destruir_toolbar()
	_destruir_gizmo_cursor()


func _handles(object: Object) -> bool:
	if object == null:
		return false
	if object is IslaFlotante:
		return true
	if object is Node:
		var scr = (object as Node).get_script()
		if scr != null and scr is Script and scr.resource_path.ends_with("isla_flotante.gd"):
			return true
	return false


func _edit(object: Object) -> void:
	if _trazo_en_curso:
		_finalizar_trazo()
	_isla = object as IslaFlotante
	_sincronizar_toolbar_con_isla()
	_actualizar_forma_gizmo()
	_actualizar_visibilidad()


func _make_visible(visible: bool) -> void:
	if is_instance_valid(_toolbar):
		_toolbar.visible = visible
	if not visible:
		if is_instance_valid(_popup_ajustes):
			_popup_ajustes.hide()
		if _trazo_en_curso:
			_finalizar_trazo()
		_isla = null
		_esculpiendo = false
		_ocultar_cursor()


# ==============================================================================
# ENTRADA DEL VISOR 3D (RAYCAST, CLIC Y ARRASTRE)
# ==============================================================================

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if not is_instance_valid(_isla) or not _isla.is_inside_tree():
		_ocultar_cursor()
		return AFTER_GUI_INPUT_PASS

	if not _isla.activar_pincel_terreno:
		_ocultar_cursor()
		return AFTER_GUI_INPUT_PASS

	var radio = _isla.radio_pincel_terreno
	var fuerza = _isla.fuerza_pincel_terreno
	var modo = int(_isla.modo_pincel_terreno)
	var forma = int(_isla.forma_pincel_terreno)

	_actualizar_forma_gizmo()

	# --- Atajos de Teclado: [ y ] para cambiar radio del pincel en tiempo real ---
	if event is InputEventKey:
		var ke = event as InputEventKey
		if ke.pressed and not ke.echo:
			if ke.keycode == KEY_BRACKETLEFT:
				var nuevo_r = maxf(0.5, radio - 0.5)
				_on_radio_changed(nuevo_r)
				return AFTER_GUI_INPUT_STOP
			elif ke.keycode == KEY_BRACKETRIGHT:
				var nuevo_r = radio + 0.5
				_on_radio_changed(nuevo_r)
				return AFTER_GUI_INPUT_STOP

	if event is InputEventMouseMotion:
		var mm = event as InputEventMouseMotion
		var hit = _hacer_raycast(camera, mm.position)
		if not hit.is_empty():
			var hit_pos: Vector3 = hit.position
			var hit_norm: Vector3 = hit.get("normal", Vector3.UP)
			_posicionar_cursor(hit_pos, hit_norm, radio)

			if _esculpiendo and _trazo_en_curso:
				var dist_min_paso = maxf(radio * 0.35, 0.4)
				if _ultima_pos_trazo.distance_to(hit_pos) >= dist_min_paso:
					_aplicar_estampa(hit_pos, radio, fuerza, _modo_trazo_activo, forma, _limitar_a_cero_activo)
					_ultima_pos_trazo = hit_pos
				return AFTER_GUI_INPUT_STOP
		else:
			_ocultar_cursor()

		return AFTER_GUI_INPUT_PASS

	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton

		# --- Atajos de Rueda del Ratón: Shift+Rueda (Radio) y Shift+Ctrl+Rueda (Fuerza) ---
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.shift_pressed:
			if mb.ctrl_pressed:
				_on_fuerza_changed(minf(10.0, fuerza + 0.2))
			else:
				_on_radio_changed(radio + 0.5)
			return AFTER_GUI_INPUT_STOP
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.shift_pressed:
			if mb.ctrl_pressed:
				_on_fuerza_changed(maxf(0.1, fuerza - 0.2))
			else:
				_on_radio_changed(maxf(0.5, radio - 0.5))
			return AFTER_GUI_INPUT_STOP

		var hit = _hacer_raycast(camera, mb.position)

		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_iniciar_trazo()
				_esculpiendo = true
				var modo_sel = modo
				var modo_final = modo_sel
				var limitar = false

				if modo_sel == 0: # ELEVAR
					if mb.shift_pressed or mb.ctrl_pressed:
						# Invertir elevación: REDUCIR pero limitado a la superficie original (sin extruir hacia adentro)
						modo_final = 4 # REDUCIR_A_BASE
						limitar = true
					else:
						modo_final = 0
						limitar = false
				elif modo_sel == 1: # HUNDIR (seleccionado explícitamente desde la barra de herramientas)
					if mb.shift_pressed or mb.ctrl_pressed:
						modo_final = 0 # Invertir a elevar
						limitar = false
					else:
						modo_final = 1 # Hundir: extruye hacia adentro del cuerpo rocoso
						limitar = false
				elif modo_sel == 4: # REDUCIR A BASE
					modo_final = 4
					limitar = true

				_modo_trazo_activo = modo_final
				_limitar_a_cero_activo = limitar

				if not hit.is_empty():
					_aplicar_estampa(hit.position, radio, fuerza, _modo_trazo_activo, forma, _limitar_a_cero_activo)
					_ultima_pos_trazo = hit.position
				return AFTER_GUI_INPUT_STOP
			else:
				if _trazo_en_curso:
					_finalizar_trazo()
				_esculpiendo = false
				_ultima_pos_trazo = Vector3.INF
				return AFTER_GUI_INPUT_STOP

		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			# Clic derecho:
			# Si está en modo ELEVAR o REDUCIR, reduce a la base original (sin hacer pozos ni extruir hacia dentro)
			# Si está explícitamente en modo HUNDIR, hunde hacia adentro libremente
			if not hit.is_empty():
				var modo_sel = modo
				var modo_r = 4 if modo_sel != 1 else 1
				var lim_r = (modo_sel != 1)
				_iniciar_trazo()
				_aplicar_estampa(hit.position, radio, fuerza, modo_r, forma, lim_r)
				_finalizar_trazo()
				return AFTER_GUI_INPUT_STOP

	return AFTER_GUI_INPUT_PASS


func _hacer_raycast(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var space_state = camera.get_world_3d().direct_space_state
	var from = camera.project_ray_origin(mouse_pos)
	var dir = camera.project_ray_normal(mouse_pos)
	var to = from + dir * 2000.0

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hit = space_state.intersect_ray(query)
	if not hit.is_empty():
		var col = hit.collider
		if col == _isla:
			return hit

	# Proyección al plano horizontal de la isla si no impactó directamente la malla física
	if is_instance_valid(_isla):
		var y_isla = _isla.global_position.y + _isla.altura_superficie
		var plano = Plane(Vector3.UP, y_isla)
		var hit_plane = plano.intersects_ray(from, dir)
		if hit_plane != null:
			var pos_local = _isla.to_local(hit_plane)
			var r_max = maxf(_isla.ancho, _isla.largo) * 0.70
			if Vector2(pos_local.x, pos_local.z).length() <= r_max:
				var h_calc = _isla.calcular_altura_en(Vector2(pos_local.x, pos_local.z))
				var pos_ajustada = _isla.to_global(Vector3(pos_local.x, h_calc, pos_local.z))
				return {"position": pos_ajustada, "normal": Vector3.UP}

	return {}


func _aplicar_estampa(pos_mundo: Vector3, radio: float, fuerza: float, modo: int, forma: int, limitar_a_cero: bool = false) -> void:
	if not is_instance_valid(_isla):
		return
	_isla.aplicar_trazo_esculpido(pos_mundo, radio, fuerza, modo, forma, limitar_a_cero)


# ==============================================================================
# DESHACER / REHACER (UNDO / REDO)
# ==============================================================================

func _iniciar_trazo() -> void:
	if not is_instance_valid(_isla):
		return
	_trazo_en_curso = true
	_isla._esculpiendo_activo = true
	_deformaciones_antes_del_trazo = _isla.deformaciones_escultura.duplicate(true)


func _finalizar_trazo() -> void:
	if not _trazo_en_curso or not is_instance_valid(_isla):
		_trazo_en_curso = false
		_esculpiendo = false
		_ultima_pos_trazo = Vector3.INF
		if is_instance_valid(_isla):
			_isla._esculpiendo_activo = false
		return

	_trazo_en_curso = false
	_esculpiendo = false
	_ultima_pos_trazo = Vector3.INF

	# Finalizar arrastre: reconstruye colisión sólida y sincroniza pasto completo de forma definitiva
	if is_instance_valid(_isla):
		_isla.finalizar_arrastre_escultura()

	var antes = _deformaciones_antes_del_trazo
	var despues = _isla.deformaciones_escultura.duplicate(true)

	if antes.size() == despues.size():
		return

	var ur = get_undo_redo()
	if ur != null:
		ur.create_action("Esculpir Isla 3D")
		ur.add_do_property(_isla, "deformaciones_escultura", despues)
		ur.add_do_method(_isla, "regenerar_completo_con_pasto")
		ur.add_undo_method(_isla, "regenerar_completo_con_pasto")
		ur.commit_action(false)


# ==============================================================================
# BARRA DE HERRAMIENTAS
# ==============================================================================

func _crear_toolbar() -> void:
	if _toolbar != null:
		return

	_toolbar = HBoxContainer.new()
	_toolbar.name = "ToolbarEscultorIslas"
	_toolbar.visible = false

	var sep1 = VSeparator.new()
	_toolbar.add_child(sep1)

	# 1. Botón activar pincel
	_btn_activar = Button.new()
	_btn_activar.text = "⛰️ Esculpir Isla"
	_btn_activar.toggle_mode = true
	_btn_activar.tooltip_text = "Activar / Desactivar herramienta de escultura 3D\n(Clic izq. = Esculpir, Shift+Clic = Reducir a base original, Hundir en barra = Extruir hacia dentro)"
	_btn_activar.toggled.connect(_on_activar_toggled)
	_toolbar.add_child(_btn_activar)

	# 2. Selector de Modo compacto
	_opt_modo = OptionButton.new()
	_opt_modo.custom_minimum_size = Vector2(100, 0)
	_opt_modo.fit_to_longest_item = false
	_opt_modo.tooltip_text = "Modo de esculpido"
	_opt_modo.add_item("⬆️ Elevar", 0)
	_opt_modo.add_item("⬇️ Hundir (Extruir)", 1)
	_opt_modo.add_item("🔲 Meseta / Terraza", 2)
	_opt_modo.add_item("〰️ Suavizar", 3)
	_opt_modo.add_item("📉 Reducir a Base", 4)
	_opt_modo.item_selected.connect(_on_modo_selected)
	_toolbar.add_child(_opt_modo)

	# 3. Botón indicador y desplegable de configuración detallada (estilo pincel de pasto)
	_btn_ajustes = Button.new()
	_btn_ajustes.text = "⚙️ R: 3.5m | F: 1.2m"
	_btn_ajustes.tooltip_text = "Configuración del Pincel (Radio, Fuerza, Forma, Deshacer, Limpiar)"
	_btn_ajustes.pressed.connect(_on_ajustes_pressed)
	_toolbar.add_child(_btn_ajustes)

	var sep2 = VSeparator.new()
	_toolbar.add_child(sep2)

	_crear_popup_ajustes()
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _toolbar)


func _destruir_toolbar() -> void:
	_destruir_popup_ajustes()
	if is_instance_valid(_toolbar):
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _toolbar)
		_toolbar.queue_free()
		_toolbar = null


func _crear_popup_ajustes() -> void:
	if _popup_ajustes != null:
		return

	_popup_ajustes = PopupPanel.new()
	_popup_ajustes.name = "PopupAjustesEscultorIslas"

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.custom_minimum_size = Vector2(280, 0)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# --- Encabezado ---
	var lbl_titulo = Label.new()
	lbl_titulo.text = "⚙️ Ajustes de Escultura de Isla"
	lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl_titulo)

	var sep_title = HSeparator.new()
	vbox.add_child(sep_title)

	# --- Forma del Relieve ---
	var hbox_forma = HBoxContainer.new()
	var lbl_forma = Label.new()
	lbl_forma.text = "Forma del Relieve:"
	lbl_forma.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_forma.add_child(lbl_forma)

	_opt_forma = OptionButton.new()
	_opt_forma.add_item("📐 Cónica Low-Poly", 0)
	_opt_forma.add_item("🟩 Meseta Plana", 1)
	_opt_forma.add_item("🔵 Cúpula Suave", 2)
	_opt_forma.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opt_forma.item_selected.connect(_on_forma_selected)
	hbox_forma.add_child(_opt_forma)
	vbox.add_child(hbox_forma)

	# --- Radio del Pincel ---
	var vbox_radio = VBoxContainer.new()
	var hbox_radio_lbl = HBoxContainer.new()
	var lbl_radio = Label.new()
	lbl_radio.text = "Radio del Pincel:"
	lbl_radio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_radio_lbl.add_child(lbl_radio)

	_spin_radio = SpinBox.new()
	_spin_radio.min_value = 0.5
	_spin_radio.max_value = 50.0
	_spin_radio.step = 0.1
	_spin_radio.value = 3.5
	_spin_radio.suffix = " m"
	_spin_radio.allow_greater = true
	_spin_radio.value_changed.connect(_on_radio_changed)
	hbox_radio_lbl.add_child(_spin_radio)
	vbox_radio.add_child(hbox_radio_lbl)

	_slider_radio = HSlider.new()
	_slider_radio.min_value = 0.5
	_slider_radio.max_value = 20.0
	_slider_radio.step = 0.1
	_slider_radio.value = 3.5
	_slider_radio.value_changed.connect(func(v): _on_radio_changed(v))
	vbox_radio.add_child(_slider_radio)
	vbox.add_child(vbox_radio)

	# --- Fuerza del Pincel ---
	var vbox_fuerza = VBoxContainer.new()
	var hbox_fuerza_lbl = HBoxContainer.new()
	var lbl_fuerza = Label.new()
	lbl_fuerza.text = "Fuerza del Pincel:"
	lbl_fuerza.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_fuerza_lbl.add_child(lbl_fuerza)

	_spin_fuerza = SpinBox.new()
	_spin_fuerza.min_value = 0.1
	_spin_fuerza.max_value = 20.0
	_spin_fuerza.step = 0.1
	_spin_fuerza.value = 1.2
	_spin_fuerza.suffix = " m"
	_spin_fuerza.allow_greater = true
	_spin_fuerza.value_changed.connect(_on_fuerza_changed)
	hbox_fuerza_lbl.add_child(_spin_fuerza)
	vbox_fuerza.add_child(hbox_fuerza_lbl)

	_slider_fuerza = HSlider.new()
	_slider_fuerza.min_value = 0.1
	_slider_fuerza.max_value = 5.0
	_slider_fuerza.step = 0.1
	_slider_fuerza.value = 1.2
	_slider_fuerza.value_changed.connect(func(v): _on_fuerza_changed(v))
	vbox_fuerza.add_child(_slider_fuerza)
	vbox.add_child(vbox_fuerza)

	var sep_mesetas = HSeparator.new()
	vbox.add_child(sep_mesetas)

	# --- Mesetas y Terrazas de Superficie ---
	var vbox_mesetas = VBoxContainer.new()
	vbox_mesetas.add_theme_constant_override("separation", 4)

	_chk_mesetas = CheckBox.new()
	_chk_mesetas.text = "🏔️ Mesetas y Terrazas de Superficie"
	_chk_mesetas.tooltip_text = "Activa o desactiva la división de la superficie en múltiples niveles y descansillos planos"
	_chk_mesetas.toggled.connect(_on_mesetas_toggled)
	vbox_mesetas.add_child(_chk_mesetas)

	var hbox_estilo_m = HBoxContainer.new()
	var lbl_est_m = Label.new()
	lbl_est_m.text = "Estilo Meseta:"
	lbl_est_m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_estilo_m.add_child(lbl_est_m)

	_opt_estilo_meseta = OptionButton.new()
	_opt_estilo_meseta.add_item("⭕ Concéntricas", 0)
	_opt_estilo_meseta.add_item("📐 Direccional", 1)
	_opt_estilo_meseta.add_item("🧩 Plataformas Orgánicas", 2)
	_opt_estilo_meseta.add_item("🏰 Meseta Central", 3)
	_opt_estilo_meseta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opt_estilo_meseta.item_selected.connect(_on_estilo_meseta_selected)
	hbox_estilo_m.add_child(_opt_estilo_meseta)
	vbox_mesetas.add_child(hbox_estilo_m)

	vbox.add_child(vbox_mesetas)

	var sep_act = HSeparator.new()
	vbox.add_child(sep_act)

	# --- Botones de Acción (Deshacer y Limpiar) ---
	var hbox_acciones = HBoxContainer.new()
	_btn_deshacer = Button.new()
	_btn_deshacer.text = "↩️ Deshacer"
	_btn_deshacer.tooltip_text = "Deshacer el último trazo de esculpido (o Ctrl+Z)"
	_btn_deshacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_deshacer.pressed.connect(_on_deshacer_pressed)
	hbox_acciones.add_child(_btn_deshacer)

	_btn_limpiar = Button.new()
	_btn_limpiar.text = "🗑️ Limpiar Todo"
	_btn_limpiar.tooltip_text = "Borrar todas las deformaciones manuales y restaurar la isla a su forma base"
	_btn_limpiar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_limpiar.pressed.connect(_on_limpiar_pressed)
	hbox_acciones.add_child(_btn_limpiar)
	vbox.add_child(hbox_acciones)

	var sep_help = HSeparator.new()
	vbox.add_child(sep_help)

	# --- Guía de atajos rápidos ---
	var lbl_atajos = Label.new()
	lbl_atajos.text = "💡 Atajos 3D:\n• Shift + Rueda o [ / ]: Radio del pincel\n• Ctrl + Shift + Rueda: Fuerza del pincel\n• Clic izq.: Esculpir relieve\n• Shift + Clic o Clic der.: Invertir (Hundir)"
	lbl_atajos.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.85))
	lbl_atajos.add_theme_font_size_override("font_size", 11)
	vbox.add_child(lbl_atajos)

	margin.add_child(vbox)
	_popup_ajustes.add_child(margin)

	EditorInterface.get_base_control().add_child(_popup_ajustes)


func _destruir_popup_ajustes() -> void:
	if is_instance_valid(_popup_ajustes):
		_popup_ajustes.queue_free()
		_popup_ajustes = null


func _on_ajustes_pressed() -> void:
	if not is_instance_valid(_popup_ajustes):
		_crear_popup_ajustes()
	if not is_instance_valid(_popup_ajustes):
		return
	if _popup_ajustes.visible:
		_popup_ajustes.hide()
		return
	var rect = _btn_ajustes.get_global_rect()
	var pos = Vector2i(int(rect.position.x), int(rect.position.y + rect.size.y + 4))
	_popup_ajustes.popup(Rect2i(pos, Vector2i(290, 320)))


func _actualizar_texto_boton_ajustes() -> void:
	if not is_instance_valid(_btn_ajustes):
		return
	var r = _spin_radio.value if is_instance_valid(_spin_radio) else 3.5
	var f = _spin_fuerza.value if is_instance_valid(_spin_fuerza) else 1.2
	_btn_ajustes.text = "⚙️ R: %.1fm | F: %.1fm" % [r, f]
	_btn_ajustes.tooltip_text = "Configuración del Pincel (Radio: %.1fm, Fuerza: %.1fm)\nHaz clic para desplegar los ajustes" % [r, f]


func _sincronizar_toolbar_con_isla() -> void:
	if not is_instance_valid(_isla):
		return
	if is_instance_valid(_btn_activar):
		_btn_activar.set_pressed_no_signal(_isla.activar_pincel_terreno)
	if is_instance_valid(_opt_modo):
		_opt_modo.select(int(_isla.modo_pincel_terreno))
	if is_instance_valid(_opt_forma):
		_opt_forma.select(int(_isla.forma_pincel_terreno))
	if is_instance_valid(_spin_radio):
		_spin_radio.set_value_no_signal(_isla.radio_pincel_terreno)
	if is_instance_valid(_slider_radio):
		_slider_radio.set_value_no_signal(_isla.radio_pincel_terreno)
	if is_instance_valid(_spin_fuerza):
		_spin_fuerza.set_value_no_signal(_isla.fuerza_pincel_terreno)
	if is_instance_valid(_slider_fuerza):
		_slider_fuerza.set_value_no_signal(_isla.fuerza_pincel_terreno)
	if is_instance_valid(_chk_mesetas) and "habilitar_mesetas_superficie" in _isla:
		_chk_mesetas.set_pressed_no_signal(_isla.habilitar_mesetas_superficie)
	if is_instance_valid(_opt_estilo_meseta) and "estilo_mesetas_superficie" in _isla:
		_opt_estilo_meseta.select(int(_isla.estilo_mesetas_superficie))
	_actualizar_texto_boton_ajustes()


func _on_activar_toggled(pressed: bool) -> void:
	if is_instance_valid(_isla):
		_isla.activar_pincel_terreno = pressed
	_actualizar_visibilidad()


func _on_modo_selected(index: int) -> void:
	if is_instance_valid(_isla):
		_isla.modo_pincel_terreno = index as IslaFlotante.ModoPincelTerreno


func _on_forma_selected(index: int) -> void:
	if is_instance_valid(_isla):
		_isla.forma_pincel_terreno = index as IslaFlotante.FormaPincelTerreno
	_actualizar_forma_gizmo()


func _on_mesetas_toggled(pressed: bool) -> void:
	if is_instance_valid(_isla) and "habilitar_mesetas_superficie" in _isla:
		_isla.habilitar_mesetas_superficie = pressed


func _on_estilo_meseta_selected(idx: int) -> void:
	if is_instance_valid(_isla) and "estilo_mesetas_superficie" in _isla:
		_isla.estilo_mesetas_superficie = idx as IslaFlotante.EstiloMeseta


func _on_radio_changed(val: float) -> void:
	if is_instance_valid(_slider_radio) and abs(_slider_radio.value - val) > 0.05:
		_slider_radio.set_value_no_signal(val)
	if is_instance_valid(_spin_radio) and abs(_spin_radio.value - val) > 0.01:
		_spin_radio.set_value_no_signal(val)
	if is_instance_valid(_isla):
		_isla.radio_pincel_terreno = val
	_actualizar_texto_boton_ajustes()


func _on_fuerza_changed(val: float) -> void:
	if is_instance_valid(_slider_fuerza) and abs(_slider_fuerza.value - val) > 0.05:
		_slider_fuerza.set_value_no_signal(val)
	if is_instance_valid(_spin_fuerza) and abs(_spin_fuerza.value - val) > 0.01:
		_spin_fuerza.set_value_no_signal(val)
	if is_instance_valid(_isla):
		_isla.fuerza_pincel_terreno = val
	_actualizar_texto_boton_ajustes()


func _on_deshacer_pressed() -> void:
	if is_instance_valid(_isla):
		_isla.deshacer_ultimo_trazo()


func _on_limpiar_pressed() -> void:
	if is_instance_valid(_isla):
		var antes = _isla.deformaciones_escultura.duplicate(true)
		var ur = get_undo_redo()
		if ur != null:
			ur.create_action("Limpiar Escultura de Isla")
			ur.add_do_property(_isla, "deformaciones_escultura", [])
			ur.add_undo_property(_isla, "deformaciones_escultura", antes)
			ur.add_do_method(_isla, "_solicitar_regeneracion")
			ur.add_undo_method(_isla, "_solicitar_regeneracion")
			ur.commit_action(true)
		else:
			_isla.limpiar_esculpido()


# ==============================================================================
# GIZMO VISUAL 3D
# ==============================================================================

func _crear_gizmo_cursor() -> void:
	if _gizmo_cursor != null:
		return

	_gizmo_cursor = MeshInstance3D.new()
	_gizmo_cursor.name = "_GizmoEscultorIslas"

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.95, 0.58, 0.18, 0.45) # Tono ámbar/dorado de relieve
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true

	_gizmo_cursor.material_override = mat
	_gizmo_cursor.visible = false
	_gizmo_cursor.top_level = true
	_forma_actual_gizmo = -1
	_actualizar_forma_gizmo()


func _actualizar_forma_gizmo() -> void:
	if not is_instance_valid(_gizmo_cursor):
		return

	var forma: int = 0
	if is_instance_valid(_isla):
		forma = int(_isla.forma_pincel_terreno)

	if _forma_actual_gizmo == forma and _gizmo_cursor.mesh != null:
		return

	_forma_actual_gizmo = forma

	match forma:
		1: # Meseta Plana (Cilindro disco de bordes nítidos)
			var cyl_flat = CylinderMesh.new()
			cyl_flat.top_radius = 1.0
			cyl_flat.bottom_radius = 1.0
			cyl_flat.height = 0.04
			cyl_flat.radial_segments = 24
			_gizmo_cursor.mesh = cyl_flat
		2: # Cúpula Suave
			var sphere = SphereMesh.new()
			sphere.radius = 1.0
			sphere.height = 0.6
			sphere.radial_segments = 24
			sphere.rings = 12
			_gizmo_cursor.mesh = sphere
		_: # Cónica Low-Poly
			var cone = CylinderMesh.new()
			cone.top_radius = 0.1
			cone.bottom_radius = 1.0
			cone.height = 0.8
			cone.radial_segments = 16
			_gizmo_cursor.mesh = cone


func _destruir_gizmo_cursor() -> void:
	if is_instance_valid(_gizmo_cursor):
		if _gizmo_cursor.get_parent() != null:
			_gizmo_cursor.get_parent().remove_child(_gizmo_cursor)
		_gizmo_cursor.queue_free()
		_gizmo_cursor = null


func _asegurar_gizmo_en_arbol() -> void:
	if not is_instance_valid(_gizmo_cursor):
		_crear_gizmo_cursor()

	if is_instance_valid(_isla) and _isla.is_inside_tree():
		if _gizmo_cursor.get_parent() != _isla:
			if _gizmo_cursor.get_parent() != null:
				_gizmo_cursor.get_parent().remove_child(_gizmo_cursor)
			_isla.add_child(_gizmo_cursor)


func _posicionar_cursor(pos: Vector3, normal: Vector3, radio: float) -> void:
	_asegurar_gizmo_en_arbol()
	if not is_instance_valid(_gizmo_cursor):
		return

	_gizmo_cursor.visible = true

	var rot_basis = Basis.IDENTITY
	if abs(normal.dot(Vector3.UP)) < 0.999:
		var eje = Vector3.UP.cross(normal).normalized()
		var angulo = Vector3.UP.angle_to(normal)
		if eje.length_squared() > 0.001:
			rot_basis = Basis(eje, angulo)

	_gizmo_cursor.global_basis = rot_basis.scaled(Vector3(radio, 1.0, radio))
	_gizmo_cursor.global_position = pos + normal * 0.05


func _ocultar_cursor() -> void:
	if is_instance_valid(_gizmo_cursor):
		_gizmo_cursor.visible = false


func _actualizar_visibilidad() -> void:
	var mostrar = is_instance_valid(_isla) and _isla.activar_pincel_terreno
	if not mostrar:
		_ocultar_cursor()
