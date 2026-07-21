# res://scenes/minigames/configuracion/cable_puzzle.gd
extends Control

signal nivel_completado
signal salir_solicitado

@export var nivel_data: NivelConfigData

@onready var contenedor_nodos: Control = $ContenedorNodos
@onready var contenedor_cables: Control = $ContenedorCables
@onready var cable_en_proceso: Line2D = $CableEnProceso
@onready var briefing_modal: Control = $BriefingModal
@onready var btn_validar: Button = $UIHeader/BtnValidar
@onready var btn_volver: Button = $UIHeader/BtnVolver
@onready var btn_reiniciar: Button = $UIHeader/BtnReiniciar
@onready var btn_ver_enunciado: Button = $UIHeader/BtnVerEnunciado
@onready var btn_info: Button = $UIHeader/BtnInfo

var nodo_origen_seleccionado: Button = null
var conexiones_actuales: Array[Dictionary] = []
var victoria_alcanzada: bool = false

var color_seleccionado: String = "AZUL"
var colores_map: Dictionary = {
	"AZUL": Color.DODGER_BLUE,
	"ROJO": Color.CRIMSON,
	"VERDE": Color.GREEN,
	"AMARILLO": Color.GOLD
}
var label_color_actual: Label
var panel_info: PanelContainer
var panel_info_visible: bool = false
var vbox_panel_info: VBoxContainer

# Fuentes del proyecto
var font_bold: FontFile
var font_display: FontFile

# Paleta de colores del proyecto
const CYAN := Color(0.0809, 0.8983, 1.0, 1.0)
const CYAN_TEAL := Color(0.0, 0.909, 0.9412, 1.0)
const BG_OSCURO := Color(0.0059, 0.0805, 0.1776, 0.659)
const BG_PANEL := Color(0.0154, 0.0275, 0.0995, 0.549)
const BG_NODOS := Color(0.0, 0.0728, 0.1869, 0.667)
const BG_INPUT := Color(0.1176, 0.1843, 0.2392, 1.0)
const ROJO := Color(1, 0, 0, 1)
const BG_ROJO := Color(0.6863, 0, 0.0353, 0.3098)
const VERDE := Color(1.21e-5, 0.963, 0.2894, 1.0)
const BG_VERDE := Color(0.0039, 0.2549, 0, 0.482)
const TEXTO_CYAN := Color(0.4128, 0.8566, 0.8717, 1.0)
const TEXTO_BLANCO := Color.WHITE
const TEXTO_GRIS := Color(0.7, 0.7, 0.7)

func _ready() -> void:
	font_bold = load("res://assets/fonts/RobotoMono-Bold.ttf")
	font_display = load("res://assets/fonts/Orbitron-Black.ttf")
	
	cable_en_proceso.hide()
	btn_validar.pressed.connect(_validar_conexiones)
	btn_volver.pressed.connect(func(): salir_solicitado.emit())
	
	if btn_reiniciar:
		btn_reiniciar.pressed.connect(reiniciar_cables)
		
	briefing_modal.modal_closed.connect(_on_briefing_closed)
	_crear_selector_color()
	_crear_panel_info()
	_aplicar_estilos_header()
	
	btn_ver_enunciado.pressed.connect(_mostrar_enunciado)
	btn_info.pressed.connect(_toggle_panel_info)
	
	if nivel_data:
		cargar_nivel(nivel_data)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancelar_trazado_actual()
	
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _seleccionar_color("AZUL")
			KEY_2: _seleccionar_color("ROJO")
			KEY_3: _seleccionar_color("VERDE")
			KEY_4: _seleccionar_color("AMARILLO")

func cargar_nivel(data: NivelConfigData) -> void:
	nivel_data = data
	victoria_alcanzada = false
	color_seleccionado = "AZUL"
	panel_info_visible = false
	if panel_info:
		panel_info.hide()
	_actualizar_label_color()
	_limpiar_tablero()
	_generar_nodos_ui()
	briefing_modal.setup_briefing(nivel_data)

# --- ESTILOS ---

func _crear_style_button(bg: Color, border: Color, corner: int = 5, margin: int = 8) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(corner)
	s.set_content_margin_all(margin)
	return s

func _aplicar_estilos_header() -> void:
	# Salir -> rojo
	var sSalir = _crear_style_button(BG_ROJO, ROJO, 5, 8)
	btn_volver.add_theme_stylebox_override("normal", sSalir)
	btn_volver.add_theme_stylebox_override("hover", sSalir)
	btn_volver.add_theme_stylebox_override("pressed", sSalir)
	btn_volver.add_theme_font_override("font", font_bold)
	btn_volver.add_theme_font_size_override("font_size", 14)
	btn_volver.add_theme_color_override("font_color", TEXTO_BLANCO)
	btn_volver.add_theme_color_override("font_hover_color", TEXTO_BLANCO)
	
	# Reiniciar -> cyan
	var sCyan = _crear_style_button(BG_OSCURO, CYAN, 5, 8)
	btn_reiniciar.add_theme_stylebox_override("normal", sCyan)
	btn_reiniciar.add_theme_stylebox_override("hover", sCyan)
	btn_reiniciar.add_theme_stylebox_override("pressed", sCyan)
	btn_reiniciar.add_theme_font_override("font", font_bold)
	btn_reiniciar.add_theme_font_size_override("font_size", 14)
	btn_reiniciar.add_theme_color_override("font_color", TEXTO_BLANCO)
	btn_reiniciar.add_theme_color_override("font_hover_color", TEXTO_BLANCO)
	
	# Validar -> verde
	var sVerde = _crear_style_button(BG_VERDE, VERDE, 5, 8)
	btn_validar.add_theme_stylebox_override("normal", sVerde)
	btn_validar.add_theme_stylebox_override("hover", sVerde)
	btn_validar.add_theme_stylebox_override("pressed", sVerde)
	btn_validar.add_theme_font_override("font", font_bold)
	btn_validar.add_theme_font_size_override("font_size", 14)
	btn_validar.add_theme_color_override("font_color", TEXTO_BLANCO)
	btn_validar.add_theme_color_override("font_hover_color", TEXTO_BLANCO)
	
	# Enunciado -> cyan
	btn_ver_enunciado.add_theme_stylebox_override("normal", sCyan)
	btn_ver_enunciado.add_theme_stylebox_override("hover", sCyan)
	btn_ver_enunciado.add_theme_stylebox_override("pressed", sCyan)
	btn_ver_enunciado.add_theme_font_override("font", font_bold)
	btn_ver_enunciado.add_theme_font_size_override("font_size", 14)
	btn_ver_enunciado.add_theme_color_override("font_color", TEXTO_BLANCO)
	btn_ver_enunciado.add_theme_color_override("font_hover_color", TEXTO_BLANCO)
	
	# Info -> cyan
	btn_info.add_theme_stylebox_override("normal", sCyan)
	btn_info.add_theme_stylebox_override("hover", sCyan)
	btn_info.add_theme_stylebox_override("pressed", sCyan)
	btn_info.add_theme_font_override("font", font_bold)
	btn_info.add_theme_font_size_override("font_size", 14)
	btn_info.add_theme_color_override("font_color", TEXTO_BLANCO)
	btn_info.add_theme_color_override("font_hover_color", TEXTO_BLANCO)

func _crear_estilo_nodo() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = BG_NODOS
	s.border_color = CYAN_TEAL
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(10)
	s.set_expand_margin_all(2)
	return s

func _crear_estilo_nodo_hover() -> StyleBoxFlat:
	var s = _crear_estilo_nodo()
	s.border_color = CYAN
	s.bg_color = Color(0.0, 0.10, 0.22, 0.75)
	return s

# --- SELECTOR DE COLOR ---

func _crear_selector_color() -> void:
	label_color_actual = Label.new()
	label_color_actual.position = Vector2(14, 14)
	label_color_actual.text = "Cable: AZUL [1-4]"
	label_color_actual.add_theme_font_override("font", font_bold)
	label_color_actual.add_theme_font_size_override("font_size", 14)
	label_color_actual.add_theme_color_override("font_color", Color.DODGER_BLUE)
	add_child(label_color_actual)

func _seleccionar_color(nombre: String) -> void:
	if colores_map.has(nombre):
		color_seleccionado = nombre
		_actualizar_label_color()

func _actualizar_label_color() -> void:
	if label_color_actual:
		label_color_actual.text = "Cable: " + color_seleccionado + " [1-4]"
		label_color_actual.add_theme_color_override("font_color", colores_map[color_seleccionado])

func _mostrar_enunciado() -> void:
	if nivel_data:
		briefing_modal.setup_briefing(nivel_data)

func _on_briefing_closed() -> void:
	if briefing_modal.es_debriefing and victoria_alcanzada:
		nivel_completado.emit()

# --- PANEL DE INFO ---

func _toggle_panel_info() -> void:
	panel_info_visible = not panel_info_visible
	if panel_info_visible:
		_actualizar_panel_info()
		panel_info.show()
	else:
		panel_info.hide()

func _crear_panel_info() -> void:
	panel_info = PanelContainer.new()
	panel_info.position = Vector2(910, 14)
	panel_info.custom_minimum_size = Vector2(228, 0)
	
	var style = StyleBoxFlat.new()
	style.bg_color = BG_PANEL
	style.border_color = CYAN
	style.set_border_width_all(2)
	style.set_corner_radius_all(15)
	style.set_content_margin_all(14)
	style.set_expand_margin_all(4)
	panel_info.add_theme_stylebox_override("panel", style)
	
	vbox_panel_info = VBoxContainer.new()
	vbox_panel_info.add_theme_constant_override("separation", 8)
	panel_info.add_child(vbox_panel_info)
	add_child(panel_info)
	panel_info.hide()

func _actualizar_panel_info() -> void:
	for child in vbox_panel_info.get_children():
		child.queue_free()
	
	if not nivel_data:
		return
	
	# Título
	var titulo = Label.new()
	titulo.text = "INFORMACIÓN DE LA MISIÓN"
	titulo.add_theme_font_override("font", font_display)
	titulo.add_theme_font_size_override("font_size", 13)
	titulo.add_theme_color_override("font_color", TEXTO_CYAN)
	vbox_panel_info.add_child(titulo)
	
	var sep1 = HSeparator.new()
	sep1.add_theme_stylebox_override("separator", _crear_linea_separadora())
	vbox_panel_info.add_child(sep1)
	
	# Tipos de cable requeridos
	var cable_label = Label.new()
	cable_label.text = "CABLES NECESARIOS"
	cable_label.add_theme_font_override("font", font_bold)
	cable_label.add_theme_font_size_override("font_size", 12)
	cable_label.add_theme_color_override("font_color", TEXTO_CYAN)
	vbox_panel_info.add_child(cable_label)
	
	var cables_requeridos: Dictionary = {}
	for conex in nivel_data.conexiones_requeridas:
		cables_requeridos[conex["cable"]] = true
	
	for cable_nombre in cables_requeridos:
		var lbl = Label.new()
		lbl.text = "  ● " + cable_nombre
		lbl.add_theme_font_override("font", font_bold)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", colores_map[cable_nombre])
		vbox_panel_info.add_child(lbl)
	
	var sep2 = HSeparator.new()
	sep2.add_theme_stylebox_override("separator", _crear_linea_separadora())
	vbox_panel_info.add_child(sep2)
	
	# Resumen de la red
	var resumen_label = Label.new()
	resumen_label.text = "RESUMEN DE RED"
	resumen_label.add_theme_font_override("font", font_bold)
	resumen_label.add_theme_font_size_override("font_size", 12)
	resumen_label.add_theme_color_override("font_color", TEXTO_CYAN)
	vbox_panel_info.add_child(resumen_label)
	
	var conex_label = Label.new()
	conex_label.text = "  Conexiones: " + str(nivel_data.conexiones_requeridas.size())
	conex_label.add_theme_font_override("font", font_bold)
	conex_label.add_theme_font_size_override("font_size", 12)
	conex_label.add_theme_color_override("font_color", TEXTO_BLANCO)
	vbox_panel_info.add_child(conex_label)
	
	var nodos_label = Label.new()
	nodos_label.text = "  Nodos en red: " + str(nivel_data.nodos_disponibles.size())
	nodos_label.add_theme_font_override("font", font_bold)
	nodos_label.add_theme_font_size_override("font_size", 12)
	nodos_label.add_theme_color_override("font_color", TEXTO_BLANCO)
	vbox_panel_info.add_child(nodos_label)
	
	var sep3 = HSeparator.new()
	sep3.add_theme_stylebox_override("separator", _crear_linea_separadora())
	vbox_panel_info.add_child(sep3)
	
	# Controles
	var ctrl_label = Label.new()
	ctrl_label.text = "CONTROLES"
	ctrl_label.add_theme_font_override("font", font_bold)
	ctrl_label.add_theme_font_size_override("font_size", 12)
	ctrl_label.add_theme_color_override("font_color", TEXTO_CYAN)
	vbox_panel_info.add_child(ctrl_label)
	
	var controles = [
		"Clic izq → Conectar nodos",
		"Clic der → Borrar cable",
		"Click der fondo → Cancelar",
		"Teclas 1-4 → Cambiar cable",
		"Reiniciar → Limpiar todo"
	]
	for ctrl in controles:
		var lbl = Label.new()
		lbl.text = "  • " + ctrl
		lbl.add_theme_font_override("font", font_bold)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", TEXTO_GRIS)
		vbox_panel_info.add_child(lbl)

func _crear_linea_separadora() -> StyleBoxLine:
	var s = StyleBoxLine.new()
	s.color = Color(0.2, 0.4, 0.6, 0.4)
	s.thickness = 1
	return s

# --- NODOS DEL PUZZLE ---

func _generar_nodos_ui() -> void:
	for nodo in nivel_data.nodos_disponibles:
		var btn = Button.new()
		btn.text = nodo["id"] + "\n(" + nodo["tipo"] + ")"
		btn.position = nodo["posicion"]
		btn.custom_minimum_size = Vector2(130, 64)
		btn.set_meta("id", nodo["id"])
		
		# Estilo del nodo
		btn.add_theme_stylebox_override("normal", _crear_estilo_nodo())
		btn.add_theme_stylebox_override("hover", _crear_estilo_nodo_hover())
		btn.add_theme_stylebox_override("pressed", _crear_estilo_nodo())
		btn.add_theme_font_override("font", font_bold)
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", TEXTO_BLANCO)
		btn.add_theme_color_override("font_hover_color", CYAN)
		
		btn.gui_input.connect(func(event): _on_nodo_gui_input(event, btn))
		contenedor_nodos.add_child(btn)

func _on_nodo_gui_input(event: InputEvent, btn: Button) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_nodo_clicked(btn)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_eliminar_conexiones_de_nodo(btn.get_meta("id"))

func _on_nodo_clicked(btn: Button) -> void:
	if nodo_origen_seleccionado == null:
		nodo_origen_seleccionado = btn
		cable_en_proceso.clear_points()
		
		var centro_origen = _get_node_center(btn)
		cable_en_proceso.add_point(centro_origen)
		cable_en_proceso.add_point(contenedor_cables.get_local_mouse_position())
		cable_en_proceso.show()
	else:
		if nodo_origen_seleccionado != btn:
			_crear_conexion(nodo_origen_seleccionado, btn)
		_cancelar_trazado_actual()

func _process(_delta: float) -> void:
	if nodo_origen_seleccionado and cable_en_proceso.visible:
		cable_en_proceso.set_point_position(1, contenedor_cables.get_local_mouse_position())

func _get_node_center(btn: Button) -> Vector2:
	var global_center = btn.global_position + (btn.size / 2.0)
	return contenedor_cables.get_global_transform().affine_inverse() * global_center

func _crear_conexion(origen: Button, destino: Button) -> void:
	var id_origen = origen.get_meta("id")
	var id_destino = destino.get_meta("id")
	
	for conex in conexiones_actuales:
		if (conex["origen"] == id_origen and conex["destino"] == id_destino) or \
		   (conex["origen"] == id_destino and conex["destino"] == id_origen):
			return

	var linea = Line2D.new()
	linea.width = 6.0
	linea.default_color = colores_map[color_seleccionado]
	linea.add_point(_get_node_center(origen))
	linea.add_point(_get_node_center(destino))
	
	contenedor_cables.add_child(linea)
	
	conexiones_actuales.append({
		"origen": id_origen,
		"destino": id_destino,
		"cable": color_seleccionado,
		"linea": linea
	})

# --- LIMPIEZA / REINICIO ---

func reiniciar_cables() -> void:
	_cancelar_trazado_actual()
	for conex in conexiones_actuales:
		if is_instance_valid(conex["linea"]):
			conex["linea"].queue_free()
	conexiones_actuales.clear()

func _eliminar_conexiones_de_nodo(nodo_id: String) -> void:
	_cancelar_trazado_actual()
	var a_eliminar: Array[Dictionary] = []
	
	for conex in conexiones_actuales:
		if conex["origen"] == nodo_id or conex["destino"] == nodo_id:
			a_eliminar.append(conex)
			
	for conex in a_eliminar:
		if is_instance_valid(conex["linea"]):
			conex["linea"].queue_free()
		conexiones_actuales.erase(conex)

func _cancelar_trazado_actual() -> void:
	nodo_origen_seleccionado = null
	cable_en_proceso.hide()
	cable_en_proceso.clear_points()

# --- VALIDACIÓN ---

func _validar_conexiones() -> void:
	var conexiones_correctas: int = 0
	var requeridas = nivel_data.conexiones_requeridas
	
	for req in requeridas:
		for actual in conexiones_actuales:
			var coincide_directo = (actual["origen"] == req["origen"] and actual["destino"] == req["destino"])
			var coincide_inverso = (actual["origen"] == req["destino"] and actual["destino"] == req["origen"])
			
			if (coincide_directo or coincide_inverso) and actual["cable"] == req["cable"]:
				conexiones_correctas += 1
				break
				
	if conexiones_correctas == requeridas.size() and conexiones_actuales.size() == requeridas.size():
		victoria_alcanzada = true
		briefing_modal.setup_debriefing(nivel_data)
	else:
		print("Conexión incorrecta o incompleta. Revisa la política de red.")

func _limpiar_tablero() -> void:
	for c in contenedor_nodos.get_children(): c.queue_free()
	reiniciar_cables()
