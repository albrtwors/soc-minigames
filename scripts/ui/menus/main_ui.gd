# res://scenes/ui/main_ui.gd
extends Control

@onready var main_menu_component: Control = $MainMenuComponent
@onready var new_game_component: Control = $NewGameComponent
@onready var loading_screen: Control = $LoadingScreenComponent
@onready var progress_bar: ProgressBar = $LoadingScreenComponent/ColorRect/ProgressBar
@onready var minigame_menu: Control = $MinigameMenu
@onready var minigame_frame: Control = $MinigameFrame
@onready var save_slot_selector: Control = $SaveSlotSelector
@onready var overwrite_modal: Control = $OverwriteModal
@onready var delete_modal: Control = $DeleteModal

@onready var main_menu_3d: Node3D = $"../MainMenu3D"

const MAPA_3D_SCENE_PATH = "res://scenes/levels/main/main_level_3d.tscn"
const POST_LOAD_DELAY: float = 0.8

const MINIJUEGOS_EN_MAPA_3D: Array[String] = [
	"configuracion_cables",
	"servidor_fisico",
	"cyber_tools",
	"bullet_dodge"
]

@onready var views: Dictionary = {
	"MainMenuComponent": main_menu_component,
	"NewGameComponent": new_game_component,
	"LoadingScreenComponent": loading_screen,
	"MinigameMenu": minigame_menu,
	"MinigameFrame": minigame_frame,
	"SaveSlotSelector": save_slot_selector,
}

var current_view: Control = null
var pending_slot_id: int = 0

func _ready() -> void:
	overwrite_modal.visible = false
	delete_modal.visible = false
	_conectar_senales()
	_switch_to_view(main_menu_component)

func _conectar_senales() -> void:
	if main_menu_component.has_signal("new_game_pressed"):
		main_menu_component.new_game_pressed.connect(_on_new_game_pressed)
	if main_menu_component.has_signal("load_game_pressed"):
		main_menu_component.load_game_pressed.connect(_on_load_game_pressed)
	if main_menu_component.has_signal("exit_pressed"):
		main_menu_component.exit_pressed.connect(func(): get_tree().quit())

	if minigame_frame.has_signal("solicitar_montar_pc_3d"):
		minigame_frame.solicitar_montar_pc_3d.connect(_on_solicitar_montar_pc_3d)
	if minigame_frame.has_signal("solicitar_camara_3d"):
		minigame_frame.solicitar_camara_3d.connect(_on_solicitar_camara_3d)
	if minigame_frame.has_signal("minijuego_completado_global"):
		minigame_frame.minijuego_completado_global.connect(_on_minigame_completed)

	if new_game_component.has_signal("character_created"):
		new_game_component.character_created.connect(_on_character_creation_complete)
	if new_game_component.has_signal("canceled"):
		new_game_component.canceled.connect(_on_character_creation_canceled)

	if minigame_menu.has_signal("exit_requested"):
		minigame_menu.exit_requested.connect(_on_minigame_menu_exit)

	# Save Slot Selector
	if save_slot_selector.has_signal("slot_selected"):
		save_slot_selector.slot_selected.connect(_on_slot_selected)
	if save_slot_selector.has_signal("slot_delete_requested"):
		save_slot_selector.slot_delete_requested.connect(_on_slot_delete_requested)
	if save_slot_selector.has_signal("back_pressed"):
		save_slot_selector.back_pressed.connect(_on_slot_selector_back)

	# Modals
	if overwrite_modal.has_signal("confirmed"):
		overwrite_modal.confirmed.connect(_on_overwrite_confirmed)
	if overwrite_modal.has_signal("cancelled"):
		overwrite_modal.cancelled.connect(_on_overwrite_cancelled)
	if delete_modal.has_signal("confirmed"):
		delete_modal.confirmed.connect(_on_delete_confirmed)
	if delete_modal.has_signal("cancelled"):
		delete_modal.cancelled.connect(_on_delete_cancelled)

	EventBus.user_exit.connect(_on_minigame_menu_exit)
	EventBus.minigame_selected.connect(_on_minigame_selected)
	EventBus.menu_changed.connect(_on_menu_changed_requested)

# --- NAVEGACIÓN ---
func _switch_to_view(target_view: Control) -> void:
	current_view = target_view
	for view_name in views:
		views[view_name].visible = (views[view_name] == target_view)
	overwrite_modal.visible = false
	delete_modal.visible = false

func _on_menu_changed_requested(view_name: String) -> void:
	if views.has(view_name):
		_switch_to_view(views[view_name])

# --- FLUJO DE NUEVA PARTIDA ---
func _on_new_game_pressed() -> void:
	save_slot_selector.setup(save_slot_selector.Mode.NEW)
	_switch_to_view(save_slot_selector)

# --- FLUJO DE CARGA ---
func _on_load_game_pressed() -> void:
	save_slot_selector.setup(save_slot_selector.Mode.LOAD)
	_switch_to_view(save_slot_selector)

# --- SLOT SELECTION ---
func _on_slot_selected(slot_id: int) -> void:
	pending_slot_id = slot_id
	if GameManager.slot_exists(slot_id):
		# Partida existente
		if save_slot_selector.mode == save_slot_selector.Mode.NEW:
			# Sobrescribir: mostrar modal
			var info = GameManager.get_slot_info(slot_id)
			var nombre = info.get("player_name", "") + " " + info.get("player_lastname", "")
			overwrite_modal.setup(nombre)
			overwrite_modal.visible = true
		else:
			# Cargar directamente
			_do_load_slot(slot_id)
	else:
		# Ranura vacía
		if save_slot_selector.mode == save_slot_selector.Mode.NEW:
			# Ir a crear personaje
			new_game_component.set_slot_id(slot_id)
			if new_game_component.has_method("reset_form"):
				new_game_component.reset_form()
			_switch_to_view(new_game_component)

func _on_slot_delete_requested(slot_id: int) -> void:
	pending_slot_id = slot_id
	var info = GameManager.get_slot_info(slot_id)
	var nombre = info.get("player_name", "") + " " + info.get("player_lastname", "")
	delete_modal.setup(nombre)
	delete_modal.visible = true

func _on_slot_selector_back() -> void:
	_switch_to_view(main_menu_component)

# --- MODALS ---
func _on_overwrite_confirmed() -> void:
	overwrite_modal.visible = false
	new_game_component.set_slot_id(pending_slot_id)
	if new_game_component.has_method("reset_form"):
		new_game_component.reset_form()
	_switch_to_view(new_game_component)

func _on_overwrite_cancelled() -> void:
	overwrite_modal.visible = false

func _on_delete_confirmed() -> void:
	delete_modal.visible = false
	EventBus.delete_save_requested.emit(pending_slot_id)
	Toast.success("Partida eliminada", "La ranura ha sido borrada")

func _on_delete_cancelled() -> void:
	delete_modal.visible = false

# --- CREACIÓN DE PERSONAJE ---
func _on_character_creation_canceled() -> void:
	_switch_to_view(main_menu_component)

func _on_character_creation_complete(data: Dictionary) -> void:
	var slot_id = new_game_component.get_slot_id()
	var nuevo_save = SaveData.new()
	nuevo_save.player_name = data.get("nombre", "")
	nuevo_save.player_lastname = data.get("apellido", "")
	nuevo_save.player_pnf = data.get("pnf", "")
	nuevo_save.player_role = data.get("rol", "")
	nuevo_save.player_avatar_path = data.get("avatar_path", "")

	EventBus.save_requested.emit(nuevo_save, slot_id)
	_start_game_sequence()

func _do_load_slot(slot_id: int) -> void:
	EventBus.load_requested.emit(slot_id)
	_start_game_sequence()

# --- FLUJO DE MINIJUEGOS ---
func _on_minigame_selected(minigame_id: String, es_3d_custom: bool = false, requiere_camara: bool = false) -> void:
	_switch_to_view(minigame_frame)
	minigame_frame.abrir_minijuego(minigame_id, es_3d_custom, requiere_camara)

func _on_solicitar_montar_pc_3d(id_minijuego: String, escena_ui: PackedScene, config_data: Resource) -> void:
	var mapa_3d = _obtener_mapa_3d_activo()
	if not mapa_3d:
		push_error("No se encontró el mapa 3D activo.")
		return
	if mapa_3d.has_method("inicializar_minijuego_en_mapa"):
		mapa_3d.inicializar_minijuego_en_mapa(id_minijuego, escena_ui, config_data)
	elif "estaciones_mapa" in mapa_3d and mapa_3d.estaciones_mapa.has(id_minijuego):
		var estacion = mapa_3d.estaciones_mapa[id_minijuego]
		if estacion.has_method("cargar_minijuego"):
			estacion.cargar_minijuego(escena_ui, config_data)
		elif estacion.has_method("montar_minijuego"):
			estacion.montar_minijuego(escena_ui, config_data)
	if mapa_3d.has_method("enfocar_interaccion_3d"):
		mapa_3d.enfocar_interaccion_3d(id_minijuego, true)

func _on_solicitar_camara_3d(id_minijuego: String, activar: bool) -> void:
	var mapa_3d = _obtener_mapa_3d_activo()
	if mapa_3d and mapa_3d.has_method("enfocar_interaccion_3d"):
		mapa_3d.enfocar_interaccion_3d(id_minijuego, activar)

func _on_minigame_completed(id_minijuego: String, score_final: int) -> void:
	print("Minijuego ", id_minijuego, " completado con puntaje: ", score_final)

func _on_minigame_menu_exit() -> void:
	if current_view == minigame_frame or minigame_frame.visible:
		_switch_to_view(minigame_menu)
		EventBus.menu_changed.emit("MinigameMenu")
		return
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
