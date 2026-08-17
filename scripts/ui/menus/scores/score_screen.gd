# ScoreScreen.gd
extends Control

signal exit_requested

@onready var back_button: Button = $Panel/VBoxContainer/Header/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	exit_requested.emit()
	EventBus.user_exit.emit()
