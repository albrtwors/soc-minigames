# MinigameCard.gd
@tool
extends PanelContainer

@export var minigame_id: String = "configuracion"
@export var es_en_mundo_3d: bool = false # Si el juego en sí es un Node3D (ej: Memorama 3D)
@export var requiere_enfoque_camara_3d: bool = false # Si queremos que la cámara se acerque a la mesa/monitor

@export_group("Personalización Card")
@export var titulo: String = "Título del Minijuego":
	set(val):
		titulo = val
		_actualizar_ui()

@export_multiline var descripcion: String = "Descripción corta del minijuego.":
	set(val):
		descripcion = val
		_actualizar_ui()

@export var icono_imagen: Texture2D:
	set(val):
		icono_imagen = val
		_actualizar_ui()

@onready var lbl_titulo: Label = $MarginContainer2/Label
@onready var lbl_descripcion: Label = $MarginContainer3/Label
@onready var img_icono: TextureRect = $MarginContainer/PanelContainer/TextureRect

var _base_scale: Vector2 = Vector2.ONE
var _hover_scale: Vector2 = Vector2(1.04, 1.04)
var _base_modulate: Color = Color(1.0, 1.0, 1.0, 0.85)
var _hover_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)

var tween: Tween

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	modulate = _base_modulate
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	
	pivot_offset = size / 2.0
	item_rect_changed.connect(func(): pivot_offset = size / 2.0)
	
	_actualizar_ui()

func _actualizar_ui() -> void:
	if lbl_titulo: lbl_titulo.text = titulo
	if lbl_descripcion: lbl_descripcion.text = descripcion
	if img_icono: img_icono.texture = icono_imagen

func _on_mouse_entered() -> void:
	if tween: tween.kill()
	tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", _hover_scale, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", _hover_modulate, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_mouse_exited() -> void:
	if tween: tween.kill()
	tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", _base_scale, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "modulate", _base_modulate, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Minijuego: ", minigame_id, " | Render 3D: ", es_en_mundo_3d, " | Enfoque Cámara: ", requiere_enfoque_camara_3d)
		# Enviamos ambas configuraciones a través del EventBus
		EventBus.minigame_selected.emit(minigame_id, es_en_mundo_3d, requiere_enfoque_camara_3d)
