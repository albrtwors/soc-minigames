extends PanelContainer

@export var animar_entrada: bool = true
@export var duracion_animacion: float = 0.25

var sub_viewport: SubViewport
var sub_viewport_container: SubViewportContainer

func _ready() -> void:
	sub_viewport_container = $VBox/MarginContainer/SubViewportContainer
	sub_viewport = $VBox/MarginContainer/SubViewportContainer/SubViewport
	$VBox/Titulo/BtnCerrar.pressed.connect(_on_cerrar)
	if animar_entrada:
		_hacer_animacion_entrada()

func _hacer_animacion_entrada() -> void:
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)

	await get_tree().process_frame
	pivot_offset = size * 0.5

	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), duracion_animacion)
	tween.tween_property(self, "modulate:a", 1.0, duracion_animacion * 0.8)

func get_viewport_3d() -> SubViewport:
	return sub_viewport

func set_scene_3d(scene: PackedScene) -> Node:
	var instance = scene.instantiate()
	sub_viewport.add_child(instance)
	return instance

func clear_scene_3d() -> void:
	for child in sub_viewport.get_children():
		child.queue_free()

func _on_cerrar() -> void:
	animar_entrada = false
	var tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(modulate.r, modulate.g, modulate.b, 0.0), 0.2)
	tween.tween_property(self, "scale", Vector2(0.85, 0.85), 0.2)
	tween.finished.connect(queue_free)
