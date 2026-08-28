# res://scripts/minigames/soc_td_3d/threat_spawner.gd
extends Node3D
class_name ThreatSpawner

signal amenaza_solicitada(id: String, lane: int)

var tiempo_entre: float = 6.0
var pool: Array = []

var _timer: Timer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.timeout.connect(_spawnear)
	add_child(_timer)


func iniciar(p_pool: Array, p_tiempo_entre: float) -> void:
	pool = p_pool
	# Se asegura un intervalo mínimo de 1.5 segundos entre cada spawn
	tiempo_entre = maxf(1.5, p_tiempo_entre)
	_timer.wait_time = tiempo_entre
	_timer.start()


func detener() -> void:
	if _timer:
		_timer.stop()


func _spawnear() -> void:
	if pool.is_empty():
		return

	var id_elegido: String = "script_kdd"

	# Normalización del pool
	if pool[0] is Dictionary:
		var total := 0.0
		for item in pool:
			total += float((item as Dictionary).get("peso", 1.0))
		var r := _rng.randf() * total
		for item in pool:
			var dict := item as Dictionary
			r -= float(dict.get("peso", 1.0))
			if r <= 0.0:
				id_elegido = str(dict.get("id", "script_kdd"))
				break
	elif pool[0] is String:
		id_elegido = pool[_rng.randi_range(0, pool.size() - 1)]

	var carril := _rng.randi_range(0, 4)
	amenaza_solicitada.emit(id_elegido, carril)
