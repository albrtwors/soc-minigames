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
@export var unlocked_minigames: Array[String] = ["configuracion_cables"]
@export var high_scores: Dictionary = {}

@export var minigames_progreso: Dictionary = {
	"configuracion_cables": {
		"max_level_unlocked": 1,
		"high_scores": {}
	},
	"phishing": {
		"max_level_unlocked": 1,
		"high_scores": {}
	},
	"cyber_tools": {
		"max_level_unlocked": 1,
		"high_scores": {}
	},
	"bullet_dodge": {
		"max_level_unlocked": 1,
		"high_scores": {}
	},
	"access_control": {
		"max_level_unlocked": 1,
		"high_scores": {}
	},
	"log_stream": {
		"max_level_unlocked": 1,
		"high_scores": {}
	},
	"infrastructure_rush": {
		"max_level_unlocked": 1,
		"high_scores": {}
	},
	"soc_td_3d": {
		"max_level_unlocked": 1,
		"high_scores": {}
	}
}
