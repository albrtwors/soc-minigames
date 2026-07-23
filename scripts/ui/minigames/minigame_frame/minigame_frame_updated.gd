# res://scenes/ui/menus/minigame_frame/minigame_frame.gd
extends Control

# Señal para avisar al mapa 3D principal que enfoque/desenfoque la cámara o interactúe
signal solicitar_camara_3d(id_minijuego: String, activar: bool)
signal minijuego_completado_global(id_minijuego: String, score_final: int)

@export_group("Escenas Auxiliares")
@export var modal_tutorial_scene: PackedScene
@export var level_button_scene: PackedScene

@export_group("Diccionarios de Configuración")
# Escenas que se instanciarán internamente (2D o 3D aislados)
@export var minigame_scenes_2d: Dictionary = {
	"phishing": "res://scenes/minigames/phishing/phishing_ui.tscn"
}

# Niveles cargados desde recursos .tres (NivelTutorialData y NivelArcadeData)
@export var level_data_resources: Dictionary = {
	"configuracion_cables": [
		"res://scripts/data/config_levels/00_tutorial_cables.tres",
		"res://scripts/data/config_levels/nivel_1_arcade.tres",
		"res://scripts/data/config_levels/nivel_2_arcade.tres"
	]
}

# Nodos de la UI
@onready var color_rect_fondo: ColorRect = $ColorRectFondo
@onready var container_2d: Control = $PlayArea/Container2D
@onready var hud: Control = $HUD
@onready var lbl_timer: Label = $HUD/TopBar/LblTimer
@onready var lbl_score: Label = $HUD/TopBar/LblScore
@onready var btn_salir: Button = $HUD/BtnSalir
@onready var menu_niveles: Control = $MenuNiveles
@onready var grid_niveles: GridContainer = $MenuNiveles/ScrollContainer/GridContainer
@onready var modal_container: Control = $ModalContainer

# Nodos de Control Arcade
var timer_arcade: Timer
var minijuego_id_actual: String = ""
var indice_nivel_actual: int = 0
var score_actual: int = 0
var en_partida_activa: bool = false
var es_minijuego_en_mundo_3d: bool = false

func _ready() -> void:
	# Crear Timer Arcade por código para evitar olvidarlo en la UI
	timer_arcade = Timer.new()
	timer_arcade.one_shot = true
	timer_arcade.timeout.connect(_on_tiempo_agotado)
	add_child(timer_arcade)

	if btn_salir: btn_salir.pressed.connect(_on_salir_pressed)
	
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
	
	menu_niveles.show()
	color_rect_fondo.show() # Fondo oscuro mientras se eligen niveles
	
	# Limpiar botones anteriores
	for child in grid_niveles.get_children():
		child.queue_free()

	if not level_data_resources.has(minijuego_id_actual):
		push_warning("No hay recursos definidos para: " + minijuego_id_actual)
		return

	var rutas = level_data_resources[minijuego_id_actual]
	for i in range(rutas.size()):
		var res_data: NivelBaseData = load(rutas[i]) as NivelBaseData
		if not res_data: continue

		var level_btn = level_button_scene.instantiate()
		grid_niveles.add_child(level_btn)
		level_btn.setup(res_data)
		
		var idx = i
		level_btn.nivel_seleccionado.connect(func(_data): _cargar_nivel_por_indice(idx))

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
	color_rect_fondo.show() # Fondo activo para leer con claridad

	if modal_tutorial_scene:
		var modal = modal_tutorial_scene.instantiate()
		modal_container.add_child(modal)
		modal.setup_tutorial(data)
		modal.tutorial_completado.connect(func():
			# Al terminar la teoría, pasa automáticamente al siguiente nivel en la lista
			_cargar_nivel_por_indice(indice_nivel_actual + 1)
		)

# --- 3. LÓGICA HÍBRIDA DE GAMEPLAY ARCADE ---
func _iniciar_partida_arcade(data: NivelArcadeData) -> void:
	_limpiar_pantalla()
	menu_niveles.hide()
	
	score_actual = 0
	_actualizar_score_ui()
	hud.show()

	if es_minijuego_en_mundo_3d:
		# MODO B: El 3D sucede afuera en el mapa principal
		color_rect_fondo.hide() # Ocultamos fondo para ver el 3D del mundo
		solicitar_camara_3d.emit(minijuego_id_actual, true)
	else:
		# MODO A: Instanciamos la escena 2D en el Container2D
		color_rect_fondo.show()
		if minigame_scenes_2d.has(minijuego_id_actual):
			var esc_path = minigame_scenes_2d[minijuego_id_actual]
			var puzzle = load(esc_path).instantiate()
			container_2d.add_child(puzzle)

			# Conectar señales estándar del minijuego
			if puzzle.has_signal("accion_correcta"):
				puzzle.accion_correcta.connect(_on_puntos_ganados)
			if puzzle.has_signal("accion_incorrecta"):
				puzzle.accion_incorrecta.connect(_on_puntos_perdidos)
			if puzzle.has_method("cargar_nivel"):
				puzzle.cargar_nivel(data)

	# Arrancar Timer Arcade de 30s
	en_partida_activa = true
	timer_arcade.start(data.tiempo_limite)

# --- 4. CONTROL DE PUNTOS Y TIEMPO ---
func _on_puntos_ganados(puntos: int) -> void:
	score_actual += puntos
	_actualizar_score_ui()

func _on_puntos_perdidos(penalizacion: int) -> void:
	score_actual = max(0, score_actual - penalizacion)
	_actualizar_score_ui()

func _actualizar_score_ui() -> void:
	lbl_score.text = "Puntos: " + str(score_actual)

func _on_tiempo_agotado() -> void:
	en_partida_activa = false
	print("¡Se acabaron los 30s! Puntaje final: ", score_actual)
	minijuego_completado_global.emit(minijuego_id_actual, score_actual)
	_mostrar_grid_niveles()

# --- 5. LIMPIEZA Y SALIDA ---
func _detener_partida() -> void:
	en_partida_activa = false
	timer_arcade.stop()
	if es_minijuego_en_mundo_3d:
		solicitar_camara_3d.emit(minijuego_id_actual, false)

func _limpiar_pantalla() -> void:
	hud.hide()
	menu_niveles.hide()
	
	# Limpiar instancias de minijuegos 2D y modales
	for child in container_2d.get_children():
		child.queue_free()
	for child in modal_container.get_children():
		child.queue_free()

func _on_salir_pressed() -> void:
	if hud.visible:
		_mostrar_grid_niveles() # Si está jugando, regresa a elegir nivel
	else:
		_detener_partida()
		_limpiar_pantalla()
		hide() # Cierra el MinigameFrame por completo
