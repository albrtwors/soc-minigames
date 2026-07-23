# res://scenes/ui/menus/minigame_frame/minigame_frame.gd
extends Control

# Mapeo de escenas interactivas por módulo
const MINIGAME_SCENES = {
	"configuracion": "res://scenes/minigames/configuracion/CablePuzzle.tscn"
}

# Mapeo de recursos .tres por nivel
const LEVEL_DATA_PATHS = {
	"configuracion": [
		"res://scripts/data/config_levels/nivel_1.tres",
		"res://scripts/data/config_levels/nivel_2.tres",
		"res://scripts/data/config_levels/nivel_3.tres"
	]
}

@onready var selector_panel: Control = $LevelSelectorPanel
@onready var container_niveles: Control = $LevelSelectorPanel/VBoxContainer/GridContainer
@onready var container_puzzle: Control = $PuzzleContainer
@onready var btn_volver: Button = $UIHeader/BtnVolverMenu

var minigame_id_actual: String = ""
var indice_nivel_actual: int = 0

func _ready() -> void:
	EventBus.minigame_selected.connect(_on_minigame_selected)
	if btn_volver:
		btn_volver.pressed.connect(_on_volver_pressed)
	_limpiar_puzzle()

func _on_minigame_selected(id: String, _level: int = 1) -> void:
	minigame_id_actual = id
	indice_nivel_actual = 0
	show()
	_mostrar_selector_niveles()

func _mostrar_selector_niveles() -> void:
	_limpiar_puzzle()
	
	if selector_panel:
		selector_panel.show()
		
	# Limpiar botones anteriores
	for child in container_niveles.get_children():
		child.queue_free()
		
	# Generar botones simples (su estilo lo heredan del Theme del proyecto o del nodo padre)
	if LEVEL_DATA_PATHS.has(minigame_id_actual):
		var rutas = LEVEL_DATA_PATHS[minigame_id_actual]
		for i in range(rutas.size()):
			var btn = Button.new()
			btn.text = "NIVEL " + str(i + 1)
			btn.custom_minimum_size = Vector2(140, 55)
			
			var idx = i
			btn.pressed.connect(func(): _cargar_nivel_por_indice(idx))
			container_niveles.add_child(btn)

func _cargar_nivel_por_indice(idx: int) -> void:
	indice_nivel_actual = idx
	
	if LEVEL_DATA_PATHS.has(minigame_id_actual):
		var rutas = LEVEL_DATA_PATHS[minigame_id_actual]
		if idx < rutas.size():
			_cargar_nivel_puzzle(rutas[idx])
		else:
			# Al completar los niveles disponibles, regresa al selector de niveles
			_mostrar_selector_niveles()

func _cargar_nivel_puzzle(ruta_tres: String) -> void:
	_limpiar_puzzle()
	
	if selector_panel:
		selector_panel.hide()
	
	if MINIGAME_SCENES.has(minigame_id_actual):
		var escena_path = MINIGAME_SCENES[minigame_id_actual]
		
		if ResourceLoader.exists(escena_path):
			var escena_resource = load(escena_path) as PackedScene
			if escena_resource:
				var puzzle_instance = escena_resource.instantiate()
				container_puzzle.add_child(puzzle_instance)
				
				# 1. Avanzar de nivel al ganar
				if puzzle_instance.has_signal("nivel_completado"):
					puzzle_instance.nivel_completado.connect(_on_nivel_completado)
					
				# 2. Regresar al selector de niveles al pulsar "Volver" dentro del puzzle
				if puzzle_instance.has_signal("salir_solicitado"):
					puzzle_instance.salir_solicitado.connect(_mostrar_selector_niveles)
				
				# Carga del recurso de datos .tres
				if ResourceLoader.exists(ruta_tres):
					var data = load(ruta_tres)
					if puzzle_instance.has_method("cargar_nivel") and data:
						puzzle_instance.cargar_nivel(data)

# Callback invocado cuando el jugador supera el puzzle
func _on_nivel_completado() -> void:
	_cargar_nivel_por_indice(indice_nivel_actual + 1)

func _limpiar_puzzle() -> void:
	for child in container_puzzle.get_children():
		container_puzzle.remove_child(child)
		child.queue_free()

func _on_volver_pressed() -> void:
	# Si hay un puzzle cargado/activo, regresa al selector local de niveles
	if container_puzzle.get_child_count() > 0:
		_mostrar_selector_niveles()
	else:
		# Si ya estamos en el selector de niveles, sale del Frame y regresa al menú de minijuegos
		_limpiar_puzzle()
		minigame_id_actual = ""
		hide()
		EventBus.user_exit.emit()
