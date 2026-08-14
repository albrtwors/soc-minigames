# res://scripts/minigames/soc_defender_3d/soc_defender_3d.gd
extends Node3D

signal minijuego_completado(puntos: int)

enum EstadoCamara { MACRO, MICRO }

@export var amenaza_scene: PackedScene

# Parámetros del nivel (Fallback + Hidratable)
var velocidad_amenazas_base: float = 1.5
var tiempo_entre_amenazas: float = 2.5
var tiempo_limite: float = 60.0
var puntos_por_acierto: int = 100
var penalizacion_error: int = 25
var pool_amenazas: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

# Recompensas específicas por contramedida
var puntos_bloqueo_firewall: int = 25
var puntos_disipar_ddos: int = 50
var puntos_resolucion_incidente: int = 150
var rafaga_ddos_proyectiles: int = 4
var preaviso_ransomware_seg: float = 2.0

# Estado del juego
var estado_actual_camara: EstadoCamara = EstadoCamara.MACRO
var rack_enfocado: RackServer = null
var puntos_actuales: int = 0
var racks_array: Array[Node3D] = []

# SLA (Acuerdo de Nivel de Servicio)
var sla_uptime: float = 100.0
var _sla_acumulador: float = 0.0

# Control de fin de juego
var juego_activo: bool = true
var _threats_activas: int = 0
var _spawns_pendientes: int = 0
var _inicio_listo: bool = false

# Transformación macro
var cam_pos_macro: Vector3
var cam_rot_macro: Vector3

# Atajos de teclado
const TECLA_RACK := {KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3}
const TECLA_PUERTO := {KEY_F1: 80, KEY_F2: 443, KEY_F3: 22, KEY_F4: 3389}

@onready var camara: Camera3D = $Camera3D
@onready var racks_container: Node3D = $RacksContainer
@onready var threats_container: Node3D = $ThreatsContainer
@onready var spawn_points: Node3D = $SpawnPoints
@onready var spawn_timer: Timer = Timer.new()
@onready var partida_timer: Timer = Timer.new()

# --- SIEM / Terminal ---
@onready var siem_panel: Control = $SIEMUI/SIEMPanel if has_node("SIEMUI/SIEMPanel") else null
@onready var log_terminal: RichTextLabel = $SIEMUI/SIEMPanel/Margin/VBox/LogTerminal if has_node("SIEMUI/SIEMPanel/Margin/VBox/LogTerminal") else null
@onready var btn_scrubbing_global: Button = $SIEMUI/SIEMPanel/Margin/VBox/Actions/BtnScrubGlobal if has_node("SIEMUI/SIEMPanel/Margin/VBox/Actions/BtnScrubGlobal") else null

var _log_lineas: int = 0

func _ready() -> void:
	if camara:
		cam_pos_macro = camara.global_position
		cam_rot_macro = camara.global_rotation

	_inicializar_timer()
	_indexar_racks()
	_conectar_ui_siem()
	_cargar_pool_predeterminado()

	get_tree().create_timer(0.2).timeout.connect(func():
		if _inicio_listo: return
		if pool_amenazas.is_empty():
			_cargar_pool_predeterminado()
		_iniciar_partida()
	)

	_log_siem("INFO", "SOC Defender online — 4 racks monitoreados")

func _process(delta: float) -> void:
	_actualizar_penalizacion_sla(delta)

func _inicializar_timer() -> void:
	add_child(spawn_timer)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(partida_timer)
	partida_timer.one_shot = true
	partida_timer.timeout.connect(_completar_partida)

func _indexar_racks() -> void:
	racks_array.clear()
	if racks_container:
		for child in racks_container.get_children():
			if child is Node3D:
				racks_array.append(child)
				if child is RackServer:
					var rack := child as RackServer
					rack.rack_aislado.connect(_on_rack_aislado)
					rack.rack_rollback_aplicado.connect(_on_rack_rollback)
					rack.rack_reconectado.connect(_on_rack_reconectado)
					rack.scrubbing_activado.connect(_on_scrubbing_rack)
					rack.parche_aplicado.connect(_on_parche_aplicado)

func _iniciar_partida() -> void:
	if _inicio_listo:
		return
	_inicio_listo = true
	juego_activo = true
	sla_uptime = 100.0
	_threats_activas = 0
	_spawns_pendientes = 0
	_limpiar_log_siem()

	for rack in racks_array:
		if rack is RackServer:
			(rack as RackServer).reiniciar_partida()

	spawn_timer.start(tiempo_entre_amenazas)
	partida_timer.start(tiempo_limite)
	_log_siem("INFO", "Partida iniciada — SLA 100%% · %ds · amenazas aleatorias (pool de %d)" % [int(tiempo_limite), pool_amenazas.size()])

## PUNTO DE ENTRADA: Hidratación desde NivelArcadeData / NivelSOCDefenderData
func inicializar_minijuego(data_nivel: NivelArcadeData) -> void:
	puntos_actuales = 0
	_limpiar_escena()
	_volver_a_vista_macro()

	if data_nivel:
		puntos_por_acierto = data_nivel.puntos_por_acierto
		penalizacion_error = data_nivel.penalizacion_error
		tiempo_limite = data_nivel.tiempo_limite
		if data_nivel is NivelSOCDefenderData:
			var datos_soc := data_nivel as NivelSOCDefenderData
			velocidad_amenazas_base = datos_soc.velocidad_amenazas_base
			tiempo_entre_amenazas = datos_soc.tiempo_entre_amenazas
			pool_amenazas = datos_soc.pool_amenazas.duplicate(true)
		else:
			_cargar_pool_predeterminado()
	else:
		_cargar_pool_predeterminado()

	_inicio_listo = false
	_iniciar_partida()

## El marco llama esto al salir o agotar el tiempo: frena spawns y deja de penalizar.
func detener_partida() -> void:
	juego_activo = false
	if spawn_timer:
		spawn_timer.stop()
	if partida_timer:
		partida_timer.stop()

func _unhandled_input(event: InputEvent) -> void:
	if not juego_activo: return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_procesar_clic_pantalla(event.position)

	var es_escape_mouse: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed
	var es_escape_tecla: bool = event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo)
	if (es_escape_mouse or es_escape_tecla) and estado_actual_camara == EstadoCamara.MICRO:
		_volver_a_vista_macro()

	if event is InputEventKey and event.pressed and not event.echo:
		if TECLA_RACK.has(event.keycode):
			var idx: int = TECLA_RACK[event.keycode]
			if idx < racks_array.size():
				_enfocar_rack(racks_array[idx])
		elif TECLA_PUERTO.has(event.keycode) and estado_actual_camara == EstadoCamara.MICRO and rack_enfocado:
			_alternar_puerto_rack(rack_enfocado, TECLA_PUERTO[event.keycode])

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

	if pool_amenazas.is_empty() or not amenaza_scene:
		return

	var data_amenaza = _elegir_amenaza_aleatoria()
	var idx_target: int = int(data_amenaza.get("rack_target", 0)) % maxi(1, racks_array.size())

	var rack_destino = racks_array[idx_target]
	var spawn_node = spawn_points.get_child(idx_target) if spawn_points and idx_target < spawn_points.get_child_count() else null

	var pos_origen = spawn_node.global_position if spawn_node else Vector3(0, 0, 2)
	var pos_destino = rack_destino.global_position
	var velocidad = float(data_amenaza.get("velocidad", 1.0)) * velocidad_amenazas_base * _rng.randf_range(0.9, 1.15)
	var tipo = int(data_amenaza.get("tipo", ThreatProjectile.TipoAmenaza.EXPLOIT_CVE))

	if tipo == ThreatProjectile.TipoAmenaza.DDOS:
		_espawnear_rafaga_ddos(data_amenaza, rack_destino, pos_origen, pos_destino, velocidad)
	elif tipo == ThreatProjectile.TipoAmenaza.RANSOMWARE:
		_espawnear_ransomware_con_preaviso(data_amenaza, rack_destino, pos_origen, pos_destino, velocidad)
	else:
		var proj := _instanciar_proyectil(data_amenaza, pos_origen, pos_destino, velocidad)
		_log_siem("WARN", "Exploit %s en ruta -> Rack %d [Port %d]" % [proj.id_amenaza, idx_target + 1, proj.puerto_objetivo])
		_encender_led_ataque(rack_destino)

## Elige un ataque al azar del pool y le asigna un rack (carril) aleatorio.
func _elegir_amenaza_aleatoria() -> Dictionary:
	var plantilla: Dictionary = pool_amenazas[_rng.randi_range(0, pool_amenazas.size() - 1)]
	var datos := plantilla.duplicate(true)
	datos["rack_target"] = _rng.randi_range(0, racks_array.size() - 1)
	return datos

func _instanciar_proyectil(data: Dictionary, pos_origen: Vector3, pos_destino: Vector3, velocidad: float) -> ThreatProjectile:
	data["velocidad"] = velocidad
	var nueva = amenaza_scene.instantiate() as ThreatProjectile
	threats_container.add_child(nueva)
	nueva.setup(data, pos_origen, pos_destino)
	nueva.objetivo_alcanzado.connect(_on_amenaza_impacto)
	_threats_activas += 1
	return nueva

## DDoS: ráfaga de N proyectiles que NO se destruye con clic — requiere Scrubbing Center.
func _espawnear_rafaga_ddos(data: Dictionary, rack_destino: Node3D, pos_origen: Vector3, pos_destino: Vector3, velocidad: float) -> void:
	var idx_target: int = int(data.get("rack_target", 0)) % maxi(1, racks_array.size())
	var rafaga_id := "ddos_rack_%d" % idx_target
	var puerto: int = int(data.get("puerto", 443))
	var seed_random := RandomNumberGenerator.new()
	seed_random.seed = Time.get_ticks_msec()

	for i in range(rafaga_ddos_proyectiles):
		var data2 := data.duplicate()
		var offset := Vector3(seed_random.randf_range(-0.4, 0.4), seed_random.randf_range(-0.15, 0.25), seed_random.randf_range(-0.4, 0.4))
		var proj := _instanciar_proyectil(data2, pos_origen + offset, pos_destino + offset * 0.15, velocidad * seed_random.randf_range(0.9, 1.1))
		proj.es_parte_de_rafaga = true
		proj.rafaga_id = rafaga_id

	_log_siem("CRIT", "Ráfaga DDoS (x%d) en ruta -> Rack %d [Port %d]. Activa SCRUBBING CENTER." % [rafaga_ddos_proyectiles, idx_target + 1, puerto])
	_flash_siem_alerta()
	_encender_led_ataque(rack_destino)

## Ransomware: preaviso en la terminal 2s antes del lanzamiento real.
func _espawnear_ransomware_con_preaviso(data: Dictionary, rack_destino: Node3D, pos_origen: Vector3, pos_destino: Vector3, velocidad: float) -> void:
	var idx_target: int = int(data.get("rack_target", 0)) % maxi(1, racks_array.size())
	_log_siem("ALERT", "Movimiento lateral sospechoso detectado -> Target: Rack %d" % (idx_target + 1))
	_flash_siem_alerta()

	_spawns_pendientes += 1
	get_tree().create_timer(preaviso_ransomware_seg).timeout.connect(func():
		_spawns_pendientes = max(0, _spawns_pendientes - 1)
		if not is_instance_valid(self) or not juego_activo:
			return
		var proj := _instanciar_proyectil(data, pos_origen, pos_destino, velocidad)
		_log_siem("CRIT", "Ransomware %s lanzado -> Rack %d [Port %d]. Si impacta: Aísla VLAN." % [proj.id_amenaza, idx_target + 1, proj.puerto_objetivo])
		_encender_led_ataque(rack_destino)
	)

func _mitigar_amenaza(amenaza: ThreatProjectile) -> void:
	if amenaza.alcanzado:
		return

	if amenaza.tipo_amenaza == ThreatProjectile.TipoAmenaza.DDOS:
		_log_siem("WARN", "DDoS no se neutraliza con clic — usa SCRUBBING CENTER (Rack %d)" % (amenaza.rack_objetivo_index + 1))
		_flash_siem_alerta()
		return

	puntos_actuales += puntos_por_acierto
	_emitir_puntos()
	_log_siem("OK", "Contramedida manual: %s neutralizado en vuelo (+%d pts)" % [amenaza.id_amenaza, puntos_por_acierto])

	var idx = amenaza.rack_objetivo_index
	if idx < racks_array.size():
		var rack = racks_array[idx]
		if rack is RackServer:
			rack.actualizar_led_estado(RackServer.EstadoRack.ESTABLE)

	amenaza.destruir_con_animacion()
	_amenaza_resuelta()

func _parchear_rack_actual(rack: Node3D) -> void:
	if rack is RackServer:
		var r := rack as RackServer
		if not r.puede_operar():
			_log_siem("WARN", "Rack %d no operativo — controles bloqueados" % (r.rack_index + 1))
			return
		r.aplicar_parche()

func _on_amenaza_impacto(amenaza: ThreatProjectile) -> void:
	var idx = amenaza.rack_objetivo_index
	var rack: RackServer = racks_array[idx] if idx < racks_array.size() and racks_array[idx] is RackServer else null

	if rack:
		if rack.esta_aislado or rack.esta_infectado:
			_log_siem("INFO", "Amenaza %s anulada — Rack %d fuera de red" % [amenaza.id_amenaza, rack.rack_index + 1])
			amenaza.destruir_con_animacion()
			_amenaza_resuelta()
			return

		# 1. Escudo/Firewall: si el puerto objetivo está cerrado, el ataque rebota.
		if not rack.puertos_estado.get(amenaza.puerto_objetivo, true):
			_bloquear_por_firewall(amenaza, rack)
			return

		# 2. Exploit: un rack parcheado al 100% bloquea CVEs automáticamente.
		if amenaza.tipo_amenaza == ThreatProjectile.TipoAmenaza.EXPLOIT_CVE and _rack_parcheado(rack):
			puntos_actuales += puntos_bloqueo_firewall
			_emitir_puntos()
			_log_siem("FIREWALL", "Exploit bloqueado por parche al 100%% en Rack %d (+%d pts)" % [rack.rack_index + 1, puntos_bloqueo_firewall])
			amenaza.destruir_con_animacion()
			_amenaza_resuelta()
			return

		# 3. Ransomware: impacta -> infecta y bloquea el rack.
		if amenaza.tipo_amenaza == ThreatProjectile.TipoAmenaza.RANSOMWARE:
			_infectar_rack(rack, amenaza)
			amenaza.destruir_con_animacion()
			_amenaza_resuelta()
			return

	# Impacto sin contramedida: resta puntos y marca el rack como bajo ataque.
	puntos_actuales = max(0, puntos_actuales - penalizacion_error)
	_emitir_puntos()
	if rack:
		_log_siem("WARN", "Impacto sin mitigar en Rack %d [Port %d] (-%d pts)" % [rack.rack_index + 1, amenaza.puerto_objetivo, penalizacion_error])
		_animar_impacto_rack(rack)
		rack.actualizar_led_estado(RackServer.EstadoRack.BAJO_ATAQUE)
	else:
		_log_siem("WARN", "Impacto sin mitigar (-%d pts)" % penalizacion_error)

	amenaza.destruir_con_animacion()
	_amenaza_resuelta()

func _bloquear_por_firewall(amenaza: ThreatProjectile, rack: RackServer) -> void:
	puntos_actuales += puntos_bloqueo_firewall
	_emitir_puntos()
	_log_siem("FIREWALL", "Bloqueado por regla de firewall — Puerto %d cerrado en Rack %d (+%d pts)" % [amenaza.puerto_objetivo, rack.rack_index + 1, puntos_bloqueo_firewall])
	amenaza.destruir_bloqueado()
	rack.actualizar_led_estado(RackServer.EstadoRack.ESTABLE)
	_amenaza_resuelta()

func _infectar_rack(rack: RackServer, amenaza: ThreatProjectile) -> void:
	puntos_actuales = max(0, puntos_actuales - penalizacion_error)
	_emitir_puntos()
	rack.marcar_infectado()
	_animar_impacto_rack(rack)
	_log_siem("CRIT", "RANSOMWARE impactó en Rack %d — Controles BLOQUEADOS. Pulsa Aislar VLAN." % (rack.rack_index + 1))
	_flash_siem_alerta()

func _animar_impacto_rack(rack: Node3D) -> void:
	var tween = create_tween().set_trans(Tween.TRANS_BOUNCE)
	var pos_original = rack.position
	tween.tween_property(rack, "position", pos_original + Vector3(0.05, 0, 0), 0.05)
	tween.tween_property(rack, "position", pos_original - Vector3(0.05, 0, 0), 0.05)
	tween.tween_property(rack, "position", pos_original, 0.05)

# --- CONTAMEDIDAS: PATCH / SCRUBBING / INCIDENTES ---

func _rack_parcheado(rack: RackServer) -> bool:
	if not rack.panel_ui:
		return false
	var barra = rack.find_child("PatchProgressBar", true, false) as ProgressBar
	return barra != null and barra.value >= 100.0

func _on_parche_aplicado(rack: RackServer, progreso: int) -> void:
	if progreso >= 100:
		_log_siem("OK", "Parche desplegado al 100%% en Rack %d — Exploits CVE bloqueados" % (rack.rack_index + 1))
		var neutralizados := 0
		for child in threats_container.get_children():
			if child is ThreatProjectile and not (child as ThreatProjectile).alcanzado:
				var proj := child as ThreatProjectile
				if proj.tipo_amenaza == ThreatProjectile.TipoAmenaza.EXPLOIT_CVE and proj.rack_objetivo_index == rack.rack_index:
					puntos_actuales += puntos_bloqueo_firewall
					neutralizados += 1
					proj.destruir_con_animacion()
					_amenaza_resuelta()
		if neutralizados > 0:
			_emitir_puntos()
			_log_siem("OK", "%d exploit(s) neutralizado(s) por parche (+%d pts)" % [neutralizados, neutralizados * puntos_bloqueo_firewall])
	else:
		_log_siem("INFO", "Parche en Rack %d: %d%%" % [rack.rack_index + 1, progreso])

func _on_scrubbing_rack(rack: RackServer) -> void:
	_disipar_rafagas_rack(rack.rack_index)

func _disipar_rafagas_rack(rack_idx: int) -> void:
	var disipadas := 0
	var objetivo: String = "GLOBAL" if rack_idx < 0 else "Rack %d" % (rack_idx + 1)
	for child in threats_container.get_children():
		if child is ThreatProjectile and (child as ThreatProjectile).tipo_amenaza == ThreatProjectile.TipoAmenaza.DDOS:
			var proj := child as ThreatProjectile
			if proj.alcanzado:
				continue
			if rack_idx >= 0 and proj.rack_objetivo_index != rack_idx:
				continue
			puntos_actuales += puntos_disipar_ddos
			disipadas += 1
			proj.destruir_con_animacion()
			_amenaza_resuelta()

	if disipadas > 0:
		_emitir_puntos()
		_log_siem("OK", "Scrubbing disipó %d paquete(s) DDoS (%s) (+%d pts)" % [disipadas, objetivo, disipadas * puntos_disipar_ddos])
	else:
		_log_siem("INFO", "Scrubbing activado — no hay ráfagas DDoS activas (%s)" % objetivo)

func _on_rack_aislado(rack: RackServer) -> void:
	_log_siem("OK", "VLAN aislada en Rack %d — amenazas en vuelo anuladas" % (rack.rack_index + 1))
	for child in threats_container.get_children():
		if child is ThreatProjectile and not (child as ThreatProjectile).alcanzado:
			var proj := child as ThreatProjectile
			if proj.rack_objetivo_index == rack.rack_index:
				_log_siem("INFO", "Amenaza %s anulada (rack fuera de red)" % proj.id_amenaza)
				proj.destruir_con_animacion()
				_amenaza_resuelta()

func _on_rack_rollback(rack: RackServer) -> void:
	_log_siem("OK", "Backup restaurado en Rack %d — reconecta a la red." % (rack.rack_index + 1))

func _on_rack_reconectado(rack: RackServer) -> void:
	puntos_actuales += puntos_resolucion_incidente
	_emitir_puntos()
	_log_siem("OK", "Rack %d reconectado — Incidente resuelto (+%d pts)" % [rack.rack_index + 1, puntos_resolucion_incidente])

func _alternar_puerto_rack(rack: RackServer, puerto: int) -> void:
	if not rack or not rack.puede_operar():
		return
	var nombre := _nombre_puerto(puerto)
	var abierto := rack.alternar_puerto(puerto)
	if abierto:
		_log_siem("INFO", "Puerto %d/%s ABIERTO en Rack %d" % [puerto, nombre, rack.rack_index + 1])
	else:
		_log_siem("WARN", "Puerto %d/%s CERRADO en Rack %d por Operador" % [puerto, nombre, rack.rack_index + 1])

func _nombre_puerto(puerto: int) -> String:
	match puerto:
		80: return "HTTP"
		22: return "SSH"
		443: return "HTTPS"
		3389: return "RDP"
		_: return str(puerto)

func _encender_led_ataque(rack: Node3D) -> void:
	if rack is RackServer:
		(rack as RackServer).actualizar_led_estado(RackServer.EstadoRack.BAJO_ATAQUE)

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
	var racks_infectados := 0
	for rack in racks_array:
		if rack is RackServer and (rack as RackServer).esta_infectado:
			racks_infectados += 1

	# Puertos cerrados: -2 SLA/s cada uno. Rack infectado: -6 SLA/s (servicio caído).
	var tasa := 2.0 * puertos_cerrados + 6.0 * racks_infectados
	if tasa <= 0.0: return

	sla_uptime = max(0.0, sla_uptime - tasa * delta)

	# Se descuentan puntos cada vez que se acumula al menos 1 entero
	_sla_acumulador += tasa * delta
	if int(_sla_acumulador) >= 1:
		var perdida := int(_sla_acumulador)
		_sla_acumulador -= perdida
		puntos_actuales = max(0, puntos_actuales - perdida)
		_emitir_puntos()

# --- PROGRESO Y CIERRE ---

func _amenaza_resuelta() -> void:
	_threats_activas = max(0, _threats_activas - 1)

func _completar_partida() -> void:
	if not juego_activo: return
	juego_activo = false
	if spawn_timer:
		spawn_timer.stop()
	if partida_timer:
		partida_timer.stop()
	_log_siem("OK", "=== TIEMPO AGOTADO — Puntuación final: %d ===" % puntos_actuales)
	print("¡Minijuego Completado! Puntuación final: ", puntos_actuales)
	minijuego_completado.emit(puntos_actuales)

# --- SIEM / TERMINAL ---

func _conectar_ui_siem() -> void:
	if btn_scrubbing_global:
		btn_scrubbing_global.pressed.connect(func(): _disipar_rafagas_rack(-1))

func _log_siem(nivel: String, mensaje: String) -> void:
	if not log_terminal: return
	if _log_lineas > 250:
		log_terminal.clear()
		_log_lineas = 0
	var hora := Time.get_time_string_from_system()
	log_terminal.append_text("[color=%s][b]%s[/b][/color] %s  %s\n" % [_color_nivel(nivel), nivel, hora, mensaje])
	_log_lineas += 1

func _color_nivel(nivel: String) -> String:
	match nivel:
		"ALERT": return "#ff4d4d"
		"CRIT": return "#ff6b6b"
		"WARN": return "#ffd166"
		"OK": return "#7cf29c"
		"FIREWALL": return "#6ee7ff"
		_: return "#9fd4ff"

func _flash_siem_alerta() -> void:
	if not siem_panel: return
	siem_panel.modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(siem_panel, "modulate", Color.WHITE, 0.35)

func _limpiar_log_siem() -> void:
	if log_terminal:
		log_terminal.clear()
	_log_lineas = 0

func _emitir_puntos() -> void:
	if has_node("/root/EventBus"):
		var bus = get_node("/root/EventBus")
		if bus.has_signal("puntos_actualizados"):
			bus.puntos_actualizados.emit(puntos_actuales)

func _cargar_pool_predeterminado() -> void:
	var nivel_data = load("res://scripts/data/soc_levels/nivel_1.tres") as NivelSOCDefenderData
	if nivel_data:
		puntos_por_acierto = nivel_data.puntos_por_acierto
		penalizacion_error = nivel_data.penalizacion_error
		velocidad_amenazas_base = nivel_data.velocidad_amenazas_base
		tiempo_entre_amenazas = nivel_data.tiempo_entre_amenazas
		tiempo_limite = nivel_data.tiempo_limite
		pool_amenazas = nivel_data.pool_amenazas.duplicate(true)
	else:
		pool_amenazas = [
			{"etiqueta": "CVE-2026-3142 [Port 80]", "tipo": 0, "puerto": 80, "velocidad": 1.2},
			{"etiqueta": "SYN FLOOD [Port 443]", "tipo": 1, "puerto": 443, "velocidad": 2.0},
			{"etiqueta": "WORM_RANSOMWARE", "tipo": 2, "puerto": 22, "velocidad": 1.0},
			{"etiqueta": "RDP EXPLOIT [Port 3389]", "tipo": 0, "puerto": 3389, "velocidad": 1.5},
			{"etiqueta": "HTTP FLOOD [Port 80]", "tipo": 1, "puerto": 80, "velocidad": 1.7},
			{"etiqueta": "CVE-2025-10086 [Port 22]", "tipo": 0, "puerto": 22, "velocidad": 1.3}
		]

func _limpiar_escena() -> void:
	if threats_container:
		for child in threats_container.get_children():
			child.queue_free()
	_threats_activas = 0
	_spawns_pendientes = 0
