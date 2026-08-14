# res://scripts/minigames/infrastructure_rush/minigame_controller.gd
extends Node3D

## Minijuego 3D "Infrastructure Hardening & Topology Rush".
## El jugador cablea la topología requerida y/o bastiona los nodos antes de
## lanzar una auditoría (TEST). Tres fases configurables desde el recurso.
## Contrato del marco: signal minijuego_completado(puntos), inicializar_minijuego(),
## detener_partida(). Emite EventBus.puntos_actualizados.

signal minijuego_completado(puntos: int)

enum EstadoCamara { MACRO, MICRO }

const FASE_TOPOLOGIA: int = 0
const FASE_BASTIONADO: int = 1
const FASE_INTEGRADO: int = 2

const FONT_ORBITRON: String = "res://assets/fonts/Orbitron-Black.ttf"
const DEFAULT_NIVEL_PATH: String = "res://scripts/data/topologia_levels/nivel_3_integrado.tres"

const CameraControllerScript := preload("res://scripts/minigames/infrastructure_rush/camera_controller.gd")
const TopologyManagerScript := preload("res://scripts/minigames/infrastructure_rush/topology_manager.gd")
const TrafficSimulatorScript := preload("res://scripts/minigames/infrastructure_rush/traffic_simulator.gd")

const COLOR_CABLE_OK := Color(0.2, 0.9, 0.4)
const COLOR_CABLE_ERROR := Color(1.0, 0.2, 0.2)
const COLOR_OK := Color(0.2, 0.95, 0.4)
const COLOR_FAIL := Color(1.0, 0.3, 0.3)
const COLOR_ACTIVO := Color(0.0, 1.0, 0.7)

# Parámetros del nivel (fallback + hidratables)
var fase: int = FASE_INTEGRADO
var dispositivos_data: Array[Dictionary] = []
var conexiones_requeridas: Array[Dictionary] = []
var tiempo_limite: float = 120.0
var puntos_por_acierto: int = 100
var penalizacion_error: int = 25
var intentos_test: int = 3
var intentos_total: int = 3
var puntos_cable_correcto: int = 200
var puntos_nodo_perfecto: int = 150
var puntos_bonus_por_segundo: int = 10
var penalizacion_segmentacion: int = 100
var penalizacion_test: int = 150
var velocidad_test: float = 2.0

# Estado del juego
var estado_camara: EstadoCamara = EstadoCamara.MACRO
var puntos_actuales: int = 0
var partida_activa: bool = false
var partida_terminada: bool = false
var _controlado_por_frame: bool = false
var _test_en_curso: bool = false
var _tiempo_restante: float = 0.0
var _seleccion_actual: String = ""
var _panel_device_actual: String = ""
var _pendientes_ok: int = 0
var _pendientes_fail: int = 0
var _dispositivos_runtime: Dictionary = {}
var _cables: Array = []
var _conexiones_logradas: Dictionary = {}
var _last_click_device: String = ""
var _last_click_time: float = -10.0
var _feedback_tween: Tween

# Nodos de la escena (instanciados en el editor)
@onready var _camara_system: CameraControllerScript = $CameraSystem
@onready var _camara: Camera3D = $CameraSystem/MainCamera3D
@onready var _topology: TopologyManagerScript = $TopologyManager
@onready var _traffic: TrafficSimulatorScript = $TrafficSimulator
@onready var _game_timer: Timer = $GameTimer

# HUD (instanciado en el editor)
@onready var _lbl_fase: Label = $CanvasHUD/HUDMain/LblFase
@onready var _lbl_tiempo: Label = $CanvasHUD/HUDMain/LblTiempo
@onready var _lbl_puntos: Label = $CanvasHUD/HUDMain/LblPuntos
@onready var _lbl_intentos: Label = $CanvasHUD/HUDMain/LblIntentos
@onready var _lbl_estado: Label = $CanvasHUD/HUDMain/LblEstado
@onready var _lbl_feedback: Label = $CanvasHUD/HUDMain/LblFeedback
@onready var _btn_test: Button = $CanvasHUD/HUDMain/BtnLanzarTest
@onready var _panel_hardening: PanelContainer = $CanvasHUD/HUDMain/PanelHardening
@onready var _lbl_device_name: Label = $CanvasHUD/HUDMain/PanelHardening/VBox/LblDeviceName
@onready var _lbl_device_hint: Label = $CanvasHUD/HUDMain/PanelHardening/VBox/LblDeviceHint
@onready var _vbox_directivas: VBoxContainer = $CanvasHUD/HUDMain/PanelHardening/VBox/VBoxDirectivas
@onready var _modal_resultado: Control = $CanvasHUD/HUDMain/ModalResultado
@onready var _lbl_resultado: Label = $CanvasHUD/HUDMain/ModalResultado/Center/VBox/LblResultado

func _ready() -> void:
	_camara_system.configurar_vista_macro()

	# Fallback: si nadie llama a inicializar_minijuego(), arrancamos solos (F6)
	get_tree().create_timer(0.15).timeout.connect(func():
		if _controlado_por_frame:
			return
		_cargar_nivel_predeterminado()
		_cargar_escena_nivel()
		partida_activa = true
		_tiempo_restante = tiempo_limite
		_game_timer.start(tiempo_limite)
		_actualizar_hud()
		_mostrar_feedback(_texto_fase(), Color(0.4, 0.85, 1.0))
		_btn_test.disabled = false
	)

func _process(_delta: float) -> void:
	_actualizar_hud()

# --- HIDRATACIÓN ---

## PUNTO DE ENTRADA: llamado por MinigameFrame al iniciar la partida.
func inicializar_minijuego(data_nivel: NivelArcadeData) -> void:
	_controlado_por_frame = true
	_reset_estado_partida()

	if data_nivel is NivelTopologiaData:
		_aplicar_data(data_nivel as NivelTopologiaData)
	else:
		_cargar_nivel_predeterminado()

	_cargar_escena_nivel()
	partida_activa = true
	_tiempo_restante = tiempo_limite
	_game_timer.start(tiempo_limite)
	_actualizar_hud()
	_mostrar_feedback(_texto_fase(), Color(0.4, 0.85, 1.0))
	if _btn_test:
		_btn_test.disabled = false

## El marco llama esto al salir o agotar el tiempo: congela la partida.
func detener_partida() -> void:
	partida_activa = false
	if _game_timer:
		_game_timer.stop()
	if _btn_test:
		_btn_test.disabled = true

func _reset_estado_partida() -> void:
	puntos_actuales = 0
	partida_activa = false
	partida_terminada = false
	_test_en_curso = false
	_pendientes_ok = 0
	_pendientes_fail = 0
	_seleccion_actual = ""
	_panel_device_actual = ""
	_last_click_device = ""
	_last_click_time = -10.0
	if _traffic:
		_traffic.limpiar()

func _aplicar_data(nd: NivelTopologiaData) -> void:
	fase = clampi(nd.fase, 0, 2)
	tiempo_limite = nd.tiempo_limite
	puntos_por_acierto = nd.puntos_por_acierto
	penalizacion_error = nd.penalizacion_error
	puntos_cable_correcto = nd.puntos_cable_correcto
	puntos_nodo_perfecto = nd.puntos_nodo_perfecto
	puntos_bonus_por_segundo = nd.puntos_bonus_por_segundo
	penalizacion_segmentacion = nd.penalizacion_segmentacion
	penalizacion_test = nd.penalizacion_test
	intentos_test = maxi(1, nd.intentos_test)
	intentos_total = intentos_test
	velocidad_test = maxf(0.5, nd.velocidad_test)
	dispositivos_data = nd.dispositivos.duplicate(true)
	conexiones_requeridas = nd.conexiones_requeridas.duplicate(true)

func _cargar_nivel_predeterminado() -> void:
	var data := load(DEFAULT_NIVEL_PATH) as NivelTopologiaData
	if data:
		_aplicar_data(data)
		return
	fase = FASE_INTEGRADO
	tiempo_limite = 120.0
	intentos_test = 3
	intentos_total = 3
	velocidad_test = 2.0
	dispositivos_data = [
		{"id": "router_edge", "nombre": "ROUTER EDGE", "tipo": "router", "x": -4.0, "z": -2.0,
			"directivas": [
				{"id": "https", "etiqueta": "HTTPS habilitado (443)", "correcta": true, "estado": false},
				{"id": "ssh_root", "etiqueta": "SSH root deshabilitado", "correcta": true, "estado": true}
			]},
		{"id": "firewall", "nombre": "FIREWALL", "tipo": "firewall", "x": 0.0, "z": -2.5,
			"directivas": [
				{"id": "drop", "etiqueta": "Regla default DROP", "correcta": true, "estado": true},
				{"id": "icmp", "etiqueta": "ICMP desde WAN permitido", "correcta": false, "estado": false}
			]},
		{"id": "web", "nombre": "SERV. WEB", "tipo": "servidor", "x": 4.0, "z": -2.0,
			"directivas": [
				{"id": "patch", "etiqueta": "Parche CVE-2026-3142", "correcta": true, "estado": false}
			]},
		{"id": "db", "nombre": "SERV. DB", "tipo": "servidor", "x": 0.0, "z": 2.2,
			"directivas": [
				{"id": "cifrado", "etiqueta": "Cifrado en reposo", "correcta": true, "estado": true},
				{"id": "root", "etiqueta": "Conexiones root remotas", "correcta": false, "estado": true}
			]}
	]
	conexiones_requeridas = [
		{"origen": "router_edge", "destino": "firewall", "etiqueta": "EDGE→FW"},
		{"origen": "firewall", "destino": "web", "etiqueta": "FW→WEB"},
		{"origen": "firewall", "destino": "db", "etiqueta": "FW→DB"}
	]

func _cargar_escena_nivel() -> void:
	_cables.clear()
	_conexiones_logradas.clear()
	_dispositivos_runtime.clear()
	_topology.construir_dispositivos(dispositivos_data)

	for def in dispositivos_data:
		var id: String = str(def.get("id", ""))
		if id.is_empty():
			continue
		var perfecto := _es_nodo_perfecto(id)
		_dispositivos_runtime[id] = {
			"def": def,
			"hardened": perfecto,
			"hardened_inicial": perfecto,
			"perfecto_awarded": false
		}

	if fase == FASE_BASTIONADO:
		for req in conexiones_requeridas:
			var o: String = str(req.get("origen", ""))
			var d: String = str(req.get("destino", ""))
			var cable := _topology.crear_cable(o, d, COLOR_CABLE_OK)
			if cable:
				_cables.append({"origen": o, "destino": d, "node": cable, "correcto": true})

	_seleccion_actual = ""
	_panel_device_actual = ""
	if _panel_hardening:
		_panel_hardening.hide()
	estado_camara = EstadoCamara.MACRO
	if _camara_system:
		_camara_system.configurar_vista_macro()

# --- INPUT ---

func _unhandled_input(event: InputEvent) -> void:
	if not partida_activa or partida_terminada:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_procesar_clic(event.position)

	var es_escape_mouse: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed
	var es_escape_tecla: bool = event.is_action_pressed("ui_cancel")
	if (es_escape_mouse or es_escape_tecla) and estado_camara == EstadoCamara.MICRO:
		_volver_macro()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_lanzar_test()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var ids: Array = _topology.get_device_ids()
			var idx: int = event.keycode - KEY_1
			if idx < ids.size():
				_tecla_dispositivo(str(ids[idx]))

func _procesar_clic(screen_pos: Vector2) -> void:
	var result := _raycast(screen_pos)
	if result.is_empty():
		return
	var device_id := _buscar_dispositivo(result.get("collider"))
	if not device_id.is_empty():
		_on_dispositivo_clic(device_id)

func _raycast(screen_pos: Vector2) -> Dictionary:
	if not _camara:
		return {}
	var origin := _camara.project_ray_origin(screen_pos)
	var normal := _camara.project_ray_normal(screen_pos)
	var end := origin + normal * 100.0
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	return space.intersect_ray(query)

func _buscar_dispositivo(obj: Object) -> String:
	var node := obj as Node
	while node:
		if node is Node3D and _dispositivos_runtime.has(str(node.name)):
			return str(node.name)
		node = node.get_parent()
	return ""

func _tecla_dispositivo(id: String) -> void:
	if _test_en_curso or not partida_activa:
		return
	if estado_camara == EstadoCamara.MICRO:
		_volver_macro()
		return
	if fase == FASE_BASTIONADO:
		_enfocar_dispositivo(id)
		return
	if _seleccion_actual == id:
		_cancelar_seleccion()
		_enfocar_dispositivo(id)
	else:
		_cancelar_seleccion()
		_seleccion_actual = id
		_topology.destacar(id, true)
		if _lbl_estado:
			_lbl_estado.text = "CONECTA: %s → elige destino (2ª tecla = BASTIONAR)" % _nombre_dispositivo(id)
		_mostrar_feedback("NODO %s SELECCIONADO" % _nombre_dispositivo(id), COLOR_ACTIVO)

func _on_dispositivo_clic(id: String) -> void:
	if _test_en_curso or not partida_activa:
		return
	if estado_camara == EstadoCamara.MICRO:
		_volver_macro()
		return
	if fase == FASE_BASTIONADO:
		_enfocar_dispositivo(id)
		return

	var ahora := Time.get_ticks_msec()
	if id == _last_click_device and ahora - _last_click_time <= 450:
		_last_click_device = ""
		_cancelar_seleccion()
		_enfocar_dispositivo(id)
		return
	_last_click_device = id
	_last_click_time = ahora

	if _seleccion_actual.is_empty():
		_seleccion_actual = id
		_topology.destacar(id, true)
		if _lbl_estado:
			_lbl_estado.text = "CONECTA: %s → elige destino (doble clic = BASTIONAR)" % _nombre_dispositivo(id)
		_mostrar_feedback("NODO %s SELECCIONADO" % _nombre_dispositivo(id), COLOR_ACTIVO)
	elif _seleccion_actual == id:
		_cancelar_seleccion()
	else:
		var a: String = _seleccion_actual
		_cancelar_seleccion()
		_intentar_conexion(a, id)

func _cancelar_seleccion() -> void:
	if not _seleccion_actual.is_empty():
		_topology.destacar(_seleccion_actual, false)
	_seleccion_actual = ""
	if _lbl_estado:
		_lbl_estado.text = ""

# --- TOPOLOGÍA: CABLES ---

func _intentar_conexion(a: String, b: String) -> void:
	if _topology.hay_cable(a, b):
		_mostrar_feedback("YA HAY CABLE ENTRE AMBOS NODOS", Color(0.95, 0.9, 0.4))
		return

	var requerida := _es_conexion_requerida(a, b)
	if requerida:
		var cable := _topology.crear_cable(a, b, COLOR_CABLE_OK)
		if cable:
			_cables.append({"origen": a, "destino": b, "node": cable, "correcto": true})
		var par := _clave_par(a, b)
		if not _conexiones_logradas.has(par):
			_conexiones_logradas[par] = true
			puntos_actuales += puntos_cable_correcto
			_mostrar_feedback("TOPOLOGÍA CORRECTA · %s ↔ %s · +%d PTS" % [_nombre_dispositivo(a), _nombre_dispositivo(b), puntos_cable_correcto], COLOR_OK)
			_emitir_puntos()
		else:
			_mostrar_feedback("TOPOLOGÍA CORRECTA · %s ↔ %s" % [_nombre_dispositivo(a), _nombre_dispositivo(b)], COLOR_OK)
	else:
		var cable := _topology.crear_cable(a, b, COLOR_CABLE_ERROR)
		if cable:
			_cables.append({"origen": a, "destino": b, "node": cable, "correcto": false})
		puntos_actuales = maxi(0, puntos_actuales - penalizacion_segmentacion)
		_mostrar_feedback("ERROR DE SEGMENTACIÓN · %s ↔ %s · -%d PTS" % [_nombre_dispositivo(a), _nombre_dispositivo(b), penalizacion_segmentacion], COLOR_FAIL)
		_emitir_puntos()
		if cable:
			get_tree().create_timer(0.9).timeout.connect(func():
				if is_instance_valid(cable):
					cable.queue_free()
			)
	_actualizar_hud()

func _es_conexion_requerida(a: String, b: String) -> bool:
	for req in conexiones_requeridas:
		var o: String = str(req.get("origen", ""))
		var d: String = str(req.get("destino", ""))
		if (o == a and d == b) or (o == b and d == a):
			return true
	return false

func _clave_par(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]

# --- BASTIONADO ---

func _enfocar_dispositivo(id: String) -> void:
	if _test_en_curso or not partida_activa:
		return
	estado_camara = EstadoCamara.MICRO
	_panel_device_actual = id
	_cancelar_seleccion()
	var focus := _topology.get_focus_marker(id)
	if _camara_system:
		_camara_system.enfocar_objetivo(focus)
	_abrir_panel(id)

func _volver_macro() -> void:
	estado_camara = EstadoCamara.MACRO
	_panel_device_actual = ""
	if _camara_system:
		_camara_system.volver_a_macro()
	if _panel_hardening:
		_panel_hardening.hide()

func _abrir_panel(id: String) -> void:
	if not _dispositivos_runtime.has(id):
		return
	if _lbl_device_name:
		_lbl_device_name.text = "◈ %s" % _nombre_dispositivo(id)
	for child in _vbox_directivas.get_children():
		child.queue_free()
	var def: Dictionary = _dispositivos_runtime[id]["def"]
	for dir in def.get("directivas", []):
		var cb := CheckButton.new()
		cb.text = str(dir.get("etiqueta", "Directiva"))
		cb.button_pressed = bool(dir.get("estado", false))
		cb.add_theme_font_override("font", load(FONT_ORBITRON))
		cb.add_theme_font_size_override("font_size", 15)
		cb.toggled.connect(func(pressed: bool, did: String = str(dir.get("id", ""))):
			_on_directiva_toggled(id, did, pressed)
		)
		_vbox_directivas.add_child(cb)
	_actualizar_panel_hint(id)
	_panel_hardening.show()

func _on_directiva_toggled(device_id: String, directiva_id: String, pressed: bool) -> void:
	if not _dispositivos_runtime.has(device_id):
		return
	var def: Dictionary = _dispositivos_runtime[device_id]["def"]
	for dir in def.get("directivas", []):
		if str(dir.get("id", "")) == directiva_id:
			dir["estado"] = pressed
	var perfecto := _es_nodo_perfecto(device_id)
	_dispositivos_runtime[device_id]["hardened"] = perfecto
	_actualizar_panel_hint(device_id)
	if perfecto and not _dispositivos_runtime[device_id]["perfecto_awarded"] and not _dispositivos_runtime[device_id]["hardened_inicial"]:
		_dispositivos_runtime[device_id]["perfecto_awarded"] = true
		puntos_actuales += puntos_nodo_perfecto
		_mostrar_feedback("BASTIONADO PERFECTO · %s · +%d PTS" % [_nombre_dispositivo(device_id), puntos_nodo_perfecto], COLOR_OK)
		_emitir_puntos()
	_actualizar_hud()

func _actualizar_panel_hint(id: String) -> void:
	if not _lbl_device_hint:
		return
	var perfecto := _es_nodo_perfecto(id)
	_lbl_device_hint.text = "ESTADO: BASTIONADO OK" if perfecto else "ESTADO: INCOMPLETO"
	_lbl_device_hint.add_theme_color_override("font_color", COLOR_OK if perfecto else Color(1.0, 0.8, 0.2))

func _es_nodo_perfecto(id: String) -> bool:
	if not _dispositivos_runtime.has(id):
		return false
	for dir in _dispositivos_runtime[id]["def"].get("directivas", []):
		if bool(dir.get("estado", false)) != bool(dir.get("correcta", false)):
			return false
	return true

func _nombre_dispositivo(id: String) -> String:
	if _dispositivos_runtime.has(id):
		return str(_dispositivos_runtime[id]["def"].get("nombre", id))
	return id

# --- AUDITORÍA / TEST ---

func _lanzar_test() -> void:
	if not partida_activa or partida_terminada or _test_en_curso:
		return

	var fallos: Array[Dictionary] = []
	for req in conexiones_requeridas:
		var o: String = str(req.get("origen", ""))
		var d: String = str(req.get("destino", ""))
		var cable_ok: bool = _topology.hay_cable(o, d)
		var hardening_ok: bool = _es_nodo_perfecto(o) and _es_nodo_perfecto(d)
		if not cable_ok or not hardening_ok:
			fallos.append({"origen": o, "destino": d, "cable": cable_ok, "hardening": hardening_ok})

	_test_en_curso = true
	if _btn_test:
		_btn_test.disabled = true
	_traffic.limpiar()

	if fallos.is_empty():
		if conexiones_requeridas.is_empty():
			_test_en_curso = false
			_completar(true)
			return
		_pendientes_ok = conexiones_requeridas.size()
		for req in conexiones_requeridas:
			var a: Vector3 = _topology.get_posicion(str(req.get("origen", "")))
			var b: Vector3 = _topology.get_posicion(str(req.get("destino", "")))
			var dur: float = a.distance_to(b) / velocidad_test
			_traffic.crear_paquete(a, b, true, str(req.get("etiqueta", "TEST OK")), dur)
		_mostrar_feedback("AUDITANDO TOPOLOGÍA...", Color(0.6, 0.85, 1.0))
	else:
		_pendientes_fail = fallos.size()
		for f in fallos:
			var a: Vector3 = _topology.get_posicion(str(f["origen"]))
			var b: Vector3 = _topology.get_posicion(str(f["destino"]))
			var dur: float = a.distance_to(b) / velocidad_test
			var motivo: String = "CABLE" if not bool(f["cable"]) else "HARDENING"
			_traffic.crear_paquete(a, b, false, "FALLO %s" % motivo, dur)
		_mostrar_feedback("TEST FALLA · CORRIGE Y REINTENTA", COLOR_FAIL)

func _on_paquete_resuelto(ok: bool) -> void:
	if partida_terminada:
		return
	if ok:
		_pendientes_ok = maxi(0, _pendientes_ok - 1)
		if _pendientes_ok <= 0 and _test_en_curso:
			_test_en_curso = false
			_completar(true)
	else:
		_pendientes_fail = maxi(0, _pendientes_fail - 1)
		if _pendientes_fail <= 0 and _test_en_curso:
			_test_en_curso = false
			_aplicar_fallo_test()

func _aplicar_fallo_test() -> void:
	intentos_test = maxi(0, intentos_test - 1)
	puntos_actuales = maxi(0, puntos_actuales - penalizacion_test)
	_actualizar_hud()
	_emitir_puntos()
	if _btn_test:
		_btn_test.disabled = false
	_mostrar_feedback("TEST FALLIDO · -%d PTS · AUDITORÍAS %d/%d" % [penalizacion_test, intentos_test, intentos_total], COLOR_FAIL)
	if intentos_test <= 0:
		_completar(false, "SIN AUDITORÍAS RESTANTES")

# --- CIERRE ---

func _on_tiempo_agotado() -> void:
	if partida_terminada:
		return
	_completar(false, "TIEMPO AGOTADO")

func _completar(ganado: bool, motivo: String = "") -> void:
	if partida_terminada:
		return
	partida_terminada = true
	partida_activa = false
	_test_en_curso = false
	var tiempo_restante_al_fin: float = _game_timer.time_left if _game_timer else 0.0
	if _game_timer:
		_game_timer.stop()
	if _btn_test:
		_btn_test.disabled = true

	if ganado:
		var bono: int = int(ceil(maxf(0.0, tiempo_restante_al_fin))) * puntos_bonus_por_segundo
		puntos_actuales += bono
		_mostrar_feedback("AUDITORÍA SUPERADA · +%d PTS BONO" % bono, COLOR_OK)
	else:
		_mostrar_feedback(motivo if not motivo.is_empty() else "AUDITORÍA FALLIDA", COLOR_FAIL)

	_actualizar_hud()
	_emitir_puntos()
	if not _controlado_por_frame:
		_mostrar_resultado_local(ganado)
	minijuego_completado.emit(puntos_actuales)

func _mostrar_resultado_local(ganado: bool) -> void:
	if _controlado_por_frame or not _lbl_resultado:
		return
	_lbl_resultado.text = ("AUDITORÍA SUPERADA" if ganado else "AUDITORÍA FALLIDA") + "\nPUNTOS FINALES: %d" % puntos_actuales
	_lbl_resultado.add_theme_color_override("font_color", COLOR_OK if ganado else COLOR_FAIL)
	_modal_resultado.show()

func _on_reintentar_pressed() -> void:
	_modal_resultado.hide()
	if not _controlado_por_frame:
		get_tree().reload_current_scene()

func _emitir_puntos() -> void:
	if has_node("/root/EventBus"):
		var bus := get_node("/root/EventBus")
		if bus.has_signal("puntos_actualizados"):
			bus.puntos_actualizados.emit(puntos_actuales)

# --- HUD ---

func _mostrar_feedback(texto: String, color: Color) -> void:
	if not _lbl_feedback:
		return
	_lbl_feedback.text = texto
	_lbl_feedback.add_theme_color_override("font_color", color)
	_lbl_feedback.modulate.a = 1.0
	if _feedback_tween:
		_feedback_tween.kill()
	_feedback_tween = create_tween()
	_feedback_tween.tween_interval(1.5)
	_feedback_tween.tween_property(_lbl_feedback, "modulate:a", 0.0, 0.4)

func _actualizar_hud() -> void:
	if _lbl_puntos:
		_lbl_puntos.text = "PTS: %d" % puntos_actuales
	if _lbl_tiempo:
		var t: float = _game_timer.time_left if partida_activa else _tiempo_restante
		_lbl_tiempo.text = "⏱ %02d" % int(ceil(maxf(0.0, t)))
	if _lbl_fase:
		_lbl_fase.text = _texto_fase()
	if _lbl_intentos:
		_lbl_intentos.text = "AUDITORÍAS: %d/%d" % [intentos_test, intentos_total]

func _texto_fase() -> String:
	match fase:
		FASE_TOPOLOGIA:
			return "FASE · TOPOLOGÍA DE RED"
		FASE_BASTIONADO:
			return "FASE · BASTIONADO DE NODOS"
		_:
			return "FASE · INTEGRADO (RED + BASTIONADO)"
