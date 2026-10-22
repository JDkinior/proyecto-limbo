@tool
extends IslaFlotante
class_name PlataformaTaxi

## ==============================================================================
## PLATAFORMA TAXI ESPECTRAL PROCEDURAL (PROYECTO LIMBO)
## Plataforma de piedra flotante procedural que el Fantasma puede poseer para
## convertirla en un vehículo aéreo ("el taxi") o elevador y transportar al Jugador Vivo.
## Soporta ejes configurables: Horizontal (plano XZ), Vertical (eje Y) o Riel 3D.
## Hereda de IslaFlotante, adoptando el diseño espectral de la Cabeza del Fantasma y Ojos 3D.
## ==============================================================================

func _init() -> void:
	super._init()
	tipo_comportamiento = TipoComportamiento.POSEIBLE
	puede_ser_poseida = true
	preset = PresetTamano.PEQUENA
	ancho = 4.2
	largo = 4.2
	profundidad_roca = 2.0
	segmentos_perimetro = 16
	anillos_roca = 4
	anillos_superficie = 2
	generar_pasto = false
	generar_faldon_pasto = false
	pasto_distancia = false
	generar_rocas_satelite = false


func _ready() -> void:
	tipo_comportamiento = TipoComportamiento.POSEIBLE
	puede_ser_poseida = true
	generar_pasto = false
	generar_faldon_pasto = false
	pasto_distancia = false
	super._ready()
	nombre_objeto = "Plataforma Taxi"
	distancia_camara_posesion = 7.5
	altura_spring_arm_posesion = 2.4
	pitch_defecto_posesion = -0.26
