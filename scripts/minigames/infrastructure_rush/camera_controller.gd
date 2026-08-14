# res://scripts/minigames/infrastructure_rush/camera_controller.gd
extends Node3D

## Controla la cámara del minijuego entre dos vistas: MACRO (mesa completa)
## y MICRO (enfoque a un dispositivo). Las transiciones se animan con Tween.

## Nodos instanciados en el editor.
@onready var camara: Camera3D = $MainCamera3D
@onready var marker_macro: Marker3D = $MarkerMacro
@onready var marker_micro: Marker3D = $MarkerMicro

var _tween: Tween

## Ubica la cámara en la vista macro. Llamar tras montar la escena.
func configurar_vista_macro() -> void:
	if not camara or not marker_macro:
		return
	camara.global_transform = marker_macro.global_transform
	camara.make_current()

## Interpola la cámara hasta el marker de enfoque de un dispositivo.
func enfocar_objetivo(marker: Marker3D) -> void:
	if not marker or not camara:
		return
	_animar_hacia(marker.global_position, marker.global_rotation)

## Devuelve la cámara a la vista general de la mesa.
func volver_a_macro() -> void:
	if not camara or not marker_macro:
		return
	_animar_hacia(marker_macro.global_position, marker_macro.global_rotation)

func _animar_hacia(pos: Vector3, rot: Vector3) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(camara, "global_position", pos, 0.5)
	_tween.tween_property(camara, "global_rotation", rot, 0.5)
