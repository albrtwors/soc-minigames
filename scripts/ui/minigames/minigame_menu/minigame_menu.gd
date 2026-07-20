# MinigameMenu.gd
extends Control

# Señal propia para avisarle a MainUI que el usuario quiere cerrar/salir de este menú
signal exit_requested

@onready var back_button: Button = $PanelContainer/VBoxContainer/HBoxContainer4/BackButton

func _ready() -> void:
	# Conexión correcta usando .connect
	back_button.pressed.connect(_on_back_button_pressed)

func _on_back_button_pressed() -> void:
	# Opción A: Emitir señal local para que MainUI la maneje
	exit_requested.emit()
	
	# Opción B: Notificar globalmente a través de EventBus si otros sistemas escuchan la salida
	EventBus.user_exit.emit()

func actualizar_progreso_visual(save_data: SaveData) -> void:
	pass
