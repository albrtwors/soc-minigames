# res://scenes/ui/menus/minigame_frame/level_button.gd
extends Button

signal nivel_seleccionado(datos: NivelBaseData)

@export var icono_tutorial: Texture2D
@export var icono_arcade: Texture2D

@onready var icon_type: TextureRect = $MarginContainer/HBoxContainer/IconType
@onready var lbl_titulo: Label = $MarginContainer/HBoxContainer/LblTitulo

var data_nivel: NivelBaseData

func setup(data: NivelBaseData) -> void:
	data_nivel = data
	lbl_titulo.text = data.titulo_ui
	
	if data is NivelTutorialData:
		modulate = Color.CYAN
		if icono_tutorial: icon_type.texture = icono_tutorial
	elif data is NivelArcadeData:
		modulate = Color.WHITE
		if icono_arcade: icon_type.texture = icono_arcade

func _pressed() -> void:
	if data_nivel:
		nivel_seleccionado.emit(data_nivel)
