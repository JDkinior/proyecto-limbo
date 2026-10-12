@tool
extends IslaFlotante
class_name PlataformaEspiritualBase

## ==============================================================================
## PLATAFORMA ESPIRITUAL PROCEDURAL (PROYECTO LIMBO)
## Hereda de IslaFlotante, configurada para habitar el plano espiritual (Capa 3)
## y reaccionar a mecanismos (Aura / Presión / Palanca) para materializarse en el plano físico.
## ==============================================================================

func _init() -> void:
	super._init()
	tipo_comportamiento = TipoComportamiento.ESPIRITUAL
	preset = PresetTamano.PEQUENA
	ancho = 5.0
	largo = 5.0
	profundidad_roca = 3.5
	segmentos_perimetro = 16
	anillos_roca = 4
	anillos_superficie = 2
	generar_faldon_pasto = true
	generar_rocas_satelite = false
