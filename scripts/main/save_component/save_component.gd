# SaveComponent.gd
extends Node

const SAVE_PATH = "user://soc_savegame.tres"

func _ready() -> void:
	EventBus.save_requested.connect(_on_save_requested)
	EventBus.load_requested.connect(_on_load_requested)

func _on_save_requested(save_data: SaveData) -> void:
	if not save_data:
		EventBus.game_saved.emit(false)
		return
		
	var error = ResourceSaver.save(save_data, SAVE_PATH)
	if error == OK:
		EventBus.game_saved.emit(true)
	else:
		push_error("Error al guardar el recurso de partida: ", error)
		EventBus.game_saved.emit(false)

func _on_load_requested() -> void:
	if not ResourceLoader.exists(SAVE_PATH):
		# Si no existe archivo previo, devolvemos un recurso nuevo con los valores por defecto
		var new_save = SaveData.new()
		EventBus.game_loaded.emit(new_save)
		return
		
	var loaded_save = ResourceLoader.load(SAVE_PATH) as SaveData
	if loaded_save:
		EventBus.game_loaded.emit(loaded_save)
	else:
		push_warning("Archivo de guardado corrupto o incompatible. Creando uno nuevo.")
		EventBus.game_loaded.emit(SaveData.new())
