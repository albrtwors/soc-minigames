# MainMenuComponent.gd (Asociado a MainMenuComponent)
extends Control

# Señales que el padre (MainUI) va a capturar
signal new_game_pressed
signal load_game_pressed
signal exit_pressed

# Vincula estas funciones a las señales 'pressed' de tus botones en el editor:
func _on_btn_nueva_partida_pressed() -> void:
	new_game_pressed.emit()

func _on_btn_cargar_partida_pressed() -> void:
	load_game_pressed.emit()

func _on_btn_salir_pressed() -> void:
	exit_pressed.emit()
