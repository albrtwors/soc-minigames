# res://scripts/minigames/soc_td_3d/soc_td_main.gd
extends Node3D

signal minijuego_completado(puntos: int)

const DEFAULT_NIVEL_PATH := "res://scripts/data/soc_td_levels/nivel_1.tres"

@export var defensa_scenes: Dictionary = {}
@export var amenaza_scenes: Dictionary = {}
@export var projectile_scene: PackedScene
@export var token_scene: PackedScene

const COSTOS_DEFECTO := {
	"server_pdu": 40,
	"firewall": 75,
	"wall_ids": 60,
	"antivirus": 100,
	"honeypot": 75,
	"ips": 125,
}

@onready var grid_board: GridBoard3D = $GridBoard3D
@onready var defense_container: Node3D = $DefenseContainer
@onready var threat_container: Node3D = $ThreatContainer
@onready var projectile_container: Node3D = $ProjectileContainer
@onready var spawner: ThreatSpawner = $SpawnerManager
@onready var hud: HudSocTd = $CanvasHUD
@onready var camara: Camera3D = $Camera3D

var presupuesto: int = 200
var puntos_actuales: int = 0
var partida_activa: bool = false
var _controlado_por_frame: bool = false
var _tiempo_restante: float = 120.0

var _costos: Dictionary = {}

# MULTIPLICADOR DE VELOCIDAD INCREMENTADO
# Pasa de 0.035 a 0.5 para que los enemigos tengan un desplazamiento claro y fluido
var _velocidad_base: float = 0.5
var _velocidad_global: float = 1.0
var _defensa_seleccionada: String = ""

var _ocupadas: Dictionary = {}
var _amenazas: Array[BaseThreat3D] = []
var _defensas_por_carril: Array = [[], [], [], [], []]
var _backup_usado: Array[int] = [0, 0, 0, 0, 0]
var _max_backup_por_carril: int = 2
var _valor_token_nivel: int = 25
var _penalizacion_token_caducado: int = 5

var X_INICIAL: float = GridBoard3D.X_INICIAL


func _ready() -> void:
	if spawner:
		spawner.amenaza_solicitada.connect(_on_amenaza_solicitada)
	if hud:
		hud.defensa_seleccionada.connect(_on_defensa_seleccionada)
		hud.velocidad_cambiada.connect(_on_velocidad_cambiada)

	get_tree().create_timer(0.2).timeout.connect(func():
		if _controlado_por_frame:
			return
		var data := load(DEFAULT_NIVEL_PATH)
		if data is NivelSocTdData:
			inicializar_minijuego(data)
		else:
			inicializar_minijuego(null)
	)


func _on_defensa_seleccionada(id: String) -> void:
	_defensa_seleccionada = id


func _on_velocidad_cambiada(n: int) -> void:
	_velocidad_global = float(n)
	Engine.time_scale = _velocidad_global


func inicializar_minijuego(data_nivel: Resource) -> void:
	_controlado_por_frame = true
	_limpiar_partida()

	_costos = COSTOS_DEFECTO.duplicate()
	var nivel_td: NivelSocTdData = null
	if data_nivel is NivelSocTdData:
		nivel_td = data_nivel as NivelSocTdData
		presupuesto = nivel_td.presupuesto_inicial
		_tiempo_restante = nivel_td.duracion_partida
		_velocidad_base = maxf(0.3, nivel_td.velocidad_base)
		_valor_token_nivel = nivel_td.valor_token_uptime
		_penalizacion_token_caducado = nivel_td.penalizacion_token_caducado
		for k in nivel_td.costos_defensas:
			if int(k) != 0:
				_costos[str(k)] = int(nivel_td.costos_defensas[k])
	else:
		presupuesto = 200
		_tiempo_restante = 120.0
		_velocidad_base = 0.5

	if spawner:
		if nivel_td:
			var t_spawn: float = maxf(1.5, nivel_td.tiempo_entre_amenazas)
			spawner.iniciar(nivel_td.pool_amenazas, t_spawn)
		else:
			var pool_defecto: Array[Dictionary] = [
				{"id": "script_kdd", "peso": 2.0},
				{"id": "phishing", "peso": 1.0}
			]
			spawner.iniciar(pool_defecto, 2.5) # Oleadas más seguidas para igualar la velocidad

	if hud:
		hud.construir_cartas(_costos)
		hud.set_presupuesto(presupuesto)
		hud.set_velocidad(int(_velocidad_global))

	partida_activa = true


func detener_partida() -> void:
	partida_activa = false
	if spawner:
		spawner.detener()
	Engine.time_scale = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if not partida_activa:
		return

	if event is InputEventMouseMotion:
		_actualizar_preview(event.position)
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_procesar_clic(event.position)
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_defensa_seleccionada = ""
		grid_board.ocultar_preview()


func _actualizar_preview(screen_pos: Vector2) -> void:
	var celda := _celda_en_pantalla(screen_pos)
	if not celda.get("valida", false):
		grid_board.ocultar_preview()
		return
	var key := "%d,%d" % [celda.col, celda.lane]
	var colocable: bool = _defensa_seleccionada != "" and not _ocupadas.has(key) \
		and _costos.get(_defensa_seleccionada, 0) <= presupuesto
	grid_board.colocar_preview(celda.world_pos, colocable)


func _procesar_clic(screen_pos: Vector2) -> void:
	var token := _raycast_token(screen_pos)
	if token:
		token.recoger()
		return

	var celda := _celda_en_pantalla(screen_pos)
	if not celda.get("valida", false):
		return
	if _defensa_seleccionada.is_empty():
		return

	var key := "%d,%d" % [celda.col, celda.lane]
	if _ocupadas.has(key):
		return
	var costo: int = _costos.get(_defensa_seleccionada, 0)
	if costo > presupuesto:
		return

	_colocar_defensa(_defensa_seleccionada, celda.col, celda.lane, key)


func _celda_en_pantalla(screen_pos: Vector2) -> Dictionary:
	return grid_board.celda_desde_pantalla(camara, screen_pos)


func _raycast_token(screen_pos: Vector2) -> UptimeToken:
	if not camara:
		return null
	var origin := camara.project_ray_origin(screen_pos)
	var normal := camara.project_ray_normal(screen_pos)
	var end := origin + normal * 100.0
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_bodies = false
	query.collide_with_areas = true
	query.collision_mask = 4
	var result := space.intersect_ray(query)
	if result.is_empty():
		return null
	var collider = result.get("collider")
	if collider is UptimeToken:
		return collider as UptimeToken
	return null


func _colocar_defensa(id: String, col: int, lane: int, key: String) -> void:
	if not defensa_scenes.has(id):
		return
	var escena: PackedScene = defensa_scenes[id]
	var defensa: BaseDefense3D = escena.instantiate() as BaseDefense3D
	defense_container.add_child(defensa)

	defensa.position = grid_board.posicion_celda(col, lane)
	defensa.lane = lane
	defensa.col = col
	defensa.costo = _costos.get(id, 0)

	_ocupadas[key] = defensa
	_defensas_por_carril[lane].append(defensa)
	presupuesto -= defensa.costo
	if hud:
		hud.set_presupuesto(presupuesto)

	_conectar_defensa(id, defensa, lane)

	if id == "ips" and defensa.has_method("activar"):
		defensa.call("activar")

	_actualizar_sensores_carril(lane)

	_defensa_seleccionada = ""
	grid_board.ocultar_preview()


func _conectar_defensa(id: String, defensa: BaseDefense3D, lane: int) -> void:
	if defensa.has_signal("token_generado"):
		defensa.token_generado.connect(func(pos: Vector3): _spawnear_token(pos))

	if defensa.has_signal("disparo_solicitado"):
		if id == "antivirus":
			defensa.disparo_solicitado.connect(
				func(pos: Vector3, dir: Vector3, dano: float):
					_spawnear_proyectil(pos, dir, dano, 0.35, 3.0)
			)
		else:
			defensa.disparo_solicitado.connect(
				func(pos: Vector3, dir: Vector3, dano: float):
					_spawnear_proyectil(pos, dir, dano, 1.0, 0.0)
			)

	if defensa.has_signal("explotar"):
		defensa.explotar.connect(
			func(_pos: Vector3, _lane: int, _col: int, radio: int):
				_aplicar_dano_area(_lane, _col, radio, 500.0)
		)

	if defensa.has_signal("drop_all"):
		defensa.drop_all.connect(_drop_all_carril)

	defensa.destruida.connect(func(d: Node3D):
		var def_target := d as BaseDefense3D
		if def_target:
			var key := key_defensa(def_target)
			if _ocupadas.get(key) == def_target:
				_ocupadas.erase(key)
			_defensas_por_carril[lane].erase(def_target)
			_actualizar_sensores_carril(lane)
			def_target.destruir()
	)


func key_defensa(defensa: BaseDefense3D) -> String:
	return "%d,%d" % [defensa.col, defensa.lane]


func _spawnear_token(pos: Vector3) -> void:
	if not token_scene or not partida_activa:
		return
	var token: UptimeToken = token_scene.instantiate() as UptimeToken
	add_child(token)
	token.add_to_group("tokens")
	
	var pos_elevada := pos
	if pos_elevada.y < 0.6:
		pos_elevada.y = 0.9
		
	token.setup(pos_elevada, _valor_token_nivel)
	
	token.token_recogido.connect(func(t: Node3D):
		presupuesto += (t as UptimeToken).valor
		if hud:
			hud.set_presupuesto(presupuesto)
		_emitir_puntos()
	)
	token.token_caducado.connect(func(t: Node3D):
		presupuesto = max(0, presupuesto - _penalizacion_token_caducado)
		if hud:
			hud.set_presupuesto(presupuesto)
	)


func _spawnear_proyectil(pos: Vector3, dir: Vector3, dano: float,
		factor_lento: float, duracion: float) -> void:
	if not projectile_scene:
		return
	var p: SocProjectile = projectile_scene.instantiate() as SocProjectile
	projectile_container.add_child(p)
	p.setup(pos, dir, dano, factor_lento, duracion, 0)


# --- AMENAZAS ---

func _on_amenaza_solicitada(id: String, lane: int) -> void:
	if not partida_activa:
		return
	if not amenaza_scenes.has(id):
		id = "script_kdd"
	var escena: PackedScene = amenaza_scenes[id]
	var amenaza: BaseThreat3D = escena.instantiate() as BaseThreat3D
	threat_container.add_child(amenaza)
	amenaza.lane = lane

	# Aplica la escala global directa
	amenaza.velocidad = amenaza.velocidad * _velocidad_base

	var z := grid_board.posicion_celda(0, lane).z
	amenaza.position = Vector3(grid_board.x_spawn(), 0.3, z)
	amenaza.amenaza_muerta.connect(_on_amenaza_muerta)
	amenaza.cruzo_perimetro.connect(_on_cruce_perimetro)
	_amenazas.append(amenaza)
	_actualizar_sensores_carril(lane)


func _on_amenaza_muerta(amenaza: BaseThreat3D) -> void:
	if _amenazas.has(amenaza):
		_amenazas.erase(amenaza)
	puntos_actuales += int(amenaza.puntos)
	_emitir_puntos()


func _on_cruce_perimetro(amenaza: BaseThreat3D) -> void:
	var lane: int = amenaza.lane
	if _backup_usado[lane] < _max_backup_por_carril:
		_backup_usado[lane] += 1
		_eliminar_amenazas_carril(lane)
	else:
		_fin_de_partida(puntos_actuales)


func _eliminar_amenazas_carril(lane: int) -> void:
	var vivas := _amenazas.duplicate()
	for a in vivas:
		if a.lane == lane and is_instance_valid(a):
			_amenazas.erase(a)
			puntos_actuales += int(a.puntos)
			a.destruir()
	_emitir_puntos()


func _drop_all_carril(lane: int) -> void:
	_eliminar_amenazas_carril(lane)


func _aplicar_dano_area(lane: int, col: int, radio: int, dano: float) -> void:
	var x_centro: float = grid_board.posicion_celda(col, lane).x
	var z_centro: float = grid_board.posicion_celda(col, lane).z
	var rango_x: float = grid_board.TAM_CELDA * (radio + 0.4)
	var rango_z: float = grid_board.TAM_CELDA * (radio + 0.4)
	
	for a in _amenazas.duplicate():
		if not is_instance_valid(a):
			continue
		if absf(a.position.x - x_centro) <= rango_x and absf(a.position.z - z_centro) <= rango_z:
			a.tomar_dano(dano)


func _actualizar_sensores_carril(lane: int) -> void:
	var hay_ids := false
	for d in _defensas_por_carril[lane]:
		if is_instance_valid(d) and str(d.id_defensa) == "wall_ids":
			hay_ids = true
			break
	for a in _amenazas:
		if is_instance_valid(a) and a.lane == lane and a.has_method("set_detectable"):
			a.set_detectable(hay_ids)


func _process(delta: float) -> void:
	if not partida_activa:
		return

	_tiempo_restante -= delta
	if hud and hud.has_method("set_tiempo"):
		hud.call("set_tiempo", maxf(0.0, _tiempo_restante))

	if _tiempo_restante <= 0.0 and not _controlado_por_frame:
		_fin_de_partida(puntos_actuales)
		return

	for a in _amenazas.duplicate():
		if is_instance_valid(a) and a.position.x <= X_INICIAL - 0.2:
			a.cruzar_perimetro()


func _fin_de_partida(puntos: int) -> void:
	if not partida_activa:
		return
	partida_activa = false
	detener_partida()
	puntos_actuales = max(puntos_actuales, puntos)
	minijuego_completado.emit(puntos_actuales)


func _limpiar_partida() -> void:
	presupuesto = 200
	puntos_actuales = 0
	_defensa_seleccionada = ""
	_ocupadas.clear()
	_amenazas.clear()
	_backup_usado = [0, 0, 0, 0, 0]
	_defensas_por_carril = [[], [], [], [], []]
	for child in defense_container.get_children():
		child.queue_free()
	for child in threat_container.get_children():
		child.queue_free()
	for child in projectile_container.get_children():
		child.queue_free()
	for child in get_tree().get_nodes_in_group("tokens"):
		child.queue_free()


func _emitir_puntos() -> void:
	if has_node("/root/EventBus"):
		var bus = get_node("/root/EventBus")
		if bus.has_signal("puntos_actualizados"):
			bus.puntos_actualizados.emit(puntos_actuales)
