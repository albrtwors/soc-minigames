# res://scripts/minigames/soc_td_3d/threats/script_kdd_threat.gd
# ============================================================
# SCRIPT KIDDIE — amenaza humana básica
# ============================================================
# Humanoides rojizos estándar: avanzan despacio, sin habilidades especiales.
# Son la amenaza más común del pool.
#
# Ajustes típicos (Inspector / nivel):
#   - hp_max ~ 40-60
#   - velocidad ~ 0.8-1.2
extends "res://scripts/minigames/soc_td_3d/threats/base_threat_3d.gd"


func _ready() -> void:
	super._ready()
	id_amenaza = "script_kdd"
	hp_max = 35.0
	hp = hp_max
	velocidad = 0.9
	puntos = 15
