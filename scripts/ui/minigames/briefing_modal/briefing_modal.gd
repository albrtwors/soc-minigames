# res://scenes/ui/modals/briefing_modal.gd
extends Control

signal modal_closed

@onready var label_titulo: RichTextLabel = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LabelTitulo
@onready var label_teoria: RichTextLabel = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LabelTeoria
@onready var label_mision: RichTextLabel = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LabelMision
@onready var btn_accion: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BtnAccion

var es_debriefing: bool = false

func _ready() -> void:
	btn_accion.pressed.connect(_on_btn_accion_pressed)
	hide()

# Muestra la lección y objetivo antes de jugar
func setup_briefing(data: NivelConfigData) -> void:
	es_debriefing = false
	label_mision.show()
	label_titulo.text = data.titulo
	label_teoria.text = "[b]Concepto de Ciberseguridad:[/b]\n" + data.briefing_teoria
	label_mision.text = "[b]Misión:[/b]\n" + data.briefing_mision
	btn_accion.text = "Comenzar Desafío"
	btn_accion.disabled = false
	show()

# Muestra el feedback de victoria al resolver el puzzle
func setup_debriefing(data: NivelConfigData) -> void:
	es_debriefing = true
	label_mision.hide() # Ocultamos la misión en el debriefing
	label_titulo.text = "¡Desafío Completado!"
	label_teoria.text = "[b]Resultado Auditado:[/b]\n" + data.debriefing_exito
	btn_accion.text = "Continuar"
	btn_accion.disabled = false
	show()

func _on_btn_accion_pressed() -> void:
	btn_accion.disabled = true
	hide()
	modal_closed.emit()
