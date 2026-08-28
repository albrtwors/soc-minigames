# res://scripts/minigames/soc_td_3d/defenses/antivirus_defense.gd
# ============================================================
# ANTIVIRUS / ENDPOINT SECURITY — análogo a la "Repetidora / Hielo"
# ============================================================
# Dispara vacunas de firmas que NO matan de inmediato: aplican el estado
# LENTO / CUARENTENA a las amenazas del carril (las ralentiza mucho).
#
# MECÁNICA:
#   - Dispara igual que el Firewall (RayCast +X) pero su proyectil, al golpear,
#     aplica un multiplicador de velocidad durante `duracion_cuarentena` segundos.
#   - El controlador principal gestiona el estado "lento" en cada amenaza
#     (ver base_threat_3d.gd -> set_lento()).
#
# ELIMINAR/VARIAR EL EFECTO:
#   - Cambia `factor_lento` (cuanto más bajo, más lento) y `duracion_cuarentena`.
extends "res://scripts/minigames/soc_td_3d/defenses/base_defense_3d.gd"

## Señal hacia el controlador: "lanza una vacuna desde esta posición"
## (declarada en base_defense_3d.gd).

## Daño pequeño que hace la vacuna al impactar.
@export var dano: float = 10.0

## Multiplicador de velocidad que aplica (0.30 = queda al 30% de su velocidad).
@export var factor_lento: float = 0.30

## Duración de la cuarentena en segundos.
@export var duracion_cuarentena: float = 4.0

## Segundos entre disparos.
@export var intervalo_disparo: float = 1.0

@export var alcance_ray: float = 14.0

var _timer: Timer
var _raycast: RayCast3D


func _ready() -> void:
	super._ready()
	id_defensa = "antivirus"
	hp_max = 80.0
	hp = hp_max
	costo = 100

	_raycast = RayCast3D.new()
	_raycast.target_position = Vector3(alcance_ray, 0, 0)
	_raycast.collision_mask = 2  # capa 2 = amenazas
	_raycast.collide_with_bodies = true
	_raycast.collide_with_areas = true
	add_child(_raycast)

	_timer = Timer.new()
	_timer.wait_time = intervalo_disparo
	_timer.timeout.connect(_intentar_disparar)
	add_child(_timer)
	_timer.start()


func _intentar_disparar() -> void:
	if hp <= 0.0 or not is_inside_tree():
		return
	_raycast.force_raycast_update()
	if _raycast.is_colliding():
		# Señal genérica reutilizada por el controlador; la vacuna lleva el
		# factor de lentitud en una propiedad que el controlador le inyecta.
		disparo_solicitado.emit(get_spawn_shoot_position(), Vector3(1, 0, 0), dano)


func destruir() -> void:
	if _timer:
		_timer.stop()
	super.destruir()
