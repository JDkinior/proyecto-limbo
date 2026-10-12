@tool
extends StaticBody3D
class_name IslaFlotante

## ==============================================================================
## GENERADOR PROCEDURAL DE ISLAS FLOTANTES LOW-POLY (GODOT 4) - PROYECTO LIMBO
## Genera geometría 3D procedural estilizada con superficie transitable dorada,
## faldón perimetral de pasto colgante, cuerpo rocoso facetado con múltiples picos
## y rocas satélite flotantes. Adaptado a la iluminación y filtros de Reino Vivo y Fantasma.
## ==============================================================================

enum PresetTamano {
	PERSONALIZADA,
	PEQUENA,
	MEDIANA,
	GRANDE
}

enum EstiloMontana {
	COLINA_SUAVE,
	PICO_ROCOSO,
	MESETA_TERRAZA,
	CORDILLERA_CRESTA,
	CRATER_VALLE
}

enum ModoPincelTerreno {
	ELEVAR,
	HUNDIR,
	APLANAR_TERRAZA,
	SUAVIZAR,
	REDUCIR_A_BASE
}

enum FormaPincelTerreno {
	CONICA_LOWPOLY,
	MESETA_PLANA,
	CUPULA_SUAVE
}

enum EstiloMeseta {
	TERRAZAS_CONCENTRICAS,  ## Niveles concéntricos escalonados en anillos transitables
	ESCALONADO_DIRECCIONAL, ## Gradas y repisas escalonadas en una dirección
	PLATAFORMAS_ORGANICAS,  ## Bloques y plataformas discretas distribuidas por el terreno
	MESETA_CENTRAL_ELEVADA  ## Meseta principal prominente en el centro rodeada de niveles inferiores
}

enum TipoComportamiento {
	ESTANDAR,   ## Isla flotante fija normal (Estructura Global).
	COLAPSO,    ## Se estremece y cae al abismo al ser pisada, luego reaparece.
	ESPIRITUAL  ## Conectada a mecanismos espirituales (Aura/Presión), intangible para el Vivo hasta activarse.
}

# Señales de eventos funcionales de plataforma
signal plataforma_colapsando
signal plataforma_restaurada
signal estado_espiritual_cambiado(activo: bool)

@export_group("Tipo de Plataforma y Comportamiento")
## Selecciona el comportamiento funcional de la isla:
## - ESTANDAR: Terreno flotante firme normal (Capa 1 Estructura Global).
## - COLAPSO: Se desmorona y cae temporalmente al ser pisada por el jugador.
## - ESPIRITUAL: Isla translúcida del plano espiritual que se activa con mecanismos.
@export var tipo_comportamiento: TipoComportamiento = TipoComportamiento.ESTANDAR:
	set(valor):
		tipo_comportamiento = valor
		if is_inside_tree():
			_al_cambiar_tipo_comportamiento()

@export_subgroup("Mecánica Colapso")
## Segundos de vibración y advertencia antes de que la isla caiga.
@export_range(0.1, 5.0, 0.1) var delay_antes_caida: float = 0.6

## Cuánto tarda en caer y desaparecer en el abismo (segundos).
@export_range(0.2, 5.0, 0.1) var duracion_caida: float = 1.0

## Distancia vertical en metros que desciende durante la caída.
@export_range(1.0, 25.0, 0.5) var distancia_caida: float = 5.0

## Tiempo que permanece oculta antes de reaparecer (segundos).
@export_range(1.0, 30.0, 0.5) var tiempo_respawn: float = 8.0

## Material opcional de alerta o emisión durante el temblor previo.
@export var material_alerta: Material = null

## Material opcional normal (para compatibilidad con escenas de colapso existentes).
@export var material_normal: Material = null:
	set(valor):
		material_normal = valor
		if valor != null:
			material_roca = valor
			material_hierba = valor

@export_subgroup("Mecánica Espiritual")
## Disparador principal (InterruptorAura, BotonPresion, Palanca, etc.)
@export var disparador_objetivo: Node3D = null

## Lista opcional de disparadores adicionales para activar la plataforma.
@export var disparadores_objetivo: Array[Node3D] = []

## Lógica de combinación: OR (cualquiera activa) o AND (todos requeridos).
@export var condicion_combinacion: ElementoInteractivoBase.CondicionCombinacion = ElementoInteractivoBase.CondicionCombinacion.CONDICION_O

## Opacidad cuando la plataforma está activada por el mecanismo (sólida para el Vivo y Fantasma).
@export_range(0.0, 1.0, 0.05) var opacidad_activa: float = 1.0:
	set(valor):
		opacidad_activa = clampf(valor, 0.0, 1.0)
		if tipo_comportamiento == TipoComportamiento.ESPIRITUAL:
			_actualizar_materiales()

## Opacidad cuando la plataforma está inactiva (sólida solo para el Fantasma).
@export_range(0.0, 1.0, 0.05) var opacidad_inactiva: float = 0.45:
	set(valor):
		opacidad_inactiva = clampf(valor, 0.0, 1.0)
		if tipo_comportamiento == TipoComportamiento.ESPIRITUAL:
			_actualizar_materiales()

## Material con shader espiritual personalizado (por defecto usa m_isla_espiritual.tres).
@export var material_espiritual: Material = null:
	set(valor):
		material_espiritual = valor
		_mat_espiritual_instancia = null
		if tipo_comportamiento == TipoComportamiento.ESPIRITUAL:
			_actualizar_materiales()

@export_group("Presets de Tamaño")
## Selecciona un preset predefinido o personaliza los parámetros individualmente.
@export var preset: PresetTamano = PresetTamano.MEDIANA:
	set(valor):
		preset = valor
		_aplicar_preset(valor)

@export_group("Dimensiones de la Isla")
## Ancho total aproximado de la isla en el eje X (metros).
@export_range(2.0, 80.0, 0.5, "or_greater") var ancho: float = 12.0:
	set(valor):
		ancho = maxf(valor, 2.0)
		_marcar_cambio_manual()

## Largo total aproximado de la isla en el eje Z (metros).
@export_range(2.0, 80.0, 0.5, "or_greater") var largo: float = 14.0:
	set(valor):
		largo = maxf(valor, 2.0)
		_marcar_cambio_manual()

## Profundidad vertical del cuerpo rocoso hacia abajo en el eje Y (metros).
@export_range(1.0, 60.0, 0.5, "or_greater") var profundidad_roca: float = 8.5:
	set(valor):
		profundidad_roca = maxf(valor, 1.0)
		_marcar_cambio_manual()

@export_group("Silueta y Complejidad")
## Nivel de irregularidad del perímetro (0 = elipse suave, 1 = silueta muy orgánica/quebrada).
@export_range(0.0, 1.0, 0.02) var irregularidad_contorno: float = 0.38:
	set(valor):
		irregularidad_contorno = clampf(valor, 0.0, 1.0)
		_marcar_cambio_manual()

## Cantidad de subdivisiones angulares del perímetro exterior.
@export_range(12, 64, 1) var segmentos_perimetro: int = 24:
	set(valor):
		segmentos_perimetro = clampi(valor, 12, 64)
		_marcar_cambio_manual()

## Cantidad de niveles verticales en el cuerpo rocoso inferior.
@export_range(3, 16, 1) var anillos_roca: int = 6:
	set(valor):
		anillos_roca = clampi(valor, 3, 16)
		_marcar_cambio_manual()

## Cantidad de anillos concéntricos en la superficie transitable superior.
@export_range(1, 8, 1) var anillos_superficie: int = 3:
	set(valor):
		anillos_superficie = clampi(valor, 1, 8)
		_marcar_cambio_manual()

## Intensidad de la rugosidad y desplazamiento de vértices para acentuar facetas low-poly.
@export_range(0.0, 1.0, 0.02) var intensidad_variacion: float = 0.42:
	set(valor):
		intensidad_variacion = clampf(valor, 0.0, 1.0)
		_marcar_cambio_manual()

## Semilla pseudoaleatoria. Mismo valor = exactamente la misma geometría y distribución.
@export var semilla: int = 12345:
	set(valor):
		semilla = valor
		_solicitar_regeneracion()

@export_group("Picos y Morfología Rocosa")
## Cantidad de picos/estalactitas inferiores (1 = punta única, 2-3 = múltiples picos asimétricos con grietas).
@export_range(1, 4, 1) var cantidad_picos_rocosos: int = 3:
	set(valor):
		cantidad_picos_rocosos = clampi(valor, 1, 4)
		_marcar_cambio_manual()

## Dispersión y separación de los picos secundarios respecto al centro.
@export_range(0.1, 0.8, 0.05) var dispersion_picos: float = 0.35:
	set(valor):
		dispersion_picos = clampf(valor, 0.1, 0.8)
		_marcar_cambio_manual()

## Subdivide los quads en centroides 3D para romper caras cuadradas en triángulos irregulares facetados.
@export var facetado_triangular_irregular: bool = true:
	set(valor):
		facetado_triangular_irregular = valor
		_solicitar_regeneracion()

@export_group("Superficie y Pasto")
## Si está activo, la isla tiene cubierta de hierba/pasto dorado superior y faldón colgante.
## Si está inactivo, la isla se genera como una formación rocosa pura (sin pasto).
@export var generar_pasto: bool = true:
	set(valor):
		generar_pasto = valor
		_solicitar_regeneracion()

## Altura base relativa de la superficie superior transitable.
@export_range(-5.0, 15.0, 0.1) var altura_superficie: float = 0.0:
	set(valor):
		altura_superficie = valor
		_marcar_cambio_manual()

## Variación vertical de ondulación del terreno superior (mantiene la transitabilidad plana para el pasto).
@export_range(0.0, 1.0, 0.02) var variacion_superficie: float = 0.08:
	set(valor):
		variacion_superficie = clampf(valor, 0.0, 1.0)
		_marcar_cambio_manual()

@export_subgroup("Mesetas y Niveles de Superficie")
## Activa la división de la superficie en múltiples niveles y mesetas transitables estilizadas.
@export var habilitar_mesetas_superficie: bool = false:
	set(valor):
		habilitar_mesetas_superficie = valor
		_marcar_cambio_manual()

## Estilo morfológico del escalonamiento y distribución de las mesetas.
@export var estilo_mesetas_superficie: EstiloMeseta = EstiloMeseta.TERRAZAS_CONCENTRICAS:
	set(valor):
		estilo_mesetas_superficie = valor
		_marcar_cambio_manual()

## Cantidad de niveles o repisas planas en la superficie (de 2 a 6 niveles).
@export_range(2, 6, 1) var cantidad_niveles_meseta: int = 3:
	set(valor):
		cantidad_niveles_meseta = clampi(valor, 2, 6)
		_marcar_cambio_manual()

## Desnivel o altura vertical máxima total acumulada entre los niveles de meseta (metros).
@export_range(0.5, 10.0, 0.2, "or_greater") var altura_desnivel_mesetas: float = 2.0:
	set(valor):
		altura_desnivel_mesetas = maxf(valor, 0.1)
		_marcar_cambio_manual()

## Nitidez del escalón o corte entre niveles (1.0 = corte vertical estilo repisa/acantilado, 0.2 = rampa suave inclinada).
@export_range(0.1, 1.0, 0.05) var nitidez_escalon_mesetas: float = 0.75:
	set(valor):
		nitidez_escalon_mesetas = clampf(valor, 0.1, 1.0)
		_marcar_cambio_manual()

## Orientación angular en grados para los estilos direccionales o de ladera.
@export_range(0.0, 360.0, 5.0) var angulo_mesetas: float = 45.0:
	set(valor):
		angulo_mesetas = wrapf(valor, 0.0, 360.0)
		_marcar_cambio_manual()

## Escala o tamaño de las zonas de meseta (mayor = plataformas más amplias).
@export_range(0.3, 3.0, 0.1) var escala_mesetas: float = 1.0:
	set(valor):
		escala_mesetas = clampf(valor, 0.2, 5.0)
		_marcar_cambio_manual()

## Genera el faldón/fleco perimetral de mechones de pasto estilizados que caen sobre la roca.
@export var generar_faldon_pasto: bool = true:
	set(valor):
		generar_faldon_pasto = valor
		_solicitar_regeneracion()

## Caída vertical hacia abajo de las hojas del faldón de pasto (metros).
@export_range(0.2, 1.8, 0.05) var longitud_faldon_pasto: float = 0.65:
	set(valor):
		longitud_faldon_pasto = clampf(valor, 0.2, 1.8)
		_solicitar_regeneracion()

## Vuelo/saliente horizontal hacia afuera del faldón de pasto (metros).
@export_range(0.1, 1.2, 0.05) var vuelo_faldon_pasto: float = 0.38:
	set(valor):
		vuelo_faldon_pasto = clampf(valor, 0.1, 1.2)
		_solicitar_regeneracion()

@export_group("Montañas y Relieve Procedural")
## Activa la generación de montañas, colinas o cordilleras sobre la superficie de la isla.
@export var habilitar_montanas: bool = false:
	set(valor):
		habilitar_montanas = valor
		_solicitar_regeneracion()

## Estilo morfológico de la elevación o montaña.
@export var estilo_montana: EstiloMontana = EstiloMontana.PICO_ROCOSO:
	set(valor):
		estilo_montana = valor
		_solicitar_regeneracion()

## Altura máxima de la montaña o relieve sobre la superficie (metros).
@export_range(0.5, 25.0, 0.5, "or_greater") var altura_montana: float = 4.5:
	set(valor):
		altura_montana = maxf(valor, 0.2)
		_solicitar_regeneracion()

## Radio de la base de la montaña en el terreno (metros).
@export_range(1.0, 40.0, 0.5, "or_greater") var radio_montana: float = 6.0:
	set(valor):
		radio_montana = maxf(valor, 0.5)
		_solicitar_regeneracion()

## Desplazamiento normalizado del centro de la montaña respecto al centro de la isla (-1.0 a 1.0).
@export var posicion_montana: Vector2 = Vector2.ZERO:
	set(valor):
		posicion_montana = valor
		_solicitar_regeneracion()

## Cantidad de cumbres o picos secundarios distribuidos sobre el macizo montañoso.
@export_range(1, 4, 1) var cantidad_picos_montana: int = 1:
	set(valor):
		cantidad_picos_montana = clampi(valor, 1, 4)
		_solicitar_regeneracion()

## Escala las laderas en descansillos y terrazas horizontales low-poly para transitabilidad del jugador.
@export var escalonamiento_terrazas: bool = true:
	set(valor):
		escalonamiento_terrazas = valor
		_solicitar_regeneracion()

## Cantidad de niveles o repisas de terraza en la pendiente.
@export_range(2, 8, 1) var niveles_terraza: int = 3:
	set(valor):
		niveles_terraza = clampi(valor, 2, 8)
		_solicitar_regeneracion()

## Rugosidad y facetas angulares adicionales en las laderas de la montaña.
@export_range(0.0, 1.0, 0.05) var rugosidad_montana: float = 0.20:
	set(valor):
		rugosidad_montana = clampf(valor, 0.0, 1.0)
		_solicitar_regeneracion()

## Si está activo y la isla tiene pasto, las laderas escarpadas de la montaña muestran roca expuesta.
@export var roca_en_pendientes: bool = true:
	set(valor):
		roca_en_pendientes = valor
		_solicitar_regeneracion()

## Ángulo de inclinación (en grados) a partir del cual una ladera muestra roca en vez de pasto.
@export_range(25.0, 75.0, 5.0) var angulo_corte_roca: float = 45.0:
	set(valor):
		angulo_corte_roca = clampf(valor, 20.0, 80.0)
		_solicitar_regeneracion()

@export_group("Pincel de Esculpido 3D (Editor)")
## Activa la herramienta de pincel en el visor 3D para esculpir montañas/valles con clic y arrastre.
@export var activar_pincel_terreno: bool = false

## Modo de acción del pincel al hacer clic en el terreno.
@export var modo_pincel_terreno: ModoPincelTerreno = ModoPincelTerreno.ELEVAR

## Forma de la huella del pincel.
@export var forma_pincel_terreno: FormaPincelTerreno = FormaPincelTerreno.CONICA_LOWPOLY

## Radio del pincel de esculpido en metros.
@export_range(0.5, 20.0, 0.2, "or_greater") var radio_pincel_terreno: float = 3.5

## Intensidad o altura añadida por cada aplicación del pincel (metros).
@export_range(0.1, 10.0, 0.2, "or_greater") var fuerza_pincel_terreno: float = 1.2

## Registro de trazos de deformación manuales guardados en la escena.
@export var deformaciones_escultura: Array[Dictionary] = []

## Botón en el Inspector para borrar todas las deformaciones manuales y reiniciar el terreno.
@export var limpiar_deformaciones: bool = false:
	set(valor):
		if valor:
			limpiar_esculpido()
			limpiar_deformaciones = false

@export_group("Rocas Satélite Flotantes")
## Genera pequeños fragmentos de roca flotando suspendidos bajo la punta inferior.
@export var generar_rocas_satelite: bool = true:
	set(valor):
		generar_rocas_satelite = valor
		_solicitar_regeneracion()

## Cantidad de rocas flotantes secundarias alrededor y debajo de la isla.
@export_range(0, 8, 1) var cantidad_rocas_satelite: int = 4:
	set(valor):
		cantidad_rocas_satelite = clampi(valor, 0, 8)
		_solicitar_regeneracion()

@export_group("Decoración Procedural")
## Activa la distribución automática de elementos dentro de la superficie transitable.
@export var generar_decoracion: bool = false:
	set(valor):
		generar_decoracion = valor
		_solicitar_regeneracion()

## Densidad de objetos decorativos sobre la isla.
@export_range(0.0, 1.0, 0.05) var densidad_decoracion: float = 0.4:
	set(valor):
		densidad_decoracion = clampf(valor, 0.0, 1.0)
		if generar_decoracion:
			_solicitar_regeneracion()

## Incluir árboles estilizados otoñales en la decoración.
@export var incluir_arboles: bool = true:
	set(valor):
		incluir_arboles = valor
		if generar_decoracion:
			_solicitar_regeneracion()

## Incluir monolitos de cristales luminosos.
@export var incluir_cristales: bool = true:
	set(valor):
		incluir_cristales = valor
		if generar_decoracion:
			_solicitar_regeneracion()

## Incluir faroles cálidos.
@export var incluir_faroles: bool = false:
	set(valor):
		incluir_faroles = valor
		if generar_decoracion:
			_solicitar_regeneracion()

## Margen mínimo desde el borde exterior para no colocar objetos al filo del precipicio.
@export_range(0.5, 5.0, 0.1) var margen_borde: float = 1.5:
	set(valor):
		margen_borde = valor
		if generar_decoracion:
			_solicitar_regeneracion()

## Radio despejado en el centro para dar espacio libre al jugador y mecánicas.
@export_range(0.0, 6.0, 0.2) var radio_despeje_centro: float = 1.2:
	set(valor):
		radio_despeje_centro = valor
		if generar_decoracion:
			_solicitar_regeneracion()

@export_group("Materiales")
## Material estilizado para la superficie superior de hierba dorada.
@export var material_hierba: Material = null:
	set(valor):
		material_hierba = valor
		_actualizar_materiales()

## Material estilizado para el cuerpo rocoso inferior y fragmentos flotantes.
@export var material_roca: Material = null:
	set(valor):
		material_roca = valor
		_actualizar_materiales()

@export_group("Acciones de Edición")
## Haz clic en la casilla para forzar la regeneración inmediata de la isla.
@export var regenerar_ahora: bool = false:
	set(valor):
		if valor:
			regenerar()
			regenerar_ahora = false

## Genera una nueva semilla aleatoria y reconstruye la geometría.
@export var nueva_semilla_aleatoria: bool = false:
	set(valor):
		if valor:
			semilla = randi()
			nueva_semilla_aleatoria = false

# Nodos internos administrados
var _mesh_instance: MeshInstance3D = null
var _collision_shape: CollisionShape3D = null
var _decoracion_nodo: Node3D = null

# Control de regeneración diferida
var _regeneracion_pendiente: bool = false
var _aplicando_preset: bool = false
var _esculpiendo_activo: bool = false
var _ultimo_trazo_pos: Vector2 = Vector2.INF
var _ultimo_trazo_radio: float = -1.0
var _necesita_notificar_pasto_completo: bool = false
var _col_caras_cache: PackedVector3Array = PackedVector3Array()
var _perimetro_pts_cache: Array[Vector3] = []
var _global_transform_anterior: Transform3D = Transform3D.IDENTITY

# Preload de materiales y decoración por defecto
const MAT_HIERBA_DEFAULT = preload("res://assets/materiales/entorno/m_isla_hierba.tres")
const MAT_ROCA_DEFAULT = preload("res://assets/materiales/entorno/m_isla_roca.tres")
const MAT_ESPIRITUAL_DEFAULT = preload("res://assets/materiales/entorno/m_isla_espiritual.tres")

# Variables internas para modo Colapso
var _estado_colapso: String = "normal"   # "normal", "temblando", "caida", "oculta"
var _posicion_inicial_colapso: Vector3 = Vector3.ZERO
var _timer_colapso: float = 0.0
var _area_colapso: Area3D = null
var esta_congelada: bool = false

# Variables internas para modo Espiritual
var esta_activo: bool = false
var _estados_disparadores: Dictionary = {}
var _mat_espiritual_instancia: ShaderMaterial = null
var _tween_opacidad: Tween = null
var _opacidad_actual: float = 1.0
var _materiales_cacheados: Dictionary = {}

# Paleta cromática oficial de Proyecto Limbo
# Pasto / Césped dorado: calibrado para integrarse con pasto_fisico_mat.tres y pasto_estilizado.gdshader
# Color base del suelo/raíces bajo la hierba (bajo la iluminación cálida produce RGB [235-248, 178-195, 60-70] en pantalla)
const COLOR_PASTO_TERRENO = Color(0.42, 0.275, 0.052, 1.0)
const COLOR_PASTO_MECHON = Color(0.48, 0.335, 0.072, 1.0)

# Roca: coincide exactamente con StandardMaterial3D_floor_vivo del bloque derecho
const COLOR_ROCA_BASE = Color(0.54901963, 0.4392157, 0.32156864, 1.0) # Terracota / caramelo cálido

const ESCENAS_ARBOLES := [
	preload("res://scenes/entorno/arboles/arbol_1.tscn"),
	preload("res://scenes/entorno/arboles/arbol_2.tscn"),
	preload("res://scenes/entorno/arboles/arbol_3.tscn"),
	preload("res://scenes/entorno/arboles/arbol_4.tscn")
]
const ESCENA_CRISTALES = preload("res://scenes/entorno/cristales/cristales.tscn")
const ESCENA_FAROL = preload("res://scenes/entorno/iluminacion/farol.tscn")


func _init() -> void:
	match tipo_comportamiento:
		TipoComportamiento.COLAPSO:
			collision_layer = 1
			collision_mask = 1
		TipoComportamiento.ESPIRITUAL:
			collision_layer = 1 << 2
			collision_mask = 1 << 2
		TipoComportamiento.ESTANDAR:
			collision_layer = 1
			collision_mask = 0


func _enter_tree() -> void:
	if not is_in_group("islas"):
		add_to_group("islas")
	set_notify_transform(true)
	_global_transform_anterior = global_transform


func _ready() -> void:
	if not is_in_group("islas"):
		add_to_group("islas")
	_asegurar_nodos_hijos()
	if material_hierba == null:
		material_hierba = MAT_HIERBA_DEFAULT
	if material_roca == null:
		material_roca = MAT_ROCA_DEFAULT
	regenerar()

	_posicion_inicial_colapso = global_position
	set_notify_transform(true)
	_global_transform_anterior = global_transform

	if not Engine.is_editor_hint():
		match tipo_comportamiento:
			TipoComportamiento.COLAPSO:
				_asegurar_area_colapso()
				collision_layer = 1
				collision_mask = 1
			TipoComportamiento.ESPIRITUAL:
				_inicializar_modo_espiritual()
			TipoComportamiento.ESTANDAR:
				collision_layer = 1
				collision_mask = 0
	else:
		if tipo_comportamiento == TipoComportamiento.COLAPSO:
			_asegurar_area_colapso()
		elif tipo_comportamiento == TipoComportamiento.ESPIRITUAL:
			collision_layer = 1 << 2
			collision_mask = 1 << 2
			_actualizar_materiales()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		if _global_transform_anterior.basis.determinant() != 0.0:
			var delta_pos = global_position - _global_transform_anterior.origin
			var rot_diff = global_transform.basis * _global_transform_anterior.basis.inverse()
			if delta_pos.length_squared() > 0.00001 or not rot_diff.is_equal_approx(Basis()):
				_notificar_movimiento_pasto(_global_transform_anterior, global_transform)
		_global_transform_anterior = global_transform


## Notifica a los generadores de pasto que esta isla se ha movido o rotado en el espacio
func _notificar_movimiento_pasto(ant: Transform3D, act: Transform3D) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var visitados: Dictionary = {}
	for n in get_tree().get_nodes_in_group("generador_pasto"):
		if is_instance_valid(n) and not visitados.has(n):
			visitados[n] = true
			if n.has_method("mover_pasto_con_isla"):
				n.mover_pasto_con_isla(self, ant, act)
	for c in get_children():
		if is_instance_valid(c) and not visitados.has(c) and c.has_method("mover_pasto_con_isla"):
			visitados[c] = true
			c.mover_pasto_con_isla(self, ant, act)
	if get_parent() != null:
		for s in get_parent().get_children():
			if is_instance_valid(s) and not visitados.has(s) and s.has_method("mover_pasto_con_isla"):
				visitados[s] = true
				s.mover_pasto_con_isla(self, ant, act)
	if owner != null:
		for o in owner.find_children("*", "MultiMeshInstance3D", true, false):
			if is_instance_valid(o) and not visitados.has(o) and o.has_method("mover_pasto_con_isla"):
				visitados[o] = true
				o.mover_pasto_con_isla(self, ant, act)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if tipo_comportamiento == TipoComportamiento.COLAPSO:
		_procesar_fisica_colapso(delta)


func _marcar_cambio_manual() -> void:
	if not _aplicando_preset and preset != PresetTamano.PERSONALIZADA:
		preset = PresetTamano.PERSONALIZADA
	_solicitar_regeneracion()


func _solicitar_regeneracion(notificar_todo_el_pasto: bool = false) -> void:
	if notificar_todo_el_pasto:
		_necesita_notificar_pasto_completo = true
	if not is_inside_tree():
		return
	if _regeneracion_pendiente:
		return
	_regeneracion_pendiente = true
	call_deferred("_ejecutar_regeneracion_diferida")


func _ejecutar_regeneracion_diferida() -> void:
	_regeneracion_pendiente = false
	if is_inside_tree():
		regenerar()


func _asegurar_nodos_hijos() -> void:
	if _mesh_instance == null:
		_mesh_instance = get_node_or_null("MeshInstance3D") as MeshInstance3D
		if _mesh_instance == null:
			_mesh_instance = MeshInstance3D.new()
			_mesh_instance.name = "MeshInstance3D"
			add_child(_mesh_instance)
			if Engine.is_editor_hint():
				_mesh_instance.owner = get_tree().edited_scene_root if get_tree() else null

	if _mesh_instance != null:
		_mesh_instance.ignore_occlusion_culling = true
		_mesh_instance.extra_cull_margin = 12.0
		_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED

	if _collision_shape == null:
		_collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
		if _collision_shape == null:
			_collision_shape = CollisionShape3D.new()
			_collision_shape.name = "CollisionShape3D"
			add_child(_collision_shape)
			if Engine.is_editor_hint():
				_collision_shape.owner = get_tree().edited_scene_root if get_tree() else null

	if _decoracion_nodo == null:
		_decoracion_nodo = get_node_or_null("Decoracion") as Node3D
		if _decoracion_nodo == null:
			_decoracion_nodo = Node3D.new()
			_decoracion_nodo.name = "Decoracion"
			add_child(_decoracion_nodo)
			if Engine.is_editor_hint():
				_decoracion_nodo.owner = get_tree().edited_scene_root if get_tree() else null


func _aplicar_preset(tipo: PresetTamano) -> void:
	_aplicando_preset = true
	match tipo:
		PresetTamano.PEQUENA:
			ancho = 6.5
			largo = 6.5
			profundidad_roca = 5.5
			irregularidad_contorno = 0.28
			segmentos_perimetro = 18
			anillos_roca = 5
			anillos_superficie = 2
			intensidad_variacion = 0.35
			altura_superficie = 0.0
			variacion_superficie = 0.06
			cantidad_picos_rocosos = 2
			dispersion_picos = 0.28
			generar_faldon_pasto = true
			longitud_faldon_pasto = 0.50
			vuelo_faldon_pasto = 0.30
			cantidad_rocas_satelite = 2
			margen_borde = 1.0
			radio_despeje_centro = 0.8
		PresetTamano.MEDIANA:
			ancho = 12.0
			largo = 14.0
			profundidad_roca = 9.0
			irregularidad_contorno = 0.38
			segmentos_perimetro = 24
			anillos_roca = 6
			anillos_superficie = 3
			intensidad_variacion = 0.42
			altura_superficie = 0.0
			variacion_superficie = 0.08
			cantidad_picos_rocosos = 3
			dispersion_picos = 0.35
			generar_faldon_pasto = true
			longitud_faldon_pasto = 0.65
			vuelo_faldon_pasto = 0.38
			cantidad_rocas_satelite = 4
			margen_borde = 1.5
			radio_despeje_centro = 1.2
		PresetTamano.GRANDE:
			ancho = 22.0
			largo = 26.0
			profundidad_roca = 14.5
			irregularidad_contorno = 0.48
			segmentos_perimetro = 32
			anillos_roca = 8
			anillos_superficie = 4
			intensidad_variacion = 0.48
			altura_superficie = 0.0
			variacion_superficie = 0.12
			cantidad_picos_rocosos = 4
			dispersion_picos = 0.42
			generar_faldon_pasto = true
			longitud_faldon_pasto = 0.80
			vuelo_faldon_pasto = 0.48
			cantidad_rocas_satelite = 6
			margen_borde = 2.0
			radio_despeje_centro = 1.8
		PresetTamano.PERSONALIZADA:
			pass
	_aplicando_preset = false
	_solicitar_regeneracion()


## Reconstruye completamente la geometría, colisiones y decoración de la isla.
func regenerar() -> void:
	_asegurar_nodos_hijos()
	
	var rng = RandomNumberGenerator.new()
	rng.seed = semilla

	# 1. Parámetros armónicos deterministas de silueta perimetral
	var arm_amp1 = rng.randf_range(0.70, 1.05)
	var arm_phase1 = rng.randf_range(0.0, TAU)
	var arm_amp2 = rng.randf_range(0.40, 0.80)
	var arm_phase2 = rng.randf_range(0.0, TAU)
	var arm_amp3 = rng.randf_range(0.20, 0.50)
	var arm_phase3 = rng.randf_range(0.0, TAU)

	# 2. Vértices del perímetro 2D exterior
	var radio_x_base = ancho * 0.5
	var radio_z_base = largo * 0.5
	var perimetro_pts: Array[Vector3] = []
	var perimetro_radios: Array[float] = []

	for i in range(segmentos_perimetro):
		var ang = (float(i) / float(segmentos_perimetro)) * TAU
		
		# Modulación armónica natural (lóbulos orgánicos de isla)
		var factor_armonico = (
			arm_amp1 * sin(2.0 * ang + arm_phase1) +
			arm_amp2 * cos(3.0 * ang + arm_phase2) +
			arm_amp3 * sin(5.0 * ang + arm_phase3)
		)
		
		var jitter_local = (rng.randf() - 0.5) * 2.0 * (intensidad_variacion * 0.32)
		var factor_radio = 1.0 + (factor_armonico * irregularidad_contorno) + jitter_local
		factor_radio = maxf(factor_radio, 0.42)

		var px = cos(ang) * radio_x_base * factor_radio
		var pz = sin(ang) * radio_z_base * factor_radio
		var py = _calcular_altura_superficie_interna(Vector2(px, pz))

		perimetro_pts.append(Vector3(px, py, pz))
		perimetro_radios.append(Vector2(px, pz).length())

	_perimetro_pts_cache = perimetro_pts

	# 3. Construir la malla con dos superficies (Pasto / Hierba y Roca) si generar_pasto es true,
	# o una única superficie monolítica de roca si generar_pasto es false.
	var mesh = ArrayMesh.new()
	var st_pasto = SurfaceTool.new()
	var st_roca = SurfaceTool.new()
	var col_caras: PackedVector3Array = PackedVector3Array()
	var espesor_suelo = minf(2.5, maxf(1.8, profundidad_roca * 0.4))

	if generar_pasto:
		st_pasto.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_roca.begin(Mesh.PRIMITIVE_TRIANGLES)

	var st_sup = st_pasto if generar_pasto else st_roca

	# ==========================================================================
	# SUPERFICIE SUPERIOR (Terreno Transitable: Pasto o Roca según generar_pasto)
	# ==========================================================================
	var num_anillos_sup = anillos_superficie
	if habilitar_montanas or not deformaciones_escultura.is_empty() or habilitar_mesetas_superficie:
		num_anillos_sup = maxi(anillos_superficie, 22)

	var y_centro = _calcular_altura_superficie_interna(Vector2.ZERO)
	var vertice_centro = Vector3(0.0, y_centro, 0.0)
	var anillos_sup_pts: Array[Array] = []

	for an in range(1, num_anillos_sup + 1):
		var t_anillo = float(an) / float(num_anillos_sup)
		var pts_anillo: Array[Vector3] = []
		for i in range(segmentos_perimetro):
			var base_p = perimetro_pts[i]
			var px = base_p.x * t_anillo
			var pz = base_p.z * t_anillo
			var pos_xz = Vector2(px, pz)
			var py = _calcular_altura_superficie_interna(pos_xz)
			pts_anillo.append(Vector3(px, py, pz))
		anillos_sup_pts.append(pts_anillo)

	var cos_corte_roca = cos(deg_to_rad(angulo_corte_roca))

	# Triangulación de la tapa central
	var primer_anillo = anillos_sup_pts[0]
	for i in range(segmentos_perimetro):
		var next_i = (i + 1) % segmentos_perimetro
		var v0 = vertice_centro
		var v1 = primer_anillo[i]
		var v2 = primer_anillo[next_i]

		var norm_tri = (v2 - v0).cross(v1 - v0).normalized()
		var es_roca = not generar_pasto or (roca_en_pendientes and norm_tri.y < cos_corte_roca)
		if es_roca:
			_anadir_triangulo_roca_lowpoly(st_roca, v0, v2, v1, rng, 1.05)
		else:
			var col_top = _color_pasto(rng, i, 1.0)
			_anadir_triangulo_lowpoly(st_pasto, v0, v2, v1, col_top)

		# Colisión: cara superior (+Y) y losa inferior (-Y) para solidez física absoluta
		col_caras.append(v0); col_caras.append(v2); col_caras.append(v1)
		var v0_b = v0 - Vector3(0.0, espesor_suelo, 0.0)
		var v1_b = v1 - Vector3(0.0, espesor_suelo, 0.0)
		var v2_b = v2 - Vector3(0.0, espesor_suelo, 0.0)
		col_caras.append(v0_b); col_caras.append(v1_b); col_caras.append(v2_b)

	for an in range(num_anillos_sup - 1):
		var r_in = anillos_sup_pts[an]
		var r_out = anillos_sup_pts[an + 1]
		for i in range(segmentos_perimetro):
			var next_i = (i + 1) % segmentos_perimetro
			var p_in0 = r_in[i]
			var p_in1 = r_in[next_i]
			var p_out0 = r_out[i]
			var p_out1 = r_out[next_i]

			# Triángulo 1
			var n1 = (p_out1 - p_in0).cross(p_out0 - p_in0).normalized()
			var es_roca1 = not generar_pasto or (roca_en_pendientes and n1.y < cos_corte_roca)
			if es_roca1:
				_anadir_triangulo_roca_lowpoly(st_roca, p_in0, p_out1, p_out0, rng, 1.04)
			else:
				var col_ring1 = _color_pasto(rng, an * segmentos_perimetro + i, 1.0)
				_anadir_triangulo_lowpoly(st_pasto, p_in0, p_out1, p_out0, col_ring1)

			# Triángulo 2
			var n2 = (p_in1 - p_in0).cross(p_out1 - p_in0).normalized()
			var es_roca2 = not generar_pasto or (roca_en_pendientes and n2.y < cos_corte_roca)
			if es_roca2:
				_anadir_triangulo_roca_lowpoly(st_roca, p_in0, p_in1, p_out1, rng, 1.04)
			else:
				var col_ring2 = _color_pasto(rng, an * segmentos_perimetro + i + 1, 1.0)
				_anadir_triangulo_lowpoly(st_pasto, p_in0, p_in1, p_out1, col_ring2)

			# Colisión: caras superiores (+Y)
			col_caras.append(p_in0); col_caras.append(p_out1); col_caras.append(p_out0)
			col_caras.append(p_in0); col_caras.append(p_in1); col_caras.append(p_out1)

			# Colisión: caras inferiores (-Y) de la losa sólida
			var in0_b = p_in0 - Vector3(0.0, espesor_suelo, 0.0)
			var in1_b = p_in1 - Vector3(0.0, espesor_suelo, 0.0)
			var out0_b = p_out0 - Vector3(0.0, espesor_suelo, 0.0)
			var out1_b = p_out1 - Vector3(0.0, espesor_suelo, 0.0)
			col_caras.append(in0_b); col_caras.append(out0_b); col_caras.append(out1_b)
			col_caras.append(in0_b); col_caras.append(out1_b); col_caras.append(in1_b)

	# Pared perimetral de la losa sólida superior (sellado volumétrico impenetrable)
	var ultimo_anillo_sup = anillos_sup_pts[num_anillos_sup - 1]
	for i in range(segmentos_perimetro):
		var next_i = (i + 1) % segmentos_perimetro
		var top0 = ultimo_anillo_sup[i]
		var top1 = ultimo_anillo_sup[next_i]
		var bot0 = top0 - Vector3(0.0, espesor_suelo, 0.0)
		var bot1 = top1 - Vector3(0.0, espesor_suelo, 0.0)
		col_caras.append(top0); col_caras.append(top1); col_caras.append(bot1)
		col_caras.append(top0); col_caras.append(bot1); col_caras.append(bot0)

	# --------------------------------------------------------------------------
	# FALDÓN / FLECO PERIMETRAL DE PASTO O TRANSICIÓN ROCOSA DIRECTA
	# --------------------------------------------------------------------------
	var rim_roca_pts: Array[Vector3] = []

	if generar_pasto:
		# 1. Puntos de los dientes del faldón de pasto que caen hacia afuera y abajo
		var dientes_pasto_pts: Array[Vector3] = []
		for i in range(segmentos_perimetro):
			var top_p = ultimo_anillo_sup[i]
			var dir_horiz = Vector3(top_p.x, 0.0, top_p.z).normalized()

			var caida_base = longitud_faldon_pasto if generar_faldon_pasto else 0.28
			var vuelo_base = vuelo_faldon_pasto if generar_faldon_pasto else 0.15

			var es_diente_largo = (i % 2 == 1)
			var factor_diente = 1.25 if (es_diente_largo and generar_faldon_pasto) else 0.75
			var ruido_diente = (rng.randf() - 0.5) * 0.16 * intensidad_variacion

			var caida = caida_base * factor_diente * (1.0 + ruido_diente)
			var vuelo = vuelo_base * factor_diente * (1.0 + ruido_diente * 0.35)

			var p_diente = Vector3(
				top_p.x + dir_horiz.x * vuelo,
				top_p.y - caida,
				top_p.z + dir_horiz.z * vuelo
			)
			dientes_pasto_pts.append(p_diente)

		# 2. Borde superior de la roca: anillo continuo y suave recogido bajo el faldón
		for i in range(segmentos_perimetro):
			var top_p = ultimo_anillo_sup[i]
			var p_roca_top = Vector3(top_p.x * 0.93, top_p.y - 0.22, top_p.z * 0.93)
			rim_roca_pts.append(p_roca_top)

		# 3. Triangulación limpia y continua de la cara exterior del faldón de pasto
		for i in range(segmentos_perimetro):
			var next_i = (i + 1) % segmentos_perimetro
			var t0 = ultimo_anillo_sup[i]
			var t1 = ultimo_anillo_sup[next_i]
			var b0 = dientes_pasto_pts[i]
			var b1 = dientes_pasto_pts[next_i]

			var col_hoja = _color_pasto(rng, i + 100, 1.0)
			var col_punta = _color_pasto(rng, i + 150, 1.12)

			_anadir_triangulo_lowpoly(st_pasto, t0, t1, b1, col_hoja)
			_anadir_triangulo_lowpoly(st_pasto, t0, b1, b0, col_punta)

			# 4. Solapa interior que sella el volumen del pasto hacia el borde de la roca
			var r0 = rim_roca_pts[i]
			var r1 = rim_roca_pts[next_i]
			var col_rev = _color_pasto(rng, i + 200, 0.92)
			_anadir_triangulo_lowpoly(st_pasto, b0, b1, r1, col_rev)
			_anadir_triangulo_lowpoly(st_pasto, b0, r1, r0, col_rev)
	else:
		# ISLA DE ROCA PURA (SIN PASTO):
		# El cuerpo rocoso conecta directamente con el borde superior perimetral
		for i in range(segmentos_perimetro):
			rim_roca_pts.append(ultimo_anillo_sup[i])

	# ==========================================================================
	# SUPERFICIE 1: CUERPO ROCOSO CON MÚLTIPLES PICOS Y FACETAS IRREGULARES
	# ==========================================================================
	# Generación determinista de picos inferiores ordenados angularmente
	var picos: Array[Vector3] = []
	var p0_x = (rng.randf() - 0.5) * ancho * 0.14 * intensidad_variacion
	var p0_z = (rng.randf() - 0.5) * largo * 0.14 * intensidad_variacion
	var p0_y = -profundidad_roca * rng.randf_range(0.96, 1.08)
	var p_main = Vector3(p0_x, p0_y, p0_z)
	picos.append(p_main)

	if cantidad_picos_rocosos >= 2:
		for k in range(1, cantidad_picos_rocosos):
			var ang_k = (float(k) / float(cantidad_picos_rocosos)) * TAU + rng.randf_range(-0.30, 0.30)
			var dist_x_k = (ancho * 0.5) * dispersion_picos * rng.randf_range(0.55, 0.95)
			var dist_z_k = (largo * 0.5) * dispersion_picos * rng.randf_range(0.55, 0.95)
			var pk_y = -profundidad_roca * rng.randf_range(0.58, 0.85)
			picos.append(Vector3(
				p0_x + cos(ang_k) * dist_x_k,
				pk_y,
				p0_z + sin(ang_k) * dist_z_k
			))

		# Ordenar los picos cíclicamente por ángulo para garantizar un fondo 100% cerrado
		picos.sort_custom(func(a: Vector3, b: Vector3) -> bool:
			var ang_a = atan2(a.z - p0_z, a.x - p0_x)
			var ang_b = atan2(b.z - p0_z, b.x - p0_x)
			return ang_a < ang_b
		)

	# Generación de niveles de roca con desfasamiento angular y vertical para evitar caras cuadradas
	var niveles_roca_pts: Array[Array] = []
	niveles_roca_pts.append(rim_roca_pts)

	for an in range(1, anillos_roca):
		var t = float(an) / float(anillos_roca)
		var y_base = -t * profundidad_roca
		var pts_nivel: Array[Vector3] = []

		# Desfase angular progresivo por anillo para romper columnas alineadas
		var twist_ang = sin(float(an) * 1.8) * 0.28 * intensidad_variacion

		for i in range(segmentos_perimetro):
			var base_rim = rim_roca_pts[i]
			var ang_orig = (float(i) / float(segmentos_perimetro)) * TAU + twist_ang
			
			# Encontrar el pico dominante más cercano en dirección angular
			var dir_vertice_2d = Vector2(cos(ang_orig), sin(ang_orig))
			var pico_influencia = picos[0]
			var max_dot = -999.0
			for pk in picos:
				var dir_pk = Vector2(pk.x, pk.z).normalized()
				var dot_val = dir_vertice_2d.dot(dir_pk)
				if dot_val > max_dot:
					max_dot = dot_val
					pico_influencia = pk

			# Factor de atracción radial hacia el pico más próximo
			var t_attract = pow(t, 1.2)
			var centro_x = lerpf(0.0, pico_influencia.x, t_attract)
			var centro_z = lerpf(0.0, pico_influencia.z, t_attract)

			# Perfil cónico quebrada con repisas y grietas
			var factor_radio: float
			if t < 0.25:
				factor_radio = lerpf(0.96, 0.88, t / 0.25)
			elif t < 0.65:
				var t_mid = (t - 0.25) / 0.40
				factor_radio = lerpf(0.88, 0.50, pow(t_mid, 0.85))
			else:
				var t_low = (t - 0.65) / 0.35
				factor_radio = lerpf(0.50, 0.12, t_low)

			# Desplazamiento 3D asimétrico (altura escalonada alterna para eliminar líneas horizontales)
			var stagger_y = ((i % 2) * 2.0 - 1.0) * (profundidad_roca / float(anillos_roca)) * 0.32 * intensidad_variacion
			var ruido_r = 1.0 + (rng.randf() - 0.5) * 0.55 * intensidad_variacion
			var ruido_y = (rng.randf() - 0.5) * (profundidad_roca / float(anillos_roca)) * 0.45 * intensidad_variacion

			var px = centro_x + cos(ang_orig) * (base_rim.length() * factor_radio * ruido_r)
			var pz = centro_z + sin(ang_orig) * (base_rim.length() * factor_radio * ruido_r)
			var py = y_base + stagger_y + ruido_y

			pts_nivel.append(Vector3(px, py, pz))

		niveles_roca_pts.append(pts_nivel)

	# --------------------------------------------------------------------------
	# TRIANGULACIÓN FACETADA IRREGULAR (Elimina caras cuadradas monótonas)
	# --------------------------------------------------------------------------
	for an in range(anillos_roca - 1):
		var r_up = niveles_roca_pts[an]
		var r_down = niveles_roca_pts[an + 1]

		for i in range(segmentos_perimetro):
			var next_i = (i + 1) % segmentos_perimetro
			var u0 = r_up[i]
			var u1 = r_up[next_i]
			var d0 = r_down[i]
			var d1 = r_down[next_i]

			if facetado_triangular_irregular:
				# Inserta un vértice centroide 3D desplazado hacia afuera/adentro
				# transformando cada cuadrilátero monótono en 4 triángulos facetados únicos
				var centroide = (u0 + u1 + d0 + d1) * 0.25
				var normal_aprox = ((u1 - u0).cross(d0 - u0)).normalized()
				var escala_jitter = 0.25 if an == 0 else 0.65
				var jitter_3d = normal_aprox * (rng.randf() - 0.5) * escala_jitter * intensidad_variacion
				var v_c = centroide + jitter_3d
				if an == 0:
					v_c.y = minf(v_c.y, minf(u0.y, u1.y) - 0.05)

				_anadir_triangulo_roca_lowpoly(st_roca, u0, u1, v_c, rng)
				_anadir_triangulo_roca_lowpoly(st_roca, u1, d1, v_c, rng)
				_anadir_triangulo_roca_lowpoly(st_roca, d1, d0, v_c, rng)
				_anadir_triangulo_roca_lowpoly(st_roca, d0, u0, v_c, rng)

				col_caras.append(u0); col_caras.append(u1); col_caras.append(v_c)
				col_caras.append(u1); col_caras.append(d1); col_caras.append(v_c)
				col_caras.append(d1); col_caras.append(d0); col_caras.append(v_c)
				col_caras.append(d0); col_caras.append(u0); col_caras.append(v_c)
			else:
				_anadir_triangulo_roca_lowpoly(st_roca, u0, u1, d0, rng)
				_anadir_triangulo_roca_lowpoly(st_roca, u1, d1, d0, rng)

				col_caras.append(u0); col_caras.append(u1); col_caras.append(d0)
				col_caras.append(u1); col_caras.append(d1); col_caras.append(d0)

	# --------------------------------------------------------------------------
	# CONEXIÓN DEL ÚLTIMO NIVEL A LOS MÚLTIPLES PICOS (100% CERRADO Y WATERTIGHT)
	# --------------------------------------------------------------------------
	var ultimo_nivel_roca = niveles_roca_pts[anillos_roca - 1]

	# Asignar cada segmento del último nivel al pico más cercano
	var asignaciones_picos: Array[int] = []
	for i in range(segmentos_perimetro):
		var next_i = (i + 1) % segmentos_perimetro
		var u0 = ultimo_nivel_roca[i]
		var u1 = ultimo_nivel_roca[next_i]
		var punto_medio = (u0 + u1) * 0.5

		var best_idx = 0
		var min_d = 999999.0
		for k in range(picos.size()):
			var d = punto_medio.distance_to(picos[k])
			if d < min_d:
				min_d = d
				best_idx = k
		asignaciones_picos.append(best_idx)

	# Centroide interior para sellar la hendidura central entre picos
	var c_mid = Vector3.ZERO
	if picos.size() > 1:
		for pk in picos:
			c_mid += pk
		c_mid /= float(picos.size())
		c_mid.y += profundidad_roca * 0.16 # Rehundido hacia arriba formando una hendidura rocosa

	# Triangulación de la base hacia los picos con caras de puente y hendidura en transiciones (100% cerrado)
	for i in range(segmentos_perimetro):
		var next_i = (i + 1) % segmentos_perimetro
		var u0 = ultimo_nivel_roca[i]
		var u1 = ultimo_nivel_roca[next_i]
		var idx_curr = asignaciones_picos[i]
		var idx_next = asignaciones_picos[next_i]
		var pk_curr = picos[idx_curr]
		var pk_next = picos[idx_next]

		# Cara principal hacia el pico asignado (Normal hacia afuera)
		_anadir_triangulo_roca_lowpoly(st_roca, u0, u1, pk_curr, rng)
		col_caras.append(u0); col_caras.append(u1); col_caras.append(pk_curr)

		# Si el siguiente segmento conecta a un pico distinto, cerrar la brecha con cara de puente
		# y sellar la hendidura central directamente para garantizar una malla hermética sin aristas abiertas
		if idx_curr != idx_next:
			_anadir_triangulo_roca_lowpoly(st_roca, u1, pk_next, pk_curr, rng)
			col_caras.append(u1); col_caras.append(pk_next); col_caras.append(pk_curr)

			_anadir_triangulo_roca_lowpoly(st_roca, pk_curr, pk_next, c_mid, rng, 0.78)
			col_caras.append(pk_curr); col_caras.append(pk_next); col_caras.append(c_mid)

	# ==========================================================================
	# ROCAS SATÉLITE FLOTANTES (Fragmentos suspendidos bajo la isla)
	# ==========================================================================
	if generar_rocas_satelite and cantidad_rocas_satelite > 0:
		var dim_min = minf(ancho, largo)
		for s in range(cantidad_rocas_satelite):
			var ang_sat = (float(s) / float(cantidad_rocas_satelite)) * TAU + rng.randf_range(-0.35, 0.35)
			var pico_ref = picos[s % picos.size()]

			# Tamaño escalado y proporcional al tamaño de la isla (evita rocas gigantes desproporcionadas)
			var tam_sat = clampf(dim_min * rng.randf_range(0.045, 0.075), 0.18, 0.60)

			var dist_sat: float
			var y_sat: float

			if s % 2 == 0:
				# Flotando suspendida en el aire debajo del pico inferior (abismo, 100% fuera de la malla)
				y_sat = pico_ref.y - rng.randf_range(0.50 + tam_sat, maxf(profundidad_roca * 0.28, 1.2) + tam_sat)
				dist_sat = rng.randf_range(0.15, maxf(dim_min * 0.08, 0.55))
			else:
				# Flotando suspendida en el aire en el perímetro exterior con holgura segura
				var t_h = rng.randf_range(0.35, 0.75)
				y_sat = -t_h * profundidad_roca
				var radio_cuerpo_aprox = (dim_min * 0.5) * lerpf(0.85, 0.30, t_h)
				dist_sat = radio_cuerpo_aprox + tam_sat + rng.randf_range(0.9, 1.8)

			var centro_sat = Vector3(
				pico_ref.x + cos(ang_sat) * dist_sat,
				y_sat,
				pico_ref.z + sin(ang_sat) * dist_sat
			)
			_generar_roca_satelite_mesh(st_roca, rng, centro_sat, tam_sat)

	# 4. Finalizar mallas con materiales asignados y normales facetadas puras
	st_roca.index()
	var mat_roca = material_roca if material_roca != null else MAT_ROCA_DEFAULT
	st_roca.set_material(mat_roca)

	if generar_pasto:
		st_pasto.index()
		var mat_pasto = material_hierba if material_hierba != null else MAT_HIERBA_DEFAULT
		st_pasto.set_material(mat_pasto)
		mesh = st_pasto.commit()
		st_roca.commit(mesh)
	else:
		mesh = st_roca.commit()

	_mesh_instance.mesh = mesh
	_actualizar_materiales()
	
	# Asegurar AABB amplio para evitar culling de cámara en cualquier ángulo
	var bbox_mesh = mesh.get_aabb()
	_mesh_instance.custom_aabb = bbox_mesh.grow(4.0)

	# 5. Generar colisión sólida e impenetrable
	_col_caras_cache = col_caras
	if not _esculpiendo_activo:
		_actualizar_colision(col_caras)

	# 6. Sincronizar área de colapso o material espiritual si corresponde
	if tipo_comportamiento == TipoComportamiento.COLAPSO:
		_asegurar_area_colapso()
	elif tipo_comportamiento == TipoComportamiento.ESPIRITUAL:
		_asegurar_material_espiritual()

	# 7. Generar decoración procedural si está habilitada
	if not _esculpiendo_activo:
		_actualizar_decoracion(rng, perimetro_pts, perimetro_radios)

	# 8. Sincronizar y adaptar generadores de pasto sobre esta isla
	if _ultimo_trazo_radio > 0.0 and _ultimo_trazo_pos.x != INF:
		_notificar_generadores_pasto(_ultimo_trazo_pos, _ultimo_trazo_radio)
		_ultimo_trazo_radio = -1.0
		_ultimo_trazo_pos = Vector2.INF
	elif _necesita_notificar_pasto_completo:
		_necesita_notificar_pasto_completo = false
		_notificar_generadores_pasto()


func _actualizar_materiales() -> void:
	if _mesh_instance == null or _mesh_instance.mesh == null:
		return
	
	if tipo_comportamiento == TipoComportamiento.ESPIRITUAL:
		_asegurar_material_espiritual()
		_mesh_instance.set_surface_override_material(0, _mat_espiritual_instancia)
		if _mesh_instance.mesh.get_surface_count() > 1:
			_mesh_instance.set_surface_override_material(1, _mat_espiritual_instancia)
		return

	var mat_roca = material_roca if material_roca != null else MAT_ROCA_DEFAULT
	if generar_pasto:
		var mat_pasto = material_hierba if material_hierba != null else MAT_HIERBA_DEFAULT
		_mesh_instance.set_surface_override_material(0, mat_pasto)
		_mesh_instance.set_surface_override_material(1, mat_roca)
	else:
		_mesh_instance.set_surface_override_material(0, mat_roca)
		if _mesh_instance.mesh.get_surface_count() > 1:
			_mesh_instance.set_surface_override_material(1, null)


func _actualizar_colision(caras: PackedVector3Array) -> void:
	if _collision_shape == null:
		return
	if caras.size() >= 3:
		var trimesh_shape = ConcavePolygonShape3D.new()
		trimesh_shape.backface_collision = true
		trimesh_shape.set_faces(caras)
		_collision_shape.shape = trimesh_shape
		_collision_shape.disabled = false
	else:
		_collision_shape.shape = null


## Añade un triángulo low-poly plano con su propia normal calculada y color por vértice puro
func _anadir_triangulo_lowpoly(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal = (b - a).cross(c - a).normalized()
	if normal.length_squared() < 0.0001:
		return

	st.set_color(color)
	st.set_normal(normal)
	st.set_uv(Vector2(a.x * 0.1, a.z * 0.1))
	st.add_vertex(a)

	st.set_color(color)
	st.set_normal(normal)
	st.set_uv(Vector2(c.x * 0.1, c.z * 0.1))
	st.add_vertex(c)

	st.set_color(color)
	st.set_normal(normal)
	st.set_uv(Vector2(b.x * 0.1, b.z * 0.1))
	st.add_vertex(b)


## Añade un cuadrilátero dividido en dos triángulos con facetas planas hacia afuera
func _anadir_quad_lowpoly(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, color: Color, diagonal_alt: bool = false) -> void:
	if diagonal_alt:
		_anadir_triangulo_lowpoly(st, v0, v1, v2, color)
		_anadir_triangulo_lowpoly(st, v0, v2, v3, color)
	else:
		_anadir_triangulo_lowpoly(st, v0, v1, v3, color)
		_anadir_triangulo_lowpoly(st, v1, v2, v3, color)


## Genera una pequeña roca satélite low-poly cerrada (poliedro irregular sin aristas afiladas artificiales)
func _generar_roca_satelite_mesh(st: SurfaceTool, rng: RandomNumberGenerator, centro: Vector3, radio: float) -> void:
	var v_top = centro + Vector3((rng.randf() - 0.5) * radio * 0.35, radio * rng.randf_range(0.85, 1.25), (rng.randf() - 0.5) * radio * 0.35)
	var v_bot = centro + Vector3((rng.randf() - 0.5) * radio * 0.35, -radio * rng.randf_range(0.90, 1.30), (rng.randf() - 0.5) * radio * 0.35)
	
	var num_pts = 5
	var r_up: Array[Vector3] = []
	var r_down: Array[Vector3] = []
	
	var offset_ang = rng.randf_range(0.0, TAU)
	for i in range(num_pts):
		var frac = float(i) / float(num_pts)
		var ang_up = frac * TAU + offset_ang + rng.randf_range(-0.18, 0.18)
		var ang_down = (frac + 0.5 / float(num_pts)) * TAU + offset_ang + rng.randf_range(-0.18, 0.18)
		
		var rad_up = radio * rng.randf_range(0.70, 1.15)
		var y_up = centro.y + radio * rng.randf_range(0.12, 0.38)
		r_up.append(Vector3(centro.x + cos(ang_up) * rad_up, y_up, centro.z + sin(ang_up) * rad_up))
		
		var rad_down = radio * rng.randf_range(0.65, 1.10)
		var y_down = centro.y - radio * rng.randf_range(0.12, 0.38)
		r_down.append(Vector3(centro.x + cos(ang_down) * rad_down, y_down, centro.z + sin(ang_down) * rad_down))
		
	# Tapa superior
	for i in range(num_pts):
		var next_i = (i + 1) % num_pts
		_anadir_triangulo_roca_lowpoly(st, v_top, r_up[next_i], r_up[i], rng, 0.98)
		
	# Cinturón lateral facetado (rompe el ecuador y elimina la arista horizontal continua)
	for i in range(num_pts):
		var next_i = (i + 1) % num_pts
		var u0 = r_up[i]
		var u1 = r_up[next_i]
		var d0 = r_down[i]
		var d1 = r_down[next_i]
		
		if i % 2 == 0:
			_anadir_triangulo_roca_lowpoly(st, u0, u1, d1, rng, 0.92)
			_anadir_triangulo_roca_lowpoly(st, u0, d1, d0, rng, 0.88)
		else:
			_anadir_triangulo_roca_lowpoly(st, u0, u1, d0, rng, 0.92)
			_anadir_triangulo_roca_lowpoly(st, u1, d1, d0, rng, 0.88)
			
	# Tapa inferior
	for i in range(num_pts):
		var next_i = (i + 1) % num_pts
		_anadir_triangulo_roca_lowpoly(st, v_bot, r_down[i], r_down[next_i], rng, 0.82)


## Añade un triángulo facetado a la malla de roca calculando su sombreado low-poly
## (AO hemisférico por normal, gradiente de profundidad vertical y variación tonal por faceta)
func _anadir_triangulo_roca_lowpoly(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, rng: RandomNumberGenerator, factor_extra: float = 1.0) -> void:
	var normal = (b - a).cross(c - a).normalized()
	if normal.length_squared() < 0.0001:
		return

	# 1. Gradiente de profundidad vertical (la roca es más oscura y profunda en la base/puntas)
	var y_mid = (a.y + b.y + c.y) / 3.0
	var t_prof = clampf(-y_mid / maxf(profundidad_roca, 0.1), 0.0, 1.0)
	var f_prof = lerpf(1.05, 0.68, pow(t_prof, 0.85))

	# 2. Oclusión ambiental hemisférica y contraste de dirección según la normal
	# Facetas orientadas hacia arriba o hacia afuera reciben más luz ambiental difusa (0.95 - 1.18)
	# Facetas hacia abajo o hacia el abismo reciben oclusión natural (0.62 - 0.85)
	var f_hemi = clampf(0.86 + normal.y * 0.22 + normal.x * 0.08 - normal.z * 0.06, 0.62, 1.18)

	# 3. Variación low-poly facetada nítida por triángulo (contraste visible entre facetas adyacentes)
	var jitter_tri = (rng.randf() - 0.5) * 0.28 # ±14% de variación entre triángulos vecinos
	var mult = f_prof * f_hemi * (1.0 + jitter_tri) * factor_extra

	# 4. Modulación tonal cálida (terracota / caramelo idéntico a StandardMaterial3D_floor_vivo)
	var col = Color(
		clampf(COLOR_ROCA_BASE.r * mult, 0.18, 0.78),
		clampf(COLOR_ROCA_BASE.g * mult * (0.96 if mult < 0.85 else 1.02), 0.14, 0.65),
		clampf(COLOR_ROCA_BASE.b * mult * (0.90 if mult < 0.85 else 1.04), 0.09, 0.55),
		1.0
	)

	st.set_color(col)
	st.set_normal(normal)
	st.set_uv(Vector2(a.x * 0.1, a.z * 0.1))
	st.add_vertex(a)

	st.set_color(col)
	st.set_normal(normal)
	st.set_uv(Vector2(c.x * 0.1, c.z * 0.1))
	st.add_vertex(c)

	st.set_color(col)
	st.set_normal(normal)
	st.set_uv(Vector2(b.x * 0.1, b.z * 0.1))
	st.add_vertex(b)


## ==============================================================================
## SISTEMA DE CÁLCULO DE RELIEVE, MONTAÑAS Y ESCULPIDO
## ==============================================================================

## Calcula la altura del terreno (Y local) en una coordenada horizontal (X, Z).
func calcular_altura_en(pos_xz: Vector2) -> float:
	return _calcular_altura_superficie_interna(pos_xz)


## Calcula la normal aproximada de la superficie en una coordenada horizontal (X, Z).
func calcular_normal_superficie_en(pos_xz: Vector2) -> Vector3:
	var eps = 0.35
	var h_x1 = calcular_altura_en(pos_xz + Vector2(eps, 0.0))
	var h_x0 = calcular_altura_en(pos_xz - Vector2(eps, 0.0))
	var h_z1 = calcular_altura_en(pos_xz + Vector2(0.0, eps))
	var h_z0 = calcular_altura_en(pos_xz - Vector2(0.0, eps))
	var dx = (h_x1 - h_x0) / (2.0 * eps)
	var dz = (h_z1 - h_z0) / (2.0 * eps)
	return Vector3(-dx, 1.0, -dz).normalized()


## Función interna determinista de cálculo de altura total
func _calcular_altura_superficie_interna(pos_xz: Vector2) -> float:
	var y = altura_superficie

	# 1. Ondulación armónica base determinista según la semilla
	var r_actual = pos_xz.length()
	var r_max = maxf(ancho, largo) * 0.5
	var t_radio = clampf(r_actual / maxf(r_max, 0.1), 0.0, 1.0)
	var ang = atan2(pos_xz.y, pos_xz.x)
	var sup_fase1 = fposmod(float(semilla) * 1.6180339887, TAU)
	var sup_fase2 = fposmod(float(semilla) * 2.7182818284, TAU)
	var ond_armonica = (sin(2.0 * ang + sup_fase1) * 0.55 + cos(3.0 * ang + sup_fase2) * 0.45)
	y += ond_armonica * (variacion_superficie * 0.35 * t_radio)

	# 2. Mesetas y Terrazas de Superficie
	var h_relieve = 0.0
	if habilitar_mesetas_superficie:
		h_relieve += _evaluar_mesetas_superficie(pos_xz)

	# 3. Montañas y Relieve Procedural
	if habilitar_montanas:
		h_relieve += _evaluar_relieve_procedural(pos_xz)

	y += h_relieve

	# 4. Deformaciones manuales esculpidas con pincel
	if not deformaciones_escultura.is_empty():
		y += _evaluar_deformaciones_escultura(pos_xz, h_relieve)

	return y


## Evalúa la elevación escalonada según el estilo de meseta configurado
func _evaluar_mesetas_superficie(pos_xz: Vector2) -> float:
	var r_actual = pos_xz.length()
	var r_max = maxf(ancho, largo) * 0.5
	var t_radio = clampf(r_actual / maxf(r_max, 0.1), 0.0, 1.0)
	var ang = atan2(pos_xz.y, pos_xz.x)
	var esc = maxf(escala_mesetas, 0.2)

	var v_norm = 0.0

	match estilo_mesetas_superficie:
		EstiloMeseta.TERRAZAS_CONCENTRICAS:
			# Anillos concéntricos que escalonan hacia el centro con sutil irregularidad orgánica
			var jitter_ring = (sin(ang * 3.0 + float(semilla) * 1.2) * 0.55 + cos(ang * 5.0 + float(semilla) * 2.1) * 0.45) * 0.10
			v_norm = clampf(1.0 - t_radio + jitter_ring, 0.0, 1.0)

		EstiloMeseta.ESCALONADO_DIRECCIONAL:
			# Gradas escalonadas en una dirección angular (repisas y terrazas de ladera)
			var rad_dir = deg_to_rad(angulo_mesetas)
			var dir = Vector2(cos(rad_dir), sin(rad_dir))
			var dir_perpen = Vector2(-dir.y, dir.x)
			var proj_eje = (pos_xz.x * dir.x + pos_xz.y * dir.y) / (r_max * 0.95 / esc)
			var proj_perpen = (pos_xz.x * dir_perpen.x + pos_xz.y * dir_perpen.y) / (r_max * 0.95)
			var jitter_dir = sin(proj_perpen * 2.8 + float(semilla) * 1.7) * 0.08
			v_norm = clampf((proj_eje + 1.0) * 0.5 + jitter_dir, 0.0, 1.0)

		EstiloMeseta.PLATAFORMAS_ORGANICAS:
			# Plataformas y bloques a diferentes alturas distribuidas por la isla
			var px = pos_xz.x / (r_max * 0.65 / esc)
			var pz = pos_xz.y / (r_max * 0.65 / esc)
			var w1 = sin(px + float(semilla) * 1.618) * cos(pz + float(semilla) * 2.718)
			var w2 = sin(px * 1.5 - pz * 1.2 + float(semilla) * 3.141) * 0.5
			v_norm = clampf((w1 + w2 + 1.5) / 3.0, 0.0, 1.0)

		EstiloMeseta.MESETA_CENTRAL_ELEVADA:
			# Meseta prominente en el centro rodeada de terrazas perimetrales
			var jitter_mesa = (sin(ang * 4.0 + float(semilla) * 2.3) * 0.5 + cos(ang * 2.0) * 0.5) * 0.12
			var t_mesa = clampf((t_radio - 0.40 + jitter_mesa) / 0.60, 0.0, 1.0)
			v_norm = clampf(1.0 - t_mesa, 0.0, 1.0)

	var num_niv = maxi(cantidad_niveles_meseta, 2)
	# Mapear v_norm (0.0..1.0) a los niveles discretos de terraza
	var escalon_idx = v_norm * float(num_niv - 1)
	var n_fl = floor(escalon_idx)
	var frac = escalon_idx - n_fl

	# Control de nitidez del escalón (ancho de la rampa vs meseta plana)
	var ancho_rampa = clampf(1.0 - nitidez_escalon_mesetas * 0.88, 0.05, 1.0)
	var ramp = smoothstep(1.0 - ancho_rampa, 1.0, frac)

	var nivel_final = (n_fl + ramp) / float(num_niv - 1)
	return nivel_final * altura_desnivel_mesetas


func _evaluar_relieve_procedural(pos_xz: Vector2) -> float:
	var delta_h = 0.0
	var centro_mtn = Vector2(posicion_montana.x * ancho * 0.38, posicion_montana.y * largo * 0.38)
	var dist = pos_xz.distance_to(centro_mtn)
	var r_eff = maxf(radio_montana, 0.8)

	if dist < r_eff:
		var t = dist / r_eff # 0 en la cumbre, 1 en la base
		var h_factor = 0.0

		match estilo_montana:
			EstiloMontana.COLINA_SUAVE:
				h_factor = pow(1.0 - t * t, 2.0)

			EstiloMontana.PICO_ROCOSO:
				var ang_pico = atan2(pos_xz.y - centro_mtn.y, pos_xz.x - centro_mtn.x)
				var faceta_ang = abs(sin(ang_pico * 2.5)) * rugosidad_montana * (1.0 - t)
				h_factor = clampf(pow(1.0 - t, 1.35) + faceta_ang, 0.0, 1.25)

			EstiloMontana.MESETA_TERRAZA:
				if t < 0.45:
					h_factor = 1.0
				else:
					var t_caida = (t - 0.45) / 0.55
					h_factor = 1.0 - smoothstep(0.0, 1.0, t_caida)

			EstiloMontana.CORDILLERA_CRESTA:
				var dist_eje = abs(pos_xz.x - centro_mtn.x)
				var dist_long = abs(pos_xz.y - centro_mtn.y)
				var t_eje = clampf(dist_eje / (r_eff * 0.45), 0.0, 1.0)
				var t_long = clampf(dist_long / (r_eff * 1.1), 0.0, 1.0)
				h_factor = (1.0 - t_eje) * (1.0 - t_long * t_long)

			EstiloMontana.CRATER_VALLE:
				if t < 0.35:
					h_factor = lerpf(-0.45, 0.0, t / 0.35)
				elif t < 0.70:
					h_factor = lerpf(0.0, 1.0, (t - 0.35) / 0.35)
				else:
					h_factor = lerpf(1.0, 0.0, (t - 0.70) / 0.30)

		var h_base = h_factor * altura_montana

		# Escalonamiento en terrazas low-poly transitables
		if escalonamiento_terrazas and niveles_terraza >= 2 and h_base > 0.1:
			var h_paso = altura_montana / float(niveles_terraza)
			var n = h_base / h_paso
			var n_fl = floor(n)
			var frac = n - n_fl
			var ramp = smoothstep(0.70, 1.0, frac)
			h_base = (n_fl + ramp) * h_paso

		delta_h += h_base

	# Picos secundarios deterministas si cantidad_picos_montana > 1
	if cantidad_picos_montana >= 2:
		for pk_i in range(1, cantidad_picos_montana):
			var sub_seed = semilla + pk_i * 9973
			var jitter_ang = sin(float(sub_seed) * 1.3) * 0.35
			var ang_sub = (float(pk_i) / float(cantidad_picos_montana)) * TAU + jitter_ang
			var dist_sub = r_eff * (0.50 + abs(cos(float(sub_seed) * 2.1)) * 0.28)
			var centro_sub = centro_mtn + Vector2(cos(ang_sub), sin(ang_sub)) * dist_sub
			var r_sub = r_eff * (0.42 + abs(sin(float(sub_seed) * 3.7)) * 0.22)
			var d_sub = pos_xz.distance_to(centro_sub)
			if d_sub < r_sub:
				var t_sub = d_sub / r_sub
				var h_sub_factor = 0.50 + abs(cos(float(sub_seed) * 4.9)) * 0.25
				var h_sub = pow(1.0 - t_sub, 1.4) * altura_montana * h_sub_factor
				delta_h = maxf(delta_h, h_sub)

	return delta_h


func _evaluar_deformaciones_escultura(pos_xz: Vector2, h_relieve_base: float = 0.0) -> float:
	var delta_total = 0.0
	for d in deformaciones_escultura:
		var pos_c: Vector2 = d.get("pos", Vector2.ZERO)
		var r: float = d.get("radio", 3.0)
		var dx = pos_xz.x - pos_c.x
		if abs(dx) >= r:
			continue
		var dz = pos_xz.y - pos_c.y
		if abs(dz) >= r:
			continue
		var d2 = dx * dx + dz * dz
		if d2 >= r * r:
			continue

		var dist = sqrt(d2)
		var t = dist / r
		var falloff = 0.0
		var forma: int = d.get("forma", 0)

		match forma:
			0: # Cónica Low-Poly
				falloff = 1.0 - t
			1: # Meseta Plana
				falloff = 1.0 if t < 0.55 else (1.0 - (t - 0.55) / 0.45)
			2: # Cúpula Suave
				falloff = (1.0 - t * t) * (1.0 - t * t)

		var f: float = d.get("fuerza", 1.0)
		var paso = f * falloff
		var modo: int = d.get("modo", 0)
		var limitar_a_cero: bool = d.get("limitar_a_cero", false) or (modo == 4)

		match modo:
			0: # Elevar
				delta_total += paso
			1: # Hundir (extrusión hacia adentro del terreno)
				if limitar_a_cero:
					var target_delta = -h_relieve_base if (h_relieve_base > 0.0) else 0.0
					if delta_total > target_delta:
						var blend = clampf(paso * 1.5, 0.0, 1.0)
						delta_total = maxf(target_delta, lerpf(delta_total, target_delta, blend))
				else:
					delta_total -= paso
			2: # Aplanar / Terraza
				delta_total += paso * 0.5
			3: # Suavizar
				delta_total = lerpf(delta_total, 0.0, clampf(paso * 0.5, 0.0, 0.8))
			4: # Reducir a Base (vuelve a la superficie original suavemente sin crear hoyos, pozos ni bordes)
				var target_delta = -h_relieve_base if (h_relieve_base > 0.0) else 0.0
				if delta_total > target_delta:
					var blend = clampf(paso * 1.5, 0.0, 1.0)
					delta_total = maxf(target_delta, lerpf(delta_total, target_delta, blend))

	return delta_total


func aplicar_trazo_esculpido(pos_mundo: Vector3, radio: float, fuerza: float, modo: int, forma: int = 0, limitar_a_cero: bool = false) -> void:
	var pos_local = to_local(pos_mundo) if is_inside_tree() else (pos_mundo - position)
	var pos_xz = Vector2(pos_local.x, pos_local.z)

	var nuevo_trazo = {
		"pos": pos_xz,
		"radio": maxf(radio, 0.3),
		"fuerza": fuerza,
		"modo": modo,
		"forma": forma,
		"limitar_a_cero": limitar_a_cero or (modo == 4)
	}
	deformaciones_escultura.append(nuevo_trazo)
	_ultimo_trazo_pos = pos_xz
	_ultimo_trazo_radio = maxf(radio, 0.3)
	_solicitar_regeneracion()


## Finaliza el trazo continuo del pincel, reconstruyendo la colisión física sin congelar el editor
func finalizar_arrastre_escultura() -> void:
	_esculpiendo_activo = false
	if not _col_caras_cache.is_empty():
		_actualizar_colision(_col_caras_cache)
	elif not _regeneracion_pendiente:
		_solicitar_regeneracion()


## Fuerza la regeneración completa de la geometría y sincroniza todo el pasto (utilizado en Deshacer/Rehacer)
func regenerar_completo_con_pasto() -> void:
	_necesita_notificar_pasto_completo = true
	regenerar()


func limpiar_esculpido() -> void:
	deformaciones_escultura.clear()
	_solicitar_regeneracion(true)


func deshacer_ultimo_trazo() -> void:
	if not deformaciones_escultura.is_empty():
		deformaciones_escultura.pop_back()
		_solicitar_regeneracion(true)


## Genera variaciones sutiles de color ámbar-dorado para las facetas de pasto estilizado.
## Calibrado para coincidir con el tono cálido de PastoArea en pantalla (RGB [235-248, 178-195, 60-70]).
func _color_pasto(rng: RandomNumberGenerator, _indice: int, factor_mult: float = 1.0) -> Color:
	var blend = clampf(factor_mult - 1.0, 0.0, 1.0)
	var col_base = COLOR_PASTO_TERRENO.lerp(COLOR_PASTO_MECHON, blend)
	var jitter = (rng.randf() - 0.5) * 0.035
	return Color(
		clampf(col_base.r * factor_mult + jitter, 0.32, 0.60),
		clampf(col_base.g * factor_mult + jitter * 0.75, 0.20, 0.44),
		clampf(col_base.b * factor_mult + jitter * 0.20, 0.030, 0.095),
		1.0
	)


## Genera variaciones de color cálido terroso / caramelo idéntico al bloque derecho
func _color_roca(rng: RandomNumberGenerator, _indice: int, factor_mult: float = 1.0) -> Color:
	var jitter = (rng.randf() - 0.5) * 0.24 # Variación low-poly facetada (±12%)
	var mult = factor_mult * (1.0 + jitter)
	return Color(
		clampf(COLOR_ROCA_BASE.r * mult, 0.20, 0.75),
		clampf(COLOR_ROCA_BASE.g * mult * (0.96 if mult < 0.85 else 1.02), 0.15, 0.65),
		clampf(COLOR_ROCA_BASE.b * mult * (0.90 if mult < 0.85 else 1.04), 0.10, 0.55),
		1.0
	)


## ==============================================================================
## SISTEMA DE DECORACIÓN PROCEDURAL RESPETUOSO
## ==============================================================================
func _actualizar_decoracion(rng: RandomNumberGenerator, perimetro_pts: Array[Vector3], _perimetro_radios: Array[float]) -> void:
	if _decoracion_nodo == null:
		return

	# Limpiar elementos generados previamente
	for hijo in _decoracion_nodo.get_children():
		hijo.queue_free()
		_decoracion_nodo.remove_child(hijo)

	if not generar_decoracion:
		return

	var radio_x = ancho * 0.5
	var radio_z = largo * 0.5
	var margen_seguro = maxf(margen_borde, 0.8)

	var area_aprox = PI * radio_x * radio_z
	var max_objetos = clampi(int(area_aprox * 0.048 * densidad_decoracion), 1, 35)

	var puntos_ocupados: Array[Vector2] = []
	var dist_minima_entre_objetos = 2.4

	var pool_escenas: Array[PackedScene] = []
	if incluir_arboles:
		pool_escenas.append_array(ESCENAS_ARBOLES)
	if incluir_cristales:
		pool_escenas.append(ESCENA_CRISTALES)
	if incluir_faroles:
		pool_escenas.append(ESCENA_FAROL)

	if pool_escenas.is_empty():
		return

	var intentos = max_objetos * 6
	for _it in range(intentos):
		if puntos_ocupados.size() >= max_objetos:
			break

		var ang = rng.randf_range(0.0, TAU)
		var r_norm = sqrt(rng.randf())
		
		var limite_radio = _estimar_radio_en_angulo(ang, perimetro_pts) - margen_seguro
		if limite_radio <= radio_despeje_centro:
			continue

		var r_candidato = radio_despeje_centro + r_norm * (limite_radio - radio_despeje_centro)
		var pos_xz = Vector2(cos(ang) * r_candidato, sin(ang) * r_candidato)

		var muy_cerca = false
		for pt in puntos_ocupados:
			if pt.distance_to(pos_xz) < dist_minima_entre_objetos:
				muy_cerca = true
				break
		if muy_cerca:
			continue

		puntos_ocupados.append(pos_xz)

		var escena_elegida = pool_escenas[rng.randi() % pool_escenas.size()]
		var instancia = escena_elegida.instantiate() as Node3D
		if instancia == null:
			continue

		var pos_y = calcular_altura_en(pos_xz)
		var norm = calcular_normal_superficie_en(pos_xz)
		if norm.y < 0.72:
			instancia.queue_free()
			continue

		instancia.position = Vector3(pos_xz.x, pos_y, pos_xz.y)
		instancia.rotation.y = rng.randf_range(0.0, TAU)
		
		var escala_var = rng.randf_range(0.85, 1.2)
		instancia.scale = Vector3.ONE * escala_var

		_decoracion_nodo.add_child(instancia)
		if Engine.is_editor_hint():
			instancia.owner = get_tree().edited_scene_root if get_tree() else null

		# Garantizar que las fuentes de luz decorativas proyecten sombras y no traspasen la roca
		for hijo_luz in instancia.find_children("*", "Light3D", true, false):
			var luz = hijo_luz as Light3D
			if luz != null:
				luz.shadow_enabled = true
				luz.shadow_bias = 0.05
				luz.shadow_normal_bias = 1.0
				if luz is OmniLight3D:
					var omni = luz as OmniLight3D
					omni.omni_range = minf(omni.omni_range, maxf(ancho, largo) * 0.75 + 1.2)


func _estimar_radio_en_angulo(ang: float, perimetro_pts: Array[Vector3]) -> float:
	var n = perimetro_pts.size()
	if n == 0:
		return 1.0
	var ang_norm = fposmod(ang, TAU)
	var fracc = (ang_norm / TAU) * float(n)
	var idx = int(fracc) % n
	var next_idx = (idx + 1) % n
	var t = fracc - float(int(fracc))
	
	var r1 = Vector2(perimetro_pts[idx].x, perimetro_pts[idx].z).length()
	var r2 = Vector2(perimetro_pts[next_idx].x, perimetro_pts[next_idx].z).length()
	return lerpf(r1, r2, t)


## Comprueba si una coordenada local XZ se encuentra sobre la superficie superior de la isla
func tiene_punto_en_superficie(pos_xz: Vector2) -> bool:
	if _perimetro_pts_cache.is_empty():
		var rx = ancho * 0.5 * 1.15
		var rz = largo * 0.5 * 1.15
		return (pos_xz.x * pos_xz.x) / (rx * rx) + (pos_xz.y * pos_xz.y) / (rz * rz) <= 1.05

	var ang = atan2(pos_xz.y, pos_xz.x)
	var r_max = _estimar_radio_en_angulo(ang, _perimetro_pts_cache) + 0.15
	return pos_xz.length() <= r_max


## Notifica y adapta automáticamente todos los nodos GeneradorPasto en la escena para que su briznas sigan el relieve
func _notificar_generadores_pasto(centro: Vector2 = Vector2.INF, radio: float = -1.0) -> void:
	if not is_inside_tree() or get_tree() == null:
		return

	var visitados: Dictionary = {}
	var lista: Array[Node] = []

	# 1. Nodos registrados en el grupo oficial
	for n in get_tree().get_nodes_in_group("generador_pasto"):
		if is_instance_valid(n) and not visitados.has(n):
			visitados[n] = true
			lista.append(n)

	# 2. Hijos de esta isla
	for c in get_children():
		if is_instance_valid(c) and not visitados.has(c) and c.has_method("adaptar_a_superficie_isla"):
			visitados[c] = true
			lista.append(c)

	# 3. Hermanos en el mismo nivel de jerarquía
	if get_parent() != null:
		for s in get_parent().get_children():
			if is_instance_valid(s) and not visitados.has(s) and s.has_method("adaptar_a_superficie_isla"):
				visitados[s] = true
				lista.append(s)

	for gen in lista:
		if is_instance_valid(gen) and gen.has_method("adaptar_a_superficie_isla"):
			gen.adaptar_a_superficie_isla(self, centro, radio)


## ==============================================================================
## COMPORTAMIENTO FUNCIONAL DE PLATAFORMA (COLAPSO Y ESPIRITUAL)
## ==============================================================================

func _al_cambiar_tipo_comportamiento() -> void:
	match tipo_comportamiento:
		TipoComportamiento.COLAPSO:
			collision_layer = 1
			collision_mask = 1
			_asegurar_area_colapso()
		TipoComportamiento.ESPIRITUAL:
			collision_layer = 1 << 2
			collision_mask = 1 << 2
			if is_instance_valid(_area_colapso):
				_area_colapso.queue_free()
				_area_colapso = null
		TipoComportamiento.ESTANDAR:
			collision_layer = 1
			collision_mask = 0
			if is_instance_valid(_area_colapso):
				_area_colapso.queue_free()
				_area_colapso = null
	_actualizar_materiales()
	notify_property_list_changed()


## -----------------------------------------------------------------------------
## MECÁNICAS DE PLATAFORMA ESPIRITUAL
## -----------------------------------------------------------------------------

func _asegurar_material_espiritual() -> void:
	if _mat_espiritual_instancia == null:
		var mat_base = material_espiritual if material_espiritual != null else MAT_ESPIRITUAL_DEFAULT
		if mat_base is ShaderMaterial:
			_mat_espiritual_instancia = mat_base.duplicate() as ShaderMaterial
		else:
			_mat_espiritual_instancia = MAT_ESPIRITUAL_DEFAULT.duplicate() as ShaderMaterial

	var span_y = profundidad_roca + maxf(0.0, altura_superficie + (altura_montana if habilitar_montanas else 0.0))
	_mat_espiritual_instancia.set_shader_parameter("altura_caja", span_y)
	_mat_espiritual_instancia.set_shader_parameter("desfase_y", (profundidad_roca - maxf(0.0, altura_superficie)) * 0.5)
	var opac = opacidad_activa if (esta_activo or Engine.is_editor_hint()) else opacidad_inactiva
	_mat_espiritual_instancia.set_shader_parameter("opacidad_global", opac)


func _inicializar_modo_espiritual() -> void:
	collision_layer = 1 << 2  # Capa 3: Plano_Espiritual
	collision_mask = 1 << 2
	_opacidad_actual = opacidad_inactiva
	_cachear_materiales(self)

	var nodos_disparadores: Array[Node3D] = []
	var disp_unido = _resolver_nodo(disparador_objetivo)
	if disp_unido and not disp_unido in nodos_disparadores:
		nodos_disparadores.append(disp_unido)
	for item in disparadores_objetivo:
		var n = _resolver_nodo(item)
		if n and not n in nodos_disparadores:
			nodos_disparadores.append(n)

	_actualizar_materiales()

	if nodos_disparadores.is_empty():
		actualizar_comportamiento(esta_activo)
		return

	for disp in nodos_disparadores:
		_estados_disparadores[disp] = false
		var conectado = false
		var callable_activado = Callable(self, "_on_disparador_estado_cambiado").bind(disp, true)
		var callable_desactivado = Callable(self, "_on_disparador_estado_cambiado").bind(disp, false)

		if disp.has_signal("signal_activado"):
			if not disp.is_connected("signal_activado", callable_activado):
				disp.connect("signal_activado", callable_activado)
			conectado = true
		else:
			push_error("[%s] ERROR: El disparador '%s' no tiene la señal 'signal_activado'." % [name, disp.name])

		if disp.has_signal("signal_desactivado"):
			if not disp.is_connected("signal_desactivado", callable_desactivado):
				disp.connect("signal_desactivado", callable_desactivado)

		if conectado:
			print("[%s] Isla Espiritual conectada dinámicamente al disparador: %s" % [name, disp.name])

	actualizar_comportamiento(false)


func actualizar_comportamiento(activo: bool) -> void:
	if tipo_comportamiento != TipoComportamiento.ESPIRITUAL:
		return

	esta_activo = activo
	if activo:
		# Activa: sólida para el Vivo (Capa 2) y el Fantasma (Capa 3)
		collision_layer = (1 << 1) | (1 << 2)
		collision_mask = (1 << 1) | (1 << 2)
		_transicionar_opacidad_espiritual(opacidad_activa)
	else:
		# Inactiva: intangible para el Vivo, pero sólida para el Fantasma (Capa 3)
		collision_layer = 1 << 2
		collision_mask = 1 << 2
		_transicionar_opacidad_espiritual(opacidad_inactiva)

	estado_espiritual_cambiado.emit(activo)


func _transicionar_opacidad_espiritual(opacidad_meta: float) -> void:
	if _tween_opacidad and _tween_opacidad.is_valid():
		_tween_opacidad.kill()

	if not is_inside_tree() or Engine.is_editor_hint():
		_aplicar_opacidad_espiritual(opacidad_meta)
		return

	_tween_opacidad = create_tween()
	_tween_opacidad.set_trans(Tween.TRANS_SINE)
	_tween_opacidad.set_ease(Tween.EASE_OUT)
	_tween_opacidad.tween_method(_aplicar_opacidad_espiritual, _opacidad_actual, opacidad_meta, 0.4)


func _aplicar_opacidad_espiritual(opacidad: float) -> void:
	_opacidad_actual = clampf(opacidad, 0.0, 1.0)
	if _mat_espiritual_instancia:
		_mat_espiritual_instancia.set_shader_parameter("opacidad_global", _opacidad_actual)
	_cambiar_opacidad_recursivo(self, _opacidad_actual)


@rpc("any_peer", "call_local", "reliable")
func rpc_sincronizar_estado(activo: bool) -> void:
	esta_activo = activo
	actualizar_comportamiento(activo)
	print("[%s] Sincronización P2P: Estado general actualizado a -> %s" % [name, "ACTIVO" if activo else "INACTIVO"])


func _on_disparador_estado_cambiado(disp: Node3D, activo: bool) -> void:
	_estados_disparadores[disp] = activo

	var condicion_cumplida = false
	if condicion_combinacion == ElementoInteractivoBase.CondicionCombinacion.CONDICION_O:
		for estado in _estados_disparadores.values():
			if estado:
				condicion_cumplida = true
				break
	else:
		condicion_cumplida = true
		for estado in _estados_disparadores.values():
			if not estado:
				condicion_cumplida = false
				break

	if condicion_cumplida != esta_activo:
		if multiplayer and multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
			rpc_sincronizar_estado.rpc(condicion_cumplida)
		else:
			rpc_sincronizar_estado(condicion_cumplida)


func _resolver_nodo(target: Variant) -> Node3D:
	if target is Node3D:
		return target
	elif target is NodePath and not (target as NodePath).is_empty():
		var n = get_node_or_null(target)
		if n is Node3D:
			return n
	return null


func _cachear_materiales(nodo: Node) -> void:
	if nodo is MeshInstance3D and nodo != _mesh_instance:
		var cache_entry = {"override": null, "surfaces": []}
		if nodo.material_override:
			cache_entry["override"] = nodo.material_override.duplicate()
			nodo.material_override = cache_entry["override"]
		if nodo.get_mesh():
			for i in range(nodo.get_mesh().get_surface_count()):
				var material = nodo.get_active_material(i)
				if not material:
					material = nodo.get_mesh().surface_get_material(i)
				if material:
					var mat_dup = material.duplicate()
					nodo.set_surface_override_material(i, mat_dup)
					cache_entry["surfaces"].append(mat_dup)
				else:
					cache_entry["surfaces"].append(null)
		_materiales_cacheados[nodo] = cache_entry
	for hijo in nodo.get_children():
		_cachear_materiales(hijo)


func _cambiar_opacidad_recursivo(nodo: Node, opacidad: float) -> void:
	if nodo is MeshInstance3D and nodo != _mesh_instance:
		nodo.visible = (opacidad > 0.001)
		if _materiales_cacheados.has(nodo):
			var cache = _materiales_cacheados[nodo]
			if cache["override"]:
				_aplicar_opacidad_a_material(cache["override"], opacidad)
			for mat in cache["surfaces"]:
				if mat:
					_aplicar_opacidad_a_material(mat, opacidad)
		else:
			if nodo.material_override:
				_aplicar_opacidad_a_material(nodo.material_override, opacidad)
	for hijo in nodo.get_children():
		_cambiar_opacidad_recursivo(hijo, opacidad)


func _aplicar_opacidad_a_material(mat: Material, opacidad: float) -> void:
	if mat is ShaderMaterial:
		mat.set_shader_parameter("opacidad_global", opacidad)
	elif mat is BaseMaterial3D:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var color = mat.albedo_color
		color.a = opacidad
		mat.albedo_color = color


## -----------------------------------------------------------------------------
## MECÁNICAS DE PLATAFORMA COLAPSO
## -----------------------------------------------------------------------------

func _asegurar_area_colapso() -> void:
	if not is_inside_tree():
		return

	if tipo_comportamiento != TipoComportamiento.COLAPSO:
		if is_instance_valid(_area_colapso):
			_area_colapso.queue_free()
			_area_colapso = null
		return

	if _area_colapso == null:
		_area_colapso = get_node_or_null("AreaDeteccionColapso") as Area3D
		if _area_colapso == null:
			_area_colapso = get_node_or_null("Area3D") as Area3D
		if _area_colapso == null:
			_area_colapso = Area3D.new()
			_area_colapso.name = "AreaDeteccionColapso"
			add_child(_area_colapso)

	_area_colapso.collision_layer = 0
	_area_colapso.collision_mask = 7 # Detecta capas 1 (Global), 2 (Vivo) y 3 (Fantasma)
	_area_colapso.monitoring = true
	_area_colapso.visible = true

	var col_shape = _area_colapso.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col_shape == null:
		col_shape = CollisionShape3D.new()
		col_shape.name = "CollisionShape3D"
		_area_colapso.add_child(col_shape)

	var cylinder = col_shape.shape as CylinderShape3D
	if cylinder == null:
		cylinder = CylinderShape3D.new()
		col_shape.shape = cylinder

	cylinder.radius = maxf(1.0, minf(ancho, largo) * 0.48)
	cylinder.height = 1.2
	col_shape.position = Vector3(0.0, altura_superficie + 0.6, 0.0)

	if not _area_colapso.body_entered.is_connected(_on_area_colapso_body_entered):
		_area_colapso.body_entered.connect(_on_area_colapso_body_entered)


func _on_area_colapso_body_entered(body: Node) -> void:
	if _estado_colapso != "normal" or esta_congelada:
		return
	if body is Fantasma or body is Jugador or body.name == "Fantasma" or body.name == "Jugador":
		_iniciar_temblor_colapso()


func _iniciar_temblor_colapso() -> void:
	_estado_colapso = "temblando"
	_timer_colapso = 0.0
	plataforma_colapsando.emit()
	if material_alerta and is_instance_valid(_mesh_instance):
		_mesh_instance.set_surface_override_material(0, material_alerta)
		if _mesh_instance.mesh and _mesh_instance.mesh.get_surface_count() > 1:
			_mesh_instance.set_surface_override_material(1, material_alerta)


func _iniciar_caida_colapso() -> void:
	_estado_colapso = "caida"
	_timer_colapso = 0.0
	if is_instance_valid(_collision_shape):
		_collision_shape.set_deferred("disabled", true)


func _ocultar_colapso() -> void:
	_estado_colapso = "oculta"
	_timer_colapso = 0.0
	visible = false


func _restaurar_colapso() -> void:
	_estado_colapso = "normal"
	visible = true
	global_position = _posicion_inicial_colapso
	if is_instance_valid(_collision_shape):
		_collision_shape.set_deferred("disabled", false)
	_actualizar_materiales()
	plataforma_restaurada.emit()


func congelar_estasis(_duracion: float = 0.0) -> void:
	esta_congelada = true


func descongelar_estasis() -> void:
	esta_congelada = false


func _procesar_fisica_colapso(delta: float) -> void:
	if esta_congelada:
		return

	match _estado_colapso:
		"temblando":
			_timer_colapso += delta
			global_position.x = _posicion_inicial_colapso.x + sin(_timer_colapso * 42.0) * 0.06
			global_position.z = _posicion_inicial_colapso.z + cos(_timer_colapso * 36.0) * 0.04
			if _timer_colapso >= delay_antes_caida:
				_iniciar_caida_colapso()

		"caida":
			_timer_colapso += delta
			var progreso = _timer_colapso / maxf(0.01, duracion_caida)
			global_position.y = _posicion_inicial_colapso.y - (progreso * progreso * distancia_caida)
			if progreso >= 1.0:
				_ocultar_colapso()

		"oculta":
			_timer_colapso += delta
			if _timer_colapso >= tiempo_respawn:
				_restaurar_colapso()


