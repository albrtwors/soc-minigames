# res://scripts/minigames/soc_td_3d/defenses/firewall_turret.gd
extends "res://scripts/minigames/soc_td_3d/defenses/base_defense_3d.gd"

@export var dano: float = 25.0
@export var intervalo_disparo: float = 1.4
@export var alcance_ray: float = 14.0

var _timer: Timer
var _raycast: RayCast3D


func _ready() -> void:
	super._ready()
	id_defensa = "firewall"
	hp_max = 90.0
	hp = hp_max
	costo = 100

	# RayCast elevado a Y = 0.3 para alinearse con el centro de las amenazas
	_raycast = RayCast3D.new()
	_raycast.position = Vector3(0.0, 0.3, 0.0)
	_raycast.target_position = Vector3(alcance_ray, 0.0, 0.0)
	_raycast.collision_mask = 2  # Capa 2 = Amenazas
	_raycast.collide_with_bodies = true
	_raycast.collide_with_areas = true
	_raycast.enabled = true
	add_child(_raycast)

	_timer = Timer.new()
	_timer.wait_time = intervalo_disparo
	_timer.timeout.connect(_intentar_disparar)
	add_child(_timer)
	_timer.start()


func _intentar_disparar() -> void:
	if hp <= 0.0 or not is_inside_tree():
		return

	_raycast.force_raycast_update()

	if _raycast.is_colliding():
		var objetivo = _raycast.get_collider()
		# Verifica que el objeto colisionado pertenezca al carril actual
		if objetivo and "lane" in objetivo and objetivo.lane == lane:
			var pos_disparo := get_spawn_shoot_position()
			disparo_solicitado.emit(pos_disparo, Vector3(1, 0, 0), dano)


func get_spawn_shoot_position() -> Vector3:
	# Retorna la posición global del punto de disparo
	if has_node("SpawnShootPoint"):
		return $SpawnShootPoint.global_position
	return global_position + Vector3(0.5, 0.3, 0.0)


func destruir() -> void:
	if _timer:
		_timer.stop()
	super.destruir()
