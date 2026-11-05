@tool
extends CharacterBody3D
class_name EnemigoEspectral

## ==============================================================================
## ENEMIGO ESPECTRAL (PROYECTO LIMBO)
## Sombra fantasmal que acecha al Jugador Vivo en el plano espiritual.
## - Permanece oculto y dormido fuera de su Zona de Peligro.
## - Marcador visual: la zona de spawn emite brasas espectrales moradas.
## - Solo se manifiesta cuando el Vivo ingresa a su territorio.
## - Una vez despierto, persigue al Vivo a cualquier rincón de la MISMA plataforma.
## - Si el Vivo abandona la plataforma (salta a otra isla o cae al vacío), el
##   espectro desiste, se desvanece y regresa a dormir a su punto original.
## - Si hace contacto con el Vivo sin estar vulnerable/embatido: provoca su MUERTE
##   INSTANTÁNEA, desaparece con efecto espectral y reaparece dormido en su origen.
## ==============================================================================

signal estado_cambiado(nuevo_estado: int)
signal enemigo_revelado
signal enemigo_ocultado
signal enemigo_manifestado
signal enemigo_desvanecido
signal enemigo_golpeado(jugador: Node3D)
signal jugador_eliminado(jugador: Node3D)

enum Estado {
	INACTIVO_OCULTO,     ## Oculto esperando a que el Vivo entre a la zona de peligro
	MANIFESTANDOSE,      ## Animación de despertar y aparición espectral en origen
	ACECHO_INVISIBLE,    ## Persiguiendo al Vivo en la misma plataforma (invisible para él)
	ANTICIPANDO_ATAQUE,  ## Se detiene un momento, aparece visualmente y anticipa su ataque
	TANGIBLE_VULNERABLE, ## Revelado y aturdido por el Aura del Fantasma: quieto, tangible y golpeable
	GOLPE_LETAL,         ## Contacto mortal: elimina al Vivo, se desvanece y reinicia
	DERROTADO            ## Embate o pisotón recibido del Vivo: squash & stretch y destrucción
}

@export_group("Zona de Peligro y Plataforma")
## Radio en metros de la zona de peligro para despertar al enemigo
@export var radio_zona_peligro: float = 8.0:
	set(valor):
		radio_zona_peligro = valor
		if is_inside_tree():
			_actualizar_dimensiones_zona()
## Si es verdadero, el enemigo permanece dormido e invisible hasta que el Vivo entra a la zona.
@export var activar_solo_en_zona: bool = true
## Muestra el aro que marca el radio de la zona (solo como ayuda para ubicar al enemigo).
## El aviso real para el Vivo es ahora la silueta translúcida del espectro.
@export var mostrar_indicador_radio: bool = false:
	set(valor):
		mostrar_indicador_radio = valor
		if is_node_ready() and is_instance_valid(indicador_anillo_spawn):
			indicador_anillo_spawn.visible = valor
## Plataforma o isla asignada a este enemigo. Si no se asigna, se detecta automáticamente bajo sus pies.
@export var plataforma_asignada: Node3D = null
## Distancia en metros a la que el enemigo elimina al Vivo por contacto íntimo
@export var distancia_ataque: float = 1.2
## Distancia a la que el enemigo se detiene, se hace visible y anticipa su ataque
@export var distancia_inicio_ataque: float = 1.85
## Tiempo en segundos que el enemigo se detiene y aparece visualmente antes de lanzar su golpe
@export var tiempo_anticipacion_ataque: float = 0.95
## Tiempo adicional en segundos que el enemigo permanece visible y vulnerable tras anticipar o fallar el golpe
@export var tiempo_permanencia_visible: float = 0.75
## Velocidad de persecución flotante y sigilosa (calibrada para dar tiempo de reacción)
@export var velocidad_acecho: float = 1.9
## Altura respecto al suelo donde flota el espectro
@export var altura_flotacion: float = 0.75
## Tiempo en segundos de anticipación al manifestarse antes de empezar a perseguir
@export var tiempo_anticipacion_spawn: float = 0.8

@export_group("Generación Múltiple (Zona de Peligro)")
## Cantidad de enemigos espectrales que se generan en esta zona (1, 2 o más)
@export_range(1, 8, 1) var cantidad_enemigos: int = 1
## Tiempo de espera (en segundos) entre la manifestación de cada enemigo
@export_range(0.2, 5.0, 0.1) var tiempo_entre_spawns: float = 1.5

@export_group("Tangibilidad y Aura")
## Margen de contacto adicional al radio del Aura del Fantasma
@export var radio_contacto_aura: float = 1.3
## Tiempo de gracia (segundos) que permanece tangible tras salir del radio del aura
@export var tiempo_gracia_tangible: float = 0.65

@export_group("Referencias de Nodos")
@onready var nodo_visual: Node3D = get_node_or_null("Visual")
@onready var modelo_glb: Node3D = get_node_or_null("Visual/ModeloEnemigo")
@onready var mesh_cuerpo: MeshInstance3D = get_node_or_null("Visual/Cuerpo")
@onready var nodo_manos: Node3D = get_node_or_null("Visual/ManosFlotantes")
@onready var mano_izq: Node3D = get_node_or_null("Visual/ManosFlotantes/ManoIzq")
@onready var mano_der: Node3D = get_node_or_null("Visual/ManosFlotantes/ManoDer")
@onready var glb_mano_izq: Node3D = get_node_or_null("Visual/ModeloEnemigo/Enemigo_Mano_L")
@onready var glb_mano_der: Node3D = get_node_or_null("Visual/ModeloEnemigo/Enemigo_Mano_R")
@onready var nodo_ojos: Node3D = get_node_or_null("Visual/OjosRojos")
@onready var mesh_distorsion: MeshInstance3D = get_node_or_null("Visual/EfectoDistorsion")
@onready var particulas_pasto: CPUParticles3D = get_node_or_null("ParticulasPasto")
@onready var particulas_muerte: CPUParticles3D = get_node_or_null("ParticulasDerrota")
@onready var particulas_zona_spawn: CPUParticles3D = get_node_or_null("ParticulasZonaSpawn")
@onready var indicador_anillo_spawn: MeshInstance3D = get_node_or_null("IndicadorAnilloSpawn")
@onready var grietas_suelo_spawn: MeshInstance3D = get_node_or_null("GrietasSueloSpawn")
@onready var audio_acecho: AudioStreamPlayer3D = get_node_or_null("AudioAcecho")
@onready var colision_cuerpo: CollisionShape3D = get_node_or_null("CollisionShape3D")

var estado_actual: Estado = Estado.INACTIVO_OCULTO
var _posicion_origen: Vector3 = Vector3.ZERO
var _plataforma_detectada: Node3D = null
var _jugador_vivo_ref: Node3D = null
var _fantasma_ref: Node3D = null
var _temporizador_gracia_aura: float = 0.0
var _temporizador_manifestacion: float = 0.0
var _temporizador_ataque: float = 0.0
var _temporizador_permanencia: float = 0.0
var _fase_anticipacion_terminada: bool = false
var _esta_tangible: bool = false
var _tiempo_acumulado: float = 0.0
var _mat_cuerpo: Material = null
var _escala_base_visual: Vector3 = Vector3.ONE
var _pos_base_visual: Vector3 = Vector3.ZERO
var _animando_transicion_vertical: bool = false
var _tween_vertical: Tween = null
var _pos_base_glb_mano_izq: Vector3 = Vector3(-1.44, -0.15, 0.25)
var _pos_base_glb_mano_der: Vector3 = Vector3(1.44, -0.15, 0.25)

## Estado de clonación y spawns múltiples
var es_clon: bool = false
var _clones_activos: Array[Node] = []
var _secuencia_spawn_activa: bool = false
var _lider_ref: EnemigoEspectral = null  ## Referencia al líder (solo para clones)
var _indice_clon: int = 0  ## Índice del enemigo en la formación (0=líder, 1..N=clones)
var _lider_derrotado: bool = false  ## True cuando el líder ha sido eliminado

func _ready() -> void:
	_posicion_origen = global_position if is_inside_tree() else position
	add_to_group("enemigos_espectrales")
	
	if is_instance_valid(nodo_visual):
		_escala_base_visual = nodo_visual.scale
		# Normalizar posición local a Vector3.ZERO para centrar la flotación en el CharacterBody3D
		nodo_visual.position = Vector3.ZERO
		_pos_base_visual = Vector3.ZERO
	if is_instance_valid(colision_cuerpo):
		colision_cuerpo.position = Vector3.ZERO
	
	_cachear_materiales()
	_configurar_capas_iniciales()
	_sincronizar_particulas_pasto()

	if es_clon:
		# Los clones no duplican las partículas del territorio ni el anillo
		if is_instance_valid(particulas_zona_spawn):
			particulas_zona_spawn.queue_free()
		if is_instance_valid(indicador_anillo_spawn):
			indicador_anillo_spawn.queue_free()
		if is_instance_valid(grietas_suelo_spawn):
			grietas_suelo_spawn.queue_free()
	else:
		_asegurar_nodo_grietas_suelo()
		_anclar_particulas_zona_spawn()

	_resolver_plataforma_inicial.call_deferred()
	
	if activar_solo_en_zona:
		_desvanecer_a_origen(false)
	else:
		_manifestar_en_zona()

func _asegurar_nodo_grietas_suelo() -> void:
	if es_clon:
		return
	if not is_instance_valid(grietas_suelo_spawn):
		grietas_suelo_spawn = get_node_or_null("GrietasSueloSpawn") as MeshInstance3D
	if not is_instance_valid(grietas_suelo_spawn):
		grietas_suelo_spawn = MeshInstance3D.new()
		grietas_suelo_spawn.name = "GrietasSueloSpawn"
		grietas_suelo_spawn.position = Vector3(0, -0.71, 0)
		grietas_suelo_spawn.layers = 7
		add_child(grietas_suelo_spawn)
	if grietas_suelo_spawn.material_override == null:
		grietas_suelo_spawn.material_override = load("res://shaders/components/peligros/grietas_espectrales_mat.tres")
	_asegurar_luz_grietas()

## Centros (en coordenadas uv_c del shader) de las 4 grietas.
const CENTROS_GRIETAS: Array[Vector2] = [
	Vector2(0.14, 0.45), Vector2(0.48, -0.10), Vector2(-0.34, -0.42), Vector2(-0.48, 0.24)
]

## Una luz roja por grieta, ubicada en el fondo de la fosa: ilumina desde abajo
## a quien se pare sobre la grieta y tiñe el entorno cercano.
func _asegurar_luz_grietas() -> void:
	if es_clon or not is_instance_valid(grietas_suelo_spawn):
		return
	for i in CENTROS_GRIETAS.size():
		var nombre := "LuzGrieta%d" % i
		if grietas_suelo_spawn.get_node_or_null(nombre) != null:
			continue
		var luz := OmniLight3D.new()
		luz.name = nombre
		luz.light_color = Color(1.0, 0.07, 0.09)
		luz.light_energy = 2.4
		luz.omni_attenuation = 1.2
		luz.shadow_enabled = false
		grietas_suelo_spawn.add_child(luz)
		var tw: Tween = luz.create_tween().set_loops()
		tw.tween_property(luz, "light_energy", 3.2, 1.3 + 0.3 * i).set_trans(Tween.TRANS_SINE)
		tw.tween_property(luz, "light_energy", 1.8, 1.3 + 0.3 * i).set_trans(Tween.TRANS_SINE)
	_actualizar_luces_grietas()

func _actualizar_luces_grietas() -> void:
	if not is_instance_valid(grietas_suelo_spawn):
		return
	var radio_malla: float = maxf(radio_zona_peligro * 0.96, 1.0)
	for i in CENTROS_GRIETAS.size():
		var luz := grietas_suelo_spawn.get_node_or_null("LuzGrieta%d" % i) as OmniLight3D
		if luz:
			luz.position = Vector3(CENTROS_GRIETAS[i].x * radio_malla, -0.35, CENTROS_GRIETAS[i].y * radio_malla)
			luz.omni_range = 2.8

func _intensificar_luces_grietas(activar: bool) -> void:
	if not is_instance_valid(grietas_suelo_spawn):
		return
	var energia_objetivo: float = 4.8 if activar else 2.4
	for i in CENTROS_GRIETAS.size():
		var luz := grietas_suelo_spawn.get_node_or_null("LuzGrieta%d" % i) as OmniLight3D
		if luz:
			var tw := luz.create_tween()
			tw.tween_property(luz, "light_energy", energia_objetivo, 0.35 if activar else 0.8)
			if not activar:
				tw.tween_callback(func():
					if is_instance_valid(luz):
						var loop_tw := luz.create_tween().set_loops()
						loop_tw.tween_property(luz, "light_energy", 3.2, 1.3 + 0.3 * i).set_trans(Tween.TRANS_SINE)
						loop_tw.tween_property(luz, "light_energy", 1.8, 1.3 + 0.3 * i).set_trans(Tween.TRANS_SINE)
				)

func _anclar_particulas_zona_spawn() -> void:
	if es_clon:
		return

	if not Engine.is_editor_hint():
		if is_instance_valid(particulas_zona_spawn):
			particulas_zona_spawn.top_level = true
			particulas_zona_spawn.global_position = _posicion_origen + Vector3.DOWN * 0.7
			particulas_zona_spawn.emitting = true
			particulas_zona_spawn.visible = true

		if is_instance_valid(indicador_anillo_spawn):
			indicador_anillo_spawn.top_level = true
			indicador_anillo_spawn.global_position = _posicion_origen + Vector3.DOWN * 0.72
			indicador_anillo_spawn.visible = mostrar_indicador_radio

		if is_instance_valid(grietas_suelo_spawn):
			grietas_suelo_spawn.top_level = true
			grietas_suelo_spawn.global_position = _posicion_origen + Vector3.DOWN * 0.71
			grietas_suelo_spawn.visible = true
	else:
		if is_instance_valid(particulas_zona_spawn):
			particulas_zona_spawn.top_level = false
			particulas_zona_spawn.position = Vector3(0, -0.7, 0)
			particulas_zona_spawn.emitting = true
			particulas_zona_spawn.visible = true
		if is_instance_valid(indicador_anillo_spawn):
			indicador_anillo_spawn.top_level = false
			indicador_anillo_spawn.position = Vector3(0, -0.72, 0)
			indicador_anillo_spawn.visible = mostrar_indicador_radio
		if is_instance_valid(grietas_suelo_spawn):
			grietas_suelo_spawn.top_level = false
			grietas_suelo_spawn.position = Vector3(0, -0.71, 0)
			grietas_suelo_spawn.visible = true

	_actualizar_dimensiones_zona()

func _actualizar_dimensiones_zona() -> void:
	if es_clon:
		return
	if is_instance_valid(indicador_anillo_spawn):
		indicador_anillo_spawn.scale = Vector3(radio_zona_peligro, 1.0, radio_zona_peligro)
	if is_instance_valid(particulas_zona_spawn):
		particulas_zona_spawn.emission_box_extents = Vector3(radio_zona_peligro * 0.72, 0.08, radio_zona_peligro * 0.72)
		var cant = clampi(int(radio_zona_peligro * 3.0), 12, 40)
		if particulas_zona_spawn.amount != cant:
			particulas_zona_spawn.amount = cant
	if is_instance_valid(grietas_suelo_spawn) and grietas_suelo_spawn.material_override is ShaderMaterial:
		var radio_malla: float = max(radio_zona_peligro * 0.96, 1.0)
		grietas_suelo_spawn.material_override.set_shader_parameter("radio_zona", radio_malla)
		_actualizar_luces_grietas()
	_generar_malla_grietas_adaptada(false)

func _resolver_plataforma_inicial() -> void:
	if is_instance_valid(plataforma_asignada):
		_plataforma_detectada = plataforma_asignada

	if not is_inside_tree() or get_world_3d() == null:
		return

	var espacio = get_world_3d().direct_space_state
	if not espacio:
		return

	var origen_rayo = _posicion_origen + Vector3.UP * 2.0
	var fin_rayo = _posicion_origen + Vector3.DOWN * 8.0
	var query = PhysicsRayQueryParameters3D.create(origen_rayo, fin_rayo, 1)
	query.exclude = [get_rid()]
	var hit = espacio.intersect_ray(query)
	if hit and not hit.is_empty():
		var col = hit.get("collider")
		if is_instance_valid(col) and not is_instance_valid(_plataforma_detectada):
			var p: Node = col
			while p != null and not (p is IslaFlotante) and p != get_tree().current_scene:
				p = p.get_parent()
			_plataforma_detectada = p if (p is IslaFlotante) else col

		var hit_pos: Vector3 = hit.get("position")
		# Ajustar origen vertical a la altura deseada sobre la superficie del suelo detectada
		_posicion_origen.y = hit_pos.y + altura_flotacion
		if estado_actual == Estado.INACTIVO_OCULTO or estado_actual == Estado.MANIFESTANDOSE:
			if is_inside_tree():
				global_position = _posicion_origen
			else:
				position = _posicion_origen

		if not Engine.is_editor_hint():
			if is_instance_valid(particulas_zona_spawn) and not es_clon:
				particulas_zona_spawn.global_position = Vector3(_posicion_origen.x, hit_pos.y + 0.05, _posicion_origen.z)
			if is_instance_valid(indicador_anillo_spawn) and not es_clon:
				indicador_anillo_spawn.global_position = Vector3(_posicion_origen.x, hit_pos.y + 0.03, _posicion_origen.z)
			if is_instance_valid(grietas_suelo_spawn) and not es_clon:
				grietas_suelo_spawn.global_position = Vector3(_posicion_origen.x, hit_pos.y + 0.025, _posicion_origen.z)
		_generar_malla_grietas_adaptada(true)

## Genera una malla circular subdividida cuyos vértices se proyectan con raycasts
## sobre la morfología real del suelo para que las grietas se adapten a colinas,
## pendientes y desniveles sin atravesar ni flotar sobre el terreno.
func _generar_malla_grietas_adaptada(usar_raycast_fisico: bool) -> void:
	if es_clon or not is_instance_valid(grietas_suelo_spawn):
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var divisiones: int = 24
	var radio: float = max(radio_zona_peligro * 0.96, 1.0)
	var paso: float = (radio * 2.0) / float(divisiones)

	var usar_espacio: bool = usar_raycast_fisico and is_inside_tree() and get_world_3d() != null
	var espacio: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state if usar_espacio else null
	var base_pos: Vector3 = grietas_suelo_spawn.global_position if is_inside_tree() else (_posicion_origen + Vector3.DOWN * 0.71)
	var excl: Array[RID] = [get_rid()]

	# Muestrear grilla de alturas y normales adaptadas a la topografía del suelo
	var grilla_pos: Array[Vector3] = []
	var grilla_norm: Array[Vector3] = []
	var grilla_uv: Array[Vector2] = []
	var grilla_valida: Array[bool] = []
	var total_puntos: int = (divisiones + 1) * (divisiones + 1)
	grilla_pos.resize(total_puntos)
	grilla_norm.resize(total_puntos)
	grilla_uv.resize(total_puntos)
	grilla_valida.resize(total_puntos)
	grilla_valida.fill(true)

	for iz in range(divisiones + 1):
		var lz: float = -radio + float(iz) * paso
		for ix in range(divisiones + 1):
			var lx: float = -radio + float(ix) * paso
			var idx: int = iz * (divisiones + 1) + ix
			var uv := Vector2(
				(lx / (radio * 2.0)) + 0.5,
				(lz / (radio * 2.0)) + 0.5
			)
			var ly: float = 0.0
			var normal_vert := Vector3.UP

			# Limitar los puntos exteriores al círculo de la zona para suavizar el borde
			var dist_r: float = Vector2(lx, lz).length()
			var px: float = lx
			var pz: float = lz
			if dist_r > radio:
				var dir_2d: Vector2 = Vector2(lx, lz) / dist_r
				px = dir_2d.x * radio
				pz = dir_2d.y * radio

			if espacio != null:
				var p_mundo := Vector3(base_pos.x + px, _posicion_origen.y + 4.0, base_pos.z + pz)
				var f_mundo := Vector3(base_pos.x + px, _posicion_origen.y - 3.0, base_pos.z + pz)
				var q := PhysicsRayQueryParameters3D.create(p_mundo, f_mundo, 1)
				q.exclude = excl
				var res: Dictionary = espacio.intersect_ray(q)
				if res and not res.is_empty():
					var hit_p: Vector3 = res.get("position")
					var hit_n: Vector3 = res.get("normal", Vector3.UP)
					var delta_y: float = absf(hit_p.y - base_pos.y)
					# Solo aceptar superficies transitables de la plataforma (no acantilados verticales ni caídas al vacío)
					if hit_n.y >= 0.65 and delta_y <= 0.75:
						normal_vert = hit_n.normalized()
						var punto_adaptado: Vector3 = hit_p + normal_vert * 0.025
						ly = punto_adaptado.y - base_pos.y
						px = punto_adaptado.x - base_pos.x
						pz = punto_adaptado.z - base_pos.z
					else:
						grilla_valida[idx] = false
				else:
					grilla_valida[idx] = false

			grilla_pos[idx] = Vector3(px, ly, pz)
			grilla_norm[idx] = normal_vert
			grilla_uv[idx] = uv

	for iz in range(divisiones):
		for ix in range(divisiones):
			var i00: int = iz * (divisiones + 1) + ix
			var i10: int = i00 + 1
			var i01: int = (iz + 1) * (divisiones + 1) + ix
			var i11: int = i01 + 1

			# Descartar celdas completamente fuera del círculo
			var c_uv: Vector2 = (grilla_uv[i00] + grilla_uv[i11]) * 0.5 - Vector2(0.5, 0.5)
			if c_uv.length() > 0.56:
				continue

			# Triángulo 1 (solo si los 3 vértices reposan válidamente sobre la plataforma)
			if grilla_valida[i00] and grilla_valida[i10] and grilla_valida[i11]:
				st.set_normal(grilla_norm[i00])
				st.set_uv(grilla_uv[i00])
				st.add_vertex(grilla_pos[i00])

				st.set_normal(grilla_norm[i10])
				st.set_uv(grilla_uv[i10])
				st.add_vertex(grilla_pos[i10])

				st.set_normal(grilla_norm[i11])
				st.set_uv(grilla_uv[i11])
				st.add_vertex(grilla_pos[i11])

			# Triángulo 2 (solo si los 3 vértices reposan válidamente sobre la plataforma)
			if grilla_valida[i00] and grilla_valida[i11] and grilla_valida[i01]:
				st.set_normal(grilla_norm[i00])
				st.set_uv(grilla_uv[i00])
				st.add_vertex(grilla_pos[i00])

				st.set_normal(grilla_norm[i11])
				st.set_uv(grilla_uv[i11])
				st.add_vertex(grilla_pos[i11])

				st.set_normal(grilla_norm[i01])
				st.set_uv(grilla_uv[i01])
				st.add_vertex(grilla_pos[i01])

	grietas_suelo_spawn.mesh = st.commit()

func _cachear_materiales() -> void:
	if is_instance_valid(mesh_cuerpo):
		var mat = mesh_cuerpo.get_active_material(0)
		if not mat and mesh_cuerpo.mesh:
			mat = mesh_cuerpo.mesh.surface_get_material(0)
		if mat:
			_mat_cuerpo = mat.duplicate()
			mesh_cuerpo.set_surface_override_material(0, _mat_cuerpo)

	if is_instance_valid(glb_mano_izq):
		_pos_base_glb_mano_izq = glb_mano_izq.position
	if is_instance_valid(glb_mano_der):
		_pos_base_glb_mano_der = glb_mano_der.position

	if is_instance_valid(modelo_glb):
		var mat_rojo = StandardMaterial3D.new()
		mat_rojo.albedo_color = Color(0.95, 0.02, 0.05, 1.0)
		mat_rojo.emission_enabled = true
		mat_rojo.emission = Color(1.0, 0.06, 0.08, 1.0)
		mat_rojo.emission_energy_multiplier = 3.8
		mat_rojo.roughness = 0.5
		mat_rojo.metallic = 0.0

		for nombre_parte in ["Enemigo_Cuerpo", "Enemigo_Copete", "Enemigo_Mano_L", "Enemigo_Mano_R", "Enemigo_Cejas"]:
			var m_node = modelo_glb.get_node_or_null(nombre_parte) as MeshInstance3D
			if is_instance_valid(m_node) and is_instance_valid(_mat_cuerpo):
				m_node.set_surface_override_material(0, _mat_cuerpo)
				if nombre_parte == "Enemigo_Cuerpo" and m_node.mesh and m_node.mesh.get_surface_count() > 1:
					m_node.set_surface_override_material(1, mat_rojo)

		for nombre_rojo in ["Enemigo_Ojos", "Enemigo_Ojo_L", "Enemigo_Ojo_R", "Enemigo_Boca"]:
			var r_node = modelo_glb.get_node_or_null(nombre_rojo) as MeshInstance3D
			if is_instance_valid(r_node):
				r_node.set_surface_override_material(0, mat_rojo)

func _configurar_capas_iniciales() -> void:
	if is_instance_valid(modelo_glb):
		_asignar_capas_recursivo(modelo_glb, 4)
	if is_instance_valid(mesh_cuerpo):
		mesh_cuerpo.layers = 4 # Capa 3 (Plano Espiritual)
	if is_instance_valid(nodo_manos):
		_asignar_capas_recursivo(nodo_manos, 4)
	if is_instance_valid(nodo_ojos):
		_asignar_capas_recursivo(nodo_ojos, 4)
	if is_instance_valid(mesh_distorsion):
		mesh_distorsion.layers = 2 # Capa 2 exclusivo para el Vivo
		mesh_distorsion.visible = false

func _sincronizar_particulas_pasto() -> void:
	if not is_instance_valid(particulas_pasto) or not is_instance_valid(particulas_zona_spawn):
		return
	particulas_pasto.layers = 7
	particulas_pasto.mesh = particulas_zona_spawn.mesh
	particulas_pasto.scale_amount_curve = particulas_zona_spawn.scale_amount_curve
	particulas_pasto.color_ramp = particulas_zona_spawn.color_ramp
	particulas_pasto.amount = 6
	particulas_pasto.lifetime = 1.6
	particulas_pasto.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particulas_pasto.emission_sphere_radius = 0.45
	particulas_pasto.direction = Vector3(0, 1, 0)
	particulas_pasto.spread = 22.0
	particulas_pasto.gravity = Vector3(0, 0.04, 0)
	particulas_pasto.initial_velocity_min = 0.18
	particulas_pasto.initial_velocity_max = 0.3
	particulas_pasto.scale_amount_min = 0.4
	particulas_pasto.scale_amount_max = 0.75

func _asignar_capas_recursivo(nodo: Node, mascara_capas: int) -> void:
	if nodo is VisualInstance3D:
		(nodo as VisualInstance3D).layers = mascara_capas
	for hijo in nodo.get_children():
		_asignar_capas_recursivo(hijo, mascara_capas)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	procesar_ciclo_ia(delta)

func procesar_ciclo_ia(delta: float) -> void:
	if estado_actual == Estado.DERROTADO or estado_actual == Estado.GOLPE_LETAL:
		return

	var vivo = _obtener_jugador_vivo()
	if not is_instance_valid(vivo):
		return

	var pos_vivo = vivo.global_position if vivo.is_inside_tree() else vivo.position
	
	# Cálculo horizontal 2D de proximidad a la zona de peligro
	var pos_origen_2d = Vector2(_posicion_origen.x, _posicion_origen.z)
	var pos_vivo_2d = Vector2(pos_vivo.x, pos_vivo.z)
	var dist_vivo_a_zona = pos_origen_2d.distance_to(pos_vivo_2d)
	var diff_y = abs(pos_vivo.y - _posicion_origen.y)

	# 1. ESTADO INACTIVO: Vigilar si el Vivo entra a la zona de peligro
	if estado_actual == Estado.INACTIVO_OCULTO:
		if dist_vivo_a_zona <= radio_zona_peligro and diff_y <= 5.0:
			_manifestar_en_zona()
		return

	# 2. FASE DE MANIFESTACIÓN (Pausa con anticipación para dar tiempo de reacción)
	if estado_actual == Estado.MANIFESTANDOSE:
		_temporizador_manifestacion -= delta
		_animar_flotacion_y_manos(delta)
		_actualizar_silueta_aviso()
		if _temporizador_manifestacion <= 0.0:
			estado_actual = Estado.ACECHO_INVISIBLE
			estado_cambiado.emit(estado_actual)
		return

	# 3. VERIFICACIÓN DE PLATAFORMA: Si el Vivo abandonó la plataforma, desvanecer y reiniciar
	if not _esta_vivo_en_misma_plataforma(vivo):
		_desvanecer_a_origen(true)
		return

	_tiempo_acumulado += delta
	_animar_flotacion_y_manos(delta)
	if not _esta_tangible and estado_actual != Estado.ANTICIPANDO_ATAQUE:
		_actualizar_silueta_aviso()

	_verificar_tangibilidad_con_aura(delta)
	_actualizar_comportamiento_ia(vivo, delta)
	if is_inside_tree():
		move_and_slide()

## ─────────────────────────────────────────────────────────────────────────────
## VERIFICACIÓN DE PERMANENCIA EN LA MISMA PLATAFORMA
## ─────────────────────────────────────────────────────────────────────────────
func _esta_vivo_en_misma_plataforma(vivo: Node3D) -> bool:
	if not is_instance_valid(vivo):
		return false

	var pos_vivo = vivo.global_position if vivo.is_inside_tree() else vivo.position
	# Si el vivo se precipitó verticalmente al abismo por debajo de la plataforma
	if pos_vivo.y < (_posicion_origen.y - 3.5):
		return false

	var plat = _plataforma_detectada if is_instance_valid(_plataforma_detectada) else plataforma_asignada
	if not is_instance_valid(plat):
		return true

	# 1. Comprobación geométrica por límites locales de la isla si es IslaFlotante
	if "ancho" in plat and "largo" in plat:
		var pos_local = plat.global_transform.affine_inverse() * pos_vivo
		var half_w = (plat.ancho * 0.5) + 3.0
		var half_l = (plat.largo * 0.5) + 3.0
		if abs(pos_local.x) > half_w or abs(pos_local.z) > half_l:
			return false

	# 2. Comprobación física con raycast hacia el suelo excluyendo al Vivo
	if is_inside_tree() and get_world_3d():
		var espacio = get_world_3d().direct_space_state
		if espacio:
			var origen_rayo = pos_vivo + Vector3.UP * 0.2
			var fin_rayo = pos_vivo + Vector3.DOWN * 5.0
			var query = PhysicsRayQueryParameters3D.create(origen_rayo, fin_rayo, 1) # Capa 1: Geometría e islas
			var exclusiones: Array[RID] = [get_rid()]
			if vivo is CollisionObject3D:
				exclusiones.append((vivo as CollisionObject3D).get_rid())
			query.exclude = exclusiones
			var hit = espacio.intersect_ray(query)
			if hit and not hit.is_empty():
				var col = hit.get("collider")
				if is_instance_valid(col):
					if col == plat:
						return true
					var p: Node = col
					while p != null and p != get_tree().current_scene:
						if p == plat:
							return true
						p = p.get_parent()
					# Si impactó otra isla distinta (por ejemplo IslaMeta)
					if col is IslaFlotante or (p != null and p is IslaFlotante):
						return false
			else:
				# En el aire sobre el abismo sin suelo debajo
				return false

	return true

func _obtener_jugador_vivo() -> Node3D:
	if not is_instance_valid(_jugador_vivo_ref):
		var red_mgr = get_node_or_null("/root/RedManager")
		if is_instance_valid(red_mgr) and "jugador_vivo" in red_mgr and is_instance_valid(red_mgr.jugador_vivo):
			_jugador_vivo_ref = red_mgr.jugador_vivo
		elif is_inside_tree() and get_tree():
			var vivos = get_tree().get_nodes_in_group("vivos")
			if vivos.size() > 0:
				_jugador_vivo_ref = vivos[0] as Node3D
	return _jugador_vivo_ref

func _obtener_fantasma() -> Node3D:
	if not is_instance_valid(_fantasma_ref):
		var red_mgr = get_node_or_null("/root/RedManager")
		if is_instance_valid(red_mgr) and "fantasma" in red_mgr and is_instance_valid(red_mgr.fantasma):
			_fantasma_ref = red_mgr.fantasma
		elif is_inside_tree() and get_tree():
			var fantasmas = get_tree().get_nodes_in_group("fantasmas")
			if fantasmas.size() > 0:
				_fantasma_ref = fantasmas[0] as Node3D
	return _fantasma_ref

## ─────────────────────────────────────────────────────────────────────────────
## MANIFESTACIÓN Y DESVANECIMIENTO
## ─────────────────────────────────────────────────────────────────────────────
## ─────────────────────────────────────────────────────────────────────────────
## SILUETA TRANSPARENTE: estado invisible/translúcido del fantasma para el Vivo
## mientras acecha antes de atacar (reemplaza la esfera de distorsión).
## ─────────────────────────────────────────────────────────────────────────────
const ALFA_SILUETA_AVISO: float = 0.26

var _silueta_aviso: Node3D = null
var _mat_silueta_aviso: ShaderMaterial = null
var _silueta_mano_izq: Node3D = null
var _silueta_mano_der: Node3D = null

func _asegurar_silueta_aviso() -> void:
	if is_instance_valid(_silueta_aviso):
		return
	var fuente: Node3D = modelo_glb if is_instance_valid(modelo_glb) else mesh_cuerpo
	if not is_instance_valid(fuente):
		return
	_silueta_aviso = fuente.duplicate() as Node3D
	_silueta_aviso.name = "SiluetaAviso"

	# Ocultar y purgar rasgos faciales internos para que solo se vea la silueta exterior limpia y transparente
	for rasgo_interno in ["Enemigo_Ojos", "Enemigo_Ojo_L", "Enemigo_Ojo_R", "Enemigo_Boca", "Enemigo_Cejas", "Cubo.013"]:
		var nodo_rasgo := _silueta_aviso.find_child(rasgo_interno, true, false)
		if is_instance_valid(nodo_rasgo):
			nodo_rasgo.visible = false
			nodo_rasgo.queue_free()

	# Material visual de la silueta (borde grueso, menos transparente y centro cristalino)
	var mat_base := load("res://shaders/components/peligros/distorsion_espectral_mat.tres") as ShaderMaterial
	if mat_base:
		_mat_silueta_aviso = mat_base.duplicate() as ShaderMaterial
	else:
		_mat_silueta_aviso = ShaderMaterial.new()
		_mat_silueta_aviso.shader = load("res://shaders/components/peligros/distorsion_espectral.gdshader")

	# Prepass de profundidad: escribe la profundidad de las caras frontales para que
	# las caras traseras y el interior inferior del modelo no se vean a traves del cuerpo
	var mat_prepass_base := load("res://shaders/components/peligros/distorsion_espectral_prepass_mat.tres") as ShaderMaterial
	var mat_prepass: ShaderMaterial = null
	if mat_prepass_base:
		mat_prepass = mat_prepass_base.duplicate() as ShaderMaterial
	else:
		mat_prepass = ShaderMaterial.new()
		mat_prepass.shader = load("res://shaders/components/peligros/distorsion_espectral_prepass.gdshader")
		mat_prepass.render_priority = 0
	mat_prepass.next_pass = _mat_silueta_aviso

	# Material invisible para descartar la boca (surface 1 de Enemigo_Cuerpo) en la silueta
	var mat_invis := StandardMaterial3D.new()
	mat_invis.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_invis.albedo_color = Color(0, 0, 0, 0)
	mat_invis.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_aplicar_material_recursivo(_silueta_aviso, mat_prepass, mat_invis)
	_asignar_capas_recursivo(_silueta_aviso, 2) # Capa 2 (Plano Físico exclusivo para el Vivo)

	var padre_silueta: Node3D = nodo_visual if is_instance_valid(nodo_visual) else self
	padre_silueta.add_child(_silueta_aviso)
	_silueta_aviso.transform = fuente.transform
	_silueta_mano_izq = _silueta_aviso.get_node_or_null("Enemigo_Mano_L") as Node3D
	_silueta_mano_der = _silueta_aviso.get_node_or_null("Enemigo_Mano_R") as Node3D
	_silueta_aviso.visible = false

func _aplicar_material_recursivo(nodo: Node, material: Material, mat_invis: Material = null) -> void:
	if nodo is MeshInstance3D:
		var m_inst := nodo as MeshInstance3D
		var n_lower := m_inst.name.to_lower()
		if "ojo" in n_lower or "ceja" in n_lower or "boca" in n_lower:
			m_inst.visible = false
			m_inst.material_override = mat_invis
			return
		if m_inst.name == "Enemigo_Cuerpo" and m_inst.mesh and m_inst.mesh.get_surface_count() > 1:
			m_inst.material_override = null
			m_inst.set_surface_override_material(0, material)
			m_inst.set_surface_override_material(1, mat_invis if mat_invis != null else material)
		else:
			m_inst.material_override = material
			if m_inst.mesh:
				for s_idx in range(m_inst.mesh.get_surface_count()):
					m_inst.set_surface_override_material(s_idx, material)
	for hijo in nodo.get_children():
		_aplicar_material_recursivo(hijo, material, mat_invis)

func _mostrar_silueta_aviso() -> void:
	_asegurar_silueta_aviso()
	if is_instance_valid(_silueta_aviso):
		if _mat_silueta_aviso:
			_mat_silueta_aviso.set_shader_parameter("factor_visibilidad", 1.0)
		_silueta_aviso.visible = true

func _actualizar_silueta_aviso() -> void:
	if not is_instance_valid(_silueta_aviso) or _mat_silueta_aviso == null:
		return
	var pulso: float = 0.85 + 0.15 * sin(_tiempo_acumulado * 4.5)
	_mat_silueta_aviso.set_shader_parameter("factor_visibilidad", pulso)

func _ocultar_silueta_aviso() -> void:
	if is_instance_valid(_silueta_aviso):
		_silueta_aviso.visible = false

func _manifestar_en_zona() -> void:
	if is_inside_tree():
		global_position = _posicion_origen
	else:
		position = _posicion_origen

	velocity = Vector3.ZERO
	if is_instance_valid(mesh_distorsion):
		mesh_distorsion.visible = false
	if is_instance_valid(colision_cuerpo):
		colision_cuerpo.set_deferred("disabled", false)

	_configurar_capas_iniciales()
	if tiempo_anticipacion_spawn > 0.0:
		var dur_emergencia: float = maxf(tiempo_anticipacion_spawn, 0.75)
		estado_actual = Estado.MANIFESTANDOSE
		_temporizador_manifestacion = dur_emergencia
	else:
		estado_actual = Estado.ACECHO_INVISIBLE

	_establecer_tangibilidad(false, true)
	estado_cambiado.emit(estado_actual)
	enemigo_manifestado.emit()

	_animar_emergencia_grietas()

	# Iniciar generación escalonada de espectros adicionales si cantidad_enemigos > 1
	if not es_clon and cantidad_enemigos > 1:
		_iniciar_secuencia_spawns()

func _animar_emergencia_grietas() -> void:
	if _tween_vertical != null and _tween_vertical.is_valid():
		_tween_vertical.kill()

	if not is_inside_tree() or not is_instance_valid(nodo_visual) or tiempo_anticipacion_spawn <= 0.0:
		if is_instance_valid(nodo_visual):
			nodo_visual.position = _pos_base_visual
			nodo_visual.scale = _escala_base_visual
			nodo_visual.visible = true
		_animando_transicion_vertical = false
		_mostrar_silueta_aviso()
		return

	_animando_transicion_vertical = true

	# 1. Asegurar posición subterránea y escala comprimida ANTES de hacer visible para evitar cualquier destello o pop
	var y_subterraneo: float = _pos_base_visual.y - 1.6
	var escala_inicial: Vector3 = _escala_base_visual * Vector3(0.12, 0.20, 0.12)
	nodo_visual.position = Vector3(_pos_base_visual.x, y_subterraneo, _pos_base_visual.z)
	nodo_visual.scale = escala_inicial
	nodo_visual.visible = true
	_mostrar_silueta_aviso()

	var duracion: float = maxf(tiempo_anticipacion_spawn, 0.75)
	var dur_subida: float = duracion * 0.70
	var dur_asentamiento: float = duracion * 0.30

	# Chispas y brasas espectrales que brotan de las grietas al emerger
	if is_instance_valid(particulas_pasto):
		particulas_pasto.top_level = false
		particulas_pasto.position = Vector3(0, -0.2, 0)
		particulas_pasto.emitting = true

	_intensificar_luces_grietas(true)

	_tween_vertical = create_tween()
	# 1. Movimiento vertical desde la tierra hacia arriba saliendo de las grietas
	_tween_vertical.tween_property(nodo_visual, "position:y", _pos_base_visual.y + 0.10, dur_subida).from(y_subterraneo).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween_vertical.parallel().tween_property(nodo_visual, "scale", _escala_base_visual * Vector3(0.9, 1.25, 0.9), dur_subida).from(escala_inicial).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 2. Asentamiento elástico en su posición y escala de flotación
	_tween_vertical.tween_property(nodo_visual, "position:y", _pos_base_visual.y, dur_asentamiento).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_vertical.parallel().tween_property(nodo_visual, "scale", _escala_base_visual, dur_asentamiento).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_tween_vertical.tween_callback(func():
		_animando_transicion_vertical = false
		if is_instance_valid(nodo_visual):
			nodo_visual.position = _pos_base_visual
			nodo_visual.scale = _escala_base_visual
		_intensificar_luces_grietas(false)
		if estado_actual == Estado.MANIFESTANDOSE:
			estado_actual = Estado.ACECHO_INVISIBLE
			estado_cambiado.emit(estado_actual)
	)

func _iniciar_secuencia_spawns() -> void:
	if _secuencia_spawn_activa:
		return
	_secuencia_spawn_activa = true
	_limpiar_clones()

	for i in range(1, cantidad_enemigos):
		if is_inside_tree() and get_tree():
			await get_tree().create_timer(tiempo_entre_spawns).timeout

		# Comprobar si durante la espera la zona se desactivó, el Vivo murió o el líder fue derrotado
		if not is_inside_tree() or estado_actual == Estado.INACTIVO_OCULTO or estado_actual == Estado.DERROTADO:
			_secuencia_spawn_activa = false
			return

		_spawnear_clon(i)

	_secuencia_spawn_activa = false

func _spawnear_clon(indice: int) -> void:
	var escena = load("res://scenes/components/peligros/enemigo_espectral.tscn")
	if escena == null:
		return

	var clon = escena.instantiate() as EnemigoEspectral
	clon.es_clon = true
	clon.cantidad_enemigos = 1
	clon.activar_solo_en_zona = false # El clon nace directamente despierto
	clon.plataforma_asignada = plataforma_asignada
	clon._plataforma_detectada = _plataforma_detectada
	clon.radio_zona_peligro = radio_zona_peligro
	clon.distancia_ataque = distancia_ataque
	clon.distancia_inicio_ataque = distancia_inicio_ataque
	clon.tiempo_anticipacion_ataque = tiempo_anticipacion_ataque
	clon.tiempo_permanencia_visible = tiempo_permanencia_visible
	clon.velocidad_acecho = velocidad_acecho * (1.0 + (float(indice) * 0.07))
	clon.altura_flotacion = altura_flotacion + (float(indice) * 0.04)
	clon.tiempo_anticipacion_spawn = tiempo_anticipacion_spawn
	clon._lider_ref = self
	clon._indice_clon = indice

	# Offset radial para que emerjan en distintos puntos de la zona contaminada
	var angulo = (float(indice) / float(cantidad_enemigos)) * TAU
	var offset_radial = Vector3(cos(angulo) * 2.2, 0.0, sin(angulo) * 2.2)
	var pos_clon = _posicion_origen + offset_radial
	clon.position = pos_clon
	clon._posicion_origen = pos_clon

	if is_inside_tree() and get_parent() != null:
		get_parent().add_child(clon)
		_clones_activos.append(clon)

		# Si el clon mata al Vivo, notificar al líder para reiniciar la zona
		clon.jugador_eliminado.connect(func(jugador):
			_al_clon_eliminar_jugador(clon, jugador)
		)
		# La señal enemigo_golpeado se conecta pero ya no borra del array aquí;
		# la limpieza la hace _al_ser_derrotado() del propio clon.
		clon.enemigo_golpeado.connect(func(_j): pass)

func _al_clon_eliminar_jugador(_clon: Node, jugador: Node3D) -> void:
	jugador_eliminado.emit(jugador)
	_desvanecer_a_origen(true)

func _limpiar_clones() -> void:
	_secuencia_spawn_activa = false
	for clon in _clones_activos:
		if is_instance_valid(clon):
			clon.queue_free()
	_clones_activos.clear()

## Lógica que ejecuta cada enemigo al ser derrotado individualmente.
## NO limpia a los hermanos: el Vivo debe matar a TODOS para despejar la zona.
func _al_ser_derrotado() -> void:
	if es_clon and is_instance_valid(_lider_ref):
		# Notificar al líder que este clon murió
		_lider_ref._clones_activos.erase(self)
		_lider_ref._verificar_zona_despejada()
	else:
		# El líder fue derrotado
		_lider_derrotado = true
		# Notificar a los clones supervivientes que el líder cayó
		for clon in _clones_activos:
			if is_instance_valid(clon) and clon is EnemigoEspectral:
				(clon as EnemigoEspectral)._lider_derrotado = true
		_verificar_zona_despejada()

## Verifica si TODOS los enemigos de la zona fueron eliminados.
## Solo cuando el líder Y todos los clones están muertos se despeja la zona.
func _verificar_zona_despejada() -> void:
	var clones_vivos: int = 0
	for clon in _clones_activos:
		if is_instance_valid(clon) and clon is EnemigoEspectral:
			var e := clon as EnemigoEspectral
			if e.estado_actual != Estado.DERROTADO:
				clones_vivos += 1
	if _lider_derrotado and clones_vivos == 0:
		# Zona despejada: limpiar efectos visuales de la zona
		if is_instance_valid(particulas_zona_spawn):
			particulas_zona_spawn.emitting = false
		if is_instance_valid(grietas_suelo_spawn):
			grietas_suelo_spawn.visible = false

func _finalizar_desvanecimiento_a_origen() -> void:
	_animando_transicion_vertical = false
	if is_instance_valid(nodo_visual):
		nodo_visual.scale = _escala_base_visual * Vector3(0.01, 0.01, 0.01)
		nodo_visual.position = Vector3(_pos_base_visual.x, _pos_base_visual.y - 1.6, _pos_base_visual.z)
		nodo_visual.visible = false
	if is_instance_valid(mesh_distorsion):
		mesh_distorsion.visible = false
	if is_instance_valid(colision_cuerpo):
		colision_cuerpo.set_deferred("disabled", true)
	if is_instance_valid(particulas_pasto):
		particulas_pasto.emitting = false
		particulas_pasto.top_level = false
		particulas_pasto.position = Vector3(0, -0.2, 0)
	if is_instance_valid(audio_acecho) and audio_acecho.playing:
		audio_acecho.stop()

	_esta_tangible = false
	_temporizador_ataque = 0.0
	_temporizador_permanencia = 0.0
	_fase_anticipacion_terminada = false
	_ocultar_silueta_aviso()

	if is_inside_tree():
		global_position = _posicion_origen
	else:
		position = _posicion_origen

	estado_actual = Estado.INACTIVO_OCULTO
	estado_cambiado.emit(estado_actual)
	enemigo_desvanecido.emit()

	_limpiar_clones()

func _desvanecer_a_origen(animado: bool = true) -> void:
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0

	if not animado or not is_inside_tree() or not is_instance_valid(nodo_visual):
		_finalizar_desvanecimiento_a_origen()
		return

	if _tween_vertical != null and _tween_vertical.is_valid():
		_tween_vertical.kill()

	_animando_transicion_vertical = true
	var y_sumergido: float = _pos_base_visual.y - 1.6

	_tween_vertical = create_tween()
	_tween_vertical.tween_property(nodo_visual, "position:y", y_sumergido, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween_vertical.parallel().tween_property(nodo_visual, "scale", Vector3(0.12, 1.35, 0.12) * _escala_base_visual, 0.35)
	_tween_vertical.tween_callback(func():
		_finalizar_desvanecimiento_a_origen()
	)

func _hundir_en_tierra_y_desvanecer(animado: bool = true) -> void:
	if _tween_vertical != null and _tween_vertical.is_valid():
		_tween_vertical.kill()

	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0

	if not animado or not is_inside_tree() or not is_instance_valid(nodo_visual):
		_finalizar_desvanecimiento_a_origen()
		return

	_animando_transicion_vertical = true

	# Detectar la distancia exacta al suelo debajo del espectro
	var dist_suelo: float = altura_flotacion
	if get_world_3d() != null:
		var espacio = get_world_3d().direct_space_state
		if espacio:
			var p_origen = global_position + Vector3.UP * 0.5
			var p_fin = global_position + Vector3.DOWN * 8.0
			var q = PhysicsRayQueryParameters3D.create(p_origen, p_fin, 1)
			q.exclude = [get_rid()]
			var hit = espacio.intersect_ray(q)
			if hit and not hit.is_empty():
				var hit_pos: Vector3 = hit.get("position")
				dist_suelo = maxf(global_position.y - hit_pos.y, 0.2)

	var suelo_y_local: float = _pos_base_visual.y - dist_suelo
	var y_sumergido: float = suelo_y_local - 1.5

	# Emitir brasas espectrales en la superficie del suelo donde el espectro se hunde
	if is_instance_valid(particulas_pasto):
		particulas_pasto.top_level = true
		particulas_pasto.global_position = Vector3(global_position.x, global_position.y - dist_suelo + 0.04, global_position.z)
		particulas_pasto.emitting = true

	_tween_vertical = create_tween()

	# 1. Breve retroceso / impacto siniestro al conectar el golpe (0.12s)
	_tween_vertical.tween_property(nodo_visual, "position:y", _pos_base_visual.y + 0.10, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween_vertical.parallel().tween_property(nodo_visual, "scale", _escala_base_visual * Vector3(1.15, 0.90, 1.15), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 2. Hundimiento en la tierra: se precipita hacia abajo atravesando el suelo
	_tween_vertical.tween_property(nodo_visual, "position:y", y_sumergido, 0.52).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	# Se estira verticalmente y se estrecha mientras es succionado por la tierra
	_tween_vertical.parallel().tween_property(nodo_visual, "scale", _escala_base_visual * Vector3(0.12, 1.45, 0.12), 0.52).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 3. Al terminar de hundirse en la tierra, ahí sí desaparecer y regresar a origen
	_tween_vertical.tween_callback(func():
		_finalizar_desvanecimiento_a_origen()
	)

## ─────────────────────────────────────────────────────────────────────────────
## VERIFICACIÓN DE CONTACTO CON EL AURA DEL FANTASMA
## ─────────────────────────────────────────────────────────────────────────────
func _verificar_tangibilidad_con_aura(delta: float) -> void:
	var f = _obtener_fantasma()
	var en_contacto = false

	if is_instance_valid(f):
		var aura: Node = null
		if "habilidad_aura" in f and is_instance_valid(f.habilidad_aura):
			aura = f.habilidad_aura
		elif f.has_node("HabilidadAura"):
			aura = f.get_node("HabilidadAura")

		if is_instance_valid(aura) and aura.has_method("esta_activa") and aura.esta_activa():
			var radio_aura = aura.obtener_radio() if aura.has_method("obtener_radio") else 0.0
			var pos_enemigo_3d = global_position if is_inside_tree() else position
			var pos_fantasma_3d = f.global_position if f.is_inside_tree() else f.position
			var pos_enemigo_2d = Vector2(pos_enemigo_3d.x, pos_enemigo_3d.z)
			var pos_fantasma_2d = Vector2(pos_fantasma_3d.x, pos_fantasma_3d.z)
			var distancia_h = pos_enemigo_2d.distance_to(pos_fantasma_2d)
			var diff_y = abs(pos_enemigo_3d.y - pos_fantasma_3d.y)

			if distancia_h <= (radio_aura + radio_contacto_aura) and diff_y <= 3.2:
				en_contacto = true

	if en_contacto:
		_temporizador_gracia_aura = tiempo_gracia_tangible
		if not _esta_tangible:
			_establecer_tangibilidad(true)
	else:
		if _esta_tangible:
			_temporizador_gracia_aura = maxf(_temporizador_gracia_aura - delta, 0.0)
			if _temporizador_gracia_aura <= 0.0:
				_establecer_tangibilidad(false)

func _establecer_tangibilidad(tangible: bool, forzar: bool = false) -> void:
	if _esta_tangible == tangible and not forzar:
		return

	_esta_tangible = tangible

	if tangible:
		estado_actual = Estado.TANGIBLE_VULNERABLE
		_temporizador_ataque = 0.0
		velocity = Vector3.ZERO
		collision_layer = 2 | 4
		collision_mask = 1 | 2

		_establecer_visibilidad_vivo(true)

		if is_instance_valid(_mat_cuerpo) and _mat_cuerpo is ShaderMaterial:
			(_mat_cuerpo as ShaderMaterial).set_shader_parameter("factor_tangible", 1.0)

		enemigo_revelado.emit()
	else:
		if estado_actual != Estado.INACTIVO_OCULTO and estado_actual != Estado.MANIFESTANDOSE:
			estado_actual = Estado.ACECHO_INVISIBLE

		collision_layer = 4
		collision_mask = 1

		_establecer_visibilidad_vivo(false)

		if is_instance_valid(_mat_cuerpo) and _mat_cuerpo is ShaderMaterial:
			(_mat_cuerpo as ShaderMaterial).set_shader_parameter("factor_tangible", 0.0)

		enemigo_ocultado.emit()

	estado_cambiado.emit(estado_actual)

func _establecer_visibilidad_vivo(visible_para_vivo: bool) -> void:
	var mascara: int = (1 | 4) if visible_para_vivo else 4
	if is_instance_valid(modelo_glb):
		_asignar_capas_recursivo(modelo_glb, mascara)
	if is_instance_valid(mesh_cuerpo):
		mesh_cuerpo.layers = mascara
	if is_instance_valid(nodo_manos):
		_asignar_capas_recursivo(nodo_manos, mascara)
	if is_instance_valid(nodo_ojos):
		_asignar_capas_recursivo(nodo_ojos, mascara)
	if is_instance_valid(mesh_distorsion):
		mesh_distorsion.visible = false
	if visible_para_vivo:
		_ocultar_silueta_aviso()
	elif estado_actual != Estado.INACTIVO_OCULTO and estado_actual != Estado.MANIFESTANDOSE:
		_mostrar_silueta_aviso()

## ─────────────────────────────────────────────────────────────────────────────
## COMPORTAMIENTO DE IA: ACECHO, ATURDIMIENTO POR AURA Y ANTICIPACIÓN DE ATAQUE
## ─────────────────────────────────────────────────────────────────────────────
func _actualizar_comportamiento_ia(vivo: Node3D, delta: float) -> void:
	var pos_vivo = vivo.global_position if vivo.is_inside_tree() else vivo.position
	var pos_propia = global_position if is_inside_tree() else position
	var dist_h = Vector2(pos_vivo.x - pos_propia.x, pos_vivo.z - pos_propia.z).length()
	var diff_y = pos_vivo.y - pos_propia.y

	# 1. ESTADO ATURDIDO POR AURA DEL FANTASMA (TANGIBLE_VULNERABLE):
	# El enemigo se queda completamente quieto y visible para que el Vivo lo ataque o salte sobre él.
	if _esta_tangible or estado_actual == Estado.TANGIBLE_VULNERABLE:
		velocity = Vector3.ZERO
		if is_instance_valid(particulas_pasto):
			particulas_pasto.emitting = false
		_verificar_contraataque_vivo(vivo)
		return

	# Orientarse fluidamente hacia el Vivo
	var dir_hacia_vivo = (pos_vivo - pos_propia)
	dir_hacia_vivo.y = 0.0
	if dir_hacia_vivo.length_squared() > 0.01:
		var target_rot_y = atan2(dir_hacia_vivo.x, dir_hacia_vivo.z)
		rotation.y = lerp_angle(rotation.y, target_rot_y, 7.0 * delta)

	# 2. ESTADO ANTICIPANDO ATAQUE / RECUPERACIÓN VULNERABLE:
	# Se detiene, aparece visualmente y asesta su golpe letal al expirar el tiempo de anticipación.
	if estado_actual == Estado.ANTICIPANDO_ATAQUE:
		velocity = Vector3.ZERO
		if _verificar_contraataque_vivo(vivo):
			return

		if not _fase_anticipacion_terminada:
			_temporizador_ataque -= delta
			if is_instance_valid(nodo_visual):
				var pulso_amenaza = 1.0 + 0.14 * sin(_tiempo_acumulado * 28.0)
				nodo_visual.scale = _escala_base_visual * Vector3(pulso_amenaza, 2.0 - pulso_amenaza, pulso_amenaza)

			if _temporizador_ataque <= 0.0:
				_fase_anticipacion_terminada = true
				if is_instance_valid(nodo_visual):
					nodo_visual.scale = _escala_base_visual

				# El espectro lanza su embestida letal. Cubre toda la distancia de inicio de ataque + lunge
				var alcance_golpe: float = maxf(distancia_ataque, distancia_inicio_ataque) + 0.45
				var vivo_saltando_arriba: bool = (vivo is CharacterBody3D and not (vivo as CharacterBody3D).is_on_floor() and diff_y >= 0.25)

				# Si el Vivo NO está en el aire pisándolo y sigue al alcance: ¡GOLPE LETAL!
				if not vivo_saltando_arriba and dist_h <= alcance_golpe and absf(diff_y) <= 1.8:
					_resolver_contacto_con_vivo(vivo)
					return
		else:
			# FASE DE PERMANENCIA VISIBLE TRAS FALLAR EL GOLPE (el Vivo esquivó o saltó):
			# Permanece completamente VISIBLE y VULNERABLE antes de desvanecerse
			_temporizador_permanencia -= delta

			# Si durante la permanencia el Vivo choca con el espectro a pie firme en el suelo: contacto letal
			var esta_en_suelo: bool = (vivo is CharacterBody3D and (vivo as CharacterBody3D).is_on_floor()) if vivo.is_inside_tree() else false
			if esta_en_suelo and dist_h <= distancia_ataque and absf(diff_y) <= 1.2:
				_resolver_contacto_con_vivo(vivo)
				return

			# Si el Vivo sigue en el aire por encima preparándose para pisarlo, extender la permanencia
			if diff_y >= 0.25 and dist_h <= 1.4:
				_temporizador_permanencia = maxf(_temporizador_permanencia, 0.35)

			if _temporizador_permanencia <= 0.0:
				_cancelar_anticipacion_ataque()
		return

	# 3. ESTADO ACECHO INVISIBLE: Persecución estrictamente horizontal
	# Comprobar si el Vivo está saltando o cayendo directamente sobre él durante el acecho
	if _verificar_contraataque_vivo(vivo):
		return

	var dir_desplazamiento = _calcular_direccion_cooperativa(pos_vivo, pos_propia, dir_hacia_vivo)
	dir_desplazamiento.y = 0.0
	if dir_desplazamiento.length_squared() > 0.01:
		dir_desplazamiento = dir_desplazamiento.normalized()

	var vel_objetivo = Vector3(dir_desplazamiento.x * velocidad_acecho, 0.0, dir_desplazamiento.z * velocidad_acecho)

	# La altura se mantiene fija en su cota de flotación (_posicion_origen.y), sin seguir verticalmente al Vivo
	var diff_y_origen = _posicion_origen.y - pos_propia.y
	vel_objetivo.y = diff_y_origen * 5.0

	velocity = velocity.move_toward(vel_objetivo, 7.0 * delta)

	# Efectos sensoriales de acecho para el Vivo
	if is_instance_valid(particulas_pasto):
		particulas_pasto.emitting = true
	if is_instance_valid(audio_acecho) and not audio_acecho.playing:
		audio_acecho.play()

	# ¿Entró en distancia horizontal para anticipar su ataque?
	var umbral_ataque = maxf(distancia_ataque, distancia_inicio_ataque)
	if dist_h <= umbral_ataque and absf(diff_y) <= 2.5:
		if tiempo_anticipacion_ataque > 0.0:
			_iniciar_anticipacion_ataque()
		else:
			_resolver_contacto_con_vivo(vivo)

## Calcula la dirección de movimiento cooperativa para rodear al Vivo cuando hay múltiples enemigos
func _calcular_direccion_cooperativa(pos_vivo: Vector3, pos_propia: Vector3, dir_hacia_vivo: Vector3) -> Vector3:
	if dir_hacia_vivo.length_squared() < 0.01:
		return Vector3.ZERO
	var dir_base := dir_hacia_vivo.normalized()
	
	# Obtener todos los hermanos enemigos activos de la misma zona
	var hermanos: Array[EnemigoEspectral] = []
	var mi_indice: int = _indice_clon
	if es_clon and is_instance_valid(_lider_ref):
		# Agregar al líder si aún vive
		if _lider_ref.estado_actual != Estado.DERROTADO and _lider_ref.estado_actual != Estado.INACTIVO_OCULTO:
			hermanos.append(_lider_ref)
		for clon in _lider_ref._clones_activos:
			if is_instance_valid(clon) and clon != self and clon is EnemigoEspectral:
				var e := clon as EnemigoEspectral
				if e.estado_actual != Estado.DERROTADO and e.estado_actual != Estado.INACTIVO_OCULTO:
					hermanos.append(e)
	elif not es_clon:
		for clon in _clones_activos:
			if is_instance_valid(clon) and clon is EnemigoEspectral:
				var e := clon as EnemigoEspectral
				if e.estado_actual != Estado.DERROTADO and e.estado_actual != Estado.INACTIVO_OCULTO:
					hermanos.append(e)
	
	var total_enemigos: int = hermanos.size() + 1  # +1 por mí mismo
	if total_enemigos <= 1:
		return dir_base
	
	# Offset angular para rodear al Vivo: distribuir uniformemente alrededor del objetivo
	var angulo_separacion: float = TAU / float(total_enemigos)
	var angulo_offset: float = angulo_separacion * float(mi_indice)
	var eje_arriba := Vector3.UP
	var dir_rotada := dir_base.rotated(eje_arriba, angulo_offset)
	
	# Fuerza de repulsión entre enemigos cercanos (distancia mínima 1.8m)
	var DIST_MIN_SEPARACION: float = 1.8
	var fuerza_repulsion := Vector3.ZERO
	for hermano in hermanos:
		var pos_h = hermano.global_position if hermano.is_inside_tree() else hermano.position
		var diff = pos_propia - pos_h
		diff.y = 0.0
		var dist_h = diff.length()
		if dist_h < DIST_MIN_SEPARACION and dist_h > 0.01:
			fuerza_repulsion += diff.normalized() * ((DIST_MIN_SEPARACION - dist_h) / DIST_MIN_SEPARACION)
	
	var dir_final := (dir_rotada + fuerza_repulsion * 0.7).normalized()
	return dir_final

func _iniciar_anticipacion_ataque() -> void:
	estado_actual = Estado.ANTICIPANDO_ATAQUE
	_temporizador_ataque = tiempo_anticipacion_ataque
	_temporizador_permanencia = tiempo_permanencia_visible
	_fase_anticipacion_terminada = false
	velocity = Vector3.ZERO
	# Hacerse tangible en colisión (Capa 2) y visible en Capa 1 para que el Vivo lo vea y pueda atacarlo o pisarlo
	collision_layer = 2 | 4
	collision_mask = 1 | 2
	_establecer_visibilidad_vivo(true)
	estado_cambiado.emit(estado_actual)

func _cancelar_anticipacion_ataque() -> void:
	if _esta_tangible:
		return
	estado_actual = Estado.ACECHO_INVISIBLE
	_temporizador_ataque = 0.0
	_temporizador_permanencia = 0.0
	_fase_anticipacion_terminada = false
	collision_layer = 4
	collision_mask = 1
	if is_instance_valid(nodo_visual):
		nodo_visual.scale = _escala_base_visual
	_establecer_visibilidad_vivo(false)
	estado_cambiado.emit(estado_actual)

## Verifica si el Vivo derrotó al enemigo saltando sobre él (pisotón) o atacándolo (embate/dive/ground pound)
func _verificar_contraataque_vivo(vivo: Node3D) -> bool:
	if not is_instance_valid(vivo) or estado_actual == Estado.DERROTADO or estado_actual == Estado.GOLPE_LETAL:
		return false

	var pos_vivo = vivo.global_position if vivo.is_inside_tree() else vivo.position
	var pos_propia = global_position if is_inside_tree() else position
	var dist_h = Vector2(pos_vivo.x - pos_propia.x, pos_vivo.z - pos_propia.z).length()
	var diff_y = pos_vivo.y - pos_propia.y

	# 1. Contraataque por Embate, Dive o Ground Pound dentro de alcance
	var en_ataque_vivo: bool = (
		("_esta_haciendo_embate" in vivo and vivo.get("_esta_haciendo_embate") == true) or
		("_en_dive" in vivo and vivo.get("_en_dive") == true) or
		("_en_ground_pound" in vivo and vivo.get("_en_ground_pound") == true)
	)
	if en_ataque_vivo and dist_h <= (distancia_inicio_ataque + 0.65) and absf(diff_y) <= 1.8:
		recibir_impacto(vivo)
		return true

	# 2. Contraataque saltando sobre el enemigo (pisotón desde arriba)
	var esta_en_suelo: bool = false
	var vel_y_vivo: float = 0.0
	if vivo is CharacterBody3D:
		var cb := vivo as CharacterBody3D
		esta_en_suelo = cb.is_on_floor() if cb.is_inside_tree() else false
		vel_y_vivo = cb.velocity.y

	# Un pisotón requiere que el Vivo esté en el aire (no en el suelo), cayendo y claramente por encima
	var es_pisoton: bool = (not esta_en_suelo) and (diff_y >= 0.25) and (diff_y <= 2.2) and (vel_y_vivo <= 1.5)
	if dist_h <= 1.35 and es_pisoton:
		if vivo is CharacterBody3D:
			var fuerza_rebote: float = 8.5
			if "FUERZA_SALTO" in vivo:
				fuerza_rebote = float(vivo.get("FUERZA_SALTO")) * 0.9
			(vivo as CharacterBody3D).velocity.y = fuerza_rebote
		recibir_impacto(vivo)
		return true

	return false

## ─────────────────────────────────────────────────────────────────────────────
## CONTACTO LETAL CON EL VIVO
## ─────────────────────────────────────────────────────────────────────────────
func _resolver_contacto_con_vivo(vivo: Node3D) -> void:
	if estado_actual == Estado.GOLPE_LETAL or estado_actual == Estado.DERROTADO:
		return

	# Si el Vivo está atacando (embate/dive/ground pound) o pisándolo desde arriba en este instante, el Vivo gana
	if _verificar_contraataque_vivo(vivo):
		return

	# CONTACTO MORTAL: El Vivo muere al instante
	estado_actual = Estado.GOLPE_LETAL
	estado_cambiado.emit(estado_actual)
	jugador_eliminado.emit(vivo)

	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0

	var vm = get_node_or_null("/root/VibrationManager")
	if is_instance_valid(vm) and vm.has_method("vibrar_dano"):
		vm.vibrar_dano()

	if is_instance_valid(vivo) and vivo.has_method("reaparecer"):
		vivo.reaparecer()

	_hundir_en_tierra_y_desvanecer(true)

## ─────────────────────────────────────────────────────────────────────────────
## CONTRATO DE COMBATE: IMPACTO POR EMBATE DEL VIVO (recibir_impacto)
## ─────────────────────────────────────────────────────────────────────────────
func recibir_impacto(jugador: Node3D) -> void:
	if estado_actual == Estado.DERROTADO:
		return

	if _tween_vertical != null and _tween_vertical.is_valid():
		_tween_vertical.kill()
	_animando_transicion_vertical = false

	estado_actual = Estado.DERROTADO
	estado_cambiado.emit(estado_actual)
	enemigo_golpeado.emit(jugador)

	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0

	if is_instance_valid(particulas_muerte):
		particulas_muerte.restart()
		particulas_muerte.emitting = true

	if is_inside_tree() and is_instance_valid(nodo_visual):
		var tween_derrota = create_tween()
		tween_derrota.tween_property(nodo_visual, "scale", Vector3(1.7, 0.25, 1.7), 0.12).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tween_derrota.tween_property(nodo_visual, "scale", Vector3(0.01, 2.2, 0.01), 0.20)
		tween_derrota.parallel().tween_property(nodo_visual, "position:y", 1.5, 0.20)
		tween_derrota.tween_callback(func():
			_al_ser_derrotado()
			queue_free()
		)
	else:
		_al_ser_derrotado()
		queue_free()

## ─────────────────────────────────────────────────────────────────────────────
## ANIMACIÓN PROCEDURAL DE FLOTACIÓN Y MANOS
## ─────────────────────────────────────────────────────────────────────────────
func _animar_flotacion_y_manos(_delta: float) -> void:
	if not is_instance_valid(nodo_visual) or not nodo_visual.visible:
		return

	if not _animando_transicion_vertical:
		var oscilacion_y = sin(_tiempo_acumulado * 3.0) * 0.08
		nodo_visual.position.y = _pos_base_visual.y + oscilacion_y

	if is_instance_valid(mano_izq) and is_instance_valid(mano_der):
		var aleteo_izq = cos(_tiempo_acumulado * 2.8 + 0.5) * 0.05
		var aleteo_der = sin(_tiempo_acumulado * 2.8) * 0.05
		mano_izq.position.y = aleteo_izq
		mano_der.position.y = aleteo_der
		mano_izq.rotation.z = sin(_tiempo_acumulado * 2.0) * 0.10
		mano_der.rotation.z = -sin(_tiempo_acumulado * 2.0) * 0.10

	if is_instance_valid(glb_mano_izq) and is_instance_valid(glb_mano_der):
		var aleteo_glb_izq = cos(_tiempo_acumulado * 2.8 + 0.5) * 0.10
		var aleteo_glb_der = sin(_tiempo_acumulado * 2.8) * 0.10
		glb_mano_izq.position.y = _pos_base_glb_mano_izq.y + aleteo_glb_izq
		glb_mano_der.position.y = _pos_base_glb_mano_der.y + aleteo_glb_der
		glb_mano_izq.rotation.z = sin(_tiempo_acumulado * 2.0) * 0.10
		glb_mano_der.rotation.z = -sin(_tiempo_acumulado * 2.0) * 0.10
		if is_instance_valid(_silueta_mano_izq) and is_instance_valid(_silueta_mano_der):
			_silueta_mano_izq.position = glb_mano_izq.position
			_silueta_mano_der.position = glb_mano_der.position
			_silueta_mano_izq.rotation = glb_mano_izq.rotation
			_silueta_mano_der.rotation = glb_mano_der.rotation
