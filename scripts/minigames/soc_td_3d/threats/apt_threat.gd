# res://scripts/minigames/soc_td_3d/threats/apt_threat.gd
# ============================================================
# APT / INFILTRADOR LATERAL — amenaza saltarina
# ============================================================
# Humanoide sigiloso que SALTA la primera defensa que encuentra para infectar
# la segunda línea. Es la amenaza más veloz y esquiva.
#
# MECÁNICA ESPECIAL:
#   - Es detectable (los firewalls le disparan), pero tiene poca vida y mucha
#     velocidad: si no lo matas rápido, se cuela.
#   - Su salto se simula en el spawner/controlador: se le da una posición de
#     spawn más adentro (columna inicial avanzada) para representar que ya
#     saltó la primera línea.
#
# OPCIONAL AVANZADO: implementar el salto real como un "teleport" hacia la
# siguiente columna al detectar una defensa (ej. al colisionar). Para ello,
# añade aquí un método `saltar_sobre(defensa)` que mueva position.x.
extends "res://scripts/minigames/soc_td_3d/threats/base_threat_3d.gd"


func _ready() -> void:
	super._ready()
	id_amenaza = "apt"
	hp_max = 20.0
	hp = hp_max
	velocidad = 2.0
	puntos = 30
