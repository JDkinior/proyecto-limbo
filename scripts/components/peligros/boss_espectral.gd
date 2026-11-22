@tool
extends CharacterBody3D
class_name BossEspectral

## ==============================================================================
## JEFE ESPECTRO GUERRERO (PROYECTO LIMBO - FINAL NIVEL 2 / COLISEO)
## - Permanece dormido mostrando su armadura sólida hasta que llegan AMBOS
##   personajes (Vivo y Fantasma).
## - Combate cooperativo estilo Mario Odyssey en 3 fases (3 puntos de vida):
##   * Gira dinámicamente hacia el Fantasma o hacia el Vivo según su patrón.
##   * Lanza tornados espirituales hacia el Fantasma para alejarlo mientras
##     el Vivo intenta escalar las pequeñas islas flotantes.
##   * Al ver al Vivo escalar, gira hacia él y agrieta/destruye la isla en la
##     que salta; al romperse, las islas se regeneran en nuevas posiciones.
##   * Si el Fantasma usa su Aura cerca, congela al jefe (TANGIBLE_VULNERABLE),
##     interrumpe su ataque y permite al Vivo pisarle el copete descubierto.
##   * Fase 2: islas oscilan arriba/abajo, nueva disposición y 2 tornados.
##   * Fase 3: oscilación intensa, 3 tornados e invocación de mini espectros.
## ==============================================================================

signal estado_cambiado(nuevo_estado: int)
signal boss_despertado
signal boss_revelado
signal boss_ocultado
signal boss_danado(vida_restante: int, vida_max: int)
signal boss_derrotado
signal fase_cambiada(nueva_fase: int)
signal tornado_lanzado(tornado: ProyectilTornadoBoss)
signal plataforma_objetivo_rota(plataforma: Node3D)
signal mini_espectro_invocado(minion: Node3D)
signal vivo_golpeado_por_puno(vivo: Node3D)
signal personaje_aplastado_por_puno(personaje: Node3D)
## Señales compatibles con ElementoInteractivoBase (ej. PuertaInteractiva de salida del coliseo)
signal signal_activado
signal signal_desactivado

enum Estado {
	DORMIDO_ARMADURA,        ## Solo armadura sólida en el suelo esperando a Vivo y Fantasma
	DESPERTANDO,             ## Armadura levita y se ensambla; islas se elevan alrededor
	COMBATE_INTANGIBLE,      ## Combate activo: Vivo ve armadura sólida + silueta; Fantasma ve cuerpo completo
	TANGIBLE_VULNERABLE,     ## Congelado por el Aura del Fantasma: visible y pisoteable en la coronilla
	ATURDIDO_GOLPE,          ## Recibió un pisotón (HP > 0): retroceso, sacudida e invulnerabilidad breve
	DERROTADO,               ## 3er golpe recibido: espectro desaparece y la armadura cae al suelo
	PREPARANDO_TORNADO,      ## Gira hacia el Fantasma y concentra viento espiritual en sus manos
	LANZANDO_TORNADO,        ## Proyecta tornados hacia el Fantasma para alejarlo
	APUNTANDO_PLATAFORMA,    ## Gira hacia el Vivo escalando y apunta rayo carmesí a su isla
	ROMPIENDO_PLATAFORMA,    ## Golpea la isla apuntada iniciando su agrietamiento y ruptura
	INVOCANDO_ESPECTROS,     ## Fase 3: ritual para invocar mini espectros en la arena
	PREPARANDO_APLASTAMIENTO,## Eleva el puño sobre el suelo telegrafiando aplastamiento contra el Vivo
	APLASTANDO_SUELO         ## Descarga el puño verticalmente intentando aplastar al objetivo en el suelo
}

const MAT_ESPECTRAL_BASE = preload("res://shaders/components/peligros/enemigo_espectral_mat.tres")
const MAT_DISTORSION_BASE = preload("res://shaders/components/peligros/distorsion_espectral_mat.tres")
const MAT_DISTORSION_PREPASS = preload("res://shaders/components/peligros/distorsion_espectral_prepass_mat.tres")
const MAT_ARMADURA_ROCAS = preload("res://assets/materiales/entorno/m_camino_rocas.tres")
const ESCENA_MINI_ESPECTRO: PackedScene = preload("res://scenes/components/peligros/enemigo_espectral.tscn")

## Alturas locales (en espacio de boss_espectral.glb / boss_armadura.glb sin escalar)
const ALTURA_CIMA_BOSS_LOCAL: float = 0.98
const ALTURA_PIES_VIVO_LOCAL: float = 0.54

## Alturas mínimas locales Y de cada pieza en boss_armadura.glb para apoyarlas exactas sobre el suelo
const ARMADURA_PIEZAS_ORDEN: Array[String] = [
	"Boss_Armadura_Faldilla",
	"Boss_Armadura_Brazal_L",
	"Boss_Armadura_Brazal_R",
	"Boss_Armadura_Mano_L",
	"Boss_Armadura_Mano_R",
	"Boss_Armadura_Casco"
]

const ARMADURA_MIN_Y_LOCAL: Dictionary = {
	"Boss_Armadura_Faldilla": -1.36,
	"Boss_Armadura_Brazal_L": -1.04,
	"Boss_Armadura_Brazal_R": -1.04,
	"Boss_Armadura_Mano_L": -0.3553,
	"Boss_Armadura_Mano_R": -0.3553,
	"Boss_Armadura_Casco": -0.3118
}

## Distribución natural de la armadura reposando en el suelo (offset X, Z y rotación en radianes)
const ARMADURA_SUELO_DESPLAZAMIENTO: Dictionary = {
	"Boss_Armadura_Faldilla": { "xz": Vector2(0.0, -0.10), "rot": Vector3(0.0, 0.06, 0.0), "margen_y": 0.03 },
	"Boss_Armadura_Brazal_L": { "xz": Vector2(-0.22, 0.18), "rot": Vector3(0.0, 0.28, 0.0), "margen_y": 0.04 },
	"Boss_Armadura_Brazal_R": { "xz": Vector2(0.22, 0.16), "rot": Vector3(0.0, -0.26, 0.0), "margen_y": 0.04 },
	"Boss_Armadura_Mano_L": { "xz": Vector2(-1.45, 0.58), "rot": Vector3(0.16, 0.30, 0.08), "margen_y": 0.10 },
	"Boss_Armadura_Mano_R": { "xz": Vector2(1.45, 0.55), "rot": Vector3(0.16, -0.28, -0.08), "margen_y": 0.10 },
	"Boss_Armadura_Casco": { "xz": Vector2(0.04, 0.36), "rot": Vector3(0.12, 0.18, -0.06), "margen_y": 0.18 }
}

@export_group("Identidad y Vida")
@export var nombre_boss: String = "ESPECTRO GUERRERO"
@export_range(1, 10, 1) var vida_maxima: int = 3

@export_group("Escala y Flotación")
## Escala del modelo del jefe (calibrada para que el copete quede ~3 islas arriba).
@export_range(1.0, 4.0, 0.05) var escala_modelo: float = 2.05:
	set(valor):
		escala_modelo = valor
		if is_inside_tree():
			_aplicar_escala_modelos()
## Altura a la que flota el centro del espectro respecto al suelo del coliseo.
@export_range(1.5, 6.0, 0.1) var altura_flotacion: float = 3.05:
	set(valor):
		altura_flotacion = valor
		if is_inside_tree():
			_aplicar_escala_modelos()
## Si es verdadero en el editor, muestra al jefe ya ensamblado y de pie para inspeccionar proporciones.
@export var previsualizar_ensamblado_en_editor: bool = false:
	set(valor):
		previsualizar_ensamblado_en_editor = valor
		if Engine.is_editor_hint() and is_inside_tree():
			_actualizar_preview_editor()

@export_group("Arena del Coliseo y Activación")
## Radio horizontal del coliseo para detectar la llegada de AMBOS personajes (Vivo y Fantasma).
@export_range(4.0, 30.0, 0.5) var radio_activacion_arena: float = 13.5
## Radio máximo que puede desplazarse el jefe respecto al centro para permanecer alcanzable desde las plataformas.
@export_range(0.0, 6.0, 0.1) var radio_patrulla_centro: float = 2.1
## Velocidad de desplazamiento flotante alrededor del centro de la arena.
@export_range(0.2, 5.0, 0.1) var velocidad_desplazamiento: float = 1.65
## Plataformas/islas del coliseo que se elevan al comenzar el combate.
@export var plataformas_combate: Array[Node3D] = []
## Si es verdadero, las plataformas descienden suavemente al derrotar al jefe.
@export var bajar_plataformas_al_derrotar: bool = true
## Offset local respecto al jefe donde se fija el punto de control de ambos jugadores al entrar al coliseo.
@export var offset_punto_control: Vector3 = Vector3(0.0, 0.6, 11.5)
## Radio horizontal máximo seguro dentro del coliseo para que la cámara no choque con pilares, linternas o muros.
@export_range(6.0, 14.0, 0.2) var radio_camara_seguro: float = 11.2

@export_group("Patrones de Combate y Fases")
@export_range(1.0, 12.0, 0.1) var velocidad_giro_combate: float = 5.5
@export_range(0.8, 8.0, 0.1) var cooldown_tornado_base: float = 3.1
@export_range(0.8, 8.0, 0.1) var cooldown_romper_plataforma_base: float = 2.5
@export_range(0.8, 6.0, 0.1) var tiempo_regeneracion_isla_base: float = 2.15
@export_range(1, 3, 1) var max_islas_destruidas_simultaneas: int = 2
@export_range(1, 4, 1) var max_mini_espectros_fase_3: int = 2
@export_range(4.0, 25.0, 0.5) var cooldown_invocacion_fase_3: float = 14.0
@export_range(4.5, 9.5, 0.1) var radio_min_islas: float = 5.4
@export_range(6.0, 10.5, 0.1) var radio_max_islas: float = 6.9
@export var reubicar_islas_al_cambiar_fase: bool = true
@export_range(0.8, 5.0, 0.1) var cooldown_aplastamiento_base: float = 2.6
@export_range(1.0, 3.5, 0.05) var radio_aplastamiento_puno: float = 2.05

@export_group("Tangibilidad, Aura y Pisotón")
## Margen adicional al radio del Aura del Fantasma (compensando el gran tamaño del jefe).
@export_range(0.5, 6.0, 0.1) var radio_contacto_aura: float = 3.2
## Tolerancia vertical para que el Aura desde el suelo o plataformas alcance al jefe flotando.
@export_range(2.0, 10.0, 0.2) var tolerancia_vertical_aura: float = 5.8
## Tiempo de gracia (s) que permanece tangible tras apagarse el Aura para completar el salto desde las plataformas.
@export_range(0.3, 4.0, 0.1) var tiempo_gracia_tangible: float = 1.8
## Radio horizontal sobre la coronilla/copete en el que cuenta el pisotón del Vivo.
@export_range(1.0, 4.5, 0.1) var radio_pisoton_cabeza: float = 2.55
## Duración en segundos de la animación de despertar (levitación de armadura + subida de islas).
@export_range(0.5, 4.0, 0.1) var duracion_despertar: float = 2.1
## Duración en segundos de la furia e invulnerabilidad tras cada pisotón no letal antes de iniciar la nueva fase.
@export_range(0.5, 4.0, 0.1) var tiempo_invulnerabilidad_golpe: float = 2.4
## Radio horizontal de repulsión cuando Vivo o Fantasma se acercan demasiado al jefe intangible.
@export_range(1.5, 6.0, 0.1) var radio_repulsion_cercania: float = 3.6
## Velocidad de lanzamiento horizontal hacia atrás al ser repelido por acercarse demasiado.
@export_range(8.0, 28.0, 0.5) var velocidad_repulsion_cercania: float = 16.5
## Duración (s) durante la cual se sostiene el empuje hacia atrás para lograr un retroceso amplio.
@export_range(0.15, 0.8, 0.05) var duracion_empuje_repulsion: float = 0.42

@export_group("Feedback")
@export_range(0.0, 0.2, 0.01) var duracion_hit_stop: float = 0.05
@export_range(0.0, 0.4, 0.01) var intensidad_shake_camara: float = 0.14

@onready var nodo_visual: Node3D = get_node_or_null("Visual")
@onready var modelo_espectral: Node3D = get_node_or_null("Visual/ModeloEspectral")
@onready var modelo_armadura: Node3D = get_node_or_null("Visual/ModeloArmadura")
@onready var colision_cuerpo: CollisionShape3D = get_node_or_null("CollisionShape3D")
@onready var halo_objetivo: MeshInstance3D = get_node_or_null("Visual/HaloObjetivoCabeza")
@onready var particulas_aura_boss: CPUParticles3D = get_node_or_null("ParticulasZonaBoss")

var estado_actual: Estado = Estado.DORMIDO_ARMADURA
var vida_actual: int = 3

var _posicion_centro_arena: Vector3 = Vector3.ZERO
var _centro_arena_inicializado: bool = false
var _y_suelo_arena: float = 0.0
var _jugador_vivo_ref: Node3D = null
var _fantasma_ref: Node3D = null
var _esta_tangible: bool = false
var _iluminado_por_farol: bool = false
var _temporizador_gracia_aura: float = 0.0
var _temporizador_invulnerable: float = 0.0
var _cooldown_repulsion_vivo: float = 0.0
var _cooldown_repulsion_fantasma: float = 0.0
var _empuje_activo_vivo: Dictionary = {"tiempo": 0.0, "dir": Vector3.ZERO, "fuerza": 0.0}
var _empuje_activo_fantasma: Dictionary = {"tiempo": 0.0, "dir": Vector3.ZERO, "fuerza": 0.0}
var _tiempo_acumulado: float = 0.0
var _en_compresion_pisoton: bool = false
var _animando_transicion: bool = false

## Variables de IA multi-fase, tornados, destrucción lateral, invocaciones y furia
var _fase_aplicada: int = 1
var _temporizador_decision: float = 0.45
var _temporizador_estado_ataque: float = 0.0
var _cooldown_tornado: float = 0.7
var _cooldown_romper_plataforma: float = 0.8
var _cooldown_invocacion: float = 1.5
var _rupturas_consecutivas: int = 0
var _invocacion_emitida_en_estado: bool = false
var _plataforma_objetivo: Node3D = null
var _usar_mano_derecha_golpe: bool = false
var _mano_golpe_actual: int = 0 # -1 = Izquierda, 1 = Derecha, 0 = Ninguna
var _progreso_puno: float = 0.0
var _progreso_barrido: float = 0.0
var _tiempo_estado_ruptura: float = 0.0
var _puno_impacto_ejecutado: bool = false
var _pos_objetivo_puno_mundo: Vector3 = Vector3.ZERO
var _dir_barrido_puno_mundo: Vector3 = Vector3.RIGHT
var _cooldown_aplastamiento: float = 0.0
var _pos_objetivo_aplastamiento_mundo: Vector3 = Vector3.ZERO
var _tiempo_estado_aplastamiento: float = 0.0
var _aplastamiento_impacto_ejecutado: bool = false
var _indicador_aplastamiento: MeshInstance3D = null

var _tiempo_estado_invocacion: float = 0.0
var _duracion_invocacion: float = 1.85
var _plataformas_invocacion_objetivo: Array[Node3D] = []
var _efectos_invocacion_activos: Array[Node3D] = []

var _duracion_enojo_total: float = 2.4
var _tiempo_en_enojo: float = 0.0
var _pulso_shake_enojo_acum: float = 0.0
var _onda_enojo_emitida_1: bool = false
var _onda_enojo_emitida_2: bool = false
var _rebote_frente_activo: bool = false
var _rebote_frente_timer: float = 0.0
var _rebote_frente_dir: Vector3 = Vector3.BACK

var _tornados_activos: Array[ProyectilTornadoBoss] = []
var _victimas_aplastadas_pendientes: Array[Dictionary] = []
var _victimas_desintegradas_pendientes: Array[Dictionary] = []
var _mini_espectros_activos: Array[Node3D] = []
var _cola_regeneracion_islas: Array[Dictionary] = []
var _islas_ordenadas: Array[Node3D] = []
var _angulo_base_espiral: float = 0.35
var _sentido_espiral: float = 1.0

var _particulas_carga: CPUParticles3D = null
var _particulas_congelado: CPUParticles3D = null
var _rayo_ataque: MeshInstance3D = null
var _mat_rayo_ataque: StandardMaterial3D = null

var _mat_cuerpo: ShaderMaterial = null
var _mat_rojo: StandardMaterial3D = null
var _mat_cristal_armadura: StandardMaterial3D = null
var _mat_silueta_aviso: ShaderMaterial = null
var _mat_halo_objetivo: StandardMaterial3D = null
var _silueta_aviso: Node3D = null

var _glb_mano_izq: Node3D = null
var _glb_mano_der: Node3D = null
var _arm_mano_izq: Node3D = null
var _arm_mano_der: Node3D = null
var _silueta_mano_izq: Node3D = null
var _silueta_mano_der: Node3D = null
var _pos_base_mano_izq: Vector3 = Vector3(-1.56, 0.14, 0.08)
var _pos_base_mano_der: Vector3 = Vector3(1.56, 0.14, 0.08)
var _arm_offset_mano_izq: Vector3 = Vector3.ZERO
var _arm_offset_mano_der: Vector3 = Vector3.ZERO
var _escala_base_glb_izq: Vector3 = Vector3.ONE
var _escala_base_glb_der: Vector3 = Vector3.ONE
var _escala_base_arm_izq: Vector3 = Vector3.ONE
var _escala_base_arm_der: Vector3 = Vector3.ONE

## Poses originales ensambladas de cada pieza de armadura: { nombre: {"pos": Vector3, "rot": Vector3} }
var _armadura_poses_ensambladas: Dictionary = {}
var _piezas_armadura: Dictionary = {}

var _tween_principal: Tween = null
var _tween_fade: Tween = null
var _tweens_armadura: Array[Tween] = []
var _visible_vivo_actual: bool = false

var _hud_canvas: CanvasLayer = null
var _hud_raiz: Control = null
var _hud_subtitulo_lbl: Label = null
var _hud_pips: Array[Panel] = []

static var _hit_stop_activo: bool = false

func _ready() -> void:
	vida_actual = vida_maxima
	_posicion_centro_arena = global_position if is_inside_tree() else position
	_centro_arena_inicializado = true
	_y_suelo_arena = _posicion_centro_arena.y
	add_to_group("bosses_espectrales")

	_aplicar_escala_modelos()
	_cachear_nodos_y_materiales()
	if not estado_cambiado.is_connected(_on_estado_cambiado_cristales):
		estado_cambiado.connect(_on_estado_cambiado_cristales)
	_asegurar_silueta_aviso()
	_asegurar_efectos_combate()
	_configurar_capas_iniciales()
	_ordenar_y_conectar_islas()

	if Engine.is_editor_hint():
		_actualizar_preview_editor()
		return

	_ajustar_suelo_inicial.call_deferred()
	call_deferred("_excluir_de_camaras_jugadores")
	_aplicar_estado_dormido_inmediato()

func _exit_tree() -> void:
	_limpiar_entidades_combate(true)
	if is_instance_valid(_hud_canvas):
		_hud_canvas.queue_free()
		_hud_canvas = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for t in _tornados_activos:
			if is_instance_valid(t) and not t.is_inside_tree():
				t.free()
		for m in _mini_espectros_activos:
			if is_instance_valid(m) and not m.is_inside_tree():
				m.free()

## ─────────────────────────────────────────────────────────────────────────────
## CONFIGURACIÓN DE MODELOS, MATERIALES, EFECTOS Y CAPAS VISUALES
## ─────────────────────────────────────────────────────────────────────────────

func _aplicar_escala_modelos() -> void:
	if is_instance_valid(nodo_visual):
		nodo_visual.position = Vector3(0.0, altura_flotacion, 0.0)
		nodo_visual.scale = Vector3.ONE
	if is_instance_valid(modelo_espectral):
		modelo_espectral.scale = Vector3.ONE * escala_modelo
	if is_instance_valid(modelo_armadura):
		modelo_armadura.scale = Vector3.ONE * escala_modelo
	if is_instance_valid(_silueta_aviso):
		_silueta_aviso.scale = Vector3.ONE * escala_modelo
	if is_instance_valid(colision_cuerpo):
		colision_cuerpo.position = Vector3(0.0, altura_flotacion - 0.15 * escala_modelo, 0.0)
		var cyl := colision_cuerpo.shape as CylinderShape3D
		if cyl == null:
			cyl = CylinderShape3D.new()
			colision_cuerpo.shape = cyl
		cyl.radius = 1.12 * escala_modelo
		cyl.height = 2.25 * escala_modelo
	if is_instance_valid(halo_objetivo):
		halo_objetivo.position = Vector3(0.0, (ALTURA_CIMA_BOSS_LOCAL + 0.18) * escala_modelo, 0.0)
		var s_halo := escala_modelo * 0.95
		halo_objetivo.scale = Vector3(s_halo, 1.0, s_halo)

func _cachear_nodos_y_materiales() -> void:
	# 1. Materiales del cuerpo espectral (mismo look que EnemigoEspectral)
	if MAT_ESPECTRAL_BASE is ShaderMaterial:
		_mat_cuerpo = MAT_ESPECTRAL_BASE.duplicate() as ShaderMaterial
		_mat_cuerpo.render_priority = -5
		_mat_cuerpo.set_shader_parameter("fade", 0.0)
		_mat_cuerpo.set_shader_parameter("factor_tangible", 0.0)

	_mat_rojo = StandardMaterial3D.new()
	_mat_rojo.render_priority = -5
	_mat_rojo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_rojo.albedo_color = Color(0.95, 0.02, 0.05, 1.0)
	_mat_rojo.emission_enabled = true
	_mat_rojo.emission = Color(1.0, 0.06, 0.08, 1.0)
	_mat_rojo.emission_energy_multiplier = 4.2
	_mat_rojo.roughness = 0.45
	_mat_rojo.metallic = 0.0

	if is_instance_valid(modelo_espectral):
		_glb_mano_izq = modelo_espectral.get_node_or_null("Boss_Mano_L") as Node3D
		_glb_mano_der = modelo_espectral.get_node_or_null("Boss_Mano_R") as Node3D
		if is_instance_valid(_glb_mano_izq):
			_pos_base_mano_izq = _glb_mano_izq.position
			_escala_base_glb_izq = _glb_mano_izq.scale
		if is_instance_valid(_glb_mano_der):
			_pos_base_mano_der = _glb_mano_der.position
			_escala_base_glb_der = _glb_mano_der.scale

		for nombre_parte in ["Boss_Cuerpo", "Boss_Copete", "Boss_Cejas", "Boss_Mano_L", "Boss_Mano_R"]:
			var m_node := modelo_espectral.get_node_or_null(nombre_parte) as MeshInstance3D
			if is_instance_valid(m_node) and is_instance_valid(_mat_cuerpo):
				m_node.set_surface_override_material(0, _mat_cuerpo)
				# Surface 1 de Boss_Cuerpo es la boca luminosa roja
				if nombre_parte == "Boss_Cuerpo" and m_node.mesh and m_node.mesh.get_surface_count() > 1:
					m_node.set_surface_override_material(1, _mat_rojo)

		var ojos_node := modelo_espectral.get_node_or_null("Boss_Ojos") as MeshInstance3D
		if is_instance_valid(ojos_node):
			ojos_node.set_surface_override_material(0, _mat_rojo)

	# 2. Cachear piezas de la armadura sólida y sus poses ensambladas originales
	_mat_cristal_armadura = StandardMaterial3D.new()
	_mat_cristal_armadura.albedo_color = Color(0.84, 0.07, 0.14, 1.0)
	_mat_cristal_armadura.roughness = 0.12
	_mat_cristal_armadura.metallic = 0.15
	_mat_cristal_armadura.emission_enabled = true
	_mat_cristal_armadura.emission = Color(0.85, 0.05, 0.09, 1.0)
	_mat_cristal_armadura.emission_energy_multiplier = 0.35

	_piezas_armadura.clear()
	_armadura_poses_ensambladas.clear()
	if is_instance_valid(modelo_armadura):
		for nombre_pieza in ARMADURA_PIEZAS_ORDEN:
			var pieza := modelo_armadura.get_node_or_null(nombre_pieza) as Node3D
			if is_instance_valid(pieza):
				_piezas_armadura[nombre_pieza] = pieza
				_armadura_poses_ensambladas[nombre_pieza] = {
					"pos": pieza.position,
					"rot": pieza.rotation
				}
				if pieza is MeshInstance3D:
					var mi := pieza as MeshInstance3D
					if mi.mesh != null and mi.mesh.get_surface_count() > 0:
						if mi.get_active_material(0) == null and MAT_ARMADURA_ROCAS != null:
							mi.material_override = MAT_ARMADURA_ROCAS
						for s_idx in range(mi.mesh.get_surface_count()):
							var mat_s := mi.mesh.surface_get_material(s_idx)
							var es_rubi := (mat_s != null and ("rubi" in mat_s.resource_name.to_lower() or "gema" in mat_s.resource_name.to_lower())) or (mi.mesh.get_surface_count() >= 3 and s_idx == 2)
							if es_rubi:
								mi.set_surface_override_material(s_idx, _mat_cristal_armadura)
		_actualizar_brillo_cristales_armadura(0.0, true)
		_arm_mano_izq = _piezas_armadura.get("Boss_Armadura_Mano_L", null) as Node3D
		_arm_mano_der = _piezas_armadura.get("Boss_Armadura_Mano_R", null) as Node3D
		_arm_offset_mano_izq = Vector3.ZERO
		_arm_offset_mano_der = Vector3.ZERO
		if is_instance_valid(_arm_mano_izq):
			_escala_base_arm_izq = _arm_mano_izq.scale
			if _armadura_poses_ensambladas.has("Boss_Armadura_Mano_L"):
				var diff_izq := (_armadura_poses_ensambladas["Boss_Armadura_Mano_L"]["pos"] as Vector3) - _pos_base_mano_izq
				if diff_izq.length() < 0.65:
					_arm_offset_mano_izq = diff_izq
		if is_instance_valid(_arm_mano_der):
			_escala_base_arm_der = _arm_mano_der.scale
			if _armadura_poses_ensambladas.has("Boss_Armadura_Mano_R"):
				var diff_der := (_armadura_poses_ensambladas["Boss_Armadura_Mano_R"]["pos"] as Vector3) - _pos_base_mano_der
				if diff_der.length() < 0.65:
					_arm_offset_mano_der = diff_der

	# 3. Halo indicador sobre la coronilla al volverse tangible
	if is_instance_valid(halo_objetivo):
		_mat_halo_objetivo = StandardMaterial3D.new()
		_mat_halo_objetivo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_halo_objetivo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_halo_objetivo.albedo_color = Color(0.35, 0.92, 1.0, 0.72)
		_mat_halo_objetivo.emission_enabled = true
		_mat_halo_objetivo.emission = Color(0.3, 0.9, 1.0, 1.0)
		_mat_halo_objetivo.emission_energy_multiplier = 2.4
		halo_objetivo.material_override = _mat_halo_objetivo
		halo_objetivo.layers = 1
		halo_objetivo.visible = false

func _asegurar_efectos_combate() -> void:
	if Engine.is_editor_hint():
		return
	var padre_visual: Node3D = nodo_visual if is_instance_valid(nodo_visual) else self

	# 1. Partículas de carga para tornados / ruptura / invocación
	if not is_instance_valid(_particulas_carga):
		_particulas_carga = padre_visual.get_node_or_null("ParticulasCargaAtaque") as CPUParticles3D
	if not is_instance_valid(_particulas_carga):
		_particulas_carga = CPUParticles3D.new()
		_particulas_carga.name = "ParticulasCargaAtaque"
		_particulas_carga.amount = 18
		_particulas_carga.lifetime = 0.65
		_particulas_carga.emitting = false
		_particulas_carga.layers = 1 | 4
		_particulas_carga.local_coords = true
		_particulas_carga.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		_particulas_carga.emission_ring_axis = Vector3.UP
		_particulas_carga.emission_ring_height = 1.4
		_particulas_carga.emission_ring_radius = 2.9
		_particulas_carga.emission_ring_inner_radius = 1.6
		_particulas_carga.direction = Vector3.UP
		_particulas_carga.spread = 45.0
		_particulas_carga.gravity = Vector3.ZERO
		_particulas_carga.radial_accel_min = -4.5
		_particulas_carga.radial_accel_max = -2.2
		_particulas_carga.tangential_accel_min = 6.0
		_particulas_carga.tangential_accel_max = 10.0

		var malla_carga := SphereMesh.new()
		malla_carga.radius = 0.11
		malla_carga.height = 0.22
		malla_carga.radial_segments = 6
		malla_carga.rings = 3
		var mat_carga := StandardMaterial3D.new()
		mat_carga.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat_carga.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_carga.vertex_color_use_as_albedo = true
		malla_carga.material = mat_carga
		_particulas_carga.mesh = malla_carga
		padre_visual.add_child(_particulas_carga)

	# 2. Partículas cristalinas cuando el Fantasma lo congela con su Aura
	if not is_instance_valid(_particulas_congelado):
		_particulas_congelado = padre_visual.get_node_or_null("ParticulasCongeladoAura") as CPUParticles3D
	if not is_instance_valid(_particulas_congelado):
		_particulas_congelado = CPUParticles3D.new()
		_particulas_congelado.name = "ParticulasCongeladoAura"
		_particulas_congelado.amount = 16
		_particulas_congelado.lifetime = 0.9
		_particulas_congelado.emitting = false
		_particulas_congelado.layers = 1 | 4
		_particulas_congelado.local_coords = true
		_particulas_congelado.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_particulas_congelado.emission_sphere_radius = 2.4
		_particulas_congelado.direction = Vector3.UP
		_particulas_congelado.spread = 35.0
		_particulas_congelado.gravity = Vector3(0.0, 0.8, 0.0)
		_particulas_congelado.initial_velocity_min = 0.4
		_particulas_congelado.initial_velocity_max = 1.2

		var malla_hielo := BoxMesh.new()
		malla_hielo.size = Vector3(0.18, 0.18, 0.18)
		var mat_hielo := StandardMaterial3D.new()
		mat_hielo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat_hielo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_hielo.albedo_color = Color(0.45, 0.95, 1.0, 0.85)
		malla_hielo.material = mat_hielo
		_particulas_congelado.mesh = malla_hielo
		padre_visual.add_child(_particulas_congelado)

	# 3. Haz espectral para telegrafiar qué isla va a romper el jefe
	if not is_instance_valid(_rayo_ataque):
		_rayo_ataque = get_node_or_null("RayoAtaquePlataforma") as MeshInstance3D
	if not is_instance_valid(_rayo_ataque):
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.10
		cyl.bottom_radius = 0.34
		cyl.height = 1.0
		cyl.radial_segments = 10
		cyl.rings = 1

		_mat_rayo_ataque = StandardMaterial3D.new()
		_mat_rayo_ataque.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_rayo_ataque.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_rayo_ataque.albedo_color = Color(1.0, 0.24, 0.14, 0.72)
		_mat_rayo_ataque.emission_enabled = true
		_mat_rayo_ataque.emission = Color(1.0, 0.32, 0.12, 1.0)
		_mat_rayo_ataque.emission_energy_multiplier = 2.8

		_rayo_ataque = MeshInstance3D.new()
		_rayo_ataque.name = "RayoAtaquePlataforma"
		_rayo_ataque.mesh = cyl
		_rayo_ataque.material_override = _mat_rayo_ataque
		_rayo_ataque.layers = 1 | 4
		_rayo_ataque.visible = false
		add_child(_rayo_ataque)

	_asegurar_indicador_aplastamiento()

func _asegurar_indicador_aplastamiento() -> void:
	if Engine.is_editor_hint():
		return
	if not is_instance_valid(_indicador_aplastamiento):
		_indicador_aplastamiento = get_node_or_null("IndicadorAplastamiento") as MeshInstance3D
	if not is_instance_valid(_indicador_aplastamiento):
		var disco := CylinderMesh.new()
		disco.top_radius = radio_aplastamiento_puno
		disco.bottom_radius = radio_aplastamiento_puno
		disco.height = 0.04
		disco.radial_segments = 24
		disco.rings = 1

		var mat_ind := StandardMaterial3D.new()
		mat_ind.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat_ind.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_ind.albedo_color = Color(1.0, 0.30, 0.12, 0.48)
		mat_ind.emission_enabled = true
		mat_ind.emission = Color(1.0, 0.32, 0.10, 1.0)
		mat_ind.emission_energy_multiplier = 2.0

		_indicador_aplastamiento = MeshInstance3D.new()
		_indicador_aplastamiento.name = "IndicadorAplastamiento"
		_indicador_aplastamiento.mesh = disco
		_indicador_aplastamiento.material_override = mat_ind
		_indicador_aplastamiento.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_indicador_aplastamiento.top_level = true
		_indicador_aplastamiento.layers = 1 | 4
		_indicador_aplastamiento.visible = false
		add_child(_indicador_aplastamiento)

func _asegurar_silueta_aviso() -> void:
	if is_instance_valid(_silueta_aviso):
		return
	if not is_instance_valid(modelo_espectral):
		return

	_silueta_aviso = modelo_espectral.duplicate() as Node3D
	_silueta_aviso.name = "SiluetaAviso"

	# Purgar rasgos internos (ojos/cejas) para que el Vivo vea la silueta translúcida limpia
	for rasgo in ["Boss_Ojos", "Boss_Cejas"]:
		var n := _silueta_aviso.get_node_or_null(rasgo)
		if is_instance_valid(n):
			n.visible = false
			n.queue_free()

	if MAT_DISTORSION_BASE is ShaderMaterial:
		_mat_silueta_aviso = MAT_DISTORSION_BASE.duplicate() as ShaderMaterial
	else:
		_mat_silueta_aviso = ShaderMaterial.new()
		_mat_silueta_aviso.shader = load("res://shaders/components/peligros/distorsion_espectral.gdshader")

	var mat_prepass: ShaderMaterial = null
	if MAT_DISTORSION_PREPASS is ShaderMaterial:
		mat_prepass = MAT_DISTORSION_PREPASS.duplicate() as ShaderMaterial
	else:
		mat_prepass = ShaderMaterial.new()
		mat_prepass.shader = load("res://shaders/components/peligros/distorsion_espectral_prepass.gdshader")
		mat_prepass.render_priority = 0
	mat_prepass.next_pass = _mat_silueta_aviso

	var mat_invis := StandardMaterial3D.new()
	mat_invis.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_invis.albedo_color = Color(0, 0, 0, 0)
	mat_invis.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_aplicar_material_silueta_recursivo(_silueta_aviso, mat_prepass, mat_invis)
	_asignar_capas_recursivo(_silueta_aviso, 2) # Capa 2: Exclusiva de la vista del Vivo

	var padre: Node3D = nodo_visual if is_instance_valid(nodo_visual) else self
	padre.add_child(_silueta_aviso)
	_silueta_aviso.transform = modelo_espectral.transform
	_silueta_mano_izq = _silueta_aviso.get_node_or_null("Boss_Mano_L") as Node3D
	_silueta_mano_der = _silueta_aviso.get_node_or_null("Boss_Mano_R") as Node3D
	_silueta_aviso.visible = false

func _aplicar_material_silueta_recursivo(nodo: Node, material: Material, mat_invis: Material) -> void:
	if nodo is MeshInstance3D:
		var mi := nodo as MeshInstance3D
		var n_low := mi.name.to_lower()
		if "ojo" in n_low or "ceja" in n_low or "boca" in n_low:
			mi.visible = false
			mi.material_override = mat_invis
			return
		if mi.name == "Boss_Cuerpo" and mi.mesh and mi.mesh.get_surface_count() > 1:
			mi.material_override = null
			mi.set_surface_override_material(0, material)
			mi.set_surface_override_material(1, mat_invis)
		else:
			mi.material_override = material
			if mi.mesh:
				for s_idx in range(mi.mesh.get_surface_count()):
					mi.set_surface_override_material(s_idx, material)
	for hijo in nodo.get_children():
		_aplicar_material_silueta_recursivo(hijo, material, mat_invis)

func _configurar_capas_iniciales() -> void:
	# La armadura es SIEMPRE sólida y visible en Capa 1 (para Vivo y Fantasma)
	if is_instance_valid(modelo_armadura):
		_asignar_capas_recursivo(modelo_armadura, 1)
	# El cuerpo espectral completo vive inicialmente en Capa 3 (solo Fantasma)
	if is_instance_valid(modelo_espectral):
		_asignar_capas_recursivo(modelo_espectral, 4)
	# La silueta semitransparente vive en Capa 2 (solo Vivo)
	if is_instance_valid(_silueta_aviso):
		_asignar_capas_recursivo(_silueta_aviso, 2)

func _asignar_capas_recursivo(nodo: Node, mascara_capas: int) -> void:
	if nodo is VisualInstance3D:
		(nodo as VisualInstance3D).layers = mascara_capas
	for hijo in nodo.get_children():
		_asignar_capas_recursivo(hijo, mascara_capas)

func _actualizar_preview_editor() -> void:
	if previsualizar_ensamblado_en_editor:
		_colocar_armadura_ensamblada()
		if is_instance_valid(modelo_espectral):
			modelo_espectral.visible = true
			_asignar_capas_recursivo(modelo_espectral, 1 | 4)
		if is_instance_valid(_silueta_aviso):
			_silueta_aviso.visible = false
	else:
		_colocar_armadura_en_suelo()
		if is_instance_valid(modelo_espectral):
			modelo_espectral.visible = false
		if is_instance_valid(_silueta_aviso):
			_silueta_aviso.visible = false

func _ajustar_suelo_inicial() -> void:
	if not is_inside_tree() or get_world_3d() == null:
		return
	var espacio := get_world_3d().direct_space_state
	if espacio == null:
		return
	var origen := _posicion_centro_arena + Vector3.UP * 3.0
	var fin := _posicion_centro_arena + Vector3.DOWN * 8.0
	var q := PhysicsRayQueryParameters3D.create(origen, fin, 1)
	q.exclude = [get_rid()]
	var hit := espacio.intersect_ray(q)
	if hit and not hit.is_empty():
		var hit_pos: Vector3 = hit.get("position")
		_y_suelo_arena = hit_pos.y
		_posicion_centro_arena.y = _y_suelo_arena
		global_position.y = _y_suelo_arena
		if estado_actual == Estado.DORMIDO_ARMADURA:
			_colocar_armadura_en_suelo()

func _excluir_de_camaras_jugadores() -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var rids_a_excluir: Array[RID] = [get_rid()]
	for plat in plataformas_combate:
		if is_instance_valid(plat) and plat is CollisionObject3D:
			rids_a_excluir.append((plat as CollisionObject3D).get_rid())
	var padre := get_parent()
	if is_instance_valid(padre):
		var col_coliseo := padre.find_child("ColisionesColiseo", true, false)
		if is_instance_valid(col_coliseo) and col_coliseo is CollisionObject3D:
			rids_a_excluir.append((col_coliseo as CollisionObject3D).get_rid())

	for grupo in ["jugadores", "fantasmas"]:
		for n in get_tree().get_nodes_in_group(grupo):
			if is_instance_valid(n) and n.has_method("obtener_spring_arm"):
				var arm: SpringArm3D = n.obtener_spring_arm()
				if is_instance_valid(arm):
					for r in rids_a_excluir:
						arm.add_excluded_object(r)

## ─────────────────────────────────────────────────────────────────────────────
## POSES DE LA ARMADURA (SUELO vs ENSAMBLADA)
## ─────────────────────────────────────────────────────────────────────────────

func _calcular_pose_suelo_pieza(nombre_pieza: String, y_suelo_relativo_al_boss: float = 0.0) -> Dictionary:
	var vis_y: float = nodo_visual.position.y if is_instance_valid(nodo_visual) else altura_flotacion
	var esc: float = maxf(escala_modelo, 0.1)
	var y_suelo_local: float = (y_suelo_relativo_al_boss - vis_y) / esc
	var min_y: float = float(ARMADURA_MIN_Y_LOCAL.get(nombre_pieza, -0.5))
	var cfg: Dictionary = ARMADURA_SUELO_DESPLAZAMIENTO.get(nombre_pieza, {
		"xz": Vector2.ZERO,
		"rot": Vector3.ZERO,
		"margen_y": 0.05
	})
	var xz: Vector2 = cfg.get("xz", Vector2.ZERO)
	var rot: Vector3 = cfg.get("rot", Vector3.ZERO)
	var margen: float = float(cfg.get("margen_y", 0.05))
	return {
		"pos": Vector3(xz.x, y_suelo_local - min_y + margen, xz.y),
		"rot": rot
	}

func _colocar_armadura_en_suelo(y_suelo_relativo: float = 0.0) -> void:
	for nombre_pieza in ARMADURA_PIEZAS_ORDEN:
		var pieza := _piezas_armadura.get(nombre_pieza, null) as Node3D
		if not is_instance_valid(pieza):
			continue
		var pose := _calcular_pose_suelo_pieza(nombre_pieza, y_suelo_relativo)
		pieza.position = pose["pos"]
		pieza.rotation = pose["rot"]
		pieza.visible = true

func _colocar_armadura_ensamblada() -> void:
	for nombre_pieza in ARMADURA_PIEZAS_ORDEN:
		var pieza := _piezas_armadura.get(nombre_pieza, null) as Node3D
		if not is_instance_valid(pieza):
			continue
		var pose: Dictionary = _armadura_poses_ensambladas.get(nombre_pieza, {"pos": Vector3.ZERO, "rot": Vector3.ZERO})
		pieza.position = pose["pos"]
		pieza.rotation = pose["rot"]
		pieza.visible = true

func _aplicar_estado_dormido_inmediato() -> void:
	_limpiar_entidades_combate(true)
	estado_actual = Estado.DORMIDO_ARMADURA
	vida_actual = vida_maxima
	_fase_aplicada = 1
	_esta_tangible = false
	_visible_vivo_actual = false
	_animando_transicion = false
	_en_compresion_pisoton = false
	_temporizador_decision = 0.45
	_temporizador_estado_ataque = 0.0
	_cooldown_tornado = 0.7
	_cooldown_romper_plataforma = 0.8
	_cooldown_invocacion = 1.5
	_rupturas_consecutivas = 0
	_invocacion_emitida_en_estado = false
	_plataforma_objetivo = null
	_usar_mano_derecha_golpe = false
	_mano_golpe_actual = 0
	_progreso_puno = 0.0
	_progreso_barrido = 0.0
	_tiempo_estado_ruptura = 0.0
	_puno_impacto_ejecutado = false
	_pos_objetivo_puno_mundo = Vector3.ZERO
	_dir_barrido_puno_mundo = Vector3.RIGHT
	_cooldown_repulsion_vivo = 0.0
	_cooldown_repulsion_fantasma = 0.0
	_empuje_activo_vivo = {"tiempo": 0.0, "dir": Vector3.ZERO, "fuerza": 0.0}
	_empuje_activo_fantasma = {"tiempo": 0.0, "dir": Vector3.ZERO, "fuerza": 0.0}
	_tiempo_estado_invocacion = 0.0
	_plataformas_invocacion_objetivo.clear()
	_tiempo_en_enojo = 0.0
	_pulso_shake_enojo_acum = 0.0
	_onda_enojo_emitida_1 = false
	_onda_enojo_emitida_2 = false
	_rebote_frente_activo = false
	_rebote_frente_timer = 0.0
	_restaurar_escala_y_rotacion_manos()
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	if is_instance_valid(colision_cuerpo):
		if is_inside_tree():
			colision_cuerpo.set_deferred("disabled", true)
		else:
			colision_cuerpo.disabled = true

	if is_instance_valid(nodo_visual):
		nodo_visual.position = Vector3(0.0, altura_flotacion, 0.0)
		nodo_visual.rotation = Vector3.ZERO
		nodo_visual.scale = Vector3.ONE
		nodo_visual.visible = true
	if is_instance_valid(modelo_armadura):
		modelo_armadura.visible = true
		_asignar_capas_recursivo(modelo_armadura, 1)
	_colocar_armadura_en_suelo()

	if is_instance_valid(modelo_espectral):
		modelo_espectral.visible = false
		_asignar_capas_recursivo(modelo_espectral, 4)
	if is_instance_valid(_silueta_aviso):
		_silueta_aviso.visible = false
		_asignar_capas_recursivo(_silueta_aviso, 2)
	if is_instance_valid(halo_objetivo):
		halo_objetivo.visible = false
	if is_instance_valid(particulas_aura_boss):
		particulas_aura_boss.emitting = false
	if is_instance_valid(_particulas_carga):
		_particulas_carga.emitting = false
	if is_instance_valid(_particulas_congelado):
		_particulas_congelado.emitting = false
	if is_instance_valid(_rayo_ataque):
		_rayo_ataque.visible = false

## ─────────────────────────────────────────────────────────────────────────────
## UTILIDADES DE ESTADO Y FASE
## ─────────────────────────────────────────────────────────────────────────────

func obtener_fase_actual() -> int:
	return clampi(1 + (vida_maxima - vida_actual), 1, 3)

func es_estado_combate_intangible() -> bool:
	return estado_actual in [
		Estado.COMBATE_INTANGIBLE,
		Estado.PREPARANDO_TORNADO,
		Estado.LANZANDO_TORNADO,
		Estado.APUNTANDO_PLATAFORMA,
		Estado.ROMPIENDO_PLATAFORMA,
		Estado.INVOCANDO_ESPECTROS,
		Estado.PREPARANDO_APLASTAMIENTO,
		Estado.APLASTANDO_SUELO
	]

func _escala_velocidad_fase() -> float:
	match obtener_fase_actual():
		2: return 1.24
		3: return 1.48
		_: return 1.0

func _obtener_tiempo_regeneracion_fase() -> float:
	match obtener_fase_actual():
		2: return maxf(tiempo_regeneracion_isla_base - 0.15, 0.9)
		3: return maxf(tiempo_regeneracion_isla_base - 0.40, 0.8)
		_: return tiempo_regeneracion_isla_base

## ─────────────────────────────────────────────────────────────────────────────
## CICLO PRINCIPAL DE FÍSICA E IA DEL JEFE (MARIO ODYSSEY STYLE)
## ─────────────────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	procesar_ciclo_boss(delta)

func procesar_ciclo_boss(delta: float) -> void:
	if estado_actual == Estado.DERROTADO or _en_compresion_pisoton:
		return

	_tiempo_acumulado += delta
	if _cooldown_repulsion_vivo > 0.0:
		_cooldown_repulsion_vivo = maxf(_cooldown_repulsion_vivo - delta, 0.0)
	if _cooldown_repulsion_fantasma > 0.0:
		_cooldown_repulsion_fantasma = maxf(_cooldown_repulsion_fantasma - delta, 0.0)

	# 1. DORMIDO: Esperar a que AMBOS personajes (Vivo y Fantasma) lleguen al coliseo
	if estado_actual == Estado.DORMIDO_ARMADURA:
		if _estan_ambos_personajes_en_coliseo():
			iniciar_despertar()
		return

	# 2. DESPERTANDO: La animación de levitación de armadura y subida de islas gobierna el estado
	if estado_actual == Estado.DESPERTANDO:
		return

	# Mantener regeneración de islas rotas activa incluso mientras el jefe está aturdido o congelado
	_actualizar_regeneracion_islas(delta)
	_actualizar_animaciones_muerte_personajes(delta)
	_limpiar_referencias_combate_invalidas()

	var vivo := _obtener_jugador_vivo()
	var fantasma := _obtener_fantasma()
	_actualizar_vuelo_rebote_vivo(vivo, delta)
	_actualizar_empujes_repulsion_activos(vivo, fantasma, delta)

	# 3. ATURDIDO TRAS GOLPE: Enojo dramático y temblor antes de activar la nueva fase
	if estado_actual == Estado.ATURDIDO_GOLPE:
		_temporizador_invulnerable = maxf(_temporizador_invulnerable - delta, 0.0)
		_tiempo_en_enojo += delta
		var p_enojo := clampf(_tiempo_en_enojo / maxf(_duracion_enojo_total, 0.01), 0.0, 1.0)
		if is_instance_valid(vivo):
			var pos_v := vivo.global_position if vivo.is_inside_tree() else vivo.position
			_rotar_hacia_punto(pos_v, velocidad_giro_combate * 2.2, delta)
		_procesar_animacion_enojo(p_enojo, vivo, fantasma, delta)
		_animar_flotacion_y_manos(delta)
		if _temporizador_invulnerable <= 0.0:
			_finalizar_animacion_enojo()
			estado_actual = Estado.COMBATE_INTANGIBLE
			_establecer_tangibilidad(false, true)
			_actualizar_fase_si_corresponde(is_inside_tree())
			_temporizador_decision = 0.25
		return

	# 4. COMBATE ACTIVO (INTANGIBLE / PATRONES DE ATAQUE / TANGIBLE CONGELADO)
	_cooldown_tornado = maxf(_cooldown_tornado - delta, 0.0)
	_cooldown_romper_plataforma = maxf(_cooldown_romper_plataforma - delta, 0.0)
	_cooldown_invocacion = maxf(_cooldown_invocacion - delta, 0.0)
	_cooldown_aplastamiento = maxf(_cooldown_aplastamiento - delta, 0.0)

	_animar_flotacion_y_manos(delta)
	_verificar_tangibilidad_con_aura(delta)

	if estado_actual == Estado.TANGIBLE_VULNERABLE:
		velocity = Vector3.ZERO
		_actualizar_halo_objetivo()
		if is_instance_valid(vivo):
			_verificar_pisoton_vivo(vivo)
		return

	# Combate intangible y ejecución de patrones
	_actualizar_silueta_aviso()
	_verificar_repulsion_cercania(vivo, fantasma)

	match estado_actual:
		Estado.COMBATE_INTANGIBLE:
			_procesar_estado_combate_intangible(vivo, fantasma, delta)
		Estado.PREPARANDO_TORNADO:
			_procesar_preparando_tornado(fantasma, delta)
		Estado.LANZANDO_TORNADO:
			_procesar_lanzando_tornado(fantasma, delta)
		Estado.APUNTANDO_PLATAFORMA:
			_procesar_apuntando_plataforma(delta)
		Estado.ROMPIENDO_PLATAFORMA:
			_procesar_rompiendo_plataforma(vivo, delta)
		Estado.INVOCANDO_ESPECTROS:
			_procesar_invocando_espectros(delta)
		Estado.PREPARANDO_APLASTAMIENTO:
			_procesar_preparando_aplastamiento(vivo, delta)
		Estado.APLASTANDO_SUELO:
			_procesar_aplastando_suelo(vivo, fantasma, delta)

	if is_inside_tree() and es_estado_combate_intangible():
		move_and_slide()
		global_position.y = _y_suelo_arena

func _rotar_hacia_punto(punto_objetivo: Vector3, velocidad_giro: float, delta: float) -> void:
	var pos_propia := global_position if is_inside_tree() else position
	var dir := punto_objetivo - pos_propia
	dir.y = 0.0
	if dir.length_squared() > 0.004:
		var ang_objetivo := atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, ang_objetivo, clampf(velocidad_giro * delta, 0.0, 1.0))

func _procesar_estado_combate_intangible(vivo: Node3D, fantasma: Node3D, delta: float) -> void:
	_actualizar_movimiento_combate(vivo, fantasma, delta)

	_temporizador_decision = maxf(_temporizador_decision - delta, 0.0)
	if _temporizador_decision > 0.0:
		return

	var fase := obtener_fase_actual()

	# 1. En Fase 3, priorizar invocación de mini espectros si queda cupo y cooldown listo
	if fase >= 3 and _contar_mini_espectros_vivos() < max_mini_espectros_fase_3 and _cooldown_invocacion <= 0.0:
		_iniciar_invocacion_espectros()
		return

	# 2. Si el Vivo está subiendo o saltando sobre una isla flotante -> girar hacia él y apuntar para romperla
	var plat_vivo := _detectar_plataforma_ocupada_por_vivo(vivo)
	if is_instance_valid(plat_vivo) and plat_vivo.esta_disponible() and _cooldown_romper_plataforma <= 0.0 and _contar_islas_destruidas() < max_islas_destruidas_simultaneas and _rupturas_consecutivas < 2:
		_iniciar_apuntar_plataforma(plat_vivo)
		return

	# 3. Si el Fantasma está en el coliseo y el tornado está listo -> girar hacia el Fantasma y preparar tornado
	if is_instance_valid(fantasma) and _cooldown_tornado <= 0.0:
		_iniciar_preparar_tornado()
		return

	# 4. Si el Vivo está en el suelo (sin plataforma) -> girar hacia él e intentar aplastarlo con el puño desde arriba
	if is_instance_valid(vivo) and not is_instance_valid(plat_vivo) and _cooldown_aplastamiento <= 0.0:
		var pos_v_suelo := vivo.global_position if vivo.is_inside_tree() else vivo.position
		if pos_v_suelo.y <= (_y_suelo_arena + 1.1):
			_iniciar_preparar_aplastamiento(vivo)
			return

	# 5. Respaldo: si ya rompió o espera tornados/aplastamiento, buscar isla activa cercana al Vivo elevado
	var plat_objetivo := plat_vivo
	if not is_instance_valid(plat_objetivo) and is_instance_valid(vivo):
		var pos_v := vivo.global_position if vivo.is_inside_tree() else vivo.position
		if pos_v.y > (_y_suelo_arena + 1.1):
			plat_objetivo = _obtener_isla_activa_mas_cercana(pos_v)

	if is_instance_valid(plat_objetivo) and plat_objetivo.esta_disponible() and _cooldown_romper_plataforma <= 0.0 and _contar_islas_destruidas() < max_islas_destruidas_simultaneas:
		_iniciar_apuntar_plataforma(plat_objetivo)
		return

	# Esperar brevemente reevaluando patrulla
	_temporizador_decision = 0.25

func _iniciar_preparar_tornado() -> void:
	var fase := obtener_fase_actual()
	estado_actual = Estado.PREPARANDO_TORNADO
	_temporizador_estado_ataque = 0.85 if fase == 1 else (0.70 if fase == 2 else 0.56)
	_plataforma_objetivo = null
	_configurar_particulas_carga(true, Color(0.32, 0.86, 1.0, 0.92))
	if is_instance_valid(_rayo_ataque):
		_rayo_ataque.visible = false
	estado_cambiado.emit(estado_actual)

func _procesar_preparando_tornado(fantasma: Node3D, delta: float) -> void:
	velocity = velocity.move_toward(Vector3.ZERO, 6.0 * delta)
	if is_instance_valid(fantasma):
		var pos_f := fantasma.global_position if fantasma.is_inside_tree() else fantasma.position
		_rotar_hacia_punto(pos_f, velocidad_giro_combate * 1.5, delta)

	_temporizador_estado_ataque -= delta
	if _temporizador_estado_ataque <= 0.0:
		_lanzar_rafaga_tornados(fantasma)

func _lanzar_rafaga_tornados(fantasma: Node3D) -> void:
	estado_actual = Estado.LANZANDO_TORNADO
	_temporizador_estado_ataque = 0.48
	_rupturas_consecutivas = 0

	var fase := obtener_fase_actual()
	match fase:
		1: _cooldown_tornado = cooldown_tornado_base
		2: _cooldown_tornado = maxf(cooldown_tornado_base - 0.7, 1.2)
		_: _cooldown_tornado = maxf(cooldown_tornado_base - 1.25, 1.0)

	_configurar_particulas_carga(false, Color.CYAN)

	var pos_boss := global_position if is_inside_tree() else position
	var dir_base := Vector3.BACK
	if is_instance_valid(fantasma):
		var pos_f := fantasma.global_position if fantasma.is_inside_tree() else fantasma.position
		var d := Vector3(pos_f.x - pos_boss.x, 0.0, pos_f.z - pos_boss.z)
		if d.length_squared() > 0.01:
			dir_base = d.normalized()
	else:
		dir_base = Vector3(sin(rotation.y), 0.0, cos(rotation.y)).normalized()

	var lateral := dir_base.rotated(Vector3.UP, PI * 0.5).normalized()
	var configs_tiro: Array[Dictionary] = [{"ang": 0.0, "lat": 0.0}]
	var vel_tornado := 8.6
	if fase == 2:
		# Separación lateral y angular amplia para dejar un corredor central seguro al Fantasma
		configs_tiro = [{"ang": -0.42, "lat": -1.15}, {"ang": 0.42, "lat": 1.15}]
		vel_tornado = 10.0
	elif fase >= 3:
		configs_tiro = [{"ang": -0.52, "lat": -1.25}, {"ang": 0.0, "lat": 0.0}, {"ang": 0.52, "lat": 1.25}]
		vel_tornado = 11.4

	for cfg in configs_tiro:
		var ang_offset := float(cfg["ang"])
		var desplazamiento_lat := float(cfg["lat"])
		var dir_tiro := dir_base.rotated(Vector3.UP, ang_offset).normalized()
		var pos_spawn := pos_boss + dir_tiro * 1.85 + lateral * desplazamiento_lat
		_instanciar_tornado(pos_spawn, dir_tiro, vel_tornado, fantasma)

	if is_inside_tree():
		_crear_rafaga_particulas(pos_boss + Vector3(0.0, altura_flotacion * 0.7, 0.0) + dir_base * 1.6, Color(0.35, 0.88, 1.0), 14, 2.2, 4.8, 0.4, 1.1)

	estado_cambiado.emit(estado_actual)

func _instanciar_tornado(pos_spawn: Vector3, dir_tiro: Vector3, vel_tornado: float, fantasma: Node3D) -> ProyectilTornadoBoss:
	var tornado := ProyectilTornadoBoss.new()
	tornado.direccion = dir_tiro
	tornado.velocidad = vel_tornado
	tornado.tiempo_vida = 2.8
	tornado.centro_arena = _posicion_centro_arena
	tornado.objetivo_fantasma = fantasma

	var pos_exacta := Vector3(pos_spawn.x, _y_suelo_arena, pos_spawn.z)
	if is_inside_tree() and get_parent() != null:
		get_parent().add_child(tornado)
		tornado.global_position = pos_exacta
	else:
		tornado.position = pos_exacta
		tornado._ready()

	_tornados_activos.append(tornado)
	tornado_lanzado.emit(tornado)
	return tornado

func _procesar_lanzando_tornado(fantasma: Node3D, delta: float) -> void:
	velocity = velocity.move_toward(Vector3.ZERO, 8.0 * delta)
	if is_instance_valid(fantasma):
		var pos_f := fantasma.global_position if fantasma.is_inside_tree() else fantasma.position
		_rotar_hacia_punto(pos_f, velocidad_giro_combate, delta)

	_temporizador_estado_ataque -= delta
	if _temporizador_estado_ataque <= 0.0:
		var fase := obtener_fase_actual()
		estado_actual = Estado.COMBATE_INTANGIBLE
		_temporizador_decision = 0.65 if fase == 1 else (0.48 if fase == 2 else 0.35)
		estado_cambiado.emit(estado_actual)

func _iniciar_apuntar_plataforma(plataforma: Node3D) -> void:
	if not is_instance_valid(plataforma):
		return
	var fase := obtener_fase_actual()
	_plataforma_objetivo = plataforma
	_usar_mano_derecha_golpe = not _usar_mano_derecha_golpe
	_mano_golpe_actual = 1 if _usar_mano_derecha_golpe else -1
	_progreso_puno = 0.0
	_progreso_barrido = 0.0
	_tiempo_estado_ruptura = 0.0
	_puno_impacto_ejecutado = false
	var pos_plat := _obtener_pos_isla_mundo(plataforma)
	_pos_objetivo_puno_mundo = pos_plat + Vector3(0.0, 0.05, 0.0)

	var pos_boss := global_position if is_inside_tree() else position
	var dir_h := Vector3(pos_plat.x - pos_boss.x, 0.0, pos_plat.z - pos_boss.z)
	if dir_h.length_squared() < 0.01:
		dir_h = Vector3.FORWARD
	else:
		dir_h = dir_h.normalized()
	var right_h := dir_h.cross(Vector3.UP).normalized()
	# Puño derecho (-dir de su costado derecho -> barre hacia adentro/izquierda); puño izquierdo barre hacia derecha
	_dir_barrido_puno_mundo = -right_h if _mano_golpe_actual > 0 else right_h

	if _plataforma_objetivo.has_method("marcar_objetivo_boss"):
		_plataforma_objetivo.marcar_objetivo_boss(true)

	estado_actual = Estado.APUNTANDO_PLATAFORMA
	_temporizador_estado_ataque = 0.65 if fase == 1 else (0.52 if fase == 2 else 0.42)
	_configurar_particulas_carga(true, Color(1.0, 0.34, 0.14, 0.95))
	if is_instance_valid(_rayo_ataque):
		_rayo_ataque.visible = false
	estado_cambiado.emit(estado_actual)

func _procesar_apuntando_plataforma(delta: float) -> void:
	velocity = velocity.move_toward(Vector3.ZERO, 6.0 * delta)
	if not is_instance_valid(_plataforma_objetivo) or (_plataforma_objetivo.has_method("esta_disponible") and not _plataforma_objetivo.esta_disponible()):
		_cancelar_ataque_activo(false)
		estado_actual = Estado.COMBATE_INTANGIBLE
		_temporizador_decision = 0.25
		estado_cambiado.emit(estado_actual)
		return

	var pos_plat := _obtener_pos_isla_mundo(_plataforma_objetivo)
	_pos_objetivo_puno_mundo = pos_plat + Vector3(0.0, 0.05, 0.0)
	_rotar_hacia_punto(pos_plat, velocidad_giro_combate * 1.75, delta)

	_temporizador_estado_ataque -= delta
	if _temporizador_estado_ataque <= 0.0:
		_lanzar_puno_a_plataforma()

func _lanzar_puno_a_plataforma() -> void:
	estado_actual = Estado.ROMPIENDO_PLATAFORMA
	_temporizador_estado_ataque = 0.74
	_tiempo_estado_ruptura = 0.0
	_progreso_puno = 0.0
	_progreso_barrido = 0.0
	_puno_impacto_ejecutado = false
	_rupturas_consecutivas += 1
	_configurar_particulas_carga(false, Color.RED)
	if is_instance_valid(_rayo_ataque):
		_rayo_ataque.visible = false
	if is_inside_tree() and is_instance_valid(_particulas_carga):
		_particulas_carga.position = Vector3.ZERO

	var fase := obtener_fase_actual()
	match fase:
		1: _cooldown_romper_plataforma = cooldown_romper_plataforma_base
		2: _cooldown_romper_plataforma = maxf(cooldown_romper_plataforma_base - 0.55, 1.0)
		_: _cooldown_romper_plataforma = maxf(cooldown_romper_plataforma_base - 1.05, 0.85)

	estado_cambiado.emit(estado_actual)

func _ejecutar_impacto_puno_en_isla() -> void:
	if is_instance_valid(_plataforma_objetivo):
		var plat_rota := _plataforma_objetivo
		var pos_plat := _obtener_pos_isla_mundo(plat_rota)
		_pos_objetivo_puno_mundo = pos_plat + Vector3(0.0, 0.05, 0.0)

		var vivo_impacto := _obtener_jugador_vivo()
		var vivo_en_plat_golpeada: bool = false
		if is_instance_valid(vivo_impacto):
			var en_plat_objetivo := (_detectar_plataforma_ocupada_por_vivo(vivo_impacto) == plat_rota)
			var pos_v := vivo_impacto.global_position if vivo_impacto.is_inside_tree() else vivo_impacto.position
			var dist_v_xz := Vector2(pos_v.x - pos_plat.x, pos_v.z - pos_plat.z).length()
			var cerca_plat := dist_v_xz <= 2.2 and pos_v.y >= (pos_plat.y - 0.6) and pos_v.y <= (pos_plat.y + 2.4)
			vivo_en_plat_golpeada = en_plat_objetivo or cerca_plat

		if plat_rota.has_method("destruir_inmediatamente"):
			plat_rota.destruir_inmediatamente(_dir_barrido_puno_mundo)
		elif plat_rota.has_method("iniciar_ruptura"):
			plat_rota.iniciar_ruptura(0.01)
		plataforma_objetivo_rota.emit(plat_rota)

		if is_inside_tree():
			_crear_rafaga_particulas(pos_plat + Vector3.UP * 0.15, Color(1.0, 0.48, 0.16), 24, 2.5, 6.0, 0.6, 1.25)
			_sacudir_camara(vivo_impacto, intensidad_shake_camara * 0.85)

		if vivo_en_plat_golpeada and is_instance_valid(vivo_impacto):
			var pos_fx_v := vivo_impacto.global_position if vivo_impacto.is_inside_tree() else vivo_impacto.position
			if is_inside_tree():
				_crear_rafaga_particulas(pos_fx_v + Vector3.UP * 0.4, Color(1.0, 0.25, 0.12), 26, 2.4, 5.8, 0.75, 1.25)
				_crear_rafaga_particulas(pos_fx_v + Vector3.UP * 0.8, Color(1.0, 0.82, 0.28), 18, 1.8, 4.4, 0.65, 0.95)
			vivo_golpeado_por_puno.emit(vivo_impacto)
			_iniciar_desintegracion_personaje(vivo_impacto, pos_fx_v, 0.42)

func _procesar_rompiendo_plataforma(vivo: Node3D, delta: float) -> void:
	velocity = velocity.move_toward(Vector3.ZERO, 8.0 * delta)
	_tiempo_estado_ruptura += delta
	_temporizador_estado_ataque -= delta

	if not _puno_impacto_ejecutado and is_instance_valid(_plataforma_objetivo):
		_pos_objetivo_puno_mundo = _obtener_pos_isla_mundo(_plataforma_objetivo) + Vector3(0.0, 0.05, 0.0)
	_rotar_hacia_punto(_pos_objetivo_puno_mundo, velocidad_giro_combate, delta)

	if _tiempo_estado_ruptura < 0.24:
		_progreso_puno = pow(clampf(_tiempo_estado_ruptura / 0.24, 0.0, 1.0), 1.25)
		_progreso_barrido = 0.0
		if is_inside_tree() and int(floor(_tiempo_estado_ruptura * 45.0)) % 2 == 0:
			var pos_trail := (global_position if is_inside_tree() else position) + Vector3(0.0, altura_flotacion, 0.0)
			pos_trail = pos_trail.lerp(_pos_objetivo_puno_mundo, _progreso_puno)
			_crear_rafaga_particulas(pos_trail, Color(1.0, 0.36, 0.14), 3, 0.5, 1.4, 0.2, 0.65)
	elif _tiempo_estado_ruptura < 0.40:
		_progreso_puno = 1.0
		_progreso_barrido = clampf((_tiempo_estado_ruptura - 0.24) / 0.16, 0.0, 1.0)
		if not _puno_impacto_ejecutado:
			_puno_impacto_ejecutado = true
			_ejecutar_impacto_puno_en_isla()
	else:
		if not _puno_impacto_ejecutado:
			_puno_impacto_ejecutado = true
			_ejecutar_impacto_puno_en_isla()
		_progreso_barrido = 1.0
		var t_ret := clampf((_tiempo_estado_ruptura - 0.40) / 0.34, 0.0, 1.0)
		_progreso_puno = 1.0 - smoothstep(0.0, 1.0, t_ret)

	if _temporizador_estado_ataque <= 0.0:
		var fase := obtener_fase_actual()
		_mano_golpe_actual = 0
		_progreso_puno = 0.0
		_progreso_barrido = 0.0
		_puno_impacto_ejecutado = false
		_plataforma_objetivo = null
		_restaurar_escala_y_rotacion_manos()
		if is_instance_valid(nodo_visual):
			nodo_visual.rotation.y = 0.0
		estado_actual = Estado.COMBATE_INTANGIBLE
		_temporizador_decision = 0.65 if fase == 1 else (0.48 if fase == 2 else 0.34)
		estado_cambiado.emit(estado_actual)
		if is_instance_valid(vivo):
			_rotar_hacia_punto(vivo.global_position if vivo.is_inside_tree() else vivo.position, velocidad_giro_combate, delta)

func _clamp_punto_suelo_arena(pos_mundo: Vector3) -> Vector3:
	var offset_xz := Vector2(pos_mundo.x - _posicion_centro_arena.x, pos_mundo.z - _posicion_centro_arena.z)
	if offset_xz.length() > 11.4:
		offset_xz = offset_xz.normalized() * 11.4
	return Vector3(_posicion_centro_arena.x + offset_xz.x, _y_suelo_arena, _posicion_centro_arena.z + offset_xz.y)

func _iniciar_preparar_aplastamiento(objetivo: Node3D) -> void:
	if not is_instance_valid(objetivo):
		return
	_asegurar_indicador_aplastamiento()
	var fase := obtener_fase_actual()
	_usar_mano_derecha_golpe = not _usar_mano_derecha_golpe
	_mano_golpe_actual = 1 if _usar_mano_derecha_golpe else -1
	_plataforma_objetivo = null
	_tiempo_estado_aplastamiento = 0.0
	_aplastamiento_impacto_ejecutado = false
	var pos_obj := objetivo.global_position if objetivo.is_inside_tree() else objetivo.position
	_pos_objetivo_aplastamiento_mundo = _clamp_punto_suelo_arena(pos_obj)

	estado_actual = Estado.PREPARANDO_APLASTAMIENTO
	_temporizador_estado_ataque = 0.78 if fase == 1 else (0.66 if fase == 2 else 0.56)
	_configurar_particulas_carga(true, Color(1.0, 0.48, 0.14, 0.95))
	if is_instance_valid(_rayo_ataque):
		_rayo_ataque.visible = false
	if is_instance_valid(_indicador_aplastamiento):
		var pos_ind := _pos_objetivo_aplastamiento_mundo + Vector3(0.0, 0.05, 0.0)
		if _indicador_aplastamiento.is_inside_tree():
			_indicador_aplastamiento.global_position = pos_ind
		else:
			_indicador_aplastamiento.position = pos_ind
		_indicador_aplastamiento.scale = Vector3.ONE
		_indicador_aplastamiento.visible = true
	_animar_flotacion_y_manos(0.016)
	estado_cambiado.emit(estado_actual)

func _procesar_preparando_aplastamiento(vivo: Node3D, delta: float) -> void:
	velocity = velocity.move_toward(Vector3.ZERO, 6.0 * delta)
	if is_instance_valid(vivo):
		var pos_v := vivo.global_position if vivo.is_inside_tree() else vivo.position
		_rotar_hacia_punto(pos_v, velocidad_giro_combate * 1.65, delta)
		if _temporizador_estado_ataque > 0.22:
			var destino_suave := _clamp_punto_suelo_arena(pos_v)
			_pos_objetivo_aplastamiento_mundo = _pos_objetivo_aplastamiento_mundo.lerp(destino_suave, clampf(7.0 * delta, 0.0, 1.0))
			_pos_objetivo_aplastamiento_mundo.y = _y_suelo_arena

	if is_instance_valid(_indicador_aplastamiento):
		var pos_ind := _pos_objetivo_aplastamiento_mundo + Vector3(0.0, 0.05, 0.0)
		if _indicador_aplastamiento.is_inside_tree():
			_indicador_aplastamiento.global_position = pos_ind
		else:
			_indicador_aplastamiento.position = pos_ind
		var pulso := 1.0 + 0.08 * sin(_tiempo_acumulado * 18.0)
		_indicador_aplastamiento.scale = Vector3(pulso, 1.0, pulso)
		_indicador_aplastamiento.visible = true

	_temporizador_estado_ataque -= delta
	if _temporizador_estado_ataque <= 0.0:
		_lanzar_aplastamiento_suelo()

func _lanzar_aplastamiento_suelo() -> void:
	estado_actual = Estado.APLASTANDO_SUELO
	_temporizador_estado_ataque = 0.86
	_tiempo_estado_aplastamiento = 0.0
	_aplastamiento_impacto_ejecutado = false
	_configurar_particulas_carga(false, Color.ORANGE)
	if is_inside_tree() and is_instance_valid(_particulas_carga):
		_particulas_carga.position = Vector3.ZERO

	var fase := obtener_fase_actual()
	match fase:
		1: _cooldown_aplastamiento = cooldown_aplastamiento_base
		2: _cooldown_aplastamiento = maxf(cooldown_aplastamiento_base - 0.5, 1.1)
		_: _cooldown_aplastamiento = maxf(cooldown_aplastamiento_base - 0.95, 0.95)

	_animar_flotacion_y_manos(0.016)
	estado_cambiado.emit(estado_actual)

func _ejecutar_impacto_aplastamiento_suelo(vivo: Node3D, fantasma: Node3D) -> void:
	if is_instance_valid(_indicador_aplastamiento):
		_indicador_aplastamiento.visible = false
	if is_inside_tree():
		_crear_rafaga_particulas(_pos_objetivo_aplastamiento_mundo + Vector3.UP * 0.25, Color(1.0, 0.58, 0.20), 26, 2.8, 6.8, 0.55, 1.3)
	_sacudir_camara(vivo, intensidad_shake_camara * 1.05)
	_sacudir_camara(fantasma, intensidad_shake_camara * 0.7)

	for item in [vivo, fantasma]:
		var pj := item as Node3D
		if not is_instance_valid(pj):
			continue
		var pos_pj: Vector3 = pj.global_position if pj.is_inside_tree() else pj.position
		var dist_xz := Vector2(pos_pj.x - _pos_objetivo_aplastamiento_mundo.x, pos_pj.z - _pos_objetivo_aplastamiento_mundo.z).length()
		if dist_xz <= radio_aplastamiento_puno and pos_pj.y <= (_y_suelo_arena + 1.85):
			if is_inside_tree():
				_crear_rafaga_particulas(pos_pj + Vector3.UP * 0.4, Color(1.0, 0.30, 0.14), 16, 2.0, 4.8, 0.65, 1.1)
			personaje_aplastado_por_puno.emit(pj)
			_iniciar_aplastamiento_personaje(pj, pos_pj, 0.46)

func _obtener_nodo_visual_personaje(pj: Node3D) -> Node3D:
	if not is_instance_valid(pj):
		return null
	for nombre in ["vivo", "fantasma", "Visual"]:
		var hijo := pj.get_node_or_null(nombre) as Node3D
		if is_instance_valid(hijo):
			return hijo
	return pj

func _iniciar_aplastamiento_personaje(pj: Node3D, pos_impacto: Vector3, duracion: float = 0.46) -> void:
	if not is_instance_valid(pj):
		return
	for i in range(_victimas_aplastadas_pendientes.size() - 1, -1, -1):
		if _victimas_aplastadas_pendientes[i].get("personaje") == pj:
			_victimas_aplastadas_pendientes.remove_at(i)
	var pos_suelo := Vector3(pos_impacto.x, _y_suelo_arena, pos_impacto.z)
	if pj.is_inside_tree():
		pj.global_position = pos_suelo
	else:
		pj.position = pos_suelo
	if pj is CharacterBody3D:
		(pj as CharacterBody3D).velocity = Vector3.ZERO
	var vis := _obtener_nodo_visual_personaje(pj)
	var escala_orig: Vector3 = vis.scale if is_instance_valid(vis) else Vector3.ONE
	if is_instance_valid(vis):
		vis.scale = Vector3(escala_orig.x * 1.68, escala_orig.y * 0.14, escala_orig.z * 1.68)
	_victimas_aplastadas_pendientes.append({
		"personaje": pj,
		"visual": vis,
		"escala_orig": escala_orig,
		"pos": pos_suelo,
		"tiempo": 0.0,
		"duracion": maxf(duracion, 0.1)
	})

func _iniciar_desintegracion_personaje(pj: Node3D, pos_impacto: Vector3, duracion: float = 0.42) -> void:
	if not is_instance_valid(pj):
		return
	for i in range(_victimas_desintegradas_pendientes.size() - 1, -1, -1):
		if _victimas_desintegradas_pendientes[i].get("personaje") == pj:
			_victimas_desintegradas_pendientes.remove_at(i)
	if pj is CharacterBody3D:
		(pj as CharacterBody3D).velocity = Vector3.ZERO
	var vis := _obtener_nodo_visual_personaje(pj)
	var escala_orig: Vector3 = vis.scale if is_instance_valid(vis) else Vector3.ONE
	var rot_y_orig: float = vis.rotation.y if is_instance_valid(vis) else 0.0
	if is_instance_valid(vis):
		vis.scale = Vector3(escala_orig.x * 0.62, escala_orig.y * 1.32, escala_orig.z * 0.62)
	_victimas_desintegradas_pendientes.append({
		"personaje": pj,
		"visual": vis,
		"escala_orig": escala_orig,
		"rot_y_orig": rot_y_orig,
		"pos": pos_impacto,
		"tiempo": 0.0,
		"duracion": maxf(duracion, 0.1)
	})

func _actualizar_animaciones_muerte_personajes(delta: float) -> void:
	for i in range(_victimas_aplastadas_pendientes.size() - 1, -1, -1):
		var item: Dictionary = _victimas_aplastadas_pendientes[i]
		var pj := item.get("personaje", null) as Node3D
		if not is_instance_valid(pj):
			_victimas_aplastadas_pendientes.remove_at(i)
			continue
		var t_nuevo: float = float(item.get("tiempo", 0.0)) + delta
		var dur: float = float(item.get("duracion", 0.46))
		item["tiempo"] = t_nuevo
		var pos_fija: Vector3 = item.get("pos", Vector3.ZERO)
		if pj.is_inside_tree():
			pj.global_position = pos_fija
		else:
			pj.position = pos_fija
		if pj is CharacterBody3D:
			(pj as CharacterBody3D).velocity = Vector3.ZERO
		var vis := item.get("visual", null) as Node3D
		var escala_orig: Vector3 = item.get("escala_orig", Vector3.ONE)
		if is_instance_valid(vis):
			vis.scale = Vector3(escala_orig.x * 1.68, escala_orig.y * 0.14, escala_orig.z * 1.68)
		if t_nuevo >= dur:
			_victimas_aplastadas_pendientes.remove_at(i)
			if is_instance_valid(vis):
				vis.scale = escala_orig
			pj.scale = Vector3.ONE
			if pj.has_method("reaparecer"):
				pj.reaparecer()

	for i in range(_victimas_desintegradas_pendientes.size() - 1, -1, -1):
		var item: Dictionary = _victimas_desintegradas_pendientes[i]
		var pj := item.get("personaje", null) as Node3D
		if not is_instance_valid(pj):
			_victimas_desintegradas_pendientes.remove_at(i)
			continue
		var t_nuevo: float = float(item.get("tiempo", 0.0)) + delta
		var dur: float = float(item.get("duracion", 0.42))
		item["tiempo"] = t_nuevo
		var prog := clampf(t_nuevo / maxf(dur, 0.05), 0.0, 1.0)
		var pos_base: Vector3 = item.get("pos", Vector3.ZERO)
		var pos_anim := pos_base + Vector3(0.0, 0.42 * prog, 0.0)
		if pj.is_inside_tree():
			pj.global_position = pos_anim
		else:
			pj.position = pos_anim
		if pj is CharacterBody3D:
			(pj as CharacterBody3D).velocity = Vector3.ZERO
		var vis := item.get("visual", null) as Node3D
		var escala_orig: Vector3 = item.get("escala_orig", Vector3.ONE)
		var rot_y_orig: float = float(item.get("rot_y_orig", 0.0))
		if is_instance_valid(vis):
			vis.rotate_y(deg_to_rad(720.0 * delta))
			vis.scale = Vector3(
				escala_orig.x * lerpf(0.62, 0.04, prog),
				escala_orig.y * lerpf(1.32, 1.85, prog),
				escala_orig.z * lerpf(0.62, 0.04, prog)
			)
		if is_inside_tree() and int(floor(t_nuevo * 30.0)) % 2 == 0:
			_crear_rafaga_particulas(pos_anim + Vector3.UP * 0.3, Color(1.0, 0.65, 0.22), 4, 1.2, 2.8, 0.35, 0.55)
		if t_nuevo >= dur:
			_victimas_desintegradas_pendientes.remove_at(i)
			if is_instance_valid(vis):
				vis.scale = escala_orig
				vis.rotation.y = rot_y_orig
			pj.scale = Vector3.ONE
			if pj.has_method("reaparecer"):
				pj.reaparecer()

func _procesar_aplastando_suelo(vivo: Node3D, fantasma: Node3D, delta: float) -> void:
	velocity = velocity.move_toward(Vector3.ZERO, 8.0 * delta)
	_rotar_hacia_punto(_pos_objetivo_aplastamiento_mundo, velocidad_giro_combate, delta)
	_tiempo_estado_aplastamiento += delta
	_temporizador_estado_ataque -= delta

	if not _aplastamiento_impacto_ejecutado and _tiempo_estado_aplastamiento >= 0.18:
		_aplastamiento_impacto_ejecutado = true
		_ejecutar_impacto_aplastamiento_suelo(vivo, fantasma)

	if _temporizador_estado_ataque <= 0.0:
		var fase := obtener_fase_actual()
		_mano_golpe_actual = 0
		_tiempo_estado_aplastamiento = 0.0
		_aplastamiento_impacto_ejecutado = false
		_restaurar_escala_y_rotacion_manos()
		if is_instance_valid(nodo_visual):
			nodo_visual.rotation.y = 0.0
		if is_instance_valid(_indicador_aplastamiento):
			_indicador_aplastamiento.visible = false
		estado_actual = Estado.COMBATE_INTANGIBLE
		_temporizador_decision = 0.60 if fase == 1 else (0.45 if fase == 2 else 0.32)
		estado_cambiado.emit(estado_actual)

func _iniciar_invocacion_espectros() -> void:
	estado_actual = Estado.INVOCANDO_ESPECTROS
	_duracion_invocacion = 1.85
	_temporizador_estado_ataque = _duracion_invocacion
	_tiempo_estado_invocacion = 0.0
	_invocacion_emitida_en_estado = false
	_cooldown_invocacion = cooldown_invocacion_fase_3
	var faltan := maxi(max_mini_espectros_fase_3 - _contar_mini_espectros_vivos(), 0)
	_plataformas_invocacion_objetivo = _seleccionar_plataformas_para_invocacion(faltan)
	_configurar_particulas_carga(true, Color(0.72, 0.22, 1.0, 0.95))
	if is_instance_valid(_rayo_ataque):
		_rayo_ataque.visible = false
	_crear_efectos_ritual_invocacion()
	_actualizar_subtitulo_hud()
	estado_cambiado.emit(estado_actual)

func _seleccionar_plataformas_para_invocacion(cantidad: int) -> Array[Node3D]:
	var seleccion: Array[Node3D] = []
	if cantidad <= 0:
		return seleccion
	if _islas_ordenadas.is_empty() and not plataformas_combate.is_empty():
		_ordenar_y_conectar_islas()

	var vivo := _obtener_jugador_vivo()
	var plat_vivo := _detectar_plataforma_ocupada_por_vivo(vivo)
	var con_minion: Array[Node3D] = []
	for m in _mini_espectros_activos:
		if is_instance_valid(m) and not m.is_queued_for_deletion():
			if "estado_actual" in m and int(m.get("estado_actual")) == EnemigoEspectral.Estado.DERROTADO:
				continue
			var p_asig = m.get("plataforma_asignada")
			if is_instance_valid(p_asig):
				con_minion.append(p_asig as Node3D)

	# Priorizar las islas intermedias de subida (índices 1, 2, 3, luego 0 y 4)
	var orden_indices: Array[int] = [1, 2, 3, 0, 4]
	for idx in orden_indices:
		if idx >= _islas_ordenadas.size():
			continue
		var p := _islas_ordenadas[idx]
		if not is_instance_valid(p) or (p.has_method("esta_disponible") and not p.esta_disponible()):
			continue
		if p in con_minion or p in seleccion or p == plat_vivo:
			continue
		seleccion.append(p)
		if seleccion.size() >= cantidad:
			return seleccion

	for p in _islas_ordenadas:
		if not is_instance_valid(p) or (p.has_method("esta_disponible") and not p.esta_disponible()):
			continue
		if p in con_minion or p in seleccion:
			continue
		seleccion.append(p)
		if seleccion.size() >= cantidad:
			return seleccion

	return seleccion

func _crear_efectos_ritual_invocacion() -> void:
	_limpiar_efectos_ritual_invocacion()
	if not is_inside_tree():
		return
	var padre: Node = get_parent() if is_instance_valid(get_parent()) else get_tree().current_scene
	if not is_instance_valid(padre):
		return

	for p in _plataformas_invocacion_objetivo:
		if not is_instance_valid(p):
			continue
		var cont := Node3D.new()
		cont.name = "RitualInvocacionIsla"
		cont.set_meta("isla", p)

		var anillo := MeshInstance3D.new()
		anillo.name = "Anillo"
		var toro := TorusMesh.new()
		toro.inner_radius = 0.65
		toro.outer_radius = 0.98
		toro.rings = 24
		toro.ring_segments = 6
		var mat_anillo := StandardMaterial3D.new()
		mat_anillo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat_anillo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_anillo.albedo_color = Color(0.82, 0.34, 1.0, 0.88)
		mat_anillo.emission_enabled = true
		mat_anillo.emission = Color(0.75, 0.22, 1.0, 1.0)
		mat_anillo.emission_energy_multiplier = 3.2
		anillo.mesh = toro
		anillo.material_override = mat_anillo
		anillo.layers = 1 | 4
		cont.add_child(anillo)

		var haz := MeshInstance3D.new()
		haz.name = "Haz"
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.14
		cyl.bottom_radius = 0.24
		cyl.height = 1.0
		cyl.radial_segments = 8
		var mat_haz := StandardMaterial3D.new()
		mat_haz.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat_haz.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_haz.albedo_color = Color(0.78, 0.28, 1.0, 0.55)
		mat_haz.emission_enabled = true
		mat_haz.emission = Color(0.8, 0.3, 1.0, 1.0)
		mat_haz.emission_energy_multiplier = 2.6
		haz.mesh = cyl
		haz.material_override = mat_haz
		haz.layers = 1 | 4
		cont.add_child(haz)

		padre.add_child(cont)
		_efectos_invocacion_activos.append(cont)

func _actualizar_efectos_ritual_invocacion(delta: float) -> void:
	if _efectos_invocacion_activos.is_empty():
		return
	var origen := (global_position if is_inside_tree() else position) + Vector3(0.0, altura_flotacion + 0.5, 0.0)
	for ef in _efectos_invocacion_activos:
		if not is_instance_valid(ef):
			continue
		var p := ef.get_meta("isla", null) as Node3D
		if not is_instance_valid(p):
			continue
		var pos_p := _obtener_pos_isla_mundo(p)
		var anillo := ef.get_node_or_null("Anillo") as Node3D
		if is_instance_valid(anillo):
			anillo.global_position = pos_p + Vector3(0.0, 0.22, 0.0)
			anillo.rotation.y += 4.2 * delta
			var s_a := 0.85 + 0.2 * sin(_tiempo_acumulado * 12.0)
			anillo.scale = Vector3(s_a, 1.0, s_a)
		var haz := ef.get_node_or_null("Haz") as Node3D
		if is_instance_valid(haz):
			var dest := pos_p + Vector3(0.0, 0.35, 0.0)
			var diff := dest - origen
			var l := maxf(diff.length(), 0.2)
			var dir := diff.normalized()
			var up_r := Vector3.FORWARD if absf(dir.dot(Vector3.UP)) > 0.98 else Vector3.UP
			var xa := dir.cross(up_r).normalized()
			var za := xa.cross(dir).normalized()
			haz.global_position = (origen + dest) * 0.5
			var ancho_h := 0.8 + 0.25 * sin(_tiempo_acumulado * 18.0)
			haz.global_transform.basis = Basis(xa, dir, za).scaled(Vector3(ancho_h, l, ancho_h))

func _limpiar_efectos_ritual_invocacion() -> void:
	for ef in _efectos_invocacion_activos:
		if is_instance_valid(ef):
			if ef.is_inside_tree():
				ef.queue_free()
			else:
				ef.free()
	_efectos_invocacion_activos.clear()

func _procesar_invocando_espectros(delta: float) -> void:
	velocity = velocity.move_toward(Vector3.ZERO, 6.0 * delta)
	_tiempo_estado_invocacion += delta
	_temporizador_estado_ataque -= delta

	var p_inv := clampf(_tiempo_estado_invocacion / maxf(_duracion_invocacion, 0.01), 0.0, 1.0)
	if p_inv < 0.52:
		rotation.y += 2.6 * delta
		_actualizar_efectos_ritual_invocacion(delta)
	elif not _invocacion_emitida_en_estado:
		_invocacion_emitida_en_estado = true
		_invocar_mini_espectros()
		_limpiar_efectos_ritual_invocacion()
		if is_inside_tree():
			var pos_boss := global_position + Vector3(0.0, altura_flotacion, 0.0)
			_crear_rafaga_particulas(pos_boss, Color(0.82, 0.25, 1.0), 28, 3.0, 6.8, 0.4, 1.35)
			_sacudir_camara(_obtener_jugador_vivo(), intensidad_shake_camara * 0.55)
			_sacudir_camara(_obtener_fantasma(), intensidad_shake_camara * 0.55)

	if _temporizador_estado_ataque <= 0.0:
		_limpiar_efectos_ritual_invocacion()
		_configurar_particulas_carga(false, Color.PURPLE)
		estado_actual = Estado.COMBATE_INTANGIBLE
		_actualizar_subtitulo_hud()
		_temporizador_decision = 0.55
		estado_cambiado.emit(estado_actual)

func _invocar_mini_espectros() -> void:
	if ESCENA_MINI_ESPECTRO == null:
		return
	var existentes := _contar_mini_espectros_vivos()
	var faltan := maxi(max_mini_espectros_fase_3 - existentes, 0)
	if faltan <= 0:
		return

	if _plataformas_invocacion_objetivo.size() < faltan:
		_plataformas_invocacion_objetivo = _seleccionar_plataformas_para_invocacion(faltan)

	var vivo := _obtener_jugador_vivo()
	var pos_vivo := (vivo.global_position if vivo.is_inside_tree() else vivo.position) if is_instance_valid(vivo) else _posicion_centro_arena
	var pack_compartido: Array[EnemigoEspectral] = []
	for prev in _mini_espectros_activos:
		if is_instance_valid(prev) and prev is EnemigoEspectral and (prev as EnemigoEspectral).estado_actual != EnemigoEspectral.Estado.DERROTADO:
			pack_compartido.append(prev as EnemigoEspectral)
	var estado_pack := {"atacante": null, "pendientes": 0}

	var ang_base := atan2(pos_vivo.z - _posicion_centro_arena.z, pos_vivo.x - _posicion_centro_arena.x) + PI
	for i in range(faltan):
		var plat_obj: Node3D = _plataformas_invocacion_objetivo[i] if i < _plataformas_invocacion_objetivo.size() else null
		var en_plataforma: bool = is_instance_valid(plat_obj) and (not plat_obj.has_method("esta_destruida") or not plat_obj.esta_destruida())

		var minion := ESCENA_MINI_ESPECTRO.instantiate() as Node3D
		if not is_instance_valid(minion):
			continue
		minion.set("es_clon", true)
		minion.set("activar_solo_en_zona", false)
		minion.set("cantidad_enemigos", 1)
		minion.set("radio_zona_peligro", 16.0)
		minion.set("velocidad_acecho", 1.55)
		minion.set("distancia_inicio_ataque", 1.45)
		minion.set("tiempo_anticipacion_ataque", 1.05)
		minion.set("altura_flotacion", 0.62)
		minion.set("plataforma_asignada", plat_obj if en_plataforma else null)
		minion.set("modo_guardia_plataforma", en_plataforma)
		minion.set("duracion_hit_stop", 0.0)

		var pos_spawn := Vector3.ZERO
		if en_plataforma:
			var pos_plat := _obtener_pos_isla_mundo(plat_obj)
			pos_spawn = pos_plat + Vector3(0.0, 0.62, 0.0)
		else:
			var ang := ang_base + (float(i) - 0.5) * 1.45
			var radio_spawn := 5.6 + 0.6 * float(i % 2)
			pos_spawn = Vector3(
				_posicion_centro_arena.x + cos(ang) * radio_spawn,
				_y_suelo_arena + 0.62,
				_posicion_centro_arena.z + sin(ang) * radio_spawn
			)
			if Vector2(pos_spawn.x - pos_vivo.x, pos_spawn.z - pos_vivo.z).length() < 3.2:
				ang += PI * 0.7
				pos_spawn.x = _posicion_centro_arena.x + cos(ang) * radio_spawn
				pos_spawn.z = _posicion_centro_arena.z + sin(ang) * radio_spawn

		var nv_pre := minion.get_node_or_null("Visual") as Node3D
		if is_instance_valid(nv_pre):
			nv_pre.scale = nv_pre.scale * 0.68

		if is_inside_tree() and get_parent() != null:
			minion.position = pos_spawn
			get_parent().add_child(minion)
			minion.global_position = pos_spawn
		else:
			minion.position = pos_spawn
			if minion.has_method("_ready"):
				minion._ready()

		var esp := minion as EnemigoEspectral
		if is_instance_valid(esp):
			esp._posicion_origen = pos_spawn
			esp._y_objetivo = pos_spawn.y
			esp._plataforma_detectada = plat_obj if en_plataforma else null
			pack_compartido.append(esp)
			esp._pack_estado = estado_pack

		_mini_espectros_activos.append(minion)
		mini_espectro_invocado.emit(minion)

		if is_inside_tree():
			_crear_rafaga_particulas(pos_spawn, Color(0.75, 0.25, 1.0), 22, 1.8, 4.4, 0.8, 1.15)

	for m in pack_compartido:
		if is_instance_valid(m):
			m._pack_enemigos = pack_compartido

func _cancelar_ataque_activo(por_congelamiento: bool) -> void:
	_temporizador_estado_ataque = 0.0
	_invocacion_emitida_en_estado = false
	_mano_golpe_actual = 0
	_progreso_puno = 0.0
	_progreso_barrido = 0.0
	_tiempo_estado_ruptura = 0.0
	_tiempo_estado_invocacion = 0.0
	_tiempo_estado_aplastamiento = 0.0
	_puno_impacto_ejecutado = false
	_aplastamiento_impacto_ejecutado = false
	_limpiar_efectos_ritual_invocacion()
	_restaurar_escala_y_rotacion_manos()
	if is_instance_valid(nodo_visual):
		nodo_visual.rotation.y = 0.0
	_configurar_particulas_carga(false, Color.CYAN)
	if is_instance_valid(_particulas_carga):
		_particulas_carga.position = Vector3.ZERO
	if is_instance_valid(_rayo_ataque):
		_rayo_ataque.visible = false
	if is_instance_valid(_indicador_aplastamiento):
		_indicador_aplastamiento.visible = false
	if is_instance_valid(_plataforma_objetivo) and _plataforma_objetivo.has_method("cancelar_ruptura"):
		_plataforma_objetivo.cancelar_ruptura()
	_plataforma_objetivo = null

	if por_congelamiento:
		# Premiar la intervención cooperativa del Fantasma deteniendo grietas recientes en curso
		for p in plataformas_combate:
			if is_instance_valid(p) and p.has_method("cancelar_ruptura"):
				p.cancelar_ruptura()

func _configurar_particulas_carga(activo: bool, color: Color) -> void:
	if not is_instance_valid(_particulas_carga):
		return
	if activo:
		_particulas_carga.color = color
		if not _particulas_carga.emitting:
			_particulas_carga.restart()
		_particulas_carga.emitting = true
	else:
		_particulas_carga.emitting = false

func _actualizar_rayo_ataque_visual() -> void:
	if not is_instance_valid(_rayo_ataque):
		return
	if not is_instance_valid(_plataforma_objetivo) or estado_actual != Estado.APUNTANDO_PLATAFORMA:
		_rayo_ataque.visible = false
		return

	var origen_local := Vector3(0.0, altura_flotacion - 0.1, 0.0)
	var destino_mundo := _obtener_pos_isla_mundo(_plataforma_objetivo)
	var destino_local := to_local(destino_mundo) if is_inside_tree() else (destino_mundo - position)
	var diff := destino_local - origen_local
	var longitud := maxf(diff.length(), 0.2)
	var dir := diff.normalized()

	var up_ref := Vector3.FORWARD if absf(dir.dot(Vector3.UP)) > 0.98 else Vector3.UP
	var x_axis := dir.cross(up_ref).normalized()
	var z_axis := x_axis.cross(dir).normalized()
	var pulso_grosor := 1.0 + 0.28 * sin(_tiempo_acumulado * 26.0)
	_rayo_ataque.transform.basis = Basis(x_axis, dir, z_axis).scaled(Vector3(pulso_grosor, longitud, pulso_grosor))
	_rayo_ataque.position = (origen_local + destino_local) * 0.5
	_rayo_ataque.visible = true

## ─────────────────────────────────────────────────────────────────────────────
## GESTIÓN DINÁMICA DE ISLAS (DESTRUCCIÓN, REGENERACIÓN, FASES Y OSCILACIÓN)
## ─────────────────────────────────────────────────────────────────────────────

func _ordenar_y_conectar_islas() -> void:
	if plataformas_combate.is_empty() and is_inside_tree():
		var padre := get_parent()
		if is_instance_valid(padre):
			var cont_plats := padre.get_node_or_null("PlataformasCombate")
			if is_instance_valid(cont_plats):
				for hijo in cont_plats.get_children():
					if hijo is Node3D and (hijo.is_in_group("plataformas_coliseo") or hijo.has_method("elevar")):
						plataformas_combate.append(hijo as Node3D)
		if plataformas_combate.is_empty() and get_tree() != null:
			var radio_busqueda := radio_activacion_arena + 4.0
			for nodo in get_tree().get_nodes_in_group("plataformas_coliseo"):
				if nodo is Node3D and is_instance_valid(nodo):
					var p_n := (nodo as Node3D).global_position
					if Vector2(p_n.x - _posicion_centro_arena.x, p_n.z - _posicion_centro_arena.z).length() <= radio_busqueda:
						plataformas_combate.append(nodo as Node3D)

	_islas_ordenadas.clear()
	for p in plataformas_combate:
		if not is_instance_valid(p):
			continue
		_islas_ordenadas.append(p)
		if p.has_signal("plataforma_destruida"):
			var cb := Callable(self, "_on_plataforma_destruida")
			if not p.is_connected("plataforma_destruida", cb):
				p.connect("plataforma_destruida", cb)
	_islas_ordenadas.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		var alt_a: float = float(a.get("altura_elevada")) if "altura_elevada" in a else 0.0
		var alt_b: float = float(b.get("altura_elevada")) if "altura_elevada" in b else 0.0
		return alt_a < alt_b
	)

func _on_plataforma_destruida(isla: Node3D) -> void:
	if estado_actual == Estado.DERROTADO or estado_actual == Estado.DORMIDO_ARMADURA:
		return
	for entrada in _cola_regeneracion_islas:
		if entrada.get("isla") == isla:
			return
	_cola_regeneracion_islas.append({
		"isla": isla,
		"tiempo": _obtener_tiempo_regeneracion_fase()
	})

func _actualizar_regeneracion_islas(delta: float) -> void:
	for i in range(_cola_regeneracion_islas.size() - 1, -1, -1):
		var entrada: Dictionary = _cola_regeneracion_islas[i]
		var isla := entrada.get("isla", null) as Node3D
		if not is_instance_valid(isla):
			_cola_regeneracion_islas.remove_at(i)
			continue
		var restante: float = float(entrada.get("tiempo", 0.0)) - delta
		if restante <= 0.0:
			_cola_regeneracion_islas.remove_at(i)
			var nueva_pos := _calcular_nueva_posicion_isla(isla)
			if isla.has_method("regenerar_en_posicion"):
				isla.regenerar_en_posicion(nueva_pos, is_inside_tree())
		else:
			entrada["tiempo"] = restante

func _obtener_centro_local_islas(isla_ref: Node3D) -> Vector3:
	var y_base := 0.06
	if is_instance_valid(isla_ref) and isla_ref.has_method("obtener_posicion_base"):
		y_base = (isla_ref.obtener_posicion_base() as Vector3).y
	if is_instance_valid(isla_ref) and isla_ref.is_inside_tree() and isla_ref.get_parent() is Node3D:
		var local_c := (isla_ref.get_parent() as Node3D).to_local(_posicion_centro_arena)
		return Vector3(local_c.x, y_base, local_c.z)
	if is_instance_valid(isla_ref) and isla_ref.has_method("obtener_posicion_base"):
		var pos_b := isla_ref.obtener_posicion_base() as Vector3
		var dist_origen := Vector2(pos_b.x, pos_b.z).length()
		var dist_centro_arena := Vector2(_posicion_centro_arena.x, _posicion_centro_arena.z).length()
		if dist_centro_arena > 12.0 and dist_origen <= (radio_max_islas + 2.5):
			return Vector3(0.0, y_base, 0.0)
	return Vector3(_posicion_centro_arena.x, y_base, _posicion_centro_arena.z)

func _obtener_pos_isla_mundo(isla: Node3D) -> Vector3:
	if not is_instance_valid(isla):
		return _posicion_centro_arena
	if isla.is_inside_tree() and is_inside_tree():
		return isla.global_position
	var pos := isla.position
	if Vector2(_posicion_centro_arena.x, _posicion_centro_arena.z).length() > 12.0 and Vector2(pos.x, pos.z).length() <= (radio_max_islas + 2.5):
		return Vector3(_posicion_centro_arena.x + pos.x, _y_suelo_arena + pos.y, _posicion_centro_arena.z + pos.z)
	return pos

func _calcular_nueva_posicion_isla(isla: Node3D) -> Vector3:
	var pos_ant: Vector3 = isla.obtener_posicion_base() if isla.has_method("obtener_posicion_base") else isla.position
	var centro := _obtener_centro_local_islas(isla)
	var y_base := pos_ant.y if pos_ant.y < 1.0 else 0.06
	var ang_ant := atan2(pos_ant.z - centro.z, pos_ant.x - centro.x)
	var r_medio := (radio_min_islas + radio_max_islas) * 0.5

	var idx_tier := _islas_ordenadas.find(isla)
	var vecina_baja: Node3D = _islas_ordenadas[idx_tier - 1] if idx_tier > 0 else null
	var vecina_alta: Node3D = _islas_ordenadas[idx_tier + 1] if (idx_tier >= 0 and idx_tier + 1 < _islas_ordenadas.size()) else null

	var mejor_pos := Vector3(centro.x + cos(ang_ant + 0.55) * r_medio, y_base, centro.z + sin(ang_ant + 0.55) * r_medio)
	var mejor_puntaje: float = -1e9
	var encontro_estricto := false

	var radios_muestra: Array[float] = [radio_min_islas, r_medio, radio_max_islas]
	var angulos_muestra: Array[float] = []
	for step_a in range(36):
		angulos_muestra.append(ang_ant + (float(step_a + 1) / 36.0) * TAU)
	# Muestrear también alrededor del ángulo medio entre vecinas para no perder nunca el puente escalable
	if is_instance_valid(vecina_baja) and is_instance_valid(vecina_alta):
		var p_vb: Vector3 = vecina_baja.obtener_posicion_base() if vecina_baja.has_method("obtener_posicion_base") else vecina_baja.position
		var p_va: Vector3 = vecina_alta.obtener_posicion_base() if vecina_alta.has_method("obtener_posicion_base") else vecina_alta.position
		var mid := ((p_vb + p_va) * 0.5) - centro
		if Vector2(mid.x, mid.z).length_squared() > 0.05:
			var ang_mid := atan2(mid.z, mid.x)
			for off_deg in [-0.35, -0.22, -0.12, 0.0, 0.12, 0.22, 0.35]:
				angulos_muestra.append(ang_mid + off_deg)

	for relajado in [false, true]:
		if relajado and encontro_estricto:
			break
		var dist_sep_min: float = 3.25 if not relajado else 2.65
		var alcance_salto_max: float = 5.65 if not relajado else 6.4

		for r_cand in radios_muestra:
			for ang_cand in angulos_muestra:
				var cand := Vector3(centro.x + cos(ang_cand) * r_cand, y_base, centro.z + sin(ang_cand) * r_cand)

				var dist_a_anterior := Vector2(cand.x - pos_ant.x, cand.z - pos_ant.z).length()
				if not relajado and dist_a_anterior < 1.65:
					continue

				# Separación mínima respecto a las demás islas para evitar amontonamientos
				var min_dist_otras: float = 99.0
				for otra in plataformas_combate:
					if not is_instance_valid(otra) or otra == isla:
						continue
					if otra.has_method("esta_destruida") and otra.esta_destruida():
						continue
					var pos_o: Vector3 = otra.obtener_posicion_base() if otra.has_method("obtener_posicion_base") else otra.position
					var d_o := Vector2(cand.x - pos_o.x, cand.z - pos_o.z).length()
					min_dist_otras = minf(min_dist_otras, d_o)
				if min_dist_otras < dist_sep_min:
					continue

				var d_vb := 0.0
				var d_va := 0.0
				if is_instance_valid(vecina_baja):
					var pos_vb: Vector3 = vecina_baja.obtener_posicion_base() if vecina_baja.has_method("obtener_posicion_base") else vecina_baja.position
					d_vb = Vector2(cand.x - pos_vb.x, cand.z - pos_vb.z).length()
					if not relajado and d_vb > alcance_salto_max:
						continue
				if is_instance_valid(vecina_alta):
					var pos_va: Vector3 = vecina_alta.obtener_posicion_base() if vecina_alta.has_method("obtener_posicion_base") else vecina_alta.position
					d_va = Vector2(cand.x - pos_va.x, cand.z - pos_va.z).length()
					if not relajado and d_va > (alcance_salto_max + 0.2):
						continue

				var puntaje := minf(dist_a_anterior, 3.8) * 1.1 + minf(min_dist_otras, 4.8) * 0.7
				if is_instance_valid(vecina_baja):
					if d_vb <= alcance_salto_max:
						puntaje += 12.0 - absf(d_vb - 4.6) * 1.2
					else:
						puntaje -= (d_vb - alcance_salto_max) * 14.0
				if is_instance_valid(vecina_alta):
					if d_va <= (alcance_salto_max + 0.2):
						puntaje += 9.0 - absf(d_va - 4.6) * 1.0
					else:
						puntaje -= (d_va - (alcance_salto_max + 0.2)) * 10.0

				if puntaje > mejor_puntaje:
					mejor_puntaje = puntaje
					mejor_pos = cand
					if not relajado:
						encontro_estricto = true

	return mejor_pos

func _reorganizar_islas_nueva_fase(animado: bool) -> void:
	if _islas_ordenadas.is_empty():
		_ordenar_y_conectar_islas()
	if _islas_ordenadas.is_empty():
		return

	_cola_regeneracion_islas.clear()
	_angulo_base_espiral = wrapf(_angulo_base_espiral + randf_range(1.15, 2.25), -PI, PI)
	_sentido_espiral = -_sentido_espiral

	var centro := _obtener_centro_local_islas(_islas_ordenadas[0])
	# Espiral compacta (~0.74 rad -> ~4.4m entre islas consecutivas) para asegurar escalabilidad tras regenerar
	var paso_ang: float = 0.74 * _sentido_espiral

	for i in range(_islas_ordenadas.size()):
		var isla := _islas_ordenadas[i]
		if not is_instance_valid(isla):
			continue
		var pos_b: Vector3 = isla.obtener_posicion_base() if isla.has_method("obtener_posicion_base") else isla.position
		var y_base := pos_b.y if pos_b.y < 1.0 else 0.06
		var ang := _angulo_base_espiral + float(i) * paso_ang
		var r_isla := clampf(6.1 + (0.25 if i % 2 == 0 else -0.20), radio_min_islas, radio_max_islas)
		var destino_local := Vector3(centro.x + cos(ang) * r_isla, y_base, centro.z + sin(ang) * r_isla)
		if isla.has_method("reubicar_suavemente"):
			isla.reubicar_suavemente(destino_local, 0.9, animado)

func _actualizar_fase_si_corresponde(animado: bool) -> void:
	var nueva_fase := obtener_fase_actual()
	if nueva_fase == _fase_aplicada:
		return
	_fase_aplicada = nueva_fase
	_aplicar_configuracion_fase(nueva_fase, animado)
	fase_cambiada.emit(nueva_fase)

func _aplicar_configuracion_fase(fase: int, animado: bool) -> void:
	if _islas_ordenadas.is_empty():
		_ordenar_y_conectar_islas()

	if reubicar_islas_al_cambiar_fase and fase >= 2:
		_reorganizar_islas_nueva_fase(animado)

	var osc_activa := fase >= 2
	var amp_bob := 0.45 if fase == 2 else (0.74 if fase >= 3 else 0.0)
	var vel_bob := 1.65 if fase == 2 else (2.25 if fase >= 3 else 1.5)
	var paso_fase := 1.15 if fase == 2 else 1.35

	for i in range(_islas_ordenadas.size()):
		var isla := _islas_ordenadas[i]
		if is_instance_valid(isla) and isla.has_method("configurar_oscilacion"):
			isla.configurar_oscilacion(osc_activa, amp_bob, vel_bob, float(i) * paso_fase)

	if fase >= 3:
		_cooldown_invocacion = 0.35

	_actualizar_subtitulo_hud()
	if is_inside_tree():
		var col_onda := Color(1.0, 0.65, 0.18) if fase == 2 else Color(0.85, 0.22, 1.0)
		_crear_rafaga_particulas(_posicion_centro_arena + Vector3.UP * altura_flotacion, col_onda, 28, 3.0, 6.8, 0.4, 1.35)

func _detectar_plataforma_ocupada_por_vivo(vivo: Node3D) -> Node3D:
	if not is_instance_valid(vivo):
		return null
	for p in plataformas_combate:
		if not is_instance_valid(p):
			continue
		if p.has_method("contiene_jugador_encima") and p.contiene_jugador_encima(vivo):
			return p
	return null

func _obtener_isla_activa_mas_cercana(pos_mundo: Vector3) -> Node3D:
	var mejor: Node3D = null
	var min_d := 1e9
	for p in plataformas_combate:
		if not is_instance_valid(p) or (p.has_method("esta_disponible") and not p.esta_disponible()):
			continue
		var pp := _obtener_pos_isla_mundo(p)
		var d := Vector2(pp.x - pos_mundo.x, pp.z - pos_mundo.z).length()
		if d < min_d:
			min_d = d
			mejor = p
	return mejor

func _buscar_isla_vecina_activa(excluir: Node3D) -> Node3D:
	var pos_ex := _obtener_pos_isla_mundo(excluir)
	var mejor: Node3D = null
	var min_d := 1e9
	for p in plataformas_combate:
		if not is_instance_valid(p) or p == excluir:
			continue
		if p.has_method("esta_disponible") and not p.esta_disponible():
			continue
		var pp := _obtener_pos_isla_mundo(p)
		var d := Vector2(pp.x - pos_ex.x, pp.z - pos_ex.z).length()
		if d < min_d:
			min_d = d
			mejor = p
	return mejor

func _contar_islas_destruidas() -> int:
	var n := 0
	for p in plataformas_combate:
		if is_instance_valid(p) and p.has_method("esta_destruida") and p.esta_destruida():
			n += 1
	return n

func _contar_islas_activas() -> int:
	var n := 0
	for p in plataformas_combate:
		if is_instance_valid(p) and p.has_method("esta_disponible") and p.esta_disponible():
			n += 1
	return n

func _contar_mini_espectros_vivos() -> int:
	var n := 0
	for m in _mini_espectros_activos:
		if is_instance_valid(m) and not m.is_queued_for_deletion():
			if "estado_actual" in m and int(m.get("estado_actual")) == EnemigoEspectral.Estado.DERROTADO:
				continue
			n += 1
	return n

func _limpiar_referencias_combate_invalidas() -> void:
	for i in range(_tornados_activos.size() - 1, -1, -1):
		var t := _tornados_activos[i]
		if not is_instance_valid(t) or t.is_queued_for_deletion() or t._disipado:
			_tornados_activos.remove_at(i)
	for i in range(_mini_espectros_activos.size() - 1, -1, -1):
		var m := _mini_espectros_activos[i]
		if not is_instance_valid(m) or m.is_queued_for_deletion():
			_mini_espectros_activos.remove_at(i)

func _limpiar_entidades_combate(inmediato: bool = false) -> void:
	_cola_regeneracion_islas.clear()
	_plataforma_objetivo = null
	_limpiar_efectos_ritual_invocacion()
	if is_instance_valid(_rayo_ataque):
		_rayo_ataque.visible = false
	_configurar_particulas_carga(false, Color.CYAN)
	if is_instance_valid(_particulas_congelado):
		_particulas_congelado.emitting = false

	for t in _tornados_activos:
		if is_instance_valid(t):
			if t.is_inside_tree():
				if inmediato:
					t.queue_free()
				else:
					t.disipar()
			else:
				t.free()
	_tornados_activos.clear()

	for m in _mini_espectros_activos:
		if is_instance_valid(m):
			if is_inside_tree() and m.is_inside_tree():
				_crear_rafaga_particulas(m.global_position, Color(0.75, 0.25, 1.0), 10, 1.0, 2.5, 0.6, 0.85)
				m.queue_free()
			elif not m.is_inside_tree():
				m.free()
			else:
				m.queue_free()
	_mini_espectros_activos.clear()

	for p in plataformas_combate:
		if is_instance_valid(p):
			if p.has_method("cancelar_ruptura"):
				p.cancelar_ruptura()
			if p.has_method("configurar_oscilacion"):
				p.configurar_oscilacion(false, 0.0, 1.5, 0.0)

## ─────────────────────────────────────────────────────────────────────────────
## DETECCIÓN DE LLEGADA DE AMBOS PERSONAJES Y SECUENCIA DE DESPERTAR
## ─────────────────────────────────────────────────────────────────────────────

func _obtener_jugador_vivo() -> Node3D:
	if not is_instance_valid(_jugador_vivo_ref) and is_inside_tree():
		var red_mgr := get_node_or_null("/root/RedManager")
		if is_instance_valid(red_mgr) and "jugador_vivo" in red_mgr and is_instance_valid(red_mgr.jugador_vivo):
			_jugador_vivo_ref = red_mgr.jugador_vivo
		elif get_tree():
			var vivos := get_tree().get_nodes_in_group("vivos")
			if vivos.size() > 0:
				_jugador_vivo_ref = vivos[0] as Node3D
	return _jugador_vivo_ref

func _obtener_fantasma() -> Node3D:
	if not is_instance_valid(_fantasma_ref) and is_inside_tree():
		var red_mgr := get_node_or_null("/root/RedManager")
		if is_instance_valid(red_mgr) and "fantasma" in red_mgr and is_instance_valid(red_mgr.fantasma):
			_fantasma_ref = red_mgr.fantasma
		elif get_tree():
			var fantasmas := get_tree().get_nodes_in_group("fantasmas")
			if fantasmas.size() > 0:
				_fantasma_ref = fantasmas[0] as Node3D
	return _fantasma_ref

func _esta_nodo_en_coliseo(nodo: Node3D) -> bool:
	if not is_instance_valid(nodo):
		return false
	var pos_n := nodo.global_position if nodo.is_inside_tree() else nodo.position
	var dist_h := Vector2(pos_n.x - _posicion_centro_arena.x, pos_n.z - _posicion_centro_arena.z).length()
	var diff_y := absf(pos_n.y - _posicion_centro_arena.y)
	return dist_h <= radio_activacion_arena and diff_y <= 8.5

func _estan_ambos_personajes_en_coliseo() -> bool:
	var vivo := _obtener_jugador_vivo()
	var fantasma := _obtener_fantasma()
	if not is_instance_valid(vivo) or not is_instance_valid(fantasma):
		return false
	return _esta_nodo_en_coliseo(vivo) and _esta_nodo_en_coliseo(fantasma)

func iniciar_despertar() -> void:
	if estado_actual != Estado.DORMIDO_ARMADURA:
		return

	_ordenar_y_conectar_islas()
	estado_actual = Estado.DESPERTANDO
	estado_cambiado.emit(estado_actual)
	boss_despertado.emit()
	_actualizar_puntos_control_coliseo()
	_elevar_plataformas_combate(is_inside_tree())

	if is_inside_tree() and is_instance_valid(particulas_aura_boss):
		particulas_aura_boss.emitting = true

	# En tests headless fuera del árbol, finalizar despertar de inmediato sin tweens
	if not is_inside_tree():
		_colocar_armadura_ensamblada()
		_finalizar_despertar()
		return

	if _tween_principal != null and _tween_principal.is_valid():
		_tween_principal.kill()

	_animando_transicion = true
	_crear_hud_boss()

	# Preparar cuerpo espectral (Capa 3 para Fantasma) y silueta semitransparente (Capa 2 para Vivo)
	if is_instance_valid(modelo_espectral):
		modelo_espectral.visible = true
		_asignar_capas_recursivo(modelo_espectral, 4)
		_set_transparencia_espectral(1.0)
	if is_instance_valid(_silueta_aviso):
		_silueta_aviso.visible = true
		_asignar_capas_recursivo(_silueta_aviso, 2)
		if is_instance_valid(_mat_silueta_aviso):
			_mat_silueta_aviso.set_shader_parameter("factor_visibilidad", 0.0)

	var dur_temblor: float = duracion_despertar * 0.22
	var dur_vuelo: float = maxf(duracion_despertar * 0.68, float(ARMADURA_PIEZAS_ORDEN.size() - 1) * 0.08 + 0.48)
	_limpiar_tweens_armadura()
	_tween_principal = create_tween()

	# FASE 1: Temblor siniestro de la armadura sobre el suelo del coliseo
	for nombre_pieza in ARMADURA_PIEZAS_ORDEN:
		var pieza := _piezas_armadura.get(nombre_pieza, null) as Node3D
		if not is_instance_valid(pieza):
			continue
		var pos_ini := pieza.position
		_tween_principal.parallel().tween_method(func(t: float):
			if is_instance_valid(pieza):
				var amp := 0.05 * sin(t * TAU * 4.0)
				pieza.position = pos_ini + Vector3(amp, absf(amp) * 0.5, -amp * 0.6)
		, 0.0, 1.0, dur_temblor)

	# FASE 2: Las 6 piezas de armadura levitan y vuelan hasta tomar la forma del espectro guerrero
	_tween_principal.tween_callback(func():
		var vivo := _obtener_jugador_vivo()
		_sacudir_camara(vivo, intensidad_shake_camara * 0.65)
	)

	var idx: int = 0
	for nombre_pieza in ARMADURA_PIEZAS_ORDEN:
		var pieza := _piezas_armadura.get(nombre_pieza, null) as Node3D
		if not is_instance_valid(pieza):
			idx += 1
			continue
		var pose_dest: Dictionary = _armadura_poses_ensambladas.get(nombre_pieza, {"pos": Vector3.ZERO, "rot": Vector3.ZERO})
		var retardo_pieza: float = float(idx) * 0.08
		var dur_pieza: float = maxf(dur_vuelo - retardo_pieza, 0.45)
		var tw_pieza := create_tween()
		_tweens_armadura.append(tw_pieza)
		tw_pieza.tween_interval(dur_temblor + retardo_pieza)
		tw_pieza.tween_property(pieza, "position", pose_dest["pos"], dur_pieza).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_pieza.parallel().tween_property(pieza, "rotation", pose_dest["rot"], dur_pieza).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		idx += 1

	# FASE 2 en paralelo: Materialización gradual del espectro (Fantasma) y su silueta translúcida (Vivo)
	_tween_principal.tween_method(_set_transparencia_espectral, 1.0, 0.0, dur_vuelo).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_mat_silueta_aviso):
		var mat_s := _mat_silueta_aviso
		_tween_principal.parallel().tween_method(func(v: float):
			if is_instance_valid(mat_s):
				mat_s.set_shader_parameter("factor_visibilidad", v)
		, 0.0, 0.88, dur_vuelo).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_tween_principal.tween_callback(_finalizar_despertar)

func _limpiar_tweens_armadura() -> void:
	for tw in _tweens_armadura:
		if tw != null and tw.is_valid():
			tw.kill()
	_tweens_armadura.clear()

func _finalizar_despertar() -> void:
	_animando_transicion = false
	_colocar_armadura_ensamblada()
	if is_instance_valid(modelo_espectral):
		modelo_espectral.visible = true
		_asignar_capas_recursivo(modelo_espectral, 4)
		_set_transparencia_espectral(0.0)
	if is_instance_valid(_silueta_aviso):
		_silueta_aviso.visible = true
		_asignar_capas_recursivo(_silueta_aviso, 2)
		if is_instance_valid(_mat_silueta_aviso):
			_mat_silueta_aviso.set_shader_parameter("factor_visibilidad", 0.88)
	if is_instance_valid(colision_cuerpo):
		if is_inside_tree():
			colision_cuerpo.set_deferred("disabled", false)
		else:
			colision_cuerpo.disabled = false

	_fase_aplicada = obtener_fase_actual()
	_temporizador_decision = 0.55
	_cooldown_tornado = 0.65
	_cooldown_romper_plataforma = 0.9
	estado_actual = Estado.COMBATE_INTANGIBLE
	_establecer_tangibilidad(false, true)

func _actualizar_puntos_control_coliseo() -> void:
	var pos_cp := _posicion_centro_arena + offset_punto_control
	for pj in [_obtener_jugador_vivo(), _obtener_fantasma()]:
		if is_instance_valid(pj) and pj.has_method("establecer_punto_control"):
			pj.establecer_punto_control(pos_cp)

func _elevar_plataformas_combate(animado: bool) -> void:
	for p in plataformas_combate:
		if not is_instance_valid(p):
			continue
		if p.has_method("elevar"):
			p.elevar(animado)

func _descender_plataformas_combate(animado: bool) -> void:
	for p in plataformas_combate:
		if not is_instance_valid(p):
			continue
		if p.has_method("descender"):
			p.descender(animado)

## ─────────────────────────────────────────────────────────────────────────────
## AURA DEL FANTASMA Y CONGELAMIENTO / TANGIBILIDAD
## ─────────────────────────────────────────────────────────────────────────────

func activar_por_luz(activo: bool) -> void:
	_iluminado_por_farol = activo

func _verificar_tangibilidad_con_aura(delta: float) -> void:
	if not es_estado_combate_intangible() and estado_actual != Estado.TANGIBLE_VULNERABLE:
		return
	if _en_compresion_pisoton or _temporizador_invulnerable > 0.0:
		return
	var f := _obtener_fantasma()
	var en_contacto: bool = _iluminado_por_farol

	if is_instance_valid(f):
		var aura: Node = null
		if "habilidad_aura" in f and is_instance_valid(f.habilidad_aura):
			aura = f.habilidad_aura
		elif f.has_node("HabilidadAura"):
			aura = f.get_node("HabilidadAura")

		if is_instance_valid(aura) and aura.has_method("esta_activa") and aura.esta_activa():
			var radio_aura: float = aura.obtener_radio() if aura.has_method("obtener_radio") else 0.0
			var pos_boss := global_position if is_inside_tree() else position
			var pos_fant := f.global_position if f.is_inside_tree() else f.position
			var dist_h := Vector2(pos_boss.x - pos_fant.x, pos_boss.z - pos_fant.z).length()
			# Medir diferencia vertical respecto al centro flotante del jefe
			var centro_y_boss: float = pos_boss.y + altura_flotacion
			var diff_y := absf(centro_y_boss - pos_fant.y)

			if dist_h <= (radio_aura + radio_contacto_aura) and diff_y <= tolerancia_vertical_aura:
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
	if tangible and (estado_actual == Estado.ATURDIDO_GOLPE or estado_actual == Estado.DERROTADO or _en_compresion_pisoton or vida_actual <= 0):
		return
	if _esta_tangible == tangible and not forzar:
		return

	_esta_tangible = tangible

	if tangible:
		_cancelar_ataque_activo(true)
		_empuje_activo_vivo["tiempo"] = 0.0
		_empuje_activo_fantasma["tiempo"] = 0.0
		_rebote_frente_activo = false
		estado_actual = Estado.TANGIBLE_VULNERABLE
		velocity = Vector3.ZERO
		collision_layer = 2 | 4 # Sólido para Vivo (Capa 2) y Fantasma (Capa 3)
		collision_mask = 1 | 2
		if is_instance_valid(colision_cuerpo):
			if is_inside_tree():
				colision_cuerpo.set_deferred("disabled", false)
			else:
				colision_cuerpo.disabled = false

		_establecer_visibilidad_vivo(true)
		if is_instance_valid(_mat_cuerpo):
			_mat_cuerpo.set_shader_parameter("factor_tangible", 1.0)
		if is_instance_valid(halo_objetivo):
			halo_objetivo.visible = true
		if is_instance_valid(_particulas_congelado):
			_particulas_congelado.emitting = true
		if is_inside_tree():
			_crear_rafaga_particulas(global_position + Vector3(0.0, altura_flotacion, 0.0), Color(0.38, 0.94, 1.0), 18, 2.2, 4.6, 0.5, 1.2)

		_actualizar_subtitulo_hud()
		boss_revelado.emit()
	else:
		if estado_actual != Estado.DORMIDO_ARMADURA and estado_actual != Estado.DESPERTANDO and estado_actual != Estado.DERROTADO and estado_actual != Estado.ATURDIDO_GOLPE:
			estado_actual = Estado.COMBATE_INTANGIBLE

		collision_layer = 4 # Solo plano espiritual (intangible para el Vivo)
		collision_mask = 1

		_establecer_visibilidad_vivo(false)
		if is_instance_valid(_mat_cuerpo):
			_mat_cuerpo.set_shader_parameter("factor_tangible", 0.0)
		if is_instance_valid(halo_objetivo):
			halo_objetivo.visible = false
		if is_instance_valid(_particulas_congelado):
			_particulas_congelado.emitting = false

		_actualizar_subtitulo_hud()
		boss_ocultado.emit()

	estado_cambiado.emit(estado_actual)

func _establecer_visibilidad_vivo(visible_para_vivo: bool) -> void:
	_visible_vivo_actual = visible_para_vivo
	if _tween_fade != null and _tween_fade.is_valid():
		_tween_fade.kill()

	# La armadura SIEMPRE se mantiene sólida en Capa 1
	if is_instance_valid(modelo_armadura):
		_asignar_capas_recursivo(modelo_armadura, 1)

	if visible_para_vivo:
		# Al volverse tangible: el cuerpo espectral completo pasa a Capa 1|3 (visible para ambos) y la silueta se oculta
		if is_instance_valid(modelo_espectral):
			modelo_espectral.visible = true
			_asignar_capas_recursivo(modelo_espectral, 1 | 4)
			_set_transparencia_espectral(0.0)
		if is_instance_valid(_silueta_aviso):
			_silueta_aviso.visible = false
	else:
		# Intangible: cuerpo completo solo en Capa 3 (Fantasma); silueta translúcida en Capa 2 (Vivo)
		if is_instance_valid(modelo_espectral):
			_asignar_capas_recursivo(modelo_espectral, 4)
			_set_transparencia_espectral(0.0)
		var mostrar_silueta: bool = estado_actual != Estado.DORMIDO_ARMADURA and estado_actual != Estado.DERROTADO
		if is_instance_valid(_silueta_aviso):
			_silueta_aviso.visible = mostrar_silueta
			if mostrar_silueta and is_instance_valid(_mat_silueta_aviso):
				_mat_silueta_aviso.set_shader_parameter("factor_visibilidad", 0.88)

func _set_transparencia_espectral(valor: float) -> void:
	if is_instance_valid(_mat_cuerpo):
		_mat_cuerpo.set_shader_parameter("fade", valor)
	if is_instance_valid(_mat_rojo):
		_mat_rojo.albedo_color.a = 1.0 - valor
		_mat_rojo.emission_energy_multiplier = 4.2 * (1.0 - valor)
	if is_instance_valid(modelo_espectral):
		_set_transparencia_recursivo(modelo_espectral, valor)

func _set_transparencia_recursivo(nodo: Node, valor: float) -> void:
	if nodo is GeometryInstance3D:
		(nodo as GeometryInstance3D).transparency = valor
	for hijo in nodo.get_children():
		_set_transparencia_recursivo(hijo, valor)

func _actualizar_silueta_aviso() -> void:
	if not is_instance_valid(_silueta_aviso) or not _silueta_aviso.visible or not is_instance_valid(_mat_silueta_aviso):
		return
	var pulso: float = 0.82 + 0.16 * sin(_tiempo_acumulado * 4.2)
	_mat_silueta_aviso.set_shader_parameter("factor_visibilidad", pulso)

func _actualizar_halo_objetivo() -> void:
	if not is_instance_valid(halo_objetivo) or not halo_objetivo.visible:
		return
	var pulso: float = 1.0 + 0.08 * sin(_tiempo_acumulado * 7.5)
	var s_base: float = escala_modelo * 0.95 * pulso
	halo_objetivo.scale = Vector3(s_base, 1.0, s_base)
	halo_objetivo.rotation.y += 0.03

## ─────────────────────────────────────────────────────────────────────────────
## MOVIMIENTO EN COMBATE, PISOTÓN Y 3 PUNTOS DE VIDA
## ─────────────────────────────────────────────────────────────────────────────

func _actualizar_movimiento_combate(vivo: Node3D, fantasma: Node3D, delta: float) -> void:
	var pos_propia := global_position if is_inside_tree() else position
	var plat_vivo := _detectar_plataforma_ocupada_por_vivo(vivo)

	# Rotar dinámicamente hacia el objetivo prioritario del momento
	if is_instance_valid(plat_vivo) and is_instance_valid(vivo):
		var pos_v := vivo.global_position if vivo.is_inside_tree() else vivo.position
		_rotar_hacia_punto(pos_v, velocidad_giro_combate, delta)
	elif is_instance_valid(fantasma) and _cooldown_tornado <= 1.2:
		var pos_f := fantasma.global_position if fantasma.is_inside_tree() else fantasma.position
		_rotar_hacia_punto(pos_f, velocidad_giro_combate, delta)
	elif is_instance_valid(vivo):
		var pos_v := vivo.global_position if vivo.is_inside_tree() else vivo.position
		_rotar_hacia_punto(pos_v, velocidad_giro_combate * 0.85, delta)

	# Flotar amenazante dentro de la zona central (siempre alcanzable desde las islas altas)
	var fase_mult: float = _escala_velocidad_fase()
	var angulo_orbita: float = _tiempo_acumulado * 0.55 * fase_mult
	var punto_orbita := Vector3(
		_posicion_centro_arena.x + cos(angulo_orbita) * radio_patrulla_centro * 0.72,
		_y_suelo_arena,
		_posicion_centro_arena.z + sin(angulo_orbita) * radio_patrulla_centro * 0.72
	)
	var objetivo := punto_orbita
	if is_instance_valid(vivo):
		var pos_v := vivo.global_position if vivo.is_inside_tree() else vivo.position
		var hacia_vivo_clamped := Vector3(pos_v.x - _posicion_centro_arena.x, 0.0, pos_v.z - _posicion_centro_arena.z)
		if hacia_vivo_clamped.length() > radio_patrulla_centro:
			hacia_vivo_clamped = hacia_vivo_clamped.normalized() * radio_patrulla_centro
		objetivo = punto_orbita.lerp(_posicion_centro_arena + hacia_vivo_clamped, 0.42)
	objetivo.y = _y_suelo_arena

	var diff := objetivo - pos_propia
	diff.y = 0.0
	var vel_obj := Vector3.ZERO
	if diff.length() > 0.2:
		vel_obj = diff.normalized() * (velocidad_desplazamiento * fase_mult)
	velocity = velocity.move_toward(vel_obj, 5.0 * delta)
	velocity.y = 0.0

func _verificar_empuje_cuerpo_intangible(vivo: Node3D) -> void:
	_verificar_repulsion_personaje(vivo, false)

func _verificar_repulsion_cercania(vivo: Node3D, fantasma: Node3D) -> void:
	_verificar_repulsion_personaje(vivo, false)
	_verificar_repulsion_personaje(fantasma, true)

func _verificar_repulsion_personaje(personaje: Node3D, es_fantasma: bool) -> void:
	if not is_instance_valid(personaje) or not (personaje is CharacterBody3D):
		return
	var cooldown := _cooldown_repulsion_fantasma if es_fantasma else _cooldown_repulsion_vivo
	if cooldown > 0.0:
		return

	var pos_pj := personaje.global_position if personaje.is_inside_tree() else personaje.position
	var pos_propia := global_position if is_inside_tree() else position
	var dist_h := Vector2(pos_pj.x - pos_propia.x, pos_pj.z - pos_propia.z).length()
	var alt_cabeza := obtener_altura_cabeza_global()
	var radio_trigger := (radio_repulsion_cercania * 0.92) if es_fantasma else radio_repulsion_cercania
	var altura_max := (alt_cabeza + 0.65) if es_fantasma else (alt_cabeza - 0.55)

	if dist_h < radio_trigger and pos_pj.y < altura_max:
		if es_fantasma:
			_cooldown_repulsion_fantasma = 0.65
		else:
			_cooldown_repulsion_vivo = 0.65

		var dir_rep := Vector3(pos_pj.x - pos_propia.x, 0.0, pos_pj.z - pos_propia.z)
		if dir_rep.length_squared() < 0.001:
			dir_rep = Vector3.BACK
		dir_rep = dir_rep.normalized()

		var cb := personaje as CharacterBody3D
		cb.velocity.x = dir_rep.x * velocidad_repulsion_cercania
		cb.velocity.z = dir_rep.z * velocidad_repulsion_cercania
		cb.velocity.y = maxf(cb.velocity.y, 5.2 if es_fantasma else 5.6)
		if "en_vuelo_balistico" in cb:
			cb.set("en_vuelo_balistico", true)

		var registro := _empuje_activo_fantasma if es_fantasma else _empuje_activo_vivo
		registro["tiempo"] = duracion_empuje_repulsion
		registro["dir"] = dir_rep
		registro["fuerza"] = velocidad_repulsion_cercania

		if is_inside_tree():
			var col_fx := Color(0.35, 0.88, 1.0) if es_fantasma else Color(1.0, 0.65, 0.22)
			_crear_rafaga_particulas(pos_pj + Vector3.UP * 0.5, col_fx, 14, 2.0, 5.0, 0.35, 1.05)
		_sacudir_camara(personaje, intensidad_shake_camara * 0.72)

func _actualizar_empujes_repulsion_activos(vivo: Node3D, fantasma: Node3D, delta: float) -> void:
	_procesar_empuje_individual(vivo, _empuje_activo_vivo, delta)
	_procesar_empuje_individual(fantasma, _empuje_activo_fantasma, delta)

func _procesar_empuje_individual(objetivo: Node3D, estado_empuje: Dictionary, delta: float) -> void:
	var t_rest: float = float(estado_empuje.get("tiempo", 0.0))
	if t_rest <= 0.0 or not is_instance_valid(objetivo):
		estado_empuje["tiempo"] = 0.0
		return

	var factor := clampf(t_rest / maxf(duracion_empuje_repulsion, 0.01), 0.0, 1.0)
	var dir: Vector3 = estado_empuje.get("dir", Vector3.BACK)
	var fuerza: float = float(estado_empuje.get("fuerza", velocidad_repulsion_cercania))
	if objetivo.has_method("aplicar_fuerza_vortice"):
		objetivo.aplicar_fuerza_vortice(dir * fuerza * (0.45 + 0.55 * factor) * 2.4, 0.0)
	elif objetivo is CharacterBody3D:
		var cb := objetivo as CharacterBody3D
		var vel_actual := Vector2(cb.velocity.x, cb.velocity.z).length()
		var vel_objetivo := fuerza * (0.55 + 0.45 * factor)
		if vel_actual < vel_objetivo:
			cb.velocity.x = dir.x * vel_objetivo
			cb.velocity.z = dir.z * vel_objetivo
	estado_empuje["tiempo"] = maxf(t_rest - delta, 0.0)

func esta_en_fase_compresion_pisada() -> bool:
	return _en_compresion_pisoton

func obtener_altura_cabeza_global() -> float:
	var pos_base_y: float = global_position.y if is_inside_tree() else position.y
	if is_instance_valid(nodo_visual):
		var s_y: float = absf(nodo_visual.scale.y)
		return pos_base_y + nodo_visual.position.y + (ALTURA_CIMA_BOSS_LOCAL * escala_modelo * s_y)
	return pos_base_y + altura_flotacion + (ALTURA_CIMA_BOSS_LOCAL * escala_modelo)

func esta_activo_para_camara() -> bool:
	return estado_actual != Estado.DERROTADO

func obtener_radio_camara_arena() -> float:
	return radio_activacion_arena + 2.5

func obtener_radio_camara_seguro() -> float:
	return radio_camara_seguro

func obtener_punto_foco_camara() -> Vector3:
	var pos_actual: Vector3 = global_position if is_inside_tree() else position
	var base: Vector3 = _posicion_centro_arena if _centro_arena_inicializado else pos_actual
	if _centro_arena_inicializado and pos_actual.distance_to(_posicion_centro_arena) > maxf(radio_patrulla_centro + 2.5, 5.0):
		base = pos_actual
	if estado_actual == Estado.DORMIDO_ARMADURA:
		return base + Vector3(0.0, 0.95, 0.0)
	return base + Vector3(0.0, 1.35 * escala_modelo, 0.0)

func obtener_intensidad_camara_arena() -> float:
	if estado_actual == Estado.DORMIDO_ARMADURA:
		return 0.55
	if estado_actual == Estado.DESPERTANDO or estado_actual == Estado.ATURDIDO_GOLPE or estado_actual == Estado.INVOCANDO_ESPECTROS:
		return 1.25
	return 1.0

func _verificar_pisoton_vivo(vivo: Node3D) -> bool:
	if estado_actual != Estado.TANGIBLE_VULNERABLE or not _esta_tangible:
		return false
	if not is_instance_valid(vivo):
		return false

	var pos_vivo := vivo.global_position if vivo.is_inside_tree() else vivo.position
	var pos_propia := global_position if is_inside_tree() else position
	var dist_h := Vector2(pos_vivo.x - pos_propia.x, pos_vivo.z - pos_propia.z).length()
	if dist_h > radio_pisoton_cabeza:
		return false

	var vel_y_vivo: float = 0.0
	if vivo is CharacterBody3D:
		vel_y_vivo = (vivo as CharacterBody3D).velocity.y
	if vel_y_vivo > 1.5:
		return false

	var alt_cabeza: float = obtener_altura_cabeza_global()
	var mis_pies: float = pos_vivo.y - ALTURA_PIES_VIVO_LOCAL
	var diff_contacto: float = mis_pies - alt_cabeza

	# Rango generoso alrededor de la coronilla/copete libre de armadura
	if diff_contacto <= 1.05 and diff_contacto >= -1.15:
		recibir_impacto_pisoton(vivo as CharacterBody3D)
		return true

	return false

## El Embate terrestre NO daña al jefe: su armadura sólida obliga a escalar las islas y pisarlo arriba.
func recibir_impacto(_jugador: Node3D) -> void:
	if estado_actual == Estado.DERROTADO or estado_actual == Estado.DORMIDO_ARMADURA:
		return
	if is_inside_tree():
		_crear_rafaga_particulas(global_position + Vector3(0.0, altura_flotacion * 0.65, 0.0), Color(0.95, 0.82, 0.45), 10, 1.5, 3.5, 0.4, 0.8)

func recibir_impacto_pisoton(vivo: CharacterBody3D) -> void:
	if _en_compresion_pisoton or _temporizador_invulnerable > 0.0:
		return
	if estado_actual != Estado.TANGIBLE_VULNERABLE or not _esta_tangible:
		return
	if vida_actual <= 0:
		return

	# Cancelar ground pound del Vivo si estaba activo para garantizar rebote limpio
	if is_instance_valid(vivo) and "_en_ground_pound" in vivo:
		vivo.set("_en_ground_pound", false)

	_cancelar_ataque_activo(false)
	if is_instance_valid(_particulas_congelado):
		_particulas_congelado.emitting = false

	vida_actual = maxi(vida_actual - 1, 0)
	_esta_tangible = false
	_temporizador_gracia_aura = 0.0
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	if is_instance_valid(colision_cuerpo):
		if is_inside_tree():
			colision_cuerpo.set_deferred("disabled", true)
		else:
			colision_cuerpo.disabled = true
	if is_instance_valid(halo_objetivo):
		halo_objetivo.visible = false

	_actualizar_hud_boss()
	boss_danado.emit(vida_actual, vida_maxima)

	var es_golpe_final: bool = (vida_actual <= 0)
	if es_golpe_final:
		estado_actual = Estado.DERROTADO
	else:
		estado_actual = Estado.ATURDIDO_GOLPE
		_temporizador_invulnerable = tiempo_invulnerabilidad_golpe
		estado_cambiado.emit(estado_actual)

	_feedback_golpe(vivo, es_golpe_final)

	# Lanzar al Vivo limpiamente al suelo AL FRENTE del jefe
	var p_b := global_position if is_inside_tree() else position
	var punto_frente := _posicion_centro_arena + Vector3(offset_punto_control.x, 0.0, clampf(offset_punto_control.z, -8.5, 8.5))
	var d_frente := Vector3(punto_frente.x - p_b.x, 0.0, punto_frente.z - p_b.z)
	var dir_salida := d_frente.normalized() if d_frente.length_squared() > 0.05 else Vector3.BACK

	if not es_golpe_final:
		_duracion_enojo_total = maxf(tiempo_invulnerabilidad_golpe, 0.4)
		_tiempo_en_enojo = 0.0
		_pulso_shake_enojo_acum = 0.0
		_onda_enojo_emitida_1 = false
		_onda_enojo_emitida_2 = false
		_rebote_frente_activo = true
		_rebote_frente_timer = 0.68
		_rebote_frente_dir = dir_salida

	if not is_inside_tree() or not is_instance_valid(nodo_visual):
		if is_instance_valid(vivo):
			vivo.velocity.y = 9.8
			vivo.velocity.x = dir_salida.x * 8.4
			vivo.velocity.z = dir_salida.z * 8.4
			if "en_vuelo_balistico" in vivo:
				vivo.set("en_vuelo_balistico", true)
		if es_golpe_final:
			_ejecutar_derrota_inmediata()
		else:
			_establecer_visibilidad_vivo(false)
			_actualizar_subtitulo_hud()
		return

	# Fase breve de compresión elástica sincronizada con el rebote del Vivo
	_en_compresion_pisoton = true
	if is_instance_valid(vivo) and vivo.has_method("iniciar_rebote_sobre_entidad"):
		vivo.iniciar_rebote_sobre_entidad(self)

	if _tween_principal != null and _tween_principal.is_valid():
		_tween_principal.kill()

	var pos_vis_base := Vector3(0.0, altura_flotacion, 0.0)
	_tween_principal = create_tween()
	_tween_principal.tween_method(func(p: float):
		if is_instance_valid(nodo_visual):
			var sy := lerpf(1.0, 0.58, p)
			var sxz := lerpf(1.0, 1.32, p)
			nodo_visual.scale = Vector3(sxz, sy, sxz)
			nodo_visual.position.y = pos_vis_base.y - (0.45 * p)
	, 0.0, 1.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_tween_principal.tween_callback(func():
		_en_compresion_pisoton = false
		if is_instance_valid(vivo):
			vivo.velocity.x = dir_salida.x * 8.4
			vivo.velocity.z = dir_salida.z * 8.4
			if "en_vuelo_balistico" in vivo:
				vivo.set("en_vuelo_balistico", true)
		if es_golpe_final:
			_iniciar_secuencia_derrota()
		else:
			_iniciar_recuperacion_golpe()
	)

func _actualizar_vuelo_rebote_vivo(vivo: Node3D, delta: float) -> void:
	if not _rebote_frente_activo:
		return
	_rebote_frente_timer -= delta
	if _rebote_frente_timer <= 0.0 or not is_instance_valid(vivo):
		_rebote_frente_activo = false
		return
	if _en_compresion_pisoton:
		return
	var en_suelo: bool = vivo.is_on_floor() if (vivo is CharacterBody3D and vivo.is_inside_tree()) else false
	var p_v := vivo.global_position if vivo.is_inside_tree() else vivo.position
	var p_b := global_position if is_inside_tree() else position
	var dist_h := Vector2(p_v.x - p_b.x, p_v.z - p_b.z).length()
	if en_suelo or dist_h >= 7.8:
		_rebote_frente_activo = false
		return
	if vivo.has_method("aplicar_fuerza_vortice"):
		vivo.aplicar_fuerza_vortice(_rebote_frente_dir * 12.0, 0.0)

func _iniciar_recuperacion_golpe() -> void:
	var cambio_estado: bool = (estado_actual != Estado.ATURDIDO_GOLPE)
	estado_actual = Estado.ATURDIDO_GOLPE
	_temporizador_invulnerable = tiempo_invulnerabilidad_golpe
	_duracion_enojo_total = maxf(tiempo_invulnerabilidad_golpe, 0.4)
	_tiempo_en_enojo = 0.0
	_pulso_shake_enojo_acum = 0.0
	_onda_enojo_emitida_1 = false
	_onda_enojo_emitida_2 = false
	if cambio_estado:
		estado_cambiado.emit(estado_actual)
	_establecer_visibilidad_vivo(false)
	if is_instance_valid(_mat_cuerpo):
		_mat_cuerpo.set_shader_parameter("factor_tangible", 0.0)
	_actualizar_subtitulo_hud()

	if not is_inside_tree() or not is_instance_valid(nodo_visual):
		return

	var pos_vis_base := Vector3(0.0, altura_flotacion, 0.0)
	var tw_rec := create_tween()
	tw_rec.tween_property(nodo_visual, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw_rec.parallel().tween_property(nodo_visual, "position:y", pos_vis_base.y, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _procesar_animacion_enojo(progreso: float, vivo: Node3D, fantasma: Node3D, delta: float) -> void:
	var en_furia := (progreso >= 0.14 and progreso <= 0.88)

	if is_instance_valid(_mat_rojo):
		if en_furia:
			var pulso := 0.5 + 0.5 * sin(_tiempo_acumulado * 36.0)
			_mat_rojo.emission = Color(1.0, 0.16, 0.02, 1.0).lerp(Color(1.0, 0.52, 0.08, 1.0), pulso)
			_mat_rojo.emission_energy_multiplier = lerpf(6.5, 10.5, pulso)
		else:
			_mat_rojo.emission = Color(1.0, 0.06, 0.08, 1.0)
			_mat_rojo.emission_energy_multiplier = 4.2

	# Traqueteo y separación de placas de armadura por la furia
	for nombre_pieza in ARMADURA_PIEZAS_ORDEN:
		var pieza := _piezas_armadura.get(nombre_pieza, null) as Node3D
		if not is_instance_valid(pieza):
			continue
		var pose_orig: Dictionary = _armadura_poses_ensambladas.get(nombre_pieza, {"pos": Vector3.ZERO, "rot": Vector3.ZERO})
		var p_orig: Vector3 = pose_orig["pos"]
		var r_orig: Vector3 = pose_orig["rot"]
		if en_furia:
			var dir_exp := p_orig.normalized() if p_orig.length() > 0.05 else Vector3(0.0, 0.5, 0.0)
			var vibr := sin(_tiempo_acumulado * 54.0 + float(nombre_pieza.length())) * 0.09
			pieza.position = p_orig + dir_exp * (0.20 + absf(vibr))
			pieza.rotation = r_orig + Vector3(vibr * 0.35, -vibr * 0.3, vibr * 0.25)
		else:
			pieza.position = pieza.position.lerp(p_orig, clampf(14.0 * delta, 0.0, 1.0))
			pieza.rotation = pieza.rotation.lerp(r_orig, clampf(14.0 * delta, 0.0, 1.0))

	if en_furia:
		_pulso_shake_enojo_acum -= delta
		if _pulso_shake_enojo_acum <= 0.0:
			_pulso_shake_enojo_acum = 0.26
			_sacudir_camara(vivo, intensidad_shake_camara * 1.15)
			_sacudir_camara(fantasma, intensidad_shake_camara * 1.15)
			if is_inside_tree():
				var vm := get_node_or_null("/root/VibrationManager")
				if is_instance_valid(vm) and vm.has_method("vibrar_impacto_fuerte"):
					vm.vibrar_impacto_fuerte()

		var prox_fase := obtener_fase_actual()
		var col_furia := Color(1.0, 0.42, 0.12) if prox_fase == 2 else Color(0.95, 0.22, 0.85)
		var centro_furia := (global_position if is_inside_tree() else position) + Vector3(0.0, altura_flotacion * 0.85, 0.0)
		if progreso >= 0.24 and not _onda_enojo_emitida_1:
			_onda_enojo_emitida_1 = true
			if is_inside_tree():
				_crear_rafaga_particulas(centro_furia, col_furia, 24, 3.2, 7.2, 0.25, 1.35)
		if progreso >= 0.56 and not _onda_enojo_emitida_2:
			_onda_enojo_emitida_2 = true
			if is_inside_tree():
				_crear_rafaga_particulas(centro_furia, col_furia, 28, 3.8, 8.2, 0.35, 1.45)

func _finalizar_animacion_enojo() -> void:
	if is_instance_valid(_mat_rojo):
		_mat_rojo.emission = Color(1.0, 0.06, 0.08, 1.0)
		_mat_rojo.emission_energy_multiplier = 4.2
	if is_instance_valid(nodo_visual):
		nodo_visual.scale = Vector3.ONE
		nodo_visual.rotation = Vector3.ZERO
		nodo_visual.position = Vector3(0.0, altura_flotacion, 0.0)
	_colocar_armadura_ensamblada()

## ─────────────────────────────────────────────────────────────────────────────
## DERROTA FINAL (3ER GOLPE): EL ESPECTRO DESAPARECE Y LA ARMADURA CAE AL SUELO
## ─────────────────────────────────────────────────────────────────────────────

func _ejecutar_derrota_inmediata() -> void:
	estado_actual = Estado.DERROTADO
	_esta_tangible = false
	_visible_vivo_actual = false
	_en_compresion_pisoton = false
	_limpiar_entidades_combate()
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	if is_instance_valid(colision_cuerpo):
		colision_cuerpo.disabled = true

	if is_instance_valid(nodo_visual):
		nodo_visual.scale = Vector3.ONE
		nodo_visual.rotation = Vector3.ZERO
		nodo_visual.position = Vector3(0.0, altura_flotacion, 0.0)
	if is_instance_valid(modelo_espectral):
		modelo_espectral.visible = false
	if is_instance_valid(_silueta_aviso):
		_silueta_aviso.visible = false
	if is_instance_valid(halo_objetivo):
		halo_objetivo.visible = false
	if is_instance_valid(particulas_aura_boss):
		particulas_aura_boss.emitting = false

	# Armadura sólida cae permanentemente al suelo del coliseo
	if is_instance_valid(modelo_armadura):
		modelo_armadura.visible = true
		_asignar_capas_recursivo(modelo_armadura, 1)
	_colocar_armadura_en_suelo(0.0)

	if bajar_plataformas_al_derrotar:
		_descender_plataformas_combate(false)

	estado_cambiado.emit(estado_actual)
	boss_derrotado.emit()
	signal_activado.emit()

func _iniciar_secuencia_derrota() -> void:
	estado_actual = Estado.DERROTADO
	_esta_tangible = false
	_visible_vivo_actual = false
	_animando_transicion = true
	_limpiar_entidades_combate()
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	if is_instance_valid(colision_cuerpo):
		colision_cuerpo.set_deferred("disabled", true)
	if is_instance_valid(halo_objetivo):
		halo_objetivo.visible = false
	if is_instance_valid(particulas_aura_boss):
		particulas_aura_boss.emitting = false

	estado_cambiado.emit(estado_actual)
	boss_derrotado.emit()
	signal_activado.emit()

	# Restaurar escala/rotación base del contenedor Visual antes de disolver el espectro y soltar la armadura
	if is_instance_valid(nodo_visual):
		nodo_visual.scale = Vector3.ONE
		nodo_visual.rotation = Vector3.ZERO
		nodo_visual.position = Vector3(0.0, altura_flotacion, 0.0)

	# 1. El espectro (cuerpo + silueta) se disuelve y desaparece por completo
	if is_instance_valid(_silueta_aviso):
		_silueta_aviso.visible = false
	if is_instance_valid(modelo_espectral):
		_asignar_capas_recursivo(modelo_espectral, 1 | 4)
		var tw_ghost := create_tween().set_parallel(true)
		tw_ghost.tween_method(_set_transparencia_espectral, 0.0, 1.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_ghost.tween_property(modelo_espectral, "scale", Vector3.ONE * (escala_modelo * 0.25), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw_ghost.chain().tween_callback(func():
			if is_instance_valid(modelo_espectral):
				modelo_espectral.visible = false
				modelo_espectral.scale = Vector3.ONE * escala_modelo
		)

	# 2. Todas las piezas sólidas de la armadura CAEN con gravedad y rebote al suelo del coliseo
	_limpiar_tweens_armadura()
	if is_instance_valid(modelo_armadura):
		modelo_armadura.visible = true
		_asignar_capas_recursivo(modelo_armadura, 1)

	var y_suelo_rel: float = _y_suelo_arena - global_position.y
	var idx: int = 0
	for nombre_pieza in ARMADURA_PIEZAS_ORDEN:
		var pieza := _piezas_armadura.get(nombre_pieza, null) as Node3D
		if not is_instance_valid(pieza):
			idx += 1
			continue
		var pose_caida := _calcular_pose_suelo_pieza(nombre_pieza, y_suelo_rel)
		var pos_final: Vector3 = pose_caida["pos"]
		var rot_final: Vector3 = pose_caida["rot"]
		var retardo: float = 0.12 + float(idx) * 0.07
		var dur_caida: float = 0.52 + (0.04 * float(idx))

		var tw_caida := create_tween()
		_tweens_armadura.append(tw_caida)
		tw_caida.tween_interval(retardo)
		# Caída acelerada por gravedad hasta impactar el suelo
		tw_caida.tween_property(pieza, "position", pos_final, dur_caida).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_caida.parallel().tween_property(pieza, "rotation", rot_final, dur_caida).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# Pequeño rebote metálico/pétreo al tocar el suelo del coliseo
		tw_caida.tween_property(pieza, "position:y", pos_final.y + 0.14, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_caida.tween_property(pieza, "position:y", pos_final.y, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw_caida.tween_callback(func():
			if is_inside_tree():
				var pos_polvo := Vector3(global_position.x + pos_final.x * escala_modelo * 0.6, _y_suelo_arena + 0.15, global_position.z + pos_final.z * escala_modelo * 0.6)
				_crear_rafaga_particulas(pos_polvo, Color(0.82, 0.72, 0.52), 6, 0.8, 2.0, 0.3, 0.9)
		)
		idx += 1

	# 3. Descender islas suavemente y ocultar HUD del jefe
	if bajar_plataformas_al_derrotar:
		get_tree().create_timer(1.1).timeout.connect(func():
			if is_instance_valid(self):
				_descender_plataformas_combate(true)
		)
	_ocultar_hud_boss()

## ─────────────────────────────────────────────────────────────────────────────
## ANIMACIÓN PROCEDURAL DE CUERPO Y MANOS SINCRONIZADAS POR ESTADO
## ─────────────────────────────────────────────────────────────────────────────

func _mundo_a_local_espectral(pos_mundo: Vector3) -> Vector3:
	if is_inside_tree() and is_instance_valid(modelo_espectral):
		return modelo_espectral.to_local(pos_mundo)
	var base_vis_y: float = nodo_visual.position.y if is_instance_valid(nodo_visual) else altura_flotacion
	var diff_mundo := pos_mundo - (position + Vector3(0.0, base_vis_y, 0.0))
	var yaw_vis: float = nodo_visual.rotation.y if is_instance_valid(nodo_visual) else 0.0
	var local_rotado := diff_mundo.rotated(Vector3.UP, -(rotation.y + yaw_vis))
	if is_instance_valid(nodo_visual) and absf(nodo_visual.rotation.x) > 0.0001:
		local_rotado = local_rotado.rotated(Vector3.RIGHT, -nodo_visual.rotation.x)
	return local_rotado / maxf(escala_modelo, 0.01)

func _calcular_destino_puno_local() -> Vector3:
	return _mundo_a_local_espectral(_pos_objetivo_puno_mundo)

func _on_estado_cambiado_cristales(_nuevo_estado: int) -> void:
	_actualizar_brillo_cristales_armadura(0.03, false)

func _actualizar_brillo_cristales_armadura(delta: float = 0.016, forzar_inmediato: bool = false) -> void:
	if not is_instance_valid(_mat_cristal_armadura):
		return
	var pulso: float = 4.2 + 0.5 * sin(_tiempo_acumulado * 14.0)
	var albedo_obj := Color(0.72, 0.06, 0.12, 1.0)
	var emision_obj := Color(0.65, 0.04, 0.08, 1.0)
	var energia_obj: float = 0.0
	match estado_actual:
		Estado.APUNTANDO_PLATAFORMA, Estado.ROMPIENDO_PLATAFORMA, Estado.PREPARANDO_APLASTAMIENTO, Estado.APLASTANDO_SUELO, Estado.ATURDIDO_GOLPE:
			albedo_obj = Color(0.95, 0.04, 0.06, 1.0)
			emision_obj = Color(1.0, 0.06, 0.08, 1.0)
			energia_obj = pulso
		Estado.PREPARANDO_TORNADO, Estado.LANZANDO_TORNADO:
			albedo_obj = Color(0.10, 0.58, 1.0, 1.0)
			emision_obj = Color(0.14, 0.72, 1.0, 1.0)
			energia_obj = pulso
		Estado.INVOCANDO_ESPECTROS:
			albedo_obj = Color(0.68, 0.14, 1.0, 1.0)
			emision_obj = Color(0.75, 0.18, 1.0, 1.0)
			energia_obj = pulso
		Estado.COMBATE_INTANGIBLE:
			albedo_obj = Color(0.84, 0.07, 0.14, 1.0)
			emision_obj = Color(0.85, 0.05, 0.09, 1.0)
			energia_obj = 0.35
		_:
			albedo_obj = Color(0.72, 0.06, 0.12, 1.0)
			emision_obj = Color(0.65, 0.04, 0.08, 1.0)
			energia_obj = 0.0

	_mat_cristal_armadura.emission_enabled = true
	var factor: float = 1.0 if forzar_inmediato else clampf(maxf(delta, 0.008) * 12.0, 0.0, 1.0)
	_mat_cristal_armadura.albedo_color = _mat_cristal_armadura.albedo_color.lerp(albedo_obj, factor)
	_mat_cristal_armadura.emission = _mat_cristal_armadura.emission.lerp(emision_obj, factor)
	_mat_cristal_armadura.emission_energy_multiplier = lerpf(_mat_cristal_armadura.emission_energy_multiplier, energia_obj, factor)

func _restaurar_escala_y_rotacion_manos() -> void:
	for m_izq in [_glb_mano_izq, _silueta_mano_izq]:
		if is_instance_valid(m_izq):
			m_izq.scale = _escala_base_glb_izq
			m_izq.rotation = Vector3.ZERO
	if is_instance_valid(_arm_mano_izq):
		_arm_mano_izq.scale = _escala_base_arm_izq
		_arm_mano_izq.rotation = Vector3.ZERO
	for m_der in [_glb_mano_der, _silueta_mano_der]:
		if is_instance_valid(m_der):
			m_der.scale = _escala_base_glb_der
			m_der.rotation = Vector3.ZERO
	if is_instance_valid(_arm_mano_der):
		_arm_mano_der.scale = _escala_base_arm_der
		_arm_mano_der.rotation = Vector3.ZERO

func _animar_flotacion_y_manos(delta: float) -> void:
	_actualizar_brillo_cristales_armadura(delta, false)
	if not is_instance_valid(nodo_visual) or _animando_transicion or _en_compresion_pisoton:
		return

	var offset_y_base := altura_flotacion
	var offset_x_temblor := 0.0
	var offset_z_temblor := 0.0
	var pitch_obj := 0.0
	var yaw_vis_obj := 0.0
	var escala_vis_obj := Vector3.ONE

	var offset_izq := Vector3.ZERO
	var offset_der := Vector3.ZERO
	var rot_z_izq := sin(_tiempo_acumulado * 1.9) * 0.12
	var rot_z_der := -sin(_tiempo_acumulado * 1.9) * 0.12
	var rot_x_izq := 0.0
	var rot_x_der := 0.0
	var rot_y_izq := 0.0
	var rot_y_der := 0.0
	var escala_mult_izq := 1.0
	var escala_mult_der := 1.0
	var usar_pos_absoluta_izq := false
	var usar_pos_absoluta_der := false
	var pos_abs_izq := Vector3.ZERO
	var pos_abs_der := Vector3.ZERO

	match estado_actual:
		Estado.ATURDIDO_GOLPE:
			var p_e := clampf(_tiempo_en_enojo / maxf(_duracion_enojo_total, 0.01), 0.0, 1.0)
			if p_e >= 0.14 and p_e <= 0.88:
				offset_x_temblor = sin(_tiempo_acumulado * 58.0) * 0.17
				offset_z_temblor = cos(_tiempo_acumulado * 47.0) * 0.12
				offset_y_base += 0.24 + absf(sin(_tiempo_acumulado * 22.0)) * 0.18
				pitch_obj = -0.22 + sin(_tiempo_acumulado * 26.0) * 0.12
				escala_vis_obj = Vector3(1.06 + sin(_tiempo_acumulado * 30.0) * 0.04, 0.96, 1.06 + sin(_tiempo_acumulado * 30.0) * 0.04)
				var golpeteo := sin(_tiempo_acumulado * 24.0)
				offset_izq = Vector3(-0.35, 0.36 + golpeteo * 0.48, 0.42)
				offset_der = Vector3(0.35, 0.36 - golpeteo * 0.48, 0.42)
				rot_z_izq = -0.55 + golpeteo * 0.35
				rot_z_der = 0.55 - golpeteo * 0.35
				rot_x_izq = 0.45
				rot_x_der = 0.45
				escala_mult_izq = 1.16
				escala_mult_der = 1.16
			else:
				offset_y_base += sin(_tiempo_acumulado * 4.0) * 0.1
		Estado.TANGIBLE_VULNERABLE:
			# Congelado tiritando por el Aura del Fantasma
			offset_y_base += sin(_tiempo_acumulado * 6.0) * 0.07
			offset_x_temblor = sin(_tiempo_acumulado * 48.0) * 0.08
			offset_izq = Vector3(0.15, -0.25, 0.1)
			offset_der = Vector3(-0.15, -0.25, 0.1)
			rot_z_izq = 0.25
			rot_z_der = -0.25
		Estado.PREPARANDO_TORNADO:
			offset_y_base += sin(_tiempo_acumulado * 5.0) * 0.16
			pitch_obj = -0.14
			var giro := _tiempo_acumulado * 8.5
			offset_izq = Vector3(cos(giro) * 0.22 - 0.18, sin(giro) * 0.24 + 0.12, -0.1)
			offset_der = Vector3(-cos(giro) * 0.22 + 0.18, -sin(giro) * 0.24 + 0.12, -0.1)
			rot_z_izq = sin(_tiempo_acumulado * 10.0) * 0.35
			rot_z_der = -sin(_tiempo_acumulado * 10.0) * 0.35
		Estado.LANZANDO_TORNADO:
			offset_y_base += sin(_tiempo_acumulado * 3.0) * 0.1
			pitch_obj = 0.18
			offset_izq = Vector3(0.28, 0.08, 0.90)
			offset_der = Vector3(-0.28, 0.08, 0.90)
			rot_z_izq = -0.22
			rot_z_der = 0.22
		Estado.APUNTANDO_PLATAFORMA:
			offset_y_base += 0.12 + sin(_tiempo_acumulado * 7.5) * 0.08
			pitch_obj = -0.10
			var vib := Vector3(sin(_tiempo_acumulado * 42.0) * 0.07, cos(_tiempo_acumulado * 38.0) * 0.05, 0.0)
			var lado := float(_mano_golpe_actual if _mano_golpe_actual != 0 else -1)
			yaw_vis_obj = -0.32 * lado
			if lado < 0.0:
				offset_izq = Vector3(-1.35, 0.18, -0.35) + vib
				rot_z_izq = -0.58
				rot_x_izq = -0.22
				escala_mult_izq = 1.12
				offset_der = Vector3(0.18, -0.04, 0.22)
				rot_z_der = 0.16
			else:
				offset_der = Vector3(1.35, 0.18, -0.35) + vib
				rot_z_der = 0.58
				rot_x_der = -0.22
				escala_mult_der = 1.12
				offset_izq = Vector3(-0.18, -0.04, 0.22)
				rot_z_izq = -0.16
		Estado.ROMPIENDO_PLATAFORMA:
			offset_y_base += 0.02
			var lado := float(_mano_golpe_actual if _mano_golpe_actual != 0 else -1)
			if _tiempo_estado_ruptura < 0.24:
				yaw_vis_obj = lerpf(-0.32 * lado, 0.22 * lado, _progreso_puno)
			elif _tiempo_estado_ruptura < 0.40:
				yaw_vis_obj = lerpf(0.22 * lado, 0.44 * lado, smoothstep(0.0, 1.0, _progreso_barrido))
			else:
				yaw_vis_obj = lerpf(0.44 * lado, 0.0, 1.0 - _progreso_puno)
			pitch_obj = 0.16 * _progreso_puno

			nodo_visual.position = Vector3(offset_x_temblor, offset_y_base, offset_z_temblor)
			nodo_visual.scale = nodo_visual.scale.lerp(escala_vis_obj, clampf(14.0 * delta, 0.0, 1.0))
			nodo_visual.rotation.x = lerpf(nodo_visual.rotation.x, pitch_obj, clampf(12.0 * delta, 0.0, 1.0))
			nodo_visual.rotation.y = lerpf(nodo_visual.rotation.y, yaw_vis_obj, clampf(14.0 * delta, 0.0, 1.0))

			var dest_local := _calcular_destino_puno_local()
			var base_activa := _pos_base_mano_der if lado > 0.0 else _pos_base_mano_izq
			var p_inicio := base_activa + Vector3(lado * 1.35, 0.12, -0.32)
			var p_flanco := dest_local + Vector3(lado * 1.65, -0.02, -0.10)
			var p_impacto := dest_local + Vector3(0.0, -0.02, 0.0)
			var p_atravesar := dest_local + Vector3(-lado * 1.40, 0.0, 0.20)
			var pos_barrido := base_activa

			if _tiempo_estado_ruptura < 0.24:
				var u := _progreso_puno
				var ab := p_inicio.lerp(p_flanco, u)
				var bc := p_flanco.lerp(p_impacto, u)
				pos_barrido = ab.lerp(bc, u)
			elif _tiempo_estado_ruptura < 0.40:
				var s := smoothstep(0.0, 1.0, _progreso_barrido)
				pos_barrido = p_impacto.lerp(p_atravesar, s)
			else:
				pos_barrido = p_atravesar.lerp(base_activa, 1.0 - _progreso_puno)

			if lado < 0.0:
				usar_pos_absoluta_izq = true
				pos_abs_izq = pos_barrido
				rot_x_izq = lerpf(-0.18, 0.25, _progreso_puno)
				rot_z_izq = lerpf(-0.55, 0.48, _progreso_barrido if _tiempo_estado_ruptura >= 0.24 else _progreso_puno * 0.4)
				escala_mult_izq = lerpf(1.0, 1.24, _progreso_puno)
				offset_der = Vector3(0.14, -0.08, -0.18)
				rot_z_der = 0.18
			else:
				usar_pos_absoluta_der = true
				pos_abs_der = pos_barrido
				rot_x_der = lerpf(-0.18, 0.25, _progreso_puno)
				rot_z_der = lerpf(0.55, -0.48, _progreso_barrido if _tiempo_estado_ruptura >= 0.24 else _progreso_puno * 0.4)
				escala_mult_der = lerpf(1.0, 1.24, _progreso_puno)
				offset_izq = Vector3(-0.14, -0.08, -0.18)
				rot_z_izq = -0.18
		Estado.INVOCANDO_ESPECTROS:
			var t_inv := clampf(_tiempo_estado_invocacion / maxf(_duracion_invocacion, 0.01), 0.0, 1.0)
			if t_inv < 0.52:
				var p_sub := t_inv / 0.52
				var vib_i := Vector3(sin(_tiempo_acumulado * 38.0) * 0.06, cos(_tiempo_acumulado * 34.0) * 0.05, 0.0)
				offset_y_base += lerpf(0.0, 0.92, smoothstep(0.0, 1.0, p_sub)) + sin(_tiempo_acumulado * 7.0) * 0.10
				pitch_obj = lerpf(0.0, -0.28, p_sub)
				offset_izq = Vector3(-0.62, 0.85, 0.12) * p_sub + vib_i
				offset_der = Vector3(0.62, 0.85, 0.12) * p_sub + vib_i
				rot_z_izq = lerpf(0.0, -0.78, p_sub)
				rot_z_der = lerpf(0.0, 0.78, p_sub)
				escala_mult_izq = lerpf(1.0, 1.18, p_sub)
				escala_mult_der = lerpf(1.0, 1.18, p_sub)
			else:
				var p_rel := clampf((t_inv - 0.52) / 0.48, 0.0, 1.0)
				var impulso_bajada := 1.0 - smoothstep(0.0, 1.0, p_rel)
				offset_y_base += lerpf(0.92, 0.0, p_rel)
				pitch_obj = lerpf(0.24, 0.0, p_rel)
				offset_izq = Vector3(-0.52, -0.22, 0.68) * impulso_bajada
				offset_der = Vector3(0.52, -0.22, 0.68) * impulso_bajada
				rot_z_izq = -0.45 * impulso_bajada
				rot_z_der = 0.45 * impulso_bajada
				rot_x_izq = 0.55 * impulso_bajada
				rot_x_der = 0.55 * impulso_bajada
		Estado.PREPARANDO_APLASTAMIENTO:
			offset_y_base += 0.28 + sin(_tiempo_acumulado * 8.0) * 0.08
			pitch_obj = -0.16
			var lado_prep := float(_mano_golpe_actual if _mano_golpe_actual != 0 else -1)
			yaw_vis_obj = -0.20 * lado_prep
			nodo_visual.position = Vector3(offset_x_temblor, offset_y_base, offset_z_temblor)
			nodo_visual.scale = nodo_visual.scale.lerp(escala_vis_obj, clampf(14.0 * delta, 0.0, 1.0))
			nodo_visual.rotation.x = lerpf(nodo_visual.rotation.x, pitch_obj, clampf(12.0 * delta, 0.0, 1.0))
			nodo_visual.rotation.y = lerpf(nodo_visual.rotation.y, yaw_vis_obj, clampf(14.0 * delta, 0.0, 1.0))

			var vib_ap := Vector3(sin(_tiempo_acumulado * 45.0) * 0.05, cos(_tiempo_acumulado * 40.0) * 0.06, 0.0)
			var pos_obj_prep_local := _mundo_a_local_espectral(_pos_objetivo_aplastamiento_mundo)
			var pos_arriba_local := _mundo_a_local_espectral(_pos_objetivo_aplastamiento_mundo + Vector3(0.0, 3.6, 0.0)) + vib_ap
			var base_prep := _pos_base_mano_der if lado_prep > 0.0 else _pos_base_mano_izq
			var ang_frente_prep := atan2(pos_obj_prep_local.x - base_prep.x * 0.25, maxf(pos_obj_prep_local.z, 0.25))
			var yaw_frente_prep := (-lado_prep * PI * 0.5) + ang_frente_prep
			if lado_prep < 0.0:
				usar_pos_absoluta_izq = true
				pos_abs_izq = pos_arriba_local
				rot_x_izq = 0.0
				rot_y_izq = yaw_frente_prep
				rot_z_izq = -0.32
				escala_mult_izq = 1.22
				offset_der = Vector3(0.18, -0.04, 0.22)
				rot_z_der = 0.16
			else:
				usar_pos_absoluta_der = true
				pos_abs_der = pos_arriba_local
				rot_x_der = 0.0
				rot_y_der = yaw_frente_prep
				rot_z_der = 0.32
				escala_mult_der = 1.22
				offset_izq = Vector3(-0.18, -0.04, 0.22)
				rot_z_izq = -0.16
		Estado.APLASTANDO_SUELO:
			var t_ap := _tiempo_estado_aplastamiento
			var lado_ap := float(_mano_golpe_actual if _mano_golpe_actual != 0 else -1)
			var base_activa_ap := _pos_base_mano_der if lado_ap > 0.0 else _pos_base_mano_izq
			if t_ap < 0.18:
				yaw_vis_obj = lerpf(-0.20 * lado_ap, 0.18 * lado_ap, clampf(t_ap / 0.18, 0.0, 1.0))
				pitch_obj = lerpf(-0.12, 0.22, clampf(t_ap / 0.18, 0.0, 1.0))
			elif t_ap < 0.56:
				yaw_vis_obj = 0.18 * lado_ap
				pitch_obj = 0.20
			else:
				var r_vis := clampf((t_ap - 0.56) / 0.30, 0.0, 1.0)
				yaw_vis_obj = lerpf(0.18 * lado_ap, 0.0, r_vis)
				pitch_obj = lerpf(0.20, 0.0, r_vis)

			nodo_visual.position = Vector3(offset_x_temblor, offset_y_base, offset_z_temblor)
			nodo_visual.scale = nodo_visual.scale.lerp(escala_vis_obj, clampf(14.0 * delta, 0.0, 1.0))
			nodo_visual.rotation.x = lerpf(nodo_visual.rotation.x, pitch_obj, clampf(14.0 * delta, 0.0, 1.0))
			nodo_visual.rotation.y = lerpf(nodo_visual.rotation.y, yaw_vis_obj, clampf(14.0 * delta, 0.0, 1.0))

			var p_arriba := _mundo_a_local_espectral(_pos_objetivo_aplastamiento_mundo + Vector3(0.0, 3.6, 0.0))
			var p_suelo := _mundo_a_local_espectral(_pos_objetivo_aplastamiento_mundo + Vector3(0.0, 0.35, 0.0))
			var pos_aplast := base_activa_ap
			var ang_frente_ap := atan2(p_suelo.x - base_activa_ap.x * 0.25, maxf(p_suelo.z, 0.25))
			var yaw_puno_frente := (-lado_ap * PI * 0.5) + ang_frente_ap
			var rot_y_ap := yaw_puno_frente
			var rot_z_ap := -0.14 * lado_ap
			var escala_ap := 1.0
			if t_ap < 0.18:
				var s_ap := clampf(t_ap / 0.18, 0.0, 1.0)
				var ease_ap := s_ap * s_ap
				pos_aplast = p_arriba.lerp(p_suelo, ease_ap)
				rot_z_ap = lerpf(0.32 * lado_ap, -0.14 * lado_ap, ease_ap)
				escala_ap = lerpf(1.22, 1.32, ease_ap)
			elif t_ap < 0.56:
				pos_aplast = p_suelo
				rot_z_ap = -0.14 * lado_ap
				escala_ap = 1.32
			else:
				var r_ap := smoothstep(0.0, 1.0, clampf((t_ap - 0.56) / 0.30, 0.0, 1.0))
				pos_aplast = p_suelo.lerp(base_activa_ap, r_ap)
				rot_y_ap = lerpf(yaw_puno_frente, 0.0, r_ap)
				rot_z_ap = lerpf(-0.14 * lado_ap, 0.0, r_ap)
				escala_ap = lerpf(1.32, 1.0, r_ap)

			if lado_ap < 0.0:
				usar_pos_absoluta_izq = true
				pos_abs_izq = pos_aplast
				rot_x_izq = 0.0
				rot_y_izq = rot_y_ap
				rot_z_izq = rot_z_ap
				escala_mult_izq = escala_ap
				offset_der = Vector3(0.14, -0.08, -0.18)
				rot_z_der = 0.18
			else:
				usar_pos_absoluta_der = true
				pos_abs_der = pos_aplast
				rot_x_der = 0.0
				rot_y_der = rot_y_ap
				rot_z_der = rot_z_ap
				escala_mult_der = escala_ap
				offset_izq = Vector3(-0.14, -0.08, -0.18)
				rot_z_izq = -0.18
		_:
			offset_y_base += sin(_tiempo_acumulado * 2.4) * 0.22
			offset_izq = Vector3(0.0, cos(_tiempo_acumulado * 2.5 + 0.4) * 0.12, 0.0)
			offset_der = Vector3(0.0, sin(_tiempo_acumulado * 2.5) * 0.12, 0.0)

	if not (estado_actual in [Estado.ROMPIENDO_PLATAFORMA, Estado.PREPARANDO_APLASTAMIENTO, Estado.APLASTANDO_SUELO]):
		nodo_visual.position.x = offset_x_temblor
		nodo_visual.position.y = offset_y_base
		nodo_visual.position.z = offset_z_temblor
		nodo_visual.scale = nodo_visual.scale.lerp(escala_vis_obj, clampf(14.0 * delta, 0.0, 1.0))
		nodo_visual.rotation.x = lerpf(nodo_visual.rotation.x, pitch_obj, clampf(12.0 * delta, 0.0, 1.0))
		nodo_visual.rotation.y = lerpf(nodo_visual.rotation.y, yaw_vis_obj, clampf(14.0 * delta, 0.0, 1.0))

	var pos_izq := pos_abs_izq if usar_pos_absoluta_izq else (_pos_base_mano_izq + offset_izq)
	var pos_der := pos_abs_der if usar_pos_absoluta_der else (_pos_base_mano_der + offset_der)

	if is_instance_valid(_particulas_carga):
		if estado_actual in [Estado.APUNTANDO_PLATAFORMA, Estado.PREPARANDO_APLASTAMIENTO]:
			_particulas_carga.position = (pos_izq if _mano_golpe_actual <= 0 else pos_der) * escala_modelo
		else:
			_particulas_carga.position = Vector3.ZERO

	for m_izq in [_glb_mano_izq, _silueta_mano_izq]:
		if is_instance_valid(m_izq):
			m_izq.position = pos_izq
			m_izq.rotation = Vector3(rot_x_izq, rot_y_izq, rot_z_izq)
			m_izq.scale = _escala_base_glb_izq * escala_mult_izq
	if is_instance_valid(_arm_mano_izq):
		_arm_mano_izq.position = pos_izq + _arm_offset_mano_izq
		_arm_mano_izq.rotation = Vector3(rot_x_izq, rot_y_izq, rot_z_izq)
		_arm_mano_izq.scale = _escala_base_arm_izq * escala_mult_izq

	for m_der in [_glb_mano_der, _silueta_mano_der]:
		if is_instance_valid(m_der):
			m_der.position = pos_der
			m_der.rotation = Vector3(rot_x_der, rot_y_der, rot_z_der)
			m_der.scale = _escala_base_glb_der * escala_mult_der
	if is_instance_valid(_arm_mano_der):
		_arm_mano_der.position = pos_der + _arm_offset_mano_der
		_arm_mano_der.rotation = Vector3(rot_x_der, rot_y_der, rot_z_der)
		_arm_mano_der.scale = _escala_base_arm_der * escala_mult_der

## ─────────────────────────────────────────────────────────────────────────────
## FEEDBACK SENSORIAL (PARTÍCULAS, HIT-STOP, SHAKE) Y HUD DE 3 PUNTOS DE VIDA
## ─────────────────────────────────────────────────────────────────────────────

func _feedback_golpe(vivo: Node3D, es_final: bool) -> void:
	if not is_inside_tree():
		return
	var pos_cima := Vector3(global_position.x, obtener_altura_cabeza_global(), global_position.z)
	_crear_rafaga_particulas(pos_cima, Color(0.35, 0.9, 1.0) if not es_final else Color(1.0, 0.28, 0.35), 24 if not es_final else 42, 2.0, 5.2, 1.0, 1.35)
	_sacudir_camara(vivo, intensidad_shake_camara * (1.5 if es_final else 1.0))
	_hit_stop(duracion_hit_stop * (1.4 if es_final else 1.0))
	var vm := get_node_or_null("/root/VibrationManager")
	if is_instance_valid(vm) and vm.has_method("vibrar_impacto_fuerte"):
		vm.vibrar_impacto_fuerte()

func _hit_stop(dur: float) -> void:
	if dur <= 0.0 or _hit_stop_activo or not is_inside_tree():
		return
	_hit_stop_activo = true
	Engine.time_scale = 0.15
	get_tree().create_timer(dur, true, false, true).timeout.connect(BossEspectral._restaurar_tiempo)

static func _restaurar_tiempo() -> void:
	Engine.time_scale = 1.0
	_hit_stop_activo = false

func _sacudir_camara(objetivo: Node3D, fuerza: float) -> void:
	if fuerza <= 0.0 or not is_instance_valid(objetivo) or not objetivo.has_method("obtener_camara"):
		return
	var cam := objetivo.obtener_camara() as Camera3D
	if not is_instance_valid(cam):
		return
	var tw := cam.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_method(func(prog: float):
		if is_instance_valid(cam):
			var amort := (1.0 - prog) * fuerza
			cam.h_offset = randf_range(-1.0, 1.0) * amort
			cam.v_offset = randf_range(-1.0, 1.0) * amort
	, 0.0, 1.0, 0.28)
	tw.tween_callback(func():
		if is_instance_valid(cam):
			cam.h_offset = 0.0
			cam.v_offset = 0.0
	)

func _crear_rafaga_particulas(pos: Vector3, color: Color, cantidad: int, vel_min: float, vel_max: float, subida: float, escala: float = 1.0) -> void:
	var padre: Node = get_tree().current_scene if (is_inside_tree() and get_tree().current_scene != null) else (get_parent() if is_inside_tree() else null)
	if padre == null:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = cantidad
	p.lifetime = 0.95
	p.explosiveness = 0.92
	p.direction = Vector3.UP
	p.spread = 65.0
	p.initial_velocity_min = vel_min
	p.initial_velocity_max = vel_max
	p.gravity = Vector3(0.0, 1.6 * subida, 0.0)
	p.damping_min = 1.2
	p.damping_max = 2.4
	p.scale_amount_min = 0.7 * escala
	p.scale_amount_max = 1.2 * escala

	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.5))
	c.add_point(Vector2(0.2, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = c

	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.18, 1.0])
	p.color_ramp = g

	var malla := SphereMesh.new()
	malla.radius = 0.10
	malla.height = 0.20
	malla.radial_segments = 6
	malla.rings = 3
	p.mesh = malla

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = color
	p.material_override = mat
	p.layers = 1 | 4 # Visible para ambos
	padre.add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.2, true, false, true).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free()
	)

func _crear_hud_boss() -> void:
	if Engine.is_editor_hint() or not is_inside_tree() or is_instance_valid(_hud_canvas):
		return
	var padre: Node = get_tree().current_scene
	if padre == null:
		return

	_hud_canvas = CanvasLayer.new()
	_hud_canvas.name = "BossEspectralHUD"
	_hud_canvas.layer = 50
	padre.add_child(_hud_canvas)

	_hud_raiz = Control.new()
	_hud_raiz.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hud_raiz.offset_top = 20.0
	_hud_raiz.offset_bottom = 132.0
	_hud_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_raiz.modulate.a = 0.0
	_hud_canvas.add_child(_hud_raiz)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER_TOP)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	_hud_raiz.add_child(vbox)

	var lbl := Label.new()
	lbl.text = nombre_boss
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.98, 0.93, 0.82))
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(lbl)

	_hud_subtitulo_lbl = Label.new()
	_hud_subtitulo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_subtitulo_lbl.add_theme_font_size_override("font_size", 14)
	_hud_subtitulo_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_hud_subtitulo_lbl.add_theme_constant_override("shadow_offset_x", 1)
	_hud_subtitulo_lbl.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(_hud_subtitulo_lbl)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 14)
	vbox.add_child(hbox)

	_hud_pips.clear()
	for i in range(vida_maxima):
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(36, 16)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.92, 0.14, 0.22, 0.95)
		sb.border_color = Color(1.0, 0.84, 0.48, 0.95)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		pip.add_theme_stylebox_override("panel", sb)
		hbox.add_child(pip)
		_hud_pips.append(pip)

	_actualizar_subtitulo_hud()
	var tw := _hud_raiz.create_tween()
	tw.tween_property(_hud_raiz, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)

func _actualizar_subtitulo_hud() -> void:
	if not is_instance_valid(_hud_subtitulo_lbl):
		return
	if estado_actual == Estado.TANGIBLE_VULNERABLE:
		_hud_subtitulo_lbl.text = "¡CONGELADO! ¡SALTA SOBRE SU CABEZA!"
		_hud_subtitulo_lbl.add_theme_color_override("font_color", Color(0.45, 0.96, 1.0))
		return
	if estado_actual == Estado.ATURDIDO_GOLPE:
		_hud_subtitulo_lbl.text = "¡EL ESPECTRO SE ENFURECE!"
		_hud_subtitulo_lbl.add_theme_color_override("font_color", Color(1.0, 0.34, 0.14))
		return
	if estado_actual == Estado.INVOCANDO_ESPECTROS:
		_hud_subtitulo_lbl.text = "¡INVOCANDO MINI ESPECTROS!"
		_hud_subtitulo_lbl.add_theme_color_override("font_color", Color(0.86, 0.42, 1.0))
		return
	match obtener_fase_actual():
		2:
			_hud_subtitulo_lbl.text = "FASE II · TORMENTA ESPIRAL"
			_hud_subtitulo_lbl.add_theme_color_override("font_color", Color(1.0, 0.72, 0.34))
		3:
			_hud_subtitulo_lbl.text = "FASE III · FURIA ESPECTRAL"
			_hud_subtitulo_lbl.add_theme_color_override("font_color", Color(0.96, 0.42, 0.98))
		_:
			_hud_subtitulo_lbl.text = "FASE I · GUARDIÁN DE PIEDRA"
			_hud_subtitulo_lbl.add_theme_color_override("font_color", Color(0.90, 0.84, 0.72))

func _actualizar_hud_boss() -> void:
	for i in range(_hud_pips.size()):
		var pip := _hud_pips[i]
		if not is_instance_valid(pip):
			continue
		var sb := pip.get_theme_stylebox("panel") as StyleBoxFlat
		if sb == null:
			continue
		var activo: bool = i < vida_actual
		sb.bg_color = Color(0.92, 0.14, 0.22, 0.95) if activo else Color(0.16, 0.14, 0.18, 0.65)
		sb.border_color = Color(1.0, 0.84, 0.48, 0.95) if activo else Color(0.35, 0.32, 0.38, 0.5)
	_actualizar_subtitulo_hud()

func _ocultar_hud_boss() -> void:
	if not is_instance_valid(_hud_canvas) or not is_instance_valid(_hud_raiz):
		return
	var canvas_ref := _hud_canvas
	_hud_canvas = null
	var tw := _hud_raiz.create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(_hud_raiz, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		if is_instance_valid(canvas_ref):
			canvas_ref.queue_free()
	)
