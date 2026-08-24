extends Control

signal new_game_pressed
signal load_game_pressed
signal options_pressed
signal exit_pressed

@onready var title_label: Label = $Label
@onready var buttons: Array[Button] = [
	$ButtonColumn/Start,
	$ButtonColumn/Load,
	$ButtonColumn/Options,
	$ButtonColumn/Exit
]

func _ready() -> void:
	_animar_entrada()

func _animar_entrada() -> void:
	title_label.modulate = Color(1, 1, 1, 0)
	var title_pos = title_label.position
	title_label.position.y = title_pos.y - 40

	var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.set_parallel(true)
	t.tween_property(title_label, "modulate", Color(1, 1, 1, 1), 0.7)
	t.tween_property(title_label, "position:y", title_pos.y, 0.7)

	for i in buttons.size():
		var btn = buttons[i]
		btn.modulate = Color(1, 1, 1, 0)
		btn.scale = Vector2(0.85, 0.85)

		var delay = 0.12 * (i + 1) + 0.2
		var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.set_parallel(true)
		tw.tween_property(btn, "modulate", Color(1, 1, 1, 1), 0.4).set_delay(delay)
		tw.tween_property(btn, "scale", Vector2(1, 1), 0.5).set_delay(delay)

		btn.mouse_entered.connect(_on_btn_hover.bind(btn))
		btn.mouse_exited.connect(_on_btn_hover_end.bind(btn))
		btn.button_down.connect(_on_btn_press.bind(btn))

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

func _on_btn_nueva_partida_pressed() -> void:
	new_game_pressed.emit()

func _on_btn_cargar_partida_pressed() -> void:
	load_game_pressed.emit()

func _on_btn_opciones_pressed() -> void:
	options_pressed.emit()

func _on_btn_salir_pressed() -> void:
	exit_pressed.emit()
