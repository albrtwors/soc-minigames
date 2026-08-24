# SaveSlotSelector.gd
extends Control

signal slot_selected(slot_id: int)
signal slot_delete_requested(slot_id: int)
signal back_pressed

enum Mode { NEW, LOAD }

var mode: Mode = Mode.LOAD

@onready var title_label: Label = $PanelContainer/VBoxContainer/Title
@onready var slots_container: VBoxContainer = $PanelContainer/VBoxContainer/SlotsContainer
@onready var back_button: Button = $PanelContainer/VBoxContainer/BackButton
@onready var slot_cards: Array[PanelContainer] = []

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	for i in range(slots_container.get_child_count()):
		var card = slots_container.get_child(i)
		if card is PanelContainer:
			slot_cards.append(card)
			_setup_card_signals(card, i)
	refresh_slots()
	EventBus.saves_list_updated.connect(_on_saves_list_updated)

func setup(new_mode: Mode) -> void:
	mode = new_mode
	match mode:
		Mode.NEW:
			title_label.text = "SELECCIONA UNA RANURA"
		Mode.LOAD:
			title_label.text = "CARGAR PARTIDA"
	refresh_slots()

func refresh_slots() -> void:
	var saves = GameManager.get_all_slots()
	for i in range(slot_cards.size()):
		if i < saves.size():
			_update_card(slot_cards[i], saves[i])

func _update_card(card: PanelContainer, info: Dictionary) -> void:
	var empty_panel = card.get_node("EmptyPanel")
	var data_panel = card.get_node("DataPanel")
	var delete_btn = card.get_node("DataPanel/DeleteButton") if card.has_node("DataPanel/DeleteButton") else null

	if not info.get("exists", false):
		empty_panel.visible = true
		data_panel.visible = false
	else:
		empty_panel.visible = false
		data_panel.visible = true
		var lbl_name = data_panel.get_node("LblName") as Label
		var lbl_role = data_panel.get_node("LblRole") as Label
		var lbl_score = data_panel.get_node("LblScore") as Label
		if lbl_name:
			lbl_name.text = info.get("player_name", "") + " " + info.get("player_lastname", "")
		if lbl_role:
			lbl_role.text = info.get("player_role", "").to_upper()
		if lbl_score:
			lbl_score.text = "PTS: " + str(info.get("total_score", 0))
		if delete_btn:
			delete_btn.visible = (mode == Mode.LOAD)

func _setup_card_signals(card: PanelContainer, index: int) -> void:
	var btn = card.get_node_or_null("EmptyPanel/ButtonEmpty") as Button
	if btn:
		btn.pressed.connect(func(): _on_card_clicked(index))

	var data_btn = card.get_node_or_null("DataPanel/ButtonData") as Button
	if data_btn:
		data_btn.pressed.connect(func(): _on_card_clicked(index))

	var delete_btn = card.get_node_or_null("DataPanel/DeleteButton") as Button
	if delete_btn:
		delete_btn.pressed.connect(func(): _on_delete_clicked(index))

func _on_card_clicked(index: int) -> void:
	slot_selected.emit(index)

func _on_delete_clicked(index: int) -> void:
	slot_delete_requested.emit(index)

func _on_saves_list_updated(_saves: Array[Dictionary]) -> void:
	refresh_slots()

func _on_back_pressed() -> void:
	back_pressed.emit()
