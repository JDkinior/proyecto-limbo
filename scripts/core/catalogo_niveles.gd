extends RefCounted
class_name CatalogoNiveles

## ==============================================================================
## CATÁLOGO CENTRALIZADO DE NIVELES (PROYECTO LIMBO)
## Fuente única de verdad para el orden, metadatos y progresión de niveles.
## Desacopla metas (Goal), pantalla de resultados, menús y RedManager.
## ==============================================================================

const NOMBRES_CAPITULOS := {
	1: "Praderas y Ruinas",
	2: "Montaña Ventosa",
	3: "Bosque del Faro",
	4: "Minas de Cristal",
	5: "Cielo Tormentoso",
	6: "El Limbo",
}

## Lista ordenada de niveles que conforman la campaña cooperativa/historia.
const NIVELES_CAMPANA: Array[Dictionary] = [
	{
		"id": "nivel_1",
		"titulo": "Nivel 1: El Despertar Separado",
		"capitulo": 1,
		"escena_path": "res://scenes/levels/Nivel 1 _ El Despertar Separado.tscn",
		"tiempo_objetivo": 180.0,
		"es_historia": true,
	},
	{
		"id": "nivel_2",
		"titulo": "Nivel 2: El Camino del Faro",
		"capitulo": 1,
		"escena_path": "res://scenes/levels/nivel 2.tscn",
		"tiempo_objetivo": 210.0,
		"es_historia": true,
	},
	{
		"id": "nivel_3",
		"titulo": "Nivel 3: La Gran Montaña",
		"capitulo": 2,
		"escena_path": "res://scenes/levels/nivel_3_la_montana.tscn",
		"tiempo_objetivo": 240.0,
		"es_historia": true,
	},
	{
		"id": "nivel_4",
		"titulo": "Nivel 4: El Ascenso del Vendaval",
		"capitulo": 2,
		"escena_path": "res://scenes/levels/nivel_4_el_ascenso_del_vendaval.tscn",
		"tiempo_objetivo": 250.0,
		"es_historia": true,
	},
	{
		"id": "nivel_5",
		"titulo": "Nivel 5: Las Raíces Brumosas",
		"capitulo": 3,
		"escena_path": "res://scenes/levels/nivel_5_las_raices_brumosas.tscn",
		"tiempo_objetivo": 240.0,
		"es_historia": true,
	},
	{
		"id": "nivel_6",
		"titulo": "Nivel 6: El Faro Ancestral",
		"capitulo": 3,
		"escena_path": "res://scenes/levels/nivel_6_el_faro_ancestral.tscn",
		"tiempo_objetivo": 260.0,
		"es_historia": true,
	},
	{
		"id": "nivel_7",
		"titulo": "Nivel 7: Las Cavernas Resonantes",
		"capitulo": 4,
		"escena_path": "res://scenes/levels/nivel_7_las_cavernas_resonantes.tscn",
		"tiempo_objetivo": 240.0,
		"es_historia": true,
	},
	{
		"id": "nivel_8",
		"titulo": "Nivel 8: El Corazón Cristalino",
		"capitulo": 4,
		"escena_path": "res://scenes/levels/nivel_8_el_corazon_cristalino.tscn",
		"tiempo_objetivo": 270.0,
		"es_historia": true,
	},
	{
		"id": "nivel_9",
		"titulo": "Nivel 9: El Mar de Nubes",
		"capitulo": 5,
		"escena_path": "res://scenes/levels/nivel_9_el_mar_de_nubes.tscn",
		"tiempo_objetivo": 240.0,
		"es_historia": true,
	},
	{
		"id": "nivel_10",
		"titulo": "Nivel 10: Las Ruinas de la Tormenta",
		"capitulo": 5,
		"escena_path": "res://scenes/levels/nivel_10_las_ruinas_de_la_tormenta.tscn",
		"tiempo_objetivo": 270.0,
		"es_historia": true,
	},
	{
		"id": "nivel_11",
		"titulo": "Nivel 11: El Último Umbral",
		"capitulo": 6,
		"escena_path": "res://scenes/levels/nivel_11_el_ultimo_umbral.tscn",
		"tiempo_objetivo": 300.0,
		"es_historia": true,
	},
	{
		"id": "nivel_12",
		"titulo": "Nivel 12: El Encuentro en el Limbo",
		"capitulo": 6,
		"escena_path": "res://scenes/levels/nivel_12_el_encuentro_en_el_limbo.tscn",
		"tiempo_objetivo": 360.0,
		"es_historia": true,
	},
]

## Niveles adicionales para pruebas o modo libre fuera de la campaña principal.
const NIVELES_EXTRA: Array[Dictionary] = [
	{
		"id": "mundo_pruebas",
		"titulo": "Mundo de Pruebas (Sandbox)",
		"capitulo": 0,
		"escena_path": "res://scenes/levels/mundo_pruebas.tscn",
		"tiempo_objetivo": 300.0,
		"es_historia": false,
	},
		{
		"id": "prueba_posesion_shorts",
		"titulo": "Prueba de posesion",
		"capitulo": 0,
		"escena_path": "res://scenes/levels/prueba_posesion_shorts.tscn",
		"tiempo_objetivo": 300.0,
		"es_historia": false,
	},
]

## Retorna la cantidad de niveles que pertenecen a la campaña de historia.
static func total_niveles_historia() -> int:
	return NIVELES_CAMPANA.size()

## Retorna la ruta de la escena del nivel de historia según su índice (0-indexado).
static func obtener_ruta_nivel_historia(indice: int) -> String:
	if indice >= 0 and indice < NIVELES_CAMPANA.size():
		return NIVELES_CAMPANA[indice]["escena_path"]
	return ""

## Retorna todas las rutas de los niveles de la campaña en orden.
static func obtener_rutas_campana() -> Array[String]:
	var rutas: Array[String] = []
	for n in NIVELES_CAMPANA:
		rutas.append(n["escena_path"])
	return rutas

## Retorna la lista unificada de todos los niveles (campaña + extras).
static func obtener_todos_los_niveles() -> Array[Dictionary]:
	var todos: Array[Dictionary] = []
	todos.append_array(NIVELES_CAMPANA)
	todos.append_array(NIVELES_EXTRA)
	return todos

## Retorna la lista de rutas de todos los niveles registrados.
static func obtener_rutas_todos_los_niveles() -> Array[String]:
	var rutas: Array[String] = []
	for n in obtener_todos_los_niveles():
		rutas.append(n["escena_path"])
	return rutas

## Busca los datos de un nivel según la ruta de su escena.
static func obtener_datos_por_ruta(ruta: String) -> Dictionary:
	for n in obtener_todos_los_niveles():
		if n["escena_path"] == ruta:
			return n
	return {}

## Determina la siguiente escena en la secuencia de campaña a partir de la escena actual.
## Si es el último nivel o no pertenece a la campaña, retorna cadena vacía "".
static func obtener_siguiente_nivel_path(ruta_actual: String) -> String:
	for i in range(NIVELES_CAMPANA.size()):
		if NIVELES_CAMPANA[i]["escena_path"] == ruta_actual:
			if i + 1 < NIVELES_CAMPANA.size():
				return NIVELES_CAMPANA[i + 1]["escena_path"]
			else:
				return "" # Campaña completada
	return ""

## Retorna el nombre por defecto del capítulo según su número.
static func obtener_titulo_capitulo(num_capitulo: int) -> String:
	return NOMBRES_CAPITULOS.get(num_capitulo, "Capítulo %d" % num_capitulo)
