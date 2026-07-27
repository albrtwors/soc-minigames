extends Area3D
class_name EstacionTrabajo3D

@export var id_minijuego: String = "phishing"

@onready var sub_viewport: SubViewport = $SubViewport
@onready var mesh_pantalla: MeshInstance3D = $Sketchfab_Scene/MeshPantalla

func _ready() -> void:
	# Asegura que el Area3D detecte clics y raycasts del ratón
	input_ray_pickable = true
	input_event.connect(_input_event)
	
	if not mesh_pantalla or not sub_viewport:
		push_error("No se encontró MeshPantalla o SubViewport")
		return

	sub_viewport.transparent_bg = false
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Desactivamos el manejo local para evitar conflictos al reemitir con push_input
	sub_viewport.handle_input_locally = false
	
	if sub_viewport.size == Vector2i.ZERO:
		sub_viewport.size = Vector2i(1280, 720)

	var mat = StandardMaterial3D.new()
	var viewport_tex = sub_viewport.get_texture()
	
	mat.albedo_texture = viewport_tex
	mat.emission_enabled = true
	mat.emission_texture = viewport_tex
	mat.emission_energy_multiplier = 1.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Invertir eje X para corregir espejo visual del SubViewport
	mat.uv1_scale = Vector3(-1, 1, 1)
	mat.uv1_offset = Vector3(1, 0, 0)

	if mesh_pantalla.mesh:
		for i in range(mesh_pantalla.mesh.get_surface_count()):
			mesh_pantalla.set_surface_override_material(i, mat)
	else:
		mesh_pantalla.set_surface_override_material(0, mat)


func montar_minijuego(escena_ui: PackedScene, config_data: Resource) -> Node:
	_limpiar_viewport()
	
	var instancia_ui = escena_ui.instantiate()
	
	if instancia_ui is CanvasLayer:
		instancia_ui.custom_viewport = sub_viewport
	
	sub_viewport.add_child(instancia_ui)
	
	if instancia_ui is Control:
		instancia_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
		instancia_ui.size = Vector2(sub_viewport.size)
		instancia_ui.position = Vector2.ZERO
	
	if instancia_ui.has_method("inicializar_minijuego"):
		instancia_ui.inicializar_minijuego(config_data)
	elif instancia_ui.has_method("cargar_nivel"):
		instancia_ui.cargar_nivel(config_data)
		
	return instancia_ui

func desmontar_minijuego() -> void:
	_limpiar_viewport()

func _limpiar_viewport() -> void:
	for child in sub_viewport.get_children():
		sub_viewport.remove_child(child)
		child.queue_free()

## Transforma el evento 3D sobre la malla en coordenadas 2D para el SubViewport
func _input_event(_cam: Camera3D, event: InputEvent, pos: Vector3, _normal: Vector3, _shape: int) -> void:
	if not sub_viewport or sub_viewport.get_child_count() == 0:
		return
		
	if not mesh_pantalla or not mesh_pantalla.mesh:
		return

	var aabb: AABB = mesh_pantalla.mesh.get_aabb()
	if aabb.size.x == 0 or aabb.size.y == 0:
		return

	# Convertir posición de impacto 3D a coordenadas locales del MeshInstance3D
	var local_pos: Vector3 = mesh_pantalla.global_transform.affine_inverse() * pos
	
	# Mapear la coordenada al rango local UV [0.0, 1.0] basándose en el AABB real
	var uv_x: float = (local_pos.x - aabb.position.x) / aabb.size.x
	var uv_y: float = 1.0 - ((local_pos.y - aabb.position.y) / aabb.size.y)
	
	# Invertir eje X debido al mat.uv1_scale.x = -1
	uv_x = 1.0 - uv_x
	
	# Clamp de seguridad
	uv_x = clampf(uv_x, 0.0, 1.0)
	uv_y = clampf(uv_y, 0.0, 1.0)

	# Si es un evento de ratón (clic o movimiento), calcular y propagar al SubViewport
	if event is InputEventMouse:
		var event_2d: InputEventMouse = event.duplicate() as InputEventMouse
		var mouse_pos_2d: Vector2 = Vector2(uv_x * sub_viewport.size.x, uv_y * sub_viewport.size.y)
		
		event_2d.position = mouse_pos_2d
		event_2d.global_position = mouse_pos_2d
		
		sub_viewport.push_input(event_2d)
