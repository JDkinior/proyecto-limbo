extends Area3D
class_name InterruptorAura

# Interruptor de Aura Espiritual.
# Se activa en cuanto el campo de la HabilidadAura del Fantasma se expande y toca
# el radio de detección de este interruptor, manteniéndose activo mientras
# el aura siga en contacto (e.g. hasta que se encoja y deje de tocarlo, o desaparezca).

signal signal_activado
signal signal_desactivado

@export_group("Configuración de Detección")
@export var radio_deteccion_switch: float = 1.2 # Radio de contacto del propio interruptor

var esta_activo: bool = false

func _ready() -> void:
	# No requiere colisiones físicas del cuerpo del personaje,
	# ya que calculamos la interacción mediante distancia matemática al aura.
	collision_layer = 0
	collision_mask = 0
	
	print("[InterruptorAura] Inicializado con radio de detección: ", radio_deteccion_switch)

func _process(_delta: float) -> void:
	var algun_aura_tocando = false
	
	# Buscar todos los fantasmas registrados en el grupo global
	var fantasmas = get_tree().get_nodes_in_group("fantasmas")
	for f in fantasmas:
		if is_instance_valid(f) and f.habilidad_aura:
			var aura = f.habilidad_aura
			if aura.esta_activa():
				# Distancia horizontal (eje X/Z) para simular el cilindro del aura
				var pos_switch_2d = Vector2(global_position.x, global_position.z)
				var pos_ghost_2d = Vector2(f.global_position.x, f.global_position.z)
				var distancia_horizontal = pos_switch_2d.distance_to(pos_ghost_2d)
				
				# Rango vertical máximo para evitar activar interruptores en pisos superiores/inferiores
				var diferencia_y = abs(global_position.y - f.global_position.y)
				
				# El aura toca el interruptor si la distancia es menor o igual al
				# radio actual del aura más el radio de detección del interruptor
				var radio_total_deteccion = aura.obtener_radio() + radio_deteccion_switch
				if distancia_horizontal <= radio_total_deteccion and diferencia_y <= 2.5:
					algun_aura_tocando = true
					break # Suficiente con que un fantasma lo esté tocando
					
	# Emitir cambios de estado
	if algun_aura_tocando != esta_activo:
		esta_activo = algun_aura_tocando
		if esta_activo:
			signal_activado.emit()
			print("[InterruptorAura] ¡Activado! El aura del Fantasma está en contacto.")
		else:
			signal_desactivado.emit()
			print("[InterruptorAura] ¡Desactivado! El aura se ha encogido o disipado.")
