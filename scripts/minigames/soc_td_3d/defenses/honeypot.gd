# res://scripts/minigames/soc_td_3d/defenses/honeypot.gd
# ============================================================
# HONEYPOT / TRAMPA DECOY — análoga a la "Mina / Papa Explosiva"
# ============================================================
# Trampa pasiva. Cuando un atacante la alcanza (colisiona con ella), explota:
#   - Daña a TODAS las amenazas en un área 3x3 (carril y adyacentes).
#   - Se autodestruye (después de la explosión desaparece).
#
# CÓMO SE ACTIVA:
#   - El controlador principal detecta la colisión amenaza<->honeypot mediante
#     un Area3D de detección (o el RayCast de ataque de la amenaza).
#   - Al detonar, emite la señal `explotar` y el controlador aplica el daño
#     en área con `_aplicar_dano_area(honeypot.lane, honeypot.col, radio_celdas)`.
extends "res://scripts/minigames/soc_td_3d/defenses/base_defense_3d.gd"

## Señal de detonación hacia el controlador (declarada en base_defense_3d.gd).

## Daño que inflige la explosión a cada amenaza del área.
@export var dano_explosion: float = 500.0

## Radio en celdas del área 3x3 (1 = la celda + las 8 vecinas).
@export var radio_celdas: int = 1

## Zona de detección (Area3D) que avisa cuando una amenaza entra en contacto.
var _detector: Area3D

## Flag para que solo explote una vez.
var _explotada: bool = false


func _ready() -> void:
	super._ready()
	id_defensa = "honeypot"
	hp_max = 1.0   # No se puede destruir a golpes: explota al primer contacto.
	hp = hp_max
	costo = 100
	if spawn_shoot_point:
		spawn_shoot_point.queue_free()
		spawn_shoot_point = null

	_crear_detector()


## Crea un Area3D pequeño alrededor de la trampa que detecta amenazas.
func _crear_detector() -> void:
	_detector = Area3D.new()
	_detector.collision_mask = 2  # capa 2 = amenazas
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 0.6, 0.6)
	shape.shape = box
	_detector.add_child(shape)
	_detector.body_entered.connect(_on_amenaza_entra)
	_detector.area_entered.connect(_on_amenaza_entra)
	add_child(_detector)


func _on_amenaza_entra(_cuerpo: Node3D) -> void:
	detonar()


## Activa la explosión (solo una vez) y notifica al controlador.
func detonar() -> void:
	if _explotada or not is_inside_tree():
		return
	_explotada = true
	explotar.emit(global_position, lane, col, radio_celdas)
	destruir()
