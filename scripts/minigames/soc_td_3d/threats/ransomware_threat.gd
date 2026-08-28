# res://scripts/minigames/soc_td_3d/threats/ransomware_threat.gd
# ============================================================
# RANSOMWARE / ZERO-DAY — amenaza sigilosa
# ============================================================
# Humanoides translúcidos/púrpuras con brillos de "matriz". Pasan
# desapercibidos ante las defensas básicas a MENOS que haya un IDS (muro
# wall_ids) desplegado en su carril.
#
# MECÁNICA ESPECIAL:
#   - `puede_ser_detectado()` devuelve false salvo que el controlador lo haya
#     marcado como detectable (por la presencia de un IDS en su carril).
#   - Si llega al perímetro, el controlador lo considera mucho más peligroso
#     (más penalización por brecha).
#
# CÓMO SE CONTROLA SU VISIBILIDAD:
#   - soc_td_main.gd -> set_detectable(true) al haber un wall_ids en el carril.
extends "res://scripts/minigames/soc_td_3d/threats/base_threat_3d.gd"

var _detectable: bool = false


func _ready() -> void:
	super._ready()
	id_amenaza = "ransomware"
	hp_max = 30.0
	hp = hp_max
	velocidad = 1.15
	puntos = 35
	sigilosa = true


func set_detectable(detectable: bool) -> void:
	_detectable = detectable
	sigilosa = not detectable


func puede_ser_detectado() -> bool:
	return _detectable
