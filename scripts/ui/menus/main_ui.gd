# res://scenes/ui/main_ui.gd
extends Control

@onready var main_menu_component: Control = $MainMenuComponent
@onready var new_game_component: Control = $NewGameComponent
@onready var loading_screen: Control = $LoadingScreenComponent
@onready var progress_bar: ProgressBar = $LoadingScreenComponent/ColorRect/ProgressBar
@onready var minigame_menu: Control = $MinigameMenu
@onready var minigame_frame: Control = $MinigameFrame

@onready var main_menu_3d: Node3D = $"../MainMenu3D"

# Rutas de escenas y constantes
const BACKGROUND_SCENE_PATH = "res://scenes/ui/menus/background/background.tscn"
const MAPA_3D_SCENE_PATH = "res://scenes/levels/main/main_level_3d.tscn"
const POST_LOAD_DELAY: float = 0.8

# Lista de IDs de minijuegos que ocurren directamente sobre el mapa 3D
const MINIJUEGOS_EN_MAPA_3D: Array[String] = [
	"configuracion_cables",
	"servidor_fisico",
	"cyber_tools",
	"bullet_dodge"
]

# Mapa de vistas registradas para la UI
@onready var views: Dictionary = {
	"MainMenuComponent": main_menu_component,
	"NewGameComponent": new_game_component,
	"LoadingScreenComponent": loading_screen,
	"MinigameMenu": minigame_menu,
	"MinigameFrame": minigame_frame
}

var current_view: Control = null

func _ready() -> void:
	_conectar_senales()
	_switch_to_view(main_menu_component)

# --- CONEXIÓN DE EVENTOS ---
func _conectar_senales() -> void:
	# Menú Principal
	if main_menu_component.has_signal("new_game_pressed"):
		main_menu_component.new_game_pressed.connect(_on_new_game_pressed)
	if main_menu_component.has_signal("load_game_pressed"):
		main_menu_component.load_game_pressed.connect(_on_load_game_pressed)
	if main_menu_component.has_signal("exit_pressed"):
		main_menu_component.exit_pressed.connect(func(): get_tree().quit())
		
	# Frame de Minijuegos
	if minigame_frame.has_signal("solicitar_montar_pc_3d"):
		minigame_frame.solicitar_montar_pc_3d.connect(_on_solicitar_montar_pc_3d)
	if minigame_frame.has_signal("solicitar_camara_3d"):
		minigame_frame.solicitar_camara_3d.connect(_on_solicitar_camara_3d)
	if minigame_frame.has_signal("minijuego_completado_global"):
		minigame_frame.minijuego_completado_global.connect(_on_minigame_completed)

	# Creación de Personaje
	if new_game_component.has_signal("character_created"):
		new_game_component.character_created.connect(_on_character_creation_complete)
	if new_game_component.has_signal("canceled"):
		new_game_component.canceled.connect(_on_character_creation_canceled)
	
	# Eventos de Selector de Minijuegos
	if minigame_menu.has_signal("exit_requested"):
		minigame_menu.exit_requested.connect(_on_minigame_menu_exit)

	# EventBus
	EventBus.user_exit.connect(_on_minigame_menu_exit)
	EventBus.minigame_selected.connect(_on_minigame_selected)
	EventBus.menu_changed.connect(_on_menu_changed_requested)

# --- NAVEGACIÓN Y GESTIÓN DE VISTAS ---
func _switch_to_view(target_view: Control) -> void:
	current_view = target_view
	for view_name in views:
		var view_node = views[view_name]
		view_node.visible = (view_node == target_view)

func _on_menu_changed_requested(view_name: String) -> void:
	if views.has(view_name):
		_switch_to_view(views[view_name])

# --- FLUJO DE MINIJUEGOS Y NAVEGACIÓN ---
# En res://scenes/ui/main_ui.gd

# --- FLUJO DE MINIJUEGOS Y NAVEGACIÓN ---
func _on_minigame_selected(minigame_id: String, es_3d_custom: bool = false, requiere_camara: bool = false) -> void:
	print("Desplegando marco para el minijuego: ", minigame_id)
	_switch_to_view(minigame_frame)
	
	# Le pasamos a minigame_frame los datos directamente
	minigame_frame.abrir_minijuego(minigame_id, es_3d_custom, requiere_camara)
	
func _on_solicitar_montar_pc_3d(id_minijuego: String, escena_ui: PackedScene, config_data: Resource) -> void:
	var mapa_3d = _obtener_mapa_3d_activo()
	if not mapa_3d:
		push_error("No se encontró el mapa 3D activo.")
		return

	# OP CION A: Si el mapa 3D maneja un método centralizado
	if mapa_3d.has_method("inicializar_minijuego_en_mapa"):
		mapa_3d.inicializar_minijuego_en_mapa(id_minijuego, escena_ui, config_data)
	# OPCION B: Si las estaciones están registradas en el diccionario del mapa 3D
	elif "estaciones_mapa" in mapa_3d and mapa_3d.estaciones_mapa.has(id_minijuego):
		var estacion = mapa_3d.estaciones_mapa[id_minijuego]
		if estacion.has_method("cargar_minijuego"):
			estacion.cargar_minijuego(escena_ui, config_data)
		elif estacion.has_method("montar_minijuego"):
			estacion.montar_minijuego(escena_ui, config_data)

	# Enfocamos la cámara hacia la mesa/interacción
	if mapa_3d.has_method("enfocar_interaccion_3d"):
		mapa_3d.enfocar_interaccion_3d(id_minijuego, true)

func _on_solicitar_camara_3d(id_minijuego: String, activar: bool) -> void:
	var mapa_3d = _obtener_mapa_3d_activo()
	if mapa_3d and mapa_3d.has_method("enfocar_interaccion_3d"):
		mapa_3d.enfocar_interaccion_3d(id_minijuego, activar)

func _on_minigame_completed(id_minijuego: String, score_final: int) -> void:
	print("Minijuego ", id_minijuego, " completado con puntaje: ", score_final)

func _on_minigame_menu_exit() -> void:
	# Si estábamos dentro del MinigameFrame, regresamos al selector de minijuegos
	if current_view == minigame_frame or minigame_frame.visible:
		_switch_to_view(minigame_menu)
		EventBus.menu_changed.emit("MinigameMenu")
		return

	# Si estábamos en el MinigameMenu, destruimos el mapa 3D y volvemos al menú principal
	if current_view == minigame_menu:
		var mapa_3d = _obtener_mapa_3d_activo()
		if mapa_3d:
			mapa_3d.queue_free()
		
		if main_menu_3d:
			main_menu_3d.global_position = Vector3.ZERO
			main_menu_3d.global_rotation = Vector3.ZERO
			
			var cam = main_menu_3d.find_child("Camera3D", true, false) as Camera3D
			if cam:
				cam.make_current()
			
			main_menu_3d.show()

		_switch_to_view(main_menu_component)
		EventBus.menu_changed.emit("MainMenuComponent")

# --- FLUJO DE NUEVA PARTIDA / CARGA ---
func _on_new_game_pressed() -> void:
	if new_game_component.has_method("reset_form"):
		new_game_component.reset_form()
	_switch_to_view(new_game_component)

func _on_character_creation_canceled() -> void:
	_switch_to_view(main_menu_component)

func _on_character_creation_complete(data: Dictionary) -> void:
	print("Creando perfil de agente: ", data.get("nombre", ""), " ", data.get("apellido", ""))
	
	var nuevo_save = SaveData.new()
	nuevo_save.player_name = data.get("nombre", "")
	nuevo_save.player_lastname = data.get("apellido", "")
	nuevo_save.player_pnf = data.get("pnf", "")
	nuevo_save.player_role = data.get("rol", "")
	nuevo_save.player_avatar_path = data.get("avatar_path", "")
	
	EventBus.save_requested.emit(nuevo_save)
	_start_game_sequence()

func _on_load_game_pressed() -> void:
	EventBus.load_requested.emit()
	_start_game_sequence()

# --- TRANSICIÓN Y CARGA 3D ---
func _start_game_sequence() -> void:
	_ocultar_todas_las_vistas()
	
	if main_menu_3d:
		_set_camera_active(main_menu_3d, false)
		main_menu_3d.set_process(false)
		main_menu_3d.set_process_unhandled_input(false)
		
		if main_menu_3d.has_node("Background"):
			var bg = main_menu_3d.get_node("Background")
			bg.set_process(false)
			bg.set_process_unhandled_input(false)
			
		main_menu_3d.hide()
		
	progress_bar.value = 0
	loading_screen.show()
	
	await TransitionManager.transition_to_3d_map(MAPA_3D_SCENE_PATH, progress_bar, POST_LOAD_DELAY)
	_fade_out_loading_screen()

func _fade_out_loading_screen() -> void:
	var tween = create_tween()
	tween.tween_property(loading_screen, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		loading_screen.hide()
		loading_screen.modulate.a = 1.0 
		
		_switch_to_view(minigame_menu)
		EventBus.menu_changed.emit("MinigameMenu")
	)

# --- AUXILIARES ---
func _obtener_mapa_3d_activo() -> Node:
	var current = get_tree().current_scene
	if current and current.name == "MainLevel3D":
		return current
	return get_tree().root.find_child("MainLevel3D", true, false)

func _ocultar_todas_las_vistas() -> void:
	for view_name in views:
		views[view_name].hide()

func _set_camera_active(parent_node: Node, active: bool) -> void:
	if parent_node is Camera3D:
		if active:
			parent_node.make_current()
		else:
			parent_node.current = false
		return
	for child in parent_node.get_children():
		_set_camera_active(child, active)
