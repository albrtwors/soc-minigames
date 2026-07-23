# res://scenes/ui/menus/minigame_frame/modal_tutorial.gd
extends Control

signal tutorial_completado

@onready var lbl_titulo: Label = $PanelContainer/MarginContainer/VBoxContainer/Header/LblTitulo
@onready var lbl_pagina: Label = $PanelContainer/MarginContainer/VBoxContainer/Header/LblPagina
@onready var img_teoria: TextureRect = $PanelContainer/MarginContainer/VBoxContainer/Content/TextureRect
@onready var txt_teoria: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/Content/LblTextoTeoria
@onready var btn_anterior: Button = $PanelContainer/MarginContainer/VBoxContainer/Footer/BtnAnterior
@onready var btn_siguiente: Button = $PanelContainer/MarginContainer/VBoxContainer/Footer/BtnSiguiente

var datos_tutorial: NivelTutorialData
var pagina_actual: int = 0

func _ready() -> void:
	btn_anterior.pressed.connect(_on_anterior_pressed)
	btn_siguiente.pressed.connect(_on_siguiente_pressed)

func setup_tutorial(data: NivelTutorialData) -> void:
	datos_tutorial = data
	pagina_actual = 0
	lbl_titulo.text = data.titulo_ui
	_actualizar_pagina()

func _actualizar_pagina() -> void:
	if not datos_tutorial or datos_tutorial.paginas_teoria.is_empty():
		return
		
	var info_pagina: Dictionary = datos_tutorial.paginas_teoria[pagina_actual]
	
	# Actualizar textos e imágenes
	txt_teoria.text = info_pagina.get("texto", "")
	
	if info_pagina.has("imagen") and info_pagina["imagen"] != null:
		img_teoria.texture = info_pagina["imagen"]
		img_teoria.show()
	else:
		img_teoria.hide()
		
	lbl_pagina.text = "Pág. %d / %d" % [pagina_actual + 1, datos_tutorial.paginas_teoria.size()]
	
	# Control de botones
	btn_anterior.disabled = (pagina_actual == 0)
	
	if pagina_actual == datos_tutorial.paginas_teoria.size() - 1:
		btn_siguiente.text = "¡A Jugar!"
	else:
		btn_siguiente.text = "Siguiente"

func _on_anterior_pressed() -> void:
	if pagina_actual > 0:
		pagina_actual -= 1
		_actualizar_pagina()

func _on_siguiente_pressed() -> void:
	if pagina_actual < datos_tutorial.paginas_teoria.size() - 1:
		pagina_actual += 1
		_actualizar_pagina()
	else:
		# Llegó al final del tutorial
		tutorial_completado.emit()
		queue_free()
