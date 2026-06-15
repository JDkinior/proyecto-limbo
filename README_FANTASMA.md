# Sistema de Personaje Fantasma - Proyecto Limbo

## Descripción General

El proyecto Limbo implementa un sistema cooperativo donde tienes dos personajes:
1. **Personaje Vivo** - El jugador principal que puede caminar, saltar y necesita alcanzar objetivos
2. **Personaje Fantasma** - Un personaje espectral que puede manipular plataformas

## Mecánica Principal

### Personaje Fantasma - Habilidad de Control de Plataformas

El fantasma puede **seleccionar plataformas y hacerlas sólidas o intangibles** para el personaje vivo.

**Cómo funciona:**
- El fantasma detecta automáticamente plataformas cercanas (radio de detección: 10 unidades)
- Presiona el botón de selección (ui_select) para alternar el estado de la plataforma más cercana
- Las plataformas activas: Visible (opacidad 100%) y sólida
- Las plataformas inactivas: Semi-transparente (opacidad 50%) e intangible

### Controles

#### Ambos Personajes:
- **Movimiento**: Joystick izquierdo (móvil) o Flechas (PC)
- **Saltar**: Botón de salto (móvil) o ESPACIADOR (PC)
- **Rotación Cámara**: Arrastra dedo en zona derecha (móvil) o Ratón (PC)

#### Fantasma (Adicional):
- **Seleccionar Plataforma**: Botón "ui_select" (Mobile: Botón Interactuar, PC: ESPACIO o ENTER)

## Estructura Técnica

### Archivos Creados

1. **Scripts/fantasma.gd** - Script del personaje fantasma
   - Movimiento similar al jugador
   - Detección de plataformas cercanas
   - Control de estado de plataformas

2. **fantasma.tscn** - Escena del fantasma
   - Mesh azul/translúcido con emisión
   - CharacterBody3D con colisiones
   - Cámara 3D con mismo setup que el jugador

3. **Scripts/administrador_plataformas.gd** - Sincronizador central
   - Monitorea el estado de plataformas
   - Sincroniza cambios entre fantasma y mundo
   - Aplica colisiones y transparencia

### Flujo de Datos

```
Fantasma detecta prox. → Fantasma selecciona plat. → Administrador sincroniza → Mundo actualiza colisiones
```

## Configuración de Plataformas

Las plataformas (Caja_Fisica, Caja_Fisica2, etc.) inician con:
- `collision_layer = 0` (no colisionan)
- `collision_mask = 0` (no detectan colisiones)
- `modulate.a = 0.5` (semi-transparentes)

Cuando se activan:
- `collision_layer = 2` (capa 2 activada)
- `collision_mask = 2` (detecta capa 2)
- `modulate.a = 1.0` (completamente visibles)

## Pruebas en Mundo_Pruebas

### Escena Incluida: mundo_pruebas.tscn

Contiene:
- 1 Suelo sólido permanente
- 4 Plataformas manipulables (Caja_Física)
- 2 Personajes (Jugador + Fantasma)
- Controles táctiles
- Iluminación y ambiente

### Cómo Probar

1. **Abre mundo_pruebas.tscn** en el editor
2. **Presiona Play** (F5)
3. **Mueve el fantasma** (lado izquierdo con joystick)
4. **Acércate a una plataforma** (verás que se detectan)
5. **Presiona el botón de selección** para activar/desactivar

### Observa:
- La plataforma cambia de opacidad
- El personaje vivo puede o no atravesarla

## Próximas Mejoras Sugeridas

1. **UI Visual**
   - Mostrar plataformas detectadas
   - Indicador de qué plataforma está seleccionada
   - Contador de plataformas activas

2. **Sonidos y Efectos**
   - Efecto visual cuando se activa/desactiva plataforma
   - Sonido de confirmación

3. **Mecánicas Avanzadas**
   - Límite de plataformas activas simultáneamente
   - Zonas especiales que solo el fantasma puede tocar
   - Inversión de roles (fantasma solamente para pasar muros, vivo para activar botones)

4. **Niveles**
   - Puzzles que requieren coordinación
   - Temporizadores de activación

## Notas Técnicas

### Capas de Colisión

- **Capa 1**: Jugador, elementos estáticos permanentes
- **Capa 2**: Plataformas manipulables (activadas/desactivadas por fantasma)
- **Capa 3**: Fantasma (se interseca con capas 1 y 2)

### Scripts Relacionados

- `jugador.gd` - Personaje vivo (original)
- `fantasma.gd` - Personaje fantasma (nuevo)
- `administrador_plataformas.gd` - Sincronizador (nuevo)
- `controles_tactiles.tscn` - UI de controles (original)

## Troubleshooting

### Los controles no responden
- Verifica que `Input Map` tenga las acciones "ui_select", "saltar" configuradas
- Revisa que los nodos de controles táctiles estén presentes

### Las plataformas no aparecen
- El administrador espera nodos `StaticBody3D` con nombre que contenga "Caja_Fisica"
- Verifica los nombres en la jerarquía

### El fantasma se queda pegado
- Los scale de las cápsulas pueden causar problemas de física
- Intenta normalizar los transforms de los personajes

## Autor
Desarrollado con MCP Godot AI para Proyecto Limbo
