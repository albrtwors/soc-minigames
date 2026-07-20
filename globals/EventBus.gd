# EventBus.gd (Configurado como Autoload)
extends Node

# --- NAVEGACIÓN Y MENÚS ---
signal menu_changed(target_menu_name: String)

# --- PERSISTENCIA DE DATOS ---
signal save_requested(save_data: SaveData)
signal load_requested
signal game_saved(success: bool)
signal game_loaded(save_data: SaveData)

# --- FLUJO DE MINIJUEGOS ---
# Emitido por la UI cuando el jugador selecciona un minijuego y nivel en el mapa
signal minigame_selected(minigame_id: String, level: int)

# Emitido por el minijuego activo al terminar (gane o pierda)
signal minigame_completed(minigame_id: String, level: int, score: int, success: bool)

signal user_exit
