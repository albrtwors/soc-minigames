# MinigameMenu.gd
extends Control

signal exit_requested
signal score_button_pressed

@onready var back_button: Button = $MainPanel/VBoxContainer/HBoxContainer5/BackButton
@onready var score_button: Button = $HeaderBar/ScoreButtonPanel/VBox/ScoreButton
@onready var lbl_nombre: Label = $HeaderBar/PlayerInfoPanel/HBoxContainer/InfoVBox/LblNombre
@onready var lbl_pnf: Label = $HeaderBar/PlayerInfoPanel/HBoxContainer/InfoVBox/LblPNF
@onready var lbl_rol: Label = $HeaderBar/PlayerInfoPanel/HBoxContainer/InfoVBox/LblRol
@onready var lbl_score_value: Label = $HeaderBar/ScoreButtonPanel/VBox/LblScoreValue
@onready var avatar_label: Label = $HeaderBar/PlayerInfoPanel/HBoxContainer/AvatarPlaceholder/AvatarLabel
@onready var avatar_texture: TextureRect = $HeaderBar/PlayerInfoPanel/HBoxContainer/AvatarPlaceholder/AvatarTexture

func _ready() -> void:
	back_button.pressed.connect(_on_back_button_pressed)
	score_button.pressed.connect(_on_score_button_pressed)
	EventBus.game_loaded.connect(_on_game_loaded)
	_actualizar_ui()

func _on_game_loaded(_save_data: SaveData) -> void:
	_actualizar_ui()

func _actualizar_ui() -> void:
	lbl_nombre.text = GameManager.get_player_full_name().to_upper()
	lbl_pnf.text = "PNF: " + GameManager.get_player_pnf()
	lbl_rol.text = "ROL: " + GameManager.get_player_role().to_upper()
	lbl_score_value.text = str(GameManager.get_total_score())
	_actualizar_avatar()

func _actualizar_avatar() -> void:
	if GameManager.save_data and GameManager.save_data.player_avatar_path != "":
		var tex := _cargar_textura_ruta(GameManager.save_data.player_avatar_path)
		if tex:
			avatar_texture.texture = tex
			avatar_texture.visible = true
			avatar_label.visible = false
			return
	avatar_texture.visible = false
	avatar_label.visible = true
	var iniciales := ""
	for part in GameManager.get_player_name().split(" "):
		if part.length() > 0:
			iniciales += part[0].to_upper()
	if iniciales.is_empty():
		iniciales = "AGT"
	avatar_label.text = iniciales

func _on_back_button_pressed() -> void:
	exit_requested.emit()
	EventBus.user_exit.emit()

func _on_score_button_pressed() -> void:
	score_button_pressed.emit()

func _cargar_textura_ruta(path: String) -> Texture2D:
	if path.begins_with("res://") or path.begins_with("user://"):
		var tex = load(path)
		if tex is Texture2D:
			return tex
	else:
		var img = Image.load_from_file(path)
		if img:
			return ImageTexture.create_from_image(img)
	return null

func actualizar_progreso_visual(_save_data: SaveData) -> void:
	_actualizar_ui()
