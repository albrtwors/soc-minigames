# res://scripts/data/nivel_base_data.gd
extends Resource
class_name NivelBaseData

enum TipoNivel { TUTORIAL, NIVE_JUGABLE }

@export var id_nivel: String = "nivel_1"
@export var titulo_ui: String = "NIVEL 1" # Texto para el botón en la Grid
@export var tipo_nivel: TipoNivel = TipoNivel.NIVE_JUGABLE
