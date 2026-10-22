@tool
extends IslaFlotante
class_name PlataformaPoseible

## ==============================================================================
## PLATAFORMA POSEÍBLE PROCEDURAL (PROYECTO LIMBO)
## Plataforma procedural que el Fantasma puede poseer para convertirla
## en un vehículo móvil aéreo (taxi) o elevador y transportar al Jugador Vivo.
## Hereda de IslaFlotante, configurada con mecánica de posesión activa.
## ==============================================================================

func _init() -> void:
	super._init()
	tipo_comportamiento = TipoComportamiento.POSEIBLE
	puede_ser_poseida = true
	preset = PresetTamano.PEQUENA
	ancho = 4.5
	largo = 4.5
	profundidad_roca = 2.8
	segmentos_perimetro = 16
	anillos_roca = 4
	anillos_superficie = 2
	generar_faldon_pasto = true
	generar_rocas_satelite = false
