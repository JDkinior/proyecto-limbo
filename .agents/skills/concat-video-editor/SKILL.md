---
name: concat-video-editor
description: >-
  Edición automatizada de video local usando Concat y su servidor MCP.
  Utiliza este skill cuando el usuario solicite editar videos, añadir subtítulos,
  hacer cortes, aplicar efectos o renderizar clips con Concat.
---

# Concat Video Editor Skill

Este skill permite interactuar con el editor de video **Concat** (ubicado en `C:\Program Files\Concat\concat.exe`) a través de su servidor MCP o su puerto local de automatización `127.0.0.1:7420`.

## Principio de Aislamiento de Tokens
Para evitar que las 41 herramientas del servidor MCP de Concat se inyecten de forma fija en cada turno de conversación (lo cual consumiría miles de tokens innecesarios en proyectos de código como Godot), la interacción se realiza:
1. **Invocando al subagente dedicado**: `concat-video-editor` mediante la herramienta `invoke_subagent`.
2. **O mediante llamadas directas al puente MCP**: Ejecutando comandos stdio hacia `concat.exe --mcp` solo durante la ejecución de la tarea.

## Flujo de Trabajo
1. **Crear o Abrir Proyecto**: `project_create` o `project_open`.
2. **Importar Archivo**: `media_import`.
3. **Organizar Línea de Tiempo**: `clip_add`, `clip_frame` (fit/fill).
4. **Títulos y Subtítulos**: `title_add`, `captions_add`.
5. **Efectos y Keyframes**: `keyframe_set`, `effect_layer_add`.
6. **Previsualización Visual**: `preview_frame` a un archivo `.png`.
7. **Guardar y Exportar**: `project_save`, `export_start` y `export_wait`.
