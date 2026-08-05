extends StaticBody3D
class_name ElementoInteractivoBase

# Clase Base Modular para Puertas Interactiva y Plataformas Espirituales.
# Soporta múltiples disparadores (Array) y combinación lógica (AND/OR).
# Sincroniza el estado mediante RPC en red P2P.

enum ModoActivacion {
	MODO_AURA,
	MODO_PRESION
}

enum CondicionCombinacion {
	CONDICION_O, # OR: Se activa si CUALQUIERA de los disparadores se activa.
	CONDICION_Y  # AND: Se activa solo si TODOS los disparadores están activos.
}

@export_group("Configuración de Activación")
@export var condicion_combinacion: CondicionCombinacion = CondicionCombinacion.CONDICION_O
@export var disparadores_objetivo: Array[Node3D] = []

# Retenido por compatibilidad hacia atrás en el Inspector
@export var disparador_objetivo: Node3D

# Diccionario para rastrear el estado individual de cada disparador
# { Node3D: bool }
var _estados_disparadores: Dictionary = {}

var esta_activo: bool = false

func _ready() -> void:
	var nodos_disparadores: Array[Node3D] = []
	
	# Resolver disparador_objetivo (soporta tanto Node3D como NodePath de la escena)
	var disp_unido = _resolver_nodo(disparador_objetivo)
	if disp_unido and not disp_unido in nodos_disparadores:
		nodos_disparadores.append(disp_unido)
		
	# Resolver disparadores_objetivo (Array)
	for item in disparadores_objetivo:
		var n = _resolver_nodo(item)
		if n and not n in nodos_disparadores:
			nodos_disparadores.append(n)
		
	if nodos_disparadores.is_empty():
		push_warning("[%s] ADVERTENCIA: No se asignaron disparadores válidos." % name)
		return
		
	# Conectarse dinámicamente a cada disparador y registrar su estado
	for disp in nodos_disparadores:
		_estados_disparadores[disp] = false
		var conectado = false
		
		var callable_activado = Callable(self, "_on_disparador_estado_cambiado").bind(disp, true)
		var callable_desactivado = Callable(self, "_on_disparador_estado_cambiado").bind(disp, false)
		
		if disp.has_signal("signal_activado"):
			if not disp.is_connected("signal_activado", callable_activado):
				disp.connect("signal_activado", callable_activado)
			conectado = true
		else:
			push_error("[%s] ERROR: El disparador '%s' no tiene la señal 'signal_activado'." % [name, disp.name])
			
		if disp.has_signal("signal_desactivado"):
			if not disp.is_connected("signal_desactivado", callable_desactivado):
				disp.connect("signal_desactivado", callable_desactivado)
			
		if conectado:
			print("[%s] Conectado dinámicamente al disparador: %s" % [name, disp.name])
			
	# Inicializar estado visual y físico desactivado
	actualizar_comportamiento(false)

func _resolver_nodo(target: Variant) -> Node3D:
	if target is Node3D:
		return target
	elif target is NodePath and not (target as NodePath).is_empty():
		var n = get_node_or_null(target)
		if n is Node3D:
			return n
	return null

func _on_disparador_estado_cambiado(disp: Node3D, activo: bool) -> void:
	# Actualizar el estado del disparador en nuestro diccionario
	_estados_disparadores[disp] = activo
	
	# Evaluar la condición combinada
	var condicion_cumplida = false
	
	if condicion_combinacion == CondicionCombinacion.CONDICION_O:
		# OR: cualquiera activo es suficiente
		for estado in _estados_disparadores.values():
			if estado:
				condicion_cumplida = true
				break
	else:
		# AND: todos deben estar activos
		condicion_cumplida = true
		for estado in _estados_disparadores.values():
			if not estado:
				condicion_cumplida = false
				break
				
	# Emitir el RPC de sincronización o ejecutar localmente si el estado general cambió
	if condicion_cumplida != esta_activo:
		if multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
			rpc_sincronizar_estado.rpc(condicion_cumplida)
		else:
			rpc_sincronizar_estado(condicion_cumplida)

@rpc("any_peer", "call_local", "reliable")
func rpc_sincronizar_estado(activo: bool) -> void:
	esta_activo = activo
	actualizar_comportamiento(activo)
	print("[%s] Sincronización P2P: Estado general actualizado a -> %s" % [name, "ACTIVO" if activo else "INACTIVO"])

# Método virtual para ser sobrescrito por clases hijas (puerta y plataforma)
func actualizar_comportamiento(_activo: bool) -> void:
	pass
