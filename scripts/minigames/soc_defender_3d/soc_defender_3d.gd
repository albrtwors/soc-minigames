# res://scripts/minigames/soc_defender_3d/soc_defender_3d.gd
extends Node3D

signal minijuego_completado(puntos: int)

enum EstadoCamara { MACRO, MICRO }

@export var amenaza_scene: PackedScene

# Parámetros del nivel (Fallback + Hidratable)
var velocidad_amenazas_base: float = 1.5
var tiempo_entre_amenazas: float = 2.5
var puntos_por_acierto: int = 100
var penalizacion_error: int = 25
var banco_amenazas: Array[Dictionary] = []

# Estado del juego
var estado_actual_camara: EstadoCamara = EstadoCamara.MACRO
var rack_enfocado: RackServer = null
var puntos_actuales: int = 0
var racks_array: Array[Node3D] = []

# SLA (Acuerdo de Nivel de Servicio)
var sla_uptime: float = 100.0
var _sla_acumulador: float = 0.0

# Control de fin de juego
var amenazas_procesadas: int = 0
var total_amenazas: int = 0
var juego_activo: bool = true

# Transformación macro
var cam_pos_macro: Vector3
var cam_rot_macro: Vector3

@onready var camara: Camera3D = $Camera3D
@onready var racks_container: Node3D = $RacksContainer
@onready var threats_container: Node3D = $ThreatsContainer
@onready var spawn_points: Node3D = $SpawnPoints
@onready var spawn_timer: Timer = Timer.new()

func _ready() -> void:
	if camara:
		cam_pos_macro = camara.global_position
		cam_rot_macro = camara.global_rotation

	_inicializar_timer()
	_indexar_racks()
	_cargar_banco_predeterminado()

	get_tree().create_timer(0.2).timeout.connect(func():
		if banco_amenazas.is_empty():
			_cargar_banco_predeterminado()
		_iniciar_partida()
	)

func _process(delta: float) -> void:
	_actualizar_penalizacion_sla(delta)

func _inicializar_timer() -> void:
	add_child(spawn_timer)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)

func _indexar_racks() -> void:
	racks_array.clear()
	if racks_container:
		for child in racks_container.get_children():
			if child is Node3D:
				racks_array.append(child)

func _iniciar_partida() -> void:
	amenazas_procesadas = 0
	total_amenazas = banco_amenazas.size()
	juego_activo = true
	sla_uptime = 100.0
	spawn_timer.start(tiempo_entre_amenazas)

## PUNTO DE ENTRADA: Hidratación desde NivelArcadeData / NivelSOCDefenderData
func inicializar_minijuego(data_nivel: NivelArcadeData) -> void:
	puntos_actuales = 0
	_limpiar_escena()
	_volver_a_vista_macro()

	if data_nivel:
		puntos_por_acierto = data_nivel.puntos_por_acierto
		penalizacion_error = data_nivel.penalizacion_error
		if data_nivel is NivelSOCDefenderData:
			var datos_soc := data_nivel as NivelSOCDefenderData
			velocidad_amenazas_base = datos_soc.velocidad_amenazas_base
			tiempo_entre_amenazas = datos_soc.tiempo_entre_amenazas
			banco_amenazas = datos_soc.lista_amenazas.duplicate(true)
		else:
			_cargar_banco_predeterminado()
	else:
		_cargar_banco_predeterminado()

	_iniciar_partida()

## El marco llama esto al salir o agotar el tiempo: frena spawns y deja de penalizar.
func detener_partida() -> void:
	juego_activo = false
	if spawn_timer:
		spawn_timer.stop()

func _unhandled_input(event: InputEvent) -> void:
	if not juego_activo: return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_procesar_clic_pantalla(event.position)

	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
		if estado_actual_camara == EstadoCamara.MICRO:
			_volver_a_vista_macro()

# --- CAMARA ---

func _enfocar_rack(rack_node: Node3D) -> void:
	var focus_marker = rack_node.find_child("CameraFocus", true, false) as Marker3D
	if not focus_marker or not camara: return

	estado_actual_camara = EstadoCamara.MICRO
	rack_enfocado = rack_node as RackServer
	if rack_enfocado:
		rack_enfocado.set_panel_visible(true)

	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camara, "global_position", focus_marker.global_position, 0.5)
	tween.tween_property(camara, "global_rotation", focus_marker.global_rotation, 0.5)

func _volver_a_vista_macro() -> void:
	if not camara: return

	estado_actual_camara = EstadoCamara.MACRO
	if rack_enfocado:
		rack_enfocado.set_panel_visible(false)
	rack_enfocado = null

	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camara, "global_position", cam_pos_macro, 0.5)
	tween.tween_property(camara, "global_rotation", cam_rot_macro, 0.5)

# --- RAYCAST ---

func _procesar_clic_pantalla(screen_pos: Vector2) -> void:
	if not camara: return

	var ray_origin = camara.project_ray_origin(screen_pos)
	var ray_end = ray_origin + camara.project_ray_normal(screen_pos) * 1000.0

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result = space_state.intersect_ray(query)

	if result:
		var collider = result.collider
		if collider is ThreatProjectile:
			_mitigar_amenaza(collider)
			return

		var rack_padre = _buscar_rack_padre(collider)
		if rack_padre:
			if estado_actual_camara == EstadoCamara.MACRO:
				_enfocar_rack(rack_padre)
			else:
				_parchear_rack_actual(rack_padre)

func _buscar_rack_padre(node: Node) -> Node3D:
	var actual: Node = node
	while actual and actual != self:
		if actual is RackServer or actual in racks_array:
			return actual as Node3D
		actual = actual.get_parent()
	return null

# --- LÓGICA DE GAMEPLAY ---

func _on_spawn_timer_timeout() -> void:
	if not juego_activo: return

	if banco_amenazas.is_empty() or not amenaza_scene:
		spawn_timer.stop()
		return

	# Extrae la siguiente amenaza (pop_front para respetar el orden de la oleada)
	var data_amenaza = banco_amenazas.pop_front()
	var idx_target = data_amenaza.get("rack_target", 0) % max(1, racks_array.size())

	var rack_destino = racks_array[idx_target]
	var spawn_node = spawn_points.get_child(idx_target) if spawn_points and idx_target < spawn_points.get_child_count() else null

	var pos_origen = spawn_node.global_position if spawn_node else Vector3(0, 0, 2)
	var pos_destino = rack_destino.global_position

	var velocidad = data_amenaza.get("velocidad", 1.0) * velocidad_amenazas_base
	data_amenaza["velocidad"] = velocidad

	var nueva_amenaza = amenaza_scene.instantiate() as ThreatProjectile
	threats_container.add_child(nueva_amenaza)
	nueva_amenaza.setup(data_amenaza, pos_origen, pos_destino)
	nueva_amenaza.objetivo_alcanzado.connect(_on_amenaza_impacto)

func _mitigar_amenaza(amenaza: ThreatProjectile) -> void:
	puntos_actuales += puntos_por_acierto
	_emitir_puntos()

	var rack_idx = amenaza.rack_objetivo_index
	if rack_idx < racks_array.size():
		var rack = racks_array[rack_idx]
		if rack is RackServer:
			rack.actualizar_led_estado(RackServer.EstadoRack.ESTABLE)

	amenaza.destruir_con_animacion()
	_verificar_progreso_oleada()

func _parchear_rack_actual(rack: Node3D) -> void:
	var rack_idx = racks_array.find(rack)
	for child in threats_container.get_children():
		if child is ThreatProjectile and child.rack_objetivo_index == rack_idx:
			_mitigar_amenaza(child)
			return

	if rack is RackServer:
		var barra_patch = rack.find_child("PatchProgressBar", true, false) as ProgressBar
		if barra_patch:
			barra_patch.value = clampf(barra_patch.value + 25.0, 0.0, 100.0)

func _on_amenaza_impacto(amenaza: ThreatProjectile) -> void:
	puntos_actuales = max(0, puntos_actuales - penalizacion_error)
	_emitir_puntos()

	# Animación de sacudida + LED rojo en el rack impactado
	var idx = amenaza.rack_objetivo_index
	if idx < racks_array.size():
		var rack = racks_array[idx]
		if rack is RackServer:
			rack.actualizar_led_estado(RackServer.EstadoRack.INFECTADO)
		_animar_impacto_rack(rack)

	amenaza.queue_free()
	_verificar_progreso_oleada()

func _animar_impacto_rack(rack: Node3D) -> void:
	var tween = create_tween().set_trans(Tween.TRANS_BOUNCE)
	var pos_original = rack.position
	tween.tween_property(rack, "position", pos_original + Vector3(0.05, 0, 0), 0.05)
	tween.tween_property(rack, "position", pos_original - Vector3(0.05, 0, 0), 0.05)
	tween.tween_property(rack, "position", pos_original, 0.05)

# --- SLA ---

func _contar_puertos_cerrados() -> int:
	var cerrados := 0
	for rack in racks_array:
		if rack is RackServer:
			for abierto in rack.puertos_estado.values():
				if not abierto:
					cerrados += 1
	return cerrados

func _actualizar_penalizacion_sla(delta: float) -> void:
	if not juego_activo: return

	var puertos_cerrados := _contar_puertos_cerrados()
	if puertos_cerrados == 0: return

	# El SLA cae 2 puntos/seg por cada puerto cerrado/bloqueado
	sla_uptime = max(0.0, sla_uptime - 2.0 * delta * puertos_cerrados)

	# Se descuentan puntos cada vez que se acumula al menos 1 entero
	_sla_acumulador += 2.0 * delta * puertos_cerrados
	if int(_sla_acumulador) >= 1:
		var perdida := int(_sla_acumulador)
		_sla_acumulador -= perdida
		puntos_actuales = max(0, puntos_actuales - perdida)
		_emitir_puntos()

func _verificar_progreso_oleada() -> void:
	amenazas_procesadas += 1
	if banco_amenazas.is_empty() and threats_container.get_child_count() <= 1:
		juego_activo = false
		spawn_timer.stop()
		print("¡Minijuego Completado! Puntuación final: ", puntos_actuales)
		minijuego_completado.emit(puntos_actuales)

func _emitir_puntos() -> void:
	if has_node("/root/EventBus"):
		var bus = get_node("/root/EventBus")
		if bus.has_signal("puntos_actualizados"):
			bus.puntos_actualizados.emit(puntos_actuales)

func _cargar_banco_predeterminado() -> void:
	var nivel_data = load("res://scripts/data/soc_levels/nivel_1.tres") as NivelSOCDefenderData
	if nivel_data:
		puntos_por_acierto = nivel_data.puntos_por_acierto
		penalizacion_error = nivel_data.penalizacion_error
		velocidad_amenazas_base = nivel_data.velocidad_amenazas_base
		tiempo_entre_amenazas = nivel_data.tiempo_entre_amenazas
		banco_amenazas = nivel_data.lista_amenazas.duplicate(true)
	else:
		banco_amenazas = [
			{"etiqueta": "CVE-2026-3142 [Port 80]", "tipo": 0, "rack_target": 0, "puerto": 80, "velocidad": 1.2},
			{"etiqueta": "SYN FLOOD [Port 443]", "tipo": 1, "rack_target": 1, "puerto": 443, "velocidad": 2.0},
			{"etiqueta": "WORM_RANSOMWARE", "tipo": 2, "rack_target": 2, "puerto": 22, "velocidad": 1.0},
			{"etiqueta": "RDP EXPLOIT [Port 3389]", "tipo": 0, "rack_target": 3, "puerto": 3389, "velocidad": 1.5}
		]

func _limpiar_escena() -> void:
	if threats_container:
		for child in threats_container.get_children():
			child.queue_free()
