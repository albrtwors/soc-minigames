# res://scripts/minigames/soc_td_3d/defenses/wall_ids.gd
# ============================================================
# IDS / SNIFFER DE RED — análogo a la "Nuez" (muro)
# ============================================================
# Servidor pasivo de alto blindaje. Detiene el avance de los atacantes
# terrestres en el carril mientras el Firewall dispara por encima.
#
# TAMBIÉN CUMPLE EL ROL DE SENSOR:
#   - Expone la amenaza Ransomware (invisible para las defensas básicas)
#     en su mismo carril mientras este muro esté vivo.
#   - El controlador consulta `hay_ids_en_carril(lane)` para saber si el
#     Ransomware debe ser detectable.
#
# HIJO TÍPICO:
#   wall_ids (StaticBody3D)
#   └── MeshServer  <- rack alto y robusto (muro)
extends "res://scripts/minigames/soc_td_3d/defenses/base_defense_3d.gd"

## El IDS no dispara: solo es muro + sensor. Aquí solo reforzamos el blindaje.
@export_range(150.0, 1000.0) var hp_blindaje: float = 400.0


func _ready() -> void:
	super._ready()
	id_defensa = "wall_ids"
	hp_max = hp_blindaje
	hp = hp_blindaje
	costo = 75
	# Un muro no necesita puntos de disparo.
	if spawn_shoot_point:
		spawn_shoot_point.queue_free()
		spawn_shoot_point = null
