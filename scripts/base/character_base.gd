extends CharacterBody3D
class_name CharacterBase

# Parámetros compartidos
@export var VELOCIDAD : float = 5.0
@export var ACELERACION_SUELO : float = 24.0
@export var DESACELERACION_SUELO : float = 30.0
@export var ACELERACION_AIRE : float = 12.0
@export var DESACELERACION_AIRE : float = 12.0
@export var VELOCIDAD_ROTACION_PERSONAJE : float = 12.0
@export var LIMITE_CAIDA_Y : float = -20.0

@export_group("Camara Inteligente")
@export var SENSIBILIDAD_CAMARA : float = 0.005
@export var SUAVIDAD_CAMARA : float = 18.0
@export var DISTANCIA_CAMARA : float = 3.5
@export var MARGEN_COLISION_CAMARA : float = 0.15
@export var PITCH_DEFECTO_CAMARA : float = -0.14            # ~-8.0 grados (mirando ligeramente hacia abajo)
@export var LIMITE_PITCH_MIN : float = -0.70               # ~-40 grados
@export var LIMITE_PITCH_MAX : float = 0.35                # ~+20 grados

@export_group("Salto Compartido")
@export var FUERZA_SALTO : float = 7.5
@export var MULTIPLICADOR_SEGUNDO_SALTO : float = 0.9
@export var MULTIPLICADOR_CAIDA : float = 2.0
@export var MULTIPLICADOR_CORTE_SALTO : float = 2.2
@export var MULTIPLICADOR_GRAVEDAD_APICE : float = 1.0
@export var UMBRAL_VELOCIDAD_APICE : float = 1.6
@export var VELOCIDAD_MAX_CAIDA : float = 26.0
@export var TIEMPO_COYOTE : float = 0.15
@export var TIEMPO_BUFFER_SALTO : float = 0.14
@export var MAX_SALTOS : int = 2

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var objetivo_rotacion_y : float = 0.0
var objetivo_rotacion_x : float = 0.0
var posicion_inicial : Vector3
var tiempo_desde_suelo : float = 0.0
var tiempo_desde_salto : float = 0.0
var saltos_realizados : int = 0

# Variables para interpolación de red (anti-stuttering)
var sync_position: Vector3
var sync_rotation: Vector3

var particulas_corazon: CPUParticles3D = null
var tiempo_cerca_otro: float = 0.0
const DISTANCIA_PROXIMIDAD_CORAZON: float = 1.4 # Deben estar pegados lado a lado
const TIEMPO_REQUERIDO_PROXIMIDAD: float = 5.0 # 5 segundos continuos de estar cerca


@onready var pivote_camara = $Node3D
var controles_tactiles: Node = null

func obtener_camara() -> Camera3D:
	if not pivote_camara:
		return null
	if pivote_camara is Camera3D:
		return pivote_camara as Camera3D
	var cam = pivote_camara.get_node_or_null("SpringArm3D/Camera3D")
	if cam is Camera3D:
		return cam
	cam = pivote_camara.get_node_or_null("Camera3D")
	if cam is Camera3D:
		return cam
	return pivote_camara.find_child("Camera3D", true, false) as Camera3D

func obtener_spring_arm() -> SpringArm3D:
	if not pivote_camara:
		return null
	if pivote_camara is SpringArm3D:
		return pivote_camara as SpringArm3D
	var arm = pivote_camara.get_node_or_null("SpringArm3D")
	if arm is SpringArm3D:
		return arm
	return pivote_camara.find_child("SpringArm3D", true, false) as SpringArm3D

func centrar_camara_inmediatamente():
	objetivo_rotacion_y = rotation.y
	objetivo_rotacion_x = PITCH_DEFECTO_CAMARA

func _ready():
	objetivo_rotacion_y = rotation.y
	var spring_arm = obtener_spring_arm()
	if spring_arm:
		spring_arm.add_excluded_object(get_rid())
		spring_arm.spring_length = DISTANCIA_CAMARA
		spring_arm.margin = MARGEN_COLISION_CAMARA
		objetivo_rotacion_x = spring_arm.rotation.x
	elif pivote_camara:
		objetivo_rotacion_x = pivote_camara.rotation.x
	else:
		objetivo_rotacion_x = PITCH_DEFECTO_CAMARA

	posicion_inicial = global_position
	sync_position = global_position
	sync_rotation = rotation
	actualizar_visibilidad_local()
	_crear_particulas_corazon_proximidad()
	
	# Buscar controles táctiles en el grupo global "ui_tactil"
	var nodos_ui = get_tree().get_nodes_in_group("ui_tactil")
	if nodos_ui.size() > 0:
		controles_tactiles = nodos_ui[0]

func es_activo() -> bool:
	if is_instance_valid(RedManager) and (RedManager.es_un_jugador or multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		var es_fantasma = is_in_group("fantasmas") or name.to_lower().contains("fantasma")
		if RedManager.personaje_activo_solo == "fantasma":
			return es_fantasma
		else:
			return not es_fantasma
	return is_multiplayer_authority()

func _process(delta: float):
	if es_activo():
		sync_position = global_position
		sync_rotation = rotation
	elif multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		# Suavizado de red (Interpolación) solo en multijugador online
		global_position = global_position.lerp(sync_position, 15.0 * delta)
		rotation.y = lerp_angle(rotation.y, sync_rotation.y, 15.0 * delta)
		rotation.x = lerp_angle(rotation.x, sync_rotation.x, 15.0 * delta)


func actualizar_visibilidad_local(preservar_rotacion_camara: bool = false):
	# Lógica base de cámara, los hijos extenderán esto
	var es_mio = es_activo()
	if pivote_camara:
		if es_mio:
			pivote_camara.top_level = true
			pivote_camara.global_position = global_position
			if not preservar_rotacion_camara:
				objetivo_rotacion_y = rotation.y
				pivote_camara.rotation.y = rotation.y
			else:
				pivote_camara.rotation.y = objetivo_rotacion_y
			var arm = obtener_spring_arm()
			if arm:
				arm.add_excluded_object(get_rid())
				arm.rotation.x = objetivo_rotacion_x
			else:
				pivote_camara.rotation.x = objetivo_rotacion_x
		else:
			pivote_camara.top_level = false
			
		var cam = obtener_camara()
		if cam:
			cam.current = es_mio

func obtener_entorno_personaje() -> Environment:
	return null

func obtener_cull_mask_personaje() -> int:
	return 1048575

func entrada_bloqueada() -> bool:
	if not is_inside_tree():
		return true
	if is_instance_valid(ScoreManager) and not ScoreManager.cronometro_activo and ScoreManager.tiempo_transcurrido > 0.0:
		return true
	var tree = get_tree()
	if tree and tree.current_scene:
		if tree.current_scene.has_node("CanvasResultados") or tree.current_scene.has_node("PantallaResultados"):
			return true
	if is_instance_valid(controles_tactiles) and controles_tactiles.has_method("esta_bloqueado_para_juego"):
		if controles_tactiles.esta_bloqueado_para_juego():
			return true
	return false

func procesar_camara_base(delta: float):
	if not es_activo() or entrada_bloqueada(): return
	if is_instance_valid(RedManager) and RedManager.transicion_en_progreso: return

	if pivote_camara:
		pivote_camara.global_position = global_position

		# Buscar controles táctiles si aún no se han referenciado
		if not controles_tactiles:
			var nodos_ui = get_tree().get_nodes_in_group("ui_tactil")
			if nodos_ui.size() > 0:
				controles_tactiles = nodos_ui[0]

		# Comprobar gesto de doble toque táctil o tecla R en PC para centrado instantáneo
		var solicito_centrado = false
		if controles_tactiles and controles_tactiles.has_method("consumir_centrado_camara"):
			solicito_centrado = controles_tactiles.consumir_centrado_camara()
		
		if not solicito_centrado:
			if InputMap.has_action("centrar_camara") and Input.is_action_just_pressed("centrar_camara"):
				solicito_centrado = true
			elif Input.is_physical_key_pressed(KEY_R):
				solicito_centrado = true

		if solicito_centrado:
			centrar_camara_inmediatamente()

		if controles_tactiles:
			var giro = controles_tactiles.consumir_arrastre()
			if giro != Vector2.ZERO:
				objetivo_rotacion_y -= giro.x * SENSIBILIDAD_CAMARA
				objetivo_rotacion_x = clamp(objetivo_rotacion_x - giro.y * SENSIBILIDAD_CAMARA, LIMITE_PITCH_MIN, LIMITE_PITCH_MAX)

		var suavizado_camara = 1.0 - exp(-SUAVIDAD_CAMARA * delta)
		pivote_camara.rotation.y = lerp_angle(pivote_camara.rotation.y, objetivo_rotacion_y, suavizado_camara)
		
		var arm = obtener_spring_arm()
		if arm:
			pivote_camara.rotation.x = 0.0
			arm.rotation.x = lerp_angle(arm.rotation.x, objetivo_rotacion_x, suavizado_camara)
		else:
			pivote_camara.rotation.x = lerp_angle(pivote_camara.rotation.x, objetivo_rotacion_x, suavizado_camara)

func procesar_salto_base(delta: float):
	var salto_mantenido = es_activo() and not entrada_bloqueada() and (Input.is_action_pressed("saltar") or Input.is_action_pressed("ui_accept"))
	if not is_on_floor():
		var gravedad_actual = gravity
		# Suspensión en el ápice (Apex Hang / Float) al alcanzar la cima del salto
		if absf(velocity.y) < UMBRAL_VELOCIDAD_APICE and salto_mantenido and MULTIPLICADOR_GRAVEDAD_APICE < 1.0:
			gravedad_actual *= MULTIPLICADOR_GRAVEDAD_APICE
		elif velocity.y < 0.0:
			gravedad_actual *= MULTIPLICADOR_CAIDA
		elif velocity.y > 0.0 and not salto_mantenido:
			gravedad_actual *= MULTIPLICADOR_CORTE_SALTO

		velocity.y -= gravedad_actual * delta
		if VELOCIDAD_MAX_CAIDA > 0.0:
			velocity.y = maxf(velocity.y, -VELOCIDAD_MAX_CAIDA)
			
		tiempo_desde_suelo += delta
	else:
		tiempo_desde_suelo = 0.0
		saltos_realizados = 0

	if not es_activo() or entrada_bloqueada() or (is_instance_valid(RedManager) and RedManager.transicion_en_progreso):
		return

	if Input.is_action_just_pressed("saltar") or Input.is_action_just_pressed("ui_accept"):
		tiempo_desde_salto = 0.0
	else:
		tiempo_desde_salto += delta

	if tiempo_desde_salto <= TIEMPO_BUFFER_SALTO:
		if (is_on_floor() or tiempo_desde_suelo <= TIEMPO_COYOTE) and saltos_realizados == 0:
			velocity.y = FUERZA_SALTO
			saltos_realizados = 1
			tiempo_desde_salto = TIEMPO_BUFFER_SALTO + 0.1 # Consumir buffer
			_al_realizar_salto(1)
		elif saltos_realizados < MAX_SALTOS:
			velocity.y = FUERZA_SALTO * MULTIPLICADOR_SEGUNDO_SALTO
			saltos_realizados += 1
			tiempo_desde_salto = TIEMPO_BUFFER_SALTO + 0.1 # Consumir buffer
			_al_realizar_salto(saltos_realizados)

func _al_realizar_salto(_numero_salto: int):
	# Hook virtual para subclases (efectos visuales, partículas, squash/stretch)
	pass

func obtener_direccion_movimiento() -> Vector3:
	if entrada_bloqueada():
		return Vector3.ZERO
		
	var input_dir = Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras", 0.05)
		
	if input_dir == Vector2.ZERO:
		return Vector3.ZERO

	var cam_basis = Basis()
	if pivote_camara:
		cam_basis = pivote_camara.global_transform.basis
	else:
		cam_basis = global_transform.basis
		
	var forward = cam_basis.z
	var right = cam_basis.x
	
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	
	var move_dir = right * input_dir.x + forward * input_dir.y
	var input_len = input_dir.length()
	if move_dir.is_zero_approx():
		return Vector3.ZERO

	return move_dir.normalized() * clampf(input_len, 0.0, 1.0)

func aplicar_friccion_y_movimiento(direccion: Vector3, delta: float):
	var velocidad_objetivo = direccion * VELOCIDAD
	var tasa_aceleracion = ACELERACION_SUELO if is_on_floor() else ACELERACION_AIRE
	
	if direccion != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, velocidad_objetivo.x, tasa_aceleracion * delta)
		velocity.z = move_toward(velocity.z, velocidad_objetivo.z, tasa_aceleracion * delta)
	else:
		var tasa_frenado = DESACELERACION_SUELO if is_on_floor() else DESACELERACION_AIRE
		velocity.x = move_toward(velocity.x, 0.0, tasa_frenado * delta)
		velocity.z = move_toward(velocity.z, 0.0, tasa_frenado * delta)
	
	move_and_slide()
	
	# Empujar objetos RigidBody3D (cajas empujables)
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider is RigidBody3D:
			var direccion_empuje = -col.get_normal()
			direccion_empuje.y = 0.0 # Evitar levantar o hundir la caja
			direccion_empuje = direccion_empuje.normalized()
			var fuerza_empuje = 2.5 # Ajusta este valor si es necesario
			var impulso = direccion_empuje * fuerza_empuje * delta * 60.0
			
			if collider.has_method("rpc_aplicar_impulso"):
				# Llamar vía RPC para que se aplique en el servidor que simula la física de la caja
				collider.rpc("rpc_aplicar_impulso", impulso)
			elif not collider.freeze:
				# Fallback local para RigidBody3D no sincronizados
				collider.apply_central_impulse(impulso)

	_comprobar_caida_vacio()
	
	# Aseguramos que la cámara siga exactamente la posición del jugador después del movimiento físico
	if es_activo() and pivote_camara and pivote_camara.top_level:
		pivote_camara.global_position = global_position

func procesar_movimiento_base(delta: float):
	if is_instance_valid(RedManager) and RedManager.transicion_en_progreso:
		aplicar_friccion_y_movimiento(Vector3.ZERO, delta)
		return

	var direccion = obtener_direccion_movimiento()
	
	if direccion != Vector3.ZERO:
		# Rotar suavemente al personaje hacia la dirección en la que se está moviendo
		var target_angle = atan2(-direccion.x, -direccion.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 1.0 - exp(-VELOCIDAD_ROTACION_PERSONAJE * delta))
		
	aplicar_friccion_y_movimiento(direccion, delta)
	_procesar_proximidad_corazon(delta)

func resetear_estados():
	saltos_realizados = 0
	tiempo_desde_suelo = 0.0
	tiempo_desde_salto = 0.0

func _comprobar_caida_vacio():
	if global_position.y < LIMITE_CAIDA_Y:
		global_position = posicion_inicial
		velocity = Vector3.ZERO
		resetear_estados()
		if pivote_camara and pivote_camara.top_level:
			pivote_camara.global_position = posicion_inicial

func _crear_particulas_corazon_proximidad():
	particulas_corazon = CPUParticles3D.new()
	particulas_corazon.name = "ParticulasCorazonProximidad"
	particulas_corazon.amount = 5 # Reducido a 5 corazones para una flotación lenta y romántica
	particulas_corazon.lifetime = 2.4
	particulas_corazon.one_shot = false
	particulas_corazon.emitting = false
	particulas_corazon.explosiveness = 0.0
	particulas_corazon.randomness = 0.4
	particulas_corazon.lifetime_randomness = 0.3
	particulas_corazon.top_level = true
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.32, 0.32)
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED # Desactiva depth-buffer write para transparencia limpia sin artefactos
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.albedo_texture = _generar_textura_corazon()
	mesh.material = mat
	
	particulas_corazon.mesh = mesh
	particulas_corazon.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particulas_corazon.emission_sphere_radius = 0.35
	particulas_corazon.direction = Vector3(0, 1, 0)
	particulas_corazon.spread = 15.0
	particulas_corazon.gravity = Vector3(0, 0.5, 0) # Elevación lenta y suave
	particulas_corazon.initial_velocity_min = 0.2
	particulas_corazon.initial_velocity_max = 0.45
	particulas_corazon.scale_amount_min = 0.6
	particulas_corazon.scale_amount_max = 1.1
	particulas_corazon.color = Color(1.0, 0.35, 0.65, 0.9)
	
	add_child(particulas_corazon)

func _generar_textura_corazon() -> ImageTexture:
	var size = 128
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center_x = size / 2.0
	var center_y = size * 0.36
	var r = size * 0.22
	var circle1 = Vector2(center_x - r * 0.90, center_y)
	var circle2 = Vector2(center_x + r * 0.90, center_y)
	var tip_bottom = Vector2(center_x, size * 0.88) # Alargado suavemente hacia abajo
	
	for y in range(size):
		for x in range(size):
			var p = Vector2(float(x), float(y))
			
			# Distancia a los lóbulos superiores (círculos)
			var d1 = p.distance_to(circle1) - r
			var d2 = p.distance_to(circle2) - r
			var dist = min(d1, d2)
			
			# Cuerpo inferior cónico en V continuo y sin sobresalir lateralmente
			if p.y >= center_y:
				var dy = p.y - tip_bottom.y
				if dy < 0:
					var slope_left = (circle1.x - r - tip_bottom.x) / (center_y - tip_bottom.y)
					var slope_right = (circle2.x + r - tip_bottom.x) / (center_y - tip_bottom.y)
					var bound_left = tip_bottom.x + slope_left * dy
					var bound_right = tip_bottom.x + slope_right * dy
					
					var dist_left = bound_left - p.x
					var dist_right = p.x - bound_right
					var dist_v = max(dist_left, dist_right)
					dist = min(dist, dist_v)
					
			if dist <= 0.0:
				img.set_pixel(x, y, Color(1.0, 0.2, 0.55, 1.0))
			elif dist < 2.0:
				var alpha = clamp(1.0 - (dist / 2.0), 0.0, 1.0)
				img.set_pixel(x, y, Color(1.0, 0.2, 0.55, alpha))
				
	return ImageTexture.create_from_image(img)





func _procesar_proximidad_corazon(delta: float):
	if not es_activo(): return

	var otro: Node3D = _buscar_otro_jugador()
	if is_instance_valid(otro):
		var dist = global_position.distance_to(otro.global_position)
		if dist <= DISTANCIA_PROXIMIDAD_CORAZON:
			tiempo_cerca_otro += delta
			if tiempo_cerca_otro >= TIEMPO_REQUERIDO_PROXIMIDAD:
				if is_instance_valid(particulas_corazon):
					particulas_corazon.emitting = true
					var pos_mitad = (global_position + otro.global_position) * 0.5
					pos_mitad.y += 0.8
					particulas_corazon.global_position = pos_mitad
			else:
				# Durante la cuenta regresiva de 5 segundos, mantener las partículas apagadas
				if is_instance_valid(particulas_corazon):
					particulas_corazon.emitting = false
		else:
			# Si se alejan más de 1.4 metros, reiniciar el contador a 0 y apagar la emisión
			tiempo_cerca_otro = 0.0
			if is_instance_valid(particulas_corazon):
				particulas_corazon.emitting = false
	else:
		tiempo_cerca_otro = 0.0
		if is_instance_valid(particulas_corazon):
			particulas_corazon.emitting = false


func _buscar_otro_jugador() -> Node3D:
	var todos = get_tree().get_nodes_in_group("jugadores")
	if todos.size() > 1:
		for p in todos:
			if p != self and is_instance_valid(p):
				return p
				
	var es_fantasma = is_in_group("fantasmas") or name.to_lower().contains("fantasma")
	if es_fantasma:
		var vivos = get_tree().get_nodes_in_group("vivos")
		if vivos.size() > 0 and vivos[0] != self:
			return vivos[0]
	else:
		var fantasmas = get_tree().get_nodes_in_group("fantasmas")
		if fantasmas.size() > 0 and fantasmas[0] != self:
			return fantasmas[0]
			
	return null
