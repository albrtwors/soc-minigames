extends PanelContainer

@export var hover_scale := Vector2(1.03, 1.03)
@export var tween_duration := 0.15

var _tween: Tween

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", hover_scale, tween_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _on_mouse_exited() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, tween_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
