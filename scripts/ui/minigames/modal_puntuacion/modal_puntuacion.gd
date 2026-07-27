extends Control

signal continuar_presionado

@onready var lbl_titulo: Label = $PanelContainer/VBoxContainer/LblTitulo
@onready var lbl_puntuacion: Label = $PanelContainer/VBoxContainer/LblPuntuacion
@onready var btn_continuar: Button = $PanelContainer/VBoxContainer/BtnContinuar

func _ready() -> void:
	btn_continuar.pressed.connect(_on_btn_continuar_pressed)

# Esta función es la que llama el MinigameFrame
func mostrar_resultado(score: int, titulo: String = "¡Nivel Completado!") -> void:
	lbl_titulo.text = titulo
	lbl_puntuacion.text = "Puntaje final: " + str(score)
	show()

func _on_btn_continuar_pressed() -> void:
	continuar_presionado.emit()
	queue_free()
