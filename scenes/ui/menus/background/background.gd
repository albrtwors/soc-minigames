# Script dentro de Background.tscn (si tiene uno)
extends Node3D

@onready var camera: Camera3D = $Camera3D # Ajusta al nombre de tu nodo Camera3D

var transform_inicial: Transform3D

func _ready() -> void:
	if camera:
		transform_inicial = camera.global_transform

# Esta función la llamaremos para forzar a la cámara a volver a su sitio exacto
func reset_camera() -> void:
	if camera and transform_inicial != Transform3D.IDENTITY:
		camera.global_transform = transform_inicial
