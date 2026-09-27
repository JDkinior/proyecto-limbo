extends Node

## VibrationManager
## Administrador global para feedback háptico inmersivo en dispositivos móviles (Android/iOS)
## y vibración en mandos / gamepads. Soporta vibraciones instantáneas y continuas dinámicas
## para puertas mecánicas, auras místicas, torbellinos y mecanismos físicos.
## Persiste la configuración en user://opciones.cfg.

signal vibracion_cambiada(habilitada: bool)

const CONFIG_PATH = "user://opciones.cfg"
const SECTION_JUEGO = "juego"
const KEY_VIBRACION = "vibracion_habilitada"

var vibracion_habilitada: bool = true

# Diccionario de efectos continuos activos:
# id -> {
#   "intensidad": float (0.0 a 1.0),
#   "cadencia_sec": float,
#   "duracion_pulso_ms": int,
#   "weak_joy": float,
#   "strong_joy": float,
#   "tiempo_restante": float (-1.0 si es continuo indefinido),
#   "_timer": float,
#   "al_terminar": Callable
# }
var _efectos_continuos: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cargar_config()

func esta_habilitada() -> bool:
	return vibracion_habilitada

func establecer_habilitada(habilitada: bool) -> void:
	if vibracion_habilitada != habilitada:
		vibracion_habilitada = habilitada
		if not vibracion_habilitada:
			detener_todas_las_vibraciones_continuas()
			detener_vibracion_mando()
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
# BUCLE DE PROCESAMIENTO HÁPTICO CONTINUO
# ─────────────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not vibracion_habilitada or _efectos_continuos.is_empty():
		return

	var ids_a_eliminar: Array[String] = []
	var max_weak_joy: float = 0.0
	var max_strong_joy: float = 0.0
	var es_movil = OS.has_feature("mobile") or OS.has_feature("android")

	for id in _efectos_continuos.keys():
		var ef = _efectos_continuos[id]
		var factor_intensidad = clampf(ef.intensidad, 0.0, 1.0)
		if factor_intensidad <= 0.01:
			continue

		# 1. Pulsos rítmicos para hardware móvil
		ef._timer += delta
		if ef._timer >= ef.cadencia_sec:
			ef._timer = 0.0
			if es_movil:
				var ms = int(ef.duracion_pulso_ms * (0.6 + 0.4 * factor_intensidad))
				Input.vibrate_handheld(maxi(ms, 38))

		# 2. Acumular motores de vibración de mandos (gamepads)
		max_weak_joy = maxf(max_weak_joy, ef.weak_joy * factor_intensidad)
		max_strong_joy = maxf(max_strong_joy, ef.strong_joy * factor_intensidad)

		# 3. Control de duración finita si está configurada
		if ef.tiempo_restante > 0.0:
			ef.tiempo_restante -= delta
			if ef.tiempo_restante <= 0.0:
				ids_a_eliminar.append(id)
				if ef.al_terminar.is_valid():
					ef.al_terminar.call()

	# Aplicar rumble combinado a todos los mandos conectados
	if max_weak_joy > 0.0 or max_strong_joy > 0.0:
		var joypads = Input.get_connected_joypads()
		for dev in joypads:
			Input.start_joy_vibration(dev, clampf(max_weak_joy, 0.0, 1.0), clampf(max_strong_joy, 0.0, 1.0), 0.12)

	# Limpiar efectos expirados
	for id in ids_a_eliminar:
		_efectos_continuos.erase(id)

# ─────────────────────────────────────────────────────────────────────────────
# MÉTODOS DE VIBRACIÓN BÁSICOS Y MULTIPLATAFORMA
# ─────────────────────────────────────────────────────────────────────────────

## Dispara un pulso háptico puntual e instantáneo
func vibrar(duracion_ms: int = 45, weak_joy: float = 0.25, strong_joy: float = 0.0, duracion_joy_sec: float = 0.1) -> void:
	if not vibracion_habilitada:
		return

	# 1. Vibración háptica en móvil (Android / iOS)
	if duracion_ms > 0:
		var ms_movil = maxi(duracion_ms, 38) if (OS.has_feature("mobile") or OS.has_feature("android")) else duracion_ms
		Input.vibrate_handheld(ms_movil)

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
# GESTOR DE EFECTOS HÁPTICOS CONTINUOS
# ─────────────────────────────────────────────────────────────────────────────

## Inicia o actualiza un efecto continuo en un canal identificado por 'id'
func iniciar_vibracion_continua(
	id: String,
	intensidad: float = 1.0,
	cadencia_sec: float = 0.08,
	duracion_pulso_ms: int = 44,
	weak_joy: float = 0.35,
	strong_joy: float = 0.40,
	tiempo_duracion: float = -1.0,
	al_terminar: Callable = Callable()
) -> void:
	if not vibracion_habilitada:
		return

	_efectos_continuos[id] = {
		"intensidad": clampf(intensidad, 0.0, 1.0),
		"cadencia_sec": maxf(cadencia_sec, 0.04),
		"duracion_pulso_ms": duracion_pulso_ms,
		"weak_joy": weak_joy,
		"strong_joy": strong_joy,
		"tiempo_restante": tiempo_duracion,
		"_timer": cadencia_sec, # Disparar el primer pulso de inmediato
		"al_terminar": al_terminar
	}

## Modifica la intensidad sobre la marcha de un efecto continuo activo
func actualizar_vibracion_continua(id: String, nueva_intensidad: float) -> void:
	if _efectos_continuos.has(id):
		_efectos_continuos[id]["intensidad"] = clampf(nueva_intensidad, 0.0, 1.0)

## Detiene un efecto continuo específico
func detener_vibracion_continua(id: String) -> void:
	if _efectos_continuos.has(id):
		_efectos_continuos.erase(id)
	if _efectos_continuos.is_empty():
		detener_vibracion_mando()

func esta_vibracion_continua_activa(id: String) -> bool:
	return _efectos_continuos.has(id)

func detener_todas_las_vibraciones_continuas() -> void:
	_efectos_continuos.clear()
	detener_vibracion_mando()

# ─────────────────────────────────────────────────────────────────────────────
# 1. PUERTAS Y COMPUERTAS MECÁNICAS (Vibración continua durante movimiento)
# ─────────────────────────────────────────────────────────────────────────────

## Inicia el retumbe mecánico de piedra/metal mientras la puerta se desplaza
func iniciar_vibracion_puerta(id: String, duracion: float, factor_proximidad: float = 1.0) -> void:
	if not vibracion_habilitada or factor_proximidad <= 0.02:
		return
	var factor = clampf(factor_proximidad, 0.15, 1.0)
	iniciar_vibracion_continua(
		id,
		factor,
		0.078,                      # Cadencia de ruidos de engranaje/roce
		44,                         # Duración de pulso
		0.38 * factor,              # Motor débil mando
		0.48 * factor,              # Motor fuerte mando (graves)
		duracion
	)

## Detiene el retumbe de la puerta y genera un impacto sordo cuando hace tope
func detener_vibracion_puerta(id: String, con_impacto_final: bool = true, factor_proximidad: float = 1.0) -> void:
	detener_vibracion_continua(id)
	if con_impacto_final and vibracion_habilitada and factor_proximidad > 0.05:
		vibrar_tope_puerta(factor_proximidad)

## Impacto pesado de cierre/apertura completa de compuerta
func vibrar_tope_puerta(intensidad: float = 1.0) -> void:
	var f = clampf(intensidad, 0.2, 1.0)
	vibrar(int(85 * f), 0.55 * f, 0.75 * f, 0.18 * f)

# ─────────────────────────────────────────────────────────────────────────────
# 2. HABILIDAD DE AURA DEL FANTASMA (Hum místico resonante)
# ─────────────────────────────────────────────────────────────────────────────

const ID_AURA = "aura_fantasma"

## Inicia la resonancia vibratoria mística al activar el Aura
func iniciar_vibracion_aura(intensidad: float = 1.0) -> void:
	if not vibracion_habilitada:
		return
	# Pulso inicial de encendido
	vibrar(85, 0.65, 0.25, 0.15)
	# Hum continuo oscilante
	iniciar_vibracion_continua(
		ID_AURA,
		intensidad,
		0.125,                      # Cadencia suave
		38,                         # Pulso delicado pero perceptible
		0.28,                       # Motor sutil mando
		0.06,                       # Casi sin motor pesado (tono espectral)
		-1.0                        # Se detiene manualmente al disiparse
	)

## Ajusta la vibración con la expansión y contracción del radio del Aura
func actualizar_intensidad_aura(intensidad: float) -> void:
	actualizar_vibracion_continua(ID_AURA, intensidad)

## Detiene el Aura con un pulso de disipación etérea
func detener_vibracion_aura(con_pulso_disipacion: bool = true) -> void:
	detener_vibracion_continua(ID_AURA)
	if con_pulso_disipacion and vibracion_habilitada:
		vibrar(40, 0.25, 0.0, 0.08)

# ─────────────────────────────────────────────────────────────────────────────
# 3. TORBELLINO / VÓRTICE ESPIRITUAL (Turbulencia y absorción)
# ─────────────────────────────────────────────────────────────────────────────

const ID_SUCCION_TORBELLINO = "succion_torbellino"
const ID_ATRAPADO_TORBELLINO = "atrapado_torbellino"

## Modula la vibración de viento y arrastre a medida que el jugador se acerca al vórtice
func actualizar_succion_torbellino(factor_succion: float) -> void:
	if not vibracion_habilitada:
		return
	var factor = clampf(factor_succion, 0.0, 1.0)
	if factor <= 0.05:
		detener_succion_torbellino()
		return

	if not esta_vibracion_continua_activa(ID_SUCCION_TORBELLINO):
		iniciar_vibracion_continua(
			ID_SUCCION_TORBELLINO,
			factor,
			0.110,
			40,
			0.30,
			0.20,
			-1.0
		)
	else:
		actualizar_vibracion_continua(ID_SUCCION_TORBELLINO, factor)

func detener_succion_torbellino() -> void:
	detener_vibracion_continua(ID_SUCCION_TORBELLINO)

## Vibración violenta y caótica mientras el personaje está atrapado orbitando en el núcleo
func iniciar_vibracion_torbellino_atrapado(duracion: float = 1.0) -> void:
	detener_succion_torbellino()
	if not vibracion_habilitada:
		return
	# Sacudida centrífuga de alta frecuencia
	iniciar_vibracion_continua(
		ID_ATRAPADO_TORBELLINO,
		1.0,
		0.054,                      # Cadencia muy rápida y agresiva
		48,                         # Pulso intenso
		0.85,                       # Motor rápido
		0.80,                       # Motor pesado (turbulencia violenta)
		duracion
	)

func detener_vibracion_torbellino_atrapado() -> void:
	detener_vibracion_continua(ID_ATRAPADO_TORBELLINO)

## Disparo explosivo cuando el torbellino expulsa al personaje
func vibrar_expulsion_torbellino() -> void:
	detener_vibracion_torbellino_atrapado()
	vibrar(125, 0.90, 0.85, 0.22)

# ─────────────────────────────────────────────────────────────────────────────
# 4. MANIVELAS, PALANCAS Y FÍSICA DE EMPUJE
# ─────────────────────────────────────────────────────────────────────────────

## Clic mecánico de trinquete / engranaje al girar una manivela continua
func vibrar_manivela_giro() -> void:
	vibrar(38, 0.38, 0.12, 0.06)

## Bloqueo sólido al completar una manivela o tornamesa al 100%
func vibrar_manivela_bloqueo() -> void:
	vibrar(75, 0.65, 0.55, 0.15)

## Activación de palanca, interruptor o botón de presión
func vibrar_mecanismo() -> void:
	vibrar(48, 0.50, 0.20, 0.10)

## Roce de arrastre cuando el personaje empuja una caja pesada sobre piedra
const ID_EMPUJE_CAJA = "empuje_caja"

func iniciar_vibracion_empuje_caja(intensidad: float = 0.5) -> void:
	if not vibracion_habilitada:
		return
	if not esta_vibracion_continua_activa(ID_EMPUJE_CAJA):
		iniciar_vibracion_continua(
			ID_EMPUJE_CAJA,
			intensidad,
			0.095,
			42,
			0.28,
			0.35,
			-1.0
		)
	else:
		actualizar_vibracion_continua(ID_EMPUJE_CAJA, intensidad)

func detener_vibracion_empuje_caja() -> void:
	detener_vibracion_continua(ID_EMPUJE_CAJA)

# ─────────────────────────────────────────────────────────────────────────────
# 5. PRESETS DE PERSONAJES Y COMBATE
# ─────────────────────────────────────────────────────────────────────────────

## Salto de personaje: pulso ligero de despegue
func vibrar_salto(numero_salto: int = 1) -> void:
	if numero_salto == 1:
		vibrar(38, 0.28, 0.0, 0.07)
	else:
		# Segundo salto / doble salto
		vibrar(48, 0.45, 0.15, 0.09)

## Aterrizaje tras caída: impacto proporcional a la fuerza de caída
func vibrar_aterrizaje(intensidad: float = 1.0) -> void:
	var factor = clampf(intensidad, 0.4, 2.0)
	var ms = int(40 * factor)
	var weak = clampf(0.40 * factor, 0.20, 0.90)
	var strong = clampf(0.25 * factor, 0.10, 0.75)
	vibrar(ms, weak, strong, 0.10 * factor)

## Embate físico del Jugador: golpe / tackle contundente
func vibrar_embate() -> void:
	vibrar(95, 0.75, 0.55, 0.16)

## Impacto contra muro o caja rompible
func vibrar_impacto_fuerte() -> void:
	vibrar(120, 0.85, 0.75, 0.20)

## Alternar de personaje (Vivo <-> Fantasma en modo 1 jugador): doble pulso armónico
func vibrar_cambio_personaje() -> void:
	if not vibracion_habilitada:
		return
	vibrar(38, 0.40, 0.12, 0.06)
	var tw = create_tween()
	tw.tween_interval(0.070)
	tw.tween_callback(func():
		vibrar(45, 0.50, 0.22, 0.08)
	)

## Recolección de moneda o gema: click háptico táctil nítido
func vibrar_coleccionable() -> void:
	vibrar(38, 0.35, 0.0, 0.05)

## Daño recibido o reaparición por caída al vacío
func vibrar_dano() -> void:
	vibrar(170, 0.85, 0.75, 0.25)
