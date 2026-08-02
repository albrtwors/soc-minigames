# res://scripts/minigames/log_stream_defender/log_stream_defender_2d.gd
extends Control

signal minijuego_completado(puntos: int)

enum TipoAccion { IGNORAR = 0, BLOQUEAR = 1, AISLAR = 2 }

## Mapeo de coordenadas del mundo 3D original (Z) a la caída vertical 2D.
## Se conservan las constantes para mantener el ritmo temporal del nivel.
const Z_SPAWN: float = -0.17
const Z_LINEA_MIRA: float = 0.10
const Z_LIMITE: float = 0.19
const RANGO_CAIDA: float = Z_LIMITE - Z_SPAWN

const INTERVALO_SPAWN: float = 0.9
const TIEMPO_STANDALONE: float = 30.0
const MARGEN_VERTICAL: float = 24.0
const ANCHO_PANEL: float = 200.0
const ALTO_PANEL: float = 54.0

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
var logs_activos: Array[Control] = []

# Geometría calculada en _calcular_layout (píxeles)
var _vel_px: float = 0.0
var _y_spawn: float = 0.0
var _y_limite: float = 0.0
var _y_mira: float = 0.0

var _spawn_timer: Timer
var _controlado_por_frame: bool = false
var _partida_activa: bool = false
var _tiempo_restante: float = 0.0
var _indice_banco: int = 0

var _divider_nodes: Array[ColorRect] = []
var _mira_node: ColorRect

@onready var zona_juego: Control = $Layout/VBox/ZonaJuego
@onready var logs_container: Control = $Layout/VBox/ZonaJuego/LogsContainer
@onready var lbl_score: Label = $Layout/VBox/TopBar/ScorePanel/LblScore
@onready var lbl_carril: Label = $Layout/VBox/TopBar/LanePanel/LblLane
@onready var feedback_overlay: PanelContainer = $FeedbackOverlay
@onready var lbl_feedback: Label = $FeedbackOverlay/LblFeedback
@onready var btn_izq: Button = $Layout/VBox/BottomControls/BtnIzquierda
@onready var btn_der: Button = $Layout/VBox/BottomControls/BtnDerecha
@onready var btn_ignorar: Button = $Layout/VBox/BottomControls/BtnIgnorar
@onready var btn_bloquear: Button = $Layout/VBox/BottomControls/BtnBloquear
@onready var btn_aislar: Button = $Layout/VBox/BottomControls/BtnAislar

func _ready() -> void:
	_cargar_banco_predeterminado()
	_conectar_ui()

	_spawn_timer = Timer.new()
	_spawn_timer.name = "SpawnTimer"
	_spawn_timer.wait_time = INTERVALO_SPAWN
	_spawn_timer.timeout.connect(_spawn_log)
	add_child(_spawn_timer)

	resized.connect(_calcular_layout)
	call_deferred("_esperar_layout")

	# Fallback: si nadie llama a inicializar_minijuego(), arrancamos solos (prueba F6)
	get_tree().create_timer(0.1).timeout.connect(func():
		if not _controlado_por_frame:
			_iniciar_partida_standalone()
	)

func _esperar_layout() -> void:
	await get_tree().process_frame
	_calcular_layout()

func _process(delta: float) -> void:
	if not _partida_activa:
		return

	if not _controlado_por_frame:
		_tiempo_restante -= delta
		if _tiempo_restante <= 0.0:
			_finalizar()
			return

	_procesar_input_teclado()

## Entrada por teclado. Se lee el estado global del Input singleton,
## así que funciona tanto standalone (F6) como dentro del frame.
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

	_calcular_layout()
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

## Geometría: convierte el rango Z del mundo 3D en píxeles del área de juego.
func _calcular_layout() -> void:
	if not zona_juego or zona_juego.size.x <= 0.0 or zona_juego.size.y <= 0.0:
		return

	var zona: Rect2 = Rect2(Vector2.ZERO, zona_juego.size)
	_y_spawn = MARGEN_VERTICAL
	_y_limite = maxf(_y_spawn + 40.0, zona.size.y - MARGEN_VERTICAL)
	_y_mira = lerpf(_y_spawn, _y_limite, (Z_LINEA_MIRA - Z_SPAWN) / RANGO_CAIDA)
	_vel_px = velocidad_caida * (_y_limite - _y_spawn) / RANGO_CAIDA

	var n: int = max(1, cantidad_carriles)
	var ancho_carril: float = minf(zona.size.x / float(n + 1), ANCHO_PANEL + 20.0)
	posiciones_x_carriles.clear()
	for i in range(n):
		var centro_x: float = zona.size.x * 0.5 + (i - (n - 1) * 0.5) * ancho_carril
		posiciones_x_carriles.append(centro_x)

	_redibujar_carriles(zona, n, ancho_carril)
	_actualizar_posicion_mira()

func _redibujar_carriles(zona: Rect2, n: int, ancho: float) -> void:
	while _divider_nodes.size() > n + 1:
		var old: ColorRect = _divider_nodes.pop_back()
		old.queue_free()
	while _divider_nodes.size() < n + 1:
		var div := ColorRect.new()
		div.color = Color(0.15, 0.45, 0.5, 0.25)
		zona_juego.add_child(div)
		zona_juego.move_child(div, 0)
		_divider_nodes.append(div)

	for i in range(n + 1):
		var x: float = zona.size.x * 0.5 + (i - n * 0.5) * ancho
		_divider_nodes[i].position = Vector2(x, _y_spawn)
		_divider_nodes[i].size = Vector2(2.0, _y_limite - _y_spawn)

	if not is_instance_valid(_mira_node):
		_mira_node = ColorRect.new()
		_mira_node.color = Color(0.1, 0.95, 0.4, 0.3)
		zona_juego.add_child(_mira_node)
		zona_juego.move_child(_mira_node, 0)

func _cambiar_carril(direccion: int) -> void:
	carril_seleccionado = clampi(carril_seleccionado + direccion, 0, cantidad_carriles - 1)
	_actualizar_posicion_mira()

func _actualizar_posicion_mira() -> void:
	if is_instance_valid(_mira_node) and not posiciones_x_carriles.is_empty():
		var cx: float = posiciones_x_carriles[carril_seleccionado]
		_mira_node.position = Vector2(cx - 90.0, _y_mira)
		_mira_node.size = Vector2(180.0, 6.0)
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

	var log_item: Control = log_item_scene.instantiate()
	log_item.name = "LogItem"
	logs_container.add_child(log_item)
	log_item.position = Vector2(pos_x - ANCHO_PANEL * 0.5, _y_spawn)
	log_item.size = Vector2(ANCHO_PANEL, ALTO_PANEL)

	if log_item.has_method("setup"):
		log_item.setup(log_data.get("texto", ""), int(log_data.get("respuesta", 0)), _vel_px, _y_limite)
	if log_item.has_signal("log_perdido"):
		log_item.log_perdido.connect(_on_log_perdido)

	logs_activos.append(log_item)

func _on_log_perdido(log_item: Control) -> void:
	if not is_instance_valid(log_item) or not logs_activos.has(log_item):
		return
	logs_activos.erase(log_item)
	log_item.queue_free()

	if not _partida_activa:
		return

	puntos_actuales = max(0, puntos_actuales - penalizacion_error)
	_mostrar_feedback("LOG PERDIDO -%d PTS" % penalizacion_error, Color(1.0, 0.6, 0.1, 1))
	_emitir_puntos()
	_actualizar_score_ui()

## Evaluación: el log activo más cercano del carril seleccionado contra la acción.
## 0 = IGNORAR, 1 = BLOQUEAR IP, 2 = AISLAR HOST
func procesar_accion(tipo_accion: int) -> void:
	if not _partida_activa:
		return

	var log_objetivo: Control = _obtener_log_mas_cercano_en_carril(carril_seleccionado)
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

func _obtener_log_mas_cercano_en_carril(carril: int) -> Control:
	if carril < 0 or carril >= posiciones_x_carriles.size():
		return null

	var target_x: float = posiciones_x_carriles[carril]
	var candidato: Control = null
	var mayor_y: float = -9999.0

	for log_node in logs_activos:
		if not is_instance_valid(log_node):
			continue
		if "esta_procesado" in log_node and log_node.esta_procesado:
			continue
		var centro_x: float = log_node.position.x + log_node.size.x * 0.5
		if absf(centro_x - target_x) < ANCHO_PANEL * 0.5:
			if log_node.position.y > mayor_y:
				mayor_y = log_node.position.y
				candidato = log_node

	return candidato

func _mostrar_feedback(texto: String, color: Color) -> void:
	if not feedback_overlay or not lbl_feedback:
		return

	lbl_feedback.text = texto
	lbl_feedback.modulate = color

	feedback_overlay.pivot_offset = feedback_overlay.size / 2.0
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
	detener_partida()
	minijuego_completado.emit(puntos_actuales)

## Detiene la partida: congela todos los logs, corta el spawn y marca la
## partida como inactiva para que los logs que ya están en pantalla dejen
## de quitar puntos. Lo llama MinigameFrame al terminar el nivel. Idempotente.
func detener_partida() -> void:
	_partida_activa = false
	if _spawn_timer:
		_spawn_timer.stop()
	_detener_logs_en_movimiento()

func _detener_logs_en_movimiento() -> void:
	for log_node in logs_activos:
		if not is_instance_valid(log_node):
			continue
		if log_node.has_method("detener"):
			log_node.detener()
		elif "esta_procesado" in log_node:
			log_node.esta_procesado = true

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
		velocidad_caida = 0.12
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
	if not is_instance_valid(logs_container):
		return
	for child in logs_container.get_children():
		child.queue_free()
	logs_activos.clear()

func _conectar_ui() -> void:
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
