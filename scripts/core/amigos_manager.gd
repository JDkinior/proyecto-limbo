extends RefCounted
class_name AmigosManager

# Sistema de amigos persistente.
# Extraído de RedManager para reducir responsabilidad.

const AMIGOS_FILE = "user://amigos.json"

static func cargar() -> Dictionary:
	if not FileAccess.file_exists(AMIGOS_FILE):
		return {}
	var file = FileAccess.open(AMIGOS_FILE, FileAccess.READ)
	if not file:
		return {}
	var text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var error = json.parse(text)
	if error == OK:
		if typeof(json.data) == TYPE_DICTIONARY:
			return json.data
	return {}

static func guardar(amigos: Dictionary) -> void:
	var file = FileAccess.open(AMIGOS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(amigos, "\t"))
		file.close()

static func agregar(nombre: String, ip: String) -> void:
	var amigos = cargar()
	amigos[nombre] = ip
	guardar(amigos)

static func eliminar(nombre: String) -> void:
	var amigos = cargar()
	if amigos.has(nombre):
		amigos.erase(nombre)
		guardar(amigos)
