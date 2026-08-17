# GameManager.gd (Autoload global)
extends Node

const SLOT_COUNT := 3
const SAVE_DIR := "user://"
const SAVE_PREFIX := "soc_save_slot_"
const SAVE_EXT := ".tres"

var save_data: SaveData
var current_slot: int = 0

func _ready() -> void:
	EventBus.game_loaded.connect(_on_game_loaded)

func _on_game_loaded(data: SaveData, slot_id: int) -> void:
	save_data = data
	current_slot = slot_id

# --- Slot utilities ---
func _get_slot_path(slot_id: int) -> String:
	return SAVE_DIR + SAVE_PREFIX + str(slot_id) + SAVE_EXT

func slot_exists(slot_id: int) -> bool:
	return ResourceLoader.exists(_get_slot_path(slot_id))

func get_slot_info(slot_id: int) -> Dictionary:
	var path = _get_slot_path(slot_id)
	if not ResourceLoader.exists(path):
		return {"exists": false, "slot_id": slot_id}
	var save = ResourceLoader.load(path) as SaveData
	if not save:
		return {"exists": false, "slot_id": slot_id}
	return {
		"exists": true,
		"slot_id": slot_id,
		"player_name": save.player_name,
		"player_lastname": save.player_lastname,
		"player_role": save.player_role,
		"player_pnf": save.player_pnf,
		"total_score": _calc_total_score(save)
	}

func get_all_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in SLOT_COUNT:
		result.append(get_slot_info(i))
	return result

func _calc_total_score(save: SaveData) -> int:
	var total := 0
	for minigame_id in save.minigames_progreso:
		var progreso = save.minigames_progreso[minigame_id]
		var scores = progreso.get("high_scores", {})
		for key in scores:
			if scores[key] is int:
				total += scores[key]
	return total

# --- Player data accessors ---
func get_player_name() -> String:
	if not save_data:
		return "Agente"
	return save_data.player_name

func get_player_lastname() -> String:
	if not save_data:
		return "Desconocido"
	return save_data.player_lastname

func get_player_full_name() -> String:
	return get_player_name() + " " + get_player_lastname()

func get_player_pnf() -> String:
	if not save_data:
		return "N/A"
	return save_data.player_pnf

func get_player_role() -> String:
	if not save_data:
		return "Agente Novel"
	return save_data.player_role

func get_high_score(minigame_id: String) -> int:
	if not save_data:
		return 0
	var progreso = save_data.minigames_progreso.get(minigame_id, {})
	var scores = progreso.get("high_scores", {})
	var best := 0
	for key in scores:
		var val = scores[key]
		if val is int and val > best:
			best = val
	return best

func get_total_score() -> int:
	if not save_data:
		return 0
	var total := 0
	for minigame_id in save_data.minigames_progreso:
		total += get_high_score(minigame_id)
	return total

func get_level_unlocked(minigame_id: String) -> int:
	if not save_data:
		return 1
	var progreso = save_data.minigames_progreso.get(minigame_id, {})
	return progreso.get("max_level_unlocked", 1)
