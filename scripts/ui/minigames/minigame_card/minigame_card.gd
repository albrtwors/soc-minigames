# MinigameCard.gd
extends PanelContainer

# ID único del minijuego para mapearlo con los markers de la cámara y datos
@export var minigame_id: String = "configuracion"

var _base_scale: Vector2 = Vector2.ONE
var _hover_scale: Vector2 = Vector2(1.04, 1.04) # Crece un 4% al hacer hover

var _base_modulate: Color = Color(1.0, 1.0, 1.0, 0.85) # Opacidad reducida en reposo (85%)
var _hover_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)  # Opacidad completa al hacer hover (100%)

var tween: Tween

func _ready() -> void:
	# Cursor de mano al pasar por encima
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# Establecer opacidad inicial
	modulate = _base_modulate
	
	# Conectar señales de interacción
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	
	# Ajustar el pivote al centro para que el escalado sea simétrico
	pivot_offset = size / 2.0
	item_rect_changed.connect(func(): pivot_offset = size / 2.0)

func _on_mouse_entered() -> void:
	# Animación puramente VISUAL (Aumenta tamaño y sube opacidad)
	if tween: 
		tween.kill()
		
	tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", _hover_scale, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", _hover_modulate, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_mouse_exited() -> void:
	# Retornar al tamaño y opacidad base
	if tween: 
		tween.kill()
		
	tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", _base_scale, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "modulate", _base_modulate, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Minijuego seleccionado: ", minigame_id)
		EventBus.minigame_selected.emit(minigame_id)
