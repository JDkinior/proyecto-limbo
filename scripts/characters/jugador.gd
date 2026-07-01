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
	var es_mio = is_multiplayer_authority()
	if es_mio and pivote_camara and pivote_camara.has_node("Camera3D"):
		var camera = pivote_camara.get_node("Camera3D")
		# Excluir capa visual 3 (Plano Espiritual) para ocultar las monedas del fantasma y elementos espirituales
		camera.cull_mask = 1048575 & ~(1 << 2)

func _physics_process(delta):
	if not is_multiplayer_authority(): return

	procesar_camara_base(delta)
	procesar_salto_base(delta)
	procesar_movimiento_base(delta)
