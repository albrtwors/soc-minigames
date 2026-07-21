# main_map_3d.gd
extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var map_overview: Marker3D = $CameraPositions/MapOverviewMarker

# Diccionario para mapear ID de minijuego a su marcador de cámara
@onready var markers: Dictionary = {
	"overview": $CameraPositions/MapOverviewMarker,
	"configuracion": $CameraPositions/ConfigStationMarker,
	"mitigacion": $CameraPositions/AttackStationMarker,
}

var camera_tween: Tween

func _ready() -> void:
	# Colocar la cámara en la vista general
	camera.global_transform = map_overview.global_transform
	
	# Escuchar eventos de la UI
	EventBus.minigame_selected.connect(_on_minigame_selected)
	EventBus.user_exit.connect(_on_user_exit)

func _on_minigame_selected(minigame_id: String, _level: int = 1) -> void:
	if markers.has(minigame_id):
		_move_camera_to(markers[minigame_id])

# Cuando el usuario sale del minijuego o del marco
func _on_user_exit() -> void:
	_move_camera_to(map_overview)

func _move_camera_to(target_marker: Marker3D) -> void:
	if camera_tween:
		camera_tween.kill()
		
	camera_tween = create_tween().set_parallel(true)
	
	camera_tween.tween_property(camera, "global_position", target_marker.global_position, 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	camera_tween.tween_property(camera, "global_basis", target_marker.global_basis, 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
