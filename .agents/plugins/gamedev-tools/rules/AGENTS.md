# Reglas de Desarrollo de Videojuegos - Proyecto Limbo

## 1. Godot 4.x & GDScript
- **Sintaxis Moderna (Godot 4)**: Utiliza siempre GDScript 2.0 (ej. `@onready`, `@export`, anotaciones `@rpc`, clases fuertemente tipadas `var speed: float = 10.0`). No utilizar sintaxis obsoleta de Godot 3.
- **Jerarquía de Nodos y Ciclo de Vida**:
  - `_ready()` para inicialización y suscripción a señales.
  - `_physics_process(delta)` para movimiento de cuerpos físicos y sincronización.
  - `_process(delta)` para lógica visual o inputs que no dependan del motor de física.
- **Gestión de Recursos**:
  - Reutiliza `PackedScene`, `Material` y `Mesh` para evitar fugas de memoria o stuttering por instanciación repetida.
- **Herramientas Godot MCP**:
  - Utiliza las herramientas de `godot-ai` para inspeccionar la jerarquía de la escena, editar nodos, gestionar scripts y analizar logs de ejecución en caliente.

## 2. Integración y Workflow 3D con Blender
- **Flujo de Modelos y Mallas**:
  - Los modelos 3D se originan o modifican en Blender y se exportan en formato `.gltf` / `.glb` hacia la carpeta `assets/` de Godot.
  - Mantener la escala uniforme en Blender (1 unidad = 1 metro) y aplicar transformaciones (Ctrl+A -> Rotación y Escala) antes de exportar.
- **Herramientas Blender MCP**:
  - Utiliza el servidor MCP de `blender` para ejecutar scripts en Blender, consultar información de escenas o generar assets directamente desde el editor.
