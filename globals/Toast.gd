# Toast.gd (Autoload global)
extends Node

enum Type { WRONG, WARNING, SUCCESS }

const DURATION := 3.0
const MAX_VISIBLE := 5

var _layer: CanvasLayer
var _container: VBoxContainer
var _toast_scene: PackedScene = preload("res://scenes/ui/components/toast/toast_item.tscn")

func _ready() -> void:
	var layer_scene = preload("res://scenes/ui/components/toast/toast_layer.tscn")
	_layer = layer_scene.instantiate()
	add_child(_layer)
	_container = _layer.get_node("MarginContainer/ToastContainer")

func show_toast(title: String, subtitle: String = "", type: Type = Type.WARNING, duration: float = DURATION) -> void:
	var toast = _toast_scene.instantiate()
	_apply_type(toast, title, subtitle, type)
	_container.add_child(toast)

	while _container.get_child_count() > MAX_VISIBLE:
		var oldest = _container.get_child(0)
		_container.remove_child(oldest)
		oldest.queue_free()

	toast.modulate.a = 0.0
	toast.scale = Vector2(0.8, 0.8)
	toast.pivot_offset = toast.custom_minimum_size / 2.0
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(toast, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(toast, "scale", Vector2.ONE, 0.3)

	await get_tree().create_timer(duration).timeout
	if not is_instance_valid(toast):
		return
	var tw_out := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw_out.tween_property(toast, "modulate:a", 0.0, 0.2)
	tw_out.parallel().tween_property(toast, "scale", Vector2(0.85, 0.85), 0.2)
	tw_out.tween_callback(toast.queue_free)

func wrong(title: String, subtitle: String = "") -> void:
	show_toast(title, subtitle, Type.WRONG)

func warning(title: String, subtitle: String = "") -> void:
	show_toast(title, subtitle, Type.WARNING)

func success(title: String, subtitle: String = "") -> void:
	show_toast(title, subtitle, Type.SUCCESS)

func _apply_type(toast: PanelContainer, title: String, subtitle: String, type: Type) -> void:
	var icon_node := toast.get_node("HBoxContainer/Icon") as Label
	var title_node := toast.get_node("HBoxContainer/VBox/Title") as Label
	var subtitle_node := toast.get_node("HBoxContainer/VBox/Subtitle") as Label
	var style := toast.get_theme_stylebox("panel").duplicate() as StyleBoxFlat

	var config := {
		Type.WRONG: {"border": Color(1, 0.2, 0.2, 0.9), "bg": Color(0.15, 0.02, 0.02, 0.95), "icon": "✗", "icon_color": Color(1, 0.3, 0.3)},
		Type.WARNING: {"border": Color(1, 0.75, 0, 0.8), "bg": Color(0.12, 0.08, 0.01, 0.95), "icon": "⚠", "icon_color": Color(1, 0.8, 0.2)},
		Type.SUCCESS: {"border": Color(0.2, 0.95, 0.4, 0.8), "bg": Color(0.01, 0.1, 0.03, 0.95), "icon": "✓", "icon_color": Color(0.3, 1, 0.5)},
	}
	var c = config[type]

	style.bg_color = c["bg"]
	style.border_color = c["border"]
	style.shadow_color = Color(c["border"].r, c["border"].g, c["border"].b, 0.15)
	toast.add_theme_stylebox_override("panel", style)

	icon_node.text = c["icon"]
	icon_node.add_theme_color_override("font_color", c["icon_color"])
	title_node.text = title

	if subtitle != "":
		subtitle_node.text = subtitle
		subtitle_node.visible = true
	else:
		subtitle_node.visible = false
