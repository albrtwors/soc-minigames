# Main.gd (Asociado al nodo raíz "Main")
extends Node

var partida_actual: SaveData
var current_slot: int = 0

func _ready() -> void:
	EventBus.game_loaded.connect(_on_game_loaded)
	EventBus.minigame_completed.connect(_on_minigame_completed)

func _on_game_loaded(save_data: SaveData, slot_id: int) -> void:
	partida_actual = save_data
	current_slot = slot_id
	print("Partida cargada (slot ", slot_id, "). Jugador: ", partida_actual.player_name, " ", partida_actual.player_lastname)

	var main_ui = get_node_or_null("MainUI")
	if main_ui and main_ui.has_node("MinigameMenu"):
		var minigame_menu = main_ui.get_node("MinigameMenu")
		if minigame_menu.has_method("actualizar_progreso_visual"):
			minigame_menu.actualizar_progreso_visual(partida_actual)

func _on_minigame_completed(minigame_id: String, level: int, score: int, success: bool) -> void:
	if not partida_actual or not success:
		return

	var progreso = partida_actual.minigames_progreso.get(minigame_id, null)
	if progreso:
		var scores = progreso.get("high_scores", {})
		var record_previo = scores.get(str(level), 0)
		if score > record_previo:
			scores[str(level)] = score

		if level == progreso.get("max_level_unlocked", 1):
			progreso["max_level_unlocked"] = level + 1

		EventBus.save_requested.emit(partida_actual, current_slot)
