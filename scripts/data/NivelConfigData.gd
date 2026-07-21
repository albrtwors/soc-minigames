# res://scripts/data/nivel_config_data.gd
extends Resource
class_name NivelConfigData

@export var nivel_id: int = 1
@export var minigame_id: String = "configuracion"
@export var titulo: String = "Nivel 1"

@export_group("Lección Didáctica")
@export_multiline var briefing_teoria: String = ""
@export_multiline var briefing_mision: String = ""
@export_multiline var debriefing_exito: String = ""

@export_group("Configuración del Puzzle")
# Array de conexiones esperadas en el puzzle de parcheo/cableado
# Ejemplo: [{"origen": "PC_Empleado", "destino": "Switch_1", "cable": "AZUL"}]
@export var conexiones_requeridas: Array[Dictionary] = []
@export var nodos_disponibles: Array[Dictionary] = []
