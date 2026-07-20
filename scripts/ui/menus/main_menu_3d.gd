# Script adjunto a MainMenu3D (si existe)
extends Node3D

@onready var camera: Camera3D = $Background/Camera3D # Ajusta la ruta a tu cámara

var transform_inicial: Transform3D

func _ready() -> void:
	if camera:
		transform_inicial = camera.global_transform

func reset_camera() -> void:
	if camera and transform_inicial:
		camera.global_transform = transform_inicial
