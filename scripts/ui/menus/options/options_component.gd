# options_component.gd
# Vista de opciones: ajuste de volumen de musica y efectos.
# Los cambios se aplican y guardan al instante via SettingsManager.
# Se cierra con el boton Volver o la tecla ESC (ui_cancel).
# ============================================================
extends Control

signal back_pressed

@onready var music_slider: HSlider = $MainPanel/VBoxContainer/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $MainPanel/VBoxContainer/SfxRow/SfxSlider
@onready var music_value_label: Label = $MainPanel/VBoxContainer/MusicRow/MusicHeader/MusicValue
@onready var sfx_value_label: Label = $MainPanel/VBoxContainer/SfxRow/SfxHeader/SfxValue
@onready var back_button: Button = $MainPanel/VBoxContainer/BackButton

func _ready() -> void:
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	back_button.pressed.connect(func(): back_pressed.emit())
	visibility_changed.connect(_on_visibility_changed)
	_refresh_from_settings()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		accept_event()
		back_pressed.emit()

# --- INTERNOS ---

func _on_visibility_changed() -> void:
	if visible:
		_refresh_from_settings()

func _refresh_from_settings() -> void:
	music_slider.set_value_no_signal(SoundManager.get_music_volume() * 100.0)
	sfx_slider.set_value_no_signal(SoundManager.get_sfx_volume() * 100.0)
	_update_value_labels()

func _on_music_slider_changed(value: float) -> void:
	SoundManager.set_music_volume(value / 100.0)
	_update_value_labels()

func _on_sfx_slider_changed(value: float) -> void:
	SoundManager.set_sfx_volume(value / 100.0)
	_update_value_labels()

func _update_value_labels() -> void:
	music_value_label.text = "%d%%" % roundi(music_slider.value)
	sfx_value_label.text = "%d%%" % roundi(sfx_slider.value)
