extends Control

signal character_created(data: Dictionary)
signal canceled

@onready var name_edit: LineEdit = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/NameEdit
@onready var surname_edit: LineEdit = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/SurNameEdit
@onready var pnf_option: OptionButton = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer4/PNFOption
@onready var role_option: OptionButton = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer4/RoleOption
@onready var avatar_panel: PanelContainer = $MarginContainer/VBoxContainer/HBoxContainer/PanelContainer
@onready var button_crear: Button = $MarginContainer/VBoxContainer/HBoxContainer2/CreateButton
@onready var button_volver: Button = $MarginContainer/VBoxContainer/HBoxContainer2/BackButton
@onready var title_label: Label = $MarginContainer/VBoxContainer/Label
@onready var form_container: HBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer
@onready var button_row: HBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer2

const PNFS = ["Informatica", "Electronica", "Telecomunicaciones", "Mantenimiento", "Mecanica", "Contaduria", "Administracion", "Electricidad"]
const ROLES = ["Novato", "Estudiante", "Ciberexperto"]

func _ready() -> void:
	pnf_option.clear()
	for pnf in PNFS:
		pnf_option.add_item(pnf)

	role_option.clear()
	for role in ROLES:
		role_option.add_item(role)

	button_crear.pressed.connect(_on_crear_pressed)
	button_volver.pressed.connect(_on_volver_pressed)

	_animar_entrada()

func _animar_entrada() -> void:
	title_label.modulate = Color(1, 1, 1, 0)
	var tp = title_label.position
	title_label.position.y = tp.y - 30

	form_container.modulate = Color(1, 1, 1, 0)
	form_container.scale = Vector2(0.94, 0.94)

	button_row.modulate = Color(1, 1, 1, 0)
	button_row.scale = Vector2(0.92, 0.92)

	var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.set_parallel(true)
	t.tween_property(title_label, "modulate", Color(1, 1, 1, 1), 0.6)
	t.tween_property(title_label, "position:y", tp.y, 0.6)

	var tf = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tf.set_parallel(true)
	tf.tween_property(form_container, "modulate", Color(1, 1, 1, 1), 0.5).set_delay(0.2)
	tf.tween_property(form_container, "scale", Vector2(1, 1), 0.5).set_delay(0.2)

	var tb = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tb.set_parallel(true)
	tb.tween_property(button_row, "modulate", Color(1, 1, 1, 1), 0.4).set_delay(0.5)
	tb.tween_property(button_row, "scale", Vector2(1, 1), 0.5).set_delay(0.5)

	name_edit.focus_entered.connect(_on_edit_focus.bind(name_edit))
	name_edit.focus_exited.connect(_on_edit_blur.bind(name_edit))
	surname_edit.focus_entered.connect(_on_edit_focus.bind(surname_edit))
	surname_edit.focus_exited.connect(_on_edit_blur.bind(surname_edit))

	button_crear.mouse_entered.connect(_on_btn_hover.bind(button_crear))
	button_crear.mouse_exited.connect(_on_btn_hover_end.bind(button_crear))
	button_crear.button_down.connect(_on_btn_press.bind(button_crear))
	button_volver.mouse_entered.connect(_on_btn_hover.bind(button_volver))
	button_volver.mouse_exited.connect(_on_btn_hover_end.bind(button_volver))
	button_volver.button_down.connect(_on_btn_press.bind(button_volver))

func _on_edit_focus(edit: LineEdit) -> void:
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.set_parallel(true)
	tw.tween_property(edit, "modulate", Color(1.15, 1.15, 1.15, 1), 0.2)
	tw.tween_property(edit, "scale", Vector2(1.02, 1.02), 0.2)

func _on_edit_blur(edit: LineEdit) -> void:
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.set_parallel(true)
	tw.tween_property(edit, "modulate", Color(1, 1, 1, 1), 0.25)
	tw.tween_property(edit, "scale", Vector2(1, 1), 0.25)

func _on_btn_hover(btn: Button) -> void:
	create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)\
		.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.15)

func _on_btn_hover_end(btn: Button) -> void:
	create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)\
		.tween_property(btn, "scale", Vector2(1, 1), 0.2)

func _on_btn_press(btn: Button) -> void:
	var tw = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_property(btn, "scale", Vector2(0.93, 0.93), 0.05)
	tw.tween_property(btn, "scale", Vector2(1, 1), 0.15)

func _on_crear_pressed() -> void:
	var nombre: String = name_edit.text.strip_edges()
	var apellido: String = surname_edit.text.strip_edges()

	if nombre == "" or apellido == "":
		push_warning("Por favor, rellene el nombre y apellido.")
		return

	var avatar_path: String = avatar_panel.imagen_cargada_ruta

	var data = {
		"nombre": nombre,
		"apellido": apellido,
		"pnf": PNFS[pnf_option.selected],
		"rol": ROLES[role_option.selected],
		"avatar_path": avatar_path
	}

	character_created.emit(data)

func _on_volver_pressed() -> void:
	canceled.emit()

func reset_form() -> void:
	name_edit.clear()
	surname_edit.clear()
	pnf_option.selected = 0
	role_option.selected = 0
	if avatar_panel.has_method("_mostrar_estado_vacio"):
		avatar_panel._mostrar_estado_vacio()
