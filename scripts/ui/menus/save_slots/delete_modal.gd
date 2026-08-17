# DeleteModal.gd
extends Control

signal confirmed
signal cancelled

@onready var lbl_title: Label = $Panel/VBoxContainer/LblTitle
@onready var lbl_detail: Label = $Panel/VBoxContainer/LblDetail
@onready var btn_confirm: Button = $Panel/VBoxContainer/HBoxContainer/BtnConfirm
@onready var btn_cancel: Button = $Panel/VBoxContainer/HBoxContainer/BtnCancel

func setup(player_name: String) -> void:
	lbl_title.text = "ELIMINAR PARTIDA"
	lbl_detail.text = "Se eliminará permanentemente la partida de \"" + player_name + "\"."

func _ready() -> void:
	btn_confirm.pressed.connect(func(): confirmed.emit())
	btn_cancel.pressed.connect(func(): cancelled.emit())
