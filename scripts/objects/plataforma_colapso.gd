extends StaticBody3D
class_name PlataformaColapso

# Plataforma de Colapso — usada en la torre del castillo (Fantasma tutorial).
# Al ser pisada, espera un breve delay y luego desaparece (se cae).
# Se reintegra tras un tiempo de respawn (para no bloquear al Fantasma si falla).
# Capa 1 (Estructura_Global) para que el Fantasma la pise al iniciar.

signal plataforma_colapsando
signal plataforma_restaurada

@export_group("Tiempos de Colapso")
@export var delay_antes_caida: float = 0.6   # Segundos de vibración antes de caer
@export var duracion_caida: float = 1.0       # Cuánto tarda en "bajar" y desaparecer
@export var tiempo_respawn: float = 8.0       # Segundos hasta volver a aparecer

@export_group("Visual")
@export var material_normal: StandardMaterial3D
@export var material_alerta: StandardMaterial3D  # Rojo/naranja, se asigna en editor

var _estado: String = "normal"   # "normal", "temblando", "caida", "oculta"
var _posicion_inicial: Vector3
var _colision: CollisionShape3D
var _mesh: MeshInstance3D
var _timer: float = 0.0

func _ready() -> void:
	_posicion_inicial = global_position
	_colision = get_node_or_null("CollisionShape3D")
	_mesh     = get_node_or_null("MeshInstance3D")

	# Configurar como estructura global (Capa 1) para que el Fantasma la pise
	collision_layer = 1
	collision_mask  = 1

	# Conectar el Area3D hijo para detectar al personaje que pisa la plataforma
	var area = get_node_or_null("Area3D") as Area3D
	if area:
		area.collision_layer = 0
		area.collision_mask  = 7   # Detecta capas 1, 2 y 3 (Fantasma + Vivo)
		if not area.body_entered.is_connected(_on_body_entered):
			area.body_entered.connect(_on_body_entered)

var esta_congelada: bool = false

func congelar_estasis(_duracion: float = 0.0) -> void:
	esta_congelada = true

func descongelar_estasis() -> void:
	esta_congelada = false

func _physics_process(delta: float) -> void:
	if esta_congelada:
		return

	match _estado:
		"temblando":
			_timer += delta
			# Vibración visual sutil
			position.x = _posicion_inicial.x + sin(_timer * 40.0) * 0.04
			if _timer >= delay_antes_caida:
				_iniciar_caida()

		"caida":
			_timer += delta
			var progreso = _timer / duracion_caida
			global_position.y = _posicion_inicial.y - (progreso * 4.0)
			if progreso >= 1.0:
				_ocultar()

		"oculta":
			_timer += delta
			if _timer >= tiempo_respawn:
				_restaurar()

func _on_body_entered(body: Node) -> void:
	if _estado != "normal":
		return
	if body is Fantasma or body is Jugador:
		_estado = "temblando"
		_timer   = 0.0
		plataforma_colapsando.emit()
		if material_alerta and is_instance_valid(_mesh):
			_mesh.set_surface_override_material(0, material_alerta)

func _iniciar_caida() -> void:
	_estado = "caida"
	_timer   = 0.0
	if is_instance_valid(_colision):
		_colision.set_deferred("disabled", true)

func _ocultar() -> void:
	_estado = "oculta"
	_timer   = 0.0
	visible  = false

func _restaurar() -> void:
	_estado = "normal"
	visible = true
	global_position = _posicion_inicial
	if is_instance_valid(_colision):
		_colision.set_deferred("disabled", false)
	if is_instance_valid(_mesh):
		_mesh.set_surface_override_material(0, null)
	plataforma_restaurada.emit()
