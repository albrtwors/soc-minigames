# res://scripts/ui/ui_view.gd
extends Control
class_name UIView

# Toda vista sabrá abrirse y cerrarse sola
func enter() -> void:
	show()

func exit() -> void:
	hide()
