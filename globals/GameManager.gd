# GameManager.gd (Autoload global)
extends Node

var save_data: SaveData

func _ready() -> void:
	EventBus.game_loaded.connect(_on_game_loaded)

func _on_game_loaded(data: SaveData) -> void:
	save_data = data

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
