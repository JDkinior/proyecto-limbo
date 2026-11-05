# Documento de Diseño de Juego (GDD) - Proyecto Limbo

**Versión:** 2.0 (Consolidada)  
**Motor:** Godot Engine 4.x (Mobile / Desktop)  
**Plataforma Objetivo:** Móviles (Android / iOS) con soporte Gamepad y PC  
**Estado:** Documento de Diseño Oficial  
**Tablero de Seguimiento (Trello):** [Kanban Proyecto Limbo](https://trello.com/b/LcyBmqEC/kanban-proyecto-limbo)

---

## 1. Visión General del Juego

**Proyecto Limbo** es un videojuego de plataformas y puzles en 3D cooperativo asimétrico, diseñado específicamente para dispositivos móviles. El núcleo jugable gira en torno a la relación de dos almas que existen en planos superpuestos pero desconectados: el **Jugador Vivo** (plano físico y terrestre) y el **Fantasma** (plano espiritual y etéreo).

> *"Dos almas que no pueden tocarse, pero sí salvarse."*

### Pilares Fundamentales
1. **Asimetría de Perspectiva:** Ambos personajes habitan el mismo escenario pero perciben e interactúan con realidades distintas (física vs. espiritual).
2. **Ayuda Mutua Estricta:** Ningún nivel puede completarse sin la intervención activa de ambos personajes. No existe avance unilateral.
3. **Convergencia Visual y Narrativa:** El juego parte de una dicotomía cromática absoluta (amarillo cálido para el Vivo, azul espectral para el Fantasma) que converge progresivamente hacia el blanco-gris del Limbo.
4. **Game Feel Ágil y Expresivo:** Inspirado en la respuesta inmediata y diversión de movimiento de *Super Mario Odyssey*, con tolerancia generosa en controles táctiles móviles.
5. **Cada Nivel produce un Short:** Cada fase introduce un gancho visual o mecánico llamativo fácilmente comunicable en videos verticales de 20 a 40 segundos.

---

## 2. Narrativa y Progresión (6 Actos)

| Acto | Zona | Hito Narrativo |
| :--- | :--- | :--- |
| **I** | **Praderas y Ruinas** | El Vivo habita praderas doradas; el Fantasma despierta en lo alto de ruinas azuladas al divisar un destello amarillo en la distancia. Baja planeando entre torbellinos hacia la pradera. Se encuentran, intentan estrechar sus manos, **se traspasan etéreamente** y comprenden su objetivo: alcanzar el Limbo para igualarse y tocarse. |
| **II** | **Montaña Ventosa** | Comienzan el viaje juntos. Una tormenta de viento huracanado los separa físicamente: el Vivo bordea las cornisas exteriores mientras el Fantasma cruza las cavernas interiores donde los tornados no penetran. Se reencuentran en la cima. |
| **III** | **Bosque del Faro** | Se adentran en un bosque místico de otoño. El Fantasma aprende a **poseer** vehículos y artefactos (Plataforma Taxi, Cañón Espiritual, Farol rotatorio) para transportar al Vivo sobre ciénagas y abrir caminos de luz. |
| **IV** | **Minas de Cristal** | Cavernas de cristal cobalto y violeta. Descubren que los cristales gigantes reflejan y canalizan el pulso del Aura espectral, engañando a criaturas subterráneas con señuelos cristalinos. |
| **V** | **Cielo Tormentoso** | Entre islas flotantes suspendidas sobre un mar de nubes y gárgolas que pulverizan plataformas, descubren el **Intercambio de Lugares**, transmutando sus posiciones en el aire para salvarse mutuamente del vacío. |
| **VI** | **El Limbo** | Un santuario etéreo blanco y gris donde convergen todas las fuerzas aprendidas. Enfrentan a **La Soledad** (manifestación de su aislamiento). Al disolverla, caminan frente a frente, extienden sus manos y **por fin se tocan físicamente**, desatando una onda cálida que unifica sus mundos. |

---

## 3. Personajes y Sistema de Movimiento

El sistema de movimiento prioriza la respuesta instantánea, conservación de inercia (*momentum*), amortiguación elástica de aterrizaje (*squash & stretch*) y tolerancia al error (*coyote time* y *jump buffer* de 0.12 segundos).

### Comparativa Asimétrica de Habilidades

| Parámetro | Jugador Vivo | Fantasma |
| :--- | :--- | :--- |
| **Color UI / Filtro** | Amarillo dorado original | Azul espectral con shader de aberración y cian |
| **Salto Principal** | Salto elástico con **doble salto** acrobático | **Salto largo único** con suspensión en el ápice |
| **Habilidad Aérea** | Caída rápida (*dive*) y pisotón (*ground pound*) | **Planeo prolongado** al mantener presionado saltar |
| **Interacción** | Física directa: empujar cajas, pisar botones, manivelas, palancas | **Aura Espectral** (activa plataformas y revela objetos) |
| **Habilidad Especial** | Golpear / aplastar enemigos vulnerables | **Posesión Espectral** de vehículos, artefactos y aliados |
| **Salud** | Sin barra de vida (1 impacto = reaparición en checkpoint) | Sin barra de vida (1 impacto = reaparición en checkpoint) |

---

## 4. Modos de Juego y Reglas de Diseño

### 4.1 Modo Cooperativo (2 Jugadores en Red Local / Online)
- Ambos jugadores controlan simultáneamente a su personaje (Host = Vivo, Cliente = Fantasma).
- La sincronización de posiciones se realiza vía `MultiplayerSynchronizer` y los eventos mecánicos mediante `RPC`.
- Si cualquiera de los dos cae al vacío o recibe un impacto, **ambos reaparecen de inmediato en el último checkpoint compartido**.

### 4.2 Modo Solitario (Alternancia Manual con Seguimiento)
El modo solitario no automatiza la resolución de los puzles:
1. **Seguimiento por rastro:** El personaje inactivo sigue automáticamente las huellas del personaje activo a 2.0–2.5 metros en tramos llanos y seguros.
2. **Sin teletransporte:** Si el seguidor no puede cruzar una brecha, **se frena**. Jamás se teletransporta por arte de magia.
3. **Puntos de Bloqueo (`PuntoCambio`):** En cada obstáculo que requiere facultades del compañero, el seguidor se detiene, aparece un icono sobre su cabeza y el botón de alternancia parpadea en la interfaz.
4. **Persistencia Total:** Al alternar, el personaje que queda en espera mantiene sus auras activas, posesiones de plataformas o mecanismos presionados.
5. **Invulnerabilidad del Inactivo:** Mientras espera o sigue por el rastro seguro, el compañero inactivo no activa trampas ni sufre daño.

### 4.3 Meta Implícita y Navegación sin HUD
- No existen flechas de navegación en pantalla ni brújulas artificiales.
- **Foco Lumínico:** La meta emite un haz volumétrico ascendente visible desde puntos clave del mapa.
- **Monedas Guiadas:** Arcos de monedas amarillas señalan las trayectorias del Vivo; arcos de monedas cian guían las rutas aéreas del Fantasma.
- **Gemas Espirituales:** Balizas luminosas en cotas elevadas o rutas alternativas que despiertan la curiosidad y guían a ambos personajes.

---

## 5. Estructura de Zonas y Niveles (12 Fases)

Cada zona consta de una pareja de niveles: el **primero introduce** la mecánica en un entorno seguro y el **segundo la pone a prueba** con mayor intensidad y un jefe final.

```
Zona 1: Praderas y Ruinas (Tutorial y Encuentro)
  ├── Nivel 1: El Despertar Separado (Pradera con toques de ruinas - Entorno del Vivo)
  └── Nivel 2: El Camino del Faro (Ruinas con toques de pradera - Entorno del Fantasma) [Jefe: Centinela Hueco]

Zona 2: Montaña Ventosa (Separación y Corrientes)
  ├── Nivel 3: La Gran Montaña (Separación: Exterior vs. Interior)
  └── Nivel 4: El Ascenso del Vendaval (Corrientes + Gólem) [Jefe: Ojo del Vendaval]

Zona 3: Bosque del Faro (Posesión y Sombras)
  ├── Nivel 5: Las Raíces Brumosas (Taxi + Cañón)
  └── Nivel 6: El Faro Ancestral (Farol rotatorio + Engranajes) [Jefe: Raíz Madre]

Zona 4: Minas de Cristal (Resonancia y Refracción)
  ├── Nivel 7: Las Cavernas Resonantes (Cristales Eco + Señuelos)
  └── Nivel 8: El Corazón Cristalino (Reflejo en cadena) [Jefe: Gusano Soberano]

Zona 5: Cielo Tormentoso (Intercambio y Vértigo)
  ├── Nivel 9: El Mar de Nubes (Intercambio de Lugares + Medusas)
  └── Nivel 10: Las Ruinas de la Tormenta (Gárgolas demoledoras) [Jefe: Gárgola Soberana]

Zona 6: El Limbo (Convergencia y Desenlace)
  ├── Nivel 11: El Último Umbral (Ecos del pasado + Recapitulación)
  └── Nivel 12: El Encuentro en el Limbo (Batalla en 5 fases contra La Soledad + Final)
```

---

## 6. Bestiario y Peligros Equilibrados

### Amenazas para el Jugador Vivo
- **Brote Espinoso (Zona 1):** Planta con apertura cíclica de espinas (2s abierta / 2s cerrada). El Vivo debe cruzar acompasadamente; el Fantasma puede adormecerla con el Aura.
- **Escarabajo Pétreo (Zona 2):** Criatura acorazada en repisas exteriores. Se enrolla y rueda; vulnerable cuando asoma.
- **Sombra Acechante (Zona 3):** Acecha en zonas en penumbra; se disuelve al ser enfocada por el Farol o farolas encendidas.
- **Gusano de Cristal (Zona 4):** Emerge del suelo rocoso; el Fantasma activa racimos de cristal para atraerlo y despejar el paso.

### Amenazas para el Fantasma
- **Torbellino Espiritual (Zonas 1 y 2):** Vórtice huracanado que succiona y arrastra al Fantasma al vacío. No se atraviesa; debe ser esquivado con planeo y timing.
- **Luciérnaga Cazadora (Zona 1-2):** Enjambre atraído por energía espiritual; el Vivo lo ahuyenta accionando fuentes de luz o palancas.
- **Centinela de Luz (Zona 3):** Foco lumínico abrasador para seres espectrales; el Vivo bloquea el haz con cajas o compuertas.
- **Espinas de Luz (Zona 4):** Cristales punzantes refractores que cortan rutas aéreas; el Vivo rompe sus anclajes físicos.

### Criaturas y Elementos Neutros / Aliados
- **Enemigo Espectral (Zona 2):** Sombra dormida que persigue al Vivo al entrar en su territorio. El Aura del Fantasma lo torna tangible y vulnerable para que el Vivo lo aplaste.
- **Gólem de Piedra (Zona 2):** El Vivo lo despierta accidentalmente; el Fantasma lo posee y utiliza sus puños de roca para demoler muros agrietados.
- **Medusa de Nube (Zona 5):** Criatura aérea etérea. Poseída por el Fantasma, sirve de trampolín elástico para propulsar al Vivo a gran altura.
- **Gárgola de Piedra (Zona 5):** Aplasta y pulveriza plataformas bajo los pies del Vivo en 1.5s, obligando a coordinar intercambios de emergencia.
- **Ecos (Zona 6):** Sombras que reproducen los movimientos pasados del jugador con 2 segundos de desfase.

---

## 7. Batallas de Jefe (Puzles Dinámicos en Equipo)

1. **Centinela Hueco (Zona 1):** Armadura antigua gigante. El Fantasma pulsa el Aura para volverlo tangible; el Vivo acciona un mecanismo para soltar un contrapeso y ejecuta un pisotón sobre su núcleo.
2. **Ojo del Vendaval (Zona 2):** Tornado colosal. El Fantasma navega corrientes laterales para penetrar el vórtice y disipar su escudo; el Vivo es lanzado por una corriente ascendente para rematarlo.
3. **Raíz Madre (Zona 3):** El Fantasma maneja el Farol para concentrar luz sobre los bulbos fotosensibles; el Vivo es disparado desde un cañón espiritual hacia los bulbos aturdidos.
4. **Gusano Soberano (Zona 4):** Empleo de resonancia múltiple reflejando el Aura en 3 prismas para aturdir al leviatán mientras el Vivo escala su lomo.
5. **Gárgola Soberana (Zona 5):** Pulveriza el cuadrilátero flotante por fases; el Fantasma conduce una medusa gigante y coordina intercambios en caída libre para alcanzar su cúspide.
6. **La Soledad (Zona 6 - Jefe Final):** Encarna 5 fases sucesivas que ponen a prueba cada una de las mecánicas aprendidas (Aura, Viento, Posesión, Cristales, Intercambio). Al disiparse, concluye con el epílogo interactivo donde ambos personajes se toman de la mano.

---

## 8. Hoja de Ruta y Metodología de Producción

- **Metodología Greybox First:** Construir la geometría básica y validar la ruta jugable antes de aplicar vegetación, pasto o rocas de alta fidelidad.
- **Presupuesto Móvil:** Máximo 100 Draw Calls simultáneos, límites estrictos de partículas y 60 FPS sostenidos en perfil Mobile Forward.
- **Gestión Kanban en Trello:** Todas las tareas del backlog, desarrollo activo, pruebas y finalizaciones se coordinan en el tablero oficial [Kanban Proyecto Limbo](https://trello.com/b/OZSrAhoz/kanban-proyecto-limbo).
