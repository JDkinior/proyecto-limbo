@tool
extends IslaFlotante
class_name PlataformaColapso

## ==============================================================================
## PLATAFORMA DE COLAPSO PROCEDURAL (PROYECTO LIMBO)
## Hereda de IslaFlotante, configurada para colapsar y desmoronarse al ser pisada.
## Se reintegra tras el tiempo de respawn para mantener la fluidez del gameplay.
## ==============================================================================

func _init() -> void:
	super._init()
	tipo_comportamiento = TipoComportamiento.COLAPSO
	preset = PresetTamano.PEQUENA
	ancho = 5.0
	largo = 5.0
	profundidad_roca = 3.5
	segmentos_perimetro = 16
	anillos_roca = 4
	anillos_superficie = 2
	generar_faldon_pasto = true
	generar_rocas_satelite = false
