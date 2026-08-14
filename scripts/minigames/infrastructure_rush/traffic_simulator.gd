# res://scripts/minigames/infrastructure_rush/traffic_simulator.gd
extends Node3D

## Simula el tráfico de auditoría: lanza paquetes 3D entre dispositivos a lo
## largo de los cables. Los paquetes verdes ("OK") llegan a destino y se
## resuelven con éxito; los rojos ("TEST FALLO") se detienen a mitad del
## recorrido, parpadean y notifican el fallo.

signal paquete_resuelto(ok: bool)

const FONT_ORBITRON: String = "res://assets/fonts/Orbitron-Black.ttf"

const COLOR_OK := Color(0.2, 1.0, 0.4)
const COLOR_FAIL := Color(1.0, 0.2, 0.2)

## Nodo contenedor instanciado en el editor.
@onready var spawner: Node3D = $PacketSpawner

var _paquetes: Array = [] # { node, a, b, t, dur, ok, etiqueta, estado, parpadeo }

## Crea un paquete que viaja de `origen` a `destino` en `duracion` segundos.
func crear_paquete(origen: Vector3, destino: Vector3, ok: bool, etiqueta: String, duracion: float) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	sphere.radial_segments = 10

	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_OK if ok else COLOR_FAIL
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 1.0
	mi.material_override = mat
	mi.position = origen
	spawner.add_child(mi)

	var lbl := Label3D.new()
	lbl.text = etiqueta
	lbl.font = load(FONT_ORBITRON)
	lbl.font_size = 18
	lbl.outline_size = 6
	lbl.outline_modulate = Color(0, 0, 0, 0.9)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.fixed_size = true
	lbl.position = Vector3(0, 0.22, 0)
	mi.add_child(lbl)

	_paquetes.append({
		"node": mi,
		"a": origen,
		"b": destino,
		"t": 0.0,
		"dur": maxf(0.3, duracion),
		"ok": ok,
		"estado": "viajando",
		"parpadeo": 0.0
	})

func quedan_paquetes() -> bool:
	return _paquetes.size() > 0

func limpiar() -> void:
	for p in _paquetes:
		if is_instance_valid(p["node"]):
			p["node"].queue_free()
	_paquetes.clear()

func _process(delta: float) -> void:
	for i in range(_paquetes.size() - 1, -1, -1):
		var p: Dictionary = _paquetes[i]
		if p["estado"] == "viajando":
			p["t"] += delta
			var u: float = clampf(p["t"] / p["dur"], 0.0, 1.0)
			p["node"].position = (p["a"] as Vector3).lerp(p["b"] as Vector3, u)
			if u >= 1.0:
				if p["ok"]:
					_resolver(i, true)
				else:
					p["estado"] = "fallido"
					p["node"].position = (p["a"] as Vector3).lerp(p["b"] as Vector3, 0.55)
					p["parpadeo"] = 0.0
		elif p["estado"] == "fallido":
			p["parpadeo"] += delta
			var node := p["node"] as MeshInstance3D
			if is_instance_valid(node):
				var pulso: float = 0.6 + 0.4 * absf(sin(p["parpadeo"] * 8.0))
				node.scale = Vector3.ONE * pulso
			if p["parpadeo"] >= 1.2:
				_resolver(i, false)

func _resolver(indice: int, ok: bool) -> void:
	var p: Dictionary = _paquetes[indice]
	_paquetes.remove_at(indice)
	if is_instance_valid(p["node"]):
		p["node"].queue_free()
	paquete_resuelto.emit(ok)
