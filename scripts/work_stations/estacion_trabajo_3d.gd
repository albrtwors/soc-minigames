# res://scripts/level/estacion_trabajo_3d.gd
extends Node3D
class_name EstacionTrabajo3D

## Identificador único del minijuego asignado a esta mesa/estación
@export var id_minijuego: String = "cyber_tools"

## Punto de origen exacto donde aparecerá el minijuego 3D (Cartas, cables, etc.)
## Si no se asigna en el Inspector, usará la posición de este mismo nodo.
@export var punto_montaje: Node3D

var minijuego_activo: Node = null

func _ready() -> void:
	# Si no asignaste un punto específico, usamos la posición de este mismo nodo
	if not punto_montaje:
		punto_montaje = self

## Instancia y monta directamente la escena 3D nativa sobre la mesa
func montar_minijuego(escena_3d: PackedScene, config_data: Resource) -> Node:
	desmontar_minijuego() # Garantizar que la mesa esté limpia antes de instanciar
	
	if not escena_3d:
		push_error("EstacionTrabajo3D [%s]: Se intentó montar una escena nula." % id_minijuego)
		return null

	minijuego_activo = escena_3d.instantiate()
	punto_montaje.add_child(minijuego_activo)
	
	# Resetear transformaciones para que quede centrado en el punto_montaje
	if minijuego_activo is Node3D:
		minijuego_activo.transform = Transform3D.IDENTITY

	# Inicializar datos del nivel si la escena lo soporta
	if minijuego_activo.has_method("inicializar_minijuego"):
		minijuego_activo.inicializar_minijuego(config_data)
	elif minijuego_activo.has_method("cargar_nivel"):
		minijuego_activo.cargar_nivel(config_data)
		
	return minijuego_activo

## Limpia y destruye el minijuego de la mesa
func desmontar_minijuego() -> void:
	if is_instance_valid(minijuego_activo):
		minijuego_activo.queue_free()
		minijuego_activo = null
	
	# Limpieza de seguridad por si quedaron nodos huérfanos
	for child in punto_montaje.get_children():
		child.queue_free()
