# ScoreViewer.gd
extends Control

signal back_pressed

const MINIGAME_DISPLAY_NAMES: Dictionary = {
	
	"infrastructure_rush": "INFRAESTRUCTURA TECNOLOGICA",
	"phishing": "TIENDA DE TRANSACCIONES",
	"cyber_tools": "CYBERTOOLS",
	"access_control": "CONTROL DE INTERFACES",
	"log_stream": "TRAFICO DE RED",
	"soc_td_3d": "SISTEMA DE AMENAZAS"
}

const MINIGAME_LEVEL_NAMES: Dictionary = {
	
	"phishing": ["Tutorial Phishing", "Nivel 1 Phishing"],
	"cyber_tools": ["Tutorial CyberTools", "Nivel 1"],
	"access_control": ["Tutorial Access Control", "Nivel 1"],
	"log_stream": ["Tutorial Log Stream", "Nivel 1"],
	"infrastructure_rush": [
		"Tutorial",
		"Nivel 1 - Topologia Basica",
		"Nivel 2 - Segmentation con Switch",
		"Nivel 3 - Topologia Red de Areas",
		"Nivel 4 - Bastionado Basico",
		"Nivel 5 - Bastionado con Switch",
		"Nivel 6 - Bastionado Avanzado",
		"Nivel 7 - Integrado Basico",
		"Nivel 8 - Integrado DMZ",
		"Nivel 9 - Integrado Redundancia",
		"Nivel 10 - Red Empresarial",
		"Nivel 11 - Arquitectura Tres Capas",
		"Nivel 12 - Capstone Empresarial"
	],
	"soc_td_3d": ["Tutorial SOC TD", "Nivel 1"]
}

const CYAN := Color(0.0809, 0.8983, 1.0, 1.0)
const CYAN_DIM := Color(0.0809, 0.8983, 1.0, 0.6)
const GOLD := Color(1.0, 0.75, 0.0, 1.0)
const GOLD_DIM := Color(1.0, 0.75, 0.0, 0.6)
const GREEN := Color(0.2, 0.9, 0.4, 1.0)
const WHITE := Color.WHITE
const GRAY := Color(0.5, 0.55, 0.57, 0.8)

var font_bold: FontFile
var font_display: FontFile

@onready var containerPrincipal: VBoxContainer = $PanelContainer/VBoxContainer
@onready var lbl_titulo: Label = $PanelContainer/VBoxContainer/LblTitulo
@onready var scroll_container: ScrollContainer = $PanelContainer/VBoxContainer/ScrollContainer
@onready var container_contenido: VBoxContainer = $PanelContainer/VBoxContainer/ScrollContainer/ContainerContenido
@onready var btn_volver: Button = $PanelContainer/VBoxContainer/HBoxBotones/BtnVolver

var vista_actual: String = "lista" # "lista" o "detalle"
var minigame_seleccionado: String = ""

func _ready() -> void:
	font_bold = load("res://assets/fonts/RobotoMono-Bold.ttf")
	font_display = load("res://assets/fonts/Orbitron-Black.ttf")
	btn_volver.pressed.connect(_on_volver_pressed)
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if not visible:
		return
	vista_actual = "lista"
	minigame_seleccionado = ""
	_actualizar_ui()

func _actualizar_ui() -> void:
	if vista_actual == "lista":
		_mostrar_lista_minijuegos()
	else:
		_mostrar_detalle_minijuego(minigame_seleccionado)

func _mostrar_lista_minijuegos() -> void:
	lbl_titulo.text = "PUNTUACIONES"
	lbl_titulo.add_theme_font_override("font", font_display)
	lbl_titulo.add_theme_font_size_override("font_size", 28)
	lbl_titulo.add_theme_color_override("font_color", CYAN)
	lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	btn_volver.text = "Volver"

	_limpiar_contenido()

	for minigame_id in MINIGAME_DISPLAY_NAMES:
		var card = _crear_card_minijuego(minigame_id)
		container_contenido.add_child(card)

func _crear_card_minijuego(minigame_id: String) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 70)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.04, 0.10, 0.7)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = CYAN_DIM
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)

	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)

	var lbl_nombre = Label.new()
	lbl_nombre.text = MINIGAME_DISPLAY_NAMES[minigame_id]
	lbl_nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_nombre.add_theme_font_override("font", font_bold)
	lbl_nombre.add_theme_font_size_override("font_size", 14)
	lbl_nombre.add_theme_color_override("font_color", WHITE)
	hbox.add_child(lbl_nombre)

	var lbl_score = Label.new()
	var best_score = GameManager.get_high_score(minigame_id)
	lbl_score.text = str(best_score) + " PTS"
	lbl_score.add_theme_font_override("font", font_display)
	lbl_score.add_theme_font_size_override("font_size", 16)
	lbl_score.add_theme_color_override("font_color", GOLD if best_score > 0 else GRAY)
	hbox.add_child(lbl_score)

	var lbl_flecha = Label.new()
	lbl_flecha.text = " >"
	lbl_flecha.add_theme_font_override("font", font_bold)
	lbl_flecha.add_theme_font_size_override("font_size", 16)
	lbl_flecha.add_theme_color_override("font_color", CYAN_DIM)
	hbox.add_child(lbl_flecha)

	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			vista_actual = "detalle"
			minigame_seleccionado = minigame_id
			_actualizar_ui()
	)

	panel.mouse_entered.connect(func():
		style.border_color = CYAN
		style.bg_color = Color(0.02, 0.06, 0.14, 0.8)
	)
	panel.mouse_exited.connect(func():
		style.border_color = CYAN_DIM
		style.bg_color = Color(0.01, 0.04, 0.10, 0.7)
	)

	return panel

func _mostrar_detalle_minijuego(minigame_id: String) -> void:
	var display_name = MINIGAME_DISPLAY_NAMES.get(minigame_id, minigame_id)
	lbl_titulo.text = display_name
	lbl_titulo.add_theme_font_override("font", font_display)
	lbl_titulo.add_theme_font_size_override("font_size", 22)
	lbl_titulo.add_theme_color_override("font_color", CYAN)
	lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	btn_volver.text = "< Atras"

	_limpiar_contenido()

	var progreso = GameManager.save_data.minigames_progreso.get(minigame_id, {})
	var high_scores = progreso.get("high_scores", {})
	var max_level = progreso.get("max_level_unlocked", 1)
	var level_names = MINIGAME_LEVEL_NAMES.get(minigame_id, [])

	for i in range(level_names.size()):
		var level_name = level_names[i]
		var level_key = str(i)
		var score = high_scores.get(level_key, 0)
		var is_unlocked = (i + 1) <= max_level

		var row = _crear_row_nivel(level_name, score, is_unlocked, i + 1)
		container_contenido.add_child(row)

	var total_score = GameManager.get_high_score(minigame_id)
	var total_label = Label.new()
	total_label.text = "MEJOR PUNTUACION: " + str(total_score) + " PTS"
	total_label.add_theme_font_override("font", font_display)
	total_label.add_theme_font_size_override("font_size", 18)
	total_label.add_theme_color_override("font_color", GOLD if total_score > 0 else GRAY)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_label.custom_minimum_size = Vector2(0, 40)
	container_contenido.add_child(total_label)

func _crear_row_nivel(level_name: String, score: int, is_unlocked: bool, level_num: int) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 50)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.04, 0.10, 0.5) if is_unlocked else Color(0.01, 0.02, 0.05, 0.3)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = CYAN_DIM if is_unlocked else Color(0.2, 0.25, 0.27, 0.3)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)

	var lbl_nivel = Label.new()
	lbl_nivel.text = "Nivel " + str(level_num)
	lbl_nivel.custom_minimum_size = Vector2(90, 0)
	lbl_nivel.add_theme_font_override("font", font_bold)
	lbl_nivel.add_theme_font_size_override("font_size", 13)
	lbl_nivel.add_theme_color_override("font_color", CYAN if is_unlocked else GRAY)
	hbox.add_child(lbl_nivel)

	var lbl_nombre = Label.new()
	lbl_nombre.text = level_name
	lbl_nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_nombre.add_theme_font_override("font", font_bold)
	lbl_nombre.add_theme_font_size_override("font_size", 13)
	lbl_nombre.add_theme_color_override("font_color", WHITE if is_unlocked else GRAY)
	hbox.add_child(lbl_nombre)

	var lbl_puntos = Label.new()
	if is_unlocked:
		lbl_puntos.text = str(score) + " PTS"
		lbl_puntos.add_theme_color_override("font_color", GOLD if score > 0 else GRAY)
	else:
		lbl_puntos.text = "BLOQUEADO"
		lbl_puntos.add_theme_color_override("font_color", Color(0.4, 0.15, 0.15, 0.8))
	lbl_puntos.add_theme_font_override("font", font_display)
	lbl_puntos.add_theme_font_size_override("font_size", 14)
	hbox.add_child(lbl_puntos)

	return panel

func _limpiar_contenido() -> void:
	for child in container_contenido.get_children():
		child.queue_free()

func _on_volver_pressed() -> void:
	if vista_actual == "detalle":
		vista_actual = "lista"
		minigame_seleccionado = ""
		_actualizar_ui()
	else:
		back_pressed.emit()
