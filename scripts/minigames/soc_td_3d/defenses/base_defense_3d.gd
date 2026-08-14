# res://scripts/minigames/soc_td_3d/defenses/base_defense_3d.gd
# ============================================================
# DEFENSA BASE — "defenses/base_defense_3d.tscn"
# ============================================================
# Clase padre de TODAS las defensas (Servidor PDU, Firewall, IDS/Muro, ...).
# Define el contrato común que usa soc_td_main.gd:
#
#   - hp / hp_max        : vida de la defensa.
#   - tomar_dano(cant)   : le resta vida; emite destruida al morir.
#   - lane / col         : posición en el tablero (para búsquedas).
#   - destruir()         : limpia la defensa del árbol (muerte real).
#
# HIJO TÍPICO QUE PUEDES ESPERAR:
#   base_defense_3d (StaticBody3D)
#   ├── CollisionShape3D      <- forma del cuerpo
#   └── MeshServer            <- MeshInstance3D con el rack low-poly
#
# PARA CREAR UNA DEFENSA NUEVA:
#   1. Crea un script nuevo que herede de este (extends).
#   2. Sobreescribe los valores @export en el Inspector o en _ready.
#   3. Si dispara, usa spawn_shoot_point para lanzar proyectiles.
#   4. Instancia la escena base_defense_3d.tscn o crea una escena hija.
extends StaticBody3D
class_name BaseDefense3D

## Señales públicas (las usa el controlador principal).
signal destruida(defensa: Node3D)

## Señales de comportamiento común (las usan las subclases y el controlador).
signal token_generado(pos: Vector3)
signal disparo_solicitado(pos: Vector3, direccion: Vector3, dano: float)
signal explotar(pos: Vector3, lane: int, col: int, radio_celdas: int)
signal drop_all(lane: int)

## Identificador del tipo de defensa (para HUD y costes).
@export var id_defensa: String = "base"

## Vida máxima y actual.
@export var hp_max: float = 100.0
var hp: float = 100.0

## Fila (carril) y columna donde está colocada.
@export var lane: int = 0
@export var col: int = 0

## Coste en $ (para el HUD y el controlador).
@export var costo: int = 50

## Punto desde el que salen los proyectiles (se busca al vuelo).
var spawn_shoot_point: Node3D

func get_spawn_token_position() -> Vector3:
	# 1. Si pusiste un nodo Marker3D llamado "SpawnTokenPoint" en el editor, usa su posición
	if has_node("SpawnTokenPoint"):
		return $SpawnTokenPoint.global_position

	# 2. Si no, calcula la altura real del modelo usando el AABB del Mesh
	var max_y: float = global_position.y
	var meshes := find_children("*", "MeshInstance3D", true, false)

	for m in meshes:
		var mesh_node := m as MeshInstance3D
		if mesh_node and mesh_node.visible:
			var aabb := mesh_node.get_aabb()
			# Punto superior local del AABB
			var tope_local := aabb.position + Vector3(0.0, aabb.size.y, 0.0)
			# Convertir a coordenadas globales (por si el mesh tiene escala o rotación)
			var tope_global := mesh_node.global_transform * tope_local
			if tope_global.y > max_y:
				max_y = tope_global.y

	# Si no se detectaron mallas, se le suma un margen por defecto (1.2m)
	if max_y == global_position.y:
		max_y += 1.2

	# Retorna el centro de la defensa en X y Z, pero con la altura Y calculada + offset
	return Vector3(global_position.x, max_y + 0.3, global_position.z)

func _ready() -> void:
	hp = hp_max
	spawn_shoot_point = get_node_or_null("SpawnPointShoot")
	# El cuerpo físico debe ser detectado por los RayCast de amenazas/firewalls.
	collision_layer = 1  # El controlador usa capa 1 para colisiones de defensas
	collision_mask = 0


## Resta vida a la defensa. Devuelve true si murió (y emite destruida).
func tomar_dano(cant: float) -> bool:
	if hp <= 0.0:
		return false
	hp = maxf(0.0, hp - cant)
	if hp <= 0.0:
		destruida.emit(self)
		return true
	return false


## Destruye visual y físicamente la defensa.
func destruir() -> void:
	set_physics_process(false)
	queue_free()


## Posición de disparo (para turrets). Devuelve global_position si no hay nodo.
func get_spawn_shoot_position() -> Vector3:
	if spawn_shoot_point:
		return spawn_shoot_point.global_position
	return global_position + Vector3(0, 0.5, 0)
