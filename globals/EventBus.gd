# EventBus.gd (Configurado como Autoload)
extends Node

# --- NAVEGACIÓN Y MENÚS ---
signal menu_changed(target_menu_name: String)

# --- PERSISTENCIA DE DATOS ---
signal save_requested(save_data: SaveData, slot_id: int)
signal load_requested(slot_id: int)
signal delete_save_requested(slot_id: int)
signal game_saved(success: bool, slot_id: int)
signal game_loaded(save_data: SaveData, slot_id: int)
signal saves_list_updated(saves_info: Array[Dictionary])

# --- FLUJO DE MINIJUEGOS ---
signal minigame_selected(minigame_id: String, level: int)
signal minigame_completed(minigame_id: String, level: int, score: int, success: bool)
signal puntos_actualizados(points: int)

signal user_exit
