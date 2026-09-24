extends Area3D
class_name ManivelaContinua

# Manivela Continua / Torno — Mecanismo físico que requiere mantener presionado el botón.
# El Jugador Vivo se acerca y mantiene presionado 'interactuar' para girar la manivela.
# Mientras la gira, el progreso avanza de 0.0 a 1.0, moviendo un objeto asignado (puente, compuerta, etc.).
# Si suelta el botón antes de completarse, la manivela se desenrolla por gravedad.

signal signal_activado
signal signal_desactivado
signal signal_progreso_cambiado(progreso: float)

@export_group("Configuración de Operación")
@export var velocidad_giro: float = 0.35            # Progreso ganado por segundo
@export var velocidad_retorno: float = 0.25         # Progreso perdido por segundo al soltar
@export var retorno_automatico: bool = true         # Si regresa sola al soltar
@export var bloquear_al_completar: bool = false      # Queda fijada en 1.0 si llega al final

@export_group("Control Directo de Objeto (Opcional)")
@export var nodo_controlado: Node3D = null
@export var desplazamiento_controlado: Vector3 = Vector3(0, 4, 0)

@export_group("Éxtasis / Congelamiento por Aura")
@export var permite_estasis_aura: bool = true
@export var duracion_estasis: float = 5.0

@onready var rueda_giratoria: Node3D = get_node_or_null("Rueda")
@onready var luz_indicador: OmniLight3D = get_node_or_null("LuzIndicador")

var progreso_actual: float = 0.0
var _jugador_cerca: Node = null
var _esta_operando: bool = false
var _pos_inicial_controlado: Vector3 = Vector3.ZERO
var _ha_completado: bool = false
var _tiempo_sync_rpc: float = 0.0

var esta_congelada: bool = false
var tiempo_estasis_restante: float = 0.0
var _fantasma_cache: Node = null

const COLOR_INACTIVO := Color(0.85, 0.4, 0.1, 1.0)
const COLOR_ACTIVO := Color(0.2, 0.95, 0.4, 1.0)
const COLOR_ESTASIS := Color(0.2, 0.85, 1.0, 1.0)

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 1  # Detecta solo al Jugador Vivo (Capa 2)
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	add_to_group("mecanismos_interactivos")
	
	if is_instance_valid(nodo_controlado):
		_pos_inicial_controlado = nodo_controlado.position

func _obtener_fantasma() -> Node:
	if not is_instance_valid(_fantasma_cache):
		var fantasmas = get_tree().get_nodes_in_group("fantasmas")
		_fantasma_cache = fantasmas[0] if fantasmas.size() > 0 else null
	return _fantasma_cache

func _on_body_entered(body: Node) -> void:
	if body is Jugador:
		_jugador_cerca = body
		if body.has_method("registrar_mecanismo_cercano"):
			body.registrar_mecanismo_cercano(self)

func _on_body_exited(body: Node) -> void:
	if body == _jugador_cerca:
		if _jugador_cerca.has_method("desregistrar_mecanismo_cercano"):
			_jugador_cerca.desregistrar_mecanismo_cercano(self)
		_jugador_cerca = null
		_esta_operando = false

func intentar_interactuar(_personaje: Node) -> bool:
	# Las manivelas se operan de forma continua manteniendo el botón presionado
	return true

func congelar_estasis(duracion: float = 5.0) -> void:
	esta_congelada = true
	tiempo_estasis_restante = duracion
	_actualizar_luz()
	print("[ManivelaContinua] '%s' ¡CONGELADA EN ÉXTASIS por el Aura del Fantasma!" % name)

func descongelar_estasis() -> void:
	esta_congelada = false
	tiempo_estasis_restante = 0.0
	_actualizar_luz()
	print("[ManivelaContinua] '%s' Descongelada." % name)

func _comprobar_estasis_aura() -> void:
	if not permite_estasis_aura or esta_congelada or progreso_actual <= 0.05:
		return
		
	var f = _obtener_fantasma()
	if not is_instance_valid(f):
		return
		
	var aura = f.get_node_or_null("HabilidadAura") as HabilidadAura
	if not aura or not aura.esta_activa():
		return
		
	var dist = Vector2(global_position.x - f.global_position.x, global_position.z - f.global_position.z).length()
	var radio_aura = aura.obtener_radio()
	
	if dist <= (radio_aura + 2.0):
		congelar_estasis(duracion_estasis)

func _physics_process(delta: float) -> void:
	_comprobar_estasis_aura()
	
	if esta_congelada:
		tiempo_estasis_restante -= delta
		if tiempo_estasis_restante <= 0.0:
			descongelar_estasis()
			
	var es_offline_o_mio = not multiplayer.has_multiplayer_peer() or (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	if not es_offline_o_mio and is_instance_valid(_jugador_cerca) and not _jugador_cerca.is_multiplayer_authority():
		return
		
	if _ha_completado and bloquear_al_completar:
		return
		
	var progreso_previo = progreso_actual
	var accion_presionada = is_instance_valid(_jugador_cerca) and Input.is_action_pressed("interactuar")
	
	if accion_presionada:
		_esta_operando = true
		progreso_actual = minf(progreso_actual + velocidad_giro * delta, 1.0)
		if is_instance_valid(rueda_giratoria):
			rueda_giratoria.rotate_z(deg_to_rad(180.0 * delta * 2.0))
	else:
		_esta_operando = false
		# Si NO está congelada por éxtasis, retrocede por gravedad
		if not esta_congelada and retorno_automatico and progreso_actual > 0.0:
			progreso_actual = maxf(progreso_actual - velocidad_retorno * delta, 0.0)
			if is_instance_valid(rueda_giratoria):
				rueda_giratoria.rotate_z(deg_to_rad(-180.0 * delta * 1.5))
				
	# Aplicar movimiento al nodo controlado si está asignado
	_actualizar_objeto_controlado()
	
	# Verificar eventos de umbral
	if progreso_actual != progreso_previo:
		signal_progreso_cambiado.emit(progreso_actual)
		_actualizar_luz()
		
		# Sincronización en red periódica
		_tiempo_sync_rpc += delta
		if _tiempo_sync_rpc > 0.08:
			_tiempo_sync_rpc = 0.0
			if multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
				rpc("rpc_sincronizar_progreso", progreso_actual, _esta_operando)
				
		if progreso_actual >= 1.0 and not _ha_completado:
			_ha_completado = true
			signal_activado.emit()
			print("[ManivelaContinua] '%s' ¡Mecanismo COMPLETADO al 100%%!" % name)
		elif progreso_actual <= 0.0 and _ha_completado:
			_ha_completado = false
			signal_desactivado.emit()
			print("[ManivelaContinua] '%s' Mecanismo retornado a 0%%." % name)

func _actualizar_objeto_controlado() -> void:
	if is_instance_valid(nodo_controlado):
		nodo_controlado.position = _pos_inicial_controlado + (desplazamiento_controlado * progreso_actual)

func _actualizar_luz() -> void:
	if is_instance_valid(luz_indicador):
		if esta_congelada:
			luz_indicador.light_color = COLOR_ESTASIS
			luz_indicador.light_energy = 2.4
		else:
			luz_indicador.light_color = COLOR_INACTIVO.lerp(COLOR_ACTIVO, progreso_actual)
			luz_indicador.light_energy = lerpf(0.6, 2.2, progreso_actual)

@rpc("any_peer", "call_remote", "unreliable")
func rpc_sincronizar_progreso(nuevo_progreso: float, operando: bool) -> void:
	progreso_actual = nuevo_progreso
	_esta_operando = operando
	_actualizar_objeto_controlado()
	_actualizar_luz()
	signal_progreso_cambiado.emit(progreso_actual)
