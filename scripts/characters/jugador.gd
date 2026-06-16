extends CharacterBase
class_name Jugador

func _ready():
	super()
	# Jugador pertenece SOLO a capa 2 (Plano Físico)
	collision_layer = 1 << 1   # solo capa 2
	# Máscara: detecta capa 1 (entorno), capa 2 (plataformas físicas), capa 4 (monedas/objetivo)
	# NO incluye capa 3 (Fantasma) → no colisiona con el fantasma
	collision_mask = (1 << 0) | (1 << 1) | (1 << 3)
	if is_instance_valid(RedManager):
		RedManager.registrar_jugador(self)

func actualizar_visibilidad_local():
	super() # Llama a la cámara base

func _physics_process(delta):
	if not is_multiplayer_authority(): return

	procesar_camara_base(delta)
	procesar_salto_base(delta)
	procesar_movimiento_base(delta)
