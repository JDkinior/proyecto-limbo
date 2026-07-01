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
	# Compatibilidad: si disparador_objetivo está asignado, lo añadimos al array
	if is_instance_valid(disparador_objetivo) and not disparador_objetivo in disparadores_objetivo:
		disparadores_objetivo.append(disparador_objetivo)
		
	if disparadores_objetivo.is_empty():
		push_warning("[%s] ADVERTENCIA: No se asignaron disparadores en disparadores_objetivo." % name)
		return
		
	# Conectarse dinámicamente a cada disparador y registrar su estado
	for disp in disparadores_objetivo:
		if not is_instance_valid(disp):
			continue
			
		_estados_disparadores[disp] = false
		var conectado = false
		
		# Usamos Callable explícito con self para máxima compatibilidad
		var callable_activado = Callable(self, "_on_disparador_estado_cambiado").bind(disp, true)
		var callable_desactivado = Callable(self, "_on_disparador_estado_cambiado").bind(disp, false)
		
		if disp.has_signal("signal_activado"):
			disp.connect("signal_activado", callable_activado)
			conectado = true
		else:
			push_error("[%s] ERROR: El disparador '%s' no tiene la señal 'signal_activado'." % [name, disp.name])
			
		if disp.has_signal("signal_desactivado"):
			disp.connect("signal_desactivado", callable_desactivado)
			
		if conectado:
			print("[%s] Conectado dinámicamente al disparador: %s" % [name, disp.name])
			
	# Inicializar estado visual y físico desactivado
	actualizar_comportamiento(false)

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
				
	# Emitir el RPC de sincronización si el estado general cambió
	if condicion_cumplida != esta_activo:
		rpc_sincronizar_estado.rpc(condicion_cumplida)

@rpc("any_peer", "call_local", "reliable")
func rpc_sincronizar_estado(activo: bool) -> void:
	esta_activo = activo
	actualizar_comportamiento(activo)
	print("[%s] Sincronización P2P: Estado general actualizado a -> %s" % [name, "ACTIVO" if activo else "INACTIVO"])

# Método virtual para ser sobrescrito por clases hijas (puerta y plataforma)
func actualizar_comportamiento(_activo: bool) -> void:
	pass
