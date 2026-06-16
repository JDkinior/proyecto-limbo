extends CharacterBase
class_name Jugador

func _ready():
	super()
	collision_mask |= 1 << 3  # enable layer 4 (Objetivo/Moneda)
	if is_instance_valid(RedManager):
		RedManager.registrar_jugador(self)

func actualizar_visibilidad_local():
	super() # Llama a la cámara base

func _physics_process(delta):
	if not is_multiplayer_authority(): return

	procesar_camara_base(delta)
	procesar_salto_base(delta)
	procesar_movimiento_base(delta)
