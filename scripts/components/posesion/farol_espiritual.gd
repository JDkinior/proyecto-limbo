@tool
extends ObjetoPoseibleBase
class_name FarolEspiritual

## ==============================================================================
## FAROL ESPECTRAL REVELADOR (PROYECTO LIMBO)
## Farol místico de piedra y cristal que el Fantasma puede poseer.
## Permite rotar un haz de luz espiritual concentrado para revelar plataformas
## invisibles o activar sensores fotomísticos para el Jugador Vivo.
## ==============================================================================

signal haz_iluminando_objeto(objeto: Node3D)

@export_group("Haz de Luz Espiritual")
@export var velocidad_rotacion_foco: float = 3.2
@export var rango_luz: float = 22.0
@export var angulo_apertura_luz: float = 45.0
@export var color_luz_posesion: Color = Color(0.2, 0.85, 1.0, 1.0)
@export var energia_luz_posesion: float = 4.5

@export_group("Referencias del Farol")
@export var luz_foco: SpotLight3D = null
@export var nodo_cabeza_farol: Node3D = null
@export var area_cono_luz: Area3D = null

var _angulo_foco: float = 0.0
var _objetos_iluminados_actuales: Array[Node3D] = []

func _ready() -> void:
	super()
	nombre_objeto = "Farol Espiritual"
	distancia_camara_posesion = 6.8
	altura_spring_arm_posesion = 3.2
	pitch_defecto_posesion = -0.42 # Contrapicado hacia abajo para ver el haz de luz
	
	if area_cono_luz:
		area_cono_luz.body_entered.connect(_on_objeto_entro_haz)
		area_cono_luz.body_exited.connect(_on_objeto_salio_haz)
		area_cono_luz.area_entered.connect(_on_objeto_entro_haz)
		area_cono_luz.area_exited.connect(_on_objeto_salio_haz)

func procesar_input_posesion(delta: float, input_dir: Vector2, _acciones: Dictionary) -> void:
	if not esta_poseido:
		return
	
	if input_dir.length_squared() > 0.05:
		# Rotación directa hacia el vector del joystick
		var angulo_meta = atan2(input_dir.x, input_dir.y)
		_angulo_foco = lerp_angle(_angulo_foco, angulo_meta, velocidad_rotacion_foco * 4.0 * delta)
		
		if is_instance_valid(nodo_cabeza_farol):
			nodo_cabeza_farol.rotation.y = _angulo_foco
		else:
			rotation.y = _angulo_foco
			
		if is_instance_valid(nodo_ojos):
			nodo_ojos.actualizar_mirada(Vector3(input_dir.x, 0.0, -input_dir.y), 0.6)

func _al_iniciar_posesion() -> void:
	if is_instance_valid(luz_foco):
		luz_foco.visible = true
		luz_foco.light_color = color_luz_posesion
		luz_foco.light_energy = energia_luz_posesion
		luz_foco.spot_range = rango_luz
		luz_foco.spot_angle = angulo_apertura_luz

func _al_terminar_posesion() -> void:
	if is_instance_valid(luz_foco):
		luz_foco.light_energy = 0.5
	# Desactivar objetos que estaban bajo el haz
	for obj in _objetos_iluminados_actuales:
		if is_instance_valid(obj) and obj.has_method("activar_por_luz"):
			obj.activar_por_luz(false)
	_objetos_iluminados_actuales.clear()

func _on_objeto_entro_haz(area_o_cuerpo: Node) -> void:
	if not esta_poseido:
		return
	if area_o_cuerpo is Node3D and not area_o_cuerpo in _objetos_iluminados_actuales:
		_objetos_iluminados_actuales.append(area_o_cuerpo as Node3D)
		if area_o_cuerpo.has_method("activar_por_luz"):
			area_o_cuerpo.activar_por_luz(true)
		haz_iluminando_objeto.emit(area_o_cuerpo as Node3D)

func _on_objeto_salio_haz(area_o_cuerpo: Node) -> void:
	if area_o_cuerpo in _objetos_iluminados_actuales:
		_objetos_iluminados_actuales.erase(area_o_cuerpo)
		if is_instance_valid(area_o_cuerpo) and area_o_cuerpo.has_method("activar_por_luz"):
			area_o_cuerpo.activar_por_luz(false)
