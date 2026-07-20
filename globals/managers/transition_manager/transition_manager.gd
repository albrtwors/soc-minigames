# TransitionManager.gd
extends Node

const BLACK_SCREEN_SCENE = preload("res://scenes/ui/menus/loading_screen/loading_screen_component.tscn")

var loading_screen: Control
var current_level_3d: Node3D

func transition_to_3d_map(scene_path: String, progress_bar: ProgressBar, post_delay: float) -> void:
	ResourceLoader.load_threaded_request(scene_path)
	
	var loading_start_time = Time.get_ticks_msec()
	var is_loading = true
	
	while is_loading:
		await get_tree().process_frame
		
		var progress = []
		var status = ResourceLoader.load_threaded_get_status(scene_path, progress)
		var real_progress = progress[0] * 100.0 if progress.size() > 0 else 0.0
		
		var elapsed_time = (Time.get_ticks_msec() - loading_start_time) / 1000.0
		var time_progress = clamp((elapsed_time / 2.0) * 100.0, 0.0, 100.0)
		
		if progress_bar:
			progress_bar.value = min(real_progress, time_progress)
		
		if status == ResourceLoader.THREAD_LOAD_LOADED and elapsed_time >= 2.0:
			is_loading = false
	
	if progress_bar:
		progress_bar.value = 100.0
		
	await get_tree().create_timer(post_delay).timeout
	
	var root = get_tree().root.get_node_or_null("Main")
	if not root:
		push_error("TransitionManager: No se encontró el nodo raíz 'Main'.")
		return

	# --- LIMPIEZA INMEDIATA Y SEGURA ---
	if root.has_node("MainLevel3D"):
		var old_level = root.get_node("MainLevel3D")
		root.remove_child(old_level)
		old_level.free() # Destrucción inmediata sincrónica para no dejar cámaras/scripts huérfanos
	
	# Instanciamos la nueva escena 3D
	var mapa_3d_scene = ResourceLoader.load_threaded_get(scene_path) as PackedScene
	if mapa_3d_scene:
		current_level_3d = mapa_3d_scene.instantiate()
		current_level_3d.name = "MainLevel3D"
		
		root.add_child(current_level_3d)
		root.move_child(current_level_3d, 0)
		
		# Forzamos la activación de la cámara del mapa nuevo
		_activate_scene_camera(current_level_3d)

func _activate_scene_camera(node: Node) -> bool:
	if node is Camera3D:
		node.make_current()
		return true
	for child in node.get_children():
		if _activate_scene_camera(child):
			return true
	return false
