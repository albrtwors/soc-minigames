# res://scripts/minigames/log_stream_defender/log_stream_defender_3d.gd
extends Node3D

signal minijuego_completado(puntos: int)

enum TipoAccion { IGNORAR = 0, BLOQUEAR = 1, AISLAR = 2 }

const ESPACIO_ENTRE_CARRILES: float = 0.08
const Z_SPAWN: float = -0.17
const Z_LINEA_MIRA: float = 0.10
const INTERVALO_SPAWN: float = 0.9
const TIEMPO_STANDALONE: float = 30.0

@export var log_item_scene: PackedScene

# Parámetros del nivel con valores por defecto (Fallback)
var cantidad_carriles: int = 3
var velocidad_caida: float = 0.5
var puntos_por_acierto: int = 100
var penalizacion_error: int = 25
var tiempo_limite: float = 30.0
var banco_logs: Array[Dictionary] = []

# Estado del juego
var carril_seleccionado: int = 1
var puntos_actuales: int = 0
var posiciones_x_carriles: Array[float] = []
var logs_activos: Array[Node3D] = []

var _spawn_timer: Timer
var _controlado_por_frame: bool = false
var _partida_activa: bool = false
var _tiempo_restante: float = 0.0
var _indice_banco: int = 0

@onready var ui_overlay: Control = $UI_Overlay
@onready var lbl_score: Label = $UI_Overlay/ScorePanel/LblScore
@onready var lbl_carril: Label = $UI_Overlay/LanePanel/LblLane
@onready var feedback_overlay: PanelContainer = $UI_Overlay/FeedbackOverlay
@onready var lbl_feedback: Label = $UI_Overlay/FeedbackOverlay/LblFeedback

func _ready() -> void:
	_setup_camara_y_luz()
	_cargar_banco_predeterminado()
	_calcular_posiciones_carriles()
	_actualizar_posicion_mira()
	_conectar_ui()

	_spawn_timer = Timer.new()
	_spawn_timer.name = "SpawnTimer"
	_spawn_timer.wait_time = INTERVALO_SPAWN
	_spawn_timer.timeout.connect(_spawn_log)
	add_child(_spawn_timer)

	# Fallback: si nadie llama a inicializar_minijuego(), arrancamos solos (prueba F6)
	get_tree().create_timer(0.1).timeout.connect(func():
		if not _controlado_por_frame:
			_iniciar_partida_standalone()
	)

func _process(delta: float) -> void:
	if not _partida_activa:
		return

	if not _controlado_por_frame:
		_tiempo_restante -= delta
		if _tiempo_restante <= 0.0:
			_finalizar()
			return

	_procesar_input_teclado()

## Entrada por teclado. Funciona dentro del SubViewport porque se lee el
## estado global del Input singleton (mismo patrón que bullet_dodge).
func _procesar_input_teclado() -> void:
	if Input.is_action_just_pressed("ui_left"):
		_cambiar_carril(-1)
	if Input.is_action_just_pressed("ui_right"):
		_cambiar_carril(1)
	if InputMap.has_action("log_ignorar") and Input.is_action_just_pressed("log_ignorar"):
		procesar_accion(TipoAccion.IGNORAR)
	if InputMap.has_action("log_bloquear") and Input.is_action_just_pressed("log_bloquear"):
		procesar_accion(TipoAccion.BLOQUEAR)
	if InputMap.has_action("log_aislar") and Input.is_action_just_pressed("log_aislar"):
		procesar_accion(TipoAccion.AISLAR)

## PUNTO DE HIDRATACIÓN: llamado por MinigameFrame al iniciar la partida
func inicializar_minijuego(data_nivel: NivelArcadeData) -> void:
	_controlado_por_frame = true
	_partida_activa = true
	puntos_actuales = 0
	carril_seleccionado = 1
	_limpiar_logs()

	if data_nivel is NivelLogArcadeData:
		puntos_por_acierto = data_nivel.puntos_por_acierto
		penalizacion_error = data_nivel.penalizacion_error
		cantidad_carriles = max(1, data_nivel.cantidad_carriles)
		velocidad_caida = data_nivel.velocidad_caida
		tiempo_limite = data_nivel.tiempo_limite
		banco_logs = data_nivel.lista_logs.duplicate(true)
	else:
		_cargar_banco_predeterminado()

	_calcular_posiciones_carriles()
	_actualizar_posicion_mira()
	_spawn_timer.start()
	_actualizar_score_ui()
	_mostrar_feedback("PROTEGE EL STREAM", Color(0.3, 0.9, 1, 1))

func _iniciar_partida_standalone() -> void:
	_partida_activa = true
	_tiempo_restante = tiempo_limite if tiempo_limite > 0.0 else TIEMPO_STANDALONE
	_spawn_timer.start()
	_actualizar_score_ui()
	_actualizar_posicion_mira()
	_mostrar_feedback("MODO PRUEBA - %ds" % int(_tiempo_restante), Color(0.3, 0.9, 1, 1))

func _setup_camara_y_luz() -> void:
	var cam = $Camera3D if has_node("Camera3D") else null
	if cam:
		cam.position = Vector3(0, 0.4, 0)
		cam.rotation_degrees = Vector3(-90, 0, 0)
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 0.25
		cam.near = 0.2
		cam.far = 10.0
		cam.current = true

	var luz = $DirectionalLight3D if has_node("DirectionalLight3D") else null
	if luz:
		luz.position = Vector3(0, 5, 0)
		luz.rotation_degrees = Vector3(-90, 0, 0)

func _calcular_posiciones_carriles() -> void:
	posiciones_x_carriles.clear()
	var centro_offset = (cantidad_carriles - 1) * ESPACIO_ENTRE_CARRILES * 0.5
	for i in range(cantidad_carriles):
		var pos_x = (i * ESPACIO_ENTRE_CARRILES) - centro_offset
		posiciones_x_carriles.append(pos_x)
		_actualizar_marcador_spawn(i, pos_x)

func _actualizar_marcador_spawn(indice: int, pos_x: float) -> void:
	var spawn_points = $SpawnPoints if has_node("SpawnPoints") else null
	if not spawn_points:
		return
	var marker = spawn_points.get_node_or_null(str(indice))
	if marker:
		marker.position.x = pos_x
		marker.position.z = Z_SPAWN

func _cambiar_carril(direccion: int) -> void:
	carril_seleccionado = clampi(carril_seleccionado + direccion, 0, cantidad_carriles - 1)
	_actualizar_posicion_mira()

func _actualizar_posicion_mira() -> void:
	var mira = $TargetSelector if has_node("TargetSelector") else null
	if mira and not posiciones_x_carriles.is_empty():
		mira.position.x = posiciones_x_carriles[carril_seleccionado]
	if lbl_carril:
		lbl_carril.text = "CARRIL %d/%d" % [carril_seleccionado + 1, cantidad_carriles]

func _spawn_log() -> void:
	if not _partida_activa:
		return
	if not log_item_scene or banco_logs.is_empty():
		return

	var log_data: Dictionary = banco_logs[_indice_banco % banco_logs.size()]
	_indice_banco += 1

	var carril: int = randi_range(0, cantidad_carriles - 1)
	var pos_x: float = posiciones_x_carriles[carril]

	var log_item: Node3D = log_item_scene.instantiate()
	log_item.name = "LogItem"
	$LogsContainer.add_child(log_item)
	log_item.position = Vector3(pos_x, 0.0, Z_SPAWN)

	if log_item.has_method("setup"):
		log_item.setup(log_data.get("texto", ""), int(log_data.get("respuesta", 0)), velocidad_caida)
	if log_item.has_signal("log_perdido"):
		log_item.log_perdido.connect(_on_log_perdido)

	logs_activos.append(log_item)

func _on_log_perdido(log_item: Node3D) -> void:
	if not is_instance_valid(log_item) or not logs_activos.has(log_item):
		return
	logs_activos.erase(log_item)

	puntos_actuales = max(0, puntos_actuales - penalizacion_error)
	_mostrar_feedback("LOG PERDIDO -%d PTS" % penalizacion_error, Color(1.0, 0.6, 0.1, 1))
	_emitir_puntos()
	_actualizar_score_ui()
	log_item.queue_free()

## Evaluación: el log activo más cercano del carril seleccionado contra la acción.
## 0 = IGNORAR, 1 = BLOQUEAR IP, 2 = AISLAR HOST
func procesar_accion(tipo_accion: int) -> void:
	if not _partida_activa:
		return

	var log_objetivo: Node3D = _obtener_log_mas_cercano_en_carril(carril_seleccionado)
	if not log_objetivo:
		_mostrar_feedback("SIN LOG EN EL CARRIL", Color(0.55, 0.6, 0.65, 1))
		return

	var respuesta_esperada: int = log_objetivo.get("respuesta_correcta") if "respuesta_correcta" in log_objetivo else 0

	if tipo_accion == respuesta_esperada:
		puntos_actuales += puntos_por_acierto
		if log_objetivo.has_method("destruir_con_exito"):
			log_objetivo.destruir_con_exito()
		_mostrar_feedback("CORRECTO +%d PTS" % puntos_por_acierto, Color(0.2, 0.9, 0.3, 1))
	else:
		puntos_actuales = max(0, puntos_actuales - penalizacion_error)
		if log_objetivo.has_method("destruir_con_error"):
			log_objetivo.destruir_con_error()
		_mostrar_feedback("ERROR -%d PTS" % penalizacion_error, Color(1.0, 0.25, 0.25, 1))

	logs_activos.erase(log_objetivo)
	_emitir_puntos()
	_actualizar_score_ui()

func _obtener_log_mas_cercano_en_carril(carril: int) -> Node3D:
	if carril < 0 or carril >= posiciones_x_carriles.size():
		return null

	var target_x: float = posiciones_x_carriles[carril]
	var candidato: Node3D = null
	var mayor_z: float = -999.0

	for log_node in logs_activos:
		if not is_instance_valid(log_node):
			continue
		if "esta_procesado" in log_node and log_node.esta_procesado:
			continue
		if abs(log_node.position.x - target_x) < 0.01:
			if log_node.position.z > mayor_z:
				mayor_z = log_node.position.z
				candidato = log_node

	return candidato

func _mostrar_feedback(texto: String, color: Color) -> void:
	if not feedback_overlay or not lbl_feedback:
		return

	lbl_feedback.text = texto
	lbl_feedback.modulate = color

	feedback_overlay.modulate = Color(1, 1, 1, 0)
	feedback_overlay.scale = Vector2(0.7, 0.7)
	feedback_overlay.show()

	var tween_in = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween_in.set_parallel(true)
	tween_in.tween_property(feedback_overlay, "modulate", Color(1, 1, 1, 1), 0.3)
	tween_in.tween_property(feedback_overlay, "scale", Vector2(1, 1), 0.3)

	get_tree().create_timer(1.1).timeout.connect(func():
		if not feedback_overlay:
			return
		var tween_out = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		tween_out.set_parallel(true)
		tween_out.tween_property(feedback_overlay, "modulate", Color(1, 1, 1, 0), 0.25)
		tween_out.tween_property(feedback_overlay, "scale", Vector2(0.85, 0.85), 0.25)
		tween_out.finished.connect(func():
			if feedback_overlay:
				feedback_overlay.hide()
		)
	)

func _actualizar_score_ui() -> void:
	if lbl_score:
		lbl_score.text = "PTS: %d" % puntos_actuales

func _emitir_puntos() -> void:
	if has_node("/root/EventBus"):
		var bus = get_node("/root/EventBus")
		if bus.has_signal("puntos_actualizados"):
			bus.puntos_actualizados.emit(puntos_actuales)

func _finalizar() -> void:
	_partida_activa = false
	if _spawn_timer:
		_spawn_timer.stop()
	minijuego_completado.emit(puntos_actuales)

func _cargar_banco_predeterminado() -> void:
	var nivel_data = load("res://scripts/data/log_defender_levels/nivel_1.tres") as NivelLogArcadeData
	if nivel_data:
		puntos_por_acierto = nivel_data.puntos_por_acierto
		penalizacion_error = nivel_data.penalizacion_error
		cantidad_carriles = max(1, nivel_data.cantidad_carriles)
		velocidad_caida = nivel_data.velocidad_caida
		tiempo_limite = nivel_data.tiempo_limite
		banco_logs = nivel_data.lista_logs.duplicate(true)
	else:
		velocidad_caida = 0.5
		tiempo_limite = 30.0
		banco_logs = [
			{"texto": "GET /index.html 200 OK", "respuesta": 0},
			{"texto": "POST /login 401 [50 req/s]", "respuesta": 1},
			{"texto": "HOST_03 -> 185.220.x:4444 [RAT]", "respuesta": 2},
			{"texto": "GET /css/main.css 200 OK", "respuesta": 0},
			{"texto": "SSH root@10.0.0.5 [19 intentos]", "respuesta": 1},
			{"texto": "PID 4412 -> 45.155.204.x:53 [C2]", "respuesta": 2}
		]

func _limpiar_logs() -> void:
	var contenedor = $LogsContainer if has_node("LogsContainer") else self
	for child in contenedor.get_children():
		child.queue_free()
	logs_activos.clear()

func _conectar_ui() -> void:
	var btn_izq = ui_overlay.get_node_or_null("BottomControls/BtnIzquierda") as Button
	var btn_der = ui_overlay.get_node_or_null("BottomControls/BtnDerecha") as Button
	var btn_ignorar = ui_overlay.get_node_or_null("BottomControls/BtnIgnorar") as Button
	var btn_bloquear = ui_overlay.get_node_or_null("BottomControls/BtnBloquear") as Button
	var btn_aislar = ui_overlay.get_node_or_null("BottomControls/BtnAislar") as Button

	if btn_izq:
		btn_izq.pressed.connect(func(): _cambiar_carril(-1))
	if btn_der:
		btn_der.pressed.connect(func(): _cambiar_carril(1))
	if btn_ignorar:
		btn_ignorar.pressed.connect(func(): procesar_accion(TipoAccion.IGNORAR))
	if btn_bloquear:
		btn_bloquear.pressed.connect(func(): procesar_accion(TipoAccion.BLOQUEAR))
	if btn_aislar:
		btn_aislar.pressed.connect(func(): procesar_accion(TipoAccion.AISLAR))
