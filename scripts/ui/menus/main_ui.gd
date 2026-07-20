# MainUI.gd
extends Control

@onready var main_menu_component: Control = $MainMenuComponent
@onready var new_game_component: Control = $NewGameComponent
@onready var loading_screen: Control = $LoadingScreenComponent
@onready var progress_bar: ProgressBar = $LoadingScreenComponent/ColorRect/ProgressBar

@onready var minigame_menu: Control = $MinigameMenu
@onready var minigame_frame: Control = $MinigameFrame

@onready var main_menu_3d: Node3D = $"../MainMenu3D"

# Guarda la ruta de la escena de Background (el nodo hijo de MainMenu3D)
const BACKGROUND_SCENE_PATH ="res://scenes/ui/menus/background/background.tscn"  # Ajusta si tu ruta difiere
const MAPA_3D_SCENE_PATH = "res://scenes/levels/main/main_level_3d.tscn"
const POST_LOAD_DELAY: float = 0.8

func _ready() -> void:
	main_menu_component.new_game_pressed.connect(_on_new_game_pressed)
	main_menu_component.load_game_pressed.connect(_on_load_game_pressed)
	main_menu_component.exit_pressed.connect(func(): get_tree().quit())
	
	new_game_component.character_created.connect(_on_character_creation_complete)
	new_game_component.canceled.connect(_on_character_creation_canceled)
	
	if minigame_menu.has_signal("exit_requested"):
		minigame_menu.exit_requested.connect(_on_minigame_menu_exit)
	else:
		EventBus.user_exit.connect(_on_minigame_menu_exit)
	
	_show_only(main_menu_component)

# MainUI.gd (Fragmentos actualizados)

func _on_minigame_menu_exit() -> void:
	var root = get_tree().root.get_node_or_null("Main")
	
	# 1. Eliminamos el nivel 3D del juego
	if root and root.has_node("MainLevel3D"):
		var level = root.get_node("MainLevel3D")
		root.remove_child(level)
		level.free()
	
	# 2. Restauramos la postura global exacta de MainMenu3D
	if main_menu_3d:
		# Reseteamos transformaciones acumuladas a nivel global
		main_menu_3d.global_position = Vector3.ZERO
		main_menu_3d.global_rotation = Vector3.ZERO
		
		# Buscamos la cámara en el Background y forzamos su orientación global
		var cam = main_menu_3d.find_child("Camera3D", true, false) as Camera3D
		if cam:
			cam.make_current()
		
		main_menu_3d.show()

	# 3. Restauramos la UI inicial
	_show_only(main_menu_component)
	EventBus.menu_changed.emit("MainMenuComponent")
	
func _on_start_game_sequence() -> void:
	main_menu_component.hide()
	new_game_component.hide()
	minigame_menu.hide()
	minigame_frame.hide()
	
	# Congelamos completamente Background y ocultamos MainMenu3D
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
func _on_new_game_pressed() -> void:
	new_game_component.reset_form()
	_show_only(new_game_component)

func _on_character_creation_canceled() -> void:
	_show_only(main_menu_component)

func _on_character_creation_complete(data: Dictionary) -> void:
	print("Creando perfil de agente: ", data["nombre"], " ", data["apellido"])
	
	var nuevo_save = SaveData.new()
	nuevo_save.player_name = data["nombre"]
	nuevo_save.player_lastname = data["apellido"]
	nuevo_save.player_pnf = data["pnf"]
	nuevo_save.player_role = data["rol"]
	nuevo_save.player_avatar_path = data["avatar_path"]
	
	EventBus.save_requested.emit(nuevo_save)
	_on_start_game_sequence()

func _on_load_game_pressed() -> void:
	EventBus.load_requested.emit()
	_on_start_game_sequence()

func _fade_out_loading_screen() -> void:
	var tween = create_tween()
	tween.tween_property(loading_screen, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		loading_screen.hide()
		loading_screen.modulate.a = 1.0 
		
		_show_only(minigame_menu)
		EventBus.menu_changed.emit("MinigameMenu")
	)

func _set_camera_active(parent_node: Node, active: bool) -> void:
	if parent_node is Camera3D:
		if active:
			parent_node.make_current()
		else:
			parent_node.current = false
		return
	for child in parent_node.get_children():
		_set_camera_active(child, active)

func _show_only(active_component: Control) -> void:
	main_menu_component.visible = (active_component == main_menu_component)
	new_game_component.visible = (active_component == new_game_component)
	loading_screen.visible = (active_component == loading_screen)
	minigame_menu.visible = (active_component == minigame_menu)
	minigame_frame.visible = (active_component == minigame_frame)
