# res://scripts/minigames/soc_td_3d/projectile.gd
# ============================================================
# PROYECTIL — paquete SYN-ACK / regla de bloqueo / vacuna
# ============================================================
# Viaja en línea recta (eje X+) por su carril. Al colisionar con una amenaza:
#   - le inflige `dano`,
#   - opcionalmente aplica el estado LENTO (cuarentena) del Antivirus,
#   - se destruye.
# Si sale del mapa, se destruye solo (sin impacto).
#
# CÓMO SE INSTANCIA (lo hace soc_td_main.gd):
#   var p := projectile_scene.instantiate()
#   p.setup(pos, direccion, dano, factor_lento, duracion_cuarentena, lane)
#   projectile_container.add_child(p)
extends Area3D
class_name SocProjectile

## Daño que inflige al impactar.
var dano: float = 25.0

## Si > 0, aplica cuarentena (factor y duración). 0 = sin efecto lento.
var factor_lento: float = 1.0
var duracion_cuarentena: float = 0.0

## Carril por el que viaja (para filtrar colisiones, aunque el Area3D ya
## solo detecta amenazas por capa 2).
var lane: int = 0

var _velocidad: float = 8.0
var _direccion := Vector3(1, 0, 0)
var _vida: float = 3.0


func _ready() -> void:
	body_entered.connect(_on_impacto)
	area_entered.connect(_on_impacto)


func setup(pos: Vector3, direccion: Vector3, p_dano: float,
		p_factor_lento: float, p_duracion: float, p_lane: int) -> void:
	global_position = pos
	_direccion = direccion.normalized()
	dano = p_dano
	factor_lento = p_factor_lento
	duracion_cuarentena = p_duracion
	lane = p_lane
	# Solo chocamos contra amenazas (capa 2).
	collision_mask = 2
	collision_layer = 0


func _physics_process(delta: float) -> void:
	global_position += _direccion * _velocidad * delta
	_vida -= delta
	if _vida <= 0.0:
		queue_free()


func _on_impacto(body: Node3D) -> void:
	# Seguridad: solo afectamos amenazas (los proyectiles no se disparan entre sí).
	if body.has_method("tomar_dano") and body is Area3D:
		var murio: bool = body.tomar_dano(dano)
		if factor_lento < 1.0 and duracion_cuarentena > 0.0 and body.has_method("set_lento"):
			body.set_lento(factor_lento, duracion_cuarentena)
	queue_free()
