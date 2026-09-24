extends Area3D
class_name GemaEspiritual

# Gema Espiritual — Zona Fantasmal del Nivel 1.
# Al ser recogida por el Fantasma, potencia permanentemente su HabilidadAura:
#   - radio_maximo se multiplica por FACTOR_RADIO.
#   - tiempo_recarga se divide por FACTOR_RECARGA.
# Solo detectable y visible para el Fantasma (Capa 3).

signal gema_recogida

@export var velocidad_rotacion: float = 60.0
@export_group("Potenciador de Aura")
@export var factor_radio: float = 1.6
@export var factor_recarga: float = 0.5   # cooldown × 0.5 = mitad del tiempo

var _ya_recogida: bool = false

func _ready() -> void:
	# Capa 4 (Objetivo/Coleccionable), solo detecta al Fantasma (Capa 3)
	collision_layer = 1 << 3
	collision_mask  = 1 << 2
	body_entered.connect(_on_body_entered)
	# Visible SOLO para el Fantasma — visual layer 3 (valor 4)
	_configurar_capas_visuales(self, 4)

func _process(delta: float) -> void:
	rotate_y(deg_to_rad(velocidad_rotacion * delta))

func _on_body_entered(body: Node) -> void:
	if _ya_recogida:
		return
	if not body is Fantasma:
		return
	_ya_recogida = true

	# Ocultar inmediatamente en el lado local para 0-lag visual
	hide()
	set_deferred("monitoring", false)

	# Solo la autoridad aplica el efecto y emite el RPC
	var es_offline = (multiplayer.multiplayer_peer == null or
			multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	if is_multiplayer_authority() or es_offline:
		_aplicar_potenciador(body)
		gema_recogida.emit()
		if not es_offline and multiplayer.has_multiplayer_peer():
			rpc("_remover_para_todos")
		else:
			queue_free()

func _aplicar_potenciador(fantasma: Node) -> void:
	# Busca el componente HabilidadAura en el Fantasma
	var aura: HabilidadAura = null
	for hijo in fantasma.get_children():
		if hijo is HabilidadAura:
			aura = hijo
			break
	if not is_instance_valid(aura):
		push_warning("[GemaEspiritual] No se encontró HabilidadAura en el Fantasma.")
		return

	aura.radio_maximo   = aura.radio_maximo * factor_radio
	aura.tiempo_recarga = aura.tiempo_recarga * factor_recarga
	# Si el aura estaba activa, actualiza el radio actual también
	if aura.esta_activa():
		aura.radio_actual = minf(aura.radio_actual * factor_radio, aura.radio_maximo)
	print("[GemaEspiritual] ¡Aura potenciada! Radio: %.1f | Recarga: %.1fs" \
		% [aura.radio_maximo, aura.tiempo_recarga])

func _configurar_capas_visuales(nodo: Node, mascara_capas: int) -> void:
	if nodo is VisualInstance3D:
		nodo.layers = mascara_capas
	for hijo in nodo.get_children():
		_configurar_capas_visuales(hijo, mascara_capas)

@rpc("any_peer", "call_local", "reliable")
func _remover_para_todos() -> void:
	queue_free()
