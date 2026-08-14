# res://scripts/ui/minigame_frame.gd
extends Control

signal solicitar_montar_pc_3d(id_minijuego: String, escena_ui: PackedScene, config_data: Resource)
signal solicitar_camara_3d(id_minijuego: String, activar: bool)
signal minijuego_completado_global(id_minijuego: String, score_final: int)

@export_group("Escenas Auxiliares")
@export var modal_tutorial_scene: PackedScene
@export var modal_score_scene: PackedScene 
@export var level_button_scene: PackedScene
@export var marco_contenedor_3d_scene: PackedScene # Asigna res://scenes/.../MarcoContenedor3D.tscn aquí en el Inspector

@export_group("Diccionarios de Configuración")
@export var minigame_scenes_2d: Dictionary = {
	"phishing": "res://scenes/minigames/phishing/minijuego_anti_phishing_updated.tscn",
	"cyber_tools": "res://scenes/minigames/cyber_tools/CyberToolsMemory3D.tscn",
	"bullet_dodge": "res://scenes/minigames/bullet_dodge/BulletDodge3D.tscn",
	"access_control": "res://scenes/minigames/access_control/AccessControl3D.tscn",
	"log_stream": "res://scenes/minigames/log_stream_defender/LogStreamDefender2D.tscn",
	"infrastructure_rush": "res://scenes/minigames/infrastructure_rush/InfrastructureMinigame3D.tscn",
	"soc_td_3d": "res://scenes/minigames/soc_td_3d/soc_td_main.tscn"
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
	],
	"cyber_tools": [
		"res://scripts/data/cyber_tools_levels/tutorial_cyber_tools.tres",
		"res://scripts/data/cyber_tools_levels/nivel_1.tres"
	],
	"bullet_dodge": [
		"res://scripts/data/cyber_tools_levels/tutorial_bullet_dodge.tres",
		"res://scripts/data/cyber_tools_levels/nivel_1.tres"
	],
	"access_control": [
		"res://scripts/data/cyber_tools_levels/tutorial_access_control.tres",
		"res://scripts/data/cyber_tools_levels/nivel_1.tres"
	],
	"log_stream": [
		"res://scripts/data/log_defender_levels/tutorial_log_stream.tres",
		"res://scripts/data/log_defender_levels/nivel_1.tres"
	],
	"infrastructure_rush": [
		"res://scripts/data/topologia_levels/tutorial_infrastructure_rush.tres",
		"res://scripts/data/topologia_levels/nivel_1_fase_topologia.tres",
		"res://scripts/data/topologia_levels/nivel_2_fase_bastionado.tres",
		"res://scripts/data/topologia_levels/nivel_3_integrado.tres",
		"res://scripts/data/topologia_levels/nivel_4_fase_topologia.tres",
		"res://scripts/data/topologia_levels/nivel_5_fase_bastionado.tres",
		"res://scripts/data/topologia_levels/nivel_6_fase_integrado.tres"
	],
	"soc_td_3d": [
		"res://scripts/data/soc_td_levels/tutorial_soc_td.tres",
		"res://scripts/data/soc_td_levels/nivel_1.tres"
	]
}

# Nodos UI Generales
@onready var color_rect_fondo: ColorRect = $ColorRectFondo
@onready var container_2d: Control = $PlayArea/PanelContainer/Container2D
@onready var menu_niveles: Control = $MenuNiveles
@onready var grid_niveles: GridContainer = $MenuNiveles/ScrollContainer/GridContainer
@onready var modal_container: Control = $ModalContainer

# Nodos HUD & BottomBar
@onready var hud: Control = $HUD
@onready var lbl_timer: Label = $HUD/BottomBar/MarginContainer/HBoxContainer/StatsWidget/HBoxContainer/LblTimer
@onready var lbl_score: Label = $HUD/BottomBar/MarginContainer/HBoxContainer/StatsWidget/HBoxContainer/LblScore

@onready var btn_pausa: Button = $HUD/BottomBar/MarginContainer/HBoxContainer/ControlesNavegacion/BtnPausa
@onready var btn_anterior: Button = $HUD/BottomBar/MarginContainer/HBoxContainer/ControlesNavegacion/BtnAnterior
@onready var btn_siguiente: Button = $HUD/BottomBar/MarginContainer/HBoxContainer/ControlesNavegacion/BtnSiguiente
@onready var btn_tutorial: Button = $HUD/BottomBar/MarginContainer/HBoxContainer/ControlesNavegacion/BtnTutorial

@onready var btn_volver_menu: Button = $BtnSalir if has_node("BtnSalir") else null

# Variables del Estado
var timer_arcade: Timer
var minijuego_id_actual: String = ""
var indice_nivel_actual: int = 0
var score_actual: int = 0
var en_partida_activa: bool = false
var puzzle_actual: Node = null
var es_minijuego_en_mundo_3d: bool = false
var requiere_camara_3d: bool = false

func _ready() -> void:
	timer_arcade = Timer.new()
	timer_arcade.one_shot = true
	timer_arcade.timeout.connect(_on_tiempo_agotado)
	add_child(timer_arcade)

	# Conexión de Botones de la BottomBar
	if btn_pausa: btn_pausa.pressed.connect(_on_salir_pressed)
	if btn_anterior: btn_anterior.pressed.connect(_on_nivel_anterior_pressed)
	if btn_siguiente: btn_siguiente.pressed.connect(_on_nivel_siguiente_pressed)
	if btn_tutorial: btn_tutorial.pressed.connect(_on_tutorial_pressed)
	
	if btn_volver_menu: 
		btn_volver_menu.pressed.connect(_on_volver_menu_pressed)
		
	if EventBus.has_signal("puntos_actualizados"):
		EventBus.puntos_actualizados.connect(_on_puntos_actualizados)
		
	if lbl_score:
		lbl_score.pivot_offset = lbl_score.size / 2.0
		
	_limpiar_pantalla()

func _process(_delta: float) -> void:
	if en_partida_activa and not timer_arcade.is_stopped():
		var tiempo_restante = ceil(timer_arcade.time_left)
		if lbl_timer:
			lbl_timer.text = "⏱️ %02ds" % int(tiempo_restante)

# --- 1. APERTURA Y SELECCIÓN DE NIVELES ---
func abrir_minijuego(id_minijuego: String, es_en_mundo_3d: bool = false, enfocar_camara: bool = false) -> void:
	minijuego_id_actual = id_minijuego
	es_minijuego_en_mundo_3d = es_en_mundo_3d
	requiere_camara_3d = enfocar_camara
	show()
	_mostrar_grid_niveles()

func _mostrar_grid_niveles() -> void:
	_detener_partida()
	_limpiar_pantalla()
	
	show()
	menu_niveles.show()
	if btn_volver_menu: btn_volver_menu.show()
	
	if requiere_camara_3d or es_minijuego_en_mundo_3d:
		_animar_fade_fondo(false)
		solicitar_camara_3d.emit(minijuego_id_actual, true)
	else:
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

	_animar_botones_grid(botones_creados)

func _cargar_nivel_por_indice(idx: int) -> void:
	indice_nivel_actual = idx
	var rutas = level_data_resources.get(minijuego_id_actual, [])
	
	if idx < 0 or idx >= rutas.size():
		_mostrar_grid_niveles()
		return

	_actualizar_estado_botones_navegacion()

	var res_data = load(rutas[idx])
	if res_data is NivelTutorialData:
		_iniciar_tutorial(res_data)
	elif res_data is NivelArcadeData:
		_iniciar_partida_arcade(res_data)

func _actualizar_estado_botones_navegacion() -> void:
	var rutas_disp = level_data_resources.get(minijuego_id_actual, [])
	if btn_anterior:
		btn_anterior.disabled = (indice_nivel_actual <= 0)
	if btn_siguiente:
		btn_siguiente.disabled = (indice_nivel_actual >= rutas_disp.size() - 1)

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

# --- 3. LÓGICA DE GAMEPLAY ADAPTADA AL MARCO ---
func _iniciar_partida_arcade(data: NivelArcadeData) -> void:
	_limpiar_pantalla()
	menu_niveles.hide()
	if btn_volver_menu: btn_volver_menu.hide()
	
	score_actual = 0
	_actualizar_score_ui(false)
	hud.show()

	if not minigame_scenes_2d.has(minijuego_id_actual):
		push_error("No hay escena asignada para: " + minijuego_id_actual)
		return

	var esc_path: String = minigame_scenes_2d[minijuego_id_actual]
	var escena_recurso: PackedScene = load(esc_path) as PackedScene
	
	if not escena_recurso:
		push_error("No se pudo cargar la escena en: " + esc_path)
		return

	_animar_fade_fondo(true)

	var puzzle: Node = null

	if es_minijuego_en_mundo_3d:
		# Instanciamos el marco visual si se asignó en la export variable, sino usamos el nodo existente si está precargado
		var marco_instancia: Control = null
		if marco_contenedor_3d_scene:
			marco_instancia = marco_contenedor_3d_scene.instantiate()
			container_2d.add_child(marco_instancia)
		elif container_2d.has_node("MarcoContenedor3D"):
			marco_instancia = container_2d.get_node("MarcoContenedor3D")
			marco_instancia.show()

		if not marco_instancia:
			push_error("No se encontró 'MarcoContenedor3D'. Asigna la escena en el Inspector o añádelo como hijo de Container2D.")
			return

		# Navegamos por la jerarquía exacta vista en tu editor: MarcoContenedor3D -> VBox -> MarginContainer -> SubViewportContainer -> SubViewport
		var sub_viewport: SubViewport = marco_instancia.get_node_or_null("VBox/MarginContainer/SubViewportContainer/SubViewport")
		
		if not sub_viewport:
			push_error("No se encontró el SubViewport en la ruta 'VBox/MarginContainer/SubViewportContainer/SubViewport'")
			return

		# Aislamiento del mundo 3D y configuración de picking de físicas.
		# El SubViewport de MarcoContenedor3D ya viene con own_world_3d = true,
		# así que no reasignamos world_3d (recrearlo aquí produce un error de
		# "scenario is null" en el servidor de renderizado).
		sub_viewport.own_world_3d = true
		sub_viewport.physics_object_picking = true
		sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

		# Actualizamos el título del marco si existe el nodo Titulo
		var lbl_titulo = marco_instancia.get_node_or_null("VBox/Titulo") as Label
		if lbl_titulo and "titulo" in data:
			lbl_titulo.text = data.titulo

		puzzle = escena_recurso.instantiate()
		sub_viewport.add_child(puzzle)
	else:
		# Si es un minijuego 2D normal
		puzzle = escena_recurso.instantiate()
		container_2d.add_child(puzzle)

	puzzle_actual = puzzle

	# CONEXIÓN DE SEÑALES Y MÉTODOS ESTÁNDAR
	if puzzle.has_signal("minijuego_completado"):
		puzzle.minijuego_completado.connect(func(puntos_finales: int):
			score_actual = puntos_finales
			_actualizar_score_ui()
			_on_tiempo_agotado()
		, CONNECT_ONE_SHOT)

	if puzzle.has_method("inicializar_minijuego"):
		puzzle.inicializar_minijuego(data)
	elif puzzle.has_method("cargar_nivel"):
		puzzle.cargar_nivel(data)

	en_partida_activa = true
	timer_arcade.start(data.tiempo_limite)

# --- 4. CONTROL DE NAVEGACIÓN BOTTOMBAR ---
func _on_nivel_anterior_pressed() -> void:
	if indice_nivel_actual > 0:
		_cargar_nivel_por_indice(indice_nivel_actual - 1)

func _on_nivel_siguiente_pressed() -> void:
	var rutas = level_data_resources.get(minijuego_id_actual, [])
	if indice_nivel_actual < rutas.size() - 1:
		_cargar_nivel_por_indice(indice_nivel_actual + 1)

func _on_tutorial_pressed() -> void:
	var rutas = level_data_resources.get(minijuego_id_actual, [])
	if rutas.size() > 0:
		var res_data = load(rutas[0])
		if res_data is NivelTutorialData:
			_detener_partida()
			_iniciar_tutorial(res_data)

# --- 5. CONTROL DE PUNTOS Y TIEMPO ---
func _on_puntos_actualizados(puntos: int) -> void:
	score_actual = puntos
	_actualizar_score_ui(true)

func _actualizar_score_ui(animar: bool = true) -> void:
	if lbl_score:
		lbl_score.text = "⭐ %d PTS" % score_actual
		if animar:
			lbl_score.pivot_offset = lbl_score.size / 2.0
			var tween = create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
			tween.tween_property(lbl_score, "scale", Vector2(1.2, 1.2), 0.1)
			tween.tween_property(lbl_score, "scale", Vector2.ONE, 0.12)

func _on_tiempo_agotado() -> void:
	_detener_partida()
	minijuego_completado_global.emit(minijuego_id_actual, score_actual)
	if EventBus.has_signal("minigame_completed"):
		EventBus.minigame_completed.emit(minijuego_id_actual, indice_nivel_actual, score_actual, true)
		
	_mostrar_popup_resultado()

# --- 6. POPUP DE RESULTADOS Y ANIMACIONES ---
func _mostrar_popup_resultado() -> void:
	hud.hide()
	
	if not modal_score_scene:
		push_error("No se ha asignado 'modal_score_scene' en el Inspector.")
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
	node.pivot_offset = node.size / 2.0
	node.modulate.a = 0.0
	node.scale = Vector2(0.7, 0.7)
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, 0.4)
	tween.tween_property(node, "scale", Vector2.ONE, 0.45)

func _animar_botones_grid(botones: Array[Control]) -> void:
	for i in range(botones.size()):
		var btn = botones[i]
		btn.modulate.a = 0.0
		btn.scale = Vector2(0.85, 0.85)
		
		await get_tree().process_frame
		btn.pivot_offset = btn.size / 2.0
		var delay = i * 0.1
		
		var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tween.tween_property(btn, "modulate:a", 1.0, 0.4).set_delay(delay)
		tween.tween_property(btn, "scale", Vector2.ONE, 0.4).set_delay(delay)

func _animar_fade_fondo(mostrar: bool) -> void:
	var target_alpha = 1.0 if mostrar else 0.0
	if mostrar: color_rect_fondo.show()
	
	var tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(color_rect_fondo, "modulate:a", target_alpha, 0.35)
	
	if not mostrar:
		tween.tween_callback(color_rect_fondo.hide)

# --- 7. LIMPIEZA Y SALIDA ---
func _detener_partida() -> void:
	en_partida_activa = false
	timer_arcade.stop()

	# Detiene el minijuego en curso (si tiene detener_partida) para que
	# sus logs/spawners dejen de correr y dejen de quitar puntos tras terminar.
	if is_instance_valid(puzzle_actual) and puzzle_actual.has_method("detener_partida"):
		puzzle_actual.detener_partida()
	puzzle_actual = null

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
	if requiere_camara_3d or es_minijuego_en_mundo_3d:
		solicitar_camara_3d.emit(minijuego_id_actual, false)

	_detener_partida()
	_limpiar_pantalla()
	hide()
	
	if EventBus.has_signal("user_exit"):
		EventBus.user_exit.emit()
