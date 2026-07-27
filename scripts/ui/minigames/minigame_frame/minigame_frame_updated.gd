extends Control

# Señales para comunicar cambios con el mapa/mundo 3D
signal solicitar_montar_pc_3d(id_minijuego: String, escena_ui: PackedScene, config_data: Resource)
signal solicitar_camara_3d(id_minijuego: String, activar: bool)
signal minijuego_completado_global(id_minijuego: String, score_final: int)

@export_group("Escenas Auxiliares")
@export var modal_tutorial_scene: PackedScene
@export var modal_score_scene: PackedScene  # Escena modal de puntuación/resumen
@export var level_button_scene: PackedScene

@export_group("Diccionarios de Configuración")
@export var minigame_scenes_2d: Dictionary = {
	"phishing": "res://scenes/minigames/phishing/minijuego_anti_phishing_updated.tscn"
}

@export var level_data_resources: Dictionary = {
	"configuracion_cables": [
		"res://scripts/data/config_levels/00_tutorial_cables.tres",
		"res://scripts/data/config_levels/nivel_1_arcade.tres",
		"res://scripts/data/config_levels/nivel_2_arcade.tres"
	],
	"phishing": [
		"res://scripts/data/phishing_levels/tutorials/phishing_arc1.tres",
		"res://scripts/data/phishing_levels/phising_arc1.tres"
	]
}

# Nodos de la UI
@onready var color_rect_fondo: ColorRect = $ColorRectFondo
@onready var container_2d: Control = $PlayArea/PanelContainer/Container2D
@onready var hud: Control = $HUD
@onready var lbl_timer: Label = $HUD/TopBar/LblTimer
@onready var lbl_score: Label = $HUD/TopBar/LblScore
@onready var btn_salir: Button = $HUD/BtnSalir
@onready var menu_niveles: Control = $MenuNiveles
@onready var grid_niveles: GridContainer = $MenuNiveles/ScrollContainer/GridContainer
@onready var btn_volver_menu: Button = $BtnSalir
@onready var modal_container: Control = $ModalContainer

# Nodos de Control Arcade
var timer_arcade: Timer
var minijuego_id_actual: String = ""
var indice_nivel_actual: int = 0
var score_actual: int = 0
var en_partida_activa: bool = false
var es_minijuego_en_mundo_3d: bool = false

func _ready() -> void:
	timer_arcade = Timer.new()
	timer_arcade.one_shot = true
	timer_arcade.timeout.connect(_on_tiempo_agotado)
	add_child(timer_arcade)

	if btn_salir: 
		btn_salir.pressed.connect(_on_salir_pressed)
		
	if btn_volver_menu: 
		btn_volver_menu.pressed.connect(_on_volver_menu_pressed)
		
	if EventBus.has_signal("puntos_actualizados"):
		EventBus.puntos_actualizados.connect(_on_puntos_actualizados)
		
	# Asegurar pivote central para la animación del Label de Puntos
	lbl_score.pivot_offset = lbl_score.size / 2.0
	_limpiar_pantalla()

func _process(_delta: float) -> void:
	if en_partida_activa and not timer_arcade.is_stopped():
		var tiempo_restante = ceil(timer_arcade.time_left)
		lbl_timer.text = "Tiempo: " + str(int(tiempo_restante)) + "s"

# --- 1. APERTURA Y SELECCIÓN DE NIVELES ---
func abrir_minijuego(id_minijuego: String, es_en_mundo_3d: bool = false) -> void:
	minijuego_id_actual = id_minijuego
	es_minijuego_en_mundo_3d = es_en_mundo_3d
	show()
	_mostrar_grid_niveles()

func _mostrar_grid_niveles() -> void:
	_detener_partida()
	_limpiar_pantalla()
	
	show()
	menu_niveles.show()
	_animar_fade_fondo(true)
	
	for child in grid_niveles.get_children():
		grid_niveles.remove_child(child)
		child.queue_free()

	if not level_data_resources.has(minijuego_id_actual):
		push_warning("No hay recursos definidos para: " + minijuego_id_actual)
		return

	var rutas = level_data_resources[minijuego_id_actual]
	var botones_creados: Array[Control] = []

	for i in range(rutas.size()):
		var res_data = load(rutas[i])
		if not res_data: continue

		var level_btn = level_button_scene.instantiate()
		grid_niveles.add_child(level_btn)
		botones_creados.append(level_btn)
		
		if level_btn.has_signal("nivel_seleccionado"):
			for conn in level_btn.nivel_seleccionado.get_connections():
				level_btn.nivel_seleccionado.disconnect(conn["callable"])

		level_btn.setup(res_data)
		
		var idx = i
		level_btn.nivel_seleccionado.connect(
			func(_data): _cargar_nivel_por_indice(idx), 
			CONNECT_ONE_SHOT
		)

	# Animación en cascada para los botones creados
	_animar_botones_grid(botones_creados)

func _cargar_nivel_por_indice(idx: int) -> void:
	indice_nivel_actual = idx
	var rutas = level_data_resources[minijuego_id_actual]
	
	if idx >= rutas.size():
		_mostrar_grid_niveles()
		return

	var res_data = load(rutas[idx])
	if res_data is NivelTutorialData:
		_iniciar_tutorial(res_data)
	elif res_data is NivelArcadeData:
		_iniciar_partida_arcade(res_data)

# --- 2. LÓGICA DE TUTORIAL ---
func _iniciar_tutorial(data: NivelTutorialData) -> void:
	_limpiar_pantalla()
	menu_niveles.hide()
	hud.hide()
	_animar_fade_fondo(true)

	if modal_tutorial_scene:
		var modal = modal_tutorial_scene.instantiate()
		modal_container.add_child(modal)
		modal.setup_tutorial(data)
		_animar_aparicion_modal(modal)
		
		modal.tutorial_completado.connect(func():
			_limpiar_pantalla()
			_cargar_nivel_por_indice(indice_nivel_actual + 1)
		, CONNECT_ONE_SHOT)

# --- 3. LÓGICA DE GAMEPLAY ---
func _iniciar_partida_arcade(data: NivelArcadeData) -> void:
	_limpiar_pantalla()
	menu_niveles.hide()
	
	score_actual = 0
	_actualizar_score_ui(false) # Sin animación de pop al iniciar
	hud.show()

	if es_minijuego_en_mundo_3d:
		_animar_fade_fondo(false) # Transparente para ver el 3D
		solicitar_camara_3d.emit(minijuego_id_actual, true)

		if not minigame_scenes_2d.has(minijuego_id_actual):
			en_partida_activa = true
			timer_arcade.start(data.tiempo_limite)
			hide() 
			return
	else:
		_animar_fade_fondo(true)

	if not minigame_scenes_2d.has(minijuego_id_actual):
		push_error("No hay escena asignada para: " + minijuego_id_actual)
		return

	var esc_path: String = minigame_scenes_2d[minijuego_id_actual]
	var escena_ui: PackedScene = load(esc_path) as PackedScene
	
	if not escena_ui:
		push_error("No se pudo cargar la escena en: " + esc_path)
		return

	var puzzle = escena_ui.instantiate()
	container_2d.add_child(puzzle)
	
	# Animación Pop-in para la entrada de la UI del minijuego
	puzzle.scale = Vector2.ZERO
	puzzle.pivot_offset = puzzle.size / 2.0
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(puzzle, "scale", Vector2.ONE, 0.3)

	if puzzle.has_signal("minijuego_completado"):
		puzzle.minijuego_completado.connect(func(puntos_finales: int):
			score_actual = puntos_finales
			_actualizar_score_ui()
			_on_tiempo_agotado()
		)

	if puzzle.has_method("inicializar_minijuego"):
		puzzle.inicializar_minijuego(data)
	elif puzzle.has_method("cargar_nivel"):
		puzzle.cargar_nivel(data)

	en_partida_activa = true
	timer_arcade.start(data.tiempo_limite)

# --- 4. CONTROL DE PUNTOS Y TIEMPO ---
func _on_puntos_actualizados(puntos: int) -> void:
	score_actual = puntos
	_actualizar_score_ui(true)

func _actualizar_score_ui(animar: bool = true) -> void:
	lbl_score.text = "Puntos: " + str(score_actual)
	
	if animar:
		lbl_score.pivot_offset = lbl_score.size / 2.0
		var tween = create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		tween.tween_property(lbl_score, "scale", Vector2(1.25, 1.25), 0.1)
		tween.tween_property(lbl_score, "scale", Vector2.ONE, 0.15)

func _on_tiempo_agotado() -> void:
	_detener_partida()
	print("¡Partida finalizada! Puntaje final: ", score_actual)
	
	minijuego_completado_global.emit(minijuego_id_actual, score_actual)
	if EventBus.has_signal("minigame_completed"):
		EventBus.minigame_completed.emit(minijuego_id_actual, score_actual)
		
	_mostrar_popup_resultado()

# --- 5. POPUP DE RESULTADOS ---
func _mostrar_popup_resultado() -> void:
	hud.hide()
	
	if not modal_score_scene:
		push_error("No se ha asignado 'modal_score_scene' en el Inspector de MinigameFrame.")
		_mostrar_grid_niveles()
		return

	var modal = modal_score_scene.instantiate()
	modal_container.add_child(modal)
	
	_animar_aparicion_modal(modal)
	
	if modal.has_method("mostrar_resultado"):
		modal.mostrar_resultado(score_actual)
	elif modal.has_method("setup_score"):
		modal.setup_score(score_actual)
	
	if modal.has_signal("continuar_presionado"):
		modal.continuar_presionado.connect(func():
			_limpiar_pantalla()
			_mostrar_grid_niveles()
		, CONNECT_ONE_SHOT)
	elif modal.has_signal("modal_cerrado"):
		modal.modal_cerrado.connect(func():
			_limpiar_pantalla()
			_mostrar_grid_niveles()
		, CONNECT_ONE_SHOT)

func _animar_aparicion_modal(node: Control) -> void:
	# Respetar el pivote central según el tamaño actual
	node.pivot_offset = node.size / 2.0
	node.modulate.a = 0.0
	node.scale = Vector2(0.7, 0.7)
	
	var tween = create_tween().set_parallel(true)
	# TRANS_BACK con EASE_OUT da una llegada más natural y asentada
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Transición de opacidad en 0.5s (antes 0.25s)
	tween.tween_property(node, "modulate:a", 1.0, 0.5)
	# Transición de tamaño en 0.55s
	tween.tween_property(node, "scale", Vector2.ONE, 0.55)

func _animar_botones_grid(botones: Array[Control]) -> void:
	for i in range(botones.size()):
		var btn = botones[i]
		btn.modulate.a = 0.0
		btn.scale = Vector2(0.85, 0.85)
		
		# Esperar un frame para que el GridContainer calcule las dimensiones reales
		await get_tree().process_frame
		btn.pivot_offset = btn.size / 2.0
		
		# Retardo aumentado a 0.12s entre cada botón (efecto dominó claro)
		var delay = i * 0.12
		
		var tween = create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		
		# Animación más pausada: 0.5s de duración
		tween.tween_property(btn, "modulate:a", 1.0, 0.5).set_delay(delay)
		tween.tween_property(btn, "scale", Vector2.ONE, 0.5).set_delay(delay)

func _animar_fade_fondo(mostrar: bool) -> void:
	var target_alpha = 1.0 if mostrar else 0.0
	if mostrar: color_rect_fondo.show()
	
	var tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	# Fondo suavizado en 0.45s para evitar brincos bruscos
	tween.tween_property(color_rect_fondo, "modulate:a", target_alpha, 0.45)
	
	if not mostrar:
		tween.tween_callback(color_rect_fondo.hide)
# --- 7. LIMPIEZA Y SALIDA ---
func _detener_partida() -> void:
	en_partida_activa = false
	timer_arcade.stop()

func _limpiar_pantalla() -> void:
	hud.hide()
	menu_niveles.hide()
	
	for child in container_2d.get_children():
		container_2d.remove_child(child)
		child.queue_free()
		
	for child in modal_container.get_children():
		modal_container.remove_child(child)
		child.queue_free()

func _on_salir_pressed() -> void:
	if hud.visible:
		_mostrar_grid_niveles()
	else:
		_on_volver_menu_pressed()

func _on_volver_menu_pressed() -> void:
	if es_minijuego_en_mundo_3d:
		solicitar_camara_3d.emit(minijuego_id_actual, false)

	_detener_partida()
	_limpiar_pantalla()
	hide()
	
	if EventBus.has_signal("user_exit"):
		EventBus.user_exit.emit()
