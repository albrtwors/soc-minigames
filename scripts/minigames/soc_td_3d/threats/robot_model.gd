# res://scripts/minigames/soc_td_3d/threats/robot_model.gd
# ============================================================
# MODELO DEL ROBOT DE AMENAZA — controla animaciones y color
# ============================================================
# Adjunto al nodo raíz del GLB del robot ("base_robot"). Expone:
#
#   reproducir(nombre, en_bucle)  -> reproduce una animación del
#       AnimationPlayer. Si el nombre no existe, NO hace nada.
#   cambiar_color(color)          -> busca el nodo "Object_38" (el cuerpo
#       del robot) y le asigna un material de superficie con el color.
extends Node3D
class_name RobotModel

## Nombre del nodo que contiene el cuerpo del robot en el GLB.
@export var nombre_cuerpo: String = "Object_7"

@onready var _anim: AnimationPlayer = $AnimationPlayer


## Reproduce una animación (en bucle por defecto).
## Si el nombre no existe, no hace nada.
func reproducir(nombre: String, en_bucle: bool = true) -> void:
	if not _anim or not _anim.has_animation(nombre):
		return
	_anim.get_animation(nombre).loop_mode = Animation.LOOP_LINEAR if en_bucle else Animation.LOOP_NONE
	_anim.play(nombre)


## Aplica el color al cuerpo del robot (nodo "Object_38") como material de
## superficie. Si el nodo no existe, no hace nada.
func cambiar_color(color: Color) -> void:
	var cuerpo := find_child(nombre_cuerpo, true, false) as MeshInstance3D
	if not cuerpo or not cuerpo.mesh:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	for idx in range(cuerpo.mesh.get_surface_count()):
		cuerpo.set_surface_override_material(idx, material)
