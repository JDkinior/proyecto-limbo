# Documentación Central - Proyecto Limbo

## 📌 Descripción General
Proyecto Limbo es un juego cooperativo asimétrico desarrollado en **Godot 4**. La mecánica principal gira en torno a la colaboración entre dos entidades en planos diferentes: el **Jugador Vivo** y el **Fantasma**. Mientras el primero navega el mundo físico, el segundo manipula la realidad para crear caminos.

## 📂 Organización del Proyecto

### Escenas Principales (`.tscn`)
*   **`mundo_pruebas.tscn`**: El escenario principal de pruebas. Contiene el entorno, las plataformas físicas, la iluminación y los puntos de spawn de los personajes.
*   **`jugador.tscn`**: Escena del personaje "Vivo". Posee colisiones físicas estándar y una cámara en tercera persona.
*   **`fantasma.tscn`**: Escena del personaje espectral. Incluye el sistema de **Aura** visual y configuraciones de visibilidad translúcida.
*   **`controles_tactiles.tscn`**: Interfaz de usuario (HUD) universal que detecta joysticks virtuales y botones de acción para dispositivos móviles.

### Scripts de Lógica (`.gd`)
*   **`red_manager.gd`**: El corazón del multijugador P2P. Gestiona la creación de servidores (Host) y la conexión de clientes (Join), asignando la autoridad de red a cada jugador.
*   **`jugador.gd`**: Controla el movimiento, salto y rotación de cámara del jugador vivo. Incluye lógica para limpiar la interfaz de efectos visuales del fantasma.
*   **`fantasma.gd`**: Script avanzado que gestiona:
	*   Movimiento y doble salto.
	*   Sistema de **Aura Temporal**: Se activa con energía que se consume (encogimiento) y tiene tiempo de recarga.
	*   Sincronización RPC de plataformas.
	*   Visión espiritual (filtro azul) y teñido de interfaz mediante Shaders.
*   **`administrador_plataformas.gd`**: Detecta y registra las plataformas en el mundo para que el fantasma pueda interactuar con ellas.

## 🌐 Sistema Multijugador (P2P)
El juego utiliza el sistema de alto nivel de Godot (`MultiplayerAPI`):
1.  **Host (ID 1)**: Controla al Jugador Vivo.
2.  **Cliente**: Controla al Fantasma.
3.  **Sincronización**: Se utiliza `MultiplayerSynchronizer` para la posición/rotación y `RPC` (Remote Procedure Calls) para eventos de estado (como activar una plataforma).

## 🎮 Mecánicas de Personaje

| Característica | Jugador Vivo | Fantasma |
| :--- | :--- | :--- |
| **Color UI** | Amarillo/Original | Azul (Shader) |
| **Visión** | Normal | Espectral (Filtro Azul/Cian) |
| **Colisión** | Suelo y Plataformas Activas | Suelo y TODAS las plataformas |
| **Habilidad** | Supervivencia y Plataformeo | Activación de Aura (Botón Interactuar) |
| **Efecto de Aura** | No posee | Activa plataformas en un radio que encoge |

## 🛠 Log de Actualizaciones - 26 de Octubre de 2023

### Implementaciones del día:
*   **Separación de Autoridad**: Se corrigió el error donde ambos personajes se movían al mismo tiempo. Ahora cada instancia controla solo a su personaje asignado.
*   **Interfaz Dinámica**: 
	*   Se implementó un **Shader** en tiempo de ejecución que tiñe la interfaz de azul para el Fantasma, eliminando el color verde no deseado.
	*   El Jugador Vivo recupera su color original automáticamente al conectar.
*   **Aura Evolucionada**: La habilidad del Fantasma ya no es pasiva. Ahora se activa con el botón "Interactuar", tiene un radio que se encoge con el tiempo y entra en *cooldown* (recarga) tras agotarse.
*   **Visión Espiritual**: Se añadió un efecto de ambiente (`Environment`) con corrección de color mediante gradientes para que el Fantasma vea el mundo en tonos azules.
*   **Física Independiente**: Se configuraron capas de colisión para que el Fantasma pueda caminar sobre plataformas incluso cuando son intangibles para el Jugador Vivo.
*   **Desactivación de Colisión entre Jugadores**: Los personajes ya no se empujan ni bloquean entre sí.

## 🚀 Próximos Pasos
1.  **Barra de Energía**: Añadir un componente visual en la UI del Fantasma para mostrar el tiempo de recarga del aura.
2.  **Efectos de Partículas**: Agregar rastro espectral al Fantasma y partículas de polvo al Jugador Vivo al saltar.
3.  **Sistema de Muerte y Respawn**: Sincronizar por red cuando un jugador cae al vacío para reiniciar a ambos o al afectado.
4.  **Menú Principal**: Diseñar una interfaz de inicio que permita elegir la IP del servidor antes de entrar al mundo de pruebas.
5.  **Puzzles Cooperativos**: Crear la primera sala que requiera que el Fantasma mantenga activa una plataforma mientras el Vivo salta y acciona una palanca.

## 🏛️ Propuesta de Arquitectura y Escalabilidad

Para asegurar que el proyecto pueda crecer sin volverse inmanejable, se recomienda la siguiente reestructuración:

### 1. Reorganización de Directorios
Separar los recursos por dominio y tipo para evitar carpetas saturadas:
*   **`assets/`**: Modelos 3D, Texturas, Sonidos y recursos de Entorno (`.tres`).
*   **`scenes/`**:
	*   `characters/`: Escenas de los personajes.
	*   `ui/`: Interfaces y menús.
	*   `levels/`: Mapas y mundos.
	*   `components/`: Nodos reutilizables (Cámaras, Áreas de detección).
*   **`scripts/`**:
	*   `core/`: Singletons/Autoloads (Red, Configuración Global).
	*   `base/`: Clases maestras de las que heredan otros scripts.
	*   `ui/`: Lógica de control de interfaz.

### 2. Refactorización de Lógica
*   **Herencia de Personajes**: Crear un `BaseCharacter.gd` que gestione el movimiento 3D, gravedad y cámara compartido. `jugador.gd` y `fantasma.gd` solo extenderán esta clase para añadir sus habilidades únicas.
*   **Desacoplamiento mediante Señales**: Evitar que los personajes busquen nodos de UI directamente. Los personajes deben emitir señales (ej. `aura_recargando(porcentaje)`) y la UI debe encargarse de escucharlas y actualizarse.
*   **Componentización**: Extraer lógicas complejas a nodos hijos. Por ejemplo, un nodo `HabilidadAura` que maneje su propio cooldown y radio, aligerando el script principal del personaje.
*   **Red como Singleton**: Convertir el `RedManager` en un Autoload para que la conexión persista entre cambios de niveles y sea accesible desde cualquier lugar.

### 3. Flujo Ideal de Trabajo
Implementar una comunicación de "Arriba hacia Abajo" (Llamadas de funciones) y de "Abajo hacia Arriba" (Señales):
1.  **Input**: Detecta la acción del jugador.
2.  **Lógica**: El personaje procesa la acción o delega a un componente.
3.  **Comunicación**: El componente emite una señal informando el cambio de estado.
4.  **Visual**: Los Shaders, la UI y los Efectos de Partículas reaccionan a la señal de forma independiente.




### Notas:
Si en el futuro quieres que el fantasma deje rastro o tenga efectos que el jugador vivo no deba ver nunca (incluso si están activos), la mejor práctica es usar Cull Layers:

1. Pones el Aura en la Capa Visual 2.
2. Configuras la cámara del Fantasma para ver capas 1 y 2.
3. Configuras la cámara del Vivo para ver solo la capa 1. De esta forma, el motor ni siquiera intentará renderizar el aura en la cámara del jugador vivo.

---
*Documento generado para el equipo de desarrollo de Proyecto Limbo.*
