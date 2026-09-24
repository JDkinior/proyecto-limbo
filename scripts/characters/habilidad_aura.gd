extends Node3D
class_name HabilidadAura

signal estado_cambiado(activo: bool, progreso_cooldown: float)
signal radio_actualizado(radio: float)

@export var radio_maximo : float = 10.0
@export var velocidad_encogimiento : float = 2.5
@export var tiempo_recarga : float = 4.0
## Altura local Y del efecto visual del aura respecto al fantasma.
## Elevado a -0.08 para mantenerse sobre el pasto estilizado sin quedar sumergido.
@export var altura_aura : float = -0.08
## Duración en segundos de la animación de expansión/aparición inicial.
@export var duracion_aparicion : float = 0.32

var activa : bool = false
var radio_actual : float = 0.0
var cooldown_actual : float = 0.0

var _en_fase_aparicion : bool = false
var _tiempo_aparicion : float = 0.0
var _mat_aura : Material = null
var _mat_halo : ShaderMaterial = null

@onready var mesh_visual: MeshInstance3D = get_parent().get_node_or_null("Aura")
@onready var particulas_aura: CPUParticles3D = _resolver_particulas()
@onready var luz_aura: OmniLight3D = _resolver_luz()

func _resolver_particulas() -> CPUParticles3D:
	if not is_inside_tree() or not get_parent():
		return null
	var p = get_parent().get_node_or_null("ParticulasAuraMistica") as CPUParticles3D
	if not p:
		p = get_parent().get_node_or_null("Aura/ParticulasAuraMistica") as CPUParticles3D
	return p

func _resolver_luz() -> OmniLight3D:
	if not is_inside_tree() or not get_parent():
		return null
	var l = get_parent().get_node_or_null("LuzAura") as OmniLight3D
	if not l:
		l = get_parent().get_node_or_null("Aura/LuzAura") as OmniLight3D
	return l

func _ready():
	_cachear_materiales()

	if mesh_visual:
		mesh_visual.visible = false
		mesh_visual.scale = Vector3(0.001, 0.001, 0.001)
		mesh_visual.position.y = altura_aura
		_configurar_capas_visuales(mesh_visual, 1)

	if is_instance_valid(particulas_aura):
		particulas_aura.emitting = false

	if is_instance_valid(luz_aura):
		luz_aura.visible = false
		luz_aura.light_energy = 0.0

	_aplicar_opacidad(0.0)

func _cachear_materiales():
	if is_instance_valid(mesh_visual):
		var mat = mesh_visual.get_active_material(0)
		if not mat and mesh_visual.mesh:
			mat = mesh_visual.mesh.surface_get_material(0)
		if mat:
			_mat_aura = mat.duplicate()
			mesh_visual.set_surface_override_material(0, _mat_aura)

		var halo = mesh_visual.get_node_or_null("HaloSuave") as MeshInstance3D
		if halo:
			var mat_h = halo.get_active_material(0)
			if not mat_h and halo.mesh:
				mat_h = halo.mesh.surface_get_material(0)
			if mat_h:
				_mat_halo = mat_h.duplicate() as ShaderMaterial
				halo.set_surface_override_material(0, _mat_halo)

func _configurar_capas_visuales(nodo: Node, mascara_capas: int) -> void:
	if nodo is VisualInstance3D:
		nodo.layers = mascara_capas
	for hijo in nodo.get_children():
		_configurar_capas_visuales(hijo, mascara_capas)

func _aplicar_opacidad(factor: float):
	factor = clampf(factor, 0.0, 1.0)
	if is_instance_valid(_mat_aura):
		if _mat_aura is ShaderMaterial:
			(_mat_aura as ShaderMaterial).set_shader_parameter("opacidad", factor)
		elif _mat_aura is StandardMaterial3D:
			(_mat_aura as StandardMaterial3D).albedo_color.a = 0.45 * factor
	if is_instance_valid(_mat_halo):
		_mat_halo.set_shader_parameter("opacidad", factor)
	if is_instance_valid(luz_aura):
		luz_aura.light_energy = 1.15 * factor

func _process(delta: float):
	var es_offline = (multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	var es_local = es_offline or (is_instance_valid(RedManager) and RedManager.es_un_jugador)
	var es_autoridad = es_local or is_multiplayer_authority()

	# El cooldown se gestiona en la autoridad
	if es_autoridad and cooldown_actual > 0.0:
		cooldown_actual = maxf(cooldown_actual - delta, 0.0)
		var progreso = 1.0 - (cooldown_actual / tiempo_recarga)
		estado_cambiado.emit(false, progreso)
		if cooldown_actual == 0.0:
			estado_cambiado.emit(false, 1.0) # 1.0 = Habilidad totalmente lista

	if not activa:
		return

	# 1. FASE DE APARICIÓN (Expansión suave y dinámica estilo onda de choque)
	if _en_fase_aparicion:
		_tiempo_aparicion += delta
		var t = clampf(_tiempo_aparicion / maxf(duracion_aparicion, 0.05), 0.0, 1.0)
		# Curva Ease-Out Cubic para expansión potente y orgánica
		var factor_expansion = 1.0 - pow(1.0 - t, 3.0)
		radio_actual = radio_maximo * factor_expansion

		# Fade-in rápido de opacidad durante el primer 40% de la expansión
		var opacidad = clampf(t / 0.40, 0.0, 1.0)
		_aplicar_opacidad(opacidad)
		_actualizar_visual(opacidad)
		radio_actualizado.emit(radio_actual)

		if t >= 1.0:
			_en_fase_aparicion = false
			radio_actual = radio_maximo
			_aplicar_opacidad(1.0)
			_actualizar_visual(1.0)
		return

	# 2. FASE DE ENCOGIMIENTO Y DISOLUCIÓN
	radio_actual = maxf(radio_actual - velocidad_encogimiento * delta, 0.0)

	# Zona de disolución final (últimos 1.2 metros):
	# Se desvanece la opacidad con smoothstep y se aplana la altura para evitar que
	# el cilindro forme un poste vertical residual o cause artefactos visuales.
	var opacidad_actual = 1.0
	if radio_actual < 1.2:
		var factor_fade = clampf(radio_actual / 1.2, 0.0, 1.0)
		opacidad_actual = factor_fade * factor_fade * (3.0 - 2.0 * factor_fade)

	_aplicar_opacidad(opacidad_actual)
	_actualizar_visual(opacidad_actual)
	radio_actualizado.emit(radio_actual)

	# Desactivación limpia sin saltos ni cortes abruptos
	if radio_actual <= 0.0:
		if es_autoridad:
			desactivar()

func intentar_activar():
	if activa or cooldown_actual > 0.0:
		return

	if multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) and not (is_instance_valid(RedManager) and RedManager.es_un_jugador):
		rpc("rpc_activar_aura")
	else:
		rpc_activar_aura()

@rpc("call_local", "reliable")
func rpc_activar_aura():
	activa = true
	_en_fase_aparicion = true
	_tiempo_aparicion = 0.0
	radio_actual = 0.001

	if is_instance_valid(mesh_visual):
		mesh_visual.visible = true
		mesh_visual.position.y = altura_aura
		mesh_visual.scale = Vector3(0.001, 0.001, 0.001)

	_aplicar_opacidad(0.0)

	if is_instance_valid(particulas_aura):
		particulas_aura.visible = true
		particulas_aura.emitting = true
		particulas_aura.restart()

	if is_instance_valid(luz_aura):
		luz_aura.visible = true
		luz_aura.light_energy = 0.0

	estado_cambiado.emit(true, 0.0)
	radio_actualizado.emit(0.0)

	if is_instance_valid(VibrationManager):
		var p = get_parent()
		if not is_instance_valid(p) or not p.has_method("es_activo") or p.es_activo():
			VibrationManager.vibrar_aura_activar()

func desactivar():
	if multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) and not (is_instance_valid(RedManager) and RedManager.es_un_jugador):
		rpc("rpc_desactivar_aura")
	else:
		rpc_desactivar_aura()

@rpc("call_local", "reliable")
func rpc_desactivar_aura():
	activa = false
	_en_fase_aparicion = false
	radio_actual = 0.0
	cooldown_actual = tiempo_recarga

	if is_instance_valid(VibrationManager):
		var p = get_parent()
		if not is_instance_valid(p) or not p.has_method("es_activo") or p.es_activo():
			VibrationManager.vibrar_aura_desactivar()

	_aplicar_opacidad(0.0)

	if is_instance_valid(mesh_visual):
		mesh_visual.visible = false
		mesh_visual.scale = Vector3(0.001, 0.001, 0.001)

	if is_instance_valid(particulas_aura):
		particulas_aura.emitting = false

	if is_instance_valid(luz_aura):
		luz_aura.visible = false
		luz_aura.light_energy = 0.0

	estado_cambiado.emit(false, 0.0)
	radio_actualizado.emit(0.0)

func _actualizar_visual(_opacidad: float = 1.0):
	if not is_instance_valid(mesh_visual):
		return

	var r = maxf(radio_actual, 0.001)
	# Cuando el radio es pequeño (< 0.8m), aplanamos progresivamente la altura Y
	# para que el cilindro nunca forme un poste/aguja vertical en el centro.
	var escala_y = clampf(r / 0.8, 0.001, 1.0)
	mesh_visual.scale = Vector3(r, escala_y, r)
	if _mat_aura is ShaderMaterial:
		(_mat_aura as ShaderMaterial).set_shader_parameter("radio_actual", r)
	if _mat_halo is ShaderMaterial:
		(_mat_halo as ShaderMaterial).set_shader_parameter("radio_actual", r)

func esta_activa() -> bool:
	return activa

func obtener_radio() -> float:
	return radio_actual
