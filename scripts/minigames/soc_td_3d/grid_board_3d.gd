# res://scripts/minigames/soc_td_3d/grid_board_3d.gd
# ============================================================
# TABLERO / GRILLA DE LA RED — "grid_board_3d.tscn"
# ============================================================
# Construye la mesa de celdas (carriles x columnas) y es el encargado de
# convertir clicks de pantalla en coordenadas de celda.
#
# CÓMO SE USA DESDE soc_td_main.gd:
#   grid.celda_desde_pantalla(camara, screen_pos) -> Dictionary con:
#       {col, lane, world_pos, valida}
#   grid.colocar_preview(world_pos, color)      -> mueve el fantasma verde/rojo
#   grid.ocultar_preview()                      -> esconde el fantasma
#
# LAYOUT (visto desde la cámara):
#   - CARILES (filas): 5, en el eje Z (profundidad).
#   - COLUMNAS: 9, en el eje X (de izquierda -> derecha).
#   - Las amenazas avanzan en X+ (de -X a +X) por su carril fijo.
#   - La columna 0 (más a la izquierda) es la puerta del perímetro: si una
#     amenaza cruza X <= X_INICIAL se activa el Firewall de Respaldo.
#
extends Node3D
class_name GridBoard3D

# CONSTANTES DE GRID (modifícalas aquí y se propaga a todo el juego):
const COLUMNAS := 9          # Celdas en el eje X
const CARILES := 5           # Celdas en el eje Z
const TAM_CELDA := 1.0       # Tamaño de celda en unidades 3D
const X_INICIAL := -4.0      # X de la primera columna
const X_FINAL := X_INICIAL + (COLUMNAS - 1) * TAM_CELDA  # X de la última columna

## Materiales de la mesa (se crean al vuelo para no depender de assets).
var _mat_celda_par: StandardMaterial3D
var _mat_celda_impar: StandardMaterial3D
var _mat_borde: StandardMaterial3D
var _mat_fantasma_valido: StandardMaterial3D
var _mat_fantasma_invalido: StandardMaterial3D

## El mesh transparente de preview (fantasma verde/rojo).
var _preview_mesh: MeshInstance3D

@onready var lanes_container: Node3D = $LanesContainer
@onready var surface_body: StaticBody3D = $SurfaceBody


func _ready() -> void:
	_crear_materiales()
	_construir_mesa()
	_crear_preview()


# --- CONSTRUCCIÓN VISUAL ---

func _crear_materiales() -> void:
	_mat_celda_par = StandardMaterial3D.new()
	_mat_celda_par.albedo_color = Color(0.10, 0.13, 0.18)
	_mat_celda_par.roughness = 0.9

	_mat_celda_impar = StandardMaterial3D.new()
	_mat_celda_impar.albedo_color = Color(0.13, 0.17, 0.23)
	_mat_celda_impar.roughness = 0.9

	_mat_borde = StandardMaterial3D.new()
	_mat_borde.albedo_color = Color(0.02, 0.04, 0.08)
	_mat_borde.roughness = 1.0

	_mat_fantasma_valido = StandardMaterial3D.new()
	_mat_fantasma_valido.albedo_color = Color(0.1, 0.9, 0.3, 0.45)
	_mat_fantasma_valido.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_mat_fantasma_invalido = StandardMaterial3D.new()
	_mat_fantasma_invalido.albedo_color = Color(0.9, 0.15, 0.15, 0.45)
	_mat_fantasma_invalido.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


## Dibuja la mesa: un suelo sólido (para los raycasts) + celdas decorativas.
func _construir_mesa() -> void:
	var ancho_x: float = COLUMNAS * TAM_CELDA
	var ancho_z: float = CARILES * TAM_CELDA
	var centro_x: float = (X_INICIAL + X_FINAL) * 0.5

	# --- Suelo físico (StaticBody3D) ---
	# Un único cuerpo grande que recibe los raycasts de click desde la cámara.
	var shape := BoxShape3D.new()
	shape.size = Vector3(ancho_x + 0.2, 0.2, ancho_z + 0.2)
	var col_shape := CollisionShape3D.new()
	col_shape.shape = shape
	surface_body.add_child(col_shape)
	surface_body.position = Vector3(centro_x, -0.05, 0)

	# --- Celdas decorativas (visual, sin física) ---
	for lane in range(CARILES):
		var z: float = lane * TAM_CELDA - (CARILES - 1) * 0.5 * TAM_CELDA
		for co in range(COLUMNAS):
			var x: float = X_INICIAL + co * TAM_CELDA
			var celda := MeshInstance3D.new()
			celda.mesh = BoxMesh.new()
			(celda.mesh as BoxMesh).size = Vector3(TAM_CELDA * 0.94, 0.02, TAM_CELDA * 0.94)
			celda.material_override = _mat_celda_par if (co + lane) % 2 == 0 else _mat_celda_impar
			celda.position = Vector3(x, 0, z)
			lanes_container.add_child(celda)

	# --- Marco exterior ---
	var marco := MeshInstance3D.new()
	marco.mesh = BoxMesh.new()
	(marco.mesh as BoxMesh).size = Vector3(ancho_x + 0.6, 0.05, ancho_z + 0.6)
	marco.material_override = _mat_borde
	marco.position = Vector3(centro_x, -0.06, 0)
	lanes_container.add_child(marco)


## Crea el mesh fantasma que sigue al cursor (escondido hasta que se usa).
func _crear_preview() -> void:
	_preview_mesh = MeshInstance3D.new()
	_preview_mesh.mesh = BoxMesh.new()
	(_preview_mesh.mesh as BoxMesh).size = Vector3(TAM_CELDA * 0.9, 0.4, TAM_CELDA * 0.9)
	_preview_mesh.material_override = _mat_fantasma_valido
	_preview_mesh.visible = false
	lanes_container.add_child(_preview_mesh)


# --- CONVERSIÓN PANTALLA <-> CELDA ---

## Convierte un click de pantalla en coordenadas de celda.
## Devuelve {col, lane, world_pos, valida}. Si el rayo no toca el tablero,
## devuelve {valida: false}.
func celda_desde_pantalla(camara: Camera3D, screen_pos: Vector2) -> Dictionary:
	if not camara:
		return {"valida": false}

	var origin := camara.project_ray_origin(screen_pos)
	var normal := camara.project_ray_normal(screen_pos)
	var end := origin + normal * 100.0

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	# Solo chocamos contra el suelo del tablero (collision_layer = 1).
	query.collision_mask = 1
	var result := space.intersect_ray(query)

	if result.is_empty():
		return {"valida": false}

	var hit_pos: Vector3 = result.position
	var x: float = hit_pos.x
	var z: float = hit_pos.z

	var col: int = int(round((x - X_INICIAL) / TAM_CELDA))
	var lane: int = int(round((z + (CARILES - 1) * 0.5 * TAM_CELDA) / TAM_CELDA))

	if col < 0 or col >= COLUMNAS or lane < 0 or lane >= CARILES:
		return {"valida": false}

	return {
		"col": col,
		"lane": lane,
		"world_pos": Vector3(X_INICIAL + col * TAM_CELDA, 0, lane * TAM_CELDA - (CARILES - 1) * 0.5 * TAM_CELDA),
		"valida": true,
	}


## Devuelve el centro de una celda en coordenadas del mundo.
func posicion_celda(col: int, lane: int) -> Vector3:
	return Vector3(
		X_INICIAL + col * TAM_CELDA,
		0,
		lane * TAM_CELDA - (CARILES - 1) * 0.5 * TAM_CELDA
	)


## Devuelve el X del spawn (justo fuera del borde derecho del tablero).
func x_spawn() -> float:
	return X_FINAL + 2.0


# --- PREVIEW (fantasma verde/rojo) ---

func colocar_preview(world_pos: Vector3, valida: bool) -> void:
	_preview_mesh.position = world_pos + Vector3(0, 0.15, 0)
	_preview_mesh.material_override = _mat_fantasma_valido if valida else _mat_fantasma_invalido
	_preview_mesh.visible = true


func ocultar_preview() -> void:
	_preview_mesh.visible = false
