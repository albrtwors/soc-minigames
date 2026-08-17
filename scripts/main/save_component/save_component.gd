# SaveComponent.gd
extends Node

func _ready() -> void:
	EventBus.save_requested.connect(_on_save_requested)
	EventBus.load_requested.connect(_on_load_requested)
	EventBus.delete_save_requested.connect(_on_delete_requested)

func _on_save_requested(save_data: SaveData, slot_id: int) -> void:
	if not save_data:
		EventBus.game_saved.emit(false, slot_id)
		return
	var error = ResourceSaver.save(save_data, GameManager._get_slot_path(slot_id))
	if error == OK:
		EventBus.game_saved.emit(true, slot_id)
		EventBus.game_loaded.emit(save_data, slot_id)
		EventBus.saves_list_updated.emit(GameManager.get_all_slots())
	else:
		push_error("Error al guardar en slot " + str(slot_id) + ": " + str(error))
		EventBus.game_saved.emit(false, slot_id)

func _on_load_requested(slot_id: int) -> void:
	var path = GameManager._get_slot_path(slot_id)
	if not ResourceLoader.exists(path):
		EventBus.game_loaded.emit(SaveData.new(), slot_id)
		return
	var loaded_save = ResourceLoader.load(path) as SaveData
	if loaded_save:
		EventBus.game_loaded.emit(loaded_save, slot_id)
	else:
		push_warning("Slot " + str(slot_id) + " corrupto. Creando uno nuevo.")
		EventBus.game_loaded.emit(SaveData.new(), slot_id)

func _on_delete_requested(slot_id: int) -> void:
	var path = GameManager._get_slot_path(slot_id)
	if ResourceLoader.exists(path):
		DirAccess.remove_absolute(path)
	EventBus.saves_list_updated.emit(GameManager.get_all_slots())
