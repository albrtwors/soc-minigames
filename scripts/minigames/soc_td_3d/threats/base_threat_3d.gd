# res://scripts/minigames/soc_td_3d/threats/base_threat_3d.gd
extends Area3D
class_name BaseThreat3D

signal amenaza_muerta(amenaza: Node3D)
signal cruzo_perimetro(amenaza: Node3D)

@export var id_amenaza: String = "base"
@export var hp_max: float = 50.0
var hp: float = 50.0

@export var lane: int = 0
@export var velocidad: float = 1.0
@export var puntos: int = 10
@export var sigilosa: bool = false
@export var dano_ataque: float = 8.0
@export var intervalo_ataque: float = 1.0

## Color del cuerpo del robot. Se aplica al modelo en _ready (cada
## amenaza hija lo sobreescribe para distinguirse).
@export var color_cuerpo: Color = Color(0.2236, 0.0, 0.9098)

@onready var model: RobotModel = $base_robot
var _factor_velocidad: float = 1.0
var _timer_lento: Timer
var _puede_moverse: bool = true
var _atacando: bool = false

# Lógica de RayCast y temporizador de ataque
var _raycast_frontal: RayCast3D
var _timer_ataque: float = 0.0


func _ready() -> void:
	hp = hp_max
	_cambiar_animacion("walking")
	_cambiar_color()
	collision_layer = 2   # Capa 2: Amenazas
	collision_mask = 1    # Capa 1: Defensas / Nodos construidos

	_configurar_raycast()


func _configurar_raycast() -> void:
	if has_node("RayCast3D"):
		_raycast_frontal = $RayCast3D
	else:
		_raycast_frontal = RayCast3D.new()
		_raycast_frontal.name = "RayCast3D"
		add_child(_raycast_frontal)

	_raycast_frontal.target_position = Vector3(-0.8, 0.0, 0.0)
	_raycast_frontal.collision_mask = 1
	_raycast_frontal.collide_with_areas = true
	_raycast_frontal.collide_with_bodies = true
	_raycast_frontal.enabled = true


func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		return

	# Chequeo de colisión frontal
	var atacando := false
	if _raycast_frontal and _raycast_frontal.is_colliding():
		var colisionador = _raycast_frontal.get_collider()
		var defensa := _obtener_instancia_defensa(colisionador)

		if defensa and is_instance_valid(defensa):
			atacando = true
			if not _atacando:
				_atacando = true
				_cambiar_animacion("punching")
			_procesar_ataque(defensa, delta)

	if not atacando:
		if _atacando:
			_atacando = false
			_cambiar_animacion("walking")
		_timer_ataque = 0.0

		# Movimiento regular en -X
		if _puede_moverse:
			position.x -= velocidad * _factor_velocidad * delta


func _cambiar_animacion(nombre: String) -> void:
	if model and model.has_method("reproducir"):
		model.reproducir(nombre)


func _cambiar_color() -> void:
	if model and model.has_method("cambiar_color"):
		model.cambiar_color(color_cuerpo)


func _obtener_instancia_defensa(colisionador: Object) -> Node:
	if not colisionador:
		return null
	if colisionador is BaseDefense3D:
		return colisionador
	if colisionador is Node and colisionador.get_parent() is BaseDefense3D:
		return colisionador.get_parent()
	return null


func _procesar_ataque(defensa: Node, delta: float) -> void:
	_timer_ataque += delta
	if _timer_ataque >= intervalo_ataque:
		_timer_ataque = 0.0
		if defensa.has_method("tomar_dano"):
			defensa.tomar_dano(dano_ataque)


func set_puede_moverse(b: bool) -> void:
	_puede_moverse = b


func get_spawn_token_position() -> Vector3:
	if has_node("SpawnTokenPoint"):
		return $SpawnTokenPoint.global_position

	var max_y: float = global_position.y
	var meshes := find_children("*", "MeshInstance3D", true, false)

	for m in meshes:
		var mesh_node := m as MeshInstance3D
		if mesh_node and mesh_node.visible:
			var aabb := mesh_node.get_aabb()
			var tope_local := aabb.position + Vector3(0.0, aabb.size.y, 0.0)
			var tope_global := mesh_node.global_transform * tope_local
			if tope_global.y > max_y:
				max_y = tope_global.y

	if max_y == global_position.y:
		max_y += 1.2

	return Vector3(global_position.x, max_y + 0.3, global_position.z)


func set_lento(factor: float, duracion: float) -> void:
	_factor_velocidad = minf(_factor_velocidad, factor)
	if _timer_lento:
		_timer_lento.stop()
		_timer_lento.start(duracion)
	else:
		_timer_lento = Timer.new()
		_timer_lento.one_shot = true
		_timer_lento.wait_time = duracion
		_timer_lento.timeout.connect(func(): _factor_velocidad = 1.0)
		add_child(_timer_lento)
		_timer_lento.start()


func set_detectable(detectable: bool) -> void:
	sigilosa = not detectable


func puede_ser_detectado() -> bool:
	return not sigilosa


func tomar_dano(cant: float) -> bool:
	if hp <= 0.0:
		return false
	hp = maxf(0.0, hp - cant)
	if hp <= 0.0:
		amenaza_muerta.emit(self)
		destruir()
		return true
	return false


func cruzar_perimetro() -> void:
	cruzo_perimetro.emit(self)


func destruir() -> void:
	set_physics_process(false)
	queue_free()
