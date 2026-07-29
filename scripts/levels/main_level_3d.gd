# main_map_3d.gd
extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var map_overview: Marker3D = $CameraPositions/MapOverviewMarker

@onready var markers: Dictionary = {
	"overview": $CameraPositions/MapOverviewMarker,
	"configuracion_cables": $CameraPositions/ConfigStationMarker,
	"mitigacion": $CameraPositions/AttackStationMarker,
	"phishing": $CameraPositions/PhishingStationMarker,
	"cyber_tools": $CameraPositions/CyberToolsMarker,
	"bullet_dodge": $CameraPositions/PhishingStationMarker,
}

# Diccionario para almacenar la referencia a cada EstacionTrabajo3D por su ID
var estaciones_mapa: Dictionary = {}
var camera_tween: Tween

func _ready() -> void:
	if map_overview:
		camera.global_transform = map_overview.global_transform
		
	# Mapear estaciones de trabajo registradas en el grupo
	for nodo in get_tree().get_nodes_in_group("estaciones_trabajo"):
		if nodo is EstacionTrabajo3D:
			estaciones_mapa[nodo.id_minijuego] = nodo
		
	EventBus.minigame_selected.connect(_on_minigame_selected)
	EventBus.user_exit.connect(_on_user_exit)

	# Auto-conectar si el MinigameFrame es un nodo hijo/CanvasLayer en la misma escena
	var frame = find_child("MinigameFrame", true, false)
	if frame:
		conectar_minigame_frame(frame)

## Enlaza la UI 2D con este mapa 3D
func conectar_minigame_frame(frame_node: Node) -> void:
	if frame_node.has_signal("solicitar_camara_3d"):
		if not frame_node.solicitar_camara_3d.is_connected(_on_solicitar_camara_3d):
			frame_node.solicitar_camara_3d.connect(_on_solicitar_camara_3d)
		
	if frame_node.has_signal("solicitar_montar_pc_3d"):
		if not frame_node.solicitar_montar_pc_3d.is_connected(enfocar_y_montar_pc):
			frame_node.solicitar_montar_pc_3d.connect(enfocar_y_montar_pc)

## Monta el minijuego en la estación 3D y desplaza la cámara
func enfocar_y_montar_pc(id_minijuego: String, escena_3d: PackedScene, config_data: Resource) -> void:
	if markers.has(id_minijuego):
		_move_camera_to(markers[id_minijuego])
		
	if estaciones_mapa.has(id_minijuego):
		var minijuego_instancia = estaciones_mapa[id_minijuego].montar_minijuego(escena_3d, config_data)
	else:
		push_warning("No se encontró la EstacionTrabajo3D registrada con ID: " + id_minijuego)

func enfocar_interaccion_3d(id_minijuego: String, activar: bool) -> void:
	if activar and markers.has(id_minijuego):
		_move_camera_to(markers[id_minijuego])

func _on_solicitar_camara_3d(id_minijuego: String, activar: bool) -> void:
	if activar and markers.has(id_minijuego):
		_move_camera_to(markers[id_minijuego])

func _on_minigame_selected(minigame_id: String, es_en_mundo_3d: bool = false) -> void:
	if es_en_mundo_3d and markers.has(minigame_id):
		_move_camera_to(markers[minigame_id])

# ÚNICO PUNTO DE REGRESO GLOBAL: Cuando el usuario abandona todo el marco
func _on_user_exit() -> void:
	for id in estaciones_mapa:
		estaciones_mapa[id].desmontar_minijuego()
		
	_move_camera_to(map_overview)

func _move_camera_to(target_marker: Marker3D) -> void:
	if not target_marker: return
	
	if camera_tween and camera_tween.is_running():
		camera_tween.kill()
		
	camera_tween = create_tween().set_parallel(true)
	camera_tween.tween_property(camera, "global_position", target_marker.global_position, 1.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	camera_tween.tween_property(camera, "global_basis", target_marker.global_basis, 1.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
