extends Node3D

var player: CharacterBody3D
var bullet_timer: Timer
var score_label: Label
var elapsed_time: float = 0.0
var game_active: bool = true
var bullets: Array[Area3D] = []

const GRID_SIZE: float = 10.0
const HALF_GRID: float = 5.0
const BULLET_SPEED: float = 8.0
const PLAYER_SPEED: float = 7.0
const SPAWN_INTERVAL: float = 0.5

func _ready() -> void:
	_setup_environment()
	_setup_player()
	_setup_bullet_spawner()
	_setup_ui()

func _setup_environment() -> void:
	var floor_static = StaticBody3D.new()
	floor_static.name = "FloorStatic"
	add_child(floor_static)

	var floor_mesh = MeshInstance3D.new()
	floor_mesh.name = "FloorMesh"
	floor_mesh.mesh = BoxMesh.new()
	floor_mesh.mesh.size = Vector3(GRID_SIZE, 0.5, GRID_SIZE)
	floor_mesh.position.y = -0.25
	floor_static.add_child(floor_mesh)

	var floor_collision = CollisionShape3D.new()
	floor_collision.shape = BoxShape3D.new()
	floor_collision.shape.size = Vector3(GRID_SIZE, 0.5, GRID_SIZE)
	floor_collision.position.y = -0.25
	floor_static.add_child(floor_collision)

	var camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0, 8, 6)
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3.ZERO)

	var light = DirectionalLight3D.new()
	light.name = "DirectionalLight3D"
	light.position = Vector3(5, 10, 5)
	light.shadow_enabled = true
	add_child(light)
	light.look_at(Vector3.ZERO)

func _setup_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 0.5, 0)

	var player_mesh = MeshInstance3D.new()
	var capsule = CapsuleMesh.new()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.4, 1.0)
	capsule.material = mat
	player_mesh.mesh = capsule
	player_mesh.position.y = 0.5
	player.add_child(player_mesh)

	var player_collision = CollisionShape3D.new()
	player_collision.shape = CapsuleShape3D.new()
	player_collision.shape.height = 1.0
	player_collision.shape.radius = 0.3
	player.add_child(player_collision)

	add_child(player)

func _setup_bullet_spawner() -> void:
	bullet_timer = Timer.new()
	bullet_timer.name = "BulletTimer"
	bullet_timer.wait_time = SPAWN_INTERVAL
	bullet_timer.timeout.connect(_spawn_bullet)
	add_child(bullet_timer)
	bullet_timer.start()

func _setup_ui() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)

	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = "Tiempo: 0.0s"
	score_label.position = Vector2(10, 10)
	score_label.add_theme_font_size_override("font_size", 24)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	canvas.add_child(score_label)

func _spawn_bullet() -> void:
	if not game_active:
		return

	var bullet = Area3D.new()
	bullet.name = "Bullet"

	var edge = randi() % 4
	var pos_x: float
	var pos_z: float
	var velocity: Vector3

	match edge:
		0:
			pos_x = -HALF_GRID
			pos_z = randf_range(-HALF_GRID, HALF_GRID)
			velocity = Vector3(BULLET_SPEED, 0, 0)
		1:
			pos_x = HALF_GRID
			pos_z = randf_range(-HALF_GRID, HALF_GRID)
			velocity = Vector3(-BULLET_SPEED, 0, 0)
		2:
			pos_x = randf_range(-HALF_GRID, HALF_GRID)
			pos_z = HALF_GRID
			velocity = Vector3(0, 0, -BULLET_SPEED)
		3:
			pos_x = randf_range(-HALF_GRID, HALF_GRID)
			pos_z = -HALF_GRID
			velocity = Vector3(0, 0, BULLET_SPEED)

	bullet.position = Vector3(pos_x, 0.5, pos_z)

	var bullet_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	var bullet_mat = StandardMaterial3D.new()
	bullet_mat.albedo_color = Color(1.0, 0.1, 0.1)
	sphere.material = bullet_mat
	sphere.radius = 0.15
	sphere.height = 0.3
	bullet_mesh.mesh = sphere
	bullet.add_child(bullet_mesh)

	var bullet_collision = CollisionShape3D.new()
	bullet_collision.shape = SphereShape3D.new()
	bullet_collision.shape.radius = 0.15
	bullet.add_child(bullet_collision)

	bullet.set_meta("velocity", velocity)
	bullet.body_entered.connect(_on_bullet_body_entered.bind(bullet))

	add_child(bullet)
	bullets.append(bullet)

func _on_bullet_body_entered(body: Node, _bullet: Area3D) -> void:
	if body == player:
		_game_over()

func _process(delta: float) -> void:
	if not game_active:
		return

	elapsed_time += delta
	score_label.text = "Tiempo: %.1fs" % elapsed_time

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	player.velocity = Vector3(input_dir.x, 0, input_dir.y) * PLAYER_SPEED
	player.move_and_slide()
	player.position.x = clamp(player.position.x, -HALF_GRID, HALF_GRID)
	player.position.z = clamp(player.position.z, -HALF_GRID, HALF_GRID)

	var to_remove: Array[Area3D] = []
	for bullet in bullets:
		var vel = bullet.get_meta("velocity") as Vector3
		bullet.position += vel * delta
		if abs(bullet.position.x) > HALF_GRID + 1 or abs(bullet.position.z) > HALF_GRID + 1:
			to_remove.append(bullet)

	for b in to_remove:
		bullets.erase(b)
		if is_instance_valid(b):
			b.queue_free()

func _game_over() -> void:
	game_active = false
	bullet_timer.stop()

	for bullet in bullets:
		if is_instance_valid(bullet):
			bullet.queue_free()
	bullets.clear()

	player.position = Vector3(0, 0.5, 0)
	score_label.text = "Game Over! %.1fs" % elapsed_time

	get_tree().create_timer(1.0).timeout.connect(func():
		elapsed_time = 0.0
		game_active = true
		bullet_timer.start()
		score_label.text = "Tiempo: 0.0s"
	)
