class_name AdministradorNubes3D
extends Node3D

# ===================================================================
# ADMINISTRADOR DE NUBES 3D (PROYECTO LIMBO)
# Distribuye y gestiona capas de nubes dinámicas estilizadas
# ===================================================================

@export_group("Generación Automática")
@export var generar_automaticamente: bool = true
@export var cantidad_nubes_fisicas: int = 8
@export var cantidad_nubes_espirituales: int = 5

@export_group("Área y Alturas")
@export var area_min: Vector3 = Vector3(-65.0, 9.0, -45.0)
@export var area_max: Vector3 = Vector3(65.0, 28.0, 55.0)

@export_group("Variaciones")
@export var escala_min: float = 0.9
@export var escala_max: float = 2.6
@export var velocidad_min: float = 1.0
@export var velocidad_max: float = 2.4
@export var direccion_viento: Vector3 = Vector3(1.0, 0.0, 0.25)

const ESCENA_NUBE_FISICA = preload("res://scenes/components/nube_estilizada_3d.tscn")
const ESCENA_NUBE_ESPIRITUAL = preload("res://scenes/components/nube_estilizada_espiritual_3d.tscn")

func _ready() -> void:
	if generar_automaticamente and get_child_count() == 0:
		_generar_nubes()
	else:
		_sincronizar_nubes_existentes()

func _generar_nubes() -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	# 1. Instanciar nubes físicas (predominan en el lado izquierdo / centro físico)
	for i in range(cantidad_nubes_fisicas):
		var nube = ESCENA_NUBE_FISICA.instantiate()
		_configurar_instancia_nube(nube, rng, false)
		add_child(nube)

	# 2. Instanciar nubes espirituales (predominan en el lado derecho / plano espiritual)
	for i in range(cantidad_nubes_espirituales):
		var nube = ESCENA_NUBE_ESPIRITUAL.instantiate()
		_configurar_instancia_nube(nube, rng, true)
		add_child(nube)

func _configurar_instancia_nube(nube: Node3D, rng: RandomNumberGenerator, es_espiritual: bool) -> void:
	# Posición aleatoria dentro del volumen del cielo
	var px: float
	if es_espiritual:
		# Plano espiritual suele estar desplazado en X positiva en los niveles
		px = rng.randf_range(0.0, area_max.x)
	else:
		# Plano físico suele estar en X negativa/central
		px = rng.randf_range(area_min.x, 15.0)

	var py = rng.randf_range(area_min.y, area_max.y)
	var pz = rng.randf_range(area_min.z, area_max.z)
	nube.position = Vector3(px, py, pz)

	# Escala aleatoria para profundidad y diversidad
	var esc = rng.randf_range(escala_min, escala_max)
	# Las nubes más altas suelen ser más grandes
	var factor_altura = clamp((py - area_min.y) / (area_max.y - area_min.y), 0.0, 1.0)
	esc *= lerp(0.9, 1.3, factor_altura)
	nube.scale = Vector3(esc, esc * rng.randf_range(0.85, 1.1), esc)

	# Configurar parámetros del script NubeFlotante si existe
	if nube is NubeFlotante:
		nube.velocidad = rng.randf_range(velocidad_min, velocidad_max)
		nube.direccion = direccion_viento
		nube.limites_min = area_min
		nube.limites_max = area_max
		nube.amplitud_flotacion = rng.randf_range(0.2, 0.6)
		nube.frecuencia_flotacion = rng.randf_range(0.5, 0.9)

func _sincronizar_nubes_existentes() -> void:
	for hijo in get_children():
		if hijo is NubeFlotante:
			hijo.limites_min = area_min
			hijo.limites_max = area_max
			hijo.direccion = direccion_viento
