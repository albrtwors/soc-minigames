# res://scripts/minigames/infrastructure_rush/topology_manager.gd
extends Node3D

## Construye y gestiona los dispositivos 3D sobre la mesa y sus cables.
## Los dispositivos son cajas con Area3D para el picking por rayo, una etiqueta
## flotante y un Marker3D "CameraFocus" para la vista MICRO.

const FONT_ORBITRON: String = "res://assets/fonts/Orbitron-Black.ttf"

const COLOR_SELECCION := Color(0.0, 1.0, 0.7)

const COLORES_TIPO := {
	"router": Color(1.0, 0.55, 0.1),
	"switch": Color(0.1, 0.6, 0.7),
	"firewall": Color(0.85, 0.18, 0.18),
	"servidor": Color(0.15, 0.4, 0.9),
	"bastion": Color(0.2, 0.7, 0.3)
}

const TAMANOS_TIPO := {
	"router": Vector3(1.2, 0.55, 0.7),
	"switch": Vector3(0.9, 0.4, 0.5),
	"firewall": Vector3(1.0, 0.5, 0.5),
	"servidor": Vector3(0.6, 1.0, 0.65),
	"bastion": Vector3(0.75, 0.6, 0.75)
}

## Contenedores instanciados en el editor.
@onready var devices_container: Node3D = $DevicesContainer
@onready var cables_container: Node3D = $CablesContainer

var _nodos: Dictionary = {} # id -> { node, material, color }
var _cable_pares: Dictionary = {} # "a|b" (ordenado) -> true

## Construye todos los dispositivos a partir del Array[Dictionary] del nivel.
func construir_dispositivos(data: Array[Dictionary]) -> void:
	limpiar_dispositivos()
	for def in data:
		var id: String = str(def.get("id", ""))
		if id.is_empty():
			continue
		_nodos[id] = _crear_dispositivo(def)

func limpiar_dispositivos() -> void:
	for child in devices_container.get_children():
		child.queue_free()
	_nodos.clear()
	limpiar_cables()

func _crear_dispositivo(def: Dictionary) -> Dictionary:
	var id: String = str(def.get("id", "dev"))
	var nombre: String = str(def.get("nombre", id.to_upper()))
	var tipo: String = str(def.get("tipo", "servidor"))
	var x: float = float(def.get("x", 0.0))
	var z: float = float(def.get("z", 0.0))
	var tam: Vector3 = TAMANOS_TIPO.get(tipo, Vector3(0.8, 0.6, 0.6))
	var color: Color = COLORES_TIPO.get(tipo, Color(0.5, 0.5, 0.5))

	var node := MeshInstance3D.new()
	node.name = id
	var box := BoxMesh.new()
	box.size = tam
	node.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.45
	mat.metallic = 0.15
	node.material_override = mat
	node.position = Vector3(x, tam.y * 0.5, z)
	devices_container.add_child(node)

	var area := Area3D.new()
	area.name = "Area"
	area.collision_layer = 1
	area.collision_mask = 1
	node.add_child(area)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = tam
	shape.shape = box_shape
	area.add_child(shape)

	var label := Label3D.new()
	label.name = "Label"
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.text = nombre
	label.font = load(FONT_ORBITRON)
	label.font_size = 50
	label.outline_size = 80
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.pixel_size = 0.0005
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	label.rotation_degrees = Vector3(-90, 0, 0)
	label.fixed_size = true
	label.position = Vector3(0, tam.y * 0.5 + 0.35, 0)
	node.add_child(label)

	var focus := Marker3D.new()
	focus.name = "CameraFocus"
	focus.position = Vector3(0, tam.y * 0.5 + 0.45, 1.9)
	node.add_child(focus)
	focus.look_at(node.global_position, Vector3.UP)

	return {"node": node, "material": mat, "color": color}

# --- Consultas ---

func get_device_ids() -> Array:
	return _nodos.keys()

func get_nodo(id: String) -> Node3D:
	if not _nodos.has(id):
		return null
	return _nodos[id]["node"]

func get_posicion(id: String) -> Vector3:
	var node := get_nodo(id)
	return node.global_position if node else Vector3.ZERO

func get_focus_marker(id: String) -> Marker3D:
	var node := get_nodo(id)
	if not node:
		return null
	return node.find_child("CameraFocus", true, false) as Marker3D

## Activa el resaltado (emisión) del dispositivo seleccionado.
func destacar(id: String, activo: bool) -> void:
	if not _nodos.has(id):
		return
	var mat: StandardMaterial3D = _nodos[id]["material"]
	if activo:
		mat.emission_enabled = true
		mat.emission = COLOR_SELECCION
		mat.emission_energy_multiplier = 0.8
	else:
		mat.emission_enabled = false

# --- Cables ---

## Crea un cable (cilindro) entre dos dispositivos y lo devuelve.
func crear_cable(origen_id: String, destino_id: String, color: Color) -> MeshInstance3D:
	if not _nodos.has(origen_id) or not _nodos.has(destino_id):
		return null

	var a: Vector3 = _nodos[origen_id]["node"].position
	var b: Vector3 = _nodos[destino_id]["node"].position
	var diff: Vector3 = b - a
	var longitud: float = diff.length()
	if longitud <= 0.001:
		return null

	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.045
	mesh.bottom_radius = 0.045
	mesh.height = longitud
	mesh.cap_top = true
	mesh.cap_bottom = true

	var mi := MeshInstance3D.new()
	mi.name = "Cable_%s_%s" % [origen_id, destino_id]
	mi.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.4
	mat.metallic = 0.1
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.35
	mi.material_override = mat

	var dir: Vector3 = diff.normalized()
	var up := Vector3.UP
	if absf(dir.dot(up)) > 0.99:
		up = Vector3.RIGHT
	var x_axis: Vector3 = up.cross(dir).normalized()
	var z_axis: Vector3 = dir.cross(x_axis).normalized()
	mi.transform = Transform3D(Basis(x_axis, dir, z_axis), (a + b) * 0.5)

	_cable_pares[_clave_cable(origen_id, destino_id)] = true
	cables_container.add_child(mi)
	return mi

func _clave_cable(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]

## Devuelve true si ya existe un cable lógico entre ambos (en cualquier sentido).
func hay_cable(origen_id: String, destino_id: String) -> bool:
	return _cable_pares.has(_clave_cable(origen_id, destino_id))

func limpiar_cables() -> void:
	for child in cables_container.get_children():
		child.queue_free()
	_cable_pares.clear()
