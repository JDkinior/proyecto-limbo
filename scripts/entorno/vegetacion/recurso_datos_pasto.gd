extends Resource
class_name RecursoDatosPasto

## Recurso binario para almacenar matrices de transformación del pasto pintado.
## Al guardarse como archivo '.res', Godot almacena los datos de forma binaria pura,
## eliminando el inflado de texto en archivos .tscn y acelerando la carga instantánea.
@export var transforms: Array[Transform3D] = []
