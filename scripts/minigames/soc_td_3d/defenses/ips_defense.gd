# res://scripts/minigames/soc_td_3d/defenses/ips_defense.gd
# ============================================================
# IPS AUTOMATIZADO — análogo a la "Cereza / Bomba"
# ============================================================
# Se despliega instantáneamente y ejecuta un DROP ALL masivo en el carril:
#   - Al colocarse, elimina TODAS las amenazas de su carril (lane).
#   - Después de la activación se autodestruye (efecto de un solo uso).
#
# CÓMO SE ACTIVA:
#   - El controlador principal llama a `activar()` justo después de colocarlo.
#   - Emite la señal `drop_all` y el controlador elimina las amenazas del carril.
extends "res://scripts/minigames/soc_td_3d/defenses/base_defense_3d.gd"

## Señal de activación hacia el controlador (declarada en base_defense_3d.gd).

## Retraso en segundos antes de que explote (para que se vea el efecto).
@export var retraso_activacion: float = 0.4

var _activado: bool = false


func _ready() -> void:
	super._ready()
	id_defensa = "ips"
	hp_max = 1.0
	hp = hp_max
	costo = 150
	if spawn_shoot_point:
		spawn_shoot_point.queue_free()
		spawn_shoot_point = null


## Activa el DROP ALL (lo llama el controlador tras colocarlo).
func activar() -> void:
	if _activado or not is_inside_tree():
		return
	_activado = true
	drop_all.emit(lane)
	get_tree().create_timer(retraso_activacion).timeout.connect(func():
		if is_inside_tree():
			destruir()
	)
