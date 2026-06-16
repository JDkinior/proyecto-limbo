# GUÍA RÁPIDA - Personaje Fantasma

## ¿Qué se creó?

Un segundo personaje llamado **Fantasma** que puede manipular plataformas en el mundo.

## Archivos Nuevos

```
Scripts/
  fantasma.gd                        ← Script del personaje fantasma
  administrador_plataformas.gd       ← Sistema de sincronización
  
fantasma.tscn                        ← Escena del personaje fantasma
README_FANTASMA.md                   ← Documentación completa
GUIA_RAPIDA.md                       ← Este archivo
```

## Cambios a Archivos Existentes

**mundo_pruebas.tscn** - Actualizado con:
- Instancia de Fantasma
- AdministradorPlataformas
- Plataformas inicialmente desactivadas (collision_layer = 0)

## Cómo Probar Ahora

### 1. Abre el Editor Godot
```
Archivo > Abrir Proyecto > proyecto-limbo/
```

### 2. Abre la Escena de Prueba
```
Busca: mundo_pruebas.tscn
Click derecho > Editar Escena
```

### 3. Presiona Play (F5)

### 4. Prueba los Controles

#### Personaje Vivo (Jugador):
- **Joystick izquierda**: Movimiento
- **Botón Saltar**: Saltar
- **Arrastrar derecha**: Rotar cámara

#### Personaje Fantasma:
- **Joystick izquierda**: Movimiento (igual que jugador)
- **Botón Interactuar**: Activar/Desactivar plataforma cercana
- **Arrastrar derecha**: Rotar cámara

### 5. Observa

1. El **Fantasma** (azul translúcido) se mueve
2. Acércate a una **plataforma** (verás que se detectan)
3. Presiona **Botón Interactuar** para activarla
4. La plataforma cambia:
   - **Opacidad**: De 50% a 100% (o viceversa)
   - **Colisión**: Puede o no ser atravesada
5. Revisa la **consola** (arriba) para ver logs:
   ```
   [Fantasma] Plataforma 'Caja_Fisica' ACTIVADA (distancia: 4.25 m)
   ```

## Mecánica en Acción

### Flujo:
1. Jugador vivo intenta pasar sobre una plataforma
2. Plataforma está inactiva → **atraviesa sin tocar**
3. Fantasma se acerca a la plataforma
4. Fantasma presiona botón interactuar
5. Plataforma se activa → **El jugador ahora puede pisar sobre ella**
6. Fantasma presiona nuevamente para desactivarla

## Próximos Pasos

### Expandir el Sistema

**1. Agregar UI Visual**
Crea un panel que muestre:
- Cuántas plataformas hay cerca
- Cuántas están activas
- Coordenadas del fantasma

**2. Nuevas Plataformas**
Duplica una Caja_Física en el editor para probar con más

**3. Enemigos o Obstáculos**
Crea objetos que solo el vivo o el fantasma puedan atravesar

**4. Niveles Puzzle**
Diseña niveles donde se requiere coordinación

## Solución de Problemas Rápida

| Problema | Solución |
|----------|----------|
| Botones no responden | Verifica que `Input Map` tenga `ui_select` configurado |
| El fantasma no detecta plataformas | Los nodos deben tener "Caja_Fisica" en el nombre |
| Las plataformas no desaparecen visualmente | A veces la transparencia necesita actualizarse; presiona F5 |
| El juego va lento | Reduce el RADIO_DETECCION en fantasma.gd |

## Comandos Útiles (En la Consola)

```gdscript
# Obtener referencias en la consola
var fantasma = get_tree().root.get_node("/Mundo_Pruebas/Fantasma")
print(fantasma.obtener_plataformas_detectadas())

# Ver estado de plataformas
print(fantasma.obtener_plataformas_activas())
```

## Estructura de Capas de Colisión

```
Capa 1: Suelo (siempre sólido)
Capa 2: Plataformas manipulables
Capa 3: Personajes (ambos)
```

- Jugador vivo: collision_layer=3, collision_mask=3 (toca capas 1 y 2)
- Fantasma: collision_layer=3, collision_mask=3 (igual)
- Suelo: collision_layer=1, collision_mask=1 (siempre activo)
- Plataformas: collision_layer=0/2, collision_mask=0/2 (toggled)

## ¿Necesitas Modificar?

### Cambiar radio de detección
Abre `Scripts/fantasma.gd` línea 18:
```gdscript
@export var RADIO_DETECCION : float = 10.0  # ← Cambia este valor
```

### Cambiar distancia de visibilidad
Línea 161-162 en fantasma.gd:
```gdscript
plataforma.modulate.a = 1.0  # Completamente opaca (1.0) o 0.5 (semi-transparente)
```

### Agregar más plataformas
1. Copia `Caja_Fisica` en mundo_pruebas.tscn
2. Muévela a otra posición
3. **Importante**: Mantén el nombre como `Caja_Fisica*`

## Recursos Relacionados

- [Documentación Completa](README_FANTASMA.md)
- [Script del Fantasma](Scripts/fantasma.gd)
- [Script del Administrador](Scripts/administrador_plataformas.gd)
- [Escena del Fantasma](fantasma.tscn)

---

**¿Todo funcionando?** ¡Excelente! Ahora puedes:
- Agregar más plataformas
- Crear niveles con puzzles
- Experimentar con la mecánica

¡Buen desarrollo! 🚀
