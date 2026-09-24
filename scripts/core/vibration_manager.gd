extends Node

## VibrationManager
## Administrador global para feedback háptico en dispositivos móviles (Android/iOS)
## y vibración en mandos / gamepads. Permite activar y desactivar la vibración
## y persistir la configuración en user://opciones.cfg.

signal vibracion_cambiada(habilitada: bool)

const CONFIG_PATH = "user://opciones.cfg"
const SECTION_JUEGO = "juego"
const KEY_VIBRACION = "vibracion_habilitada"

var vibracion_habilitada: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cargar_config()

func esta_habilitada() -> bool:
	return vibracion_habilitada

func establecer_habilitada(habilitada: bool) -> void:
	if vibracion_habilitada != habilitada:
		vibracion_habilitada = habilitada
		guardar_config()
		vibracion_cambiada.emit(vibracion_habilitada)
		print("[VibrationManager] Vibración establecida en: ", vibracion_habilitada)

func cargar_config() -> void:
	var config_file = ConfigFile.new()
	var err = config_file.load(CONFIG_PATH)
	if err == OK and config_file.has_section(SECTION_JUEGO):
		vibracion_habilitada = config_file.get_value(SECTION_JUEGO, KEY_VIBRACION, true)
	else:
		vibracion_habilitada = true

func guardar_config() -> void:
	var config_file = ConfigFile.new()
	var _err = config_file.load(CONFIG_PATH)
	config_file.set_value(SECTION_JUEGO, KEY_VIBRACION, vibracion_habilitada)
	var save_err = config_file.save(CONFIG_PATH)
	if save_err == OK:
		print("[VibrationManager] Configuración guardada exitosamente en: ", CONFIG_PATH)
	else:
		push_error("[VibrationManager] Error al guardar configuración: " + str(save_err))

# ─────────────────────────────────────────────────────────────────────────────
# MÉTODOS DE VIBRACIÓN BÁSICOS Y MULTIPLATAFORMA
# ─────────────────────────────────────────────────────────────────────────────

func vibrar(duracion_ms: int = 40, weak_joy: float = 0.25, strong_joy: float = 0.0, duracion_joy_sec: float = 0.1) -> void:
	if not vibracion_habilitada:
		return

	# 1. Vibración háptica en móvil (Android / iOS)
	if duracion_ms > 0:
		Input.vibrate_handheld(duracion_ms)

	# 2. Vibración en mandos / gamepads conectados
	var joypads = Input.get_connected_joypads()
	if joypads.size() > 0:
		for dev in joypads:
			Input.start_joy_vibration(dev, clampf(weak_joy, 0.0, 1.0), clampf(strong_joy, 0.0, 1.0), duracion_joy_sec)

func detener_vibracion_mando() -> void:
	var joypads = Input.get_connected_joypads()
	for dev in joypads:
		Input.stop_joy_vibration(dev)

# ─────────────────────────────────────────────────────────────────────────────
# PRESETS TEMÁTICOS PARA PERSONAJES Y ACCIONES
# ─────────────────────────────────────────────────────────────────────────────

## Salto de personaje: pulso ligero de despegue
func vibrar_salto(numero_salto: int = 1) -> void:
	if numero_salto == 1:
		vibrar(25, 0.22, 0.0, 0.07)
	else:
		# Segundo salto / doble salto
		vibrar(38, 0.38, 0.12, 0.09)

## Aterrizaje tras caída: impacto proporcional a la fuerza de caída
func vibrar_aterrizaje(intensidad: float = 1.0) -> void:
	var factor = clampf(intensidad, 0.4, 2.0)
	var ms = int(35 * factor)
	var weak = clampf(0.35 * factor, 0.15, 0.85)
	var strong = clampf(0.20 * factor, 0.05, 0.70)
	vibrar(ms, weak, strong, 0.10 * factor)

## Embate físico del Jugador: golpe / tackle contundente
func vibrar_embate() -> void:
	vibrar(95, 0.75, 0.50, 0.16)

## Impacto contra muro o caja rompible
func vibrar_impacto_fuerte() -> void:
	vibrar(120, 0.85, 0.70, 0.20)

## Habilidad de Aura del Fantasma al encenderse: resonancia mística espectral
func vibrar_aura_activar() -> void:
	vibrar(80, 0.60, 0.25, 0.15)

## Habilidad de Aura del Fantasma al expirar o apagarse: desvanecimiento sutil
func vibrar_aura_desactivar() -> void:
	vibrar(30, 0.20, 0.0, 0.06)

## Alternar de personaje (Vivo <-> Fantasma en modo 1 jugador): doble pulso armónico
func vibrar_cambio_personaje() -> void:
	if not vibracion_habilitada:
		return
	vibrar(30, 0.35, 0.10, 0.06)
	var tw = create_tween()
	tw.tween_interval(0.065)
	tw.tween_callback(func():
		vibrar(40, 0.45, 0.20, 0.08)
	)

## Recolección de moneda o gema: click háptico táctil nítido
func vibrar_coleccionable() -> void:
	vibrar(22, 0.30, 0.0, 0.05)

## Activación de mecanismo (Palanca, manivela, botón de presión)
func vibrar_mecanismo() -> void:
	vibrar(45, 0.45, 0.15, 0.10)

## Daño recibido, absorción por torbellino o reaparición por caída al vacío
func vibrar_dano() -> void:
	vibrar(170, 0.85, 0.75, 0.25)
