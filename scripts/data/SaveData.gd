# SaveData.gd
class_name SaveData
extends Resource

# --- DATOS DEL JUGADOR ---
@export var player_name: String = ""
@export var player_lastname: String = ""
@export var player_pnf: String = "" # informatica, electronica, etc.
@export var player_role: String = "" # novato, estudiante, ciberexperto
@export var player_avatar_path: String = "" # Ruta local del archivo de imagen cargado

# --- PROGRESO GLOBAL ---
@export var current_level: int = 1
@export var unlocked_minigames: Array[String] = ["configuracion"]
@export var high_scores: Dictionary = {}

@export var minigames_progreso: Dictionary = {
	"configuracion": {
		"max_level_unlocked": 1,
		"high_scores": {}
	},
	"mitigacion": {
		"max_level_unlocked": 1,
		"high_scores": {}
	},
	"social": {
		"max_level_unlocked": 1,
		"high_scores": {}
	},
	"forense": {
		"max_level_unlocked": 1,
		"high_scores": {}
	},
	"criptografia": {
		"max_level_unlocked": 1,
		"high_scores": {}
	}
}
