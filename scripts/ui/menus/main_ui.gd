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
	"servidor_fisico"
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
	main_menu_component.new_game_pressed.connect(_on_new_game_pressed)
	main_menu_component.load_game_pressed.connect(_on_load_game_pressed)
	main_menu_component.exit_pressed.connect(func(): get_tree().quit())
	
	# Creación de Personaje
	new_game_component.character_created.connect(_on_character_creation_complete)
	new_game_component.canceled.connect(_on_character_creation_canceled)
	
	# Eventos de Minijuegos y EventBus
	if minigame_menu.has_signal("exit_requested"):
		minigame_menu.exit_requested.connect(_on_minigame_menu_exit)
		
	# Conectar la señal de cámara 3D emitida por el MinigameFrame
	if minigame_frame.has_signal("solicitar_camara_3d"):
		minigame_frame.solicitar_camara_3d.connect(_on_solicitar_camara_3d)
		
	# Conectar SIEMPRE la salida global emitida por MinigameFrame o el Bus
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
func _on_minigame_selected(minigame_id: String, _level: int = 1) -> void:
	print("Desplegando marco para el minijuego: ", minigame_id)
	
	# 1. Cambiar a la vista del MinigameFrame
	_switch_to_view(minigame_frame)
	
	# 2. Evaluar si el minijuego es 3D (en el mundo) o 2D (aislado)
	var es_en_mundo_3d: bool = minigame_id in MINIJUEGOS_EN_MAPA_3D
	
	# 3. Invocar activamente la carga de la grilla de niveles en el MinigameFrame
	minigame_frame.abrir_minijuego(minigame_id, es_en_mundo_3d)

func _on_solicitar_camara_3d(id_minijuego: String, activar: bool) -> void:
	# Notificar al nivel 3D activo para enfocar la cámara en la estación interactiva
	var root = get_tree().root.get_node_or_null("Main")
	if root and root.has_node("MainLevel3D"):
		var mapa_3d = root.get_node("MainLevel3D")
		if mapa_3d.has_method("enfocar_interaccion_3d"):
			mapa_3d.enfocar_interaccion_3d(id_minijuego, activar)

func _on_minigame_menu_exit() -> void:
	# Si estábamos en el marco del minijuego (o acaba de cerrarse), regresamos al menú del selector
	if current_view == minigame_frame or minigame_frame.visible:
		_switch_to_view(minigame_menu)
		EventBus.menu_changed.emit("MinigameMenu")
		return

	# Si la vista activa es el MinigameMenu, salimos de la partida hacia el menú principal 3D
	if current_view == minigame_menu:
		var root = get_tree().root.get_node_or_null("Main")
		if root and root.has_node("MainLevel3D"):
			var level = root.get_node("MainLevel3D")
			root.remove_child(level)
			level.free()
		
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
	new_game_component.reset_form()
	_switch_to_view(new_game_component)

func _on_character_creation_canceled() -> void:
	_switch_to_view(main_menu_component)

func _on_character_creation_complete(data: Dictionary) -> void:
	print("Creando perfil de agente: ", data["nombre"], " ", data["apellido"])
	
	var nuevo_save = SaveData.new()
	nuevo_save.player_name = data["nombre"]
	nuevo_save.player_lastname = data["apellido"]
	nuevo_save.player_pnf = data["pnf"]
	nuevo_save.player_role = data["rol"]
	nuevo_save.player_avatar_path = data["avatar_path"]
	
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
