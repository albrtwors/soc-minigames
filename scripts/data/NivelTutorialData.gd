# res://scripts/data/nivel_tutorial_data.gd
extends NivelBaseData
class_name NivelTutorialData

func _init() -> void:
	tipo_nivel = TipoNivel.TUTORIAL
	titulo_ui = "TUTORIAL"

@export_group("Páginas Explicativas")
# Array de diccionarios o structs: [{"texto": "...", "imagen": Texture2D}]
@export var paginas_teoria: Array[Dictionary] = []

@export_group("Demo Practica (Opcional)")
@export var tiene_demo_jugable: bool = true
@export var paso_demo_requerido: String = "" # ID o instrucción del paso a repetir
