extends RigidBody3D
class_name CajaEmpujable

# Caja empujable física para el jugador Vivo.
# La física se simula únicamente en el Servidor/Host y se sincroniza en los clientes
# desactivando su simulación local (freeze = true) para evitar desincronización y jittering.

func _ready() -> void:
	# Capa de colisión 2 (Plano Físico)
	collision_layer = 1 << 1
	
	# Colisiona con Capa 1 (Entorno) y Capa 2 (Plano Físico: vivo y otras cajas)
	collision_mask = (1 << 0) | (1 << 1)
	
	# Si estamos en red y no somos el servidor, congelamos la física localmente
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		if not multiplayer.is_server():
			freeze = true
			print("[CajaEmpujable] Configurada como freeze en cliente.")
		else:
			freeze = false
			print("[CajaEmpujable] Configurada como simulada en servidor.")

@rpc("any_peer", "call_local", "reliable")
func rpc_aplicar_impulso(impulso: Vector3) -> void:
	# Solo el peer que simula la física (el que no está congelado) aplica la fuerza física real
	if not freeze:
		apply_central_impulse(impulso)
