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
	"AZUL": Color.DODGER_BLUE, "ROJO": Color.CRIMSON,
	"VERDE": Color.GREEN, "AMARILLO": Color.GOLD
}
var lista_colores: Array = ["AZUL", "ROJO", "VERDE", "AMARILLO"]

var label_color_actual: Label
var panel_info: PanelContainer
var vbox_panel_info: VBoxContainer

func _ready() -> void:
	cable_en_proceso.hide()
	
	if btn_validar: btn_validar.pressed.connect(_validar_conexiones)
	if btn_volver: btn_volver.pressed.connect(salir_solicitado.emit)
	if btn_reiniciar: btn_reiniciar.pressed.connect(reiniciar_cables)
	if btn_ver_enunciado: btn_ver_enunciado.pressed.connect(_mostrar_enunciado)
	if btn_info: btn_info.pressed.connect(_toggle_panel_info)
	briefing_modal.modal_closed.connect(_on_briefing_closed)
	
	_crear_selector_color()
	_crear_panel_info()
	if nivel_data: cargar_nivel(nivel_data)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancelar_trazado_actual()
	elif event is InputEventKey and event.pressed and not event.echo:
		var idx = event.keycode - KEY_1
		if idx >= 0 and idx < lista_colores.size():
			color_seleccionado = lista_colores[idx]
			_actualizar_label_color()

func cargar_nivel(data: NivelConfigData) -> void:
	nivel_data = data
	victoria_alcanzada = false
	color_seleccionado = "AZUL"
	if panel_info: panel_info.hide()
	_actualizar_label_color()
	_limpiar_tablero()
	_generar_nodos_ui()
	briefing_modal.setup_briefing(nivel_data)

# --- SELECTOR Y PANEL INFO ---

func _crear_selector_color() -> void:
	label_color_actual = Label.new()
	label_color_actual.position = Vector2(14, 14)
	add_child(label_color_actual)

func _actualizar_label_color() -> void:
	if label_color_actual:
		label_color_actual.text = "Cable: " + color_seleccionado + " [1-4]"
		label_color_actual.modulate = colores_map[color_seleccionado]

func _mostrar_enunciado() -> void:
	if nivel_data: briefing_modal.setup_briefing(nivel_data)

func _on_briefing_closed() -> void:
	if briefing_modal.es_debriefing and victoria_alcanzada:
		nivel_completado.emit()

func _toggle_panel_info() -> void:
	panel_info.visible = not panel_info.visible
	if panel_info.visible: _actualizar_panel_info()

func _crear_panel_info() -> void:
	panel_info = PanelContainer.new()
	panel_info.position = Vector2(910, 14)
	panel_info.custom_minimum_size = Vector2(228, 0)
	vbox_panel_info = VBoxContainer.new()
	vbox_panel_info.add_theme_constant_override("separation", 8)
	panel_info.add_child(vbox_panel_info)
	add_child(panel_info)
	panel_info.hide()

func _add_lbl(texto: String, color: Color = Color.WHITE) -> Label:
	var l = Label.new()
	l.text = texto
	l.modulate = color
	vbox_panel_info.add_child(l)
	return l

func _actualizar_panel_info() -> void:
	for child in vbox_panel_info.get_children(): child.queue_free()
	if not nivel_data: return
	
	_add_lbl("INFORMACIÓN DE LA MISIÓN")
	vbox_panel_info.add_child(HSeparator.new())
	
	_add_lbl("CABLES NECESARIOS")
	var req_cables = {}
	for c in nivel_data.conexiones_requeridas: req_cables[c.cable] = true
	for c in req_cables: _add_lbl("  ● " + c, colores_map[c])
	
	vbox_panel_info.add_child(HSeparator.new())
	_add_lbl("RESUMEN DE RED")
	_add_lbl("  Conexiones: " + str(nivel_data.conexiones_requeridas.size()))
	_add_lbl("  Nodos en red: " + str(nivel_data.nodos_disponibles.size()))
	
	vbox_panel_info.add_child(HSeparator.new())
	_add_lbl("CONTROLES")
	for ctrl in ["Clic izq → Conectar", "Clic der → Borrar cable", "Clic der fondo → Cancelar", "Teclas 1-4 → Cambiar cable", "Reiniciar → Limpiar"]:
		_add_lbl("  • " + ctrl)

# --- NODOS Y LÓGICA DE CABLES ---

func _generar_nodos_ui() -> void:
	for nodo in nivel_data.nodos_disponibles:
		var btn = Button.new()
		btn.text = nodo.id + "\n(" + nodo.tipo + ")"
		btn.position = nodo.posicion
		btn.custom_minimum_size = Vector2(130, 64)
		btn.set_meta("id", nodo.id)
		btn.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed:
				if ev.button_index == MOUSE_BUTTON_LEFT: _on_nodo_clicked(btn)
				elif ev.button_index == MOUSE_BUTTON_RIGHT: _eliminar_conexiones_de_nodo(nodo.id)
		)
		contenedor_nodos.add_child(btn)

func _on_nodo_clicked(btn: Button) -> void:
	if nodo_origen_seleccionado == null:
		nodo_origen_seleccionado = btn
		cable_en_proceso.clear_points()
		cable_en_proceso.add_point(_get_node_center(btn))
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
	return contenedor_cables.get_global_transform().affine_inverse() * (btn.global_position + btn.size / 2.0)

func _crear_conexion(origen: Button, destino: Button) -> void:
	var o_id = origen.get_meta("id")
	var d_id = destino.get_meta("id")
	
	if conexiones_actuales.any(func(c): return (c.origen == o_id and c.destino == d_id) or (c.origen == d_id and c.destino == o_id)):
		return

	var linea = Line2D.new()
	linea.width = 6.0
	linea.default_color = colores_map[color_seleccionado]
	linea.add_point(_get_node_center(origen))
	linea.add_point(_get_node_center(destino))
	contenedor_cables.add_child(linea)
	
	conexiones_actuales.append({"origen": o_id, "destino": d_id, "cable": color_seleccionado, "linea": linea})

func reiniciar_cables() -> void:
	_cancelar_trazado_actual()
	for c in conexiones_actuales:
		if is_instance_valid(c.linea): c.linea.queue_free()
	conexiones_actuales.clear()

func _eliminar_conexiones_de_nodo(nodo_id: String) -> void:
	_cancelar_trazado_actual()
	conexiones_actuales = conexiones_actuales.filter(func(c):
		var coincide = c.origen == nodo_id or c.destino == nodo_id
		if coincide and is_instance_valid(c.linea): c.linea.queue_free()
		return not coincide
	)

func _cancelar_trazado_actual() -> void:
	nodo_origen_seleccionado = null
	cable_en_proceso.hide()
	cable_en_proceso.clear_points()

func _validar_conexiones() -> void:
	var reqs = nivel_data.conexiones_requeridas
	var es_valido = conexiones_actuales.size() == reqs.size() and reqs.all(func(req):
		return conexiones_actuales.any(func(act):
			var match_dir = (act.origen == req.origen and act.destino == req.destino) or (act.origen == req.destino and act.destino == req.origen)
			return match_dir and act.cable == req.cable
		)
	)
	
	if es_valido:
		victoria_alcanzada = true
		briefing_modal.setup_debriefing(nivel_data)
	else:
		print("Conexión incorrecta o incompleta.")

func _limpiar_tablero() -> void:
	for c in contenedor_nodos.get_children(): c.queue_free()
	reiniciar_cables()
