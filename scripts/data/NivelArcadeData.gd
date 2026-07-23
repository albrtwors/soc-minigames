# res://scripts/data/nivel_arcade_data.gd
extends NivelBaseData
class_name NivelArcadeData

func _init() -> void:
	tipo_nivel = TipoNivel.NIVE_JUGABLE

@export_group("Parámetros Arcade")
@export var tiempo_limite: float = 30.0 # Segundos predeterminados
@export var puntos_por_acierto: int = 100
@export var penalizacion_error: int = 25

# Aquí mantienes tus configuraciones específicas del minijuego (nodos, cables, etc.)
@export_group("Configuración Específica")
@export var nodos_disponibles: Array[Dictionary] = []
@export var conexiones_requeridas: Array[Dictionary] = []
