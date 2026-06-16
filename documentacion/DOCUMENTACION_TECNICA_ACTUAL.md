# Proyecto Limbo - Documentacion Tecnica Actual

Ultima actualizacion de este documento: 2026-06-16 (sesion nocturna).

Este archivo describe el estado actual de Proyecto Limbo para que una persona o una IA pueda continuar el desarrollo sin perder contexto. Debe leerse como la fuente tecnica viva del proyecto: arquitectura, archivos, conexiones, reglas de red, flujo de control, convenciones y puntos delicados.

## 1. Vision General

Proyecto Limbo es un juego cooperativo asimetrico en Godot 4.6, pensado para dos jugadores:

- Jugador Vivo: personaje fisico, amarillo, con movimiento de plataformeo mas tradicional.
- Fantasma: personaje espectral, azul/translucido, con salto unico mas alto, caida lenta tipo levitacion y una habilidad de aura que activa plataformas para el Jugador Vivo.

La fantasia principal es que ambos personajes existen en planos distintos y deben cooperar. El Vivo depende de plataformas fisicas activadas por el Fantasma; el Fantasma puede interactuar con el plano espiritual y manipular la realidad temporalmente.

## 2. Configuracion Del Proyecto

Archivo principal:

- `project.godot`

Datos importantes:

- Motor objetivo: Godot 4.6.
- Escena principal: `scenes/levels/mundo_pruebas.tscn`.
- Render: mobile.
- Fisica: Jolt Physics.
- Autoload activo:
  - `RedManager`: `scripts/core/red_manager.gd`.
  - `ScoreManager`: `scripts/core/score_manager.gd` (singleton de puntuacion, agregado 2026-06-16).
  - `_mcp_game_helper`: helper del addon `godot_ai`.
- Controles tactiles:
  - `input_devices/pointing/emulate_touch_from_mouse=true`, util para probar controles moviles con mouse.

Acciones de input registradas:

- `mover_adelante`: W.
- `mover_atras`: S.
- `mover_izquierda`: A.
- `mover_derecha`: D.
- `saltar`: Space.
- `interactuar`: tecla registrada como keycode `4194325`.

Nota importante: actualmente la logica de movimiento base usa `Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")`, no las acciones `mover_izquierda`, `mover_derecha`, `mover_adelante`, `mover_atras`. Si se quiere usar WASD via acciones personalizadas, hay que actualizar `CharacterBase.obtener_direccion_movimiento()`.

Capas fisicas nombradas:

- Layer 1: `Estructura_Global` (entorno, suelo, paredes).
- Layer 2: `Plano_Fisico` (Jugador Vivo).
- Layer 3: `Plano_Espiritual` (Fantasma).
- Layer 4: `Objetivo_Moneda` (monedas y objetivo de nivel, agregada 2026-06-16).

Resumen rapido de colisiones entre capas:

| Nodo | `collision_layer` | `collision_mask` | Colisiona con |
| --- | --- | --- | --- |
| Entorno/Suelo | Capa 1 (`1`) | Capa 1 (`1`) | Todo lo que escuche capa 1 |
| Jugador | Capa 2 (`0b0010`) | Capas 1, 2, 4 (`0b1011`) | Entorno, plataformas fisicas, monedas/objetivo |
| Fantasma | Capa 3 (`0b0100`) | Capas 1, 3, 4 (`0b1101`) | Entorno, plataformas espirituales, monedas/objetivo |
| Moneda/Coin | Capa 4 (`0b1000`) | Capas 2, 3 (`0b0110`) | Jugador y Fantasma |
| Goal/Objetivo | Capa 4 (`0b1000`) | Capas 2, 3 (`0b0110`) | Jugador y Fantasma |

Nota critica: Jugador y Fantasma NO colisionan entre si. Jugador solo esta en capa 2, Fantasma solo en capa 3, y ninguno escucha la capa del otro.

## 3. Estructura De Carpetas

La organizacion actual ya sigue una arquitectura separada por dominio:

```text
assets/
  Texturas/
    Provicionales/

documentacion/
  DOCUMENTACION_PROYECTO.md
  DOCUMENTACION_TECNICA_ACTUAL.md

scenes/
  characters/
    fantasma.tscn
    jugador.tscn
  levels/
    mundo_pruebas.tscn
  ui/
    controles_tactiles.tscn

scripts/
  base/
    character_base.gd
  characters/
    fantasma.gd
    habilidad_aura.gd
    jugador.gd
  core/
    administrador_plataformas.gd
    red_manager.gd
    score_manager.gd          # NUEVO: singleton de puntuacion
  objects/
    coin.gd                    # NUEVO: moneda coleccionable
    goal.gd                    # NUEVO: objetivo de nivel
  ui/
    area_camara.gd
    boton_tactil_visual.gd
    controles_tactiles.gd
    fantasma_camera_environment.tres
    joystick_virtual.gd
```

Regla de mantenimiento:

- Las escenas viven en `scenes/`.
- Los scripts reutilizables o de logica deben vivir en `scripts/`.
- No poner scripts de logica dentro de `scenes/characters/`; ya se corrigio el caso de `HabilidadAura`.

## 4. Escenas Principales

### `scenes/levels/mundo_pruebas.tscn`

Escena principal del proyecto.

Contiene:

- `AdministradorPlataformas`.
- `Controles_Tactiles`.
- Instancia de `Fantasma`.
- `WorldEnvironment`.
- `DirectionalLight3D`.
- `Suelo`.
- Plataformas/obstaculos `StaticBody3D` del nivel, algunos marcables como plataformas de aura mediante la capa `Plano_Espiritual`.
- Instancia de `Jugador`.

Importante para el sistema de plataformas:

- El Fantasma detecta plataformas buscando nodos `StaticBody3D` que tengan configurada la capa o mascara espiritual.
- Ya no depende del nombre `Caja_Fisica`.
- Si se agregan nuevas plataformas espirituales, deben ser `StaticBody3D` y tener `collision_layer` o `collision_mask` con `CAPA_ESPIRITUAL = 4`, que corresponde a la layer 3 `Plano_Espiritual`.

### `scenes/characters/jugador.tscn`

Escena del Jugador Vivo.

Nodos principales:

- `Jugador`: `CharacterBody3D`.
- `MeshInstance3D`: capsula amarilla.
- `CollisionShape3D`.
- `Node3D`: pivote de camara.
- `Camera3D`: camara en tercera persona.
- `MultiplayerSynchronizer`: sincroniza posicion y rotacion.

Script:

- `scripts/characters/jugador.gd`.

Colisiones actuales (configuradas por codigo en `_ready()`):

- `collision_layer = 1 << 1` → solo capa 2 (`Plano_Fisico`).
- `collision_mask = (1 << 0) | (1 << 1) | (1 << 3)` → capas 1 (entorno), 2 (plataformas fisicas), 4 (monedas/objetivo).
- NO incluye capa 3 en mask → no colisiona con el Fantasma.

### `scenes/characters/fantasma.tscn`

Escena del Fantasma.

Nodos principales:

- `Fantasma`: `CharacterBody3D`.
- `MeshInstance3D`: capsula azul/translucida.
- `Aura`: cilindro visual que se escala cuando el aura esta activa.
- `Node3D`: pivote de camara.
- `Camera3D`: camara en tercera persona.
- `MultiplayerSynchronizer`: sincroniza posicion y rotacion.
- `HabilidadAura`: nodo hijo que maneja la habilidad de aura.

Scripts:

- `scripts/characters/fantasma.gd`.
- `scripts/characters/habilidad_aura.gd`.

Colisiones actuales (configuradas por codigo en `_ready()`):

- `collision_layer = 1 << 2` → solo capa 3 (`Plano_Espiritual`).
- `collision_mask = (1 << 0) | (1 << 2) | (1 << 3)` → capas 1 (entorno), 3 (plataformas espirituales), 4 (monedas/objetivo).
- NO incluye capa 2 en mask → no colisiona con el Jugador.

Camera cull_mask:

- La camara del Fantasma usa `cull_mask = (1 << 0) | (1 << 1) | (1 << 2)` → renderiza capas 1, 2 y 3.
- Excluye capa 4 → las monedas y el objetivo NO se dibujan en la pantalla del Fantasma, aunque este sigue pudiendo detectarlas por colision.

### `scenes/ui/controles_tactiles.tscn`

HUD tactil universal para ambos jugadores.

Nodos principales:

- `Controles_Tactiles`: raiz `Control`, usa `scripts/ui/controles_tactiles.gd`.
- `Joystick_Virtual`: control analogico, usa `scripts/ui/joystick_virtual.gd`.
- `Area_Camara`: zona derecha para arrastre de camara, usa `scripts/ui/area_camara.gd`.
- `Zona_Botones_Accion`.
- `Boton_Saltar`: `TouchScreenButton`, accion `saltar`.
- `Boton_Interactuar`: `TouchScreenButton`, accion `interactuar`.

La UI cambia de estilo segun el personaje local:

- Jugador Vivo: estilo amarillo/original.
- Fantasma: shader azul aplicado recursivamente.

## 5. Arquitectura De Personajes

### `scripts/base/character_base.gd`

Clase base:

```gdscript
extends CharacterBody3D
class_name CharacterBase
```

Responsabilidades:

- Parametros compartidos de movimiento.
- Parametros compartidos de salto.
- Rotacion de camara tactil.
- Lectura de joystick virtual.
- Aplicacion de friccion y movimiento.
- `move_and_slide()`.
- Respawn simple si el personaje cae bajo `LIMITE_CAIDA_Y`.
- Seleccion de camara local segun `is_multiplayer_authority()`.

Funciones clave:

- `_ready()`: guarda rotacion inicial, posicion inicial y actualiza visibilidad local.
- `actualizar_visibilidad_local()`: activa la camara solo para la autoridad local.
- `procesar_camara_base(delta)`: consume arrastre de `Controles_Tactiles`.
- `procesar_salto_base(delta)`: gravedad, salto, coyote time, buffer y multiples saltos.
- `obtener_direccion_movimiento()`: joystick virtual o input de teclado.
- `aplicar_friccion_y_movimiento(direccion, delta)`: movimiento horizontal y `move_and_slide()`.
- `procesar_movimiento_base(delta)`: wrapper de direccion + movimiento.
- `resetear_estados()`: limpia saltos y buffers.
- `_comprobar_caida_vacio()`: respawn local.

Regla para futuras IA:

- No duplicar movimiento, camara o salto dentro de `jugador.gd` o `fantasma.gd`.
- Si ambos personajes necesitan una mejora de locomocion, hacerla aqui.
- Si solo un personaje necesita diferencias de parametros, cambiar valores desde su script o desde la escena.

### `scripts/characters/jugador.gd`

Clase:

```gdscript
extends CharacterBase
class_name Jugador
```

Responsabilidades:

- Registrar el Jugador Vivo en `RedManager`.
- Ejecutar la logica base si tiene autoridad local.

Flujo:

```gdscript
procesar_camara_base(delta)
procesar_salto_base(delta)
procesar_movimiento_base(delta)
```

Comportamiento actual:

- Usa los valores por defecto de `CharacterBase`.
- Tiene doble salto (`MAX_SALTOS = 2` heredado).
- Caida mas fisica y rapida que el Fantasma.

### `scripts/characters/fantasma.gd`

Clase:

```gdscript
extends CharacterBase
class_name Fantasma
```

Senal publica:

```gdscript
signal aura_estado_actualizado(activo: bool, progreso: float)
```

Responsabilidades:

- Registrar el Fantasma en `RedManager`.
- Ajustar parametros propios de movimiento.
- Configurar vision espiritual.
- Conectar el componente `HabilidadAura`.
- Detectar plataformas espirituales.
- Sincronizar por RPC el estado de plataformas.
- Emitir senales hacia la UI sin que la UI este hardcodeada en el personaje.

Parametros actuales del Fantasma:

```gdscript
FUERZA_SALTO = 8.0
MULTIPLICADOR_SEGUNDO_SALTO = 1.0
MULTIPLICADOR_CAIDA = 0.45
MULTIPLICADOR_CORTE_SALTO = 1.1
TIEMPO_COYOTE = 0.15
TIEMPO_BUFFER_SALTO = 0.12
MAX_SALTOS = 1
```

Resultado:

- El Fantasma tiene un solo salto.
- Salta mas alto que el Jugador Vivo.
- Cae mas lento, como si levitara.
- Se diferencia claramente del Jugador Vivo, que tiene doble salto mas fisico.

Vision espiritual:

- Si `fantasma_camera_environment` esta asignado, se usa ese Environment.
- Si no esta asignado, se duplica el entorno base o se crea uno nuevo.
- Se aplica `adjustment_color_correction` con gradiente azul.

Plataformas:

- Busca plataformas `StaticBody3D` con capa o mascara espiritual (`CAPA_ESPIRITUAL = 4`, layer 3 `Plano_Espiritual`).
- Cuando el aura esta activa, calcula distancia entre Fantasma y plataforma.
- Si entra o sale del radio, llama `rpc_sincronizar_estado_plataforma.rpc(path, estado)`.
- El RPC usa:

```gdscript
@rpc("any_peer", "call_local", "reliable")
```

Estados aplicados:

- Plataforma activa:
  - `collision_layer = 6`.
  - `collision_mask = 6`.
  - opacidad `1.0`.
- Plataforma inactiva:
  - `collision_layer = 4`.
  - `collision_mask = 4`.
  - opacidad `0.5`.

Advertencia:

- La logica de plataformas existe tambien en `AdministradorPlataformas`. Actualmente el Fantasma ya aplica/sincroniza directamente el estado, asi que hay duplicidad conceptual. Si se refactoriza, elegir una unica autoridad de plataformas.

## 6. Sistema De Aura

### `scripts/characters/habilidad_aura.gd`

Clase:

```gdscript
extends Node3D
class_name HabilidadAura
```

Senales:

```gdscript
signal estado_cambiado(activo: bool, progreso_cooldown: float)
signal radio_actualizado(radio: float)
```

Responsabilidades:

- Controlar si el aura esta activa.
- Manejar radio actual.
- Reducir radio con el tiempo.
- Manejar cooldown.
- Escalar el mesh visual `Aura`.
- Emitir senales para que otros sistemas reaccionen.

Parametros actuales:

- `radio_maximo = 10.0`.
- `velocidad_encogimiento = 2.5`.
- `tiempo_recarga = 4.0`.

Flujo:

1. El Fantasma detecta input `interactuar`.
2. Llama `habilidad_aura.intentar_activar()`.
3. `HabilidadAura` activa el aura si no esta activa ni en cooldown.
4. Se muestra el mesh `Aura`.
5. Cada frame:
   - reduce `radio_actual`;
   - escala el mesh;
   - emite `radio_actualizado(radio_actual)`.
6. El Fantasma escucha `radio_actualizado` y revisa plataformas.
7. Cuando el radio llega a 0:
   - se desactiva;
   - inicia cooldown;
   - emite `estado_cambiado(false, progreso)`.
8. La UI escucha el estado del aura a traves del Fantasma.

Regla de arquitectura:

- `HabilidadAura` no debe llamar directamente metodos del padre.
- Debe comunicar cambios mediante senales.
- El Fantasma decide que hacer con esas senales.
- La UI no debe consultar el componente directamente; escucha al Fantasma mediante `aura_estado_actualizado`.

## 7. UI Tactil Y Senales

### `scripts/ui/controles_tactiles.gd`

Responsabilidades:

- Detectar arrastre de camara en el lado derecho de la pantalla.
- Proveer `consumir_arrastre()` para `CharacterBase`.
- Configurar estilo visual segun personaje local.
- Conectarse a `Fantasma.aura_estado_actualizado`.
- Actualizar color del boton de aura durante cooldown.

Funciones clave:

- `configurar_personaje_local(personaje)`.
- `aplicar_estilo_jugador()`.
- `aplicar_estilo_fantasma()`.
- `actualizar_boton_aura(activo, progreso)`.

Flujo de desacoplamiento:

```text
HabilidadAura -> estado_cambiado
Fantasma -> aura_estado_actualizado
Controles_Tactiles -> actualizar_boton_aura
```

Esto evita que el Fantasma busque y pinte la UI directamente.

### `scripts/ui/joystick_virtual.gd`

Responsabilidades:

- Control analogico tactil.
- Detectar dedo/mouse que inicio el toque.
- Calcular `vector_salida`.
- Dibujar base y palanca.

Variables importantes:

- `tocando`.
- `vector_salida`.
- `id_dedo`.

`CharacterBase.obtener_direccion_movimiento()` lee este nodo por ruta relativa:

```gdscript
../Controles_Tactiles/Joystick_Virtual
```

Por eso los personajes y `Controles_Tactiles` deben seguir siendo hermanos dentro de la escena de nivel, o se debe cambiar la ruta.

### `scripts/ui/area_camara.gd`

Actualmente conserva una logica propia de arrastre con `_gui_input()` y `consumir_arrastre()`.

Nota importante:

- `CharacterBase` consume el arrastre desde `Controles_Tactiles`, no desde `Area_Camara`.
- `area_camara.gd` puede estar redundante tras la creacion de `controles_tactiles.gd`.
- Si se limpia el proyecto, revisar si `Area_Camara` sigue siendo necesaria.

### `scripts/ui/boton_tactil_visual.gd`

Responsabilidades:

- Redibujar botones tactiles circulares.
- Mantener apariencia amarilla semitransparente por defecto.

Cuando el Fantasma es el personaje local, `controles_tactiles.gd` aplica un shader azul recursivo que afecta tambien estos botones.

## 8. Sistema Multijugador

### `scripts/core/red_manager.gd`

Es Autoload con nombre `RedManager`.

Responsabilidades:

- Crear servidor P2P local con ENet.
- Conectar cliente a `127.0.0.1`.
- Registrar referencias a `Jugador` y `Fantasma`.
- Asignar autoridad multiplayer.
- Configurar UI local segun personaje controlado.
- Crear menu rapido de red por codigo.

Constantes:

```gdscript
const PORT = 7000
const ADDRESS = "127.0.0.1"
```

Flujo host:

1. `crear_partida()`.
2. Crea `ENetMultiplayerPeer`.
3. `peer.create_server(PORT, 2)`.
4. `multiplayer.multiplayer_peer = peer`.
5. Conecta `peer_connected`.
6. Asigna autoridad del Jugador Vivo al peer 1.
7. Actualiza camaras e interfaz.
8. Espera cliente.

Flujo cliente:

1. `unirse_a_partida()`.
2. Crea `ENetMultiplayerPeer`.
3. `peer.create_client(ADDRESS, PORT)`.
4. Conecta `connected_to_server`.
5. Al conectar:
   - toma autoridad del Fantasma con su peer ID;
   - asegura Jugador Vivo en autoridad 1;
   - actualiza camaras e interfaz.

Controles rapidos:

- F1: crear partida como Host/Jugador Vivo.
- F2: unirse como Cliente/Fantasma.
- Tambien se crea un menu simple con botones al iniciar.

Reglas de autoridad:

- Host ID 1: Jugador Vivo.
- Cliente: Fantasma.
- Cada personaje solo procesa `_physics_process` si `is_multiplayer_authority()` es true.

Punto delicado:

- La escena contiene ambos personajes en ambos peers.
- La camara actual se activa/desactiva con autoridad local.
- Si se agregan mas niveles, `RedManager` deberia persistir y volver a registrar personajes al cargar escena.

## 9. Sincronizacion De Posicion

Tanto `jugador.tscn` como `fantasma.tscn` tienen `MultiplayerSynchronizer`.

Propiedades sincronizadas:

- `position`.
- `rotation`.

No se sincronizan directamente:

- velocidad.
- saltos.
- estado de aura.
- entorno visual.
- UI.

El estado de plataformas se sincroniza con RPC desde `Fantasma`.

## 10. Sistema De Plataformas

El sistema actual tiene dos piezas:

### Fantasma

El Fantasma:

- detecta plataformas;
- calcula distancia con el aura;
- emite RPC;
- aplica collision layer/mask y opacidad.

### AdministradorPlataformas

`scripts/core/administrador_plataformas.gd`:

- busca referencias a `Fantasma` y `Jugador`;
- consulta `fantasma_ref.obtener_plataformas_activas()`;
- si detecta cambios, aplica colisiones y opacidad.

Estado actual:

- Es funcional como apoyo, pero puede ser redundante con la logica directa del Fantasma.
- Si aparecen bugs de plataformas aplicandose dos veces, revisar esta duplicidad primero.

Recomendacion:

- Refactor futuro ideal: convertir plataformas en un componente/script propio, por ejemplo `PlataformaAura.gd`, y usar grupos.
- El Fantasma solo deberia emitir intencion o evento.
- Un administrador o cada plataforma deberia aplicar su propio estado.

## 11. Flujo General De Juego

```text
Inicio escena mundo_pruebas
  RedManager crea menu de red
  Jugador y Fantasma se registran en RedManager

Host pulsa F1 o boton Host
  Host crea servidor
  Host controla Jugador Vivo
  Camara del Jugador Vivo queda activa
  UI queda estilo jugador

Cliente pulsa F2 o boton Cliente
  Cliente conecta al host
  Cliente toma autoridad del Fantasma
  Camara del Fantasma queda activa
  UI queda azul

Durante juego
  CharacterBase procesa camara, salto y movimiento del personaje local
  Jugador Vivo hace plataformeo fisico
  Fantasma salta alto una vez y cae lento
  Fantasma pulsa interactuar
  HabilidadAura activa aura
  Aura emite radio actualizado
  Fantasma activa plataformas en rango
  Plataformas se sincronizan por RPC

  Jugador o Fantasma tocan moneda
    Moneda llama rpc("_remover_para_todos")
    ScoreManager incrementa puntuacion
    Moneda desaparece en todos los peers

  Ambos personajes tocan el Goal simultaneamente
    Goal verifica que haya Jugador + Fantasma dentro
    Goal llama rpc("rpc_change_scene", next_scene_path)
    Todos los peers cambian a la escena siguiente
```

## 12. Diferencias Actuales Entre Personajes

| Sistema | Jugador Vivo | Fantasma |
| --- | --- | --- |
| Script | `jugador.gd` | `fantasma.gd` |
| Base | `CharacterBase` | `CharacterBase` |
| Collision layer | Capa 2 (`Plano_Fisico`) | Capa 3 (`Plano_Espiritual`) |
| Collision mask | Capas 1, 2, 4 | Capas 1, 3, 4 |
| Colision mutua | No colisionan entre si | No colisionan entre si |
| Saltos | 2 | 1 |
| Altura salto | Normal | Alta |
| Caida | Rapida/fisica | Lenta/levitacion |
| UI | Amarilla/original | Azul por shader |
| Vision | Normal | Azul espiritual (cull_mask excluye capa 4) |
| Habilidad | Ninguna especial todavia | Aura temporal |
| Plataformas | Solo usa activas | Detecta/activa con aura |
| Monedas | Ve y recoge | Recoge pero NO ve (cull_mask) |
| Red | Host ID 1 | Cliente |

## 13. Convenciones Importantes Para Futuras IA

Seguir estas reglas antes de modificar:

1. Leer este documento y `DOCUMENTACION_PROYECTO.md`.
2. Revisar `project.godot` para confirmar Autoloads, inputs y escena principal.
3. No duplicar movimiento en personajes. Usar `CharacterBase`.
4. No mover scripts de logica a `scenes/`.
5. No conectar UI directamente desde componentes de habilidad.
6. Usar senales para comunicacion de abajo hacia arriba.
7. Usar llamadas directas solo de arriba hacia abajo cuando el padre controla al hijo.
8. Respetar autoridad multiplayer: todo input local debe estar protegido con `is_multiplayer_authority()`.
9. Antes de cambiar plataformas, revisar tanto `fantasma.gd` como `administrador_plataformas.gd`.
10. Si se agregan plataformas de aura, marcarlas con layer o mask `Plano_Espiritual`; el nombre ya no importa.
11. Si se agregan nuevos personajes o habilidades, crear componentes hijos como `HabilidadAura`.
12. Si se modifica la jerarquia de la escena de nivel, actualizar rutas relativas en `CharacterBase` y UI.

## 14. Puntos Delicados Y Riesgos

### Inputs de movimiento

El proyecto define acciones `mover_adelante`, `mover_atras`, `mover_izquierda`, `mover_derecha`, pero `CharacterBase` usa `ui_left`, `ui_right`, `ui_up`, `ui_down`.

Riesgo:

- WASD podria no responder si las acciones `ui_*` no estan configuradas como se espera.

Solucion recomendada:

```gdscript
input_dir = Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras")
```

Revisar orientacion del eje Z despues de cambiarlo.

### Duplicidad de plataformas

`Fantasma` y `AdministradorPlataformas` pueden aplicar estados de plataforma.

Riesgo:

- Logs duplicados.
- Estados aplicados dos veces.
- Dificultad para depurar red.

Solucion recomendada:

- Centralizar aplicacion de plataformas en un solo sistema.

### Deteccion por colision espiritual

Las plataformas se detectan por capa o mascara espiritual, no por nombre.

Riesgo:

- Una plataforma sin `collision_layer` o `collision_mask` espiritual no sera registrada por el Fantasma.

Solucion recomendada:

- Asegurar que toda plataforma de aura use `CAPA_ESPIRITUAL = 4` / layer 3 `Plano_Espiritual`, o migrar en el futuro a grupos de Godot si se quiere una marca semantica mas explicita.

### UI por rutas relativas

`CharacterBase` espera `../Controles_Tactiles`.

Riesgo:

- Si se reorganiza el nivel, la camara tactil y joystick dejan de funcionar.

Solucion recomendada:

- Usar grupo `ui_controles_tactiles` o inyeccion desde `RedManager`.

### IP fija local

`RedManager.ADDRESS = "127.0.0.1"`.

Riesgo:

- Solo sirve para pruebas locales en la misma maquina.

Solucion recomendada:

- Menu principal con campo IP.

### Godot en PATH

En la terminal usada durante esta documentacion, `godot` no estaba disponible en PATH.

Riesgo:

- No se pudo validar el proyecto desde consola con Godot.

Solucion recomendada:

- Agregar Godot al PATH o documentar ruta exacta del ejecutable.

## 15. Roadmap Recomendado

Prioridad alta:

1. Cambiar input de movimiento para usar las acciones personalizadas `mover_*`.
2. Unificar sistema de plataformas para evitar duplicidad.
3. Crear barra/indicador de energia del aura en UI.
4. Crear menu principal real para Host/Join e IP.
5. Validar red en dos instancias de Godot.
6. Agregar UI de puntuacion (Label) que escuche `ScoreManager.score_changed`.

Prioridad media:

1. Evaluar si conviene migrar plataformas de deteccion por colision a grupos.
2. Agregar particulas:
   - polvo al Jugador Vivo;
   - rastro espectral al Fantasma.
3. Implementar muerte/respawn sincronizado.
4. Crear primera sala puzzle cooperativa.
5. Separar entornos visuales en recursos `.tres` bien nombrados.
6. Crear escenas `.tscn` para Coin y Goal con nodos preconfigurados (Area3D + CollisionShape3D + MeshInstance3D).
7. Agregar efectos visuales/sonido a la recogida de monedas y al completar nivel.

Prioridad baja:

1. Mejorar materiales y modelos temporales.
2. Agregar sonidos de salto, aura y activacion de plataformas.
3. Agregar feedback visual cuando una plataforma entra en rango del aura.
4. Considerar pantalla de victoria/resumen al completar nivel antes de cambiar escena.

## 16. Como Agregar Una Nueva Habilidad

Patron recomendado:

1. Crear script en `scripts/characters/`, por ejemplo `habilidad_nueva.gd`.
2. Crear un nodo hijo en la escena del personaje.
3. El componente maneja su estado interno.
4. El componente emite senales.
5. El personaje conecta esas senales.
6. La UI escucha senales publicas del personaje, no del componente.

Ejemplo conceptual:

```text
Input local en Fantasma
  -> fantasma.gd llama habilidad.intentar_activar()
  -> habilidad emite estado_cambiado
  -> fantasma.gd emite senal publica
  -> controles_tactiles.gd actualiza UI
```

## 17. Como Agregar Una Nueva Plataforma Cooperativa

Forma actual:

1. Crear `StaticBody3D`.
2. Configurar `collision_layer` o `collision_mask` con `CAPA_ESPIRITUAL = 4` / layer 3 `Plano_Espiritual`.
3. Agregar `CollisionShape3D`.
4. Agregar `MeshInstance3D`.
5. Revisar que collision layer/mask iniciales permitan que el Fantasma la registre.

Forma recomendada futura:

1. Crear grupo `plataforma_aura`.
2. Agregar las plataformas a ese grupo.
3. Reemplazar busqueda por nombre con:

```gdscript
get_tree().get_nodes_in_group("plataforma_aura")
```

## 18. Como Probar Manualmente

Prueba local rapida:

1. Abrir el proyecto en Godot.
2. Ejecutar `mundo_pruebas.tscn`.
3. Usar F1 para iniciar Host.
4. Abrir segunda instancia del proyecto.
5. Usar F2 para conectar Cliente.
6. Verificar:
   - Host controla Jugador Vivo.
   - Cliente controla Fantasma.
   - Solo la camara del personaje local esta activa.
   - UI del Fantasma se vuelve azul.
   - Fantasma tiene un salto alto unico.
   - Fantasma cae lento.
   - Interactuar activa aura.
   - Plataformas con colision espiritual se vuelven solidas/visibles al entrar en radio.

Prueba de regresion recomendada:

- Mover ambos personajes.
- Saltar con ambos.
- Activar aura varias veces y esperar cooldown.
- Hacer que el Jugador Vivo intente usar plataforma inactiva y activa.
- Hacer caer personajes bajo `LIMITE_CAIDA_Y`.
- Confirmar que no se mueven ambos personajes desde una sola instancia.

## 19. Resumen De Estado Actual

Completado:

- Reorganizacion principal de carpetas.
- `RedManager` como Autoload.
- `ScoreManager` como Autoload (singleton de puntuacion).
- Base compartida `CharacterBase`.
- Jugador y Fantasma heredando de `CharacterBase`.
- Aura componentizada en `HabilidadAura`.
- UI desacoplada por senales para el estado del aura.
- Fantasma diferenciado con salto unico alto y caida lenta.
- Plataformas activables por aura con sincronizacion RPC.
- Camaras locales segun autoridad multiplayer.
- Sistema de monedas (`coin.gd`) con eliminacion sincronizada por RPC.
- Objetivo de nivel (`goal.gd`) que requiere ambos personajes para activarse, con cambio de escena sincronizado por RPC.
- Jugador y Fantasma NO colisionan entre si (capas 2 y 3 separadas, sin incluir la capa del otro en mask).
- Camera cull_mask del Fantasma excluye capa 4 → monedas/objetivo no se renderizan en su pantalla.
- Capa 4 (`Objetivo_Moneda`) creada y estandarizada para objetos coleccionables y objetivo.

Pendiente o mejorable:

- Unificar sistema de plataformas.
- Evaluar migracion de deteccion por colision a grupos.
- Cambiar input base a acciones `mover_*`.
- Menu principal real con IP configurable.
- Barra visual de energia/cooldown.
- Respawn sincronizado por red.
- Validacion automatica con Godot desde consola.
- UI de puntuacion (Label que escuche `ScoreManager.score_changed`).
- Crear escenas `.tscn` para Coin y Goal con nodos preconfigurados.
- Efectos visuales/sonido para recogida de monedas y completar nivel.
- Pantalla de victoria/resumen antes de cambiar escena.

## 20. Sistema De Objetos Interactivos (Nuevo)

### `scripts/objects/coin.gd`

Clase:

```gdscript
extends Area3D
```

Responsabilidades:

- Representar una moneda coleccionable.
- Incrementar la puntuacion mediante `ScoreManager`.
- Eliminarse de forma sincronizada en todos los peers via RPC.

Variable exportada:

- `value: int = 1` → puntos que otorga al recogerla.

Colisiones:

- `collision_layer = 1 << 3` → capa 4 (`Objetivo_Moneda`).
- `collision_mask = (1 << 1) | (1 << 2)` → detecta capas 2 (Jugador) y 3 (Fantasma).

Flujo:

1. Un personaje entra en el area.
2. Si el peer tiene autoridad, llama `ScoreManager.add_score(value)`.
3. Llama `rpc("_remover_para_todos")` para eliminar la moneda en todos los peers.
4. `queue_free()` local como respaldo.

Nota visual: la camara del Fantasma tiene `cull_mask` sin capa 4, por lo que las monedas no se ven en su pantalla, aunque puede recogerlas.

### `scripts/objects/goal.gd`

Clase:

```gdscript
extends Area3D
```

Responsabilidades:

- Representar el objetivo de nivel.
- Cambiar de escena solo cuando ambos personajes (Jugador y Fantasma) estan dentro simultaneamente.
- Sincronizar el cambio de escena en todos los peers.

Variable exportada:

- `next_scene_path: String = "res://scenes/levels/mundo_pruebas.tscn"` → ruta de la siguiente escena. Configurable desde el inspector.

Colisiones:

- `collision_layer = 1 << 3` → capa 4 (`Objetivo_Moneda`).
- `collision_mask = (1 << 1) | (1 << 2)` → detecta capas 2 y 3.

Flujo:

1. Cada vez que un personaje entra, se agrega a `_cuerpos_dentro`.
2. Cada vez que un personaje sale, se remueve de `_cuerpos_dentro`.
3. `_verificar_activacion()` comprueba si hay al menos un `Jugador` y un `Fantasma`.
4. Si ambos estan presentes y el peer tiene autoridad, llama `rpc("rpc_change_scene", next_scene_path)`.
5. El RPC ejecuta `get_tree().change_scene_to_file(path)` en todos los peers.

### `scripts/core/score_manager.gd`

Clase:

```gdscript
extends Node
```

Es Autoload con nombre `ScoreManager`.

Responsabilidades:

- Mantener la variable `score: int`.
- Emitir la senal `score_changed(new_score)` al incrementar.
- Funcion `add_score(value)` para sumar puntos.

Pendiente:

- Crear un nodo de UI (Label) que escuche `score_changed` y muestre el puntaje.
- Evaluar si la puntuacion debe sincronizarse por red o si cada peer lleva su propia cuenta.

### Como Agregar Una Nueva Moneda Al Nivel

1. Crear un `Area3D` en la escena del nivel.
2. Asignar el script `scripts/objects/coin.gd`.
3. Agregar un `CollisionShape3D` hijo (esfera o caja pequena).
4. Agregar un `MeshInstance3D` hijo para la representacion visual.
5. En el inspector, configurar `value` si se quiere un valor distinto de 1.
6. Las capas se configuran automaticamente por codigo.

### Como Agregar El Objetivo De Nivel

1. Crear un `Area3D` en la escena del nivel.
2. Asignar el script `scripts/objects/goal.gd`.
3. Agregar un `CollisionShape3D` hijo (zona donde deben pararse ambos personajes).
4. Agregar representacion visual (mesh, particulas, modelo).
5. En el inspector, configurar `next_scene_path` con la ruta de la siguiente escena.
6. Ambos personajes deben estar dentro simultaneamente para activar el cambio.

## 21. Archivos Que Una IA Deberia Leer Primero

Orden recomendado:

1. `documentacion/DOCUMENTACION_TECNICA_ACTUAL.md`.
2. `project.godot`.
3. `scenes/levels/mundo_pruebas.tscn`.
4. `scripts/base/character_base.gd`.
5. `scripts/characters/jugador.gd`.
6. `scripts/characters/fantasma.gd`.
7. `scripts/characters/habilidad_aura.gd`.
8. `scripts/core/red_manager.gd`.
9. `scripts/core/score_manager.gd`.
10. `scripts/objects/coin.gd`.
11. `scripts/objects/goal.gd`.
12. `scripts/ui/controles_tactiles.gd`.
13. `scripts/core/administrador_plataformas.gd`.

Con ese orden se entiende primero el objetivo, luego la configuracion, despues la escena principal y finalmente los sistemas que se comunican entre si.
